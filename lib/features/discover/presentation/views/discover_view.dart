import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:ghar360/core/controllers/page_state_service.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/utils/app_spacing.dart';
import 'package:ghar360/core/utils/error_mapper.dart';
import 'package:ghar360/core/utils/responsive.dart';
import 'package:ghar360/core/widgets/common/error_states.dart';
import 'package:ghar360/core/widgets/common/loading_states.dart';
import 'package:ghar360/core/widgets/common/property_filter_widget.dart';
import 'package:ghar360/core/widgets/common/unified_top_bar.dart';
import 'package:ghar360/features/discover/presentation/controllers/discover_controller.dart';
import 'package:ghar360/features/discover/presentation/widgets/property_swipe_stack.dart';

class DiscoverView extends GetView<DiscoverController> {
  const DiscoverView({super.key});

  @override
  Widget build(BuildContext context) {
    final pageStateService = Get.find<PageStateService>();

    return Semantics(
      label: 'qa.discover.screen',
      identifier: 'qa.discover.screen',
      child: Scaffold(
        key: const ValueKey('qa.discover.screen'),
        backgroundColor: AppDesign.scaffoldBackground,
        appBar: DiscoverTopBar(
          onFilterTap: () => showPropertyFilterBottomSheet(context, pageType: 'discover'),
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              // Subtle refresh indicator (reactive only)
              Obx(() {
                final isRefreshing = pageStateService.discoverState.value.isRefreshing;
                if (!isRefreshing) return const SizedBox.shrink();
                return const LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: AppDesign.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(AppDesign.primaryYellow),
                );
              }),
              // Main content (reacts only to state)
              Expanded(
                child: Obx(() {
                  final Widget child;
                  final Key key;
                  switch (controller.state.value) {
                    case DiscoverState.loading:
                      key = const ValueKey('loading');
                      child = _buildLoadingState();
                    case DiscoverState.error:
                      key = const ValueKey('error');
                      child = _buildErrorState();
                    case DiscoverState.empty:
                      key = const ValueKey('empty');
                      child = _buildEmptyState(context);
                    case DiscoverState.loaded:
                    case DiscoverState.prefetching:
                      key = const ValueKey('loaded');
                      child = _buildSwipeInterface(context);
                    default:
                      key = const ValueKey('loading');
                      child = _buildLoadingState();
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
  }

  Widget _buildLoadingState() {
    return Column(
      children: [
        // Contextual loading message so users know what's happening when
        // location acquisition takes time (previously a bare skeleton with
        // no explanation, which could look like the app was stuck).
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Column(
            children: [
              Icon(
                Icons.travel_explore_rounded,
                size: 28,
                color: AppDesign.primaryYellow.withValues(alpha: 0.8),
              ),
              const SizedBox(height: 8),
              Text(
                'discovering_properties_message'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppDesign.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'finding_nearby_properties_hint'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppDesign.textSecondary),
              ),
            ],
          ),
        ),

        // Show loading progress if available
        Obx(() {
          if (controller.isPrefetching.value) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppDesign.primaryYellow),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'loading_more_properties'.tr,
                    style: TextStyle(fontSize: 14, color: AppDesign.textSecondary),
                  ),
                ],
              ),
            );
          }
          return const SizedBox();
        }),

        // Main loading
        Expanded(child: LoadingStates.swipeCardSkeleton()),
      ],
    );
  }

  Widget _buildErrorState() {
    return Obx(() {
      final errorMessage = controller.error.value;
      if (errorMessage == null) return const SizedBox();

      // Try to map the error for better user experience
      try {
        // Don't wrap in Exception() - pass the original error message directly
        final exception = ErrorMapper.mapApiError(errorMessage);
        return ErrorStates.genericError(error: exception, onRetry: controller.retryLoading);
      } catch (e) {
        return ErrorStates.networkError(
          onRetry: controller.retryLoading,
          customMessage: errorMessage.toString(),
        );
      }
    });
  }

  Widget _buildEmptyState(BuildContext context) {
    return ErrorStates.swipeDeckEmpty(
      onRefresh: controller.refreshDeck,
      onChangeFilters: () =>
          showPropertyFilterBottomSheet(Get.context ?? context, pageType: 'discover'),
    );
  }

  Widget _buildSwipeInterface(BuildContext context) {
    // Phone: cardMaxWidth is double.infinity → no cap, identical to before.
    // Medium+ (tablet/iPad): cap and center so cards stay a comfortable width.
    final cardMaxWidth = responsiveValue<double>(
      context,
      compact: double.infinity,
      medium: 520,
      expanded: 520,
      large: 520,
      fallback: 520,
    );

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: cardMaxWidth),
                child: Obx(
                  () => Semantics(
                    label: 'qa.discover.swipe_stack',
                    identifier: 'qa.discover.swipe_stack',
                    child: PropertySwipeStack(
                      key: const ValueKey('qa.discover.swipe_stack'),
                      properties: controller.deck
                          .skip(controller.currentIndex.value)
                          .take(3)
                          .toList(),
                      onSwipeLeft: controller.swipeLeft,
                      onSwipeRight: controller.swipeRight,
                      onSwipeUp: (property) => controller.viewPropertyDetails(property),
                      onRefresh: controller.refreshDeck,
                      onChangeFilters: () => showPropertyFilterBottomSheet(
                        Get.context ?? context,
                        pageType: 'discover',
                      ),
                      showSwipeInstructions: controller.totalSwipesInSession.value < 3,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
