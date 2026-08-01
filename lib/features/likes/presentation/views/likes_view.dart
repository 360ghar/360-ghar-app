import 'package:flutter/material.dart';

import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';

import 'package:ghar360/core/controllers/page_state_service.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/utils/app_spacing.dart';
import 'package:ghar360/core/utils/error_mapper.dart';
import 'package:ghar360/core/widgets/common/error_states.dart';
import 'package:ghar360/core/widgets/common/loading_states.dart';
import 'package:ghar360/core/widgets/common/paginated_scroll_mixin.dart';
import 'package:ghar360/core/widgets/common/property_filter_widget.dart';
import 'package:ghar360/core/widgets/common/segmented_control.dart';
import 'package:ghar360/core/widgets/common/unified_top_bar.dart';
import 'package:ghar360/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:ghar360/features/likes/presentation/controllers/likes_controller.dart';
import 'package:ghar360/features/likes/presentation/widgets/likes_property_card.dart';

class LikesView extends GetView<LikesController> {
  const LikesView({super.key});

  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) return 2;
    if (width < 900) return 3;
    return 4;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final pageStateService = Get.find<PageStateService>();

    return Obx(() {
      // Observed (not used) so the Scaffold re-reads LikesTopBar.preferredSize
      // when the search field is shown or hidden — the app bar grows by 52px.
      // It must NOT re-key the Scaffold: that threw away the grid's scroll
      // position and every element below it on each toggle.
      pageStateService.isSearchVisible(PageType.likes);
      return Scaffold(
        backgroundColor: AppDesign.scaffoldBackground,
        appBar: LikesTopBar(
          onSearchChanged: controller.updateSearchQuery,
          onFilterTap: () => showPropertyFilterBottomSheet(context, pageType: 'likes'),
        ),
        body: SafeArea(
          top: false,
          child: Semantics(
            label: 'liked'.tr,
            identifier: 'qa.likes.screen',
            child: Column(
              children: [
                Obx(() {
                  if (!pageStateService.likesState.value.isRefreshing) {
                    return const SizedBox.shrink();
                  }
                  return LinearProgressIndicator(
                    minHeight: 2,
                    backgroundColor: AppDesign.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                  );
                }),
                Container(
                  color: AppDesign.appBarBackground,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenPadding,
                    AppSpacing.sm,
                    AppSpacing.screenPadding,
                    AppSpacing.md,
                  ),
                  child: Obx(
                    () => SegmentedControl(
                      selectedIndex: controller.currentSegment.value == LikesSegment.liked ? 0 : 1,
                      segments: [
                        SegmentItem(
                          label: 'liked'.tr,
                          badge:
                              controller.currentSegment.value == LikesSegment.liked &&
                                  controller.hasCurrentProperties
                              ? controller.currentProperties.length
                              : null,
                          semanticsLabel: 'qa.likes.tab.liked',
                          semanticsIdentifier: 'qa.likes.tab.liked',
                        ),
                        SegmentItem(
                          label: 'passed'.tr,
                          badge:
                              controller.currentSegment.value == LikesSegment.passed &&
                                  controller.hasCurrentProperties
                              ? controller.currentProperties.length
                              : null,
                          semanticsLabel: 'qa.likes.tab.passed',
                          semanticsIdentifier: 'qa.likes.tab.passed',
                        ),
                      ],
                      onSegmentChanged: (index) {
                        final segment = index == 0 ? LikesSegment.liked : LikesSegment.passed;
                        controller.switchToSegment(segment);
                      },
                    ),
                  ),
                ),
                Expanded(
                  child: Obx(() {
                    final Widget child;
                    final Key key;

                    if (controller.isCurrentLoading) {
                      key = const ValueKey('loading');
                      child = _buildResponsiveGridSkeleton(context);
                    } else if (controller.hasCurrentError) {
                      key = const ValueKey('error');
                      child = _buildErrorState();
                    } else if (controller.isCurrentEmpty) {
                      key = const ValueKey('empty');
                      final isLiked = controller.currentSegment.value == LikesSegment.liked;
                      child = _buildEmptyState(isLiked);
                    } else {
                      key = const ValueKey('grid');
                      child = _LikesPropertyGrid(
                        controller: controller,
                        crossAxisCount: _getCrossAxisCount(context),
                      );
                    }

                    return AnimatedSwitcher(
                      duration: AppDurations.contentFade,
                      transitionBuilder: (child, animation) =>
                          FadeTransition(opacity: animation, child: child),
                      child: KeyedSubtree(key: key, child: child),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildResponsiveGridSkeleton(BuildContext context) {
    final crossAxisCount = _getCrossAxisCount(context);
    return LoadingStates.responsiveGridSkeleton(
      crossAxisCount: crossAxisCount,
      itemCount: crossAxisCount * 2,
    );
  }

  Widget _buildErrorState() {
    return Obx(() {
      final errorMessage = controller.currentError;
      if (errorMessage == null) return const SizedBox();

      try {
        final exception = ErrorMapper.mapApiError(errorMessage);
        return ErrorStates.genericError(error: exception, onRetry: controller.retryCurrentSegment);
      } catch (e) {
        return ErrorStates.networkError(
          onRetry: controller.retryCurrentSegment,
          customMessage: errorMessage,
        );
      }
    });
  }

  Widget _buildEmptyState(bool isLiked) {
    if (controller.hasSearchQuery) {
      return ErrorStates.searchEmpty(
        searchQuery: controller.searchQuery.value,
        onClearSearch: controller.clearSearch,
      );
    }

    return ErrorStates.emptyState(
      title: isLiked ? 'no_liked_properties'.tr : 'no_passed_properties'.tr,
      message: controller.emptyStateMessage,
      icon: isLiked ? Icons.favorite_border : Icons.not_interested,
      onAction: () => Get.find<DashboardController>().changeTab(DashboardController.discoverTab),
      actionText: 'explore_properties'.tr,
    );
  }
}

/// The scrollable property grid.
///
/// Stateful so pagination can be driven from a scroll listener
/// ([PaginatedScrollMixin]) instead of from the sliver's `itemBuilder`:
/// `loadMoreCurrentSegment` writes the likes page state synchronously, and
/// calling it while the sliver is building marked the enclosing `Obx` dirty
/// mid-build.
class _LikesPropertyGrid extends StatefulWidget {
  const _LikesPropertyGrid({required this.controller, required this.crossAxisCount});

  final LikesController controller;
  final int crossAxisCount;

  @override
  State<_LikesPropertyGrid> createState() => _LikesPropertyGridState();
}

class _LikesPropertyGridState extends State<_LikesPropertyGrid>
    with PaginatedScrollMixin<_LikesPropertyGrid> {
  @override
  void initState() {
    super.initState();
    // Note: scroll-driven only — a first page shorter than the viewport
    // produces no scroll events and will not auto-advance. Add a post-frame
    // bootstrap inside the mixin (so it shares the in-flight guard) if a
    // short first page ever happens in practice.
    initPaginatedScroll(
      onLoadMore: widget.controller.loadMoreCurrentSegment,
      hasMore: () => widget.controller.currentHasMore,
      isLoadingMore: () => widget.controller.isCurrentLoadingMore,
    );
  }

  void _handleFavoriteToggle(PropertyModel property, bool isCurrentlyLiked) {
    if (isCurrentlyLiked) {
      widget.controller.removeFromLikes(property);
    } else {
      widget.controller.moveToLikes(property);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    return RefreshIndicator(
      onRefresh: controller.refreshCurrentSegment,
      color: Theme.of(context).colorScheme.primary,
      child: CustomScrollView(
        controller: scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: Obx(() {
              if (!controller.hasSearchQuery) return const SizedBox.shrink();
              return Container(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  AppSpacing.md,
                  AppSpacing.screenPadding,
                  0,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppDesign.primaryYellow.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'filtered'.tr,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppDesign.primaryYellow,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
          Obx(() {
            final properties = controller.currentProperties;
            final isLiked = controller.currentSegment.value == LikesSegment.liked;
            final hasTrailingCell = controller.currentHasMore || controller.isCurrentLoadingMore;

            return SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
              sliver: SliverMasonryGrid.count(
                crossAxisCount: widget.crossAxisCount,
                mainAxisSpacing: AppSpacing.listItemSpacing,
                crossAxisSpacing: AppSpacing.listItemSpacing,
                childCount: properties.length + (hasTrailingCell ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == properties.length) {
                    return controller.isCurrentLoadingMore
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        : const SizedBox();
                  }

                  final property = properties[index];

                  return LikesPropertyCard(
                    property: property,
                    isFavourite: controller.isFavourite(property),
                    isUpdating: controller.isFavouriteUpdating(property),
                    onFavouriteToggle: () => _handleFavoriteToggle(property, isLiked),
                  );
                },
              ),
            );
          }),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}
