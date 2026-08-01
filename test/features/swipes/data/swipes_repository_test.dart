// test/features/swipes/data/swipes_repository_test.dart
//
// Unit tests for [SwipesRepository]. Covers:
// - recordSwipe success
// - recordSwipe network failure enqueues to offline queue
// - recordSwipe queue failure rethrows

import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/controllers/offline_queue_service.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/swipes/data/swipes_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/getx_test_binding.dart';
import '../../../helpers/mocks.dart';
import '../../../helpers/test_data.dart';

class MockOfflineQueueService extends GetxServiceMock implements OfflineQueueService {}

void main() {
  late MockApiClient mockApiClient;
  late MockOfflineQueueService mockOfflineQueue;
  late SwipesRepository repository;

  setUp(() {
    GetxTestBinding.init();
    mockApiClient = MockApiClient();
    mockOfflineQueue = MockOfflineQueueService();

    GetxTestBinding.bind()
      ..register<ApiClient>(mockApiClient)
      ..register<OfflineQueueService>(mockOfflineQueue);

    repository = SwipesRepository();
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  group('SwipesRepository', () {
    // ── recordSwipe success ────────────────────────────────────────────

    test('recordSwipe completes successfully on valid API response', () async {
      when(
        () => mockApiClient.post(
          '/swipes',
          body: any(named: 'body'),
          idempotent: any(named: 'idempotent'),
        ),
      ).thenAnswer((_) async => ApiResponse(statusCode: 200, body: {}, headers: {}));

      await repository.recordSwipe(propertyId: 100, isLiked: true);

      verify(
        () => mockApiClient.post(
          '/swipes',
          body: {'property_id': 100, 'is_liked': true},
          idempotent: true,
        ),
      ).called(1);
    });

    test('recordSwipe with isLiked=false sends correct payload', () async {
      when(
        () => mockApiClient.post(
          '/swipes',
          body: any(named: 'body'),
          idempotent: any(named: 'idempotent'),
        ),
      ).thenAnswer((_) async => ApiResponse(statusCode: 200, body: {}, headers: {}));

      await repository.recordSwipe(propertyId: 200, isLiked: false);

      verify(
        () => mockApiClient.post(
          '/swipes',
          body: {'property_id': 200, 'is_liked': false},
          idempotent: true,
        ),
      ).called(1);
    });

    // ── recordSwipe network failure enqueues to offline queue ──────────

    test('recordSwipe enqueues to offline queue on NetworkException', () async {
      when(
        () => mockApiClient.post(
          '/swipes',
          body: any(named: 'body'),
          idempotent: any(named: 'idempotent'),
        ),
      ).thenThrow(NetworkException('No internet connection'));

      when(
        () => mockOfflineQueue.enqueueSwipe(
          propertyId: any(named: 'propertyId'),
          isLiked: any(named: 'isLiked'),
        ),
      ).thenAnswer((_) async {});

      // Should not throw — swallows network error after enqueueing
      await repository.recordSwipe(propertyId: 100, isLiked: true);

      verify(() => mockOfflineQueue.enqueueSwipe(propertyId: 100, isLiked: true)).called(1);
    });

    test('recordSwipe enqueues dislike on NetworkException', () async {
      when(
        () => mockApiClient.post(
          '/swipes',
          body: any(named: 'body'),
          idempotent: any(named: 'idempotent'),
        ),
      ).thenThrow(NetworkException('Connection refused'));

      when(
        () => mockOfflineQueue.enqueueSwipe(
          propertyId: any(named: 'propertyId'),
          isLiked: any(named: 'isLiked'),
        ),
      ).thenAnswer((_) async {});

      await repository.recordSwipe(propertyId: 50, isLiked: false);

      verify(() => mockOfflineQueue.enqueueSwipe(propertyId: 50, isLiked: false)).called(1);
    });

    // ── recordSwipe queue failure rethrows ─────────────────────────────

    test('recordSwipe rethrows when offline queue enqueue fails', () async {
      when(
        () => mockApiClient.post(
          '/swipes',
          body: any(named: 'body'),
          idempotent: any(named: 'idempotent'),
        ),
      ).thenThrow(NetworkException('Offline'));

      when(
        () => mockOfflineQueue.enqueueSwipe(
          propertyId: any(named: 'propertyId'),
          isLiked: any(named: 'isLiked'),
        ),
      ).thenThrow(Exception('Queue storage full'));

      expect(
        () => repository.recordSwipe(propertyId: 100, isLiked: true),
        throwsA(isA<Exception>()),
      );
    });

    // ── recordSwipe enqueues when offline with a stale token ───────────

    test('recordSwipe enqueues on AuthenticationException(MISSING_AUTH_HEADER)', () async {
      // Offline + expired cached token: ApiClient cannot mint an auth header so
      // it throws before any socket is opened. The swipe must still be queued.
      when(
        () => mockApiClient.post(
          '/swipes',
          body: any(named: 'body'),
          idempotent: any(named: 'idempotent'),
        ),
      ).thenThrow(
        AuthenticationException(
          'Authentication required but no auth header available',
          code: 'MISSING_AUTH_HEADER',
        ),
      );

      when(
        () => mockOfflineQueue.enqueueSwipe(
          propertyId: any(named: 'propertyId'),
          isLiked: any(named: 'isLiked'),
        ),
      ).thenAnswer((_) async {});

      // Must not throw — the swipe is queued rather than lost.
      await repository.recordSwipe(propertyId: 100, isLiked: true);

      verify(() => mockOfflineQueue.enqueueSwipe(propertyId: 100, isLiked: true)).called(1);
    });

    test('recordSwipe rethrows AuthenticationException with a non-offline code', () async {
      when(
        () => mockApiClient.post(
          '/swipes',
          body: any(named: 'body'),
          idempotent: any(named: 'idempotent'),
        ),
      ).thenThrow(AuthenticationException('Unauthorized', code: 'UNAUTHORIZED'));

      await expectLater(
        () => repository.recordSwipe(propertyId: 100, isLiked: true),
        throwsA(isA<AuthenticationException>()),
      );

      verifyNever(
        () => mockOfflineQueue.enqueueSwipe(
          propertyId: any(named: 'propertyId'),
          isLiked: any(named: 'isLiked'),
        ),
      );
    });

    // ── recordSwipe rethrows non-network AppExceptions ─────────────────

    test('recordSwipe rethrows non-network AppExceptions directly', () async {
      when(
        () => mockApiClient.post(
          '/swipes',
          body: any(named: 'body'),
          idempotent: any(named: 'idempotent'),
        ),
      ).thenThrow(AuthenticationException('Unauthorized'));

      expect(
        () => repository.recordSwipe(propertyId: 100, isLiked: true),
        throwsA(isA<AuthenticationException>()),
      );

      // Offline queue should NOT be called for non-network errors
      verifyNever(
        () => mockOfflineQueue.enqueueSwipe(
          propertyId: any(named: 'propertyId'),
          isLiked: any(named: 'isLiked'),
        ),
      );
    });

    // ── getSwipeHistoryProperties ──────────────────────────────────────

    test('getSwipeHistoryProperties parses items and pagination signals', () async {
      when(
        () => mockApiClient.get(
          '/swipes',
          queryParams: any(named: 'queryParams'),
          useCache: any(named: 'useCache'),
        ),
      ).thenAnswer(
        (_) async => ApiResponse(
          statusCode: 200,
          body: {
            'items': testPropertyJsonList(count: 3),
            'has_more': true,
            'next_cursor': 'cursor-abc',
            'limit': 50,
          },
          headers: {},
        ),
      );

      final response = await repository.getSwipeHistoryProperties(
        filters: const UnifiedFilterModel(),
        limit: 50,
      );

      expect(response.items.length, 3);
      expect(response.hasMore, isTrue);
      expect(response.nextCursor, 'cursor-abc');
      expect(response.items.first.id, 100);
    });

    test('getSwipeHistoryProperties returns terminal page when has_more absent', () async {
      when(
        () => mockApiClient.get(
          '/swipes',
          queryParams: any(named: 'queryParams'),
          useCache: any(named: 'useCache'),
        ),
      ).thenAnswer(
        (_) async => ApiResponse(
          statusCode: 200,
          body: {'items': testPropertyJsonList(count: 1)},
          headers: {},
        ),
      );

      final response = await repository.getSwipeHistoryProperties(
        filters: const UnifiedFilterModel(),
      );

      expect(response.hasMore, isFalse);
      expect(response.nextCursor, isNull);
    });

    test('getSwipeHistoryProperties handles non-Map body as empty result', () async {
      when(
        () => mockApiClient.get(
          '/swipes',
          queryParams: any(named: 'queryParams'),
          useCache: any(named: 'useCache'),
        ),
      ).thenAnswer((_) async => ApiResponse(statusCode: 200, body: 'not-a-map', headers: {}));

      final response = await repository.getSwipeHistoryProperties(
        filters: const UnifiedFilterModel(),
      );

      expect(response.items, isEmpty);
      expect(response.hasMore, isFalse);
    });

    test('getSwipeHistoryProperties skips unparseable items but keeps valid ones', () async {
      when(
        () => mockApiClient.get(
          '/swipes',
          queryParams: any(named: 'queryParams'),
          useCache: any(named: 'useCache'),
        ),
      ).thenAnswer(
        (_) async => ApiResponse(
          statusCode: 200,
          body: {
            'items': [testPropertyJson(id: 1), 'not-a-map', testPropertyJson(id: 3)],
          },
          headers: {},
        ),
      );

      final response = await repository.getSwipeHistoryProperties(
        filters: const UnifiedFilterModel(),
      );

      expect(response.items.length, 2);
      expect(response.items.map((p) => p.id), containsAll([1, 3]));
    });

    test('getSwipeHistoryProperties propagates AppException', () async {
      when(
        () => mockApiClient.get(
          '/swipes',
          queryParams: any(named: 'queryParams'),
          useCache: any(named: 'useCache'),
        ),
      ).thenThrow(NetworkException('Offline'));

      expect(
        () => repository.getSwipeHistoryProperties(filters: const UnifiedFilterModel()),
        throwsA(isA<NetworkException>()),
      );
    });

    test('getSwipeHistoryProperties passes cursor and location into query params', () async {
      when(
        () => mockApiClient.get(
          '/swipes',
          queryParams: any(named: 'queryParams'),
          useCache: any(named: 'useCache'),
        ),
      ).thenAnswer(
        (_) async => ApiResponse(statusCode: 200, body: {'items': <dynamic>[]}, headers: {}),
      );

      await repository.getSwipeHistoryProperties(
        filters: const UnifiedFilterModel(),
        latitude: 28.61,
        longitude: 77.20,
        cursor: 'next-page',
        isLiked: true,
      );

      final captured = verify(
        () => mockApiClient.get(
          '/swipes',
          queryParams: captureAny(named: 'queryParams'),
          useCache: any(named: 'useCache'),
        ),
      ).captured;

      final params = captured.single as Map<String, dynamic>;
      expect(params['cursor'], 'next-page');
      expect(params['lat'], '28.61');
      expect(params['lng'], '77.2');
      expect(params['is_liked'], 'true');
    });

    // ── getLikedProperties / getPassedProperties / getAllSwipedProperties ──

    test('getLikedProperties returns items from history with isLiked=true', () async {
      when(
        () => mockApiClient.get(
          '/swipes',
          queryParams: any(named: 'queryParams'),
          useCache: any(named: 'useCache'),
        ),
      ).thenAnswer(
        (_) async => ApiResponse(
          statusCode: 200,
          body: {'items': testPropertyJsonList(count: 2), 'has_more': false},
          headers: {},
        ),
      );

      final liked = await repository.getLikedProperties(filters: const UnifiedFilterModel());

      expect(liked.length, 2);
      // Verify is_liked=true was sent.
      final captured = verify(
        () => mockApiClient.get(
          '/swipes',
          queryParams: captureAny(named: 'queryParams'),
          useCache: any(named: 'useCache'),
        ),
      ).captured;
      expect((captured.single as Map<String, dynamic>)['is_liked'], 'true');
    });

    test('getPassedProperties returns items from history with isLiked=false', () async {
      when(
        () => mockApiClient.get(
          '/swipes',
          queryParams: any(named: 'queryParams'),
          useCache: any(named: 'useCache'),
        ),
      ).thenAnswer(
        (_) async => ApiResponse(
          statusCode: 200,
          body: {'items': testPropertyJsonList(count: 1)},
          headers: {},
        ),
      );

      final passed = await repository.getPassedProperties(filters: const UnifiedFilterModel());

      expect(passed.length, 1);
      final captured = verify(
        () => mockApiClient.get(
          '/swipes',
          queryParams: captureAny(named: 'queryParams'),
          useCache: any(named: 'useCache'),
        ),
      ).captured;
      expect((captured.single as Map<String, dynamic>)['is_liked'], 'false');
    });

    test('getLikedProperties propagates AppException', () async {
      when(
        () => mockApiClient.get(
          '/swipes',
          queryParams: any(named: 'queryParams'),
          useCache: any(named: 'useCache'),
        ),
      ).thenThrow(ServerException('Down', statusCode: 500));

      expect(
        () => repository.getLikedProperties(filters: const UnifiedFilterModel()),
        throwsA(isA<ServerException>()),
      );
    });

    test('getLikedPropertiesWithSwipeIds delegates to history with isLiked=true', () async {
      when(
        () => mockApiClient.get(
          '/swipes',
          queryParams: any(named: 'queryParams'),
          useCache: any(named: 'useCache'),
        ),
      ).thenAnswer(
        (_) async => ApiResponse(
          statusCode: 200,
          body: {'items': testPropertyJsonList(count: 4)},
          headers: {},
        ),
      );

      final result = await repository.getLikedPropertiesWithSwipeIds(
        filters: const UnifiedFilterModel(),
      );

      expect(result.length, 4);
    });

    test('getAllSwipedProperties omits is_liked to fetch both liked and passed', () async {
      when(
        () => mockApiClient.get(
          '/swipes',
          queryParams: any(named: 'queryParams'),
          useCache: any(named: 'useCache'),
        ),
      ).thenAnswer(
        (_) async => ApiResponse(
          statusCode: 200,
          body: {'items': testPropertyJsonList(count: 2), 'has_more': true},
          headers: {},
        ),
      );

      final response = await repository.getAllSwipedProperties(filters: const UnifiedFilterModel());

      expect(response.items.length, 2);
      expect(response.hasMore, isTrue);
      final captured = verify(
        () => mockApiClient.get(
          '/swipes',
          queryParams: captureAny(named: 'queryParams'),
          useCache: any(named: 'useCache'),
        ),
      ).captured;
      expect((captured.single as Map<String, dynamic>).containsKey('is_liked'), isFalse);
    });
  });
}
