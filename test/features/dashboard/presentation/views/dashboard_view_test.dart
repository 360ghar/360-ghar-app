// test/features/dashboard/presentation/views/dashboard_view_test.dart

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/controllers/location_controller.dart';
import 'package:ghar360/core/controllers/page_state_service.dart';
import 'package:ghar360/core/data/models/likes_segment.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/user_model.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/assistant/presentation/controllers/assistant_controller.dart';
import 'package:ghar360/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:ghar360/features/dashboard/presentation/views/dashboard_view.dart';
import 'package:ghar360/features/discover/presentation/controllers/discover_controller.dart';
import 'package:ghar360/features/explore/presentation/controllers/explore_controller.dart';
import 'package:ghar360/features/likes/presentation/controllers/likes_controller.dart';
import 'package:ghar360/features/profile/presentation/controllers/profile_controller.dart';
import 'package:ghar360/features/visits/presentation/controllers/visits_controller.dart';
import '../../../../helpers/getx_test_binding.dart';
import '../../../../helpers/mocks.dart';
import '../../../../helpers/pump_app.dart';

// ---------------------------------------------------------------------------
// Stub controllers — lightweight implementations that avoid calling
// Get.find / GetStorage / navigation methods. Each provides the minimal
// reactive fields that the corresponding view reads during build.
// ---------------------------------------------------------------------------

/// Dashboard stub: avoids GetStorage (which creates a pending timer in tests).
class _StubDashboardController extends GetxServiceMock implements DashboardController {
  @override
  final RxInt currentIndex = 2.obs;
  @override
  final Set<int> visitedTabs = <int>{};

  @override
  void changeTab(int index) {
    if (currentIndex.value == index) return;
    visitedTabs.add(index);
    currentIndex.value = index;
  }
}

/// ProfileView stub: provides the reactive fields that ProfileView.build reads.
class _StubProfileController extends GetxServiceMock implements ProfileController {
  @override
  final RxBool isProfileLoading = false.obs;
  @override
  Rxn<UserModel> get currentUser => Rxn<UserModel>();
  @override
  bool get isLoading => isProfileLoading.value;
}

/// ExploreView stub.
class _StubExploreController extends GetxServiceMock implements ExploreController {
  @override
  void updateSearchQuery(String query) {}
}

/// DiscoverView stub.
class _StubDiscoverController extends GetxServiceMock implements DiscoverController {
  @override
  final Rx<DiscoverState> state = DiscoverState.initial.obs;
}

/// LikesView stub.
class _StubLikesController extends GetxServiceMock implements LikesController {
  @override
  final Rx<LikesSegment> currentSegment = LikesSegment.liked.obs;
  @override
  void updateSearchQuery(String query) {}
}

/// VisitsView stub.
class _StubVisitsController extends GetxServiceMock implements VisitsController {
  @override
  final RxBool isLoading = false.obs;
  @override
  final Rxn<AppException> error = Rxn<AppException>();
}

/// AssistantView stub.
class _StubAssistantController extends GetxServiceMock implements AssistantController {
  @override
  final Rxn<String> activeToolCall = Rxn<String>();
}

// ---------------------------------------------------------------------------
// Lightweight mock PageStateService for child views that call
// Get.find<PageStateService>() in their build methods.
// ---------------------------------------------------------------------------

class _MockPageStateService extends GetxServiceMock implements PageStateService {
  @override
  final Rx<PageStateModel> discoverState = PageStateModel.initial(PageType.discover).obs;
  @override
  final Rx<PageStateModel> likesState = PageStateModel.initial(PageType.likes).obs;
  @override
  final Rx<PageStateModel> exploreState = PageStateModel.initial(PageType.explore).obs;
  @override
  final Rx<PageType> currentPageType = PageType.discover.obs;

  @override
  bool isSearchVisible(PageType pageType) => false;

  @override
  PageStateModel getStateForPage(PageType pageType) {
    switch (pageType) {
      case PageType.explore:
        return exploreState.value;
      case PageType.discover:
        return discoverState.value;
      case PageType.likes:
        return likesState.value;
    }
  }

  @override
  LikesSegment get currentLikesSegment => LikesSegment.tryParse(
      likesState.value.getAdditionalData<String>('currentSegment'));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _MockPageStateService pageStateService;
  late MockAuthController authController;
  late MockLocationController locationController;

  setUp(() {
    GetxTestBinding.init();
    pageStateService = _MockPageStateService();
    authController = MockAuthController();
    locationController = MockLocationController();

    // Register dependencies needed by child views that get built when tabs
    // change. Also register stubs for all child view controllers so
    // Get.find<XController>() doesn't throw.
    GetxTestBinding.bind()
      ..register<PageStateService>(pageStateService)
      ..register<AuthController>(authController)
      ..register<LocationController>(locationController)
      ..register<ProfileController>(_StubProfileController())
      ..register<ExploreController>(_StubExploreController())
      ..register<DiscoverController>(_StubDiscoverController())
      ..register<LikesController>(_StubLikesController())
      ..register<VisitsController>(_StubVisitsController())
      ..register<AssistantController>(_StubAssistantController());
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  group('DashboardView', () {
    testWidgets('renders bottom navigation bar with 6 tabs', (tester) async {
      final controller = _StubDashboardController();
      Get.put<DashboardController>(controller);

      await tester.pumpApp(const DashboardView());
      // Flush any pending timers (e.g. from GetStorage in other controllers).
      await tester.pump(const Duration(seconds: 1));

      // The CustomBottomNavigationBar should be rendered.
      expect(find.byType(DashboardView), findsOneWidget);

      // Verify all 6 navigation items are present via their ValueKeys.
      expect(find.byKey(const ValueKey('qa.dashboard.nav.profile')), findsOneWidget);
      expect(find.byKey(const ValueKey('qa.dashboard.nav.explore_properties')), findsOneWidget);
      expect(find.byKey(const ValueKey('qa.dashboard.nav.discover')), findsOneWidget);
      expect(find.byKey(const ValueKey('qa.dashboard.nav.liked')), findsOneWidget);
      expect(find.byKey(const ValueKey('qa.dashboard.nav.visits')), findsOneWidget);
      expect(find.byKey(const ValueKey('qa.dashboard.nav.assistant')), findsOneWidget);
    });

    testWidgets('initial tab is Discover (index 2)', (tester) async {
      final controller = _StubDashboardController();
      Get.put<DashboardController>(controller);

      await tester.pumpApp(const DashboardView());
      await tester.pump();

      expect(controller.currentIndex.value, 2);

      // The IndexedStack should be present with semantics.
      expect(find.bySemanticsLabel('qa.dashboard.indexed_stack'), findsOneWidget);
    });

    testWidgets('tapping a nav item changes the active tab', (tester) async {
      final controller = _StubDashboardController();
      Get.put<DashboardController>(controller);

      await tester.pumpApp(const DashboardView());
      await tester.pump(const Duration(milliseconds: 500));

      // Tap the Profile tab (index 0) — this is safe since ProfileView
      // is rendered first and its stub provides all needed observables.
      await tester.tap(find.byKey(const ValueKey('qa.dashboard.nav.profile')));
      await tester.pump(const Duration(milliseconds: 500));

      expect(controller.currentIndex.value, 0);
    });

    testWidgets('tapping the same tab does not change the index', (tester) async {
      final controller = _StubDashboardController();
      Get.put<DashboardController>(controller);

      await tester.pumpApp(const DashboardView());
      await tester.pump();

      // Already on Discover (index 2); tap it again.
      await tester.tap(find.byKey(const ValueKey('qa.dashboard.nav.discover')));
      await tester.pump();

      expect(controller.currentIndex.value, 2);
    });

    testWidgets('switching tabs marks them as visited', (tester) async {
      final controller = _StubDashboardController();
      Get.put<DashboardController>(controller);

      await tester.pumpApp(const DashboardView());
      await tester.pump(const Duration(milliseconds: 500));

      // Initially, visitedTabs is empty.
      expect(controller.visitedTabs, isEmpty);

      // Tap Profile (index 0) — safe since ProfileView stub is complete.
      await tester.tap(find.byKey(const ValueKey('qa.dashboard.nav.profile')));
      await tester.pump(const Duration(milliseconds: 500));

      expect(controller.visitedTabs.contains(0), isTrue);
    });
  });
}
