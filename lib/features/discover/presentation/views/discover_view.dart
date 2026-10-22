import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/design/paper/paper_art.dart';
import 'package:ghar360/core/design/paper/paper_chrome.dart';
import 'package:ghar360/core/design/paper/paper_scene_data.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/core/routes/route_policy.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/utils/app_spacing.dart';
import 'package:ghar360/core/utils/app_toast.dart';
import 'package:ghar360/core/utils/responsive.dart';
import 'package:ghar360/core/widgets/common/error_states.dart';
import 'package:ghar360/core/widgets/common/inline_retry_banner.dart';
import 'package:ghar360/core/widgets/common/loading_states.dart';
import 'package:ghar360/core/widgets/common/out_of_area_note.dart';
import 'package:ghar360/core/widgets/common/property_filter_widget.dart';
import 'package:ghar360/core/widgets/common/property_location_recovery.dart';
import 'package:ghar360/core/widgets/common/property_recovery_banner.dart';
import 'package:ghar360/core/widgets/common/sign_in_gate.dart';
import 'package:ghar360/core/widgets/common/unified_top_bar.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';
import 'package:ghar360/features/discover/presentation/controllers/discover_controller.dart';
import 'package:ghar360/features/discover/presentation/widgets/property_swipe_stack.dart';
import 'package:ghar360/features/location/presentation/widgets/location_explainer.dart';
import 'package:ghar360/features/properties/application/property_location.dart';
import 'package:ghar360/features/properties/application/property_queries.dart';
import 'package:ghar360/features/properties/application/swipe_history.dart';
import 'package:go_router/go_router.dart';

class DiscoverView extends ConsumerWidget {
  const DiscoverView({super.key});

  static void _filters(BuildContext context) =>
      showPropertyFilterBottomSheet(context, pageType: PageType.discover);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(swipeHistoryProvider.select((history) => history.failures), (previous, next) {
      if (next.isNotEmpty && next != previous) {
        AppToast.error(context.l10n.text('error'), context.l10n.text('swipe_save_failed'));
      }
    });
    // The frame watches nothing: each part below watches only what it draws,
    // so a swipe rebuilds the deck and not the whole screen.
    return LocationExplainerGate(
      child: Semantics(
        label: context.l10n.text('discover'),
        identifier: 'qa.discover.screen',
        child: Scaffold(
          key: const ValueKey('qa.discover.screen'),
          backgroundColor: context.design.background,
          appBar: DiscoverTopBar(
            onFilterTap: () => _filters(context),
            additionalActions: [
              Consumer(
                builder: (context, ref, _) => ref.watch(guestProvider)
                    // A guest has no Assistant: the slot offers sign-in.
                    ? TextButton(
                        key: const ValueKey('qa.discover.sign_in'),
                        onPressed: () =>
                            context.push(routeWithReturn(AppRoutes.phoneEntry, AppRoutes.discover)),
                        child: Text(context.l10n.text('sign_in')),
                      )
                    // The Assistant's mark is the onboarding kite: bare, no box.
                    : TextButton.icon(
                        key: const ValueKey('qa.discover.assistant'),
                        onPressed: () => context.push(AppRoutes.assistant),
                        icon: PaperIcon(KnifeIcon.kite, size: 22, color: context.design.accent),
                        label: Text(context.l10n.text('assistant')),
                      ),
              ),
            ],
          ),
          // The deck stands in front of the city: the far towers and the
          // sector blocks rise from the foot of the page behind the cards.
          body: Stack(
            children: [
              const Positioned.fill(child: PageGrain()),
              // When the shell lays the body under its roofline, the lawn
              // runs on behind it.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 200 + MediaQuery.paddingOf(context).bottom,
                child: const _City(),
              ),
              const SafeArea(
                top: false,
                child: Column(
                  children: [
                    _RefreshBar(),
                    OutOfAreaNote(pageType: PageType.discover),
                    _DiscoverBanners(),
                    PropertyRecoveryBanner(feed: PropertyFeed.discover),
                    Expanded(child: _DiscoverBody()),
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

const _feed = PropertyFeed.discover;

final guestProvider = Provider<bool>(
  (ref) => ref.watch(storageScopeProvider.select((scope) => scope.accountId == null)),
);

/// The far towers, sector blocks and lawn of the city, standing at the foot
/// of the page behind the deck. Painted once at the full height of the box;
/// a wide box shows more of the street. No clouds, so nothing floats in the
/// gutters.
class _City extends StatelessWidget {
  const _City();

  static final _art = () {
    final art = paperHeaders['skyline']!;
    return PaperArtData(
      width: art.width,
      height: art.height,
      shadow: art.shadow,
      layers: [
        for (final layer in art.layers)
          if (layer.id != 'clouds') layer,
      ],
    );
  }();

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(child: CustomPaint(painter: _CityPainter(context.design))),
  );
}

class _CityPainter extends CustomPainter {
  const _CityPainter(this.design);

  final AppPalette design;

  @override
  void paint(Canvas canvas, Size size) {
    final art = _City._art;
    final scale = size.height / art.height;
    canvas
      ..save()
      ..clipRect(Offset.zero & size)
      ..translate((size.width - art.width * scale) / 2, 0)
      ..scale(scale);
    paintPaperArt(canvas, art.size, art, design.inks);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CityPainter old) => old.design.isDark != design.isDark;
}

class _RefreshBar extends ConsumerWidget {
  const _RefreshBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final refreshing = ref.watch(propertyQueryProvider(_feed).select((page) => page.isRefreshing));
    return SizedBox(
      height: 2,
      child: refreshing ? const LinearProgressIndicator(minHeight: 2) : null,
    );
  }
}

class _DiscoverBanners extends ConsumerWidget {
  const _DiscoverBanners();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasCards = ref.watch(visiblePropertiesProvider(_feed).select((deck) => deck.isNotEmpty));
    final locationBusy = ref.watch(
      propertyLocationProvider(
        PageType.discover,
      ).select((location) => location.load.hasError || location.load.isLoading),
    );
    final (paginationError, error, busy) = ref.watch(
      propertyQueryProvider(_feed).select(
        (page) => (page.paginationError, page.error, page.isLoadingMore || page.isRefreshing),
      ),
    );
    final failed = paginationError ?? (hasCards && error is! LocationException ? error : null);
    return Column(
      children: [
        if (hasCards && locationBusy)
          const PropertyLocationRecovery(pageType: PageType.discover, inline: true),
        if (failed != null)
          InlineRetryBanner(
            message: context.l10n.text(
              paginationError != null ? 'load_more_failed' : 'refresh_content_failed',
            ),
            error: failed,
            isLoading: busy,
            identifier: 'qa.discover.content.retry',
            onRetry: () {
              final query = ref.read(propertyQueryProvider(_feed).notifier);
              if (paginationError != null) {
                query.loadMore(retry: true);
              } else {
                query.load(refresh: true);
              }
            },
          ),
      ],
    );
  }
}

class _DiscoverBody extends ConsumerWidget {
  const _DiscoverBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only the top three cards are drawn; changes further down the deck do
    // not rebuild this.
    final (top, second, third, empty) = ref.watch(
      visiblePropertiesProvider(_feed).select(
        (deck) => (
          deck.isNotEmpty ? deck[0] : null,
          deck.length > 1 ? deck[1] : null,
          deck.length > 2 ? deck[2] : null,
          deck.isEmpty,
        ),
      ),
    );
    final (isLoading, isLoadingMore, idle, showFullError, error) = ref.watch(
      propertyQueryProvider(_feed).select(
        (page) => (
          page.isLoading,
          page.isLoadingMore,
          page.phase == PropertyLoadPhase.idle,
          page.showFullError,
          page.error,
        ),
      ),
    );
    final (noLocation, locationFailed) = ref.watch(
      propertyLocationProvider(
        PageType.discover,
      ).select((location) => (location.location == null, location.load.hasError)),
    );
    final hydrated = ref.watch(swipeHistoryProvider.select((history) => history.hydrated));
    final controller = ref.read(discoverProvider.notifier);
    final loading = !hydrated || (empty && (isLoading || isLoadingMore || idle));
    if (empty && noLocation && (locationFailed || error is LocationException)) {
      return const PropertyLocationRecovery(pageType: PageType.discover);
    }
    if (loading) return LoadingStates.swipeCardSkeleton();
    if (showFullError && empty) {
      return ErrorStates.genericError(
        error: error!,
        onRetry: controller.retryLoading,
        seed: 'discover',
      );
    }
    if (empty) {
      return ErrorStates.swipeDeckEmpty(
        onRefresh: controller.refreshDeck,
        onChangeFilters: () => DiscoverView._filters(context),
      );
    }
    final cards = [top!, ?second, ?third];
    final design = context.design;
    // Both buttons are paper on the page: the same shape, the same short
    // shadow. Pass is a white sheet with a brick mark; Like is the marigold.
    Widget lifted(Widget button) => DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppBorderRadius.button),
        boxShadow: paperShadows(PaperElevation.low, design.shadowOn(design.background)),
      ),
      child: button,
    );
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          // The turned sheets under the top card reach about 10 px into the
          // gutters and the gap above the buttons.
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            // On a wide, tall window the deck stops at a sane card shape and
            // the deck with its buttons sits in the middle of the page.
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: LayoutBuilder(
                  builder: (context, box) => ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: context.windowSizeClass == WindowSizeClass.compact
                          ? double.infinity
                          : box.maxWidth * 1.5,
                    ),
                    child: Semantics(
                      identifier: 'qa.discover.swipe_stack',
                      label: context.l10n.text('discover'),
                      child: PropertySwipeStack(
                        key: const ValueKey('qa.discover.swipe_stack'),
                        properties: cards,
                        onSwipeLeft: controller.swipeLeft,
                        onSwipeRight: controller.swipeRight,
                        onSwipeUp: (property) =>
                            context.push(AppRoutes.detailsFor(property.id), extra: property),
                        isLoadingMore: isLoadingMore,
                        canSwipe: (property, isRight) {
                          if (!ref
                              .read(visiblePropertiesProvider(_feed))
                              .any((item) => item.id == property.id)) {
                            return false;
                          }
                          // A guest may pass but not like: the card snaps back.
                          if (isRight && ref.read(guestProvider)) {
                            unawaited(requireAccount(context, ref));
                            return false;
                          }
                          return true;
                        },
                        onRefresh: controller.refreshDeck,
                        onChangeFilters: () => DiscoverView._filters(context),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              // Both buttons keep one height when a label wraps.
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: lifted(
                        FilledButton.icon(
                          key: const ValueKey('qa.discover.action.pass'),
                          style: ButtonStyle(
                            minimumSize: const WidgetStatePropertyAll(Size(48, 52)),
                            backgroundColor: WidgetStateProperty.resolveWith(
                              (states) =>
                                  states.contains(WidgetState.pressed) ||
                                      states.contains(WidgetState.hovered)
                                  ? design.tabBehind
                                  : design.surface,
                            ),
                            foregroundColor: WidgetStatePropertyAll(design.textPrimary),
                          ),
                          onPressed: () => controller.swipeLeft(top),
                          icon: PaperIcon(KnifeIcon.close, size: 20, color: design.favoriteActive),
                          label: Text(context.l10n.text('pass')),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: lifted(
                        FilledButton.icon(
                          key: const ValueKey('qa.discover.action.like'),
                          style: FilledButton.styleFrom(minimumSize: const Size(48, 52)),
                          onPressed: () async {
                            if (await requireAccount(context, ref)) controller.swipeRight(top);
                          },
                          icon: const PaperIcon(KnifeIcon.heart, size: 20),
                          label: Text(context.l10n.text('like')),
                        ),
                      ),
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
