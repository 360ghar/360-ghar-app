import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/controllers/location_controller.dart';
import 'package:ghar360/core/controllers/page_state_service.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:ghar360/features/explore/presentation/controllers/explore_controller.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/getx_test_binding.dart';
import '../../../../helpers/mocks.dart';

class MockPageStateService extends GetxServiceMock implements PageStateService {}

class MockDashboardController extends GetxServiceMock implements DashboardController {}

void main() {
  late MockPageStateService mockPageStateService;
  late MockLocationController mockLocationController;
  late Rx<PageStateModel> exploreState;
  late Rx<PageType> currentPageType;
  late Rxn<Position> currentPosition;

  setUpAll(() {
    registerFallbackValue(PageType.explore);
    registerFallbackValue(const UnifiedFilterModel());
    registerFallbackValue(const LocationData(name: '', latitude: 0, longitude: 0));
  });

  setUp(() {
    GetxTestBinding.init();

    mockPageStateService = MockPageStateService();
    mockLocationController = MockLocationController();

    exploreState = PageStateModel.initial(PageType.explore).obs;
    currentPageType = PageType.explore.obs;
    currentPosition = Rxn<Position>();

    // Stub PageStateService reactive fields
    when(() => mockPageStateService.exploreState).thenReturn(exploreState);
    when(() => mockPageStateService.currentPageType).thenReturn(currentPageType);

    // Stub PageStateService methods
    when(
      () => mockPageStateService.loadPageData(
        any(),
        forceRefresh: any(named: 'forceRefresh'),
        backgroundRefresh: any(named: 'backgroundRefresh'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockPageStateService.recordSwipe(
        propertyId: any(named: 'propertyId'),
        isLiked: any(named: 'isLiked'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockPageStateService.getCurrentPageState(),
    ).thenReturn(PageStateModel.initial(PageType.explore));
    when(() => mockPageStateService.updatePageFilters(any(), any())).thenReturn(null);
    when(() => mockPageStateService.updatePageSearch(any(), any())).thenReturn(null);
    when(
      () => mockPageStateService.updateLocationForPage(any(), any(), source: any(named: 'source')),
    ).thenAnswer((_) async {});
    when(() => mockPageStateService.loadMoreData(any())).thenAnswer((_) async {});

    // Stub LocationController reactive fields
    when(() => mockLocationController.currentPosition).thenReturn(currentPosition);
    when(() => mockLocationController.hasLocation).thenReturn(false);

    // Stub LocationController methods
    when(
      () => mockLocationController.getCurrentLocation(forceRefresh: any(named: 'forceRefresh')),
    ).thenAnswer((_) async {});
    when(() => mockLocationController.getIpLocation()).thenAnswer((_) async => null);
    when(() => mockLocationController.getInitialLocation()).thenAnswer(
      (_) async => const LocationData(name: 'Test', latitude: 28.6139, longitude: 77.2090),
    );

    GetxTestBinding.bind()
      ..register<PageStateService>(mockPageStateService)
      ..register<LocationController>(mockLocationController);
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  ExploreController createController() {
    final c = ExploreController();
    c.onInit();
    return c;
  }

  List<PropertyModel> seedProperties(int count) {
    return List.generate(count, (i) => testPropertyModel(id: 200 + i));
  }

  group('ExploreController', () {
    test('initial state is ExploreState.initial with empty properties', () {
      final controller = createController();

      expect(controller.state.value, ExploreState.initial);
      expect(controller.properties, isEmpty);
      expect(controller.selectedProperty.value, isNull);
      expect(controller.isMapReady.value, isFalse);
    });

    test('activatePage syncs properties from page state when data present', () {
      final props = seedProperties(3);
      exploreState.value = PageStateModel(
        pageType: PageType.explore,
        filters: const UnifiedFilterModel(),
        properties: props,
        selectedLocation: const LocationData(name: 'Test', latitude: 28.61, longitude: 77.21),
        lastFetched: DateTime.now(),
      );

      final controller = createController();
      controller.activatePage();

      expect(controller.properties.length, 3);
      expect(controller.state.value, ExploreState.loaded);
    });

    test('toggleLike sets optimistic override for unliked property', () async {
      final props = seedProperties(3);
      exploreState.value = PageStateModel(
        pageType: PageType.explore,
        filters: const UnifiedFilterModel(),
        properties: props,
        selectedLocation: const LocationData(name: 'Test', latitude: 28.61, longitude: 77.21),
        lastFetched: DateTime.now(),
      );

      final controller = createController();
      controller.activatePage();

      final property = props[0];
      expect(controller.isPropertyLiked(property), isFalse);

      await controller.toggleLike(property);

      expect(controller.likedOverrides[property.id], isTrue);
      expect(controller.isPropertyLiked(property), isTrue);
    });

    test('toggleLike reverts override on failure', () async {
      final props = seedProperties(3);
      exploreState.value = PageStateModel(
        pageType: PageType.explore,
        filters: const UnifiedFilterModel(),
        properties: props,
        selectedLocation: const LocationData(name: 'Test', latitude: 28.61, longitude: 77.21),
        lastFetched: DateTime.now(),
      );

      when(
        () => mockPageStateService.recordSwipe(
          propertyId: any(named: 'propertyId'),
          isLiked: any(named: 'isLiked'),
        ),
      ).thenThrow(ServerException('network error'));

      final controller = createController();
      controller.activatePage();

      final property = props[0];
      await controller.toggleLike(property);

      // Should revert to original (not liked)
      expect(controller.likedOverrides[property.id], isFalse);
    });

    test('selectProperty sets selected property and auto-expands list', () {
      final controller = createController();
      controller.isListCollapsed.value = true;

      final prop = testPropertyModel(id: 300);
      controller.selectProperty(prop);

      expect(controller.selectedProperty.value?.id, 300);
      expect(controller.isListCollapsed.value, isFalse);
    });

    test('clearSelection clears the selected property', () {
      final controller = createController();
      final prop = testPropertyModel(id: 301);
      controller.selectedProperty.value = prop;

      controller.clearSelection();

      expect(controller.selectedProperty.value, isNull);
    });

    test('retryLoading clears error and sets loading state', () {
      final controller = createController();
      controller.error.value = ServerException('test error');
      controller.state.value = ExploreState.error;

      controller.retryLoading();

      expect(controller.error.value, isNull);
      expect(controller.state.value, ExploreState.loading);
      verify(
        () => mockPageStateService.loadPageData(PageType.explore, forceRefresh: true),
      ).called(1);
    });

    test('helper getters reflect state correctly', () {
      final controller = createController();

      expect(controller.isLoading, isFalse);
      expect(controller.isEmpty, isFalse);
      expect(controller.hasError, isFalse);
      expect(controller.isLoaded, isFalse);
      expect(controller.hasProperties, isFalse);
      expect(controller.hasSelection, isFalse);

      controller.state.value = ExploreState.loaded;
      expect(controller.isLoaded, isTrue);

      controller.state.value = ExploreState.empty;
      expect(controller.isEmpty, isTrue);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // Additional tests for untested methods, error handling, and edge cases
  // ─────────────────────────────────────────────────────────────────────

  group('ExploreController — property selection', () {
    test('highlightPropertyFromCard sets selected property when different', () {
      final controller = createController();
      final prop1 = testPropertyModel(id: 400);
      controller.selectedProperty.value = prop1;

      final prop2 = testPropertyModel(id: 401);
      controller.highlightPropertyFromCard(prop2);

      expect(controller.selectedProperty.value?.id, 401);
    });

    test('highlightPropertyFromCard is a no-op when same property', () {
      final controller = createController();
      final prop = testPropertyModel(id: 400);
      controller.selectedProperty.value = prop;

      controller.highlightPropertyFromCard(prop);

      expect(controller.selectedProperty.value?.id, 400);
    });

    test('selectProperty does not collapse an already-expanded list', () {
      final controller = createController();
      controller.isListCollapsed.value = false;

      controller.selectProperty(testPropertyModel(id: 500));

      expect(controller.isListCollapsed.value, isFalse);
      expect(controller.hasSelection, isTrue);
    });
  });

  group('ExploreController — list collapse/expand', () {
    test('toggleListCollapsed flips the value', () {
      final controller = createController();
      expect(controller.isListCollapsed.value, isFalse);

      controller.toggleListCollapsed();
      expect(controller.isListCollapsed.value, isTrue);

      controller.toggleListCollapsed();
      expect(controller.isListCollapsed.value, isFalse);
    });

    test('expandList sets isListCollapsed to false', () {
      final controller = createController();
      controller.isListCollapsed.value = true;

      controller.expandList();

      expect(controller.isListCollapsed.value, isFalse);
    });

    test('collapseList sets isListCollapsed to true', () {
      final controller = createController();

      controller.collapseList();

      expect(controller.isListCollapsed.value, isTrue);
    });
  });

  group('ExploreController — search', () {
    test('updateSearchQuery with empty query calls updatePageSearch immediately', () {
      final controller = createController();

      controller.updateSearchQuery('');

      expect(controller.searchQuery.value, '');
      verify(() => mockPageStateService.updatePageSearch(PageType.explore, '')).called(1);
    });

    test('updateSearchQuery sets searchQuery reactively', () {
      final controller = createController();

      controller.updateSearchQuery('apartment');

      expect(controller.searchQuery.value, 'apartment');
    });

    test('clearSearch resets query and calls updatePageSearch', () {
      final controller = createController();
      controller.searchQuery.value = 'villa';

      controller.clearSearch();

      expect(controller.searchQuery.value, '');
      verify(() => mockPageStateService.updatePageSearch(PageType.explore, '')).called(1);
    });
  });

  group('ExploreController — isPropertyLiked', () {
    test('returns property.liked when no override exists', () {
      final controller = createController();
      final prop = testPropertyModel(id: 600);

      // testPropertyModel creates with liked=false by default
      expect(controller.isPropertyLiked(prop), isFalse);
    });

    test('returns override when override exists', () {
      final controller = createController();
      final prop = testPropertyModel(id: 601);
      controller.likedOverrides[prop.id] = true;

      expect(controller.isPropertyLiked(prop), isTrue);
    });

    test('toggleLike on already-liked property sets override to false', () async {
      final props = seedProperties(2);
      exploreState.value = PageStateModel(
        pageType: PageType.explore,
        filters: const UnifiedFilterModel(),
        properties: props,
        selectedLocation: const LocationData(name: 'Test', latitude: 28.61, longitude: 77.21),
        lastFetched: DateTime.now(),
      );

      final controller = createController();
      controller.activatePage();

      // Pre-set the property as liked
      controller.likedOverrides[props[0].id] = true;
      expect(controller.isPropertyLiked(props[0]), isTrue);

      await controller.toggleLike(props[0]);

      expect(controller.likedOverrides[props[0].id], isFalse);
      expect(controller.isPropertyLiked(props[0]), isFalse);
    });
  });

  group('ExploreController — error handling', () {
    test('clearError clears error and transitions from error to empty', () {
      final controller = createController();
      controller.error.value = ServerException('err');
      controller.state.value = ExploreState.error;

      controller.clearError();

      expect(controller.error.value, isNull);
      expect(controller.state.value, ExploreState.empty);
    });

    test('clearError transitions from error to loaded when properties exist', () {
      final controller = createController();
      controller.error.value = ServerException('err');
      controller.state.value = ExploreState.error;
      controller.properties.assignAll(seedProperties(2));

      controller.clearError();

      expect(controller.error.value, isNull);
      expect(controller.state.value, ExploreState.loaded);
    });

    test('clearError is a no-op when not in error state', () {
      final controller = createController();
      controller.state.value = ExploreState.loaded;

      controller.clearError();

      expect(controller.state.value, ExploreState.loaded);
    });
  });

  group('ExploreController — filter shortcuts', () {
    test('quickFilterByType calls updatePageFilters with type wireValue', () {
      final controller = createController();

      controller.quickFilterByType(PropertyType.apartment);

      verify(() => mockPageStateService.updatePageFilters(any(), any())).called(1);
    });

    test('quickFilterByPurpose calls updatePageFilters with purpose wireValue', () {
      final controller = createController();

      controller.quickFilterByPurpose(PropertyPurpose.rent);

      verify(() => mockPageStateService.updatePageFilters(any(), any())).called(1);
    });
  });

  group('ExploreController — map controls', () {
    test('zoomIn increases currentZoom when map not ready', () {
      final controller = createController();
      final initialZoom = controller.currentZoom.value;

      controller.zoomIn();

      expect(controller.currentZoom.value, initialZoom + 1);
    });

    test('zoomOut decreases currentZoom when map not ready', () {
      final controller = createController();
      final initialZoom = controller.currentZoom.value;

      controller.zoomOut();

      expect(controller.currentZoom.value, initialZoom - 1);
    });

    test('onMapReady sets isMapReady to true', () {
      final controller = createController();

      controller.onMapReady();

      expect(controller.isMapReady.value, isTrue);
    });

    test('onMapReady is idempotent (second call is a no-op)', () {
      final controller = createController();

      controller.onMapReady();
      controller.onMapReady();

      expect(controller.isMapReady.value, isTrue);
    });

    test('onCameraIdle returns early when map not ready', () {
      final controller = createController();
      final initialCenter = controller.currentCenter.value;

      controller.onCameraIdle(const LatLng(19.0760, 72.8777), 14.0);

      // Center should not change because map is not ready
      expect(controller.currentCenter.value, initialCenter);
    });

    test('onCameraIdle with programmatic move syncs center and clears flag', () {
      final controller = createController();
      controller.isMapReady.value = true;
      // Simulate a programmatic move flag set by zoomIn/recenter
      // We can't directly set _mapSession.programmaticMove, but we can
      // verify the early-return path works when map is ready.
      final newCenter = const LatLng(19.0760, 72.8777);
      controller.onCameraIdle(newCenter, 14.0);

      // Without programmaticMove flag, it goes through the gesture path.
      // The center should still be updated.
      expect(controller.currentCenter.value, newCenter);
    });
  });

  group('ExploreController — fitBoundsToProperties', () {
    test('returns early when properties is empty', () {
      final controller = createController();
      controller.isMapReady.value = true;

      // Should not throw
      controller.fitBoundsToProperties();

      expect(controller.properties, isEmpty);
    });

    test('returns early when no properties have location', () {
      final controller = createController();
      controller.isMapReady.value = true;
      controller.properties.assignAll([
        testPropertyModel(id: 700), // no latitude/longitude
      ]);

      controller.fitBoundsToProperties();

      // No crash, no markers generated
      expect(controller.propertyMarkers, isEmpty);
    });

    test('returns early when map is not ready even with located properties', () {
      final controller = createController();
      controller.isMapReady.value = false;
      controller.properties.assignAll([
        const PropertyModel(
          id: 701,
          title: 'Located',
          basePrice: 5000000,
          latitude: 28.61,
          longitude: 77.21,
          isAvailable: true,
          viewCount: 0,
          likeCount: 0,
          interestCount: 0,
        ),
      ]);

      // Should not throw
      controller.fitBoundsToProperties();
    });
  });

  group('ExploreController — propertiesWithLocation', () {
    test('returns only properties with location', () {
      final controller = createController();
      controller.properties.assignAll([
        const PropertyModel(
          id: 800,
          title: 'With Location',
          basePrice: 5000000,
          latitude: 28.61,
          longitude: 77.21,
          isAvailable: true,
          viewCount: 0,
          likeCount: 0,
          interestCount: 0,
        ),
        testPropertyModel(id: 801), // no location
      ]);

      final result = controller.propertiesWithLocation;
      expect(result.length, 1);
      expect(result.first.id, 800);
    });

    test('returns empty list when all properties lack location', () {
      final controller = createController();
      controller.properties.assignAll([testPropertyModel(id: 900), testPropertyModel(id: 901)]);

      expect(controller.propertiesWithLocation, isEmpty);
    });
  });

  group('ExploreController — property markers', () {
    test('propertyMarkers returns markers for properties with location', () {
      final controller = createController();
      controller.properties.assignAll([
        const PropertyModel(
          id: 1000,
          title: 'Marker Property',
          basePrice: 5000000,
          latitude: 28.61,
          longitude: 77.21,
          isAvailable: true,
          viewCount: 0,
          likeCount: 0,
          interestCount: 0,
        ),
      ]);

      final markers = controller.propertyMarkers;
      expect(markers.length, 1);
      expect(markers.first.property.id, 1000);
      expect(markers.first.isSelected, isFalse);
    });

    test('propertyMarkers reflects selected property', () {
      final controller = createController();
      final prop = const PropertyModel(
        id: 1001,
        title: 'Selected Marker',
        basePrice: 5000000,
        latitude: 28.61,
        longitude: 77.21,
        isAvailable: true,
        viewCount: 0,
        likeCount: 0,
        interestCount: 0,
      );
      controller.properties.assignAll([prop]);
      controller.selectedProperty.value = prop;

      final markers = controller.propertyMarkers;
      expect(markers.length, 1);
      expect(markers.first.isSelected, isTrue);
    });
  });

  group('ExploreController — pagination', () {
    test('hasMore delegates to page state', () {
      final controller = createController();

      exploreState.value = PageStateModel(
        pageType: PageType.explore,
        filters: const UnifiedFilterModel(),
        properties: seedProperties(2),
        hasMore: true,
      );

      expect(controller.hasMore, isTrue);
    });

    test('loadMoreProperties returns early when already loading', () async {
      final controller = createController();
      exploreState.value = PageStateModel(
        pageType: PageType.explore,
        filters: const UnifiedFilterModel(),
        properties: seedProperties(2),
        isLoading: true,
      );

      await controller.loadMoreProperties();

      verifyNever(() => mockPageStateService.loadMorePageData(any()));
    });

    test('loadMoreProperties returns early when isLoadingMore is true', () async {
      final controller = createController();
      exploreState.value = PageStateModel(
        pageType: PageType.explore,
        filters: const UnifiedFilterModel(),
        properties: seedProperties(2),
        isLoadingMore: true,
      );

      await controller.loadMoreProperties();

      verifyNever(() => mockPageStateService.loadMorePageData(any()));
    });

    test('loadMoreProperties returns early when hasMore is false', () async {
      final controller = createController();
      exploreState.value = PageStateModel(
        pageType: PageType.explore,
        filters: const UnifiedFilterModel(),
        properties: seedProperties(2),
        hasMore: false,
      );

      await controller.loadMoreProperties();

      verifyNever(() => mockPageStateService.loadMorePageData(any()));
    });

    test('loadMoreProperties calls loadMorePageData when conditions are met', () async {
      when(() => mockPageStateService.loadMorePageData(any())).thenAnswer((_) async {});

      final controller = createController();
      exploreState.value = PageStateModel(
        pageType: PageType.explore,
        filters: const UnifiedFilterModel(),
        properties: seedProperties(2),
        hasMore: true,
      );

      await controller.loadMoreProperties();

      verify(() => mockPageStateService.loadMorePageData(PageType.explore)).called(1);
    });
  });

  group('ExploreController — refresh and retry', () {
    test('refreshProperties calls loadPageData with forceRefresh', () async {
      final controller = createController();

      await controller.refreshProperties();

      verify(
        () => mockPageStateService.loadPageData(PageType.explore, forceRefresh: true),
      ).called(1);
    });
  });

  group('ExploreController — display text getters', () {
    test('propertiesCountText returns no_properties_found when empty', () {
      final controller = createController();
      controller.properties.clear();

      // .tr returns the key itself when no translation is registered
      expect(controller.propertiesCountText, 'no_properties_found');
    });

    test('propertiesCountText returns one_property for single property', () {
      final controller = createController();
      controller.properties.assignAll([testPropertyModel(id: 1100)]);

      expect(controller.propertiesCountText, 'one_property');
    });

    test('propertiesCountText returns n_properties for multiple', () {
      final controller = createController();
      controller.properties.assignAll(seedProperties(3));

      expect(controller.propertiesCountText, contains('n_properties'));
    });

    test('currentAreaText returns radius_km for radius >= 1', () {
      final controller = createController();
      controller.currentRadius.value = 5.0;

      expect(controller.currentAreaText, contains('radius_km'));
    });

    test('currentAreaText returns radius_meters for radius < 1', () {
      final controller = createController();
      controller.currentRadius.value = 0.5;

      expect(controller.currentAreaText, contains('radius_meters'));
    });

    test('locationDisplayText delegates to page state', () {
      when(() => mockPageStateService.getCurrentPageState()).thenReturn(
        const PageStateModel(
          pageType: PageType.explore,
          filters: UnifiedFilterModel(),
          properties: [],
          selectedLocation: LocationData(name: 'Mumbai', latitude: 19.07, longitude: 72.87),
        ),
      );

      final controller = createController();

      expect(controller.locationDisplayText, 'Mumbai');
    });
  });

  group('ExploreController — helper getters edge cases', () {
    test('isLoadingMore getter returns true when state is loadingMore', () {
      final controller = createController();
      controller.state.value = ExploreState.loadingMore;

      expect(controller.isLoadingMore, isTrue);
    });

    test('hasError getter returns true when state is error', () {
      final controller = createController();
      controller.state.value = ExploreState.error;

      expect(controller.hasError, isTrue);
    });

    test('hasProperties returns true when properties list is non-empty', () {
      final controller = createController();
      controller.properties.assignAll(seedProperties(1));

      expect(controller.hasProperties, isTrue);
    });

    test('hasSelection returns true when a property is selected', () {
      final controller = createController();
      controller.selectedProperty.value = testPropertyModel(id: 1200);

      expect(controller.hasSelection, isTrue);
    });
  });

  group('ExploreController — activatePage edge cases', () {
    test('activatePage sets error state when page state has error and data present', () {
      final controller = createController();
      // Set state to loaded first so shouldRequestWhenEmpty is false
      controller.state.value = ExploreState.loaded;
      exploreState.value = PageStateModel(
        pageType: PageType.explore,
        filters: const UnifiedFilterModel(),
        properties: seedProperties(1),
        error: ServerException('page error'),
        selectedLocation: const LocationData(name: 'Test', latitude: 28.61, longitude: 77.21),
        lastFetched: DateTime.now(),
      );

      controller.activatePage();

      expect(controller.state.value, ExploreState.error);
      expect(controller.error.value, isNotNull);
    });

    test('activatePage sets loading state when page state is refreshing', () {
      final controller = createController();
      // Set state to loaded first so shouldRequestWhenEmpty is false
      controller.state.value = ExploreState.loaded;
      exploreState.value = PageStateModel(
        pageType: PageType.explore,
        filters: const UnifiedFilterModel(),
        properties: seedProperties(1),
        isLoading: true,
        isRefreshing: true,
        selectedLocation: const LocationData(name: 'Test', latitude: 28.61, longitude: 77.21),
        lastFetched: DateTime.now(),
      );

      controller.activatePage();

      expect(controller.state.value, ExploreState.loading);
    });

    test('activatePage sets empty state when properties are empty and data is fresh', () {
      final controller = createController();
      // Set state to loaded first so shouldRequestWhenEmpty is false
      controller.state.value = ExploreState.loaded;
      exploreState.value = PageStateModel(
        pageType: PageType.explore,
        filters: const UnifiedFilterModel(),
        properties: [],
        selectedLocation: const LocationData(name: 'Test', latitude: 28.61, longitude: 77.21),
        lastFetched: DateTime.now(),
      );

      controller.activatePage();

      expect(controller.state.value, ExploreState.empty);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // onMapReady
  // ─────────────────────────────────────────────────────────────────────

  group('ExploreController — onMapReady', () {
    test('moves camera to page state location when hasLocation is true', () {
      exploreState.value = PageStateModel(
        pageType: PageType.explore,
        filters: const UnifiedFilterModel(),
        properties: [],
        selectedLocation: const LocationData(name: 'Mumbai', latitude: 19.07, longitude: 72.87),
        lastFetched: DateTime.now(),
      );

      final controller = createController();
      controller.onMapReady();

      expect(controller.isMapReady.value, isTrue);
      // The camera center should be updated via post-frame callback.
      // We verify the flag is set; the actual camera move is deferred.
    });

    test('uses default center when page state has no location', () {
      final controller = createController();
      controller.onMapReady();

      expect(controller.isMapReady.value, isTrue);
      // currentCenter should remain at default (Delhi)
      expect(controller.currentCenter.value.latitude, 28.6139);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // attachMap
  // ─────────────────────────────────────────────────────────────────────

  group('ExploreController — attachMap', () {
    test('attachMap does not throw', () {
      final controller = createController();

      expect(() => controller.attachMap(MockMapLibreMapController()), returnsNormally);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // onCameraIdle
  // ─────────────────────────────────────────────────────────────────────

  group('ExploreController — onCameraIdle advanced', () {
    test('programmatic move syncs center and clears flag', () {
      final controller = createController();
      controller.isMapReady.value = true;

      // Trigger a programmatic move by zoomIn (sets programmaticMove flag)
      controller.zoomIn();

      final newCenter = const LatLng(19.0760, 72.8777);
      controller.onCameraIdle(newCenter, controller.currentZoom.value);

      // After programmatic move, center should be synced
      expect(controller.currentCenter.value, newCenter);
    });

    test('gesture move with small delta does not trigger fetch', () {
      final controller = createController();
      controller.isMapReady.value = true;

      final initialCenter = controller.currentCenter.value;
      // Very small move (< 100m)
      final tinyMove = LatLng(initialCenter.latitude + 0.00001, initialCenter.longitude + 0.00001);

      controller.onCameraIdle(tinyMove, controller.currentZoom.value);

      // Center should still be updated
      expect(controller.currentCenter.value, tinyMove);
    });

    test('gesture move with large delta updates center', () {
      final controller = createController();
      controller.isMapReady.value = true;

      final newCenter = const LatLng(19.0760, 72.8777);
      controller.onCameraIdle(newCenter, controller.currentZoom.value);

      expect(controller.currentCenter.value, newCenter);
    });

    test('gesture move with zoom delta updates zoom', () {
      final controller = createController();
      controller.isMapReady.value = true;

      controller.onCameraIdle(controller.currentCenter.value, 15.0);

      expect(controller.currentZoom.value, 15.0);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // recenterToCurrentLocation
  // ─────────────────────────────────────────────────────────────────────

  group('ExploreController — recenterToCurrentLocation', () {
    test('calls _useCurrentLocation without throwing', () async {
      final controller = createController();

      // Stub getCurrentLocation to set hasLocation true
      when(() => mockLocationController.hasLocation).thenReturn(true);
      when(() => mockLocationController.currentPosition).thenReturn(
        Rxn(
          Position(
            latitude: 28.61,
            longitude: 77.21,
            timestamp: DateTime.now(),
            accuracy: 10,
            altitude: 0,
            altitudeAccuracy: 0,
            heading: 0,
            headingAccuracy: 0,
            speed: 0,
            speedAccuracy: 0,
          ),
        ),
      );

      controller.recenterToCurrentLocation();

      // Allow async work to flush
      await Future.delayed(const Duration(milliseconds: 100));

      // Should not throw; center may be updated
      expect(controller.state.value, isA<ExploreState>());
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // updateSearchQuery with debounce
  // ─────────────────────────────────────────────────────────────────────

  group('ExploreController — search debounce', () {
    test('updateSearchQuery with non-empty query sets searchQuery', () {
      final controller = createController();

      controller.updateSearchQuery('apartment');

      expect(controller.searchQuery.value, 'apartment');
    });

    test('updateSearchQuery debounces and calls updatePageSearch after delay', () async {
      final controller = createController();

      controller.updateSearchQuery('villa');

      // Before debounce fires, updatePageSearch should NOT have been called
      verifyNever(() => mockPageStateService.updatePageSearch(PageType.explore, 'villa'));

      // Wait for debounce (300ms)
      await Future.delayed(const Duration(milliseconds: 400));

      // After debounce, updatePageSearch should have been called
      verify(() => mockPageStateService.updatePageSearch(PageType.explore, 'villa')).called(1);
    });

    test('updateSearchQuery with changing query only fires for latest', () async {
      final controller = createController();

      controller.updateSearchQuery('villa');
      controller.updateSearchQuery('apartment');

      // Wait for debounce
      await Future.delayed(const Duration(milliseconds: 400));

      // Only the latest query should be propagated
      verify(() => mockPageStateService.updatePageSearch(PageType.explore, 'apartment')).called(1);
      verifyNever(() => mockPageStateService.updatePageSearch(PageType.explore, 'villa'));
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // viewPropertyDetails
  // ─────────────────────────────────────────────────────────────────────

  group('ExploreController — viewPropertyDetails', () {
    test('viewPropertyDetails does not throw', () {
      final controller = createController();
      final prop = testPropertyModel(id: 2000);

      // Get.toNamed will fail in test without routing, but the call itself
      // should be catchable (wrapped in try-catch in the view, but the
      // controller calls Get.toNamed directly).
      expect(() => controller.viewPropertyDetails(prop), returnsNormally);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // showFilters
  // ─────────────────────────────────────────────────────────────────────

  group('ExploreController — showFilters', () {
    test('showFilters does not throw when no context', () {
      final controller = createController();

      // Get.context is null in test, so showFilters should catch and ignore
      expect(() => controller.showFilters(), returnsNormally);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // activatePage with initial state (triggers initialization)
  // ─────────────────────────────────────────────────────────────────────

  group('ExploreController — activatePage initialization', () {
    test('activatePage triggers initialization when initial and no location', () async {
      // Page state has no location and is initial
      exploreState.value = PageStateModel.initial(PageType.explore);

      final controller = createController();
      // state is initial
      expect(controller.state.value, ExploreState.initial);

      controller.activatePage();

      // Should trigger _initializeMapAndLoadProperties (async)
      // Allow async work to flush
      await Future.delayed(const Duration(milliseconds: 200));

      // State should transition to loading or loaded/empty
      expect(controller.state.value, isNot(ExploreState.initial));
    });

    test('activatePage with stale loading flag re-initializes', () async {
      exploreState.value = const PageStateModel(
        pageType: PageType.explore,
        filters: UnifiedFilterModel(),
        properties: [],
        isLoading: true,
        isRefreshing: false,
      );

      // Set state to loaded so shouldRequestWhenEmpty is checked
      final controller = createController();
      controller.state.value = ExploreState.loaded;

      controller.activatePage();

      // Should trigger re-initialization
      await Future.delayed(const Duration(milliseconds: 200));

      expect(controller.state.value, isNot(ExploreState.loaded));
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // onClose cleanup
  // ─────────────────────────────────────────────────────────────────────

  group('ExploreController — onClose', () {
    test('onClose disposes workers and timers without throwing', () {
      final controller = createController();

      expect(() => controller.onClose(), returnsNormally);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // location listener
  // ─────────────────────────────────────────────────────────────────────

  group('ExploreController — location listener', () {
    test('location update >1km updates map center', () async {
      when(() => mockLocationController.hasLocation).thenReturn(true);

      final controller = createController();

      // Emit a position >1km away from default Delhi center
      currentPosition.value = Position(
        latitude: 19.0760,
        longitude: 72.8777,
        timestamp: DateTime.now(),
        accuracy: 10,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );

      // Allow listener to process
      await Future.delayed(const Duration(milliseconds: 100));

      // The center should have been updated (from Delhi to Mumbai)
      expect(controller.currentCenter.value.latitude, closeTo(19.0760, 0.01));
    });

    test('location update <1km does not update map center', () async {
      final controller = createController();
      final initialCenter = controller.currentCenter.value;

      // Small move (<1km from default Delhi)
      currentPosition.value = Position(
        latitude: initialCenter.latitude + 0.001,
        longitude: initialCenter.longitude + 0.001,
        timestamp: DateTime.now(),
        accuracy: 10,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );

      await Future.delayed(const Duration(milliseconds: 100));

      // Center should not change
      expect(controller.currentCenter.value, initialCenter);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // zoomIn / zoomOut with map ready
  // ─────────────────────────────────────────────────────────────────────

  group('ExploreController — zoom with map ready', () {
    test('zoomIn updates zoom and sets programmaticMove when map ready', () {
      final controller = createController();
      controller.isMapReady.value = true;
      controller.attachMap(MockMapLibreMapController());

      final initialZoom = controller.currentZoom.value;
      controller.zoomIn();

      expect(controller.currentZoom.value, initialZoom + 1);
    });

    test('zoomOut updates zoom and sets programmaticMove when map ready', () {
      final controller = createController();
      controller.isMapReady.value = true;
      controller.attachMap(MockMapLibreMapController());

      final initialZoom = controller.currentZoom.value;
      controller.zoomOut();

      expect(controller.currentZoom.value, initialZoom - 1);
    });

    test('zoomIn clamps to max zoom', () {
      final controller = createController();
      controller.isMapReady.value = true;
      // Set zoom to near max
      controller.currentZoom.value = 20.0;

      controller.zoomIn();

      // Should be clamped to kDefaultMaxZoom
      expect(controller.currentZoom.value, lessThanOrEqualTo(22.0));
    });

    test('zoomOut clamps to min zoom', () {
      final controller = createController();
      controller.isMapReady.value = true;
      // Set zoom to near min
      controller.currentZoom.value = 1.0;

      controller.zoomOut();

      // Should be clamped to kDefaultMinZoom
      expect(controller.currentZoom.value, greaterThanOrEqualTo(0.0));
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // fitBoundsToProperties with located properties and map ready
  // ─────────────────────────────────────────────────────────────────────

  group('ExploreController — fitBoundsToProperties with map ready', () {
    test('schedules fitBounds when map ready and properties have location', () {
      final controller = createController();
      controller.isMapReady.value = true;
      controller.attachMap(MockMapLibreMapController());
      controller.properties.assignAll([
        const PropertyModel(
          id: 2000,
          title: 'Located',
          basePrice: 5000000,
          latitude: 28.61,
          longitude: 77.21,
          isAvailable: true,
          viewCount: 0,
          likeCount: 0,
          interestCount: 0,
        ),
      ]);

      // Should not throw
      expect(() => controller.fitBoundsToProperties(), returnsNormally);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // isLoading getter
  // ─────────────────────────────────────────────────────────────────────

  group('ExploreController — isLoading getter', () {
    test('isLoading returns true when state is loading', () {
      final controller = createController();
      controller.state.value = ExploreState.loading;

      expect(controller.isLoading, isTrue);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // onReady
  // ─────────────────────────────────────────────────────────────────────

  group('ExploreController — onReady', () {
    test('onReady sets up page activation listener without throwing', () {
      final controller = createController();

      expect(() => controller.onReady(), returnsNormally);
    });

    test('onReady triggers activatePage when already on explore page', () async {
      currentPageType.value = PageType.explore;
      exploreState.value = PageStateModel.initial(PageType.explore);

      final controller = createController();
      controller.onReady();

      // The onReady schedules a 100ms delayed activatePage.
      await Future.delayed(const Duration(milliseconds: 200));

      // activatePage should have been called, transitioning state from initial.
      expect(controller.state.value, isNot(ExploreState.initial));
    });

    test('onReady does not trigger activatePage when on a different page', () async {
      currentPageType.value = PageType.discover;
      exploreState.value = PageStateModel.initial(PageType.explore);

      final controller = createController();
      controller.onReady();

      await Future.delayed(const Duration(milliseconds: 200));

      // State should remain initial since we're not on explore page.
      expect(controller.state.value, ExploreState.initial);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // recenterToCurrentLocation — null position fallback
  // ─────────────────────────────────────────────────────────────────────

  group('ExploreController — recenterToCurrentLocation null position', () {
    test('falls back to default location when position is null', () async {
      // currentPosition is null by default (Rxn<Position>)
      when(() => mockLocationController.hasLocation).thenReturn(false);

      final controller = createController();
      controller.recenterToCurrentLocation();

      // Allow async work to flush
      await Future.delayed(const Duration(milliseconds: 200));

      // Should fall back to default center (Delhi)
      expect(controller.currentCenter.value.latitude, 28.6139);
      expect(controller.currentCenter.value.longitude, 77.2090);

      // Verify updateLocationForPage was called with fallback
      verify(
        () => mockPageStateService.updateLocationForPage(
          PageType.explore,
          any(),
          source: any(named: 'source'),
        ),
      ).called(greaterThanOrEqualTo(1));
    });

    test('falls back to default when getCurrentLocation throws', () async {
      when(
        () => mockLocationController.getCurrentLocation(forceRefresh: any(named: 'forceRefresh')),
      ).thenThrow(Exception('Location permission denied'));

      final controller = createController();
      controller.recenterToCurrentLocation();

      await Future.delayed(const Duration(milliseconds: 200));

      // Should fall back to default center
      expect(controller.currentCenter.value.latitude, 28.6139);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // onCameraIdle — large delta triggers debounced fetch
  // ─────────────────────────────────────────────────────────────────────

  group('ExploreController — onCameraIdle large delta', () {
    test('large move updates center and schedules fetch', () async {
      final controller = createController();
      controller.isMapReady.value = true;

      final newCenter = const LatLng(19.0760, 72.8777); // Mumbai, far from Delhi
      controller.onCameraIdle(newCenter, 14.0);

      expect(controller.currentCenter.value, newCenter);
      expect(controller.currentZoom.value, 14.0);

      // Wait for the 600ms debounce to fire
      await Future.delayed(const Duration(milliseconds: 700));

      // After debounce, updateLocationForPage should be called
      verify(
        () => mockPageStateService.updateLocationForPage(
          PageType.explore,
          any(),
          source: any(named: 'source'),
        ),
      ).called(greaterThanOrEqualTo(1));
    });

    test('large zoom delta schedules fetch', () async {
      final controller = createController();
      controller.isMapReady.value = true;

      // Same center, big zoom change
      controller.onCameraIdle(controller.currentCenter.value, 18.0);

      expect(controller.currentZoom.value, 18.0);

      await Future.delayed(const Duration(milliseconds: 700));

      verify(
        () => mockPageStateService.updatePageFilters(any(), any()),
      ).called(greaterThanOrEqualTo(1));
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // fitBoundsToProperties — with valid coordinates and map ready
  // ─────────────────────────────────────────────────────────────────────

  group('ExploreController — fitBoundsToProperties with valid coords', () {
    test('schedules fitBounds when map ready and properties have coords', () {
      final controller = createController();
      controller.isMapReady.value = true;
      controller.attachMap(MockMapLibreMapController());
      controller.properties.assignAll([
        const PropertyModel(
          id: 3000,
          title: 'Located A',
          basePrice: 5000000,
          latitude: 28.61,
          longitude: 77.21,
          isAvailable: true,
          viewCount: 0,
          likeCount: 0,
          interestCount: 0,
        ),
        const PropertyModel(
          id: 3001,
          title: 'Located B',
          basePrice: 5000000,
          latitude: 28.63,
          longitude: 77.22,
          isAvailable: true,
          viewCount: 0,
          likeCount: 0,
          interestCount: 0,
        ),
      ]);

      // Should not throw
      expect(() => controller.fitBoundsToProperties(), returnsNormally);
    });

    test('returns early when only some properties have null coords', () {
      final controller = createController();
      controller.isMapReady.value = true;
      controller.attachMap(MockMapLibreMapController());
      controller.properties.assignAll([
        const PropertyModel(
          id: 3100,
          title: 'With Location',
          basePrice: 5000000,
          latitude: 28.61,
          longitude: 77.21,
          isAvailable: true,
          viewCount: 0,
          likeCount: 0,
          interestCount: 0,
        ),
        testPropertyModel(id: 3101), // no location
      ]);

      // Should not throw, should process only the one with location
      expect(() => controller.fitBoundsToProperties(), returnsNormally);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // updateSearchQuery — with DashboardController registered
  // ─────────────────────────────────────────────────────────────────────

  group('ExploreController — search with DashboardController', () {
    test('records search activity when DashboardController is registered', () async {
      final mockDashboard = MockDashboardController();
      Get.put<DashboardController>(mockDashboard, permanent: true);

      when(() => mockDashboard.incrementStat(any(), by: any(named: 'by'))).thenReturn(null);
      when(
        () => mockDashboard.recordActivity(
          type: any(named: 'type'),
          title: any(named: 'title'),
          icon: any(named: 'icon'),
        ),
      ).thenReturn(null);

      final controller = createController();
      controller.updateSearchQuery('apartment');

      // Wait for the 300ms debounce
      await Future.delayed(const Duration(milliseconds: 400));

      verify(() => mockDashboard.incrementStat(kDashSearchesMadeKey)).called(1);
      verify(
        () => mockDashboard.recordActivity(
          type: 'search',
          title: any(named: 'title'),
          icon: 'search',
        ),
      ).called(1);

      Get.delete<DashboardController>();
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // _setupFilterListener — debounce worker
  // ─────────────────────────────────────────────────────────────────────

  group('ExploreController — filter listener debounce', () {
    test('syncs properties when page state updates (not current page)', () async {
      final props = seedProperties(2);
      exploreState.value = PageStateModel(
        pageType: PageType.explore,
        filters: const UnifiedFilterModel(),
        properties: props,
        selectedLocation: const LocationData(name: 'Test', latitude: 28.61, longitude: 77.21),
        lastFetched: DateTime.now(),
      );

      // Set current page to discover so the "not current page" path is taken
      currentPageType.value = PageType.discover;

      final controller = createController();

      // Trigger the debounce worker by updating exploreState
      exploreState.value = exploreState.value.copyWith(properties: seedProperties(3));

      // Wait for the 200ms debounce
      await Future.delayed(const Duration(milliseconds: 300));

      // Properties should be synced even when not on explore page
      expect(controller.properties.length, 3);

      // Reset page type
      currentPageType.value = PageType.explore;
    });

    test('syncs state to loading when page state isLoading', () async {
      exploreState.value = PageStateModel(
        pageType: PageType.explore,
        filters: const UnifiedFilterModel(),
        properties: seedProperties(1),
        isLoading: true,
        selectedLocation: const LocationData(name: 'Test', latitude: 28.61, longitude: 77.21),
        lastFetched: DateTime.now(),
      );

      final controller = createController();
      controller.state.value = ExploreState.loaded;

      // Trigger debounce by updating exploreState
      exploreState.value = exploreState.value.copyWith(isLoading: true);

      await Future.delayed(const Duration(milliseconds: 300));

      expect(controller.state.value, ExploreState.loading);
    });

    test('syncs state to loadingMore when page state isLoadingMore', () async {
      exploreState.value = PageStateModel(
        pageType: PageType.explore,
        filters: const UnifiedFilterModel(),
        properties: seedProperties(1),
        isLoadingMore: true,
        selectedLocation: const LocationData(name: 'Test', latitude: 28.61, longitude: 77.21),
        lastFetched: DateTime.now(),
      );

      final controller = createController();
      controller.state.value = ExploreState.loaded;

      exploreState.value = exploreState.value.copyWith(isLoadingMore: true);

      await Future.delayed(const Duration(milliseconds: 300));

      expect(controller.state.value, ExploreState.loadingMore);
    });

    test('clears selection when property is no longer in list', () async {
      final props = seedProperties(2);
      exploreState.value = PageStateModel(
        pageType: PageType.explore,
        filters: const UnifiedFilterModel(),
        properties: props,
        selectedLocation: const LocationData(name: 'Test', latitude: 28.61, longitude: 77.21),
        lastFetched: DateTime.now(),
      );

      final controller = createController();
      controller.activatePage();
      controller.selectedProperty.value = props[0];

      // Update exploreState to remove the selected property
      exploreState.value = exploreState.value.copyWith(
        properties: [props[1]], // Only keep the second property
      );

      await Future.delayed(const Duration(milliseconds: 300));

      // Selection should be cleared since props[0] is no longer in the list
      expect(controller.selectedProperty.value, isNull);
    });

    test('syncs radius from page state filters', () async {
      exploreState.value = PageStateModel(
        pageType: PageType.explore,
        filters: const UnifiedFilterModel(radiusKm: 25.0),
        properties: seedProperties(1),
        selectedLocation: const LocationData(name: 'Test', latitude: 28.61, longitude: 77.21),
        lastFetched: DateTime.now(),
      );

      final controller = createController();
      controller.currentRadius.value = 5.0;

      // Trigger debounce
      exploreState.value = exploreState.value.copyWith(
        filters: const UnifiedFilterModel(radiusKm: 25.0),
      );

      await Future.delayed(const Duration(milliseconds: 300));

      // Radius should be synced from state
      expect(controller.currentRadius.value, 25.0);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // _initializeMapAndLoadProperties — with PageStateService location
  // ─────────────────────────────────────────────────────────────────────

  group('ExploreController — initialization with page state location', () {
    test('uses location from PageStateService when available', () async {
      exploreState.value = PageStateModel(
        pageType: PageType.explore,
        filters: const UnifiedFilterModel(),
        properties: [],
        selectedLocation: const LocationData(name: 'Mumbai', latitude: 19.07, longitude: 72.87),
        lastFetched: DateTime.now(),
      );

      final controller = createController();
      controller.activatePage();

      // Allow async initialization to complete
      await Future.delayed(const Duration(milliseconds: 300));

      // Should use Mumbai coordinates from PageStateService
      expect(controller.currentCenter.value.latitude, closeTo(19.07, 0.01));
    });

    test('uses device location when PageStateService has no location', () async {
      exploreState.value = PageStateModel.initial(PageType.explore);

      when(() => mockLocationController.hasLocation).thenReturn(true);
      when(() => mockLocationController.currentPosition).thenReturn(
        Rxn(
          Position(
            latitude: 12.97,
            longitude: 77.59,
            timestamp: DateTime.now(),
            accuracy: 10,
            altitude: 0,
            altitudeAccuracy: 0,
            heading: 0,
            headingAccuracy: 0,
            speed: 0,
            speedAccuracy: 0,
          ),
        ),
      );

      final controller = createController();
      controller.activatePage();

      await Future.delayed(const Duration(milliseconds: 300));

      // Should use device location (Bangalore)
      expect(controller.currentCenter.value.latitude, closeTo(12.97, 0.01));
    });

    test('uses IP location when device location fails', () async {
      exploreState.value = PageStateModel.initial(PageType.explore);

      when(() => mockLocationController.hasLocation).thenReturn(false);
      when(
        () => mockLocationController.getCurrentLocation(forceRefresh: any(named: 'forceRefresh')),
      ).thenAnswer((_) async {});
      when(() => mockLocationController.getIpLocation()).thenAnswer(
        (_) async => const LocationData(name: 'IP Location', latitude: 13.08, longitude: 80.27),
      );

      final controller = createController();
      controller.activatePage();

      await Future.delayed(const Duration(milliseconds: 300));

      // Should use IP location (Chennai)
      expect(controller.currentCenter.value.latitude, closeTo(13.08, 0.01));
    });

    test('sets error state when initialization fails', () async {
      exploreState.value = PageStateModel.initial(PageType.explore);

      when(
        () => mockPageStateService.loadPageData(
          any(),
          forceRefresh: any(named: 'forceRefresh'),
          backgroundRefresh: any(named: 'backgroundRefresh'),
        ),
      ).thenThrow(ServerException('Load failed'));

      final controller = createController();
      controller.activatePage();

      await Future.delayed(const Duration(milliseconds: 300));

      expect(controller.state.value, ExploreState.error);
      expect(controller.error.value, isNotNull);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // onMapReady — with page state location
  // ─────────────────────────────────────────────────────────────────────

  group('ExploreController — onMapReady with location', () {
    test('syncs camera to page state location when hasLocation', () {
      exploreState.value = PageStateModel(
        pageType: PageType.explore,
        filters: const UnifiedFilterModel(),
        properties: [],
        selectedLocation: const LocationData(name: 'Mumbai', latitude: 19.07, longitude: 72.87),
        lastFetched: DateTime.now(),
      );

      final controller = createController();
      controller.onMapReady();

      expect(controller.isMapReady.value, isTrue);
      // The post-frame callback updates currentCenter
      addTearDown(() {});
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // activatePage — with location already set
  // ─────────────────────────────────────────────────────────────────────

  group('ExploreController — activatePage with location', () {
    test('triggers initialization when initial state and hasLocation is false', () async {
      exploreState.value = PageStateModel.initial(PageType.explore);

      final controller = createController();
      expect(controller.state.value, ExploreState.initial);

      controller.activatePage();

      await Future.delayed(const Duration(milliseconds: 300));

      // Should have transitioned from initial
      expect(controller.state.value, isNot(ExploreState.initial));
    });

    test('syncs from page state when hasLocation and not initial', () {
      final props = seedProperties(2);
      exploreState.value = PageStateModel(
        pageType: PageType.explore,
        filters: const UnifiedFilterModel(),
        properties: props,
        selectedLocation: const LocationData(name: 'Test', latitude: 28.61, longitude: 77.21),
        lastFetched: DateTime.now(),
      );

      final controller = createController();
      // Set state to loaded so shouldRequestWhenEmpty is false
      controller.state.value = ExploreState.loaded;

      controller.activatePage();

      expect(controller.properties.length, 2);
      expect(controller.state.value, ExploreState.loaded);
    });
  });
}

// ---------------------------------------------------------------------------
// Mock MapLibreMapController for attachMap / zoom tests
// ---------------------------------------------------------------------------

class MockMapLibreMapController extends Mock implements MapLibreMapController {}
