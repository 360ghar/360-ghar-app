import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:ghar360/core/controllers/page_state_service.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/app_design_tokens.dart';
import 'package:ghar360/core/utils/app_spacing.dart';
import 'package:ghar360/core/utils/responsive.dart';
import 'package:ghar360/core/widgets/common/error_states.dart';
import 'package:ghar360/core/widgets/common/loading_states.dart';
import 'package:ghar360/core/widgets/common/property_filter_widget.dart';
import 'package:ghar360/core/widgets/common/unified_top_bar.dart';
import 'package:ghar360/features/explore/presentation/controllers/explore_controller.dart';
import 'package:ghar360/features/explore/presentation/widgets/explore_map.dart';
import 'package:ghar360/features/explore/presentation/widgets/property_horizontal_list.dart';

class ExploreView extends GetView<ExploreController> {
  const ExploreView({super.key});

  // Side panel width for the two-pane (expanded/large) layout.
  static const double _sidePanelWidth = 360.0;

  @override
  Widget build(BuildContext context) {
    final pageStateService = Get.find<PageStateService>();

    // Wrap in Obx to rebuild Scaffold when search visibility changes
    return Obx(() {
      final searchVisible = pageStateService.isSearchVisible(PageType.explore);
      return Scaffold(
        key: ValueKey('explore_scaffold_$searchVisible'),
        backgroundColor: AppDesign.scaffoldBackground,
        appBar: ExploreTopBar(
          onSearchChanged: (query) => controller.updateSearchQuery(query),
          onFilterTap: () => showPropertyFilterBottomSheet(context, pageType: 'explore'),
        ),
        body: Semantics(
          label: 'qa.explore.screen',
          identifier: 'qa.explore.screen',
          child: Column(
            children: [
              // Subtle refresh indicator (reactive only)
              Obx(() {
                final isRefreshing = pageStateService.exploreState.value.isRefreshing;
                if (!isRefreshing) return const SizedBox.shrink();
                return const LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: AppDesign.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(AppDesign.primaryYellow),
                );
              }),
              // Main content (reactive state switch with smooth fade)
              Expanded(
                child: Obx(() {
                  final currentState = controller.state.value;
                  final Widget child;
                  final Key key;

                  switch (currentState) {
                    case ExploreState.loading:
                      final hasLocation = pageStateService.exploreState.value.hasLocation;
                      if (hasLocation) {
                        key = const ValueKey('map');
                        child = _buildMapInterface(context);
                      } else {
                        key = const ValueKey('loading');
                        child = _buildLoadingState(context);
                      }

                    case ExploreState.error:
                      key = const ValueKey('error');
                      child = _buildErrorState();

                    case ExploreState.empty:
                      key = const ValueKey('empty');
                      child = _buildEmptyState(context);

                    case ExploreState.loaded:
                    case ExploreState.loadingMore:
                      key = const ValueKey('map');
                      child = _buildMapInterface(context);

                    default:
                      final hasLocation = pageStateService.exploreState.value.hasLocation;
                      if (hasLocation) {
                        key = const ValueKey('map');
                        child = _buildMapInterface(context);
                      } else {
                        key = const ValueKey('loading');
                        child = _buildLoadingState(context);
                      }
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
      );
    });
  }

  Widget _buildLoadingState(BuildContext context) {
    return Stack(
      children: [
        // Skeleton map
        Container(
          color: AppDesign.surface,
          child: Center(child: Icon(Icons.map, size: 100, color: AppDesign.divider)),
        ),

        // Loading overlay
        LoadingStates.mapLoadingOverlay(context),
      ],
    );
  }

  Widget _buildErrorState() {
    return Obx(() {
      final appException = controller.error.value;
      if (appException == null) return const SizedBox();

      return ErrorStates.genericError(error: appException, onRetry: controller.retryLoading);
    });
  }

  Widget _buildEmptyState(BuildContext context) {
    return ErrorStates.emptyState(
      title: 'no_properties_found'.tr,
      message: 'no_properties_found_area_message'.tr,
      icon: Icons.location_off,
      onAction: () => showPropertyFilterBottomSheet(Get.context ?? context, pageType: 'explore'),
      actionText: 'adjust_filters'.tr,
    );
  }

  /// Branches between the single-pane phone layout (compact/medium) and the
  /// two-pane tablet layout (expanded/large).
  Widget _buildMapInterface(BuildContext context) {
    final sizeClass = context.windowSizeClass;
    final isTwoPane = sizeClass == WindowSizeClass.expanded || sizeClass == WindowSizeClass.large;

    if (isTwoPane) {
      return _buildTwoPaneMapInterface(context);
    }
    return _buildSinglePaneMapInterface(context);
  }

  // ---------------------------------------------------------------------------
  // Single-pane layout (compact / medium) — phone, visually unchanged.
  // ---------------------------------------------------------------------------
  Widget _buildSinglePaneMapInterface(BuildContext context) {
    return Stack(
      children: [
        // Main map (MapLibre + OpenFreeMap Liberty vector tiles)
        Positioned.fill(
          child: Semantics(
            label: 'qa.explore.map',
            identifier: 'qa.explore.map',
            child: ExploreMap(controller: controller),
          ),
        ),
        // Map controls
        Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          right: 16,
          child: _buildMapControls(context),
        ),
        // Info panel
        Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          left: 16,
          child: _buildInfoPanel(context),
        ),
        // Loading indicator for more properties (position reacts to collapse)
        if (controller.state.value == ExploreState.loadingMore)
          Obx(() {
            final indicatorBottom = controller.isListCollapsed.value ? 58.0 : 230.0;
            return Positioned(
              bottom: indicatorBottom,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color:
                      (Theme.of(context).brightness == Brightness.dark
                              ? AppDesignTokens.darkSurfaceAlt
                              : AppDesignTokens.warmCream)
                          .withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(AppBorderRadius.sm),
                  border: Border.all(color: AppDesignTokens.neutral300, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        valueColor: AlwaysStoppedAnimation<Color>(AppDesignTokens.brandGold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'loading_more_properties'.tr,
                      style: const TextStyle(fontSize: 12, color: AppDesignTokens.neutral500),
                    ),
                  ],
                ),
              ),
            );
          }),
        // Collapsible horizontal property list at bottom
        Obx(() {
          final collapsed = controller.isListCollapsed.value;
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final panelBg = (isDark ? AppDesignTokens.darkSurfaceAlt : AppDesignTokens.warmCream)
              .withValues(alpha: 0.95);
          final borderColor = isDark ? AppDesignTokens.darkBorder : AppDesignTokens.neutral300;
          final handleBarColor = isDark ? AppDesignTokens.darkBorder : AppDesignTokens.neutral300;
          final textColor = isDark ? AppDesignTokens.darkTextSecondary : AppDesignTokens.neutral500;
          final iconColor = isDark ? AppDesignTokens.darkTextTertiary : AppDesignTokens.neutral500;

          return AnimatedPositioned(
            duration: AppDurations.normal,
            curve: AppCurves.standard,
            left: 0,
            right: 0,
            bottom: collapsed ? -220.0 : 0.0,
            child: SafeArea(
              top: false,
              child: Container(
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  color: panelBg,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppBorderRadius.lg),
                  ),
                  border: Border(
                    top: BorderSide(color: borderColor, width: 1),
                    left: BorderSide(color: borderColor, width: 1),
                    right: BorderSide(color: borderColor, width: 1),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle area — inherits panel bg, no separate container
                    GestureDetector(
                      onTap: () => controller.toggleListCollapsed(),
                      onVerticalDragEnd: (details) {
                        if (details.primaryVelocity != null) {
                          if (details.primaryVelocity! < -200) {
                            controller.expandList();
                          } else if (details.primaryVelocity! > 200) {
                            controller.collapseList();
                          }
                        }
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Semantics(
                        label: collapsed ? 'expand_property_list'.tr : 'collapse_property_list'.tr,
                        button: true,
                        child: SizedBox(
                          height: 44,
                          width: double.infinity,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 36,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: handleBarColor,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Obx(() {
                                final count = controller.properties.length;
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '$count ${count == 1 ? 'property'.tr : 'properties'.tr}',
                                      style: TextStyle(fontSize: 12, color: textColor),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      collapsed
                                          ? Icons.keyboard_arrow_up
                                          : Icons.keyboard_arrow_down,
                                      size: 16,
                                      color: iconColor,
                                    ),
                                  ],
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Card list
                    PropertyHorizontalList(controller: controller),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Two-pane layout (expanded / large) — iPad / tablet.
  // ---------------------------------------------------------------------------
  Widget _buildTwoPaneMapInterface(BuildContext context) {
    return SafeArea(
      top: false,
      child: Row(
        children: [
          // Left: map fills the remaining width with re-anchored overlays.
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    Positioned.fill(
                      child: Semantics(
                        label: 'qa.explore.map',
                        identifier: 'qa.explore.map',
                        child: ExploreMap(controller: controller),
                      ),
                    ),
                    // Map controls — anchored to the top-right of the *map pane*
                    // (not the screen), so they never float over the side panel.
                    Positioned(
                      top: AppSpacing.sm + 4,
                      right: AppSpacing.md,
                      child: _buildMapControls(context),
                    ),
                    // Info panel — top-left of the map pane.
                    Positioned(
                      top: AppSpacing.sm + 4,
                      left: AppSpacing.md,
                      child: _buildInfoPanel(context),
                    ),
                    // Loading-more indicator — sits just above the panel's bottom.
                    if (controller.state.value == ExploreState.loadingMore)
                      Positioned(
                        bottom: AppSpacing.md,
                        left: AppSpacing.md,
                        right: AppSpacing.md,
                        child: _buildLoadingMoreChip(context),
                      ),
                  ],
                );
              },
            ),
          ),
          // Right: fixed-width vertical property list panel.
          _buildSidePanel(context),
        ],
      ),
    );
  }

  Widget _buildSidePanel(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panelBg = isDark ? AppDesignTokens.darkSurfaceAlt : AppDesignTokens.warmCream;
    final borderColor = isDark ? AppDesignTokens.darkBorder : AppDesignTokens.neutral300;
    final textPrimary = isDark ? AppDesignTokens.darkTextPrimary : AppDesignTokens.neutral900;
    final textSecondary = isDark ? AppDesignTokens.darkTextSecondary : AppDesignTokens.neutral500;
    final dividerColor = isDark ? AppDesignTokens.darkBorder : AppDesignTokens.neutral300;

    return Container(
      width: _sidePanelWidth,
      decoration: BoxDecoration(
        color: panelBg,
        border: Border(left: BorderSide(color: borderColor, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Panel header — count + area summary (mirrors the info panel text).
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Obx(() {
              final count = controller.properties.length;
              return Row(
                children: [
                  Text(
                    '$count',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      count == 1 ? 'property'.tr : 'properties'.tr,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    controller.currentAreaText,
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                ],
              );
            }),
          ),
          Divider(height: 1, thickness: 1, color: dividerColor),
          // Vertical property list.
          Expanded(
            child: PropertyHorizontalList(controller: controller, direction: Axis.vertical),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingMoreChip(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chipBg = (isDark ? AppDesignTokens.darkSurfaceAlt : AppDesignTokens.warmCream).withValues(
      alpha: 0.95,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: chipBg,
        borderRadius: BorderRadius.circular(AppBorderRadius.sm),
        border: Border.all(color: AppDesignTokens.neutral300, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation<Color>(AppDesignTokens.brandGold),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'loading_more_properties'.tr,
            style: const TextStyle(fontSize: 12, color: AppDesignTokens.neutral500),
          ),
        ],
      ),
    );
  }

  Widget _buildMapControls(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controlBg = isDark ? AppDesignTokens.darkSurfaceAlt : AppDesignTokens.warmCream;
    final controlBorder = isDark ? AppDesignTokens.darkBorder : AppDesignTokens.neutral300;
    final iconTint = isDark ? AppDesignTokens.darkTextPrimary : AppDesignTokens.neutral900;

    return Column(
      children: [
        // Zoom controls
        Container(
          decoration: BoxDecoration(
            color: controlBg,
            borderRadius: BorderRadius.circular(AppBorderRadius.sm),
            border: Border.all(color: controlBorder, width: 1),
          ),
          child: Column(
            children: [
              IconButton(
                icon: Icon(Icons.add, color: iconTint),
                onPressed: controller.zoomIn,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minHeight: 36, minWidth: 36),
              ),
              Container(width: 24, height: 1, color: controlBorder),
              IconButton(
                icon: Icon(Icons.remove, color: iconTint),
                onPressed: controller.zoomOut,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minHeight: 36, minWidth: 36),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Current location button
        Container(
          decoration: BoxDecoration(
            color: controlBg,
            borderRadius: BorderRadius.circular(AppBorderRadius.sm),
            border: Border.all(color: controlBorder, width: 1),
          ),
          child: IconButton(
            icon: const Icon(Icons.my_location, color: AppDesign.primaryYellow),
            onPressed: controller.recenterToCurrentLocation,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minHeight: 36, minWidth: 36),
          ),
        ),

        const SizedBox(height: 12),

        // Fit bounds button
        Container(
          decoration: BoxDecoration(
            color: controlBg,
            borderRadius: BorderRadius.circular(AppBorderRadius.sm),
            border: Border.all(color: controlBorder, width: 1),
          ),
          child: IconButton(
            icon: Icon(Icons.center_focus_strong, color: iconTint),
            onPressed: controller.fitBoundsToProperties,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minHeight: 36, minWidth: 36),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoPanel(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panelBg = isDark ? AppDesignTokens.darkSurfaceAlt : AppDesignTokens.warmCream;
    final panelBorder = isDark ? AppDesignTokens.darkBorder : AppDesignTokens.neutral300;
    final textPrimary = isDark ? AppDesignTokens.darkTextPrimary : AppDesignTokens.neutral900;
    final textSecondary = isDark ? AppDesignTokens.darkTextSecondary : AppDesignTokens.neutral500;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: panelBg.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
        border: Border.all(color: panelBorder, width: 1),
      ),
      child: Obx(() {
        final count = controller.properties.length;
        final currentAreaText = controller.currentAreaText;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$count',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary),
            ),
            Text(
              ' ${count == 1 ? 'property'.tr : 'properties'.tr}',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: textSecondary),
            ),
            Text('bullet_separator'.tr, style: TextStyle(fontSize: 11, color: textSecondary)),
            Text(currentAreaText, style: TextStyle(fontSize: 11, color: textSecondary)),
          ],
        );
      }),
    );
  }

  // Bottom sheet removed in favor of persistent horizontal list
}
