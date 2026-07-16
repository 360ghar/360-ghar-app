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
import 'package:ghar360/core/data/ports/properties_port.dart';
import 'package:ghar360/core/data/ports/swipes_port.dart';
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

    // Stub PropertiesPort.searchProperties — PageDataLoader uses the port API
    // (not getProperties) for explore/discover loads.
    when(
      () => propertiesRepo.searchProperties(
        filters: any(named: 'filters'),
        cursor: any(named: 'cursor'),
        limit: any(named: 'limit'),
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
        radiusKm: any(named: 'radiusKm'),
        excludeSwiped: any(named: 'excludeSwiped'),
        useCache: any(named: 'useCache'),
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
      ..register<SwipesPort>(swipesRepo)
      ..register<PropertiesRepository>(propertiesRepo)
      ..register<PropertiesPort>(propertiesRepo);
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
      // NOT added to visible liked list (default segment is liked)
      expect(service.likesState.value.properties.any((p) => p.id == 99), isFalse);
      verify(() => swipesRepo.recordSwipe(propertyId: 99, isLiked: false)).called(1);
    });

    test('liked swipe updates likes even when current segment is passed', () async {
      final service = await createService();
      final prop = testPropertyModel(id: 88);

      service.updatePageState(
        PageType.discover,
        service.discoverState.value.copyWith(properties: [prop]),
      );
      // Seed liked segment so switching away caches it, then open passed.
      service.updatePageState(
        PageType.likes,
        service.likesState.value.copyWith(properties: [testPropertyModel(id: 1)]),
      );
      service.updateLikesSegment('passed');
      expect(service.currentLikesSegment, 'passed');

      await service.recordSwipe(propertyId: 88, isLiked: true);

      // Visible list is still the passed segment (empty after switch without cache).
      expect(service.likesState.value.properties.any((p) => p.id == 88), isFalse);

      // Switching back to liked should surface the optimistically cached like.
      service.updateLikesSegment('liked');
      expect(service.likesState.value.properties.any((p) => p.id == 88), isTrue);
    });

    test('passed swipe appears when switching to passed segment', () async {
      final service = await createService();
      final prop = testPropertyModel(id: 77);

      service.updatePageState(
        PageType.discover,
        service.discoverState.value.copyWith(properties: [prop]),
      );
      expect(service.currentLikesSegment, 'liked');

      await service.recordSwipe(propertyId: 77, isLiked: false);

      expect(service.likesState.value.properties.any((p) => p.id == 77), isFalse);

      service.updateLikesSegment('passed');
      expect(service.likesState.value.properties.any((p) => p.id == 77), isTrue);
    });

    test('session-swiped properties stay out of discover after filter', () async {
      final service = await createService();
      final swiped = testPropertyModel(id: 901);
      final other = testPropertyModel(id: 902);

      service.updatePageState(
        PageType.discover,
        service.discoverState.value.copyWith(properties: [swiped, other]),
      );

      await service.recordSwipe(propertyId: 901, isLiked: true);

      expect(service.discoverState.value.properties.any((p) => p.id == 901), isFalse);
      expect(service.isSessionSwiped(901), isTrue);

      // Simulate API refresh still returning the swiped property.
      final filtered = service.filterOutSessionSwiped([swiped, other]);
      expect(filtered.map((p) => p.id), [902]);

      // Undo restores eligibility for the deck.
      service.reinsertPropertyToDiscover(swiped);
      expect(service.isSessionSwiped(901), isFalse);
      expect(service.filterOutSessionSwiped([swiped, other]).map((p) => p.id), [901, 902]);
    });

    test('mergeLikesServerResults keeps optimistic like until server returns it', () async {
      final service = await createService();
      final prop = testPropertyModel(id: 501);
      final older = testPropertyModel(id: 100);

      service.updatePageState(
        PageType.discover,
        service.discoverState.value.copyWith(properties: [prop]),
      );
      await service.recordSwipe(propertyId: 501, isLiked: true);

      // Server history is still missing the just-liked property (race).
      final merged = service.mergeLikesServerResults([older], isLikedSegment: true);
      expect(merged.map((p) => p.id), [501, 100]);

      // Once server includes it, optimistic is cleared and not duplicated.
      final merged2 = service.mergeLikesServerResults([prop, older], isLikedSegment: true);
      expect(merged2.map((p) => p.id), [501, 100]);
      final merged3 = service.mergeLikesServerResults([prop, older], isLikedSegment: true);
      expect(merged3.map((p) => p.id), [501, 100]);
    });

    test('recordSwipe uses explicit property after visible list removal', () async {
      final service = await createService();
      final prop = testPropertyModel(id: 606);

      service.updatePageState(
        PageType.likes,
        service.likesState.value.copyWith(properties: [prop]),
      );
      // Caller removed from visible list first (legacy LikesController pattern).
      service.removePropertyFromLikes(606);

      await service.recordSwipe(propertyId: 606, isLiked: false, property: prop);

      service.updateLikesSegment('passed');
      expect(service.likesState.value.properties.any((p) => p.id == 606), isTrue);
    });

    test('mergeLikesServerResults skips server rows with opposite optimistic swipe', () async {
      final service = await createService();
      final prop = testPropertyModel(id: 707);

      service.updatePageState(
        PageType.discover,
        service.discoverState.value.copyWith(properties: [prop]),
      );
      await service.recordSwipe(propertyId: 707, isLiked: false);

      // Liked history still has the property; opposite pass optimistic wins.
      final merged = service.mergeLikesServerResults([prop], isLikedSegment: true);
      expect(merged.any((p) => p.id == 707), isFalse);
    });

    test('mergeDiscoverRefreshResults preserves undo reinsert after concurrent fetch', () async {
      final service = await createService();
      final a = testPropertyModel(id: 1);
      final b = testPropertyModel(id: 2);
      final reinserted = testPropertyModel(id: 3);

      final epoch = service.discoverMutationEpoch;
      service.updatePageState(
        PageType.discover,
        service.discoverState.value.copyWith(properties: [a, b]),
      );

      // Simulate undo reinsert while a fetch (started at [epoch]) is in flight.
      service.reinsertPropertyToDiscover(reinserted);
      expect(service.discoverMutationEpoch, greaterThan(epoch));

      final merged = service.mergeDiscoverRefreshResults(
        serverItems: [a, b],
        localItems: service.discoverState.value.properties,
        epochAtRequestStart: epoch,
      );
      expect(merged.map((p) => p.id).toList(), [3, 1, 2]);
    });

    test(
      'mergeDiscoverRefreshResults does not keep old-query cards after mid-refresh swipe',
      () async {
        final service = await createService();
        final a = testPropertyModel(id: 1);
        final b = testPropertyModel(id: 2);
        final c = testPropertyModel(id: 3);
        final d = testPropertyModel(id: 4);
        final e = testPropertyModel(id: 5);

        final epoch = service.discoverMutationEpoch;
        // Pre-refresh deck for location A.
        service.updatePageState(
          PageType.discover,
          service.discoverState.value.copyWith(properties: [a, b, c]),
        );

        // User swipes A away while a location-change fetch is in flight.
        // Epoch bumps, but only undo reinserts should be preserved — not B/C.
        await service.recordSwipe(propertyId: 1, isLiked: true);
        expect(service.discoverMutationEpoch, greaterThan(epoch));
        expect(service.discoverState.value.properties.map((p) => p.id), [2, 3]);

        // Server returns the new location's first page.
        final merged = service.mergeDiscoverRefreshResults(
          serverItems: [d, e],
          localItems: service.discoverState.value.properties,
          epochAtRequestStart: epoch,
        );
        expect(merged.map((p) => p.id).toList(), [4, 5]);
      },
    );

    test('mergeDiscoverRefreshResults keeps undo reinsert even when epoch matches', () async {
      final service = await createService();
      final a = testPropertyModel(id: 1);
      final b = testPropertyModel(id: 2);
      final reinserted = testPropertyModel(id: 3);

      // Undo happens before the fetch starts, so epoch at request start
      // equals the post-undo epoch. Preserve markers must still win.
      service.updatePageState(
        PageType.discover,
        service.discoverState.value.copyWith(properties: [a, b]),
      );
      service.reinsertPropertyToDiscover(reinserted);
      final epoch = service.discoverMutationEpoch;

      final merged = service.mergeDiscoverRefreshResults(
        serverItems: [a, b],
        localItems: service.discoverState.value.properties,
        epochAtRequestStart: epoch,
      );
      expect(merged.map((p) => p.id).toList(), [3, 1, 2]);
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

  // -------------------------------------------------------------------------
  // clearSessionData
  // -------------------------------------------------------------------------
  group('clearSessionData', () {
    test('resets all page states to initial', () async {
      final service = await createService();

      // Seed data into all page states
      service.updatePageState(
        PageType.explore,
        service.exploreState.value.copyWith(properties: [testPropertyModel(id: 1)]),
      );
      service.updatePageState(
        PageType.discover,
        service.discoverState.value.copyWith(properties: [testPropertyModel(id: 2)]),
      );
      service.updatePageState(
        PageType.likes,
        service.likesState.value.copyWith(properties: [testPropertyModel(id: 3)]),
      );

      expect(service.exploreState.value.properties, isNotEmpty);
      expect(service.discoverState.value.properties, isNotEmpty);
      expect(service.likesState.value.properties, isNotEmpty);

      service.clearSessionData();

      expect(service.exploreState.value.properties, isEmpty);
      expect(service.discoverState.value.properties, isEmpty);
      expect(service.likesState.value.properties, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // undoSwipe
  // -------------------------------------------------------------------------
  group('undoSwipe', () {
    test('undo of a liked swipe removes from likes', () async {
      final service = await createService();
      final prop = testPropertyModel(id: 42);

      // Add property to likes
      service.updatePageState(
        PageType.likes,
        service.likesState.value.copyWith(properties: [prop]),
      );

      await service.undoSwipe(propertyId: 42, originalIsLiked: true);

      // Should be removed from likes
      expect(service.likesState.value.properties.any((p) => p.id == 42), isFalse);
      // Network sync called with reversed action
      verify(() => swipesRepo.recordSwipe(propertyId: 42, isLiked: false)).called(1);
    });

    test('undo of a passed swipe does not add to likes', () async {
      final service = await createService();

      await service.undoSwipe(propertyId: 99, originalIsLiked: false);

      // Should NOT add to likes
      expect(service.likesState.value.properties.any((p) => p.id == 99), isFalse);
      // Network sync called with reversed action (liked=true)
      verify(() => swipesRepo.recordSwipe(propertyId: 99, isLiked: true)).called(1);
    });
  });

  // -------------------------------------------------------------------------
  // updateLikesSegment
  // -------------------------------------------------------------------------
  group('updateLikesSegment', () {
    test('switching to same segment is a no-op', () async {
      final service = await createService();
      expect(service.currentLikesSegment, 'liked');

      service.updateLikesSegment('liked');

      expect(service.currentLikesSegment, 'liked');
    });

    test('switching to passed resets data and triggers load', () async {
      final service = await createService();
      final prop = testPropertyModel(id: 10);
      service.updatePageState(
        PageType.likes,
        service.likesState.value.copyWith(properties: [prop]),
      );

      service.updateLikesSegment('passed');

      expect(service.currentLikesSegment, 'passed');
      // Data should be reset (empty) since no cache for passed
      expect(service.likesState.value.properties, isEmpty);
    });

    test('switching back to liked restores cached data', () async {
      final service = await createService();
      final prop = testPropertyModel(id: 10);
      service.updatePageState(
        PageType.likes,
        service.likesState.value.copyWith(properties: [prop], lastFetched: DateTime.now()),
      );

      // Switch to passed (caches liked data)
      service.updateLikesSegment('passed');

      // Switch back to liked (should restore cached data)
      service.updateLikesSegment('liked');

      expect(service.currentLikesSegment, 'liked');
      // Cached data should be restored
      expect(service.likesState.value.properties.any((p) => p.id == 10), isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // Search visibility
  // -------------------------------------------------------------------------
  group('search visibility', () {
    test('isSearchVisible returns false by default', () async {
      final service = await createService();

      expect(service.isSearchVisible(PageType.explore), isFalse);
      expect(service.isSearchVisible(PageType.discover), isFalse);
      expect(service.isSearchVisible(PageType.likes), isFalse);
    });

    test('setSearchVisible updates visibility', () async {
      final service = await createService();

      service.setSearchVisible(PageType.explore, true);
      expect(service.isSearchVisible(PageType.explore), isTrue);

      service.setSearchVisible(PageType.likes, true);
      expect(service.isSearchVisible(PageType.likes), isTrue);
    });

    test('toggleSearch flips visibility', () async {
      final service = await createService();

      expect(service.isSearchVisible(PageType.discover), isFalse);
      service.toggleSearch(PageType.discover);
      expect(service.isSearchVisible(PageType.discover), isTrue);
      service.toggleSearch(PageType.discover);
      expect(service.isSearchVisible(PageType.discover), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // Page refreshing
  // -------------------------------------------------------------------------
  group('page refreshing', () {
    test('isPageRefreshing returns false by default', () async {
      final service = await createService();

      expect(service.isPageRefreshing(PageType.explore), isFalse);
      expect(service.isPageRefreshing(PageType.discover), isFalse);
      expect(service.isPageRefreshing(PageType.likes), isFalse);
    });

    test('notifyPageRefreshing updates refreshing state', () async {
      final service = await createService();

      service.notifyPageRefreshing(PageType.explore, true);
      expect(service.isPageRefreshing(PageType.explore), isTrue);

      service.notifyPageRefreshing(PageType.likes, true);
      expect(service.isPageRefreshing(PageType.likes), isTrue);

      service.notifyPageRefreshing(PageType.explore, false);
      expect(service.isPageRefreshing(PageType.explore), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // normalizeLegacyStateForRuntime
  // -------------------------------------------------------------------------
  group('normalizeLegacyStateForRuntime', () {
    test('clears transient fields and properties', () {
      final legacy = PageStateModel(
        pageType: PageType.explore,
        filters: UnifiedFilterModel.initial(),
        properties: [testPropertyModel(id: 1)],
        isLoading: true,
        isLoadingMore: true,
        isRefreshing: true,
        hasMore: false,
        nextCursor: 'abc',
      );

      final normalized = PageStateService.normalizeLegacyStateForRuntime(legacy);

      expect(normalized.properties, isEmpty);
      expect(normalized.isLoading, isFalse);
      expect(normalized.isLoadingMore, isFalse);
      expect(normalized.isRefreshing, isFalse);
      expect(normalized.hasMore, isTrue);
      expect(normalized.nextCursor, isNull);
      expect(normalized.error, isNull);
    });

    test('preserves pageType, filters, and selectedLocation', () {
      final legacy = PageStateModel(
        pageType: PageType.likes,
        filters: UnifiedFilterModel.initial(),
        properties: [testPropertyModel(id: 1)],
        selectedLocation: const LocationData(name: 'Delhi', latitude: 28.6, longitude: 77.2),
      );

      final normalized = PageStateService.normalizeLegacyStateForRuntime(legacy);

      expect(normalized.pageType, PageType.likes);
      expect(normalized.selectedLocation?.name, 'Delhi');
    });
  });

  // -------------------------------------------------------------------------
  // syncPreferencesToBackend
  // -------------------------------------------------------------------------
  group('syncPreferencesToBackend', () {
    test('skips when not authenticated', () async {
      final service = await createService();

      when(() => authController.isAuthenticated).thenReturn(false);

      await service.syncPreferencesToBackend();

      verifyNever(() => authController.updateUserPreferences(any()));
    });

    test('syncs preferences when authenticated with filters', () async {
      final service = await createService();

      when(() => authController.isAuthenticated).thenReturn(true);
      when(() => authController.updateUserPreferences(any())).thenAnswer((_) async => true);

      // Set some filters on current page
      service.setCurrentPage(PageType.explore);
      service.updatePageState(
        PageType.explore,
        service.exploreState.value.copyWith(
          filters: UnifiedFilterModel.initial().copyWith(
            purpose: 'buy',
            priceMin: 5000000,
            priceMax: 10000000,
          ),
        ),
      );

      await service.syncPreferencesToBackend();

      verify(() => authController.updateUserPreferences(any())).called(1);
    });

    test('syncs with default purpose when authenticated', () async {
      final service = await createService();

      when(() => authController.isAuthenticated).thenReturn(true);
      when(() => authController.updateUserPreferences(any())).thenAnswer((_) async => true);

      // Default filters have purpose='buy' set during bootstrap
      await service.syncPreferencesToBackend();

      // Should call updateUserPreferences (purpose is set by default)
      verify(() => authController.updateUserPreferences(any())).called(1);
    });
  });

  // -------------------------------------------------------------------------
  // addPropertyToPassed
  // -------------------------------------------------------------------------
  group('addPropertyToPassed', () {
    test('does not add when segment is not passed', () async {
      final service = await createService();
      // Default segment is 'liked'
      final prop = testPropertyModel(id: 50);

      service.addPropertyToPassed(prop);

      expect(service.likesState.value.properties, isEmpty);
    });

    test('does not duplicate existing property in passed', () async {
      final service = await createService();
      service.updateLikesSegment('passed');
      final prop = testPropertyModel(id: 50);

      service.addPropertyToPassed(prop);
      service.addPropertyToPassed(prop);

      expect(service.likesState.value.properties, hasLength(1));
    });
  });

  // -------------------------------------------------------------------------
  // onClose
  // -------------------------------------------------------------------------
  group('onClose', () {
    test('disposes without throwing', () async {
      final service = await createService();

      expect(() => service.onClose(), returnsNormally);
    });
  });

  // -------------------------------------------------------------------------
  // Filter / search / location delegates
  // -------------------------------------------------------------------------
  group('filter and search delegates', () {
    test('updatePageFilters mutates page filters', () async {
      final service = await createService();
      final filters = UnifiedFilterModel.initial().copyWith(purpose: 'sale');

      service.updatePageFilters(PageType.discover, filters);

      expect(service.discoverState.value.filters.purpose, 'sale');
    });

    test('updatePageSearch and clearPageSearch round-trip', () async {
      final service = await createService();
      service.updatePageSearch(PageType.explore, 'gurgaon');
      expect(service.exploreState.value.searchQuery, 'gurgaon');

      service.clearPageSearch(PageType.explore);
      final cleared = service.exploreState.value.searchQuery;
      expect(cleared == null || cleared.isEmpty, isTrue);
    });

    test('getOrCreateSearchController seeds text and is reusable', () async {
      final service = await createService();
      final first = service.getOrCreateSearchController(PageType.discover, seedText: 'seed');
      final second = service.getOrCreateSearchController(PageType.discover);
      expect(identical(first, second), isTrue);
      expect(first.text, 'seed');
      first.dispose();
    });

    test('resetPageFilters and resetAllFilters do not throw', () async {
      final service = await createService();
      service.updatePageFilters(
        PageType.discover,
        UnifiedFilterModel.initial().copyWith(purpose: 'rent'),
      );
      service.resetPageFilters(PageType.discover);
      service.resetAllFilters();
      expect(service.discoverState.value.filters, isA<UnifiedFilterModel>());
    });

    test('setPurposeForAllPages and setPropertyTypeForAllPages apply', () async {
      final service = await createService();
      service.setPurposeForAllPages('sale');
      service.setPropertyTypeForAllPages(const ['apartment']);

      expect(service.discoverState.value.filters.purpose, 'sale');
      expect(service.exploreState.value.filters.purpose, 'sale');
    });

    test('search visibility helpers toggle state', () async {
      final service = await createService();
      expect(service.isSearchVisible(PageType.discover), isFalse);
      service.setSearchVisible(PageType.discover, true);
      expect(service.isSearchVisible(PageType.discover), isTrue);
      service.toggleSearch(PageType.discover);
      expect(service.isSearchVisible(PageType.discover), isFalse);
    });

    test('notifyPageRefreshing updates isPageRefreshing', () async {
      final service = await createService();
      service.notifyPageRefreshing(PageType.explore, true);
      expect(service.isPageRefreshing(PageType.explore), isTrue);
      service.notifyPageRefreshing(PageType.explore, false);
      expect(service.isPageRefreshing(PageType.explore), isFalse);
    });
  });

  group('location delegates', () {
    test('updateLocation and updateLocationForPage apply location', () async {
      final service = await createService();
      const location = LocationData(name: 'Noida', latitude: 28.5, longitude: 77.4);

      await service.updateLocation(location, source: 'manual');
      await service.updateLocationForPage(PageType.discover, location, source: 'manual');

      expect(service.discoverState.value.selectedLocation?.name, 'Noida');
    });
  });

  group('loadPageData delegates', () {
    test('loadPageData and loadMore* complete against stubs', () async {
      final service = await createService();
      await service.loadPageData(PageType.explore, forceRefresh: true);
      await service.loadMorePageData(PageType.explore);
      await service.loadMoreData(PageType.explore);
      expect(service.exploreState.value, isA<PageStateModel>());
    });
  });

  group('clearSessionData', () {
    test('clears properties without throwing', () async {
      final service = await createService();
      service.clearSessionData();
      expect(service.discoverState.value.properties, isEmpty);
      expect(service.exploreState.value.properties, isEmpty);
      // Allow GetStorage microtask flushes to finish before tearDown.
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
  });
}
