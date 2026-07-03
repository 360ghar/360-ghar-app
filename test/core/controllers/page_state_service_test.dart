// test/core/controllers/page_state_service_test.dart
//
// Unit tests for [PageStateService]. Covers:
// - Initial state values (PageStateModel factory)
// - setCurrentPage changes active page
// - getStateForPage / getCurrentPageState return correct state
// - updatePageState mutates the correct observable
// - recordSwipe optimistically updates likes/dislikes
// - removePropertyFromDiscover / reinsertPropertyToDiscover
// - addPropertyToLikes / removePropertyFromLikes

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/controllers/location_controller.dart';
import 'package:ghar360/core/controllers/page_state_service.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/features/properties/data/properties_repository.dart';
import 'package:ghar360/features/swipes/data/swipes_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/getx_test_binding.dart';
import '../../helpers/mocks.dart';

void main() {
  // Mock path_provider platform channel so GetStorage can initialise in tests.
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory storageDir;

  setUpAll(() async {
    storageDir = await Directory.systemTemp.createTemp('page_state_service_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return storageDir.path;
        }
        return null;
      },
    );

    registerFallbackValue(UnifiedFilterModel.initial());
    registerFallbackValue(const LocationData(name: 'fallback', latitude: 0, longitude: 0));
    registerFallbackValue(testPropertyResponse());
  });

  tearDownAll(() async {
    // Keep the path_provider mock installed for the test process lifetime.
    // GetStorage can schedule delayed flush/backup work after erase()/writes,
    // and a late flush may still resolve getApplicationDocumentsDirectory.
    try {
      await storageDir.delete(recursive: true);
    } catch (_) {}
  });

  late MockLocationController locationController;
  late MockAuthController authController;
  late MockSwipesRepository swipesRepo;
  late MockPropertiesRepository propertiesRepo;

  setUp(() async {
    GetxTestBinding.init();
    await GetStorage.init();
    await GetStorage().erase();

    locationController = MockLocationController();
    authController = MockAuthController();
    swipesRepo = MockSwipesRepository();
    propertiesRepo = MockPropertiesRepository();

    // Stub LocationController Rx fields (needed by sub-services created in onInit)
    when(() => locationController.currentPosition).thenReturn(Rxn<Position>());
    when(() => locationController.isLocationEnabled).thenReturn(false.obs);
    when(() => locationController.isLocationPermissionGranted).thenReturn(false.obs);
    when(() => locationController.isLoading).thenReturn(false.obs);
    when(() => locationController.locationError).thenReturn(''.obs);
    when(() => locationController.currentAddress).thenReturn(''.obs);
    when(() => locationController.hasLocation).thenReturn(false);

    // Stub methods called during _bootstrapInitialStates
    when(() => locationController.getInitialLocation()).thenAnswer(
      (_) async => const LocationData(name: 'Test City', latitude: 28.6139, longitude: 77.2090),
    );
    when(
      () => locationController.getAddressFromCoordinates(any(), any()),
    ).thenAnswer((_) async => 'Test Area, Test City');

    // Stub AuthController
    when(() => authController.isAuthenticated).thenReturn(false);
    when(() => authController.updateUserPreferences(any())).thenAnswer((_) async => true);

    // Stub PropertiesRepository — called during initial data load for explore/discover
    when(
      () => propertiesRepo.getProperties(
        filters: any(named: 'filters'),
        cursor: any(named: 'cursor'),
        limit: any(named: 'limit'),
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
      ),
    ).thenAnswer((_) async => testPropertyResponse());

    // Stub SwipesRepository — called during initial data load for likes
    when(
      () => swipesRepo.getSwipeHistoryProperties(
        filters: any(named: 'filters'),
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
        cursor: any(named: 'cursor'),
        limit: any(named: 'limit'),
        isLiked: any(named: 'isLiked'),
      ),
    ).thenAnswer((_) async => testPropertyResponse());
    when(
      () => swipesRepo.recordSwipe(
        propertyId: any(named: 'propertyId'),
        isLiked: any(named: 'isLiked'),
      ),
    ).thenAnswer((_) async {});

    GetxTestBinding.bind()
      ..register<LocationController>(locationController)
      ..register<AuthController>(authController)
      ..register<SwipesRepository>(swipesRepo)
      ..register<PropertiesRepository>(propertiesRepo);
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  /// Creates and registers PageStateService, waiting for async onInit to complete.
  Future<PageStateService> createService() async {
    final service = PageStateService();
    Get.put<PageStateService>(service);
    // onInit is async (dependency retry + bootstrap). Give it time to settle.
    await Future.delayed(const Duration(seconds: 2));
    return service;
  }

  // -------------------------------------------------------------------------
  // PageStateModel initial factory
  // -------------------------------------------------------------------------
  group('PageStateModel.initial', () {
    test('creates correct initial state for each page type', () {
      for (final pageType in PageType.values) {
        final state = PageStateModel.initial(pageType);

        expect(state.pageType, pageType);
        expect(state.selectedLocation, isNull);
        expect(state.properties, isEmpty);
        expect(state.hasMore, isTrue);
        expect(state.isLoading, isFalse);
        expect(state.isLoadingMore, isFalse);
        expect(state.isRefreshing, isFalse);
        expect(state.error, isNull);
        expect(state.filters, isA<UnifiedFilterModel>());
      }
    });

    test('likes page has currentSegment additional data', () {
      final state = PageStateModel.initial(PageType.likes);
      expect(state.getAdditionalData<String>('currentSegment'), 'liked');
    });

    test('explore page has no additional data', () {
      final state = PageStateModel.initial(PageType.explore);
      expect(state.additionalData, isNull);
    });

    test('hasLocation is false when selectedLocation is null', () {
      final state = PageStateModel.initial(PageType.discover);
      expect(state.hasLocation, isFalse);
    });

    test('isDataStale is true when lastFetched is null', () {
      final state = PageStateModel.initial(PageType.discover);
      expect(state.isDataStale, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // PageStateModel copyWith
  // -------------------------------------------------------------------------
  group('PageStateModel.copyWith', () {
    test('preserves unmodified fields', () {
      final original = PageStateModel.initial(PageType.discover);
      final copied = original.copyWith(isLoading: true, properties: [testPropertyModel(id: 1)]);

      expect(copied.pageType, PageType.discover);
      expect(copied.isLoading, isTrue);
      expect(copied.properties, hasLength(1));
      expect(copied.hasMore, original.hasMore);
      expect(copied.filters, original.filters);
    });

    test('can set selectedLocation to null explicitly', () {
      final withLocation = PageStateModel.initial(PageType.discover).copyWith(
        selectedLocation: const LocationData(name: 'Delhi', latitude: 28.6, longitude: 77.2),
      );
      expect(withLocation.hasLocation, isTrue);

      final cleared = withLocation.copyWith(selectedLocation: null);
      expect(cleared.hasLocation, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // setCurrentPage / getStateForPage / getCurrentPageState
  // -------------------------------------------------------------------------
  group('page navigation', () {
    test('initial currentPageType is discover', () async {
      final service = await createService();
      expect(service.currentPageType.value, PageType.discover);
    });

    test('setCurrentPage changes active page', () async {
      final service = await createService();

      service.setCurrentPage(PageType.explore);
      expect(service.currentPageType.value, PageType.explore);

      service.setCurrentPage(PageType.likes);
      expect(service.currentPageType.value, PageType.likes);
    });

    test('setCurrentPage with same page is a no-op', () async {
      final service = await createService();
      service.setCurrentPage(PageType.explore);

      // Should not throw or cause side effects
      service.setCurrentPage(PageType.explore);
      expect(service.currentPageType.value, PageType.explore);
    });

    test('getStateForPage returns the correct page state', () async {
      final service = await createService();

      final exploreState = service.getStateForPage(PageType.explore);
      expect(exploreState.pageType, PageType.explore);

      final discoverState = service.getStateForPage(PageType.discover);
      expect(discoverState.pageType, PageType.discover);

      final likesState = service.getStateForPage(PageType.likes);
      expect(likesState.pageType, PageType.likes);
    });

    test('getCurrentPageState returns state for current page', () async {
      final service = await createService();

      service.setCurrentPage(PageType.explore);
      expect(service.getCurrentPageState().pageType, PageType.explore);

      service.setCurrentPage(PageType.likes);
      expect(service.getCurrentPageState().pageType, PageType.likes);
    });
  });

  // -------------------------------------------------------------------------
  // updatePageState
  // -------------------------------------------------------------------------
  group('updatePageState', () {
    test('updates the correct page observable', () async {
      final service = await createService();

      final newState = service.exploreState.value.copyWith(isLoading: true, searchQuery: 'villa');
      service.updatePageState(PageType.explore, newState);

      expect(service.exploreState.value.isLoading, isTrue);
      expect(service.exploreState.value.searchQuery, 'villa');
      // Other pages unaffected
      expect(service.discoverState.value.isLoading, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // recordSwipe
  // -------------------------------------------------------------------------
  group('recordSwipe', () {
    test('liked swipe adds property to likes and removes from discover', () async {
      final service = await createService();
      final prop = testPropertyModel(id: 42);

      // Seed the discover deck with the property
      final discoverState = service.discoverState.value.copyWith(properties: [prop]);
      service.updatePageState(PageType.discover, discoverState);

      await service.recordSwipe(propertyId: 42, isLiked: true);

      // Should be removed from discover
      expect(service.discoverState.value.properties.any((p) => p.id == 42), isFalse);
      // Should be added to likes
      expect(service.likesState.value.properties.any((p) => p.id == 42), isTrue);
      // Background sync called
      verify(() => swipesRepo.recordSwipe(propertyId: 42, isLiked: true)).called(1);
    });

    test('disliked swipe removes property from discover without adding to likes', () async {
      final service = await createService();
      final prop = testPropertyModel(id: 99);

      final discoverState = service.discoverState.value.copyWith(properties: [prop]);
      service.updatePageState(PageType.discover, discoverState);

      await service.recordSwipe(propertyId: 99, isLiked: false);

      // Removed from discover
      expect(service.discoverState.value.properties.any((p) => p.id == 99), isFalse);
      // NOT added to likes
      expect(service.likesState.value.properties.any((p) => p.id == 99), isFalse);
      verify(() => swipesRepo.recordSwipe(propertyId: 99, isLiked: false)).called(1);
    });

    test('liked swipe finds property in explore list too', () async {
      final service = await createService();
      final prop = testPropertyModel(id: 55);

      // Put the property in explore state
      final exploreState = service.exploreState.value.copyWith(properties: [prop]);
      service.updatePageState(PageType.explore, exploreState);

      await service.recordSwipe(propertyId: 55, isLiked: true);

      // Should be found in explore and added to likes
      expect(service.likesState.value.properties.any((p) => p.id == 55), isTrue);
    });

    test('liked swipe finds property already in likes list', () async {
      final service = await createService();
      final prop = testPropertyModel(id: 77);

      // Put the property in all three lists
      service.updatePageState(
        PageType.explore,
        service.exploreState.value.copyWith(properties: [prop]),
      );
      service.updatePageState(
        PageType.discover,
        service.discoverState.value.copyWith(properties: [prop]),
      );
      service.updatePageState(
        PageType.likes,
        service.likesState.value.copyWith(properties: [prop]),
      );

      await service.recordSwipe(propertyId: 77, isLiked: true);

      // Should not duplicate in likes
      final likedIds = service.likesState.value.properties.where((p) => p.id == 77).toList();
      expect(likedIds, hasLength(1));
    });
  });

  // -------------------------------------------------------------------------
  // removePropertyFromDiscover / reinsertPropertyToDiscover
  // -------------------------------------------------------------------------
  group('discover deck mutations', () {
    test('removePropertyFromDiscover removes the matching property', () async {
      final service = await createService();
      final p1 = testPropertyModel(id: 1);
      final p2 = testPropertyModel(id: 2);

      service.updatePageState(
        PageType.discover,
        service.discoverState.value.copyWith(properties: [p1, p2]),
      );

      service.removePropertyFromDiscover(1);

      expect(service.discoverState.value.properties, hasLength(1));
      expect(service.discoverState.value.properties.first.id, 2);
    });

    test('removePropertyFromDiscover is no-op when id not found', () async {
      final service = await createService();
      final p1 = testPropertyModel(id: 1);

      service.updatePageState(
        PageType.discover,
        service.discoverState.value.copyWith(properties: [p1]),
      );

      service.removePropertyFromDiscover(999);

      expect(service.discoverState.value.properties, hasLength(1));
    });

    test('reinsertPropertyToDiscover adds to front of list', () async {
      final service = await createService();
      final p1 = testPropertyModel(id: 1);
      final p2 = testPropertyModel(id: 2);

      service.updatePageState(
        PageType.discover,
        service.discoverState.value.copyWith(properties: [p1, p2]),
      );

      final restored = testPropertyModel(id: 99);
      service.reinsertPropertyToDiscover(restored);

      expect(service.discoverState.value.properties, hasLength(3));
      expect(service.discoverState.value.properties.first.id, 99);
    });

    test('reinsertPropertyToDiscover does not duplicate existing property', () async {
      final service = await createService();
      final p1 = testPropertyModel(id: 1);

      service.updatePageState(
        PageType.discover,
        service.discoverState.value.copyWith(properties: [p1]),
      );

      service.reinsertPropertyToDiscover(p1);

      // Should still be 1, not duplicated
      expect(service.discoverState.value.properties, hasLength(1));
    });
  });

  // -------------------------------------------------------------------------
  // addPropertyToLikes / removePropertyFromLikes
  // -------------------------------------------------------------------------
  group('likes list mutations', () {
    test('addPropertyToLikes prepends to likes list when segment is liked', () async {
      final service = await createService();
      final p1 = testPropertyModel(id: 10);
      final p2 = testPropertyModel(id: 20);

      // Ensure we're in the 'liked' segment (default)
      expect(service.currentLikesSegment, 'liked');

      service.addPropertyToLikes(p1);
      expect(service.likesState.value.properties, hasLength(1));
      expect(service.likesState.value.properties.first.id, 10);

      service.addPropertyToLikes(p2);
      expect(service.likesState.value.properties, hasLength(2));
      expect(service.likesState.value.properties.first.id, 20); // prepended
    });

    test('addPropertyToLikes does not duplicate existing property', () async {
      final service = await createService();
      final p1 = testPropertyModel(id: 10);

      service.addPropertyToLikes(p1);
      service.addPropertyToLikes(p1);

      expect(service.likesState.value.properties, hasLength(1));
    });

    test('addPropertyToLikes is skipped when segment is not liked', () async {
      final service = await createService();

      // Switch to 'passed' segment
      service.updateLikesSegment('passed');

      final p1 = testPropertyModel(id: 10);
      service.addPropertyToLikes(p1);

      // Should NOT be added because we're in 'passed' segment
      expect(service.likesState.value.properties, isEmpty);
    });

    test('addPropertyToPassed works when segment is passed', () async {
      final service = await createService();
      service.updateLikesSegment('passed');

      final p1 = testPropertyModel(id: 10);
      service.addPropertyToPassed(p1);

      expect(service.likesState.value.properties, hasLength(1));
      expect(service.likesState.value.properties.first.id, 10);
    });

    test('addPropertyToPassed is skipped when segment is liked', () async {
      final service = await createService();
      // Default segment is 'liked'

      final p1 = testPropertyModel(id: 10);
      service.addPropertyToPassed(p1);

      expect(service.likesState.value.properties, isEmpty);
    });

    test('removePropertyFromLikes removes matching property', () async {
      final service = await createService();
      final p1 = testPropertyModel(id: 10);
      final p2 = testPropertyModel(id: 20);

      service.updatePageState(
        PageType.likes,
        service.likesState.value.copyWith(properties: [p1, p2]),
      );

      service.removePropertyFromLikes(10);

      expect(service.likesState.value.properties, hasLength(1));
      expect(service.likesState.value.properties.first.id, 20);
    });

    test('removePropertyFromLikes is no-op when id not found', () async {
      final service = await createService();
      final p1 = testPropertyModel(id: 10);

      service.updatePageState(PageType.likes, service.likesState.value.copyWith(properties: [p1]));

      service.removePropertyFromLikes(999);

      expect(service.likesState.value.properties, hasLength(1));
    });
  });

  // -------------------------------------------------------------------------
  // PageStateModel helpers
  // -------------------------------------------------------------------------
  group('PageStateModel helpers', () {
    test('getAdditionalData returns typed value', () {
      final state = PageStateModel.initial(PageType.likes);
      expect(state.getAdditionalData<String>('currentSegment'), 'liked');
      expect(state.getAdditionalData<bool>('nonexistent'), isNull);
    });

    test('updateAdditionalData creates new map with updated value', () {
      final state = PageStateModel.initial(PageType.likes);
      final updated = state.updateAdditionalData('currentSegment', 'passed');

      expect(updated.getAdditionalData<String>('currentSegment'), 'passed');
      // Original unchanged (immutable)
      expect(state.getAdditionalData<String>('currentSegment'), 'liked');
    });

    test('resetData clears transient fields', () {
      final state = PageStateModel(
        pageType: PageType.discover,
        filters: UnifiedFilterModel.initial(),
        properties: [testPropertyModel()],
        isLoading: true,
        isLoadingMore: true,
        isRefreshing: true,
        hasMore: false,
        nextCursor: 'abc',
      );

      final reset = state.resetData();

      expect(reset.properties, isEmpty);
      expect(reset.isLoading, isFalse);
      expect(reset.isLoadingMore, isFalse);
      expect(reset.isRefreshing, isFalse);
      expect(reset.hasMore, isTrue);
      expect(reset.nextCursor, isNull);
      expect(reset.error, isNull);
    });
  });
}
