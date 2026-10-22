import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/design/paper/paper_chrome.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/utils/app_spacing.dart';
import 'package:ghar360/core/utils/error_message.dart';
import 'package:ghar360/core/widgets/common/inline_retry_banner.dart';
import 'package:ghar360/core/widgets/common/loading_states.dart';
import 'package:ghar360/core/widgets/common/property_filter_widget.dart';
import 'package:ghar360/core/widgets/common/property_location_recovery.dart';
import 'package:ghar360/core/widgets/common/property_recovery_banner.dart';
import 'package:ghar360/core/widgets/common/unified_top_bar.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';
import 'package:ghar360/core/widgets/paper/paper_sheet.dart';
import 'package:ghar360/core/widgets/paper/paper_vignette.dart';
import 'package:ghar360/core/widgets/paper/sheet_sliver.dart';
import 'package:ghar360/features/explore/presentation/controllers/explore_controller.dart';
import 'package:ghar360/features/explore/presentation/widgets/explore_map.dart';
import 'package:ghar360/features/explore/presentation/widgets/property_detail_pane.dart';
import 'package:ghar360/features/explore/presentation/widgets/property_horizontal_list.dart';
import 'package:ghar360/features/properties/application/property_filters.dart';
import 'package:ghar360/features/properties/application/property_location.dart';
import 'package:ghar360/features/properties/application/property_queries.dart';

const _feed = PropertyFeed.explore;
const _page = PageType.explore;

/// The map with a strip of homes over it. From 840 px the open home shows in
/// a pane on the right. The frame watches nothing; each part below watches
/// only what it draws, so a camera move or a highlight does not rebuild it.
class ExploreView extends ConsumerStatefulWidget {
  const ExploreView({super.key});
  @override
  ConsumerState<ExploreView> createState() => _ExploreViewState();
}

class _ExploreViewState extends ConsumerState<ExploreView> {
  /// The home in the detail pane. Only two-pane windows use it.
  PropertyModel? _open;

  @override
  Widget build(BuildContext context) {
    final twoPane = isTwoPane(context);
    return Scaffold(
      backgroundColor: context.design.background,
      appBar: ExploreTopBar(
        onFilterTap: () => showPropertyFilterBottomSheet(context, pageType: _page),
      ),
      body: Semantics(
        label: context.l10n.text('explore'),
        identifier: 'qa.explore.screen',
        child: Column(
          children: [
            const PropertyRecoveryBanner(feed: _feed),
            const _ExploreBanners(),
            Expanded(
              child: twoPane
                  ? Row(
                      children: [
                        Expanded(
                          child: _ExploreBody(
                            openId: _open?.id,
                            onOpen: (property) => setState(() => _open = property),
                          ),
                        ),
                        SizedBox(width: 420, child: PropertyDetailPane(property: _open)),
                      ],
                    )
                  : const _ExploreBody(),
            ),
          ],
        ),
      ),
    );
  }
}

/// The sky's hand-cut bottom edge, lying over the top of the map.
class _SkyEdge extends StatelessWidget {
  const _SkyEdge();

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    return IgnorePointer(
      child: CustomPaint(painter: _SkyEdgePainter(design.background, design.sheetLip)),
    );
  }
}

class _SkyEdgePainter extends CustomPainter {
  const _SkyEdgePainter(this.sky, this.edge);

  final Color sky;
  final Color edge;

  @override
  void paint(Canvas canvas, Size size) {
    // A sheet lip turned upside down: the cut faces the map below.
    canvas
      ..save()
      ..translate(0, size.height)
      ..scale(1, -1);
    paintPaperLip(canvas, size, 'explore-sky', sheet: sky, edge: edge);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SkyEdgePainter old) => old.sky != sky || old.edge != edge;
}

/// Progress and the failures that keep the map: refresh, next page, GPS,
/// location save and the map-area search.
class _ExploreBanners extends ConsumerWidget {
  const _ExploreBanners();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (refreshing, loading, paginationError, error, busy) = ref.watch(
      propertyQueryProvider(_feed).select(
        (page) => (page.isRefreshing, page.isLoading, page.paginationError, page.error, page.busy),
      ),
    );
    final (located, loadFailed, loadBusy, saveFailed, saveBusy) = ref.watch(
      propertyLocationProvider(_page).select(
        (location) => (
          location.location != null,
          location.load.hasError,
          location.load.isLoading,
          location.save.hasError,
          location.save.isLoading,
        ),
      ),
    );
    final (cameraFailed, cameraBusy) = ref.watch(
      exploreProvider.select(
        (state) => (state.cameraUpdate.hasError, state.cameraUpdate.isLoading),
      ),
    );
    final contentError = paginationError ?? (located && error is! LocationException ? error : null);
    return Column(
      children: [
        SizedBox(
          height: 2,
          child: refreshing || (loading && located)
              ? const LinearProgressIndicator(minHeight: 2)
              : null,
        ),
        if (contentError != null)
          InlineRetryBanner(
            message: paginationError != null
                ? context.l10n.text('load_more_failed')
                : errorMessage(context, contentError),
            error: contentError,
            isLoading: busy,
            identifier: 'qa.explore.content.retry',
            onRetry: () {
              final query = ref.read(propertyQueryProvider(_feed).notifier);
              if (paginationError != null) {
                query.loadMore(retry: true);
              } else {
                query.load(refresh: true);
              }
            },
          ),
        if (located && (loadFailed || loadBusy))
          const PropertyLocationRecovery(pageType: _page, inline: true),
        if (located && (saveFailed || cameraFailed))
          InlineRetryBanner(
            message: context.l10n.text(
              saveFailed ? 'location_storage_failed' : 'unable_to_get_current_location',
            ),
            isLoading: loadBusy || saveBusy || cameraBusy,
            identifier: 'qa.explore.location.retry',
            onRetry: () {
              if (saveFailed) {
                ref.read(propertyLocationProvider(_page).notifier).retrySave();
              } else {
                ref.read(exploreProvider.notifier).retryCameraSearch();
              }
            },
          ),
      ],
    );
  }
}

/// The map once there is a place to show, else location recovery or loading.
class _ExploreBody extends ConsumerWidget {
  const _ExploreBody({this.onOpen, this.openId});

  final ValueChanged<PropertyModel>? onOpen;
  final int? openId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (located, loadFailed) = ref.watch(
      propertyLocationProvider(
        _page,
      ).select((location) => (location.location != null, location.load.hasError)),
    );
    final locationError = ref.watch(
      propertyQueryProvider(_feed).select((page) => page.error is LocationException),
    );
    if (!located) {
      if (loadFailed || locationError) return const PropertyLocationRecovery(pageType: _page);
      return Stack(
        children: [
          Positioned.fill(child: ColoredBox(color: context.design.surface)),
          LoadingStates.mapLoadingOverlay(context),
        ],
      );
    }
    return Stack(
      children: [
        Positioned.fill(
          child: Semantics(
            label: context.l10n.text('explore'),
            identifier: 'qa.explore.map',
            child: const ExploreMap(),
          ),
        ),
        // The page's hand-cut edge over the top of the map: the map is a
        // print laid under the sky.
        const Positioned(top: 0, left: 0, right: 0, height: kPaperLip, child: _SkyEdge()),
        // The search slip floats over the top of the map with the map
        // controls beside it on a wide map, or in one row under it on a
        // phone, so a short map (320 px, 2x text, a banner) keeps them clear
        // of the list sheet. Gaps pass touches to the map.
        Positioned(
          top: 8,
          left: 16 + MediaQuery.paddingOf(context).left,
          right: 16 + MediaQuery.paddingOf(context).right,
          child: const _MapTop(),
        ),
        const _LoadingMore(),
        _ListSheet(onOpen: onOpen, openId: openId),
      ],
    );
  }
}

/// The search slip and the map controls over the top of the map.
class _MapTop extends StatelessWidget {
  const _MapTop();

  @override
  Widget build(BuildContext context) {
    const search = PaperSheet(
      seed: 'explore-search',
      elevation: PaperElevation.low,
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: PropertySearchField(pageType: _page, bare: true),
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= 600
          ? const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: search),
                SizedBox(width: 12),
                _MapControls(),
              ],
            )
          : const Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [search, SizedBox(height: 10), _MapControls()],
            ),
    );
  }
}

/// Zoom, my location and show-all on one paper slip, in a row. Bare icons.
class _MapControls extends ConsumerWidget {
  const _MapControls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(exploreProvider.notifier);
    final ink = context.design.textPrimary;
    const target = BoxConstraints(minHeight: 48, minWidth: 48);
    return PaperSheet(
      seed: 'explore-controls',
      elevation: PaperElevation.low,
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: PaperIcon(KnifeIcon.plus, color: ink),
            tooltip: context.l10n.text('zoom_in'),
            onPressed: controller.zoomIn,
            constraints: target,
          ),
          IconButton(
            icon: PaperIcon(KnifeIcon.minus, color: ink),
            tooltip: context.l10n.text('zoom_out'),
            onPressed: controller.zoomOut,
            constraints: target,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: PaperIcon(KnifeIcon.locate, color: context.design.accent),
            tooltip: context.l10n.text('my_location'),
            onPressed: controller.recenterToCurrentLocation,
            constraints: target,
          ),
          IconButton(
            icon: PaperIcon(KnifeIcon.map, color: ink),
            tooltip: context.l10n.text('fit_map_to_properties'),
            onPressed: controller.fitBoundsToProperties,
            constraints: target,
          ),
        ],
      ),
    );
  }
}

/// The search radius, quiet beside the count on the list handle.
class _RadiusNote extends ConsumerWidget {
  const _RadiusNote();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final radius = ref.watch(
      propertyFiltersProvider.select((state) => state.forPage(_page).radiusKm ?? 10),
    );
    return Text(
      context.l10n.text(
        'radius_km',
        // 10 km, 12.5 km: no trailing ".0".
        params: {'km': radius.clamp(5, 50).toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '')},
      ),
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.design.textSecondary),
    );
  }
}

class _LoadingMore extends ConsumerWidget {
  const _LoadingMore();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loadingMore = ref.watch(
      propertyQueryProvider(_feed).select((page) => page.isLoadingMore),
    );
    final collapsed = ref.watch(exploreProvider.select((state) => state.collapsed));
    return Positioned(
      bottom: (collapsed ? 0 : PropertyHorizontalList.height(context)) + 64,
      left: 16,
      right: 16,
      child: !loadingMore
          ? const SizedBox.shrink()
          : Center(
              child: PaperSheet(
                seed: 'explore-more',
                elevation: PaperElevation.low,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LoadingStates.buttonSpinner(size: 16, color: context.design.textSecondary),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        context.l10n.text('loading_more_properties'),
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// The paper sheet of homes over the map. Its sides and bottom sit just past
/// the edges, so only the cut top edge shows. Tap or drag the handle to fold it.
class _ListSheet extends ConsumerWidget {
  const _ListSheet({this.onOpen, this.openId});

  final ValueChanged<PropertyModel>? onOpen;
  final int? openId;

  static const double _bleed = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collapsed = ref.watch(exploreProvider.select((state) => state.collapsed));
    final (count, empty) = ref.watch(
      propertyQueryProvider(
        _feed,
      ).select((page) => (page.items.length, page.phase == PropertyLoadPhase.empty)),
    );
    final controller = ref.read(exploreProvider.notifier);
    final design = context.design;
    final l10n = context.l10n;
    return AnimatedPositioned(
      duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : AppDurations.normal,
      curve: AppCurves.standard,
      left: -_bleed,
      right: -_bleed,
      bottom: (collapsed && !empty ? -PropertyHorizontalList.height(context) : 0) - _bleed,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: design.surface,
          shape: CutBorder(
            seed: 'explore-list',
            amp: 3,
            shadows: paperShadows(PaperElevation.mid, design.shadowOn(design.background)),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(_bleed, _bleed, _bleed, _bleed),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: controller.toggleListCollapsed,
                  onVerticalDragEnd: (details) {
                    final velocity = details.primaryVelocity ?? 0;
                    if (velocity < -200) controller.expandList();
                    if (velocity > 200) controller.collapseList();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Semantics(
                    label: l10n.text(collapsed ? 'expand_property_list' : 'collapse_property_list'),
                    button: true,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        // The count, the radius in quiet type, the fold mark.
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 10,
                          runSpacing: 2,
                          children: [
                            Text(
                              '$count ${l10n.text(count == 1 ? 'property' : 'properties')}',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const _RadiusNote(),
                            PaperIcon(
                              collapsed ? KnifeIcon.chevronUp : KnifeIcon.chevronDown,
                              size: 18,
                              color: design.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (empty)
                  const _EmptyArea()
                else
                  PropertyHorizontalList(onOpen: onOpen, openId: openId),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Nothing in this area. It takes the place of the list, so the map stays
/// clear and the controls stay whole; one way forward.
class _EmptyArea extends StatelessWidget {
  const _EmptyArea();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final words = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.text('no_properties_found'), style: text.titleMedium),
        const SizedBox(height: 4),
        Text(
          l10n.text('no_properties_found_area_message'),
          style: text.bodyMedium?.copyWith(color: context.design.textSecondary),
        ),
        const SizedBox(height: 12),
        Semantics(
          identifier: 'qa.explore.empty.action',
          child: FilledButton(
            key: const ValueKey('qa.explore.empty.action'),
            onPressed: () => showPropertyFilterBottomSheet(context, pageType: _page),
            child: Text(l10n.text('adjust_filters')),
          ),
        ),
      ],
    );
    // No taller than the list it replaces, so the sheet never climbs over the
    // map controls. The scene sits beside the words when there is room.
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: PropertyHorizontalList.height(context)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
            if (constraints.maxWidth / scale < 340) return words;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PaperVignette(PaperScene.empty, seed: 'explore', width: 128),
                const SizedBox(width: 16),
                Expanded(child: words),
              ],
            );
          },
        ),
      ),
    );
  }
}
