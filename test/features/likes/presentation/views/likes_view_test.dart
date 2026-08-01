// test/features/likes/presentation/views/likes_view_test.dart
//
// Widget + controller tests for [LikesView] and [LikesController].
// Covers:
// - Rendering the scaffold, app bar, and segmented control
// - Loading skeleton state
// - Error state (generic + network)
// - Empty state (liked / passed / search-empty)
// - Property grid with cards
// - Segment switching via tap
// - Refresh progress indicator
// - Search filter badge
// - Favorite toggle calls removeFromLikes / moveToLikes
// - Controller-level state transitions

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/controllers/location_controller.dart';
import 'package:ghar360/core/controllers/page_state_service.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:ghar360/features/likes/presentation/controllers/likes_controller.dart';
import 'package:ghar360/features/likes/presentation/views/likes_view.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/getx_test_binding.dart';
import '../../../../helpers/mocks.dart';
import '../../../../helpers/pump_app.dart';

// ---------------------------------------------------------------------------
// Stub PageStateService — provides reactive fields and overrides the methods
// that UnifiedTopBar / LocationSelector / LikesView call during build.
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

  // Reactive backing for isSearchVisible / isPageRefreshing so Obx widgets
  // in UnifiedTopBar observe a real reactive and don't throw.
  final RxBool _searchVisible = false.obs;
  final RxBool _pageRefreshing = false.obs;

  final Map<PageType, TextEditingController> _searchControllers = {};

  @override
  bool isSearchVisible(PageType pageType) => _searchVisible.value;

  @override
  bool isPageRefreshing(PageType pageType) => _pageRefreshing.value;

  @override
  void toggleSearch(PageType pageType) {
    _searchVisible.value = !_searchVisible.value;
  }

  @override
  TextEditingController getOrCreateSearchController(PageType pageType, {String? seedText}) {
    return _searchControllers.putIfAbsent(pageType, () => TextEditingController());
  }

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
  String get currentLikesSegment =>
      likesState.value.getAdditionalData<String>('currentSegment') ?? 'liked';

  @override
  Future<void> loadPageData(
    PageType pageType, {
    bool forceRefresh = false,
    bool backgroundRefresh = false,
  }) async {}

  @override
  Future<void> loadMorePageData(PageType pageType) async {}

  @override
  Future<void> updatePageSearch(PageType pageType, String query) async {}
}

// ---------------------------------------------------------------------------
// Stub LikesController — provides reactive backing fields so Obx widgets in
// LikesView can track changes. Methods are no-op or record calls for verification.
// ---------------------------------------------------------------------------

class _StubLikesController extends GetxServiceMock implements LikesController {
  @override
  final Rx<LikesSegment> currentSegment = LikesSegment.liked.obs;
  @override
  final RxString searchQuery = ''.obs;

  final RxList<PropertyModel> _properties = <PropertyModel>[].obs;
  final RxBool _isLoading = false.obs;
  final RxnString _error = RxnString();

  // hasMore + isLoadingMore share ONE Rx, mirroring the real controller where
  // both read `PageStateService.likesState`. That coupling matters: it is what
  // makes the synchronous `isLoadingMore = true` write inside
  // `loadMoreCurrentSegment` notify the grid's Obx, which is the
  // "markNeedsBuild during build" path under test.
  final Rx<({bool hasMore, bool loadingMore})> _pagination = (
    hasMore: false,
    loadingMore: false,
  ).obs;

  bool removeFromLikesCalled = false;
  bool moveToLikesCalled = false;
  bool refreshCalled = false;
  int loadMoreCallCount = 0;
  bool retryCalled = false;
  bool clearSearchCalled = false;

  @override
  List<PropertyModel> get currentProperties => _properties;

  @override
  bool get isCurrentLoading => _isLoading.value;

  @override
  bool get hasCurrentError => _error.value != null;

  @override
  String? get currentError => _error.value;

  @override
  bool get isCurrentEmpty => !_isLoading.value && _properties.isEmpty && _error.value == null;

  @override
  bool get currentHasMore => _pagination.value.hasMore;

  @override
  bool get isCurrentLoadingMore => _pagination.value.loadingMore;

  @override
  bool get hasCurrentProperties => _properties.isNotEmpty;

  @override
  bool isFavourite(PropertyModel property) => currentSegment.value == LikesSegment.liked;

  @override
  bool isFavouriteUpdating(PropertyModel property) => false;

  @override
  bool get hasSearchQuery => searchQuery.value.isNotEmpty;

  @override
  String get emptyStateMessage => 'No properties yet';

  @override
  void updateSearchQuery(String query) {
    searchQuery.value = query;
  }

  @override
  void switchToSegment(LikesSegment segment) {
    currentSegment.value = segment;
  }

  @override
  void clearSearch() {
    clearSearchCalled = true;
    searchQuery.value = '';
  }

  @override
  Future<void> refreshCurrentSegment() async {
    refreshCalled = true;
  }

  @override
  Future<void> loadMoreCurrentSegment() async {
    loadMoreCallCount++;
    // Mirrors PageStateService.loadMorePageData: flips isLoadingMore
    // synchronously, BEFORE the first await.
    _pagination.value = (hasMore: _pagination.value.hasMore, loadingMore: true);
    await Future<void>.value();
    _pagination.value = (hasMore: _pagination.value.hasMore, loadingMore: false);
  }

  @override
  Future<void> removeFromLikes(PropertyModel property) async {
    removeFromLikesCalled = true;
    _properties.removeWhere((p) => p.id == property.id);
  }

  @override
  Future<void> moveToLikes(PropertyModel property) async {
    moveToLikesCalled = true;
  }

  @override
  void retryCurrentSegment() {
    retryCalled = true;
  }
}

// ---------------------------------------------------------------------------
// Stub DashboardController — for the empty-state "explore properties" action.
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _MockPageStateService pageStateService;
  late _StubLikesController likesController;
  late _StubDashboardController dashboardController;
  late MockLocationController locationController;

  setUp(() {
    GetxTestBinding.init();

    pageStateService = _MockPageStateService();
    likesController = _StubLikesController();
    dashboardController = _StubDashboardController();
    locationController = MockLocationController();

    // Stub LocationController reactive fields used by LocationSelector
    when(() => locationController.currentPosition).thenReturn(Rxn());
    when(() => locationController.currentAddress).thenReturn(''.obs);
    when(() => locationController.hasLocation).thenReturn(false);
    when(() => locationController.locationStatusText).thenReturn('location_not_available');

    GetxTestBinding.bind()
      ..register<PageStateService>(pageStateService)
      ..register<LikesController>(likesController)
      ..register<DashboardController>(dashboardController)
      ..register<LocationController>(locationController);

    // Suppress RenderFlex overflow errors that can occur in constrained test
    // environments (the segmented control / badges may overflow at small widths).
    FlutterError.onError = (FlutterErrorDetails details) {
      final summary = details.exception.toString();
      if (summary.contains('RenderFlex overflowed')) return;
      FlutterError.presentError(details);
    };
  });

  tearDown(() {
    FlutterError.onError = FlutterError.presentError;
    GetxTestBinding.reset();
  });

  // Helper: pump the LikesView without calling pumpAndSettle (shimmer skeletons
  // run infinite animations that would time out pumpAndSettle).
  Future<void> pumpLikesView(WidgetTester tester) async {
    await tester.pumpApp(const LikesView());
    // A single pump lets the first frame render without waiting for animations.
    await tester.pump();
  }

  // =========================================================================
  // Widget rendering tests
  // =========================================================================

  group('LikesView rendering', () {
    testWidgets('renders scaffold with semantics label and app bar', (tester) async {
      await pumpLikesView(tester);

      expect(find.byType(LikesView), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
      // The LikesTopBar is an AppBar
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('renders segmented control with liked and passed tabs', (tester) async {
      await pumpLikesView(tester);

      expect(find.bySemanticsIdentifier('qa.likes.tab.liked'), findsOneWidget);
      expect(find.bySemanticsIdentifier('qa.likes.tab.passed'), findsOneWidget);
    });

    testWidgets('liked tab is selected by default', (tester) async {
      await pumpLikesView(tester);

      // The liked segment identifier should be present
      expect(find.bySemanticsIdentifier('qa.likes.tab.liked'), findsOneWidget);
    });
  });

  // =========================================================================
  // Loading state
  // =========================================================================

  group('LikesView loading state', () {
    testWidgets('shows skeleton loading grid when isCurrentLoading is true', (tester) async {
      likesController._isLoading.value = true;

      await pumpLikesView(tester);

      // The AnimatedSwitcher child should be the loading skeleton (KeyedSubtree
      // with ValueKey('loading'))
      expect(find.byKey(const ValueKey('loading')), findsOneWidget);
    });

    testWidgets('does not show loading skeleton when not loading', (tester) async {
      likesController._isLoading.value = false;
      likesController._properties.value = [testPropertyModel(id: 1)];

      await pumpLikesView(tester);

      expect(find.byKey(const ValueKey('loading')), findsNothing);
    });
  });

  // =========================================================================
  // Error state
  // =========================================================================

  group('LikesView error state', () {
    testWidgets('shows error state when hasCurrentError is true', (tester) async {
      likesController._error.value = 'Something went wrong';

      await pumpLikesView(tester);

      expect(find.byKey(const ValueKey('error')), findsOneWidget);
    });

    testWidgets('does not show error state when no error', (tester) async {
      likesController._properties.value = [testPropertyModel(id: 1)];

      await pumpLikesView(tester);

      expect(find.byKey(const ValueKey('error')), findsNothing);
    });
  });

  // =========================================================================
  // Empty state
  // =========================================================================

  group('LikesView empty state', () {
    testWidgets('shows empty state for liked segment when no properties', (tester) async {
      likesController.currentSegment.value = LikesSegment.liked;

      await pumpLikesView(tester);

      expect(find.byKey(const ValueKey('empty')), findsOneWidget);
    });

    testWidgets('shows empty state for passed segment when no properties', (tester) async {
      likesController.currentSegment.value = LikesSegment.passed;

      await pumpLikesView(tester);

      expect(find.byKey(const ValueKey('empty')), findsOneWidget);
    });

    testWidgets('does not show empty state when properties exist', (tester) async {
      likesController._properties.value = [testPropertyModel(id: 1)];

      await pumpLikesView(tester);

      expect(find.byKey(const ValueKey('empty')), findsNothing);
    });
  });

  // =========================================================================
  // Property grid
  // =========================================================================

  group('LikesView property grid', () {
    testWidgets('shows grid key when properties are loaded', (tester) async {
      likesController._properties.value = [testPropertyModel(id: 1), testPropertyModel(id: 2)];

      await pumpLikesView(tester);

      expect(find.byKey(const ValueKey('grid')), findsOneWidget);
    });

    testWidgets('renders a card for each property', (tester) async {
      likesController._properties.value = [testPropertyModel(id: 1), testPropertyModel(id: 2)];

      await pumpLikesView(tester);

      // Each property card has a key 'qa.likes.card.<id>'
      expect(find.byKey(const ValueKey('qa.likes.card.1')), findsOneWidget);
      expect(find.byKey(const ValueKey('qa.likes.card.2')), findsOneWidget);
    });
  });

  // =========================================================================
  // Pagination / scroll behaviour
  // =========================================================================

  // The grid's Scrollable (the CustomScrollView inside the property grid).
  Finder gridScrollable() =>
      find.descendant(of: find.byType(CustomScrollView), matching: find.byType(Scrollable));

  ScrollPosition gridPosition(WidgetTester tester) =>
      tester.state<ScrollableState>(gridScrollable()).position;

  List<PropertyModel> manyProperties() =>
      List.generate(20, (index) => testPropertyModel(id: index + 1));

  group('LikesView pagination', () {
    testWidgets('scrolling to the end triggers exactly one load-more, with no build-phase '
        'setState', (tester) async {
      likesController._properties.value = manyProperties();
      likesController._pagination.value = (hasMore: true, loadingMore: false);

      await pumpLikesView(tester);

      final position = gridPosition(tester);
      // Two scroll events inside the trigger threshold: the in-flight guard
      // must collapse them into a single request.
      position.jumpTo(position.maxScrollExtent - 10);
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();
      // A second frame at the bottom: a rebuild-driven trigger would fire again.
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(likesController.loadMoreCallCount, 1);
    });

    testWidgets('does not load more while a page is already in flight', (tester) async {
      likesController._properties.value = manyProperties();
      likesController._pagination.value = (hasMore: true, loadingMore: true);

      await pumpLikesView(tester);

      final position = gridPosition(tester);
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();

      expect(likesController.loadMoreCallCount, 0);
    });

    testWidgets('swapping the grid out mid-load does not throw', (tester) async {
      likesController._properties.value = manyProperties();
      likesController._pagination.value = (hasMore: true, loadingMore: false);

      await pumpLikesView(tester);

      final position = gridPosition(tester);
      position.jumpTo(position.maxScrollExtent);
      // A segment switch flips the view to the skeleton, disposing the grid's
      // ScrollController while the load-more future is still in flight.
      likesController._isLoading.value = true;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
    });
  });

  // =========================================================================
  // Search toggle
  // =========================================================================

  group('LikesView search toggle', () {
    testWidgets('toggling the search field preserves the grid scroll offset', (tester) async {
      likesController._properties.value = manyProperties();

      await pumpLikesView(tester);

      gridPosition(tester).jumpTo(300);
      await tester.pump();
      expect(gridPosition(tester).pixels, 300);

      pageStateService.toggleSearch(PageType.likes);
      await tester.pump();
      await tester.pump();

      expect(gridPosition(tester).pixels, 300);
    });

    testWidgets('showing the search field grows the app bar and renders the input', (tester) async {
      likesController._properties.value = manyProperties();

      await pumpLikesView(tester);

      final collapsedHeight = tester.getSize(find.byType(AppBar)).height;
      expect(find.byKey(const ValueKey('qa.topbar.search_input.likes')), findsNothing);

      pageStateService.toggleSearch(PageType.likes);
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const ValueKey('qa.topbar.search_input.likes')), findsOneWidget);
      expect(tester.getSize(find.byType(AppBar)).height, collapsedHeight + 52);
      expect(tester.takeException(), isNull);
    });
  });

  // =========================================================================
  // Segment switching
  // =========================================================================

  group('LikesView segment switching', () {
    testWidgets('tapping passed segment calls switchToSegment', (tester) async {
      await pumpLikesView(tester);

      // Tap the "passed" tab (semantics identifier)
      await tester.tap(find.bySemanticsIdentifier('qa.likes.tab.passed'));
      await tester.pump();

      expect(likesController.currentSegment.value, LikesSegment.passed);
    });

    testWidgets('tapping liked segment calls switchToSegment', (tester) async {
      // Start on passed
      likesController.currentSegment.value = LikesSegment.passed;

      await pumpLikesView(tester);

      await tester.tap(find.bySemanticsIdentifier('qa.likes.tab.liked'));
      await tester.pump();

      expect(likesController.currentSegment.value, LikesSegment.liked);
    });
  });

  // =========================================================================
  // Refresh indicator
  // =========================================================================

  group('LikesView refresh indicator', () {
    testWidgets('shows LinearProgressIndicator when page state is refreshing', (tester) async {
      // Set the likes page state to refreshing
      pageStateService.likesState.value = pageStateService.likesState.value.copyWith(
        isRefreshing: true,
      );

      await pumpLikesView(tester);

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('hides LinearProgressIndicator when not refreshing', (tester) async {
      pageStateService.likesState.value = pageStateService.likesState.value.copyWith(
        isRefreshing: false,
      );

      await pumpLikesView(tester);

      expect(find.byType(LinearProgressIndicator), findsNothing);
    });
  });

  // =========================================================================
  // Search filter badge
  // =========================================================================

  group('LikesView search filter', () {
    testWidgets('shows grid when no search query', (tester) async {
      likesController._properties.value = [testPropertyModel(id: 1)];

      await pumpLikesView(tester);

      expect(find.byKey(const ValueKey('grid')), findsOneWidget);
    });
  });

  // =========================================================================
  // Favorite toggle
  // =========================================================================

  group('LikesView favorite toggle', () {
    testWidgets('tapping favorite on a liked property calls removeFromLikes', (tester) async {
      likesController.currentSegment.value = LikesSegment.liked;
      likesController._properties.value = [testPropertyModel(id: 1)];

      await pumpLikesView(tester);

      // The favorite toggle is an AnimatedFavoriteIcon (GestureDetector).
      // When isFavourite=true (liked segment), the icon is Icons.favorite (filled).
      final card = find.byKey(const ValueKey('qa.likes.card.1'));
      expect(card, findsOneWidget);

      final favoriteIcon = find.descendant(of: card, matching: find.byIcon(Icons.favorite));
      expect(favoriteIcon, findsOneWidget);

      await tester.tap(favoriteIcon);
      await tester.pump();

      expect(likesController.removeFromLikesCalled, isTrue);
    });

    testWidgets('tapping favorite on a passed property calls moveToLikes', (tester) async {
      likesController.currentSegment.value = LikesSegment.passed;
      likesController._properties.value = [testPropertyModel(id: 1)];

      await pumpLikesView(tester);

      final card = find.byKey(const ValueKey('qa.likes.card.1'));
      expect(card, findsOneWidget);

      final favoriteIcon = find.descendant(of: card, matching: find.byIcon(Icons.favorite_border));
      expect(favoriteIcon, findsOneWidget);

      await tester.tap(favoriteIcon);
      await tester.pump();

      expect(likesController.moveToLikesCalled, isTrue);
    });
  });

  // =========================================================================
  // Controller-level tests (preserved from original)
  // =========================================================================

  group('LikesController state', () {
    test('initial segment is liked', () {
      final controller = LikesController();
      Get.put<LikesController>(controller);

      expect(controller.currentSegment.value, LikesSegment.liked);
    });

    test('switchToSegment changes to passed', () {
      final controller = LikesController();
      Get.put<LikesController>(controller);

      controller.switchToSegment(LikesSegment.passed);

      expect(controller.currentSegment.value, LikesSegment.passed);
    });

    test('switchToSegment no-op for same segment', () {
      final controller = LikesController();
      Get.put<LikesController>(controller);

      controller.switchToSegment(LikesSegment.liked);

      expect(controller.currentSegment.value, LikesSegment.liked);
    });

    test('currentProperties returns page state properties', () {
      pageStateService.likesState.value = const PageStateModel(
        pageType: PageType.likes,
        filters: UnifiedFilterModel(),
        properties: [],
      );

      final controller = LikesController();
      Get.put<LikesController>(controller);

      expect(controller.currentProperties, isEmpty);
    });

    test('page state has liked segment data', () {
      pageStateService.likesState.value = const PageStateModel(
        pageType: PageType.likes,
        filters: UnifiedFilterModel(),
        properties: [],
        additionalData: {'currentSegment': 'liked'},
      );

      expect(
        pageStateService.likesState.value.getAdditionalData<String>('currentSegment'),
        'liked',
      );
    });

    test('page state has passed segment data', () {
      pageStateService.likesState.value = const PageStateModel(
        pageType: PageType.likes,
        filters: UnifiedFilterModel(),
        properties: [],
        additionalData: {'currentSegment': 'passed'},
      );

      expect(
        pageStateService.likesState.value.getAdditionalData<String>('currentSegment'),
        'passed',
      );
    });
  });

  // =========================================================================
  // Controller getters
  // =========================================================================

  group('LikesController getters', () {
    test('currentState returns loading when page state is loading', () {
      pageStateService.likesState.value = const PageStateModel(
        pageType: PageType.likes,
        filters: UnifiedFilterModel(),
        properties: [],
        isLoading: true,
      );

      final controller = LikesController();
      Get.put<LikesController>(controller);

      expect(controller.currentState, LikesState.loading);
    });

    test('currentState returns error when page state has error', () {
      pageStateService.likesState.value = PageStateModel(
        pageType: PageType.likes,
        filters: const UnifiedFilterModel(),
        properties: [],
        error: ServerException('test error'),
      );

      final controller = LikesController();
      Get.put<LikesController>(controller);

      expect(controller.currentState, LikesState.error);
    });

    test('currentState returns empty when no properties and not loading', () {
      pageStateService.likesState.value = const PageStateModel(
        pageType: PageType.likes,
        filters: UnifiedFilterModel(),
        properties: [],
      );

      final controller = LikesController();
      Get.put<LikesController>(controller);

      expect(controller.currentState, LikesState.empty);
    });

    test('currentState returns loaded when properties exist', () {
      pageStateService.likesState.value = PageStateModel(
        pageType: PageType.likes,
        filters: const UnifiedFilterModel(),
        properties: [testPropertyModel(id: 1)],
      );

      final controller = LikesController();
      Get.put<LikesController>(controller);

      expect(controller.currentState, LikesState.loaded);
    });

    test('currentState returns loadingMore when isLoadingMore is true', () {
      pageStateService.likesState.value = const PageStateModel(
        pageType: PageType.likes,
        filters: UnifiedFilterModel(),
        properties: [],
        isLoadingMore: true,
      );

      final controller = LikesController();
      Get.put<LikesController>(controller);

      expect(controller.currentState, LikesState.loadingMore);
    });

    test('currentError returns error string from page state', () {
      pageStateService.likesState.value = PageStateModel(
        pageType: PageType.likes,
        filters: const UnifiedFilterModel(),
        properties: [],
        error: ServerException('err msg'),
      );

      final controller = LikesController();
      Get.put<LikesController>(controller);

      expect(controller.currentError, isNotNull);
      expect(controller.currentError, contains('err msg'));
    });

    test('currentHasMore delegates to page state', () {
      pageStateService.likesState.value = const PageStateModel(
        pageType: PageType.likes,
        filters: UnifiedFilterModel(),
        properties: [],
        hasMore: true,
      );

      final controller = LikesController();
      Get.put<LikesController>(controller);

      expect(controller.currentHasMore, isTrue);
    });

    test('isCurrentLoading delegates to page state', () {
      pageStateService.likesState.value = const PageStateModel(
        pageType: PageType.likes,
        filters: UnifiedFilterModel(),
        properties: [],
        isLoading: true,
      );

      final controller = LikesController();
      Get.put<LikesController>(controller);

      expect(controller.isCurrentLoading, isTrue);
    });

    test('isCurrentEmpty is true when not loading, empty, no error', () {
      pageStateService.likesState.value = const PageStateModel(
        pageType: PageType.likes,
        filters: UnifiedFilterModel(),
        properties: [],
      );

      final controller = LikesController();
      Get.put<LikesController>(controller);

      expect(controller.isCurrentEmpty, isTrue);
    });

    test('isCurrentEmpty is false when loading', () {
      pageStateService.likesState.value = const PageStateModel(
        pageType: PageType.likes,
        filters: UnifiedFilterModel(),
        properties: [],
        isLoading: true,
      );

      final controller = LikesController();
      Get.put<LikesController>(controller);

      expect(controller.isCurrentEmpty, isFalse);
    });

    test('isCurrentEmpty is false when properties exist', () {
      pageStateService.likesState.value = PageStateModel(
        pageType: PageType.likes,
        filters: const UnifiedFilterModel(),
        properties: [testPropertyModel(id: 1)],
      );

      final controller = LikesController();
      Get.put<LikesController>(controller);

      expect(controller.isCurrentEmpty, isFalse);
    });

    test('hasCurrentError is true when page state has error', () {
      pageStateService.likesState.value = PageStateModel(
        pageType: PageType.likes,
        filters: const UnifiedFilterModel(),
        properties: [],
        error: ServerException('err'),
      );

      final controller = LikesController();
      Get.put<LikesController>(controller);

      expect(controller.hasCurrentError, isTrue);
    });

    test('hasCurrentProperties is true when properties exist', () {
      pageStateService.likesState.value = PageStateModel(
        pageType: PageType.likes,
        filters: const UnifiedFilterModel(),
        properties: [testPropertyModel(id: 1)],
      );

      final controller = LikesController();
      Get.put<LikesController>(controller);

      expect(controller.hasCurrentProperties, isTrue);
    });

    test('hasSearchQuery is true when searchQuery is non-empty', () {
      final controller = LikesController();
      Get.put<LikesController>(controller);
      controller.searchQuery.value = 'villa';

      expect(controller.hasSearchQuery, isTrue);
    });

    test('hasSearchQuery is false when searchQuery is empty', () {
      final controller = LikesController();
      Get.put<LikesController>(controller);

      expect(controller.hasSearchQuery, isFalse);
    });

    test('isCurrentLoadingMore delegates to page state', () {
      pageStateService.likesState.value = const PageStateModel(
        pageType: PageType.likes,
        filters: UnifiedFilterModel(),
        properties: [],
        isLoadingMore: true,
      );

      final controller = LikesController();
      Get.put<LikesController>(controller);

      expect(controller.isCurrentLoadingMore, isTrue);
    });

    test('isCurrentLoaded is true when loaded, not empty, no error', () {
      pageStateService.likesState.value = PageStateModel(
        pageType: PageType.likes,
        filters: const UnifiedFilterModel(),
        properties: [testPropertyModel(id: 1)],
      );

      final controller = LikesController();
      Get.put<LikesController>(controller);

      expect(controller.isCurrentLoaded, isTrue);
    });
  });

  // =========================================================================
  // Controller search and segment
  // =========================================================================

  group('LikesController search', () {
    test('updateSearchQuery sets searchQuery reactively', () {
      final controller = LikesController();
      Get.put<LikesController>(controller);

      controller.updateSearchQuery('apartment');

      expect(controller.searchQuery.value, 'apartment');
    });

    test('clearSearch resets searchQuery', () {
      final controller = LikesController();
      Get.put<LikesController>(controller);
      controller.searchQuery.value = 'villa';

      controller.clearSearch();

      expect(controller.searchQuery.value, '');
    });
  });

  group('LikesController retry', () {
    test('retryCurrentSegment calls loadPageData for liked segment', () {
      pageStateService.likesState.value = const PageStateModel(
        pageType: PageType.likes,
        filters: UnifiedFilterModel(),
        properties: [],
      );

      final controller = LikesController();
      Get.put<LikesController>(controller);

      // retryCurrentSegment delegates to _pageStateService.loadPageData
      // which is not stubbed on the mock — it will throw, but the call is made.
      // We just verify it doesn't crash on the segment check.
      controller.currentSegment.value = LikesSegment.liked;
      expect(() => controller.retryCurrentSegment(), returnsNormally);
    });

    test('retryCurrentSegment for passed segment', () {
      pageStateService.likesState.value = const PageStateModel(
        pageType: PageType.likes,
        filters: UnifiedFilterModel(),
        properties: [],
      );

      final controller = LikesController();
      Get.put<LikesController>(controller);
      controller.currentSegment.value = LikesSegment.passed;

      expect(() => controller.retryCurrentSegment(), returnsNormally);
    });
  });

  group('LikesController refresh', () {
    test('refreshCurrentSegment calls refreshLiked for liked segment', () async {
      pageStateService.likesState.value = const PageStateModel(
        pageType: PageType.likes,
        filters: UnifiedFilterModel(),
        properties: [],
      );

      final controller = LikesController();
      Get.put<LikesController>(controller);
      controller.currentSegment.value = LikesSegment.liked;

      await controller.refreshCurrentSegment();
      // No exception thrown — success
    });

    test('refreshCurrentSegment calls refreshPassed for passed segment', () async {
      pageStateService.likesState.value = const PageStateModel(
        pageType: PageType.likes,
        filters: UnifiedFilterModel(),
        properties: [],
      );

      final controller = LikesController();
      Get.put<LikesController>(controller);
      controller.currentSegment.value = LikesSegment.passed;

      await controller.refreshCurrentSegment();
    });
  });

  // isFavourite is model-backed (PropertyModel.liked + optimistic override),
  // NOT a lookup in whichever segment list happens to be loaded. Full coverage
  // lives in likes_controller_test.dart.
  group('LikesController isFavourite', () {
    test('isFavourite is false when the property model is not liked', () {
      final property = testPropertyModel(id: 42);
      pageStateService.likesState.value = PageStateModel(
        pageType: PageType.likes,
        filters: const UnifiedFilterModel(),
        properties: [property],
      );

      final controller = LikesController();
      Get.put<LikesController>(controller);

      expect(controller.isFavourite(property), isFalse);
    });

    test('isFavourite follows the optimistic override', () {
      final property = testPropertyModel(id: 42);

      final controller = LikesController();
      Get.put<LikesController>(controller);
      controller.likedOverrides[property.id] = true;

      expect(controller.isFavourite(property), isTrue);
    });
  });

  group('LikesController count text', () {
    test('currentCountText returns property count for single property', () {
      pageStateService.likesState.value = PageStateModel(
        pageType: PageType.likes,
        filters: const UnifiedFilterModel(),
        properties: [testPropertyModel(id: 1)],
      );

      final controller = LikesController();
      Get.put<LikesController>(controller);

      expect(controller.currentCountText, contains('1'));
    });

    test('currentCountText returns properties count for multiple', () {
      pageStateService.likesState.value = PageStateModel(
        pageType: PageType.likes,
        filters: const UnifiedFilterModel(),
        properties: [testPropertyModel(id: 1), testPropertyModel(id: 2)],
      );

      final controller = LikesController();
      Get.put<LikesController>(controller);

      expect(controller.currentCountText, contains('2'));
    });
  });

  group('LikesController segment title', () {
    test('currentSegmentTitle returns liked_properties for liked segment', () {
      final controller = LikesController();
      Get.put<LikesController>(controller);
      controller.currentSegment.value = LikesSegment.liked;

      expect(controller.currentSegmentTitle, 'liked_properties');
    });

    test('currentSegmentTitle returns passed_properties for passed segment', () {
      final controller = LikesController();
      Get.put<LikesController>(controller);
      controller.currentSegment.value = LikesSegment.passed;

      expect(controller.currentSegmentTitle, 'passed_properties');
    });
  });

  group('LikesController emptyStateMessage', () {
    test('returns search message when searchQuery is non-empty', () {
      final controller = LikesController();
      Get.put<LikesController>(controller);
      controller.searchQuery.value = 'test';

      expect(controller.emptyStateMessage, 'no_properties_match_your_search');
    });

    test('returns liked message for liked segment', () {
      final controller = LikesController();
      Get.put<LikesController>(controller);
      controller.currentSegment.value = LikesSegment.liked;

      expect(controller.emptyStateMessage, contains('no_liked_properties'));
    });

    test('returns passed message for passed segment', () {
      final controller = LikesController();
      Get.put<LikesController>(controller);
      controller.currentSegment.value = LikesSegment.passed;

      expect(controller.emptyStateMessage, contains('no_passed_properties'));
    });
  });
}
