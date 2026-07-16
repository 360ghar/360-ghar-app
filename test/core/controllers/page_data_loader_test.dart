// test/core/controllers/page_data_loader_test.dart
//
// Unit tests for [PageDataLoader]. The loader is a plain (non-Getx) class that
// collaborates with [PageStateService], [PropertiesPort], [SwipesPort] and
// [LocationController]; all four are mocked with mocktail. A real
// [PageStateModel] is seeded via the page-state mock so the loader's branching
// on cached data, staleness and loading flags is exercised end-to-end.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/controllers/page_data_loader.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/data/models/unified_property_response.dart';
import 'package:ghar360/core/data/ports/properties_port.dart';
import 'package:ghar360/core/data/ports/swipes_port.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/mocks.dart';

// ---------------------------------------------------------------------------
// Mocks local to this test file
// ---------------------------------------------------------------------------

class MockPropertiesPort extends Mock implements PropertiesPort {}

class MockSwipesPort extends Mock implements SwipesPort {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    Get.testMode = true;
    registerFallbackValue(PageType.explore);
    registerFallbackValue(PageStateModel.initial(PageType.explore));
    registerFallbackValue(UnifiedFilterModel.initial());
    registerFallbackValue(const LocationData(name: 'fallback', latitude: 0, longitude: 0));
    registerFallbackValue(testPropertyResponse());
  });

  late MockPageStateService pageState;
  late MockPropertiesPort propertiesRepo;
  late MockSwipesPort swipesRepo;
  late MockLocationController locationController;
  late PageDataLoader loader;

  setUp(() {
    pageState = MockPageStateService();
    propertiesRepo = MockPropertiesPort();
    swipesRepo = MockSwipesPort();
    locationController = MockLocationController();

    // Default stubs ---------------------------------------------------------
    // getStateForPage returns the initial (empty, no location) state unless a
    // test overrides it. Tests use `thenAnswer` to return a mutable state.
    when(
      () => pageState.getStateForPage(any()),
    ).thenAnswer((inv) => PageStateModel.initial(inv.positionalArguments[0] as PageType));
    when(() => pageState.updatePageState(any(), any())).thenReturn(null);
    when(() => pageState.notifyPageRefreshing(any(), any())).thenReturn(null);
    when(
      () => pageState.filterOutSessionSwiped(any()),
    ).thenAnswer((inv) => List<PropertyModel>.from(inv.positionalArguments[0] as List));
    when(() => pageState.discoverMutationEpoch).thenReturn(0);
    when(
      () => pageState.mergeDiscoverRefreshResults(
        serverItems: any(named: 'serverItems'),
        localItems: any(named: 'localItems'),
        epochAtRequestStart: any(named: 'epochAtRequestStart'),
      ),
    ).thenAnswer((inv) => List<PropertyModel>.from(inv.namedArguments[#serverItems] as List));
    when(
      () => pageState.mergeLikesServerResults(any(), isLikedSegment: any(named: 'isLikedSegment')),
    ).thenAnswer((inv) => List<PropertyModel>.from(inv.positionalArguments[0] as List));
    when(
      () => pageState.applyLikesSegmentFetchResult(
        isLikedSegment: any(named: 'isLikedSegment'),
        serverItems: any(named: 'serverItems'),
        hasMore: any(named: 'hasMore'),
        nextCursor: any(named: 'nextCursor'),
      ),
    ).thenReturn(null);
    when(
      () => pageState.syncLikesSegmentCacheFromVisible(
        hasMore: any(named: 'hasMore'),
        nextCursor: any(named: 'nextCursor'),
      ),
    ).thenReturn(null);
    when(() => pageState.currentLikesSegment).thenReturn('liked');

    // LocationController stubs.
    when(
      () => locationController.getInitialLocation(),
    ).thenAnswer((_) async => const LocationData(name: 'GPS Loc', latitude: 28.6, longitude: 77.2));
    when(
      () => locationController.getAddressFromCoordinates(any(), any()),
    ).thenAnswer((_) async => 'Resolved Address');

    loader = PageDataLoader(pageState, propertiesRepo, swipesRepo, locationController);
  });

  tearDown(() {
    loader.dispose();
  });

  // Helper: a state with cached properties and a location (not stale).
  PageStateModel cachedState(
    PageType pageType, {
    List<PropertyModel> properties = const [],
    String? nextCursor,
    bool hasMore = true,
    DateTime? lastFetched,
    LocationData? location,
  }) {
    return PageStateModel(
      pageType: pageType,
      filters: UnifiedFilterModel.initial(),
      properties: properties,
      nextCursor: nextCursor,
      hasMore: hasMore,
      lastFetched: lastFetched ?? DateTime.now(),
      selectedLocation:
          location ?? const LocationData(name: 'Saved', latitude: 28.6, longitude: 77.2),
    );
  }

  // ── loadPageData: foreground (no cache) ──────────────────────────────

  group('loadPageData — foreground load (no cache)', () {
    test('fetches first page for explore when no cached data', () async {
      final resp = UnifiedPropertyResponse(
        items: [testPropertyModel(id: 1), testPropertyModel(id: 2)],
        nextCursor: 'cursor1',
        hasMore: true,
      );
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
      ).thenAnswer((_) async => resp);

      await loader.loadPageData(PageType.explore);

      verify(() => pageState.updatePageState(PageType.explore, any())).called(greaterThan(0));
      verify(
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
      ).called(1);
    });

    test('fetches first page for likes via swipes repo', () async {
      final resp = UnifiedPropertyResponse(
        items: [testPropertyModel(id: 5)],
        nextCursor: null,
        hasMore: false,
      );
      when(
        () => swipesRepo.getSwipeHistoryProperties(
          filters: any(named: 'filters'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
          isLiked: any(named: 'isLiked'),
        ),
      ).thenAnswer((_) async => resp);

      await loader.loadPageData(PageType.likes);

      verify(
        () => swipesRepo.getSwipeHistoryProperties(
          filters: any(named: 'filters'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
          isLiked: any(named: 'isLiked'),
        ),
      ).called(1);
    });

    test('discover uses excludeSwiped=true and limit 20', () async {
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

      await loader.loadPageData(PageType.discover);

      final captured = verify(
        () => propertiesRepo.searchProperties(
          filters: any(named: 'filters'),
          cursor: any(named: 'cursor'),
          limit: captureAny(named: 'limit'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          radiusKm: any(named: 'radiusKm'),
          excludeSwiped: captureAny(named: 'excludeSwiped'),
          useCache: any(named: 'useCache'),
        ),
      ).captured;

      expect(captured[0], 20); // limit
      expect(captured[1], true); // excludeSwiped
    });

    test('sets isLoading=true then false during foreground load', () async {
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

      await loader.loadPageData(PageType.explore);

      // At least one updatePageState call should have isLoading=true.
      final calls = verify(
        () => pageState.updatePageState(PageType.explore, captureAny()),
      ).captured.cast<PageStateModel>();
      expect(calls.any((s) => s.isLoading), true);
      expect(calls.any((s) => !s.isLoading), true);
    });

    test('catches repository error and sets error state', () async {
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
      ).thenThrow(Exception('fetch failed'));

      await loader.loadPageData(PageType.explore);

      final calls = verify(
        () => pageState.updatePageState(PageType.explore, captureAny()),
      ).captured.cast<PageStateModel>();
      expect(calls.any((s) => s.error != null), true);
    });
  });

  // ── loadPageData: cached data paths ──────────────────────────────────

  group('loadPageData — cached data', () {
    test('no-op when cached data is fresh and no refresh requested', () async {
      when(() => pageState.getStateForPage(any())).thenAnswer(
        (inv) => cachedState(
          inv.positionalArguments[0] as PageType,
          properties: [testPropertyModel(id: 1)],
        ),
      );

      await loader.loadPageData(PageType.explore);

      verifyNever(
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
      );
    });

    test('forceRefresh triggers background refresh with cached data', () async {
      when(() => pageState.getStateForPage(any())).thenAnswer(
        (inv) => cachedState(
          inv.positionalArguments[0] as PageType,
          properties: [testPropertyModel(id: 1)],
        ),
      );
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

      await loader.loadPageData(PageType.explore, forceRefresh: true);
      // Allow background unawaited future to settle.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      verify(
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
      ).called(1);
      verify(() => pageState.notifyPageRefreshing(PageType.explore, true)).called(1);
      verify(() => pageState.notifyPageRefreshing(PageType.explore, false)).called(1);
    });

    test('backgroundRefresh triggers background refresh', () async {
      when(
        () => pageState.getStateForPage(any()),
      ).thenAnswer((inv) => cachedState(inv.positionalArguments[0] as PageType));
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

      await loader.loadPageData(PageType.discover, backgroundRefresh: true);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      verify(
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
      ).called(1);
    });

    test('stale cached data triggers background refresh', () async {
      when(() => pageState.getStateForPage(any())).thenAnswer(
        (inv) => cachedState(
          inv.positionalArguments[0] as PageType,
          lastFetched: DateTime.now().subtract(const Duration(minutes: 30)),
        ),
      );
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

      await loader.loadPageData(PageType.explore);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      verify(
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
      ).called(1);
    });

    test('background refresh failure sets error on current state', () async {
      when(() => pageState.getStateForPage(any())).thenAnswer(
        (inv) => cachedState(
          inv.positionalArguments[0] as PageType,
          properties: [testPropertyModel(id: 1)],
        ),
      );
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
      ).thenThrow(Exception('refresh failed'));

      await loader.loadPageData(PageType.explore, forceRefresh: true);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // The background catchError path updates state with isRefreshing=false.
      final calls = verify(
        () => pageState.updatePageState(PageType.explore, captureAny()),
      ).captured.cast<PageStateModel>();
      expect(calls.any((s) => s.error != null && !s.isRefreshing), true);
    });
  });

  // ── loadPageData: guards ─────────────────────────────────────────────

  group('loadPageData — guards', () {
    test('does not load when state.isLoading is already true', () async {
      when(() => pageState.getStateForPage(any())).thenAnswer(
        (inv) => cachedState(
          inv.positionalArguments[0] as PageType,
          properties: [testPropertyModel(id: 1)],
        ).copyWith(isLoading: true),
      );

      await loader.loadPageData(PageType.explore);

      verifyNever(
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
      );
    });

    test('does not load when state.isRefreshing is already true', () async {
      when(() => pageState.getStateForPage(any())).thenAnswer(
        (inv) => cachedState(
          inv.positionalArguments[0] as PageType,
          properties: [testPropertyModel(id: 1)],
        ).copyWith(isRefreshing: true),
      );

      await loader.loadPageData(PageType.explore, forceRefresh: true);

      verifyNever(
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
      );
    });

    test('heals stale loading state when no properties and old lastFetched', () async {
      // A loading flag with no properties and a lastFetched older than the
      // guard window should be healed (reset) and a fresh load performed.
      when(() => pageState.getStateForPage(any())).thenAnswer(
        (inv) => PageStateModel(
          pageType: inv.positionalArguments[0] as PageType,
          filters: UnifiedFilterModel.initial(),
          properties: const [],
          isLoading: true,
          lastFetched: DateTime.now().subtract(const Duration(seconds: 30)),
        ),
      );
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

      await loader.loadPageData(PageType.explore);

      // The heal path calls updatePageState to reset flags, then loads.
      verify(
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
      ).called(1);
    });
  });

  // ── loadMorePageData ─────────────────────────────────────────────────

  group('loadMorePageData', () {
    test('appends properties for explore via properties repo', () async {
      when(() => pageState.getStateForPage(any())).thenAnswer(
        (inv) => cachedState(
          inv.positionalArguments[0] as PageType,
          properties: [testPropertyModel(id: 1)],
          nextCursor: 'next',
          hasMore: true,
        ),
      );
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
      ).thenAnswer(
        (_) async => UnifiedPropertyResponse(
          items: [testPropertyModel(id: 2), testPropertyModel(id: 3)],
          nextCursor: 'next2',
          hasMore: true,
        ),
      );

      await loader.loadMorePageData(PageType.explore);

      final calls = verify(
        () => pageState.updatePageState(PageType.explore, captureAny()),
      ).captured.cast<PageStateModel>();
      // Final state should contain appended properties (3 total).
      final last = calls.last;
      expect(last.properties.length, 3);
      expect(last.nextCursor, 'next2');
      expect(last.isLoadingMore, false);
    });

    test('appends properties for likes via swipes repo', () async {
      when(() => pageState.getStateForPage(any())).thenAnswer(
        (inv) => cachedState(
          inv.positionalArguments[0] as PageType,
          properties: [testPropertyModel(id: 1)],
          nextCursor: 'next',
          hasMore: true,
        ),
      );
      when(
        () => swipesRepo.getSwipeHistoryProperties(
          filters: any(named: 'filters'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
          isLiked: any(named: 'isLiked'),
        ),
      ).thenAnswer(
        (_) async => UnifiedPropertyResponse(
          items: [testPropertyModel(id: 2)],
          nextCursor: null,
          hasMore: false,
        ),
      );

      await loader.loadMorePageData(PageType.likes);

      verify(
        () => swipesRepo.getSwipeHistoryProperties(
          filters: any(named: 'filters'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
          isLiked: any(named: 'isLiked'),
        ),
      ).called(1);
      verify(
        () =>
            pageState.mergeLikesServerResults(any(), isLikedSegment: any(named: 'isLikedSegment')),
      ).called(1);
      verify(
        () => pageState.syncLikesSegmentCacheFromVisible(
          hasMore: any(named: 'hasMore'),
          nextCursor: any(named: 'nextCursor'),
        ),
      ).called(1);
    });

    test('queues forceRefresh likes load while an in-flight likes fetch is active', () async {
      final gate = Completer<UnifiedPropertyResponse>();
      var calls = 0;
      when(
        () => swipesRepo.getSwipeHistoryProperties(
          filters: any(named: 'filters'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
          isLiked: any(named: 'isLiked'),
        ),
      ).thenAnswer((_) async {
        calls++;
        if (calls == 1) {
          return gate.future;
        }
        return UnifiedPropertyResponse(
          items: [testPropertyModel(id: 99)],
          nextCursor: null,
          hasMore: false,
        );
      });

      // Foreground load (empty cache).
      final first = loader.loadPageData(PageType.likes);
      // Allow the first fetch to register as active.
      await Future<void>.delayed(Duration.zero);

      // Segment switch / force refresh while first fetch is still pending.
      await loader.loadPageData(PageType.likes, forceRefresh: true);
      expect(calls, 1); // second call blocked until first completes

      gate.complete(
        UnifiedPropertyResponse(
          items: [testPropertyModel(id: 1)],
          nextCursor: null,
          hasMore: false,
        ),
      );
      await first;
      // Queued reload runs on a microtask after _finishActiveLoad.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(calls, 2);
    });

    test('skips when isLoading is true', () async {
      when(() => pageState.getStateForPage(any())).thenAnswer(
        (inv) => cachedState(
          inv.positionalArguments[0] as PageType,
          nextCursor: 'next',
        ).copyWith(isLoading: true),
      );

      await loader.loadMorePageData(PageType.explore);

      verifyNever(
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
      );
    });

    test('skips when isLoadingMore is true', () async {
      when(() => pageState.getStateForPage(any())).thenAnswer(
        (inv) => cachedState(
          inv.positionalArguments[0] as PageType,
          nextCursor: 'next',
        ).copyWith(isLoadingMore: true),
      );

      await loader.loadMorePageData(PageType.explore);

      verifyNever(
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
      );
    });

    test('skips when hasMore is false', () async {
      when(() => pageState.getStateForPage(any())).thenAnswer(
        (inv) =>
            cachedState(inv.positionalArguments[0] as PageType, nextCursor: 'next', hasMore: false),
      );

      await loader.loadMorePageData(PageType.explore);

      verifyNever(
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
      );
    });

    test('skips and clears isLoadingMore when no location set', () async {
      when(() => pageState.getStateForPage(any())).thenAnswer(
        (inv) => PageStateModel(
          pageType: inv.positionalArguments[0] as PageType,
          filters: UnifiedFilterModel.initial(),
          properties: [testPropertyModel(id: 1)],
          nextCursor: 'next',
          hasMore: true,
          selectedLocation: null,
        ),
      );

      await loader.loadMorePageData(PageType.explore);

      verifyNever(
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
      );
    });

    test('marks terminal when nextCursor is empty', () async {
      when(() => pageState.getStateForPage(any())).thenAnswer(
        (inv) => cachedState(inv.positionalArguments[0] as PageType, nextCursor: '', hasMore: true),
      );

      await loader.loadMorePageData(PageType.explore);

      final calls = verify(
        () => pageState.updatePageState(PageType.explore, captureAny()),
      ).captured.cast<PageStateModel>();
      expect(calls.any((s) => s.hasMore == false && !s.isLoadingMore), true);
    });

    test('catches error and resets isLoadingMore', () async {
      when(() => pageState.getStateForPage(any())).thenAnswer(
        (inv) =>
            cachedState(inv.positionalArguments[0] as PageType, nextCursor: 'next', hasMore: true),
      );
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
      ).thenThrow(Exception('load more failed'));

      await loader.loadMorePageData(PageType.explore);

      final calls = verify(
        () => pageState.updatePageState(PageType.explore, captureAny()),
      ).captured.cast<PageStateModel>();
      expect(calls.any((s) => !s.isLoadingMore), true);
    });

    test('loadMoreData alias delegates to loadMorePageData', () async {
      when(() => pageState.getStateForPage(any())).thenAnswer(
        (inv) =>
            cachedState(inv.positionalArguments[0] as PageType, nextCursor: 'next', hasMore: true),
      );
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

      await loader.loadMoreData(PageType.explore);

      verify(
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
      ).called(1);
    });
  });

  // ── debounceRefresh / refreshAllPagesData / dispose ──────────────────

  group('debounceRefresh', () {
    test('schedules a refresh for explore after delay', () async {
      when(
        () => pageState.getStateForPage(any()),
      ).thenAnswer((inv) => cachedState(inv.positionalArguments[0] as PageType));
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

      loader.debounceRefresh(PageType.explore);
      // Wait for the 500ms debounce timer to fire.
      await Future<void>.delayed(const Duration(milliseconds: 600));

      verify(
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
      ).called(1);
    });

    test('cancels previous debounce timer on repeated calls', () async {
      when(
        () => pageState.getStateForPage(any()),
      ).thenAnswer((inv) => cachedState(inv.positionalArguments[0] as PageType));
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

      // Call twice rapidly; only the last timer should fire.
      loader.debounceRefresh(PageType.discover);
      loader.debounceRefresh(PageType.discover);
      await Future<void>.delayed(const Duration(milliseconds: 600));

      verify(
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
      ).called(1);
    });
  });

  group('refreshAllPagesData', () {
    test('triggers forceRefresh for all three pages', () async {
      when(
        () => pageState.getStateForPage(any()),
      ).thenAnswer((inv) => cachedState(inv.positionalArguments[0] as PageType));
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

      loader.refreshAllPagesData();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // explore + discover hit properties repo, likes hits swipes repo.
      verify(
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
      ).called(2);
      verify(
        () => swipesRepo.getSwipeHistoryProperties(
          filters: any(named: 'filters'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
          isLiked: any(named: 'isLiked'),
        ),
      ).called(1);
    });
  });

  group('dispose', () {
    test('cancels pending debounce timers without throwing', () {
      // Schedule a debounce then dispose immediately.
      loader.debounceRefresh(PageType.explore);
      expect(() => loader.dispose(), returnsNormally);
    });
  });

  // ── _fetchAndUpdatePage: location fallback ───────────────────────────

  group('_fetchAndUpdatePage — location fallback', () {
    test('falls back to LocationController.getInitialLocation when no location', () async {
      // State with no selectedLocation forces the getInitialLocation path.
      when(() => pageState.getStateForPage(any())).thenAnswer(
        (inv) => PageStateModel(
          pageType: inv.positionalArguments[0] as PageType,
          filters: UnifiedFilterModel.initial(),
          properties: const [],
          selectedLocation: null,
        ),
      );
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

      await loader.loadPageData(PageType.explore);

      verify(() => locationController.getInitialLocation()).called(1);
    });
  });
}
