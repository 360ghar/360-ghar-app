import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ghar360/core/controllers/offline_queue_service.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/data/ports/swipes_port.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/storage/storage_failure.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/swipes/data/swipes_repository.dart';
import '../../../helpers/property_query_test_support.dart';
import '../../../helpers/test_data.dart';

class SwipeApi extends Mock implements ApiClient {}

/// A `SwipeOut` receipt, as `POST /swipes` answers.
ApiResponse receipt() => const ApiResponse(
  statusCode: 201,
  body: {'id': 5, 'property_id': 100, 'is_liked': true},
  headers: {},
);

void main() {
  late PropertyQueryHarness h;
  late SwipeApi api;
  late OfflineQueueService queue;
  late StorageScope scope;
  late SwipesRepository repository;
  setUp(() async {
    h = await PropertyQueryHarness.create();
    scope = h.container.read(storageScopeProvider);
    api = SwipeApi();
    queue = OfflineQueueService(database: h.database, scope: () => scope);
    repository = SwipesRepository(apiClient: api, offlineQueue: queue);
    when(
      () => api.post(
        '/swipes',
        body: any(named: 'body'),
        idempotent: any(named: 'idempotent'),
      ),
    ).thenAnswer((_) async => receipt());
  });
  tearDown(() async {
    queue.close();
    await h.close();
  });
  void offline() {
    when(
      () => api.post(
        '/swipes',
        body: any(named: 'body'),
        idempotent: any(named: 'idempotent'),
      ),
    ).thenThrow(NetworkException('Offline'));
  }

  for (final liked in [true, false]) {
    test('persist $liked intent before POST and confirm the same operation', () async {
      String? operation;
      when(() => api.post('/swipes', body: any(named: 'body'), idempotent: false)).thenAnswer((
        _,
      ) async {
        final pending = (await queue.list()).single;
        expect(pending.status, PendingActionStatus.pending);
        expect(pending.attempts, 1);
        operation = pending.operationId;
        return receipt();
      });
      final outcome = await repository.recordSwipe(propertyId: 100, isLiked: liked);
      expect(outcome, isA<ConfirmedSwipe>());
      expect((outcome as ConfirmedSwipe).operationId, operation);
      expect((await queue.list()).single.status, PendingActionStatus.confirmed);
      verify(
        () => api.post('/swipes', body: {'property_id': 100, 'is_liked': liked}, idempotent: false),
      ).called(1);
    });
  }
  for (final failure in [
    NetworkException('Offline'),
    AuthenticationException('No header', code: 'MISSING_AUTH_HEADER'),
    ServerException('Server failed', statusCode: 503),
  ]) {
    test('${failure.runtimeType} retains one unresolved durable operation', () async {
      when(
        () => api.post('/swipes', body: any(named: 'body'), idempotent: false),
      ).thenThrow(failure);
      final outcome = await repository.recordSwipe(propertyId: 100, isLiked: true) as PendingSwipe;
      expect((await queue.list()).single.operationId, outcome.action.operationId);
      expect(outcome.action.attempts, 1);
      expect(outcome.action.status, PendingActionStatus.pending);
    });
  }
  test('an unreadable receipt after a 2xx does not undo the stored swipe', () async {
    when(
      () => api.post('/swipes', body: any(named: 'body'), idempotent: false),
    ).thenAnswer((_) async => const ApiResponse(statusCode: 201, body: {'id': 'x'}, headers: {}));
    final outcome = await repository.recordSwipe(propertyId: 100, isLiked: true);
    expect(outcome, isA<ConfirmedSwipe>());
    expect((outcome as ConfirmedSwipe).swipe, isNull);
  });
  test('the receipt of the server is kept on a confirmed swipe', () async {
    final outcome = await repository.recordSwipe(propertyId: 100, isLiked: true);
    expect((outcome as ConfirmedSwipe).swipe?.id, 5);
  });
  test('storage failure prevents POST instead of losing the user intent', () async {
    await h.raw.execute(
      "CREATE TRIGGER no_actions BEFORE INSERT ON actions BEGIN SELECT RAISE(ABORT,'disk full'); END",
    );
    await expectLater(
      repository.recordSwipe(propertyId: 100, isLiked: true),
      throwsA(isA<StorageFailure>()),
    );
    verifyNever(
      () => api.post(
        any(),
        body: any(named: 'body'),
        idempotent: any(named: 'idempotent'),
      ),
    );
  });
  test('invalid property cannot create a durable action or a POST', () async {
    await expectLater(
      repository.recordSwipe(propertyId: 0, isLiked: true),
      throwsA(isA<ValidationException>()),
    );
    expect(await queue.list(), isEmpty);
    verifyNever(
      () => api.post(
        any(),
        body: any(named: 'body'),
        idempotent: any(named: 'idempotent'),
      ),
    );
  });
  test('unresolved response survives a failed failure-metadata write', () async {
    offline();
    await h.raw.execute(
      "CREATE TRIGGER no_failure BEFORE UPDATE ON actions WHEN NEW.failure_code IS NOT NULL BEGIN SELECT RAISE(ABORT,'disk full'); END",
    );
    final result = await repository.recordSwipe(propertyId: 100, isLiked: true) as PendingSwipe;
    expect((await queue.list()).single.operationId, result.action.operationId);
    expect(result.action.status, PendingActionStatus.pending);
  });
  test('definite rejection stays failed and throws a typed failure', () async {
    when(
      () => api.post('/swipes', body: any(named: 'body'), idempotent: false),
    ).thenThrow(AuthenticationException('Unauthorized', code: 'UNAUTHORIZED'));
    await expectLater(
      repository.recordSwipe(propertyId: 100, isLiked: true),
      throwsA(isA<AuthenticationException>()),
    );
    expect((await queue.list()).single.status, PendingActionStatus.failed);
  });
  test('manual retry uses the same operation and increases attempts', () async {
    offline();
    final pending = await repository.recordSwipe(propertyId: 100, isLiked: true) as PendingSwipe;
    when(
      () => api.post('/swipes', body: any(named: 'body'), idempotent: false),
    ).thenAnswer((_) async => receipt());
    expect(await repository.retryPendingSwipe(pending.action), isA<ConfirmedSwipe>());
    final records = await queue.list();
    expect(records.length, 1);
    expect(records.single.operationId, pending.action.operationId);
    expect(records.single.attempts, 2);
    expect(records.single.status, PendingActionStatus.confirmed);
  });
  test('repeated offline retry does not create a replacement operation', () async {
    offline();
    final pending = await repository.recordSwipe(propertyId: 100, isLiked: false) as PendingSwipe;
    final again = await repository.retryPendingSwipe(pending.action) as PendingSwipe;
    expect(again.action.operationId, pending.action.operationId);
    expect((await queue.list()).length, 1);
    expect(again.action.attempts, 2);
  });
  test('duplicate manual retry coalesces one POST', () async {
    offline();
    final pending = await repository.recordSwipe(propertyId: 100, isLiked: true) as PendingSwipe;
    final completion = Completer<ApiResponse>();
    final started = Completer<void>();
    when(() => api.post('/swipes', body: any(named: 'body'), idempotent: false)).thenAnswer((_) {
      started.complete();
      return completion.future;
    });
    final one = repository.retryPendingSwipe(pending.action);
    final two = repository.retryPendingSwipe(pending.action);
    expect(identical(one, two), true);
    await started.future;
    completion.complete(receipt());
    await Future.wait([one, two]);
    verify(() => api.post('/swipes', body: any(named: 'body'), idempotent: false)).called(2);
  });
  test('new confirmed intent makes every older pending operation ineligible', () async {
    offline();
    final old = await repository.recordSwipe(propertyId: 100, isLiked: true) as PendingSwipe;
    when(
      () => api.post('/swipes', body: any(named: 'body'), idempotent: false),
    ).thenAnswer((_) async => receipt());
    await repository.recordSwipe(propertyId: 100, isLiked: false);
    final records = await queue.list();
    expect(records.first.failureCode, 'SUPERSEDED');
    expect(records.last.status, PendingActionStatus.confirmed);
    await expectLater(
      repository.retryPendingSwipe(old.action),
      throwsA(isA<ValidationException>().having((e) => e.code, 'code', 'SWIPE_SUPERSEDED')),
    );
    verify(() => api.post('/swipes', body: any(named: 'body'), idempotent: false)).called(2);
  });
  test('latest-created guard also rejects interrupted supersede work', () async {
    final old = await queue.create(kind: 'swipe', payload: {'property_id': 100, 'is_liked': true});
    await queue.create(kind: 'swipe', payload: {'property_id': 100, 'is_liked': false});
    await expectLater(repository.retryPendingSwipe(old), throwsA(isA<ValidationException>()));
    verifyNever(
      () => api.post(
        any(),
        body: any(named: 'body'),
        idempotent: any(named: 'idempotent'),
      ),
    );
  });
  test('confirmation storage failure remains explicitly unresolved', () async {
    await h.raw.execute(
      "CREATE TRIGGER no_confirmation BEFORE UPDATE ON actions WHEN NEW.status = 'confirmed' BEGIN SELECT RAISE(ABORT,'disk full'); END",
    );
    final result = await repository.recordSwipe(propertyId: 100, isLiked: true);
    expect(result, isA<PendingSwipe>());
    expect((await queue.list()).single.status, PendingActionStatus.pending);
  });
  test('account switch rejects response and never copies a request into another account', () async {
    final completion = Completer<ApiResponse>();
    final started = Completer<void>();
    when(() => api.post('/swipes', body: any(named: 'body'), idempotent: false)).thenAnswer((_) {
      started.complete();
      return completion.future;
    });
    final request = repository.recordSwipe(propertyId: 100, isLiked: true);
    await started.future;
    scope = h.database.activateScope(environment: 'test', accountId: 'b');
    completion.complete(receipt());
    await expectLater(request, throwsA(isA<NetworkException>()));
    expect(await queue.list(), isEmpty);
  });
  test('confirmed operation is a no-op if retried explicitly', () async {
    await repository.recordSwipe(propertyId: 100, isLiked: true);
    final action = (await queue.list()).single;
    expect(await repository.retryPendingSwipe(action), isA<ConfirmedSwipe>());
    verify(() => api.post('/swipes', body: any(named: 'body'), idempotent: false)).called(1);
  });
  test('history parses rows and pagination while passing query location and cursor', () async {
    when(
      () => api.get('/swipes', queryParams: any(named: 'queryParams'), useCache: false),
    ).thenAnswer(
      (_) async => ApiResponse(
        statusCode: 200,
        body: testPropertyPage(count: 3, hasMore: true, nextCursor: 'next'),
        headers: {},
      ),
    );
    final response = await repository.getSwipeHistoryProperties(
      filters: const UnifiedFilterModel(),
      latitude: 28.61,
      longitude: 77.2,
      cursor: 'page2',
      isLiked: true,
    );
    expect(response.items.length, 3);
    expect(response.nextCursor, 'next');
    expect(response.hasMore, true);
    final query =
        verify(
              () => api.get(
                '/swipes',
                queryParams: captureAny(named: 'queryParams'),
                useCache: false,
              ),
            ).captured.single
            as Map;
    expect(query['lat'], '28.61');
    expect(query['lng'], '77.2');
    expect(query['cursor'], 'page2');
    expect(query['is_liked'], 'true');
  });
  for (final body in [
    'invalid',
    {
      ...testPropertyPage(),
      'items': [testPropertyJson(id: 1), 'invalid'],
    },
    testPropertyJsonList(count: 1),
    {'data': testPropertyPage()},
    {'wrong': []},
  ]) {
    test('history malformed $body is a failure rather than empty success', () async {
      when(
        () => api.get('/swipes', queryParams: any(named: 'queryParams'), useCache: false),
      ).thenAnswer((_) async => ApiResponse(statusCode: 200, body: body, headers: {}));
      await expectLater(
        repository.getSwipeHistoryProperties(filters: const UnifiedFilterModel()),
        throwsA(isA<ServerException>()),
      );
    });
  }
  test('history last page is terminal and request errors propagate', () async {
    when(
      () => api.get('/swipes', queryParams: any(named: 'queryParams'), useCache: false),
    ).thenAnswer(
      (_) async => ApiResponse(statusCode: 200, body: testPropertyPage(count: 1), headers: {}),
    );
    expect(
      (await repository.getSwipeHistoryProperties(filters: const UnifiedFilterModel())).hasMore,
      false,
    );
    when(
      () => api.get('/swipes', queryParams: any(named: 'queryParams'), useCache: false),
    ).thenThrow(NetworkException('offline'));
    await expectLater(
      repository.getSwipeHistoryProperties(filters: const UnifiedFilterModel()),
      throwsA(isA<NetworkException>()),
    );
  });
}
