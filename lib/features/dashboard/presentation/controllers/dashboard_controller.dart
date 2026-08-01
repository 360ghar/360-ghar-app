import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/controllers/page_state_service.dart';
import 'package:ghar360/core/data/models/auth_status.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/utils/app_toast.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/core/utils/error_mapper.dart';
import 'package:ghar360/features/visits/presentation/controllers/visits_controller.dart';

/// GetStorage keys for persisted, locally-aggregated dashboard stats.
/// These are incremented as the user interacts with the app and survive
/// across sessions until the backend exposes a real stats endpoint.
const String kDashPropertiesViewedKey = 'dash_properties_viewed';
const String kDashPropertiesLikedKey = 'dash_properties_liked';
const String kDashSearchesMadeKey = 'dash_searches_made';
const String kDashRecentActivityKey = 'dash_recent_activity';

class DashboardController extends GetxController {
  // Named constants for tab indices
  static const int profileTab = 0;
  static const int exploreTab = 1;
  static const int discoverTab = 2;
  static const int likesTab = 3;
  static const int visitsTab = 4;
  static const int assistantTab = 5;

  // Resolved lazily on access so onInit() can never crash on a re-init.
  AuthController get _authController => Get.find<AuthController>();
  PageStateService get _pageStateService => Get.find<PageStateService>();

  final RxList<Map<String, dynamic>> recentActivity = <Map<String, dynamic>>[].obs;
  final RxMap<String, dynamic> userStats = <String, dynamic>{}.obs;
  final RxBool isLoading = false.obs;
  final RxBool isRefreshing = false.obs;
  final Rxn<AppException> error = Rxn<AppException>();

  // Bottom navigation state
  final RxInt currentIndex = 2.obs; // Default to Discover tab (index 2)
  final Set<int> visitedTabs = {2}; // Lazy tab initialization tracking
  Worker? _authStatusWorker;
  int _loadGeneration = 0;

  final GetStorage _storage = GetStorage();

  @override
  void onInit() {
    super.onInit();

    // Listen to authentication state changes (guarded against re-entrant onInit)
    _authStatusWorker ??= ever(_authController.authStatus, (authStatus) {
      if (authStatus == AuthStatus.initial) return; // Skip initial status
      if (_authController.isAuthenticated) {
        // User is authenticated, safe to fetch data
        loadDashboardData();
      } else {
        // User logged out, clear all data
        _clearAllData();
      }
    });

    // If already authenticated, load dashboard data
    if (_authController.isAuthenticated) {
      loadDashboardData();
    }
  }

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

  Future<void> loadDashboardData() async {
    if (isLoading.value || !_authController.isAuthenticated) return;

    final generation = ++_loadGeneration;
    try {
      isLoading.value = true;
      error.value = null;

      // Load dashboard data (analytics removed)
      final results = await Future.wait([_loadUserStats(), _loadRecentActivity()]);
      if (generation != _loadGeneration || !_authController.isAuthenticated) return;

      userStats.value = results[0] as Map<String, dynamic>;
      recentActivity.value = results[1] as List<Map<String, dynamic>>;
    } catch (e, stackTrace) {
      if (generation != _loadGeneration || !_authController.isAuthenticated) return;
      error.value = ErrorMapper.mapApiError('Failed to load dashboard data');
      DebugLogger.error('Error loading dashboard data', e, stackTrace);

      AppToast.error('dashboard_error_title'.tr, 'dashboard_error_message'.tr);
    } finally {
      if (generation == _loadGeneration) isLoading.value = false;
    }
  }

  Future<void> refreshDashboard() async {
    if (!_authController.isAuthenticated || isRefreshing.value) return;

    try {
      isRefreshing.value = true;
      await loadDashboardData();
    } finally {
      isRefreshing.value = false;
    }
  }

  Future<Map<String, dynamic>> _loadUserStats() async {
    try {
      // Aggregate real stats from existing controllers and persisted counters.
      // Backend analytics endpoint is not available, so we derive values that
      // already exist in the app rather than fabricating fake data.
      final propertiesLiked = _storage.read<int>(kDashPropertiesLikedKey) ?? 0;
      final searchesMade = _storage.read<int>(kDashSearchesMadeKey) ?? 0;
      final propertiesViewed = _storage.read<int>(kDashPropertiesViewedKey) ?? 0;

      int visitsScheduled = 0;
      try {
        if (Get.isRegistered<VisitsController>()) {
          visitsScheduled = Get.find<VisitsController>().upcomingVisitsList.length;
        }
      } catch (e) {
        DebugLogger.warning('Could not read visits count for stats: $e');
      }

      return {
        'properties_viewed': propertiesViewed,
        'properties_liked': propertiesLiked,
        'visits_scheduled': visitsScheduled,
        'searches_made': searchesMade,
        'time_spent_minutes': 0, // Not tracked locally; left as 0 (no fake data)
        'favorite_location': _resolveFavoriteLocation(),
      };
    } catch (e, stackTrace) {
      DebugLogger.error('Error loading user stats', e, stackTrace);
      return {};
    }
  }

  String _resolveFavoriteLocation() {
    try {
      final location = _pageStateService.discoverState.value.selectedLocation;
      if (location != null && location.name.trim().isNotEmpty) {
        return location.name.trim();
      }
    } catch (_) {}
    return 'N/A';
  }

  Future<List<Map<String, dynamic>>> _loadRecentActivity() async {
    try {
      // Recent activity is persisted locally as the user interacts with the
      // app (see recordActivity). We never fabricate entries; if the list is
      // empty, the UI shows an empty state.
      final raw = _storage.read(kDashRecentActivityKey);
      if (raw is List) {
        final items = <Map<String, dynamic>>[];
        for (final entry in raw) {
          if (entry is Map) {
            items.add(Map<String, dynamic>.from(entry));
          }
        }
        // Keep only the 10 most recent entries
        if (items.length > 10) {
          items.removeRange(10, items.length);
        }
        return items;
      }
      return [];
    } catch (e, stackTrace) {
      DebugLogger.error('Error loading recent activity', e, stackTrace);
      return [];
    }
  }

  /// Records a user activity locally so it can surface on the dashboard
  /// without requiring a backend analytics endpoint. Keeps the 10 most
  /// recent entries.
  void recordActivity({required String type, required String title, String icon = 'visibility'}) {
    try {
      final entry = {
        'type': type,
        'title': title,
        'timestamp': DateTime.now().toIso8601String(),
        'icon': icon,
      };

      final raw = _storage.read(kDashRecentActivityKey);
      final List<Map<String, dynamic>> items = [];
      if (raw is List) {
        for (final e in raw) {
          if (e is Map) items.add(Map<String, dynamic>.from(e));
        }
      }
      items.insert(0, entry);
      if (items.length > 10) items.removeRange(10, items.length);
      _storage.write(kDashRecentActivityKey, items);

      // Update in-memory list so any open dashboard reflects it
      recentActivity.assignAll(items);
    } catch (e) {
      DebugLogger.warning('Failed to record activity: $e');
    }
  }

  /// Increments a persisted counter (used by feature controllers/hooks).
  void incrementStat(String key, {int by = 1}) {
    try {
      final current = _storage.read<int>(key) ?? 0;
      _storage.write(key, current + by);
    } catch (e) {
      DebugLogger.warning('Failed to increment stat $key: $e');
    }
  }

  /// Decrements a persisted counter, never going below zero. Used to reverse
  /// a previously recorded stat (e.g. swipe undo).
  void decrementStat(String key, {int by = 1}) {
    try {
      final current = _storage.read<int>(key) ?? 0;
      _storage.write(key, (current - by).clamp(0, 1 << 31));
    } catch (e) {
      DebugLogger.warning('Failed to decrement stat $key: $e');
    }
  }

  void _clearAllData() {
    // Invalidate any in-flight load so a previous user cannot repopulate state
    // after logout or account switching.
    _loadGeneration++;
    isLoading.value = false;
    isRefreshing.value = false;
    recentActivity.clear();
    userStats.clear();
    error.value = null;

    // Clear persisted GetStorage counters
    _storage.remove(kDashPropertiesViewedKey);
    _storage.remove(kDashPropertiesLikedKey);
    _storage.remove(kDashSearchesMadeKey);
    _storage.remove(kDashRecentActivityKey);
  }

  // User stats getters
  int get propertiesViewed => userStats['properties_viewed'] ?? 0;
  int get propertiesLiked => userStats['properties_liked'] ?? 0;
  int get visitsScheduled => userStats['visits_scheduled'] ?? 0;
  int get searchesMade => userStats['searches_made'] ?? 0;
  int get timeSpentMinutes => userStats['time_spent_minutes'] ?? 0;
  String get favoriteLocation => userStats['favorite_location'] ?? 'N/A';

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

  @override
  void onClose() {
    _authStatusWorker?.dispose();
    super.onClose();
  }
}
