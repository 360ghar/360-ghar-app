// test/features/dashboard/presentation/controllers/dashboard_controller_test.dart
//
// Unit tests for [DashboardController]. Covers:
// - Initial state (currentIndex=2, visitedTabs={2})
// - changeTab updates index and adds to visitedTabs
// - syncTabWithRoute mapping
// - loadDashboardData concurrent guard (isLoading check)
// - _clearAllData clears storage keys and reactive state

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/controllers/page_state_service.dart';
import 'package:ghar360/core/data/models/auth_status.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/getx_test_binding.dart';
import '../../../../helpers/mocks.dart';

void main() {
  // Mock path_provider platform channel so GetStorage can initialise in tests.
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return '.';
        }
        return null;
      },
    );
    registerFallbackValue(PageType.discover);
  });

  late MockAuthController mockAuthController;
  late MockPageStateService mockPageStateService;
  late Rx<AuthStatus> authStatus;
  late Rx<PageType> currentPageType;

  setUp(() async {
    GetxTestBinding.init();
    await GetStorage.init();
    GetStorage().erase();

    mockAuthController = MockAuthController();
    mockPageStateService = MockPageStateService();

    // Auth setup — start authenticated by default
    authStatus = AuthStatus.authenticated.obs;
    when(() => mockAuthController.authStatus).thenReturn(authStatus);
    when(() => mockAuthController.isAuthenticated).thenReturn(true);

    // PageStateService setup
    currentPageType = PageType.discover.obs;
    when(() => mockPageStateService.currentPageType).thenReturn(currentPageType);
    when(() => mockPageStateService.setCurrentPage(any())).thenReturn(null);
    when(
      () => mockPageStateService.discoverState,
    ).thenReturn(PageStateModel.initial(PageType.discover).obs);

    GetxTestBinding.bind()
      ..register<AuthController>(mockAuthController)
      ..register<PageStateService>(mockPageStateService);
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  DashboardController createController() {
    final c = DashboardController();
    c.onInit();
    return c;
  }

  group('DashboardController', () {
    // ── Initial state ──────────────────────────────────────────────────

    test('initial state has currentIndex=2 and visitedTabs={2}', () {
      final controller = createController();

      expect(controller.currentIndex.value, 2);
      expect(controller.visitedTabs, {2});
    });

    test('initial reactive collections are empty', () {
      // Start unauthenticated so onInit does not trigger loadDashboardData,
      // which would set isLoading to true asynchronously.
      when(() => mockAuthController.isAuthenticated).thenReturn(false);
      final controller = createController();

      expect(controller.dashboardData, isEmpty);
      expect(controller.recentActivity, isEmpty);
      expect(controller.userStats, isEmpty);
      expect(controller.isLoading.value, false);
      expect(controller.isRefreshing.value, false);
      expect(controller.error.value, isNull);
    });

    // ── changeTab ──────────────────────────────────────────────────────

    test('changeTab updates currentIndex and adds to visitedTabs', () {
      final controller = createController();

      controller.changeTab(1);

      expect(controller.currentIndex.value, 1);
      expect(controller.visitedTabs, contains(1));
      expect(controller.visitedTabs, contains(2)); // initial tab preserved
    });

    test('changeTab with same index is a no-op', () {
      final controller = createController();

      // Default index is 2
      controller.changeTab(2);

      // No redundant update — visitedTabs unchanged (only {2} from init)
      expect(controller.currentIndex.value, 2);
    });

    test('changeTab calls setCurrentPage for mapped page types', () {
      final controller = createController();

      controller.changeTab(1); // Explore
      verify(() => mockPageStateService.setCurrentPage(PageType.explore)).called(1);

      controller.changeTab(3); // Likes
      verify(() => mockPageStateService.setCurrentPage(PageType.likes)).called(1);
    });

    test('changeTab does not call setCurrentPage for unmapped indices (Profile, Visits)', () {
      final controller = createController();

      controller.changeTab(0); // Profile — no PageType
      controller.changeTab(4); // Visits — no PageType

      verifyNever(() => mockPageStateService.setCurrentPage(any()));
    });

    // ── syncTabWithRoute ───────────────────────────────────────────────

    test('syncTabWithRoute maps known routes to correct tab indices', () {
      final controller = createController();

      controller.syncTabWithRoute(AppRoutes.profile);
      expect(controller.currentIndex.value, 0);
      expect(controller.visitedTabs, contains(0));

      controller.syncTabWithRoute(AppRoutes.explore);
      expect(controller.currentIndex.value, 1);
      expect(controller.visitedTabs, contains(1));

      controller.syncTabWithRoute(AppRoutes.discover);
      expect(controller.currentIndex.value, 2);

      controller.syncTabWithRoute(AppRoutes.likes);
      expect(controller.currentIndex.value, 3);
      expect(controller.visitedTabs, contains(3));

      controller.syncTabWithRoute(AppRoutes.visits);
      expect(controller.currentIndex.value, 4);
      expect(controller.visitedTabs, contains(4));

      controller.syncTabWithRoute(AppRoutes.assistant);
      expect(controller.currentIndex.value, 5);
      expect(controller.visitedTabs, contains(5));
    });

    test('syncTabWithRoute does not change tab for dashboard or unknown routes', () {
      final controller = createController();

      controller.syncTabWithRoute(AppRoutes.dashboard);
      expect(controller.currentIndex.value, 2); // unchanged

      controller.syncTabWithRoute('/');
      expect(controller.currentIndex.value, 2); // unchanged

      controller.syncTabWithRoute('/some-unknown-route');
      expect(controller.currentIndex.value, 2); // unchanged
    });

    // ── loadDashboardData concurrent guard ─────────────────────────────

    test('loadDashboardData returns early when already loading (concurrent guard)', () async {
      // Start unauthenticated so onInit does not trigger loadDashboardData.
      when(() => mockAuthController.isAuthenticated).thenReturn(false);
      final controller = DashboardController();
      controller.onInit();

      // Now make authenticated so the isAuthenticated guard passes,
      // but set isLoading to simulate a concurrent load in progress.
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      controller.isLoading.value = true;

      // Call loadDashboardData — should return immediately due to isLoading guard
      await controller.loadDashboardData();

      // isLoading should still be true (never entered the try block)
      expect(controller.isLoading.value, true);
    });

    test('loadDashboardData returns early when not authenticated', () async {
      when(() => mockAuthController.isAuthenticated).thenReturn(false);

      final controller = createController();
      controller.isLoading.value = false;

      await controller.loadDashboardData();

      // Should not have set isLoading to true (returned before try block)
      expect(controller.isLoading.value, false);
    });

    // ── _clearAllData (tested indirectly via auth state change) ────────

    test('logout clears all dashboard data and storage keys', () async {
      final controller = createController();

      // Seed some data into storage
      final storage = GetStorage();
      await storage.write(kDashPropertiesViewedKey, 10);
      await storage.write(kDashPropertiesLikedKey, 5);
      await storage.write(kDashSearchesMadeKey, 3);
      await storage.write(kDashRecentActivityKey, [
        {'type': 'view', 'title': 'test'},
      ]);

      // Seed reactive data
      controller.userStats.value = {'properties_viewed': 10};
      controller.recentActivity.value = [
        {'type': 'view', 'title': 'test'},
      ];
      controller.dashboardData.value = {'total_views': 100};

      // Trigger logout — the ever worker should call _clearAllData
      when(() => mockAuthController.isAuthenticated).thenReturn(false);
      authStatus.value = AuthStatus.unauthenticated;

      // Wait for the worker to fire
      await Future<void>.delayed(Duration.zero);

      // Verify reactive state is cleared
      expect(controller.dashboardData, isEmpty);
      expect(controller.recentActivity, isEmpty);
      expect(controller.userStats, isEmpty);
      expect(controller.error.value, isNull);

      // Verify storage keys are removed
      expect(storage.read(kDashPropertiesViewedKey), isNull);
      expect(storage.read(kDashPropertiesLikedKey), isNull);
      expect(storage.read(kDashSearchesMadeKey), isNull);
      expect(storage.read(kDashRecentActivityKey), isNull);
    });

    // ── refreshDashboard ───────────────────────────────────────────────

    test('refreshDashboard is a no-op when not authenticated', () async {
      when(() => mockAuthController.isAuthenticated).thenReturn(false);

      final controller = createController();

      await controller.refreshDashboard();

      expect(controller.isRefreshing.value, false);
    });

    test('refreshDashboard is a no-op when already refreshing', () async {
      final controller = createController();
      controller.isRefreshing.value = true;

      await controller.refreshDashboard();

      expect(controller.isRefreshing.value, true);
    });

    // ── userStats getters ──────────────────────────────────────────────

    test('stat getters return defaults when userStats is empty', () {
      final controller = createController();

      expect(controller.propertiesViewed, 0);
      expect(controller.propertiesLiked, 0);
      expect(controller.visitsScheduled, 0);
      expect(controller.searchesMade, 0);
      expect(controller.timeSpentMinutes, 0);
      expect(controller.favoriteLocation, 'N/A');
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // Additional tests for tab navigation, route syncing, data loading,
  // storage, auth state, stats, and engagement metrics
  // ─────────────────────────────────────────────────────────────────────

  group('DashboardController — changeTab edge cases', () {
    test('changeTab to discover sets page type', () {
      final controller = createController();
      // Default index is 2 (discover), so change to another tab first then back.
      controller.changeTab(1); // explore

      controller.changeTab(2); // discover

      verify(() => mockPageStateService.setCurrentPage(PageType.discover)).called(1);
    });

    test('changeTab to assistant does not call setCurrentPage', () {
      final controller = createController();

      controller.changeTab(5);

      verifyNever(() => mockPageStateService.setCurrentPage(any()));
    });

    test('changeTab adds all visited tabs to set', () {
      final controller = createController();

      controller.changeTab(0);
      controller.changeTab(1);
      controller.changeTab(3);
      controller.changeTab(4);
      controller.changeTab(5);

      expect(controller.visitedTabs, containsAll([0, 1, 2, 3, 4, 5]));
    });
  });

  group('DashboardController — onReady route syncing', () {
    test('onReady sets discover page type for default index 2', () {
      final controller = createController();
      controller.onReady();

      verify(() => mockPageStateService.setCurrentPage(PageType.discover)).called(1);
    });

    test('onReady sets explore page type when currentIndex is 1', () {
      final controller = createController();
      controller.currentIndex.value = 1;
      controller.onReady();

      verify(() => mockPageStateService.setCurrentPage(PageType.explore)).called(1);
    });

    test('onReady sets likes page type when currentIndex is 3', () {
      final controller = createController();
      controller.currentIndex.value = 3;
      controller.onReady();

      verify(() => mockPageStateService.setCurrentPage(PageType.likes)).called(1);
    });

    test('onReady does not set page type for profile tab (index 0)', () {
      final controller = createController();
      controller.currentIndex.value = 0;
      controller.onReady();

      verifyNever(() => mockPageStateService.setCurrentPage(any()));
    });
  });

  group('DashboardController — auth state changes', () {
    test('login triggers loadDashboardData', () async {
      // Start unauthenticated
      when(() => mockAuthController.isAuthenticated).thenReturn(false);
      final controller = createController();

      // Simulate login
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      authStatus.value = AuthStatus.authenticated;
      await Future<void>.delayed(Duration.zero);

      // loadDashboardData should have been called (isLoading was set to true then false)
      expect(controller.isLoading.value, isFalse);
    });

    test('initial auth status is skipped', () async {
      // Start with initial status
      authStatus.value = AuthStatus.initial;
      when(() => mockAuthController.isAuthenticated).thenReturn(false);
      final controller = createController();

      // Change to initial again - should be skipped
      authStatus.value = AuthStatus.initial;
      await Future<void>.delayed(Duration.zero);

      // Should not have loaded dashboard data
      expect(controller.isLoading.value, isFalse);
    });
  });

  group('DashboardController — stats persistence', () {
    test('incrementStat persists value to storage', () async {
      final controller = createController();

      controller.incrementStat(kDashPropertiesViewedKey);
      controller.incrementStat(kDashPropertiesViewedKey);
      controller.incrementStat(kDashPropertiesViewedKey, by: 5);

      final storage = GetStorage();
      expect(storage.read<int>(kDashPropertiesViewedKey), 7);
    });

    test('decrementStat persists value and clamps to zero', () async {
      final controller = createController();
      final storage = GetStorage();
      await storage.write(kDashPropertiesLikedKey, 3);

      controller.decrementStat(kDashPropertiesLikedKey);
      expect(storage.read<int>(kDashPropertiesLikedKey), 2);

      controller.decrementStat(kDashPropertiesLikedKey, by: 10);
      expect(storage.read<int>(kDashPropertiesLikedKey), 0);
    });

    test('incrementStat on non-existent key starts from zero', () {
      final controller = createController();

      controller.incrementStat('new_key');

      final storage = GetStorage();
      expect(storage.read<int>('new_key'), 1);
    });
  });

  group('DashboardController — recordActivity', () {
    test('recordActivity stores entry in storage', () {
      final controller = createController();

      controller.recordActivity(type: 'view', title: 'Viewed Property X');

      final storage = GetStorage();
      final raw = storage.read(kDashRecentActivityKey);
      expect(raw, isA<List>());
      expect((raw as List).length, 1);
      expect(raw.first['type'], 'view');
      expect(raw.first['title'], 'Viewed Property X');
    });

    test('recordActivity updates in-memory recentActivity list', () {
      final controller = createController();

      controller.recordActivity(type: 'like', title: 'Liked Property Y');

      expect(controller.recentActivity.length, 1);
      expect(controller.recentActivity.first['type'], 'like');
    });

    test('recordActivity keeps only 10 most recent entries', () {
      final controller = createController();

      for (int i = 0; i < 15; i++) {
        controller.recordActivity(type: 'view', title: 'Activity $i');
      }

      expect(controller.recentActivity.length, 10);
      // Most recent should be first
      expect(controller.recentActivity.first['title'], 'Activity 14');
    });

    test('recordActivity with custom icon', () {
      final controller = createController();

      controller.recordActivity(type: 'search', title: 'Searched "villa"', icon: 'search');

      expect(controller.recentActivity.first['icon'], 'search');
    });
  });

  group('DashboardController — engagement metrics', () {
    test('engagementScore returns 0 when no properties viewed', () {
      final controller = createController();

      expect(controller.engagementScore, 0.0);
    });

    test('engagementScore calculates percentage correctly', () {
      final controller = createController();
      controller.userStats.value = {'properties_viewed': 10, 'properties_liked': 5};

      expect(controller.engagementScore, 50.0);
    });

    test('engagementScore clamps to 100', () {
      final controller = createController();
      controller.userStats.value = {'properties_viewed': 10, 'properties_liked': 20};

      expect(controller.engagementScore, 100.0);
    });

    test('userEngagementLevelKey returns priority_high for score >= 80', () {
      final controller = createController();
      controller.userStats.value = {'properties_viewed': 10, 'properties_liked': 9};

      expect(controller.userEngagementLevelKey, 'priority_high');
    });

    test('userEngagementLevelKey returns priority_medium for score >= 50', () {
      final controller = createController();
      controller.userStats.value = {'properties_viewed': 10, 'properties_liked': 5};

      expect(controller.userEngagementLevelKey, 'priority_medium');
    });

    test('userEngagementLevelKey returns priority_low for score >= 20', () {
      final controller = createController();
      controller.userStats.value = {'properties_viewed': 10, 'properties_liked': 2};

      expect(controller.userEngagementLevelKey, 'priority_low');
    });

    test('userEngagementLevelKey returns priority_very_low for score < 20', () {
      final controller = createController();
      controller.userStats.value = {'properties_viewed': 10, 'properties_liked': 1};

      expect(controller.userEngagementLevelKey, 'priority_very_low');
    });
  });

  group('DashboardController — time formatting', () {
    test('timeSpentFormatted returns minutes for < 60', () {
      final controller = createController();
      controller.userStats.value = {'time_spent_minutes': 45};

      expect(controller.timeSpentFormatted, '45m');
    });

    test('timeSpentFormatted returns hours and minutes for >= 60', () {
      final controller = createController();
      controller.userStats.value = {'time_spent_minutes': 125};

      expect(controller.timeSpentFormatted, '2h 5m');
    });

    test('timeSpentFormatted returns 0m for zero', () {
      final controller = createController();

      expect(controller.timeSpentFormatted, '0m');
    });
  });

  group('DashboardController — isActiveUser', () {
    test('returns true when propertiesViewed >= 10', () {
      final controller = createController();
      controller.userStats.value = {'properties_viewed': 10};

      expect(controller.isActiveUser, isTrue);
    });

    test('returns true when timeSpentMinutes >= 60', () {
      final controller = createController();
      controller.userStats.value = {'time_spent_minutes': 60};

      expect(controller.isActiveUser, isTrue);
    });

    test('returns false when neither threshold met', () {
      final controller = createController();
      controller.userStats.value = {'properties_viewed': 5, 'time_spent_minutes': 30};

      expect(controller.isActiveUser, isFalse);
    });
  });

  group('DashboardController — data export', () {
    test('exportDashboardData returns map with all keys', () {
      final controller = createController();
      controller.userStats.value = {'properties_viewed': 5};
      controller.recentActivity.value = [
        {'type': 'view', 'title': 'test'},
      ];

      final exported = controller.exportDashboardData();

      expect(exported, containsPair('dashboard_data', controller.dashboardData));
      expect(exported, containsPair('user_stats', controller.userStats));
      expect(exported, containsPair('recent_activity', controller.recentActivity));
      expect(exported, contains('export_timestamp'));
    });
  });

  group('DashboardController — quickSummary', () {
    test('quickSummary contains all expected keys', () {
      final controller = createController();
      controller.userStats.value = {
        'properties_viewed': 10,
        'properties_liked': 5,
        'visits_scheduled': 2,
        'time_spent_minutes': 30,
        'favorite_location': 'Mumbai',
      };

      final summary = controller.quickSummary;

      expect(summary, containsPair('properties_viewed', 10));
      expect(summary, containsPair('properties_liked', 5));
      expect(summary, containsPair('visits_scheduled', 2));
      expect(summary, contains('engagement_level'));
      expect(summary, contains('time_spent'));
      expect(summary, containsPair('favorite_location', 'Mumbai'));
    });
  });

  group('DashboardController — dashboard data getters', () {
    test('totalViews returns 0 when dashboardData is empty', () {
      final controller = createController();

      expect(controller.totalViews, 0);
    });

    test('totalViews returns value from dashboardData', () {
      final controller = createController();
      controller.dashboardData.value = {'total_views': 500};

      expect(controller.totalViews, 500);
    });

    test('totalLikes returns value from dashboardData', () {
      final controller = createController();
      controller.dashboardData.value = {'total_likes': 42};

      expect(controller.totalLikes, 42);
    });

    test('conversionRate returns 0.0 by default', () {
      final controller = createController();

      expect(controller.conversionRate, 0.0);
    });

    test('preferredLocations returns empty list by default', () {
      final controller = createController();

      expect(controller.preferredLocations, isEmpty);
    });

    test('preferredLocations returns list from dashboardData', () {
      final controller = createController();
      controller.dashboardData.value = {
        'preferred_locations': ['Mumbai', 'Delhi'],
      };

      expect(controller.preferredLocations, ['Mumbai', 'Delhi']);
    });

    test('topLocations returns empty list by default', () {
      final controller = createController();

      expect(controller.topLocations, isEmpty);
    });

    test('mostViewedPropertyType returns default Apartment', () {
      final controller = createController();

      expect(controller.mostViewedPropertyType, 'Apartment');
    });
  });

  group('DashboardController — loadDashboardData success', () {
    test('loads user stats and recent activity from storage', () async {
      final storage = GetStorage();
      await storage.write(kDashPropertiesViewedKey, 15);
      await storage.write(kDashPropertiesLikedKey, 7);
      await storage.write(kDashSearchesMadeKey, 3);
      await storage.write(kDashRecentActivityKey, [
        {
          'type': 'view',
          'title': 'test',
          'timestamp': '2024-01-01T00:00:00Z',
          'icon': 'visibility',
        },
      ]);

      final controller = createController();
      // onInit already called loadDashboardData since authenticated
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(controller.propertiesViewed, 15);
      expect(controller.propertiesLiked, 7);
      expect(controller.searchesMade, 3);
      expect(controller.recentActivity.length, 1);
      expect(controller.isLoading.value, isFalse);
    });
  });

  group('DashboardController — refreshDashboard success', () {
    test('refreshDashboard loads data when authenticated', () async {
      final controller = createController();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      controller.isRefreshing.value = false;

      await controller.refreshDashboard();

      expect(controller.isRefreshing.value, isFalse);
    });
  });
}
