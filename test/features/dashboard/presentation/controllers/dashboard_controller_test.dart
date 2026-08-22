// test/features/dashboard/presentation/controllers/dashboard_controller_test.dart
//
// Unit tests for [DashboardController]. Covers:
// - Initial state (currentIndex=2, visitedTabs={2})
// - changeTab updates index and adds to visitedTabs
// - syncTabWithRoute mapping
// - onReady page-type activation

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
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
  registerFallbackValue(PageType.discover);

  late MockAuthController mockAuthController;
  late MockPageStateService mockPageStateService;
  late Rx<PageType> currentPageType;

  setUp(() async {
    GetxTestBinding.init();

    mockAuthController = MockAuthController();
    mockPageStateService = MockPageStateService();

    // Auth setup
    when(() => mockAuthController.authStatus).thenReturn(AuthStatus.authenticated.obs);
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
  });

  // ─────────────────────────────────────────────────────────────────────
  // Additional tests for tab navigation and route syncing
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
}
