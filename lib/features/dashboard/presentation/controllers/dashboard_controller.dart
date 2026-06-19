import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/controllers/page_state_service.dart';
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
  late final AuthController _authController;
  late final PageStateService _pageStateService;

  final RxMap<String, dynamic> dashboardData = <String, dynamic>{}.obs;
  final RxList<Map<String, dynamic>> recentActivity = <Map<String, dynamic>>[].obs;
  final RxMap<String, dynamic> userStats = <String, dynamic>{}.obs;
  final RxBool isLoading = false.obs;
  final RxBool isRefreshing = false.obs;
  final Rxn<AppException> error = Rxn<AppException>();

  // Bottom navigation state
  final RxInt currentIndex = 2.obs; // Default to Discover tab (index 2)
  Worker? _authStatusWorker;

  final GetStorage _storage = GetStorage();

  @override
  void onInit() {
    super.onInit();

    _authController = Get.find<AuthController>();
    _pageStateService = Get.find<PageStateService>();

    // Listen to authentication state changes
    _authStatusWorker = ever(_authController.authStatus, (authStatus) {
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
    if (!_authController.isAuthenticated) return;

    try {
      isLoading.value = true;
      error.value = null;

      // Load dashboard data (analytics removed)
      final results = await Future.wait([_loadUserStats(), _loadRecentActivity()]);

      userStats.value = results[0] as Map<String, dynamic>;
      recentActivity.value = results[1] as List<Map<String, dynamic>>;

      // Clear analytics data that's no longer available
      dashboardData.value = {};
    } catch (e, stackTrace) {
      error.value = ErrorMapper.mapApiError('Failed to load dashboard data');
      DebugLogger.error('Error loading dashboard data', e, stackTrace);

      AppToast.error('dashboard_error_title'.tr, 'dashboard_error_message'.tr);
    } finally {
      isLoading.value = false;
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
    dashboardData.clear();
    recentActivity.clear();
    userStats.clear();
    error.value = null;
  }

  // Analytics dashboard getters
  int get totalViews => dashboardData['total_views'] ?? 0;
  int get totalLikes => dashboardData['total_likes'] ?? 0;
  int get totalVisitsScheduled => dashboardData['total_visits_scheduled'] ?? 0;
  double get conversionRate => dashboardData['conversion_rate']?.toDouble() ?? 0.0;

  List<String> get preferredLocations {
    final locations = dashboardData['preferred_locations'];
    if (locations is List) {
      return List<String>.from(locations);
    }
    return [];
  }

  Map<String, dynamic> get activitySummary => dashboardData['activity_summary'] ?? {};

  // User stats getters
  int get propertiesViewed => userStats['properties_viewed'] ?? 0;
  int get propertiesLiked => userStats['properties_liked'] ?? 0;
  int get visitsScheduled => userStats['visits_scheduled'] ?? 0;
  int get searchesMade => userStats['searches_made'] ?? 0;
  int get timeSpentMinutes => userStats['time_spent_minutes'] ?? 0;
  String get favoriteLocation => userStats['favorite_location'] ?? 'N/A';

  // Dashboard insights

  double get averagePropertyPrice {
    final summary = activitySummary;
    return summary['average_property_price']?.toDouble() ?? 0.0;
  }

  String get mostViewedPropertyType {
    final summary = activitySummary;
    return summary['most_viewed_property_type'] ?? 'Apartment';
  }

  List<Map<String, dynamic>> get topLocations {
    final locations = dashboardData['top_locations'];
    if (locations is List) {
      return List<Map<String, dynamic>>.from(locations);
    }
    return [];
  }

  // Engagement metrics
  double get engagementScore {
    if (propertiesViewed == 0) return 0.0;
    return (propertiesLiked / propertiesViewed * 100).clamp(0.0, 100.0);
  }

  /// Returns translation key for user engagement level
  String get userEngagementLevelKey {
    final score = engagementScore;
    if (score >= 80) return 'priority_high';
    if (score >= 50) return 'priority_medium';
    if (score >= 20) return 'priority_low';
    return 'priority_very_low';
  }

  @Deprecated('Use userEngagementLevelKey with .tr for localized text')
  String get userEngagementLevel => userEngagementLevelKey;

  // Time-based insights
  String get timeSpentFormatted {
    final minutes = timeSpentMinutes;
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return '${hours}h ${remainingMinutes}m';
  }

  bool get isActiveUser => propertiesViewed >= 10 || timeSpentMinutes >= 60;

  // Data export functionality
  Map<String, dynamic> exportDashboardData() {
    return {
      'dashboard_data': dashboardData,
      'user_stats': userStats,
      'recent_activity': recentActivity,
      'export_timestamp': DateTime.now().toIso8601String(),
    };
  }

  // Dashboard summary for quick overview
  Map<String, dynamic> get quickSummary => {
    'properties_viewed': propertiesViewed,
    'properties_liked': propertiesLiked,
    'visits_scheduled': visitsScheduled,
    'engagement_level': userEngagementLevel,
    'time_spent': timeSpentFormatted,
    'favorite_location': favoriteLocation,
  };

  // Navigation methods
  void changeTab(int index) {
    if (currentIndex.value == index) return; // Prevent redundant updates
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
        currentIndex.value = 0; // ProfileView
        break;
      case AppRoutes.explore:
        currentIndex.value = 1; // ExploreView
        break;
      case AppRoutes.discover:
        currentIndex.value = 2; // DiscoverView
        break;
      case AppRoutes.likes:
        currentIndex.value = 3; // LikesView
        break;
      case AppRoutes.visits:
        currentIndex.value = 4; // VisitsView
        break;
      case AppRoutes.assistant:
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
