import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/design/paper/paper_chrome.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/app_spacing.dart';
import 'package:ghar360/core/utils/app_toast.dart';
import 'package:ghar360/core/utils/indian_currency.dart';
import 'package:ghar360/core/widgets/common/inline_retry_banner.dart';
import 'package:ghar360/core/widgets/common/loading_states.dart';
import 'package:ghar360/core/widgets/common/symmetric_safe_area.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';
import 'package:ghar360/core/widgets/property/property_facts.dart';
import 'package:ghar360/features/properties/application/amenities.dart';
import 'package:ghar360/features/properties/application/property_filters.dart';

/// Opens the filter sheet for [pageType]. The sheet takes its cut paper edge
/// from the theme; changes apply only when the user taps Apply.
void showPropertyFilterBottomSheet(
  BuildContext context, {
  PageType pageType = PageType.explore,
  VoidCallback? onFiltersApplied,
}) {
  FocusScope.of(context).unfocus();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    constraints: sheetConstraints(context),
    builder: (_) => UncontrolledProviderScope(
      container: ProviderScope.containerOf(context),
      // A left-aligned form: it clears the pill on the right, not both sides.
      child: SafeArea(
        top: false,
        bottom: false,
        child: _FilterBottomSheet(pageType: pageType, onFiltersApplied: onFiltersApplied),
      ),
    ),
  );
}

class _FilterBottomSheet extends ConsumerStatefulWidget {
  final PageType pageType;
  final VoidCallback? onFiltersApplied;

  const _FilterBottomSheet({required this.pageType, this.onFiltersApplied});

  @override
  ConsumerState<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends ConsumerState<_FilterBottomSheet> {
  bool _applying = false;
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  late String _selectedPurpose;
  late double _minPrice;
  late double _maxPrice;
  late int _minBedrooms;
  late int _maxBedrooms;
  late List<String> _selectedPropertyTypes;
  late List<String> _selectedAmenities;
  late String _selectedGenderPreference;
  late String _selectedSharingType;

  static const purposes = ['buy', 'rent', 'short_stay'];

  static const propertyTypes = [
    'all',
    'apartment',
    'house',
    'builder_floor',
    'room',
    'villa',
    'plot',
    'condo',
    'penthouse',
    'studio',
    'loft',
    'pg',
    'flatmate',
    'office',
    'shop',
    'warehouse',
  ];

  @override
  void initState() {
    super.initState();
    final current = ref.read(propertyFiltersProvider).forPage(widget.pageType);
    _selectedPurpose = purposes.contains(current.purpose) ? current.purpose! : 'buy';
    // Clamp saved values into the slider range.
    final maxRange = _getPriceMax(_selectedPurpose);
    _minPrice = (current.priceMin ?? _getPriceMin(_selectedPurpose)).clamp(0.0, maxRange);
    _maxPrice = (current.priceMax ?? maxRange).clamp(0.0, maxRange);
    if (_maxPrice < _minPrice) _maxPrice = _minPrice;
    _minBedrooms = (current.bedroomsMin ?? 0).clamp(0, 10);
    _maxBedrooms = (current.bedroomsMax ?? 10).clamp(_minBedrooms, 10);
    _selectedPropertyTypes = UnifiedFilterModel.normalizePropertyTypes(
      current.propertyType ?? const <String>[],
    );
    _selectedAmenities = List<String>.from(current.amenities ?? const <String>[]);
    _selectedGenderPreference =
        UnifiedFilterModel.normalizeGenderPreferenceToken(current.genderPreference) ?? '';
    _selectedSharingType = UnifiedFilterModel.normalizeSharingTypeToken(current.sharingType) ?? '';
    if (!_hasPgOrFlatmateSelection) {
      _selectedGenderPreference = '';
      _selectedSharingType = '';
    }
  }

  bool get _hasPgOrFlatmateSelection =>
      _selectedPropertyTypes.any((type) => type == 'pg' || type == 'flatmate');

  bool _isPropertyTypeSelected(String type) =>
      type == 'all' ? _selectedPropertyTypes.isEmpty : _selectedPropertyTypes.contains(type);

  void _togglePropertyType(String type) {
    setState(() {
      if (type == 'all') {
        _selectedPropertyTypes = <String>[];
        _selectedGenderPreference = '';
        _selectedSharingType = '';
        return;
      }
      final nextTypes = List<String>.from(_selectedPropertyTypes);
      if (nextTypes.contains(type)) {
        nextTypes.remove(type);
      } else {
        if ((type == 'pg' || type == 'flatmate') && _selectedPurpose != 'rent') {
          _selectedPurpose = 'rent';
          _minPrice = _getPriceMin('rent');
          _maxPrice = _getPriceMax('rent');
        }
        nextTypes.add(type);
      }
      _selectedPropertyTypes = nextTypes;
      if (!_hasPgOrFlatmateSelection) {
        _selectedGenderPreference = '';
        _selectedSharingType = '';
      }
    });
  }

  void _selectPurpose(String purpose) {
    setState(() {
      _selectedPurpose = purpose;
      _minPrice = _getPriceMin(purpose);
      _maxPrice = _getPriceMax(purpose);
      if (purpose != 'rent') {
        _selectedPropertyTypes.removeWhere((type) => type == 'pg' || type == 'flatmate');
        _selectedGenderPreference = '';
        _selectedSharingType = '';
      }
    });
  }

  /// Amenity titles match without case, as on the backend.
  bool _isAmenitySelected(String title) =>
      _selectedAmenities.any((selected) => selected.toLowerCase() == title.toLowerCase());

  void _toggleAmenity(String title) {
    setState(() {
      if (_isAmenitySelected(title)) {
        _selectedAmenities.removeWhere((selected) => selected.toLowerCase() == title.toLowerCase());
      } else {
        _selectedAmenities.add(title);
      }
    });
  }

  static const double _sectionGap = 24;

  @override
  Widget build(BuildContext context) {
    final saveFailed = ref.watch(propertyFiltersProvider.select((state) => state.save.hasError));
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (saveFailed)
                    InlineRetryBanner(
                      identifier: 'qa.filters.sheet.retry',
                      message: context.l10n.text('filters_save_failed'),
                      onRetry: _applyFilters,
                      isLoading: _applying,
                    ),
                  _buildPurposeFilter(),
                  const SizedBox(height: _sectionGap),
                  _buildPriceFilter(),
                  const SizedBox(height: _sectionGap),
                  _buildBedroomsFilter(),
                  const SizedBox(height: _sectionGap),
                  _buildPropertyTypeFilter(),
                  const SizedBox(height: _sectionGap),
                  if (_hasPgOrFlatmateSelection) ...[
                    _buildListingPreferencesFilter(),
                    const SizedBox(height: _sectionGap),
                  ],
                  _buildAmenitiesFilter(),
                ],
              ),
            ),
          ),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              context.l10n.text('filter_properties'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: PaperIcon(KnifeIcon.close, color: context.design.textSecondary),
          tooltip: context.l10n.text('dismiss'),
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        ),
      ],
    ),
  );

  Widget _choices(List<Widget> children) => Wrap(spacing: 8, runSpacing: 8, children: children);

  Widget _buildPurposeFilter() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SectionTitle(context.l10n.text('purpose')),
      _choices([
        for (final purpose in purposes)
          _Choice(
            label: context.l10n.text(purpose),
            selected: _selectedPurpose == purpose,
            onTap: () => _selectPurpose(purpose),
          ),
      ]),
    ],
  );

  Widget _buildPriceFilter() {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final priceLabel = switch (_selectedPurpose) {
      'rent' => l10n.text('price_per_month'),
      'short_stay' => l10n.text('daily_rate'),
      _ => l10n.text('property_price'),
    };
    final minRange = _getPriceMin(_selectedPurpose);
    final maxRange = _getPriceMax(_selectedPurpose);
    String money(double value) =>
        IndianCurrency.compact(value, fractionDigits: 1, languageCode: l10n.locale.languageCode);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(priceLabel),
        RangeSlider(
          values: RangeValues(
            _minPrice.clamp(minRange, maxRange),
            _maxPrice.clamp(minRange, maxRange),
          ),
          min: minRange,
          max: maxRange,
          divisions: 100,
          labels: RangeLabels(money(_minPrice), money(_maxPrice)),
          onChanged: (values) => setState(() {
            _minPrice = values.start;
            _maxPrice = values.end;
          }),
        ),
        // The two ends of the range, under the two ends of the slider.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text(money(_minPrice), style: text.labelLarge)),
              const SizedBox(width: 16),
              Flexible(
                child: Text(money(_maxPrice), style: text.labelLarge, textAlign: TextAlign.end),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBedroomsFilter() {
    final l10n = context.l10n;
    final helper = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: context.design.textSecondary);
    Widget field(String label, Widget dropdown) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: helper),
          const SizedBox(height: 6),
          dropdown,
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(l10n.text('bedrooms')),
        // The two fields share one line even when one label wraps.
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            field(
              l10n.text('min_bedrooms'),
              DropdownButtonFormField<int>(
                key: ValueKey('qa.filters.min_bedrooms.$_minBedrooms'),
                initialValue: _minBedrooms,
                isExpanded: true,
                isDense: true,
                items: [
                  for (var bedroom = 0; bedroom <= 10; bedroom++)
                    DropdownMenuItem(
                      value: bedroom,
                      child: Text(bedroom == 0 ? l10n.text('any') : '$bedroom+'),
                    ),
                ],
                onChanged: (value) => setState(() {
                  _minBedrooms = value!;
                  if (_maxBedrooms < _minBedrooms) _maxBedrooms = _minBedrooms;
                }),
              ),
            ),
            const SizedBox(width: 12),
            field(
              l10n.text('max_bedrooms'),
              DropdownButtonFormField<int>(
                key: ValueKey('qa.filters.max_bedrooms.$_maxBedrooms'),
                initialValue: _maxBedrooms,
                isExpanded: true,
                isDense: true,
                items: [
                  for (var bedroom = _minBedrooms; bedroom <= 10; bedroom++)
                    DropdownMenuItem(
                      value: bedroom,
                      child: Text(bedroom == 10 ? '10+' : '$bedroom'),
                    ),
                ],
                onChanged: (value) => setState(() => _maxBedrooms = value!),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPropertyTypeFilter() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SectionTitle(context.l10n.text('property_type')),
      _choices([
        for (final type in propertyTypes)
          _Choice(
            label: context.l10n.text(type),
            selected: _isPropertyTypeSelected(type),
            onTap: () => _togglePropertyType(type),
          ),
      ]),
    ],
  );

  Widget _buildListingPreferencesFilter() {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(l10n.text('pg_flatmate_preferences')),
        DropdownButtonFormField<String>(
          key: ValueKey('qa.filters.gender.$_selectedGenderPreference'),
          initialValue: _selectedGenderPreference.isNotEmpty ? _selectedGenderPreference : null,
          isExpanded: true,
          isDense: true,
          decoration: InputDecoration(labelText: l10n.text('gender_preference')),
          items: [
            DropdownMenuItem(value: '', child: Text(l10n.text('any_gender'))),
            DropdownMenuItem(value: 'any', child: Text(l10n.text('open_to_all'))),
            DropdownMenuItem(value: 'male', child: Text(l10n.text('male_only'))),
            DropdownMenuItem(value: 'female', child: Text(l10n.text('female_only'))),
          ],
          onChanged: (value) => setState(() => _selectedGenderPreference = value ?? ''),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey('qa.filters.sharing.$_selectedSharingType'),
          initialValue: _selectedSharingType.isNotEmpty ? _selectedSharingType : null,
          isExpanded: true,
          isDense: true,
          decoration: InputDecoration(labelText: l10n.text('room_type')),
          items: [
            DropdownMenuItem(value: '', child: Text(l10n.text('any_room_type'))),
            DropdownMenuItem(value: 'private_room', child: Text(l10n.text('private_room'))),
            DropdownMenuItem(value: 'shared_room', child: Text(l10n.text('shared_room'))),
          ],
          onChanged: (value) => setState(() => _selectedSharingType = value ?? ''),
        ),
      ],
    );
  }

  /// The backend's amenity list. It shows the cached copy at once; a failed
  /// first load shows a retry here only, and the rest of the sheet still works.
  Widget _buildAmenitiesFilter() {
    final amenities = ref.watch(amenitiesProvider);
    final items = amenities.items;
    if (items != null && items.isEmpty) return const SizedBox.shrink();
    final Widget body;
    if (items != null) {
      body = _choices([
        for (final amenity in items)
          _Choice(
            label: amenity.title,
            selected: _isAmenitySelected(amenity.title),
            onTap: () => _toggleAmenity(amenity.title),
          ),
      ]);
    } else if (amenities.error != null && !amenities.loading) {
      // InlineRetryBanner, not ErrorStates.inlineError: the latter overflows at
      // 320 px in Hindi (its retry label and message share one row).
      body = InlineRetryBanner(
        message: context.l10n.text('amenities_load_failed'),
        error: amenities.error,
        identifier: 'qa.filters.amenities.retry',
        onRetry: ref.read(amenitiesProvider.notifier).retry,
      );
    } else {
      body = Skeleton(
        child: _choices([
          for (final width in const [72.0, 104.0, 64.0, 88.0, 96.0, 80.0])
            SkeletonBox(width: width, height: 40),
        ]),
      );
    }
    return Column(
      key: const ValueKey('qa.filters.amenities'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [SectionTitle(context.l10n.text('amenities')), body],
    );
  }

  Widget _buildActionButtons() {
    final clear = TextButton(
      key: const ValueKey('qa.filters.clear'),
      onPressed: _applying ? null : _clearFilters,
      child: Text(context.l10n.text('clear_filters'), textAlign: TextAlign.center),
    );
    final apply = FilledButton(
      key: const ValueKey('qa.filters.apply'),
      onPressed: _applying ? null : _applyFilters,
      child: Text(context.l10n.text('apply_filters'), textAlign: TextAlign.center),
    );
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 360 || MediaQuery.textScalerOf(context).scale(14) > 21) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [apply, const SizedBox(height: 4), clear],
              );
            }
            return Row(
              children: [
                clear,
                const SizedBox(width: 12),
                Expanded(child: apply),
              ],
            );
          },
        ),
      ),
    );
  }

  void _clearFilters() {
    setState(() {
      final purpose = ref.read(propertyFiltersProvider).forPage(widget.pageType).purpose;
      _selectedPurpose = purposes.contains(purpose) ? purpose! : 'buy';
      _minPrice = _getPriceMin(_selectedPurpose);
      _maxPrice = _getPriceMax(_selectedPurpose);
      _minBedrooms = 0;
      _maxBedrooms = 10;
      _selectedPropertyTypes = <String>[];
      _selectedAmenities.clear();
      _selectedGenderPreference = '';
      _selectedSharingType = '';
    });
  }

  Future<void> _applyFilters() async {
    if (_applying) return;
    setState(() => _applying = true);
    // A saved title the backend no longer lists would match no home at all.
    final known = ref.read(amenitiesProvider).items;
    final amenities = known == null
        ? List<String>.from(_selectedAmenities)
        : [
            for (final amenity in known)
              if (_isAmenitySelected(amenity.title)) amenity.title,
          ];
    final current = ref.read(propertyFiltersProvider).forPage(widget.pageType);
    final saved = await ref
        .read(propertyFiltersProvider.notifier)
        .update(
          widget.pageType,
          current.copyWith(
            purpose: _selectedPurpose,
            priceMin: _minPrice,
            priceMax: _maxPrice,
            bedroomsMin: _minBedrooms,
            bedroomsMax: _maxBedrooms,
            propertyType: List<String>.from(_selectedPropertyTypes),
            amenities: amenities,
            genderPreference: _hasPgOrFlatmateSelection ? _selectedGenderPreference : '',
            sharingType: _hasPgOrFlatmateSelection ? _selectedSharingType : '',
          ),
        );
    if (!mounted) return;
    setState(() => _applying = false);
    if (!saved) {
      if (_scroll.hasClients) {
        _scroll.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
      return;
    }
    widget.onFiltersApplied?.call();
    final title = context.l10n.text('filters_applied');
    final message = context.l10n.text('filters_applied_message');
    Navigator.pop(context);
    AppToast.success(title, message);
  }

  double _getPriceMin(String purpose) => switch (purpose) {
    'rent' => 5000.0, // ₹5K per month
    'short_stay' => 500.0, // ₹500 per day
    _ => 500000.0, // ₹5L
  };

  double _getPriceMax(String purpose) => switch (purpose) {
    'rent' => 500000.0, // ₹5L per month
    'short_stay' => 50000.0, // ₹50K per day
    _ => 150000000.0, // ₹15Cr
  };
}

/// One selectable option, cut from paper like the folder tabs: off, it lies
/// behind in the darker card stock; on, it is the white sheet with teal words,
/// a check and a teal 2 px cut edge. No outline on the options that are off.
class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final ink = selected ? design.accent : design.textPrimary;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      avatar: selected ? PaperIcon(KnifeIcon.check, size: 16, color: ink) : null,
      labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: ink,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
      ),
      color: WidgetStatePropertyAll(selected ? design.surface : design.tabBehind),
      side: selected ? BorderSide(color: design.accent, width: 2) : BorderSide.none,
      shape: CutBorder(seed: 'choice-$label', amp: 1.5),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      elevation: 0,
      pressElevation: 0,
    );
  }
}
