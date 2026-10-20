import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/popular_city.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/services/google_places_service.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/utils/app_spacing.dart';
import 'package:ghar360/core/utils/app_toast.dart';
import 'package:ghar360/core/widgets/common/loading_states.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';
import 'package:ghar360/features/location/application/location_search_controller.dart';
import 'package:ghar360/features/location/application/location_source.dart';
import 'package:ghar360/features/properties/application/property_filters.dart';
import 'package:ghar360/features/properties/application/property_location.dart';

Future<void> showLocationPicker(BuildContext context, {required PageType pageType}) {
  final container = ProviderScope.containerOf(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => UncontrolledProviderScope(
      container: container,
      child: LocationPickerModal(pageType: pageType),
    ),
  );
}

class LocationSelector extends ConsumerWidget {
  const LocationSelector({super.key, required this.pageType});
  final PageType pageType;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (area, source) = ref.watch(
      propertyLocationProvider(pageType).select((state) => (state.location?.name, state.source)),
    );
    final name = area?.trim();
    final text = name == null
        ? context.l10n.text('select_location')
        : name.isEmpty
        ? context.l10n.text('current_location')
        : name;
    final label = source == LocationSource.ip
        ? '$text · ${context.l10n.text('location_approximate')}'
        : text;
    final id = 'qa.location.selector.trigger.${pageType.name}';
    final design = context.design;
    // A flat text control: bare pin, the area, a chevron. No pill.
    return Semantics(
      identifier: id,
      button: true,
      label: label,
      child: InkWell(
        key: ValueKey(id),
        borderRadius: BorderRadius.circular(AppBorderRadius.sm),
        onTap: () => showLocationPicker(context, pageType: pageType),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PaperIcon(KnifeIcon.pin, size: 18, color: design.accent),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                const SizedBox(width: 4),
                PaperIcon(KnifeIcon.chevronDown, size: 18, color: design.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LocationPickerModal extends ConsumerStatefulWidget {
  const LocationPickerModal({super.key, required this.pageType});
  final PageType pageType;
  @override
  ConsumerState<LocationPickerModal> createState() => _LocationPickerModalState();
}

class _LocationPickerModalState extends ConsumerState<LocationPickerModal> {
  final _searchController = TextEditingController();
  double? _radius;
  PlaceSuggestion? _lastSelected;
  AsyncValue<void> _settings = const AsyncData(null);
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _select(PlaceSuggestion suggestion) async {
    final scope = ref.read(storageScopeProvider);
    final controller = ref.read(locationSearchProvider(widget.pageType).notifier);
    final locationState = ref.read(propertyLocationProvider(widget.pageType));
    if (locationState.load.isLoading || locationState.save.isLoading) return;
    _lastSelected = suggestion;
    final location = await controller.resolve(suggestion);
    if (!mounted || location == null || !identical(scope, ref.read(storageScopeProvider))) return;
    final saved = await ref
        .read(propertyLocationProvider(widget.pageType).notifier)
        .select(location);
    if (!mounted || !saved || !identical(scope, ref.read(storageScopeProvider))) return;
    final title = context.l10n.text('location_selected');
    Navigator.of(context).pop();
    AppToast.success(title, location.name);
  }

  Future<void> _useCurrent() async {
    final scope = ref.read(storageScopeProvider);
    if (ref.read(locationSearchProvider(widget.pageType)).selection.isLoading) return;
    await ref.read(propertyLocationProvider(widget.pageType).notifier).useCurrent();
    if (!mounted || !identical(scope, ref.read(storageScopeProvider))) return;
    final state = ref.read(propertyLocationProvider(widget.pageType));
    if (state.location == null ||
        state.load.hasError ||
        state.save.hasError ||
        state.save.isLoading) {
      return;
    }
    final title = context.l10n.text('location_updated');
    final message = state.source == LocationSource.ip
        ? context.l10n.text('using_approximate_location')
        : context.l10n.text('using_current_location');
    Navigator.of(context).pop();
    AppToast.success(title, message);
  }

  Future<void> _openSettings(bool appSettings) async {
    if (_settings.isLoading) return;
    setState(() => _settings = const AsyncLoading());
    try {
      final source = ref.read(deviceLocationSourceProvider);
      final opened = await (appSettings ? source.openAppSettings() : source.openLocationSettings());
      if (!opened) throw LocationException('Settings unavailable', code: 'SETTINGS_UNAVAILABLE');
      if (mounted) setState(() => _settings = const AsyncData(null));
    } catch (error, stack) {
      if (mounted) setState(() => _settings = AsyncError(error, stack));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(locationSearchProvider(widget.pageType), (previous, next) {
      if (next.query != _searchController.text) {
        _searchController.value = TextEditingValue(
          text: next.query,
          selection: TextSelection.collapsed(offset: next.query.length),
        );
      }
    });
    final search = ref.watch(locationSearchProvider(widget.pageType));
    final searchController = ref.read(locationSearchProvider(widget.pageType).notifier);
    final location = ref.watch(propertyLocationProvider(widget.pageType));
    final filters = ref.watch(propertyFiltersProvider);
    final radius = (_radius ?? filters.forPage(widget.pageType).radiusKm ?? 10)
        .clamp(5.0, 50.0)
        .toDouble();
    final suggestions = PopularCity.buildSuggestionsList(search.query.trim(), search.suggestions);
    final busy = location.load.isLoading || location.save.isLoading || search.selection.isLoading;
    final error = location.load.error;
    final code = error is LocationException ? error.code : null;
    final screen = MediaQuery.sizeOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final modalId = 'qa.location.selector.modal.${widget.pageType.name}';
    return Semantics(
      identifier: modalId,
      label: context.l10n.text('select_location'),
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: SizedBox(
          key: ValueKey(modalId),
          height: (screen.height - keyboard) * 0.85,
          child: Column(
            children: [
              // The same head as the filter sheet: Erode title, bare close.
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          context.l10n.text('select_location'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: context.l10n.text('close'),
                      icon: const PaperIcon(KnifeIcon.close),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Semantics(
                  identifier: 'qa.location.selector.search_input.${widget.pageType.name}',
                  child: TextField(
                    key: ValueKey('qa.location.selector.search_input.${widget.pageType.name}'),
                    controller: _searchController,
                    onChanged: searchController.updateQuery,
                    onSubmitted: (_) => searchController.search(),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      labelText: context.l10n.text('search_location_hint'),
                      prefixIcon: const PaperIcon(KnifeIcon.search),
                      suffixIcon: search.query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: context.l10n.text('clear_search'),
                              icon: const PaperIcon(KnifeIcon.close),
                              onPressed: () {
                                _searchController.clear();
                                searchController.updateQuery('');
                              },
                            ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  children: [
                    if (search.query.trim().length >= 2)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          key: ValueKey(
                            'qa.location.selector.search_submit.${widget.pageType.name}',
                          ),
                          onPressed: search.search.isLoading
                              ? null
                              : () => searchController.search(),
                          icon: const PaperIcon(KnifeIcon.search),
                          label: Text(context.l10n.text('search')),
                        ),
                      ),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 16,
                      children: [
                        Text(context.l10n.text('search_radius')),
                        Text('${radius.toInt()} ${context.l10n.text('km_unit')}'),
                      ],
                    ),
                    Slider(
                      value: radius,
                      min: 5,
                      max: 50,
                      divisions: 9,
                      label: '${radius.toInt()} ${context.l10n.text('km_unit')}',
                      onChanged: (value) => setState(() => _radius = value),
                      onChangeEnd: (value) => ref
                          .read(propertyFiltersProvider.notifier)
                          .update(
                            widget.pageType,
                            filters.forPage(widget.pageType).copyWith(radiusKm: value),
                          ),
                    ),
                    if (filters.save.hasError)
                      _LocationRecovery(
                        messageKey: 'location_storage_failed',
                        onRetry: ref.read(propertyFiltersProvider.notifier).retrySave,
                      ),
                    Semantics(
                      identifier:
                          'qa.location.selector.use_current_location.${widget.pageType.name}',
                      child: ListTile(
                        key: ValueKey(
                          'qa.location.selector.use_current_location.${widget.pageType.name}',
                        ),
                        contentPadding: EdgeInsets.zero,
                        leading: PaperIcon(KnifeIcon.locate, color: context.design.accent),
                        title: Text(context.l10n.text('use_current_location')),
                        subtitle: Text(context.l10n.text('get_location_from_gps')),
                        trailing: location.load.isLoading
                            ? LoadingStates.buttonSpinner(
                                size: 20,
                                semanticsLabel: context.l10n.text('getting_location'),
                              )
                            : PaperIcon(
                                KnifeIcon.chevronRight,
                                color: context.design.textSecondary,
                              ),
                        onTap: busy ? null : _useCurrent,
                      ),
                    ),
                    if (error != null)
                      _LocationRecovery(
                        messageKey: switch (code) {
                          'LOCATION_DENIED_FOREVER' => 'location_permission_permanently_denied',
                          'LOCATION_DENIED' => 'location_permission_denied',
                          'LOCATION_DISABLED' => 'location_services_disabled',
                          _ => 'unable_to_get_current_location',
                        },
                        onRetry: busy ? null : _useCurrent,
                      ),
                    if (code == 'LOCATION_DENIED_FOREVER' || code == 'LOCATION_DISABLED')
                      TextButton(
                        onPressed: _settings.isLoading
                            ? null
                            : () => _openSettings(code == 'LOCATION_DENIED_FOREVER'),
                        child: Text(context.l10n.text('open_settings')),
                      ),
                    if (_settings.hasError)
                      _LocationRecovery(
                        messageKey: 'location_settings_failed',
                        onRetry: () => _openSettings(code == 'LOCATION_DENIED_FOREVER'),
                      ),
                    if (location.save.hasError)
                      _LocationRecovery(
                        messageKey: 'location_storage_failed',
                        onRetry: ref
                            .read(propertyLocationProvider(widget.pageType).notifier)
                            .retrySave,
                      ),
                    if (search.selection.hasError)
                      _LocationRecovery(
                        messageKey: 'location_details_failed',
                        onRetry: _lastSelected == null ? null : () => _select(_lastSelected!),
                      ),
                    if (search.search.isLoading)
                      Semantics(
                        label: context.l10n.text('loading'),
                        child: const LinearProgressIndicator(),
                      ),
                    if (search.search.hasError)
                      _LocationRecovery(
                        messageKey: 'failed_to_search_locations',
                        onRetry: () => searchController.search(),
                      ),
                    if (suggestions.isEmpty &&
                        search.query.isNotEmpty &&
                        !search.search.isLoading &&
                        !search.search.hasError)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          context.l10n.text('no_locations_found'),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    for (var index = 0; index < suggestions.listItemCount; index++)
                      if (suggestions.suggestionAt(index) case final PlaceSuggestion suggestion)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: PaperIcon(
                            PopularCity.isPopularPlaceId(suggestion.placeId)
                                ? KnifeIcon.building
                                : KnifeIcon.pin,
                            color: context.design.accent,
                          ),
                          title: Text(suggestion.mainText),
                          subtitle: suggestion.secondaryText.isEmpty
                              ? null
                              : Text(suggestion.secondaryText),
                          onTap: busy ? null : () => _select(suggestion),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 4),
                          child: Semantics(
                            header: true,
                            child: Text(
                              context.l10n.text('popular_cities'),
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ),
                        ),
                    if (search.usedFallback)
                      TextButton(
                        onPressed: () =>
                            launchUrl(Uri.parse('https://www.openstreetmap.org/copyright')),
                        child: Text(context.l10n.text('location_search_attribution')),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A flat failure line with an optional retry. The retry sits under the
/// message, so long Hindi labels at 2x never share a row with it.
class _LocationRecovery extends StatelessWidget {
  const _LocationRecovery({required this.messageKey, this.onRetry});
  final String messageKey;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) {
    final design = context.design;
    return Semantics(
      liveRegion: true,
      child: Padding(
        key: ValueKey(messageKey),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PaperIcon(KnifeIcon.alert, size: 20, color: design.error),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.l10n.text(messageKey),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: design.error),
                  ),
                ),
              ],
            ),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: Text(context.l10n.text('retry'))),
          ],
        ),
      ),
    );
  }
}
