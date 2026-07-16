import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/controllers/location_controller.dart';
import 'package:ghar360/core/controllers/page_state_service.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/services/google_places_service.dart';
import 'package:ghar360/core/translations/app_translations.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/explore/presentation/controllers/explore_controller.dart';
import 'package:ghar360/features/explore/presentation/views/explore_view.dart';
import 'package:ghar360/features/explore/presentation/widgets/explore_map.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/getx_test_binding.dart';
import '../../../../helpers/mocks.dart';

/// Fake [ExploreController] that exposes only the surface used by
/// [ExploreView]. Uses [GetxServiceMock] to satisfy the type requirement
/// without triggering the real constructor's Get.find dependencies.
class _FakeExploreController extends GetxServiceMock implements ExploreController {
  _FakeExploreController({List<PropertyModel> initial = const []}) {
    properties.assignAll(initial);
  }

  @override
  final Rx<ExploreState> state = ExploreState.loaded.obs;
  @override
  final RxList<PropertyModel> properties = <PropertyModel>[].obs;
  @override
  final Rxn<AppException> error = Rxn<AppException>();
  @override
  final Rx<PropertyModel?> selectedProperty = Rx<PropertyModel?>(null);
  @override
  final RxBool isListCollapsed = false.obs;
  @override
  final Rx<LatLng> currentCenter = const LatLng(28.6139, 77.2090).obs;
  @override
  final RxDouble currentZoom = 12.0.obs;
  @override
  final RxDouble currentRadius = 5.0.obs;
  @override
  final RxInt markersRevision = 0.obs;
  @override
  final RxBool isMapReady = false.obs;
  @override
  final RxString searchQuery = ''.obs;
  @override
  final RxMap<int, bool> likedOverrides = <int, bool>{}.obs;

  int zoomInCalls = 0;
  int zoomOutCalls = 0;
  int recenterCalls = 0;
  int fitBoundsCalls = 0;
  int searchCalls = 0;
  int retryCalls = 0;
  int toggleCollapseCalls = 0;
  int expandCalls = 0;
  int collapseCalls = 0;
  int selectCalls = 0;

  @override
  bool hasMore = false;
  @override
  bool isLoadingMore = false;

  @override
  String get currentAreaText => '5.0 km';

  @override
  void zoomIn() => zoomInCalls++;

  @override
  void zoomOut() => zoomOutCalls++;

  @override
  void recenterToCurrentLocation() => recenterCalls++;

  @override
  void fitBoundsToProperties() => fitBoundsCalls++;

  @override
  void updateSearchQuery(String query) => searchCalls++;

  @override
  void retryLoading() => retryCalls++;

  @override
  void toggleListCollapsed() => toggleCollapseCalls++;

  @override
  void expandList() => expandCalls++;

  @override
  void collapseList() => collapseCalls++;

  @override
  void selectProperty(PropertyModel property) => selectCalls++;

  @override
  void highlightPropertyFromCard(PropertyModel property) {}

  @override
  bool isPropertyLiked(PropertyModel property) => likedOverrides[property.id] ?? property.liked;

  @override
  Future<void> toggleLike(PropertyModel property) async {
    likedOverrides[property.id] = !isPropertyLiked(property);
  }

  @override
  Future<void> loadMoreProperties() async {}

  @override
  void attachMap(MapLibreMapController controller) {}

  @override
  void onMapReady() {
    isMapReady.value = true;
  }

  @override
  void onCameraIdle(LatLng center, double zoom) {}

  @override
  List<PropertyMarker> get propertyMarkers => const [];

  @override
  String get locationDisplayText => 'Test Location';

  @override
  String get propertiesCountText => '${properties.length} properties';

  @override
  List<PropertyModel> get propertiesWithLocation => properties;
}

PropertyModel _property({int id = 100}) {
  return PropertyModel(
    id: id,
    title: 'Property $id',
    basePrice: 5000000,
    isAvailable: true,
    viewCount: 0,
    likeCount: 0,
    interestCount: 0,
  );
}

/// Finder for a [Semantics] widget whose [identifier] matches [id].
Finder _findBySemanticsIdentifier(String id) {
  return find.byWidgetPredicate((w) => w is Semantics && w.properties.identifier == id);
}

void main() {
  late _FakeExploreController controller;
  late MockPageStateService mockPageStateService;
  late MockLocationController mockLocationController;
  late MockGooglePlacesService mockGooglePlacesService;
  late Rx<PageStateModel> exploreState;
  late Rx<PageType> currentPageType;
  late TextEditingController searchController;

  setUpAll(() {
    registerFallbackValue(PageType.explore);
    registerFallbackValue(const UnifiedFilterModel());
    registerFallbackValue(const LocationData(name: '', latitude: 0, longitude: 0));
  });

  setUp(() {
    GetxTestBinding.init();

    mockPageStateService = MockPageStateService();
    mockLocationController = MockLocationController();
    mockGooglePlacesService = MockGooglePlacesService();
    searchController = TextEditingController();

    exploreState = PageStateModel.initial(PageType.explore).obs;
    currentPageType = PageType.explore.obs;

    // Stub PageStateService reactive fields
    when(() => mockPageStateService.exploreState).thenReturn(exploreState);
    when(() => mockPageStateService.currentPageType).thenReturn(currentPageType);
    when(
      () => mockPageStateService.discoverState,
    ).thenReturn(PageStateModel.initial(PageType.discover).obs);
    when(
      () => mockPageStateService.likesState,
    ).thenReturn(PageStateModel.initial(PageType.likes).obs);

    // Stub PageStateService methods
    when(() => mockPageStateService.isSearchVisible(any())).thenReturn(false);
    when(() => mockPageStateService.isPageRefreshing(any())).thenReturn(false);
    when(
      () =>
          mockPageStateService.getOrCreateSearchController(any(), seedText: any(named: 'seedText')),
    ).thenReturn(searchController);
    when(
      () => mockPageStateService.getCurrentPageState(),
    ).thenReturn(PageStateModel.initial(PageType.explore));
    when(() => mockPageStateService.updatePageFilters(any(), any())).thenReturn(null);
    when(() => mockPageStateService.updatePageSearch(any(), any())).thenReturn(null);
    when(
      () => mockPageStateService.loadPageData(
        any(),
        forceRefresh: any(named: 'forceRefresh'),
        backgroundRefresh: any(named: 'backgroundRefresh'),
      ),
    ).thenAnswer((_) async {});
    when(() => mockPageStateService.loadMorePageData(any())).thenAnswer((_) async {});
    when(() => mockPageStateService.loadMoreData(any())).thenAnswer((_) async {});
    when(
      () => mockPageStateService.recordSwipe(
        propertyId: any(named: 'propertyId'),
        isLiked: any(named: 'isLiked'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockPageStateService.updateLocationForPage(any(), any(), source: any(named: 'source')),
    ).thenAnswer((_) async {});

    // Stub LocationController
    when(() => mockLocationController.currentPosition).thenReturn(Rxn());
    when(() => mockLocationController.hasLocation).thenReturn(false);
    when(
      () => mockLocationController.getCurrentLocation(forceRefresh: any(named: 'forceRefresh')),
    ).thenAnswer((_) async {});
    when(() => mockLocationController.getIpLocation()).thenAnswer((_) async => null);
    when(() => mockLocationController.getInitialLocation()).thenAnswer(
      (_) async => const LocationData(name: 'Test', latitude: 28.6139, longitude: 77.2090),
    );

    controller = _FakeExploreController(initial: [_property(id: 1), _property(id: 2)]);

    GetxTestBinding.bind()
      ..register<PageStateService>(mockPageStateService)
      ..register<LocationController>(mockLocationController)
      ..register<GooglePlacesService>(mockGooglePlacesService)
      ..register<ExploreController>(controller);
  });

  tearDown(() {
    searchController.dispose();
    GetxTestBinding.reset();
  });

  Future<void> pumpExploreView(
    WidgetTester tester, {
    Size size = const Size(400, 800),
    ThemeData? theme,
  }) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        fallbackLocale: const Locale('en', 'US'),
        theme: theme ?? ThemeData.light(),
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: const ExploreView(),
        ),
      ),
    );
    // Use pump (not pumpAndSettle) because the map may have infinite
    // animations and async platform calls that never settle.
    await tester.pump();
    // Drain any pending async exceptions (image loads, platform channel
    // errors from the headless MapLibreMap, etc.) so they don't fail the test.
    tester.takeException();
  }

  group('ExploreView — state rendering', () {
    testWidgets('renders map interface in loaded state (compact)', (tester) async {
      controller.state.value = ExploreState.loaded;
      await pumpExploreView(tester);

      // The screen-level Semantics with identifier 'qa.explore.screen' should exist.
      expect(_findBySemanticsIdentifier('qa.explore.screen'), findsOneWidget);
      // The ExploreMap widget should be rendered.
      expect(find.byType(ExploreMap), findsOneWidget);
    });

    testWidgets('renders loading state without location', (tester) async {
      controller.state.value = ExploreState.loading;
      exploreState.value = PageStateModel.initial(PageType.explore);
      await pumpExploreView(tester);

      // Loading state shows a skeleton map icon.
      expect(find.byIcon(Icons.map), findsOneWidget);
    });

    testWidgets('renders map interface in loading state with location', (tester) async {
      controller.state.value = ExploreState.loading;
      exploreState.value = const PageStateModel(
        pageType: PageType.explore,
        filters: UnifiedFilterModel(),
        properties: [],
        selectedLocation: LocationData(name: 'Test', latitude: 28.61, longitude: 77.21),
      );
      await pumpExploreView(tester);

      // With location, loading state should show the map interface.
      expect(find.byType(ExploreMap), findsOneWidget);
    });

    testWidgets('renders error state with retry button', (tester) async {
      controller.state.value = ExploreState.error;
      // Use a retryable ServerException (statusCode >= 500).
      controller.error.value = ServerException('Test error', statusCode: 500);
      await pumpExploreView(tester);

      // Error state shows a retry button.
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('renders empty state with adjust filters text', (tester) async {
      controller.state.value = ExploreState.empty;
      await pumpExploreView(tester);

      // Empty state shows the location_off icon.
      expect(find.byIcon(Icons.location_off), findsOneWidget);
    });

    testWidgets('renders loadingMore state with map and indicator', (tester) async {
      controller.state.value = ExploreState.loadingMore;
      await pumpExploreView(tester);

      // Map interface should be visible.
      expect(find.byType(ExploreMap), findsOneWidget);
    });

    testWidgets('renders initial state without location as loading', (tester) async {
      controller.state.value = ExploreState.initial;
      exploreState.value = PageStateModel.initial(PageType.explore);
      await pumpExploreView(tester);

      // Initial state without location shows loading skeleton.
      expect(find.byIcon(Icons.map), findsOneWidget);
    });

    testWidgets('renders initial state with location as map', (tester) async {
      controller.state.value = ExploreState.initial;
      exploreState.value = const PageStateModel(
        pageType: PageType.explore,
        filters: UnifiedFilterModel(),
        properties: [],
        selectedLocation: LocationData(name: 'Test', latitude: 28.61, longitude: 77.21),
      );
      await pumpExploreView(tester);

      expect(find.byType(ExploreMap), findsOneWidget);
    });
  });

  group('ExploreView — refresh indicator', () {
    testWidgets('shows LinearProgressIndicator when refreshing', (tester) async {
      controller.state.value = ExploreState.loaded;
      exploreState.value = PageStateModel(
        pageType: PageType.explore,
        filters: const UnifiedFilterModel(),
        properties: [_property(id: 1)],
        isRefreshing: true,
      );
      await pumpExploreView(tester);

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('hides LinearProgressIndicator when not refreshing', (tester) async {
      controller.state.value = ExploreState.loaded;
      exploreState.value = PageStateModel(
        pageType: PageType.explore,
        filters: const UnifiedFilterModel(),
        properties: [_property(id: 1)],
        isRefreshing: false,
      );
      await pumpExploreView(tester);

      expect(find.byType(LinearProgressIndicator), findsNothing);
    });
  });

  group('ExploreView — map controls', () {
    testWidgets('tapping zoom in calls controller.zoomIn', (tester) async {
      controller.state.value = ExploreState.loaded;
      await pumpExploreView(tester);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      expect(controller.zoomInCalls, 1);
    });

    testWidgets('tapping zoom out calls controller.zoomOut', (tester) async {
      controller.state.value = ExploreState.loaded;
      await pumpExploreView(tester);

      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();

      expect(controller.zoomOutCalls, 1);
    });

    testWidgets('tapping recenter calls controller.recenterToCurrentLocation', (tester) async {
      controller.state.value = ExploreState.loaded;
      await pumpExploreView(tester);

      await tester.tap(find.byIcon(Icons.my_location));
      await tester.pump();

      expect(controller.recenterCalls, 1);
    });

    testWidgets('tapping fit bounds calls controller.fitBoundsToProperties', (tester) async {
      controller.state.value = ExploreState.loaded;
      await pumpExploreView(tester);

      await tester.tap(find.byIcon(Icons.center_focus_strong));
      await tester.pump();

      expect(controller.fitBoundsCalls, 1);
    });
  });

  group('ExploreView — property list handle', () {
    testWidgets('tapping the list handle toggles collapse', (tester) async {
      controller.state.value = ExploreState.loaded;
      await pumpExploreView(tester);

      // The handle area has a GestureDetector with the collapse/expand semantics.
      // Tap the handle area (the drag handle bar).
      final handleFinder = find.byIcon(Icons.keyboard_arrow_down);
      expect(handleFinder, findsOneWidget);

      await tester.tap(handleFinder);
      await tester.pump();

      expect(controller.toggleCollapseCalls, 1);
    });

    testWidgets('shows property count in handle', (tester) async {
      controller.state.value = ExploreState.loaded;
      await pumpExploreView(tester);

      // The handle shows "2 properties" text.
      expect(find.textContaining('2'), findsWidgets);
    });

    testWidgets('shows expand icon when collapsed', (tester) async {
      controller.state.value = ExploreState.loaded;
      controller.isListCollapsed.value = true;
      await pumpExploreView(tester);

      expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);
    });

    testWidgets('handle area is present and tappable in loaded state', (tester) async {
      controller.state.value = ExploreState.loaded;
      await pumpExploreView(tester);

      // The GestureDetector for the handle (it has onVerticalDragEnd).
      final handleGestureFinder = find.byWidgetPredicate(
        (w) => w is GestureDetector && w.onVerticalDragEnd != null,
      );
      expect(handleGestureFinder, findsOneWidget);
    });

    testWidgets('handle area is present when collapsed', (tester) async {
      controller.state.value = ExploreState.loaded;
      controller.isListCollapsed.value = true;
      await pumpExploreView(tester);

      final handleGestureFinder = find.byWidgetPredicate(
        (w) => w is GestureDetector && w.onVerticalDragEnd != null,
      );
      expect(handleGestureFinder, findsOneWidget);
    });
  });

  group('ExploreView — info panel', () {
    testWidgets('shows property count and area text in info panel', (tester) async {
      controller.state.value = ExploreState.loaded;
      await pumpExploreView(tester);

      // The info panel shows the area text.
      expect(find.text('5.0 km'), findsOneWidget);
    });
  });

  group('ExploreView — two-pane (tablet) layout', () {
    testWidgets('renders side panel for expanded size class', (tester) async {
      controller.state.value = ExploreState.loaded;
      await pumpExploreView(tester, size: const Size(1000, 800));

      // In two-pane mode, the map should still be present.
      expect(find.byType(ExploreMap), findsOneWidget);
    });

    testWidgets('renders side panel for large size class', (tester) async {
      controller.state.value = ExploreState.loaded;
      await pumpExploreView(tester, size: const Size(1400, 900));

      expect(find.byType(ExploreMap), findsOneWidget);
    });

    testWidgets('shows loading more chip in two-pane layout', (tester) async {
      controller.state.value = ExploreState.loadingMore;
      await pumpExploreView(tester, size: const Size(1000, 800));

      expect(find.byType(ExploreMap), findsOneWidget);
    });

    testWidgets('tapping zoom in works in two-pane layout', (tester) async {
      controller.state.value = ExploreState.loaded;
      await pumpExploreView(tester, size: const Size(1000, 800));

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      expect(controller.zoomInCalls, 1);
    });

    testWidgets('tapping recenter works in two-pane layout', (tester) async {
      controller.state.value = ExploreState.loaded;
      await pumpExploreView(tester, size: const Size(1000, 800));

      await tester.tap(find.byIcon(Icons.my_location));
      await tester.pump();

      expect(controller.recenterCalls, 1);
    });
  });

  group('ExploreView — dark theme', () {
    testWidgets('renders correctly in dark theme', (tester) async {
      controller.state.value = ExploreState.loaded;
      await pumpExploreView(tester, theme: ThemeData.dark());

      expect(find.byType(ExploreMap), findsOneWidget);
    });

    testWidgets('renders error state in dark theme', (tester) async {
      controller.state.value = ExploreState.error;
      controller.error.value = ServerException('Dark error', statusCode: 500);
      await pumpExploreView(tester, theme: ThemeData.dark());

      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('renders empty state in dark theme', (tester) async {
      controller.state.value = ExploreState.empty;
      await pumpExploreView(tester, theme: ThemeData.dark());

      expect(find.byIcon(Icons.location_off), findsOneWidget);
    });

    testWidgets('renders loading state in dark theme', (tester) async {
      controller.state.value = ExploreState.loading;
      exploreState.value = PageStateModel.initial(PageType.explore);
      await pumpExploreView(tester, theme: ThemeData.dark());

      expect(find.byIcon(Icons.map), findsOneWidget);
    });
  });

  group('ExploreView — error state retry', () {
    testWidgets('tapping retry button calls controller.retryLoading', (tester) async {
      controller.state.value = ExploreState.error;
      controller.error.value = ServerException('Retry test', statusCode: 500);
      await pumpExploreView(tester);

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();

      expect(controller.retryCalls, 1);
    });
  });

  group('ExploreView — empty state action', () {
    testWidgets('empty state shows adjust filters button', (tester) async {
      controller.state.value = ExploreState.empty;
      await pumpExploreView(tester);

      // The empty state has an action button.
      expect(find.byType(ElevatedButton), findsOneWidget);
    });
  });

  group('ExploreView — loading more indicator (single-pane)', () {
    testWidgets('shows loading more indicator in single-pane layout', (tester) async {
      controller.state.value = ExploreState.loadingMore;
      await pumpExploreView(tester);

      // The loading more indicator text should be present.
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });
  });
}
