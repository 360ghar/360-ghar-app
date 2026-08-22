import 'package:get/get.dart';

import 'package:ghar360/core/controllers/page_state_service.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/core/utils/debug_logger.dart';

class DashboardController extends GetxController {
  // Named constants for tab indices
  static const int profileTab = 0;
  static const int exploreTab = 1;
  static const int discoverTab = 2;
  static const int likesTab = 3;
  static const int visitsTab = 4;
  static const int assistantTab = 5;

  PageStateService get _pageStateService => Get.find<PageStateService>();

  // Bottom navigation state
  final RxInt currentIndex = 2.obs; // Default to Discover tab (index 2)
  final Set<int> visitedTabs = {2}; // Lazy tab initialization tracking

  @override
  void onReady() {
    super.onReady();

    // Activate the initial page (Discover by default)
    final initialIndex = currentIndex.value;
    DebugLogger.info('🚀 Dashboard ready, activating initial tab: $initialIndex');

    // Activate the default page without changing the index
    PageType? pageType;
    switch (initialIndex) {
      case 1:
        pageType = PageType.explore;
        break;
      case 2:
        pageType = PageType.discover;
        break;
      case 3:
        pageType = PageType.likes;
        break;
    }

    if (pageType != null) {
      // Single source of truth: update current page type only
      _pageStateService.setCurrentPage(pageType);
    }
  }

  // Navigation methods
  void changeTab(int index) {
    if (currentIndex.value == index) return; // Prevent redundant updates
    visitedTabs.add(index);
    currentIndex.value = index;

    // Update PageStateService with the corresponding page type
    PageType? pageType;
    switch (index) {
      case 0: // Profile (no associated PageType)
        break;
      case 1:
        pageType = PageType.explore;
        break;
      case 2:
        pageType = PageType.discover;
        break;
      case 3:
        pageType = PageType.likes;
        break;
      case 4: // Visits (no associated PageType)
        break;
      case 5: // Assistant (no associated PageType)
        break;
    }

    if (pageType != null) {
      // Single source of truth: feature controllers listen to this
      _pageStateService.setCurrentPage(pageType);
    }
  }

  // Sync tab with current route
  void syncTabWithRoute(String route) {
    switch (route) {
      case AppRoutes.profile:
        visitedTabs.add(0);
        currentIndex.value = 0; // ProfileView
        break;
      case AppRoutes.explore:
        visitedTabs.add(1);
        currentIndex.value = 1; // ExploreView
        break;
      case AppRoutes.discover:
        visitedTabs.add(2);
        currentIndex.value = 2; // DiscoverView
        break;
      case AppRoutes.likes:
        visitedTabs.add(3);
        currentIndex.value = 3; // LikesView
        break;
      case AppRoutes.visits:
        visitedTabs.add(4);
        currentIndex.value = 4; // VisitsView
        break;
      case AppRoutes.assistant:
        visitedTabs.add(5);
        currentIndex.value = 5; // AssistantView
        break;
      case AppRoutes.dashboard:
      case '/':
        // Keep current tab for dashboard route to avoid unwanted switches
        break;
      default:
        // For other routes, don't change the tab
        break;
    }
  }
}
