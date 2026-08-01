import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/controllers/page_state_service.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:ghar360/features/discover/presentation/controllers/discover_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/getx_test_binding.dart';
import '../../../../helpers/mocks.dart';
import '../../../../helpers/toast_host.dart';

class MockPageStateService extends GetxServiceMock implements PageStateService {}

class MockDashboardController extends GetxServiceMock implements DashboardController {}

void main() {
  late MockPageStateService mockPageStateService;
  late Rx<PageStateModel> discoverState;
  late Rx<PageType> currentPageType;

  setUpAll(() {
    registerFallbackValue(PageType.discover);
    registerFallbackValue(const UnifiedFilterModel());
    registerFallbackValue(testPropertyModel());
  });

  setUp(() {
    GetxTestBinding.init();

    mockPageStateService = MockPageStateService();
    discoverState = PageStateModel.initial(PageType.discover).obs;
    currentPageType = PageType.discover.obs;

    // Stub reactive fields so controller workers can register listeners
    when(() => mockPageStateService.discoverState).thenReturn(discoverState);
    when(() => mockPageStateService.currentPageType).thenReturn(currentPageType);

    // Stub methods that the controller or its helpers may call
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
    ).thenReturn(PageStateModel.initial(PageType.discover));
    when(() => mockPageStateService.updatePageFilters(any(), any())).thenReturn(null);
    when(() => mockPageStateService.useCurrentLocation()).thenAnswer((_) async {});
    when(() => mockPageStateService.useCurrentLocationForPage(any())).thenAnswer((_) async {});
    when(() => mockPageStateService.loadMoreData(any())).thenAnswer((_) async {});
    when(
      () => mockPageStateService.undoSwipe(
        propertyId: any(named: 'propertyId'),
        originalIsLiked: any(named: 'originalIsLiked'),
        notifyServer: any(named: 'notifyServer'),
      ),
    ).thenAnswer((_) async {});
    when(() => mockPageStateService.reinsertPropertyToDiscover(any())).thenReturn(null);

    GetxTestBinding.bind().register<PageStateService>(mockPageStateService);
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  DiscoverController createController() {
    final c = DiscoverController();
    c.onInit();
    return c;
  }

  List<PropertyModel> seedProperties(int count) {
    return List.generate(count, (i) => testPropertyModel(id: 100 + i));
  }

  void seedDeck(List<PropertyModel> properties) {
    discoverState.value = PageStateModel(
      pageType: PageType.discover,
      filters: const UnifiedFilterModel(),
      properties: properties,
    );
  }

  group('DiscoverController', () {
    test('initial state is DiscoverState.initial with empty deck and zero stats', () {
      final controller = createController();

      expect(controller.state.value, DiscoverState.initial);
      expect(controller.deck, isEmpty);
      expect(controller.totalSwipesInSession.value, 0);
      expect(controller.likesInSession.value, 0);
      expect(controller.passesInSession.value, 0);
      expect(controller.currentIndex.value, 0);
    });

    test('nextProperties returns empty list when deck is empty', () {
      final controller = createController();
      expect(controller.nextProperties, isEmpty);
    });

    test('nextProperties returns up to 3 properties after current index', () {
      final props = seedProperties(5);
      seedDeck(props);

      final controller = createController();
      final next = controller.nextProperties;

      expect(next.length, 3);
      expect(next[0].id, 101);
      expect(next[1].id, 102);
      expect(next[2].id, 103);
    });

    test('nextProperties returns remaining items when fewer than 3 left', () {
      final props = seedProperties(3);
      seedDeck(props);

      final controller = createController();
      final next = controller.nextProperties;

      // currentIndex is 0, so nextProperties skips the first, returns 2
      expect(next.length, 2);
      expect(next[0].id, 101);
      expect(next[1].id, 102);
    });

    test('progressPercentage returns 0 for empty deck', () {
      final controller = createController();
      expect(controller.progressPercentage, 0.0);
    });

    test('progressPercentage returns correct ratio when deck has items', () {
      final props = seedProperties(4);
      seedDeck(props);

      final controller = createController();
      controller.currentIndex.value = 1;

      expect(controller.progressPercentage, 0.25);
    });

    test('swipeRight increments like stats', () async {
      final props = seedProperties(5);
      seedDeck(props);

      final controller = createController();
      await controller.swipeRight(props[0]);

      expect(controller.totalSwipesInSession.value, 1);
      expect(controller.likesInSession.value, 1);
      expect(controller.passesInSession.value, 0);
    });

    test('swipeLeft increments pass stats', () async {
      final props = seedProperties(5);
      seedDeck(props);

      final controller = createController();
      await controller.swipeLeft(props[0]);

      expect(controller.totalSwipesInSession.value, 1);
      expect(controller.likesInSession.value, 0);
      expect(controller.passesInSession.value, 1);
    });

    test('retryLoading clears error and calls loadPageData', () {
      final controller = createController();
      controller.error.value = ServerException('test error');
      controller.state.value = DiscoverState.error;

      controller.retryLoading();

      expect(controller.error.value, isNull);
      verify(
        () => mockPageStateService.loadPageData(PageType.discover, forceRefresh: true),
      ).called(1);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // Additional tests for swipe actions, undo, filters, error/empty states,
  // pagination, and computed getters
  // ─────────────────────────────────────────────────────────────────────

  group('DiscoverController — computed getters', () {
    test('currentProperty returns null when deck is empty', () {
      final controller = createController();
      expect(controller.currentProperty, isNull);
    });

    test('currentProperty returns first property when deck has items', () {
      final props = seedProperties(3);
      seedDeck(props);

      final controller = createController();
      expect(controller.currentProperty?.id, 100);
    });

    test('currentProperty returns null when currentIndex exceeds deck length', () {
      final props = seedProperties(2);
      seedDeck(props);

      final controller = createController();
      controller.currentIndex.value = 5;

      expect(controller.currentProperty, isNull);
    });

    test('remainingCards returns 0 when deck is empty', () {
      final controller = createController();
      expect(controller.remainingCards, 0);
    });

    test('remainingCards returns count of cards after current index', () {
      final props = seedProperties(5);
      seedDeck(props);

      final controller = createController();
      // currentIndex=0, deck.length=5, remaining = 5-0-1 = 4
      expect(controller.remainingCards, 4);
    });

    test('sessionStats returns start_swiping_stats when no swipes', () {
      final controller = createController();
      // .tr returns key when no translation registered
      expect(controller.sessionStats, 'start_swiping_stats');
    });

    test('sessionStats returns formatted stats after swipes', () {
      final props = seedProperties(5);
      seedDeck(props);

      final controller = createController();
      controller.totalSwipesInSession.value = 4;
      controller.likesInSession.value = 1;

      // Should contain the session_stats key (untranslated)
      expect(controller.sessionStats, contains('session_stats'));
    });

    test('canSwipe is false when deck is empty', () {
      final controller = createController();
      expect(controller.canSwipe, isFalse);
    });

    test('canSwipe is true when deck has items and currentProperty is not null', () {
      final props = seedProperties(3);
      seedDeck(props);

      final controller = createController();
      expect(controller.canSwipe, isTrue);
    });

    test('hasProperties returns true when deck is non-empty', () {
      final props = seedProperties(1);
      seedDeck(props);

      final controller = createController();
      expect(controller.hasProperties, isTrue);
    });

    test('isLoading, isEmpty, hasError, isLoaded reflect state', () {
      final controller = createController();

      controller.state.value = DiscoverState.loading;
      expect(controller.isLoading, isTrue);

      controller.state.value = DiscoverState.empty;
      expect(controller.isEmpty, isTrue);

      controller.state.value = DiscoverState.error;
      expect(controller.hasError, isTrue);

      controller.state.value = DiscoverState.loaded;
      expect(controller.isLoaded, isTrue);
    });
  });

  group('DiscoverController — swipe actions', () {
    test('swipeRight removes property from deck via recordSwipe', () async {
      final props = seedProperties(3);
      seedDeck(props);

      final controller = createController();
      await controller.swipeRight(props[0]);

      // recordSwipe should have been called
      verify(() => mockPageStateService.recordSwipe(propertyId: 100, isLiked: true)).called(1);
    });

    test('swipeLeft removes property from deck via recordSwipe', () async {
      final props = seedProperties(3);
      seedDeck(props);

      final controller = createController();
      await controller.swipeLeft(props[0]);

      verify(() => mockPageStateService.recordSwipe(propertyId: 100, isLiked: false)).called(1);
    });

    test('swipeRight on property not in deck is ignored (duplicate gesture)', () async {
      final props = seedProperties(3);
      seedDeck(props);

      final controller = createController();
      // Property 999 is not in the deck
      final orphan = testPropertyModel(id: 999);
      await controller.swipeRight(orphan);

      // Stats should not increment
      expect(controller.totalSwipesInSession.value, 0);
      expect(controller.likesInSession.value, 0);
    });

    test('swipeLeft on property not in deck is ignored (duplicate gesture)', () async {
      final props = seedProperties(3);
      seedDeck(props);

      final controller = createController();
      final orphan = testPropertyModel(id: 999);
      await controller.swipeLeft(orphan);

      expect(controller.totalSwipesInSession.value, 0);
      expect(controller.passesInSession.value, 0);
    });

    test('swiping last property with no more pages sets empty state', () async {
      final props = seedProperties(1);
      discoverState.value = PageStateModel(
        pageType: PageType.discover,
        filters: const UnifiedFilterModel(),
        properties: props,
        hasMore: false,
      );

      // Make recordSwipe actually empty the deck (simulating optimistic removal)
      when(
        () => mockPageStateService.recordSwipe(
          propertyId: any(named: 'propertyId'),
          isLiked: any(named: 'isLiked'),
        ),
      ).thenAnswer((invocation) async {
        discoverState.value = const PageStateModel(
          pageType: PageType.discover,
          filters: UnifiedFilterModel(),
          properties: [],
          hasMore: false,
        );
      });

      final controller = createController();
      await controller.swipeRight(props[0]);

      expect(controller.state.value, DiscoverState.empty);
    });

    test('swipeRight reverts the card and toasts when the swipe fails to persist', () async {
      final props = seedProperties(3);
      seedDeck(props);

      when(
        () => mockPageStateService.recordSwipe(
          propertyId: any(named: 'propertyId'),
          isLiked: any(named: 'isLiked'),
        ),
      ).thenAnswer((_) async {
        // Simulate real network latency — the rejection must land after
        // swipeRight's own synchronous stat recording, exactly as a real
        // failed HTTP call would (never faster than the caller returning).
        await Future<void>.delayed(const Duration(milliseconds: 5));
        throw ServerException('boom');
      });

      final controller = createController();
      await controller.swipeRight(props[0]);

      // Let the fire-and-forget recordSwipe future reject and run .catchError.
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Session stats recorded optimistically are rolled back.
      expect(controller.totalSwipesInSession.value, 0);
      expect(controller.likesInSession.value, 0);

      verify(() => mockPageStateService.reinsertPropertyToDiscover(props[0])).called(1);
      verify(
        () => mockPageStateService.undoSwipe(
          propertyId: props[0].id,
          originalIsLiked: true,
          notifyServer: false,
        ),
      ).called(1);
    });

    testWidgets('a superseded failed swipe still tells the user it was not saved', (tester) async {
      // Slow network: the user swipes again while the first POST is still in
      // flight, then that POST fails. The deck-restore is correctly skipped
      // (restoring a superseded card would clobber newer state) — but the
      // property is gone having never reached the server, so staying silent
      // loses the swipe invisibly.
      final props = seedProperties(3);
      seedDeck(props);

      when(
        () => mockPageStateService.recordSwipe(
          propertyId: any(named: 'propertyId'),
          isLiked: any(named: 'isLiked'),
        ),
      ).thenAnswer((invocation) async {
        if (invocation.namedArguments[#propertyId] == props[0].id) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
          throw ServerException('boom');
        }
      });

      final controller = createController();

      await pumpToastHost(tester);
      // First swipe fails (slowly); the second supersedes it before it lands.
      await controller.swipeRight(props[0]);
      await controller.swipeRight(props[1]);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('Error'), findsOneWidget);
      expect(find.text('One of your swipes could not be saved.'), findsOneWidget);

      // The superseded card is still NOT restored — that guard must survive.
      verifyNever(() => mockPageStateService.reinsertPropertyToDiscover(props[0]));

      await settleToasts(tester);
    });

    test('a failed prefetch does not leave the controller stuck in prefetching', () async {
      // The reset to `loaded` sat after the await inside try, so a load-more
      // that threw left state == prefetching forever while isPrefetching
      // cleared in finally — isLoaded stayed false until the next emission.
      final props = seedProperties(1);
      discoverState.value = PageStateModel(
        pageType: PageType.discover,
        filters: const UnifiedFilterModel(),
        properties: props,
        hasMore: true,
      );
      when(() => mockPageStateService.loadMoreData(any())).thenThrow(ServerException('boom'));

      final controller = createController();
      await controller.swipeRight(props[0]);

      expect(controller.state.value, isNot(DiscoverState.prefetching));
      expect(controller.isLoaded, isTrue);
      expect(controller.isPrefetching.value, isFalse);
    });

    test('swiping last property with hasMore triggers prefetch', () async {
      final props = seedProperties(1);
      discoverState.value = PageStateModel(
        pageType: PageType.discover,
        filters: const UnifiedFilterModel(),
        properties: props,
        hasMore: true,
      );

      final controller = createController();
      await controller.swipeRight(props[0]);

      // loadMoreData should be called for prefetch
      verify(() => mockPageStateService.loadMoreData(PageType.discover)).called(1);
    });
  });

  group('DiscoverController — filter shortcuts', () {
    test('filterByPropertyType calls updatePageFilters with type', () {
      when(() => mockPageStateService.getCurrentPageState()).thenReturn(
        const PageStateModel(
          pageType: PageType.discover,
          filters: UnifiedFilterModel(),
          properties: [],
        ),
      );

      final controller = createController();
      controller.filterByPropertyType('apartment');

      verify(() => mockPageStateService.updatePageFilters(any(), any())).called(1);
    });

    test('filterByPurpose calls updatePageFilters with purpose', () {
      when(() => mockPageStateService.getCurrentPageState()).thenReturn(
        const PageStateModel(
          pageType: PageType.discover,
          filters: UnifiedFilterModel(),
          properties: [],
        ),
      );

      final controller = createController();
      controller.filterByPurpose('rent');

      verify(() => mockPageStateService.updatePageFilters(any(), any())).called(1);
    });

    test('showNearbyProperties calls useCurrentLocation', () async {
      final controller = createController();

      await controller.showNearbyProperties();

      verify(() => mockPageStateService.useCurrentLocation()).called(1);
    });
  });

  group('DiscoverController — error handling', () {
    test('clearError clears error and transitions from error to empty', () {
      final controller = createController();
      controller.error.value = ServerException('err');
      controller.state.value = DiscoverState.error;

      controller.clearError();

      expect(controller.error.value, isNull);
      expect(controller.state.value, DiscoverState.empty);
    });

    test('clearError transitions from error to loaded when deck has items', () {
      final props = seedProperties(2);
      seedDeck(props);

      final controller = createController();
      controller.error.value = ServerException('err');
      controller.state.value = DiscoverState.error;

      controller.clearError();

      expect(controller.error.value, isNull);
      expect(controller.state.value, DiscoverState.loaded);
    });

    test('clearError is a no-op when not in error state', () {
      final controller = createController();
      controller.state.value = DiscoverState.loaded;

      controller.clearError();

      expect(controller.state.value, DiscoverState.loaded);
    });
  });

  group('DiscoverController — refresh', () {
    test('refreshDeck resets session stats and currentIndex', () async {
      final props = seedProperties(5);
      seedDeck(props);

      final controller = createController();
      controller.totalSwipesInSession.value = 10;
      controller.likesInSession.value = 4;
      controller.passesInSession.value = 6;
      controller.currentIndex.value = 3;

      await controller.refreshDeck();

      expect(controller.totalSwipesInSession.value, 0);
      expect(controller.likesInSession.value, 0);
      expect(controller.passesInSession.value, 0);
      expect(controller.currentIndex.value, 0);
    });

    test('refreshDeck calls loadPageData with forceRefresh', () async {
      final controller = createController();

      await controller.refreshDeck();

      verify(
        () => mockPageStateService.loadPageData(PageType.discover, forceRefresh: true),
      ).called(1);
    });
  });

  group('DiscoverController — activatePage', () {
    test('activatePage with fresh data sets loaded state', () {
      final props = seedProperties(3);
      discoverState.value = PageStateModel(
        pageType: PageType.discover,
        filters: const UnifiedFilterModel(),
        properties: props,
        lastFetched: DateTime.now(),
      );

      final controller = createController();
      controller.state.value = DiscoverState.initial;

      controller.activatePage();

      expect(controller.state.value, DiscoverState.loaded);
    });

    test('activatePage with stale data triggers background refresh', () {
      final props = seedProperties(3);
      discoverState.value = PageStateModel(
        pageType: PageType.discover,
        filters: const UnifiedFilterModel(),
        properties: props,
        lastFetched: DateTime.now().subtract(const Duration(minutes: 10)),
      );

      final controller = createController();
      controller.state.value = DiscoverState.loaded;

      controller.activatePage();

      verify(
        () => mockPageStateService.loadPageData(PageType.discover, backgroundRefresh: true),
      ).called(1);
    });

    test('activatePage with empty data triggers location + load', () {
      final controller = createController();
      controller.state.value = DiscoverState.initial;

      controller.activatePage();

      verify(() => mockPageStateService.useCurrentLocationForPage(PageType.discover)).called(1);
    });
  });

  group('DiscoverController — state sync worker', () {
    test('state sync transitions to loading when page state is loading', () {
      final controller = createController();

      discoverState.value = const PageStateModel(
        pageType: PageType.discover,
        filters: UnifiedFilterModel(),
        properties: [],
        isLoading: true,
      );

      expect(controller.state.value, DiscoverState.loading);
    });

    test('state sync transitions to error when page state has error and empty props', () {
      final controller = createController();
      // First move out of initial so the empty check passes
      controller.state.value = DiscoverState.loading;

      discoverState.value = PageStateModel(
        pageType: PageType.discover,
        filters: const UnifiedFilterModel(),
        properties: [],
        error: ServerException('err'),
      );

      expect(controller.state.value, DiscoverState.error);
      expect(controller.error.value, isNotNull);
    });

    test('state sync transitions to loaded when properties arrive', () {
      final controller = createController();
      controller.state.value = DiscoverState.empty;

      discoverState.value = PageStateModel(
        pageType: PageType.discover,
        filters: const UnifiedFilterModel(),
        properties: seedProperties(2),
      );

      expect(controller.state.value, DiscoverState.loaded);
      expect(controller.error.value, isNull);
    });

    test('state sync keeps currentIndex in bounds', () {
      final controller = createController();
      controller.currentIndex.value = 5;

      discoverState.value = PageStateModel(
        pageType: PageType.discover,
        filters: const UnifiedFilterModel(),
        properties: seedProperties(2),
      );

      expect(controller.currentIndex.value, 0);
    });
  });

  group('DiscoverController — remaining high-miss paths', () {
    test('onReady activates page when already on discover', () async {
      final props = seedProperties(2);
      discoverState.value = PageStateModel(
        pageType: PageType.discover,
        filters: const UnifiedFilterModel(),
        properties: props,
        lastFetched: DateTime.now(),
      );

      final controller = createController();
      controller.state.value = DiscoverState.initial;
      controller.onReady();

      // Delayed activatePage (100ms)
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(controller.state.value, DiscoverState.loaded);
    });

    test('page activation worker reacts to currentPageType changes', () async {
      currentPageType.value = PageType.explore;
      final controller = createController();
      controller.onReady();

      final props = seedProperties(2);
      discoverState.value = PageStateModel(
        pageType: PageType.discover,
        filters: const UnifiedFilterModel(),
        properties: props,
        lastFetched: DateTime.now(),
      );
      controller.state.value = DiscoverState.initial;

      currentPageType.value = PageType.discover;
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(controller.state.value, DiscoverState.loaded);
    });

    test('state sync skips updates while prefetching', () {
      final controller = createController();
      controller.state.value = DiscoverState.prefetching;
      controller.isPrefetching.value = true;

      discoverState.value = const PageStateModel(
        pageType: PageType.discover,
        filters: UnifiedFilterModel(),
        properties: [],
        isLoading: true,
      );

      // Should remain prefetching because isPrefetching short-circuits
      expect(controller.state.value, DiscoverState.prefetching);
    });

    test('state sync transitions to empty when properties become empty after load', () {
      final props = seedProperties(1);
      seedDeck(props);
      final controller = createController();
      controller.state.value = DiscoverState.loaded;

      discoverState.value = const PageStateModel(
        pageType: PageType.discover,
        filters: UnifiedFilterModel(),
        properties: [],
        isLoading: false,
      );

      expect(controller.state.value, DiscoverState.empty);
    });

    test('activatePage forces reload for empty non-initial state', () {
      discoverState.value = PageStateModel(
        pageType: PageType.discover,
        filters: const UnifiedFilterModel(),
        properties: [],
        lastFetched: DateTime.now(), // not stale by time, but empty + non-initial
      );

      final controller = createController();
      controller.state.value = DiscoverState.empty;

      controller.activatePage();

      // Empty with non-stale lastFetched and non-initial may hit final force path
      verify(
        () => mockPageStateService.useCurrentLocationForPage(PageType.discover),
      ).called(greaterThanOrEqualTo(1));
      expect(controller.state.value, DiscoverState.loading);
    });

    test('activatePage forces reload for stale loading without data', () {
      discoverState.value = const PageStateModel(
        pageType: PageType.discover,
        filters: UnifiedFilterModel(),
        properties: [],
        isLoading: true,
      );

      final controller = createController();
      controller.state.value = DiscoverState.loading;

      controller.activatePage();

      verify(
        () => mockPageStateService.useCurrentLocationForPage(PageType.discover),
      ).called(greaterThanOrEqualTo(1));
    });

    test('_loadInitialDeck surfaces mapped error when loadPageData throws', () async {
      when(
        () => mockPageStateService.loadPageData(
          any(),
          forceRefresh: any(named: 'forceRefresh'),
          backgroundRefresh: any(named: 'backgroundRefresh'),
        ),
      ).thenThrow(Exception('boom'));

      final controller = createController();
      await controller.refreshDeck();

      expect(controller.state.value, DiscoverState.error);
      expect(controller.error.value, isA<NetworkException>());
    });

    test('retryLoading is no-op when already loading (guard)', () async {
      final controller = createController();
      controller.state.value = DiscoverState.loading;

      // _loadInitialDeck returns early when already loading unless ignoreLoadingGuard
      controller.retryLoading();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // loadPageData may still not be called from retry if guard blocks
      // (retryLoading calls _loadInitialDeck without ignoreLoadingGuard)
      expect(controller.state.value, DiscoverState.loading);
    });

    test('swipeRight records dashboard activity when DashboardController registered', () async {
      final mockDash = MockDashboardController();
      when(() => mockDash.incrementStat(any(), by: any(named: 'by'))).thenReturn(null);
      when(
        () => mockDash.recordActivity(
          type: any(named: 'type'),
          title: any(named: 'title'),
          icon: any(named: 'icon'),
        ),
      ).thenReturn(null);
      Get.put<DashboardController>(mockDash, permanent: true);

      final props = seedProperties(3);
      seedDeck(props);
      final controller = createController();
      await controller.swipeRight(props[0]);

      verify(() => mockDash.incrementStat(kDashPropertiesViewedKey)).called(1);
      verify(() => mockDash.incrementStat(kDashPropertiesLikedKey)).called(1);
      verify(
        () => mockDash.recordActivity(
          type: 'like',
          title: any(named: 'title'),
          icon: 'favorite',
        ),
      ).called(1);

      Get.delete<DashboardController>();
    });

    test('prefetch failure is swallowed and clears isPrefetching', () async {
      when(() => mockPageStateService.loadMoreData(any())).thenThrow(Exception('prefetch fail'));

      final props = seedProperties(1);
      discoverState.value = PageStateModel(
        pageType: PageType.discover,
        filters: const UnifiedFilterModel(),
        properties: props,
        hasMore: true,
      );

      final controller = createController();
      await controller.swipeRight(props[0]);

      // Allow prefetch future to complete
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(controller.isPrefetching.value, isFalse);
    });

    test('viewPropertyDetails navigates without throwing in test mode', () {
      final controller = createController();
      final prop = testPropertyModel(id: 55);
      expect(() => controller.viewPropertyDetails(prop), returnsNormally);
    });

    test('onClose disposes workers without throwing', () {
      final controller = createController();
      controller.onReady();
      expect(() => controller.onClose(), returnsNormally);
    });

    test('mid-deck swipe with low remaining and hasMore prefetches', () async {
      // 4 cards, remaining after swipe check = 4 - 0 - 1 = 3 <= threshold
      final props = seedProperties(4);
      discoverState.value = PageStateModel(
        pageType: PageType.discover,
        filters: const UnifiedFilterModel(),
        properties: props,
        hasMore: true,
      );

      final controller = createController();
      await controller.swipeLeft(props[0]);

      verify(() => mockPageStateService.loadMoreData(PageType.discover)).called(1);
    });

    test('swipeLeft records pass dashboard activity when registered', () async {
      final mockDash = MockDashboardController();
      when(() => mockDash.incrementStat(any(), by: any(named: 'by'))).thenReturn(null);
      when(
        () => mockDash.recordActivity(
          type: any(named: 'type'),
          title: any(named: 'title'),
          icon: any(named: 'icon'),
        ),
      ).thenReturn(null);
      Get.put<DashboardController>(mockDash, permanent: true);

      final props = seedProperties(2);
      seedDeck(props);
      final controller = createController();
      await controller.swipeLeft(props[0]);

      verify(
        () => mockDash.recordActivity(
          type: 'pass',
          title: any(named: 'title'),
          icon: 'close',
        ),
      ).called(1);

      Get.delete<DashboardController>();
    });
  });
}
