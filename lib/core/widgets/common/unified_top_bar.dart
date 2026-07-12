import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:get/get.dart';

import 'package:ghar360/core/controllers/page_state_service.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/widgets/common/location_selector.dart';
import 'package:ghar360/core/widgets/common/property_filter_widget.dart';

class UnifiedTopBar extends GetView<PageStateService> implements PreferredSizeWidget {
  final PageType pageType;
  final String title;
  final bool showSearch;
  final Function(String)? onSearchChanged;
  final VoidCallback? onFilterTap;
  final VoidCallback? onSearchClear;
  final List<Widget>? additionalActions;
  final PreferredSizeWidget? bottom;

  const UnifiedTopBar({
    super.key,
    required this.pageType,
    required this.title,
    this.showSearch = true,
    this.onSearchChanged,
    this.onFilterTap,
    this.onSearchClear,
    this.additionalActions,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool supportsSearch = showSearch && _shouldShowSearch();

    if (supportsSearch) {
      // Reactive: toggle bottom search bar based on isSearchVisible
      return Obx(() {
        final bool searchVisible = controller.isSearchVisible(pageType);
        return _buildAppBar(context, theme, supportsSearch, searchVisible);
      });
    }

    // Non-reactive: no search support, no reactive state needed at this level
    return _buildAppBar(context, theme, false, false);
  }

  AppBar _buildAppBar(
    BuildContext context,
    ThemeData theme,
    bool supportsSearch,
    bool searchVisible,
  ) {
    final PreferredSizeWidget? bottomWidget = searchVisible
        ? _buildBottomSearchBar(controller)
        : bottom;

    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: kToolbarHeight,
      titleSpacing: 16,
      systemOverlayStyle: theme.brightness == Brightness.dark
          ? const SystemUiOverlayStyle(statusBarIconBrightness: Brightness.light)
          : const SystemUiOverlayStyle(statusBarIconBrightness: Brightness.dark),
      title: Row(
        children: [
          LocationSelector(pageType: pageType),
          const Spacer(),
          if (supportsSearch) _buildSearchToggle(controller),
          _buildRefreshIndicator(controller),
          _buildFilterButton(context, controller),
          ...?additionalActions,
        ],
      ),
      bottom: bottomWidget,
    );
  }

  bool _shouldShowSearch() {
    // Only show search for Explore and Likes pages
    return pageType == PageType.explore || pageType == PageType.likes;
  }

  PreferredSizeWidget _buildBottomSearchBar(PageStateService pageStateService) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(52),
      child: Obx(() {
        final currentState = _getCurrentPageState(pageStateService);
        final searchQuery = currentState.searchQuery ?? '';
        final searchController = pageStateService.getOrCreateSearchController(
          pageType,
          seedText: searchQuery,
        );
        return Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
          color: AppDesign.appBarBackground,
          child: Container(
            height: 38,
            decoration: BoxDecoration(
              color: AppDesign.inputBackground,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppDesign.divider, width: 0.5),
            ),
            child: TextField(
              key: ValueKey('qa.topbar.search_input.${pageType.name}'),
              onChanged: (value) {
                onSearchChanged?.call(value);
              },
              controller: searchController,
              style: TextStyle(color: AppDesign.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: _getSearchHint(),
                hintStyle: TextStyle(color: AppDesign.textSecondary, fontSize: 14),
                prefixIcon: Icon(Icons.search, color: AppDesign.iconColor, size: 18),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: AppDesign.iconColor, size: 18),
                        onPressed: () {
                          searchController.clear();
                          onSearchClear?.call();
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                isDense: true,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildFilterButton(BuildContext context, PageStateService pageStateService) {
    return Obx(() {
      final currentState = _getCurrentPageState(pageStateService);
      final activeFiltersCount = currentState.activeFiltersCount;

      return IconButton(
        key: ValueKey('qa.topbar.filter.${pageType.name}'),
        tooltip: activeFiltersCount > 0
            ? '${'filters'.tr} ($activeFiltersCount)'
            : 'filters'.tr,
        icon: Stack(
          children: [
            Icon(Icons.tune, color: AppDesign.iconColor, size: 24),
            if (activeFiltersCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppDesign.primaryYellow,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    activeFiltersCount.toString(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        onPressed:
            onFilterTap ?? () => showPropertyFilterBottomSheet(context, pageType: pageType.name),
      );
    });
  }

  Widget _buildSearchToggle(PageStateService pageStateService) {
    return Obx(() {
      final visible = pageStateService.isSearchVisible(pageType);
      return IconButton(
        key: ValueKey('qa.topbar.search_toggle.${pageType.name}'),
        tooltip: 'search_properties'.tr,
        icon: Icon(visible ? Icons.search_off : Icons.search, color: AppDesign.iconColor, size: 22),
        onPressed: () => pageStateService.toggleSearch(pageType),
      );
    });
  }

  Widget _buildRefreshIndicator(PageStateService pageStateService) {
    return Obx(() {
      final refreshing = pageStateService.isPageRefreshing(pageType);
      if (!refreshing) return const SizedBox.shrink();
      return const Padding(
        padding: EdgeInsets.only(right: 8.0),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppDesign.primaryYellow),
          ),
        ),
      );
    });
  }

  PageStateModel _getCurrentPageState(PageStateService pageStateService) {
    switch (pageType) {
      case PageType.explore:
        return pageStateService.exploreState.value;
      case PageType.discover:
        return pageStateService.discoverState.value;
      case PageType.likes:
        return pageStateService.likesState.value;
    }
  }

  String _getSearchHint() {
    switch (pageType) {
      case PageType.explore:
        return 'search_locations_hint'.tr;
      case PageType.likes:
        return 'search_in_likes_hint'.tr;
      case PageType.discover:
        return 'search_properties_hint_simple'.tr;
    }
  }

  @override
  Size get preferredSize {
    double height = kToolbarHeight;
    final bool supportsSearch = showSearch && _shouldShowSearch();
    final bool searchVisible = supportsSearch && controller.isSearchVisible(pageType);

    if (searchVisible) {
      height += 52; // Add height for search bar
    } else if (bottom != null) {
      height += bottom!.preferredSize.height;
    }
    return Size.fromHeight(height);
  }
}

// Extension for easy integration with existing views
extension UnifiedTopBarBuilder on Widget {
  Widget withUnifiedTopBar({
    required PageType pageType,
    required String title,
    bool showSearch = true,
    Function(String)? onSearchChanged,
    VoidCallback? onFilterTap,
    VoidCallback? onSearchClear,
    List<Widget>? additionalActions,
  }) {
    return GetX<PageStateService>(
      builder: (c) {
        final supportsSearch =
            (pageType == PageType.explore || pageType == PageType.likes) && showSearch;
        final searchVisible = supportsSearch && c.isSearchVisible(pageType);
        final height = kToolbarHeight + (searchVisible ? 52 : 0);
        return Scaffold(
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(height),
            child: UnifiedTopBar(
              pageType: pageType,
              title: title,
              showSearch: showSearch,
              onSearchChanged: onSearchChanged,
              onFilterTap: onFilterTap,
              onSearchClear: onSearchClear,
              additionalActions: additionalActions,
              bottom: null,
            ),
          ),
          body: this,
        );
      },
    );
  }
}

// Specialized top bars for different page types
class ExploreTopBar extends UnifiedTopBar {
  ExploreTopBar({super.key, super.onSearchChanged, super.onFilterTap, super.additionalActions})
    : super(pageType: PageType.explore, title: 'explore_properties'.tr, showSearch: true);
}

class DiscoverTopBar extends UnifiedTopBar {
  DiscoverTopBar({super.key, super.onFilterTap, super.additionalActions})
    : super(
        pageType: PageType.discover,
        title: 'app_name'.tr,
        showSearch: false, // Discover doesn't have search
      );
}

class LikesTopBar extends UnifiedTopBar {
  LikesTopBar({super.key, super.onSearchChanged, super.onFilterTap, super.additionalActions})
    : super(pageType: PageType.likes, title: 'my_likes'.tr, showSearch: true);
}
