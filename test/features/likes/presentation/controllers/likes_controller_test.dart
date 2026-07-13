import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/controllers/page_state_service.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/likes/presentation/controllers/likes_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/getx_test_binding.dart';
import '../../../../helpers/mocks.dart';

class MockPageStateService extends GetxServiceMock implements PageStateService {}

void main() {
  late MockPageStateService mockPageStateService;
  late Rx<PageStateModel> likesState;
  late Rx<PageType> currentPageType;

  setUpAll(() {
    registerFallbackValue(PageType.likes);
  });

  setUp(() {
    GetxTestBinding.init();

    mockPageStateService = MockPageStateService();
    likesState = PageStateModel.initial(PageType.likes).obs;
    currentPageType = PageType.likes.obs;

    // Stub reactive fields
    when(() => mockPageStateService.likesState).thenReturn(likesState);
    when(() => mockPageStateService.currentPageType).thenReturn(currentPageType);
    when(() => mockPageStateService.currentLikesSegment).thenReturn('liked');

    // Stub methods
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
    when(() => mockPageStateService.updatePageSearch(any(), any())).thenReturn(null);
    when(() => mockPageStateService.updateLikesSegment(any())).thenReturn(null);
    when(() => mockPageStateService.loadMorePageData(any())).thenAnswer((_) async {});
    when(() => mockPageStateService.useCurrentLocationForPage(any())).thenAnswer((_) async {});
    when(() => mockPageStateService.removePropertyFromLikes(any())).thenReturn(null);

    GetxTestBinding.bind().register<PageStateService>(mockPageStateService);
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  LikesController createController() {
    final c = LikesController();
    c.onInit();
    return c;
  }

  List<PropertyModel> seedProperties(int count) {
    return List.generate(count, (i) => testPropertyModel(id: 200 + i));
  }

  group('LikesController', () {
    test('initial state has liked segment selected and empty properties', () {
      final controller = createController();

      expect(controller.currentSegment.value, LikesSegment.liked);
      expect(controller.likedProperties, isEmpty);
      expect(controller.passedProperties, isEmpty);
      expect(controller.searchQuery.value, '');
    });

    test('switchToSegment updates segment and calls updateLikesSegment', () {
      final controller = createController();

      controller.switchToSegment(LikesSegment.passed);

      expect(controller.currentSegment.value, LikesSegment.passed);
      verify(() => mockPageStateService.updateLikesSegment('passed')).called(1);
    });

    test('switchToSegment same segment is a no-op', () {
      final controller = createController();
      // Default segment is 'liked'
      controller.switchToSegment(LikesSegment.liked);

      // updateLikesSegment should NOT be called since segment didn't change
      verifyNever(() => mockPageStateService.updateLikesSegment(any()));
    });

    test('addToFavourites calls recordSwipe with isLiked true', () async {
      final controller = createController();

      await controller.addToFavourites(42);

      verify(() => mockPageStateService.recordSwipe(propertyId: 42, isLiked: true)).called(1);
      verify(() => mockPageStateService.loadPageData(PageType.likes, forceRefresh: true)).called(1);
    });

    test('removeFromFavourites calls recordSwipe with isLiked false', () async {
      final controller = createController();

      await controller.removeFromFavourites(42);

      verify(() => mockPageStateService.recordSwipe(propertyId: 42, isLiked: false)).called(1);
      verify(() => mockPageStateService.loadPageData(PageType.likes, forceRefresh: true)).called(1);
    });

    test('currentProperties returns properties from page state', () {
      final props = seedProperties(3);
      likesState.value = PageStateModel(
        pageType: PageType.likes,
        filters: const UnifiedFilterModel(),
        properties: props,
        additionalData: const {'currentSegment': 'liked'},
      );

      final controller = createController();
      expect(controller.currentProperties.length, 3);
    });

    test('retryCurrentSegment calls loadPageData', () {
      final controller = createController();

      controller.retryCurrentSegment();

      verify(() => mockPageStateService.loadPageData(PageType.likes, forceRefresh: true)).called(1);
    });

    test('clearSearch resets query and calls updatePageSearch', () {
      final controller = createController();
      controller.searchQuery.value = 'test query';

      controller.clearSearch();

      expect(controller.searchQuery.value, '');
      verify(() => mockPageStateService.updatePageSearch(PageType.likes, '')).called(1);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // Additional tests for segment switching, search, pagination, property
  // removal, state getters, and error handling
  // ─────────────────────────────────────────────────────────────────────

  group('LikesController — segment switching', () {
    test('switchToSegment to passed updates segment', () {
      final controller = createController();

      controller.switchToSegment(LikesSegment.passed);

      expect(controller.currentSegment.value, LikesSegment.passed);
      verify(() => mockPageStateService.updateLikesSegment('passed')).called(1);
    });

    test('switchToSegment back to liked updates segment', () {
      final controller = createController();
      controller.switchToSegment(LikesSegment.passed);

      controller.switchToSegment(LikesSegment.liked);

      expect(controller.currentSegment.value, LikesSegment.liked);
      verify(() => mockPageStateService.updateLikesSegment('liked')).called(1);
    });

    test('switchToSegment to passed twice only calls update once', () {
      final controller = createController();
      controller.switchToSegment(LikesSegment.passed);

      controller.switchToSegment(LikesSegment.passed);

      verify(() => mockPageStateService.updateLikesSegment('passed')).called(1);
    });
  });

  group('LikesController — search', () {
    test('updateSearchQuery sets searchQuery reactively', () {
      final controller = createController();

      controller.updateSearchQuery('luxury apartment');

      expect(controller.searchQuery.value, 'luxury apartment');
    });

    test('hasSearchQuery returns false when query is empty', () {
      final controller = createController();

      expect(controller.hasSearchQuery, isFalse);
    });

    test('hasSearchQuery returns true when query is non-empty', () {
      final controller = createController();
      controller.searchQuery.value = 'villa';

      expect(controller.hasSearchQuery, isTrue);
    });
  });

  group('LikesController — pagination', () {
    test('loadMoreCurrentSegment calls loadMorePageData', () async {
      final controller = createController();

      await controller.loadMoreCurrentSegment();

      verify(() => mockPageStateService.loadMorePageData(PageType.likes)).called(1);
    });

    test('loadMoreLiked calls loadMorePageData', () async {
      final controller = createController();

      await controller.loadMoreLiked();

      verify(() => mockPageStateService.loadMorePageData(PageType.likes)).called(1);
    });

    test('loadMorePassed calls loadMorePageData', () async {
      final controller = createController();

      await controller.loadMorePassed();

      verify(() => mockPageStateService.loadMorePageData(PageType.likes)).called(1);
    });
  });

  group('LikesController — refresh', () {
    test('refreshCurrentSegment calls loadPageData for liked segment', () async {
      final controller = createController();
      controller.currentSegment.value = LikesSegment.liked;

      await controller.refreshCurrentSegment();

      verify(() => mockPageStateService.loadPageData(PageType.likes, forceRefresh: true)).called(1);
    });

    test('refreshCurrentSegment calls loadPageData for passed segment', () async {
      final controller = createController();
      controller.currentSegment.value = LikesSegment.passed;

      await controller.refreshCurrentSegment();

      verify(() => mockPageStateService.loadPageData(PageType.likes, forceRefresh: true)).called(1);
    });

    test('refreshLiked calls loadPageData with forceRefresh', () async {
      final controller = createController();

      await controller.refreshLiked();

      verify(() => mockPageStateService.loadPageData(PageType.likes, forceRefresh: true)).called(1);
    });

    test('refreshPassed calls loadPageData with forceRefresh', () async {
      final controller = createController();

      await controller.refreshPassed();

      verify(() => mockPageStateService.loadPageData(PageType.likes, forceRefresh: true)).called(1);
    });

    test('refreshAll calls loadPageData with forceRefresh', () async {
      final controller = createController();

      await controller.refreshAll();

      verify(() => mockPageStateService.loadPageData(PageType.likes, forceRefresh: true)).called(1);
    });
  });

  group('LikesController — retry', () {
    test('retryLiked calls loadPageData with forceRefresh', () {
      final controller = createController();

      controller.retryLiked();

      verify(() => mockPageStateService.loadPageData(PageType.likes, forceRefresh: true)).called(1);
    });

    test('retryPassed calls loadPageData with forceRefresh', () {
      final controller = createController();

      controller.retryPassed();

      verify(() => mockPageStateService.loadPageData(PageType.likes, forceRefresh: true)).called(1);
    });

    test('retryCurrentSegment for liked segment calls retryLiked', () {
      final controller = createController();
      controller.currentSegment.value = LikesSegment.liked;

      controller.retryCurrentSegment();

      verify(() => mockPageStateService.loadPageData(PageType.likes, forceRefresh: true)).called(1);
    });

    test('retryCurrentSegment for passed segment calls retryPassed', () {
      final controller = createController();
      controller.currentSegment.value = LikesSegment.passed;

      controller.retryCurrentSegment();

      verify(() => mockPageStateService.loadPageData(PageType.likes, forceRefresh: true)).called(1);
    });
  });

  group('LikesController — property removal', () {
    test('removeFromLikes calls removePropertyFromLikes and recordSwipe', () async {
      final props = seedProperties(2);
      likesState.value = PageStateModel(
        pageType: PageType.likes,
        filters: const UnifiedFilterModel(),
        properties: props,
        additionalData: const {'currentSegment': 'liked'},
      );

      final controller = createController();
      await controller.removeFromLikes(props[0]);

      verify(() => mockPageStateService.removePropertyFromLikes(props[0].id)).called(1);
      verify(
        () => mockPageStateService.recordSwipe(propertyId: props[0].id, isLiked: false),
      ).called(1);
    });

    test('removeFromLikes refreshes data on failure', () async {
      final props = seedProperties(2);
      likesState.value = PageStateModel(
        pageType: PageType.likes,
        filters: const UnifiedFilterModel(),
        properties: props,
        additionalData: const {'currentSegment': 'liked'},
      );

      when(
        () => mockPageStateService.recordSwipe(
          propertyId: any(named: 'propertyId'),
          isLiked: any(named: 'isLiked'),
        ),
      ).thenThrow(ServerException('network error'));

      final controller = createController();
      await controller.removeFromLikes(props[0]);

      // Should refresh to restore correct state
      verify(() => mockPageStateService.loadPageData(PageType.likes, forceRefresh: true)).called(1);
    });
  });

  group('LikesController — moveToLikes', () {
    test('moveToLikes calls removePropertyFromLikes and recordSwipe with isLiked true', () async {
      final props = seedProperties(2);
      likesState.value = PageStateModel(
        pageType: PageType.likes,
        filters: const UnifiedFilterModel(),
        properties: props,
        additionalData: const {'currentSegment': 'passed'},
      );

      final controller = createController();
      await controller.moveToLikes(props[0]);

      verify(() => mockPageStateService.removePropertyFromLikes(props[0].id)).called(1);
      verify(
        () => mockPageStateService.recordSwipe(propertyId: props[0].id, isLiked: true),
      ).called(1);
    });

    test('moveToLikes refreshes data on failure', () async {
      final props = seedProperties(2);
      likesState.value = PageStateModel(
        pageType: PageType.likes,
        filters: const UnifiedFilterModel(),
        properties: props,
        additionalData: const {'currentSegment': 'passed'},
      );

      when(
        () => mockPageStateService.recordSwipe(
          propertyId: any(named: 'propertyId'),
          isLiked: any(named: 'isLiked'),
        ),
      ).thenThrow(ServerException('network error'));

      final controller = createController();
      await controller.moveToLikes(props[0]);

      verify(() => mockPageStateService.loadPageData(PageType.likes, forceRefresh: true)).called(1);
    });
  });

  group('LikesController — isFavourite', () {
    test('returns true when property is in liked properties', () {
      final props = seedProperties(2);
      likesState.value = PageStateModel(
        pageType: PageType.likes,
        filters: const UnifiedFilterModel(),
        properties: props,
        additionalData: const {'currentSegment': 'liked'},
      );

      final controller = createController();

      expect(controller.isFavourite(props[0].id), isTrue);
    });

    test('returns false when property is not in liked properties', () {
      final controller = createController();

      expect(controller.isFavourite(999), isFalse);
    });

    test('handles string property IDs', () {
      final props = seedProperties(1);
      likesState.value = PageStateModel(
        pageType: PageType.likes,
        filters: const UnifiedFilterModel(),
        properties: props,
        additionalData: const {'currentSegment': 'liked'},
      );

      final controller = createController();

      expect(controller.isFavourite(props[0].id.toString()), isTrue);
    });
  });

  group('LikesController — state getters', () {
    test('currentState returns loading when page state is loading', () {
      likesState.value = const PageStateModel(
        pageType: PageType.likes,
        filters: UnifiedFilterModel(),
        properties: [],
        isLoading: true,
      );

      final controller = createController();

      expect(controller.currentState, LikesState.loading);
    });

    test('currentState returns loadingMore when page state is loadingMore', () {
      likesState.value = const PageStateModel(
        pageType: PageType.likes,
        filters: UnifiedFilterModel(),
        properties: [],
        isLoadingMore: true,
      );

      final controller = createController();

      expect(controller.currentState, LikesState.loadingMore);
    });

    test('currentState returns error when page state has error', () {
      likesState.value = PageStateModel(
        pageType: PageType.likes,
        filters: const UnifiedFilterModel(),
        properties: [],
        error: ServerException('err'),
      );

      final controller = createController();

      expect(controller.currentState, LikesState.error);
    });

    test('currentState returns empty when properties are empty and not loading', () {
      likesState.value = const PageStateModel(
        pageType: PageType.likes,
        filters: UnifiedFilterModel(),
        properties: [],
      );

      final controller = createController();

      expect(controller.currentState, LikesState.empty);
    });

    test('currentState returns loaded when properties are present', () {
      likesState.value = PageStateModel(
        pageType: PageType.likes,
        filters: const UnifiedFilterModel(),
        properties: seedProperties(2),
      );

      final controller = createController();

      expect(controller.currentState, LikesState.loaded);
    });

    test('currentError returns error string from page state', () {
      final err = ServerException('test error');
      likesState.value = PageStateModel(
        pageType: PageType.likes,
        filters: const UnifiedFilterModel(),
        properties: [],
        error: err,
      );

      final controller = createController();

      expect(controller.currentError, err.toString());
    });

    test('currentError returns null when no error', () {
      final controller = createController();

      expect(controller.currentError, isNull);
    });

    test('currentHasMore delegates to page state', () {
      likesState.value = PageStateModel(
        pageType: PageType.likes,
        filters: const UnifiedFilterModel(),
        properties: seedProperties(2),
        hasMore: true,
      );

      final controller = createController();

      expect(controller.currentHasMore, isTrue);
    });
  });

  group('LikesController — helper getters', () {
    test('isCurrentLoading returns true when page state is loading', () {
      likesState.value = const PageStateModel(
        pageType: PageType.likes,
        filters: UnifiedFilterModel(),
        properties: [],
        isLoading: true,
      );

      final controller = createController();

      expect(controller.isCurrentLoading, isTrue);
    });

    test('isCurrentEmpty returns true when not loading, empty, and no error', () {
      likesState.value = const PageStateModel(
        pageType: PageType.likes,
        filters: UnifiedFilterModel(),
        properties: [],
      );

      final controller = createController();

      expect(controller.isCurrentEmpty, isTrue);
    });

    test('isCurrentEmpty returns false when loading', () {
      likesState.value = const PageStateModel(
        pageType: PageType.likes,
        filters: UnifiedFilterModel(),
        properties: [],
        isLoading: true,
      );

      final controller = createController();

      expect(controller.isCurrentEmpty, isFalse);
    });

    test('hasCurrentError returns true when page state has error', () {
      likesState.value = PageStateModel(
        pageType: PageType.likes,
        filters: const UnifiedFilterModel(),
        properties: [],
        error: ServerException('err'),
      );

      final controller = createController();

      expect(controller.hasCurrentError, isTrue);
    });

    test('isCurrentLoaded returns true when not loading, not empty, no error', () {
      likesState.value = PageStateModel(
        pageType: PageType.likes,
        filters: const UnifiedFilterModel(),
        properties: seedProperties(2),
      );

      final controller = createController();

      expect(controller.isCurrentLoaded, isTrue);
    });

    test('isCurrentLoadingMore returns true when page state is loadingMore', () {
      likesState.value = PageStateModel(
        pageType: PageType.likes,
        filters: const UnifiedFilterModel(),
        properties: seedProperties(2),
        isLoadingMore: true,
      );

      final controller = createController();

      expect(controller.isCurrentLoadingMore, isTrue);
    });

    test('hasCurrentProperties returns true when properties exist', () {
      likesState.value = PageStateModel(
        pageType: PageType.likes,
        filters: const UnifiedFilterModel(),
        properties: seedProperties(1),
      );

      final controller = createController();

      expect(controller.hasCurrentProperties, isTrue);
    });
  });

  group('LikesController — display text getters', () {
    test('currentSegmentTitle returns liked_properties for liked segment', () {
      final controller = createController();
      controller.currentSegment.value = LikesSegment.liked;

      expect(controller.currentSegmentTitle, 'liked_properties');
    });

    test('currentSegmentTitle returns passed_properties for passed segment', () {
      final controller = createController();
      controller.currentSegment.value = LikesSegment.passed;

      expect(controller.currentSegmentTitle, 'passed_properties');
    });

    test('currentCountText returns count with properties for multiple', () {
      likesState.value = PageStateModel(
        pageType: PageType.likes,
        filters: const UnifiedFilterModel(),
        properties: seedProperties(3),
      );

      final controller = createController();

      expect(controller.currentCountText, contains('3'));
    });

    test('currentCountText returns singular for single property', () {
      likesState.value = PageStateModel(
        pageType: PageType.likes,
        filters: const UnifiedFilterModel(),
        properties: seedProperties(1),
      );

      final controller = createController();

      expect(controller.currentCountText, contains('1'));
    });

    test('emptyStateMessage returns search-specific message when searching', () {
      final controller = createController();
      controller.searchQuery.value = 'test';

      expect(controller.emptyStateMessage, contains('no_properties_match_your_search'));
    });

    test('emptyStateMessage returns liked-specific message for liked segment', () {
      final controller = createController();
      controller.currentSegment.value = LikesSegment.liked;
      controller.searchQuery.value = '';

      expect(controller.emptyStateMessage, contains('no_liked_properties'));
    });

    test('emptyStateMessage returns passed-specific message for passed segment', () {
      final controller = createController();
      controller.currentSegment.value = LikesSegment.passed;
      controller.searchQuery.value = '';

      expect(controller.emptyStateMessage, contains('no_passed_properties'));
    });
  });

  group('LikesController — activatePage', () {
    test('activatePage loads data when no location is available', () {
      final controller = createController();

      // likesState is initial (no location)
      controller.activatePage();

      verify(() => mockPageStateService.useCurrentLocationForPage(PageType.likes)).called(1);
    });

    test('activatePage skips when already loading', () {
      likesState.value = const PageStateModel(
        pageType: PageType.likes,
        filters: UnifiedFilterModel(),
        properties: [],
        isLoading: true,
        selectedLocation: LocationData(name: 'Test', latitude: 28.61, longitude: 77.21),
      );

      final controller = createController();

      controller.activatePage();

      // Should not call loadPageData since already loading
      verifyNever(
        () => mockPageStateService.loadPageData(any(), forceRefresh: any(named: 'forceRefresh')),
      );
    });

    test('activatePage loads data when properties are empty', () {
      likesState.value = const PageStateModel(
        pageType: PageType.likes,
        filters: UnifiedFilterModel(),
        properties: [],
        selectedLocation: LocationData(name: 'Test', latitude: 28.61, longitude: 77.21),
      );

      final controller = createController();

      controller.activatePage();

      verify(() => mockPageStateService.loadPageData(PageType.likes, forceRefresh: true)).called(1);
    });

    test('activatePage background refreshes when data is stale', () {
      likesState.value = PageStateModel(
        pageType: PageType.likes,
        filters: const UnifiedFilterModel(),
        properties: seedProperties(2),
        selectedLocation: const LocationData(name: 'Test', latitude: 28.61, longitude: 77.21),
        lastFetched: DateTime.now().subtract(const Duration(minutes: 10)),
      );

      final controller = createController();

      controller.activatePage();

      verify(
        () => mockPageStateService.loadPageData(PageType.likes, backgroundRefresh: true),
      ).called(1);
    });
  });
}
