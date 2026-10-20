import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/design/paper/paper_art.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/widgets/common/loading_states.dart';
import 'package:ghar360/core/widgets/common/location_selector.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';
import 'package:ghar360/features/properties/application/property_filters.dart';
import 'package:ghar360/features/properties/application/property_queries.dart';

/// Search input is presentation state owned by the mounted tab. Filters are
/// durable provider state, and changing a filter never rebuilds the map here.
class UnifiedTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const UnifiedTopBar({
    super.key,
    required this.pageType,
    required this.title,
    this.showSearch = true,
    this.onSearchChanged,
    this.onSearchClear,
    this.onFilterTap,
    this.additionalActions,
    this.bottom,
  });
  final PageType pageType;
  final String title;
  final bool showSearch;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onSearchClear;
  final VoidCallback? onFilterTap;
  final List<Widget>? additionalActions;
  final PreferredSizeWidget? bottom;
  bool get supportsSearch => showSearch && pageType != PageType.discover;
  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (supportsSearch ? 64 : bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(
      propertyFiltersProvider.select((state) => state.forPage(pageType).activeFilterCount),
    );
    final save = ref.watch(propertyFiltersProvider.select((state) => state.save));
    final feed = switch (pageType) {
      PageType.discover => PropertyFeed.discover,
      PageType.explore => PropertyFeed.explore,
      PageType.likes => PropertyFeed.liked,
    };
    final refreshing = ref.watch(propertyQueryProvider(feed).select((state) => state.isRefreshing));
    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 12,
      // The bar is the page sky, with the page's grain under the controls.
      flexibleSpace: const PageGrain(),
      title: Row(
        children: [
          Expanded(child: LocationSelector(pageType: pageType)),
          if (refreshing) LoadingStates.buttonSpinner(size: 20, color: context.design.accent),
          if (save.hasError)
            IconButton(
              key: const ValueKey('qa.topbar.filters.retry'),
              tooltip: '${context.l10n.text('filters_save_failed')} ${context.l10n.text('retry')}',
              icon: const PaperIcon(KnifeIcon.retry),
              onPressed: () => ref.read(propertyFiltersProvider.notifier).retrySave(),
            ),
          IconButton(
            key: ValueKey('qa.topbar.filter.${pageType.name}'),
            tooltip: '${context.l10n.text('filters')}${count == 0 ? '' : ' ($count)'}',
            onPressed: onFilterTap,
            icon: Badge(
              isLabelVisible: count > 0,
              backgroundColor: context.design.buttonPrimary,
              textColor: context.design.buttonPrimaryText,
              label: Text('$count'),
              child: const PaperIcon(KnifeIcon.filter),
            ),
          ),
          ...?additionalActions,
        ],
      ),
      bottom: supportsSearch
          ? PreferredSize(
              preferredSize: const Size.fromHeight(64),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: PropertySearchField(
                  pageType: pageType,
                  onChanged: onSearchChanged,
                  onClear: onSearchClear,
                ),
              ),
            )
          : bottom,
    );
  }
}

/// The search input of one tab. It writes the tab's search filter and follows
/// it when the filter changes elsewhere. [bare] drops the field's own fill and
/// outline, for a field that sits on a paper slip.
class PropertySearchField extends ConsumerStatefulWidget {
  const PropertySearchField({
    super.key,
    required this.pageType,
    this.onChanged,
    this.onClear,
    this.bare = false,
  });

  final PageType pageType;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final bool bare;

  @override
  ConsumerState<PropertySearchField> createState() => _PropertySearchFieldState();
}

class _PropertySearchFieldState extends ConsumerState<PropertySearchField> {
  late final TextEditingController _search;
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(
      text: ref.read(propertyFiltersProvider).forPage(widget.pageType).searchQuery ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant PropertySearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageType != widget.pageType) {
      _search.text = ref.read(propertyFiltersProvider).forPage(widget.pageType).searchQuery ?? '';
      _focus.unfocus();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _change(String value) {
    ref.read(propertyFiltersProvider.notifier).search(widget.pageType, value);
    widget.onChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      propertyFiltersProvider.select((state) => state.forPage(widget.pageType).searchQuery),
      (_, value) {
        if (_search.text != (value ?? '')) setState(() => _search.text = value ?? '');
      },
    );
    final design = context.design;
    const none = InputBorder.none;
    return TextField(
      key: ValueKey('qa.topbar.search_input.${widget.pageType.name}'),
      controller: _search,
      focusNode: _focus,
      onChanged: (value) {
        _change(value);
        // The clear control follows the text.
        setState(() {});
      },
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _focus.unfocus(),
      style: TextStyle(color: design.textPrimary),
      decoration: InputDecoration(
        hintText: context.l10n.text(
          widget.pageType == PageType.likes ? 'search_in_likes_hint' : 'search_locations_hint',
        ),
        prefixIcon: const PaperIcon(KnifeIcon.search),
        filled: !widget.bare,
        fillColor: design.inputBackground,
        border: widget.bare ? none : null,
        enabledBorder: widget.bare ? none : null,
        focusedBorder: widget.bare ? none : null,
        constraints: const BoxConstraints(minHeight: 48),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        suffixIcon: _search.text.isEmpty
            ? null
            : IconButton(
                tooltip: context.l10n.text('clear'),
                icon: const PaperIcon(KnifeIcon.close),
                onPressed: () {
                  _search.clear();
                  _change('');
                  setState(() {});
                  widget.onClear?.call();
                },
              ),
      ),
    );
  }
}

/// The page's paper grain, for a backdrop under the content. Never over text.
class PageGrain extends StatelessWidget {
  const PageGrain({super.key});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(child: CustomPaint(painter: _GrainPainter(context.design.grain))),
  );
}

class _GrainPainter extends CustomPainter {
  const _GrainPainter(this.grain);

  final Color grain;

  @override
  void paint(Canvas canvas, Size size) => paintPaperGrain(canvas, Offset.zero & size, grain);

  @override
  bool shouldRepaint(_GrainPainter old) => old.grain != grain;
}

/// Explore's bar: the place and the filters. Its search is a paper slip
/// floating over the top of the map ([PropertySearchField], bare).
class ExploreTopBar extends UnifiedTopBar {
  const ExploreTopBar({super.key, super.onFilterTap, super.additionalActions})
    : super(pageType: PageType.explore, title: 'explore_properties', showSearch: false);
}

class DiscoverTopBar extends UnifiedTopBar {
  const DiscoverTopBar({super.key, super.onFilterTap, super.additionalActions})
    : super(pageType: PageType.discover, title: 'app_name', showSearch: false);
}

class LikesTopBar extends UnifiedTopBar {
  const LikesTopBar({super.key, super.onSearchChanged, super.onFilterTap, super.additionalActions})
    : super(pageType: PageType.likes, title: 'my_likes');
}
