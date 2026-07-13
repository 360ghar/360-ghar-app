import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/controllers/offline_action.dart';
import 'package:ghar360/core/controllers/offline_queue_service.dart';
import 'package:ghar360/core/data/models/visit_model.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/swipes/data/datasources/swipes_remote_datasource.dart';
import 'package:ghar360/features/visits/data/datasources/visits_remote_datasource.dart';
import 'package:mocktail/mocktail.dart';

class _MockSwipesRemote extends Mock implements SwipesRemoteDatasource {}

class _MockVisitsRemote extends Mock implements VisitsRemoteDatasource {}

void main() {
  late InMemoryOfflineQueueStorage storage;
  late _MockSwipesRemote swipes;
  late _MockVisitsRemote visits;
  late StreamController<List<ConnectivityResult>> connectivity;
  late OfflineQueueService queue;

  setUp(() {
    storage = InMemoryOfflineQueueStorage();
    swipes = _MockSwipesRemote();
    visits = _MockVisitsRemote();
    connectivity = StreamController<List<ConnectivityResult>>.broadcast();

    when(
      () => swipes.swipeProperty(
        propertyId: any(named: 'propertyId'),
        isLiked: any(named: 'isLiked'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => visits.scheduleVisit(
        propertyId: any(named: 'propertyId'),
        scheduledDate: any(named: 'scheduledDate'),
        specialRequirements: any(named: 'specialRequirements'),
      ),
    ).thenAnswer((_) async => throw UnimplementedError('not used'));

    queue = OfflineQueueService(
      storage: storage,
      swipesRemoteDatasource: swipes,
      visitsRemoteDatasource: visits,
      connectivityStream: connectivity.stream,
    );
  });

  tearDown(() async {
    await connectivity.close();
  });

  group('OfflineAction parsing', () {
    test('round-trips swipe and visit maps', () {
      final swipe = OfflineSwipeAction(
        propertyId: 42,
        isLiked: true,
        timestamp: DateTime.utc(2024, 1, 2, 3, 4, 5),
        retries: 1,
      );
      final visit = OfflineVisitAction(
        propertyId: 7,
        scheduledDate: '2024-06-01T10:00:00.000Z',
        specialRequirements: 'gate code 12',
        timestamp: DateTime.utc(2024, 1, 2),
        retries: 0,
      );

      expect(OfflineAction.tryParse(swipe.toJson()), isA<OfflineSwipeAction>());
      expect(OfflineAction.tryParse(visit.toJson()), isA<OfflineVisitAction>());
      expect(OfflineAction.tryParse({'type': 'unknown'}), isNull);
      expect(OfflineAction.tryParse({'type': 'swipe'}), isNull);
    });
  });

  group('OfflineQueueService', () {
    test('enqueueSwipe persists typed action', () async {
      await queue.enqueueSwipe(propertyId: 10, isLiked: true);
      expect(queue.queueLength, 1);

      final raw = storage.readList(OfflineQueueService.storageKey)!;
      final action = OfflineAction.tryParse(Map<String, dynamic>.from(raw.first as Map));
      expect(action, isA<OfflineSwipeAction>());
      expect((action as OfflineSwipeAction).propertyId, 10);
      expect(action.isLiked, isTrue);
    });

    test('processQueue replays swipe and clears storage', () async {
      await queue.enqueueSwipe(propertyId: 3, isLiked: false);
      await queue.processQueue();

      verify(() => swipes.swipeProperty(propertyId: 3, isLiked: false)).called(1);
      expect(queue.queueLength, 0);
    });

    test('network failure increments retries and keeps action', () async {
      when(
        () => swipes.swipeProperty(
          propertyId: any(named: 'propertyId'),
          isLiked: any(named: 'isLiked'),
        ),
      ).thenThrow(NetworkException('offline', code: 'CONNECTION_ERROR'));

      await queue.enqueueSwipe(propertyId: 9, isLiked: true);
      await queue.processQueue();

      expect(queue.queueLength, 1);
      final raw = storage.readList(OfflineQueueService.storageKey)!;
      final action = OfflineAction.tryParse(Map<String, dynamic>.from(raw.first as Map))!;
      expect(action.retries, 1);
    });

    test('stale actions are purged before processing', () async {
      final stale = OfflineSwipeAction(
        propertyId: 1,
        isLiked: true,
        timestamp: DateTime.now().subtract(const Duration(hours: 48)),
      );
      storage.writeList(OfflineQueueService.storageKey, [stale.toJson()]);

      await queue.processQueue();

      verifyNever(
        () => swipes.swipeProperty(
          propertyId: any(named: 'propertyId'),
          isLiked: any(named: 'isLiked'),
        ),
      );
      expect(queue.queueLength, 0);
    });

    test('actions exceeding max retries are dropped', () async {
      final exhausted = OfflineSwipeAction(
        propertyId: 2,
        isLiked: false,
        timestamp: DateTime.now(),
        retries: maxOfflineRetries,
      );
      storage.writeList(OfflineQueueService.storageKey, [exhausted.toJson()]);

      await queue.processQueue();

      verifyNever(
        () => swipes.swipeProperty(
          propertyId: any(named: 'propertyId'),
          isLiked: any(named: 'isLiked'),
        ),
      );
      expect(queue.queueLength, 0);
    });

    test('clearQueue removes all actions', () async {
      await queue.enqueueSwipe(propertyId: 1, isLiked: true);
      await queue.enqueueVisit(propertyId: 2, scheduledDate: '2024-01-01T00:00:00.000Z');
      expect(queue.queueLength, 2);

      queue.clearQueue();
      expect(queue.queueLength, 0);
    });

    test('queue size cap drops oldest', () async {
      for (var i = 0; i < maxOfflineQueueSize + 3; i++) {
        await queue.enqueueSwipe(propertyId: i, isLiked: i.isEven);
      }
      expect(queue.queueLength, maxOfflineQueueSize);

      final raw = storage.readList(OfflineQueueService.storageKey)!;
      final first =
          OfflineAction.tryParse(Map<String, dynamic>.from(raw.first as Map)) as OfflineSwipeAction;
      expect(first.propertyId, 3);
    });
  });

  group('OfflineQueueService — visit actions', () {
    test('enqueueVisit persists typed action', () async {
      await queue.enqueueVisit(
        propertyId: 5,
        scheduledDate: '2025-06-01T10:00:00.000Z',
        specialRequirements: 'Need elevator',
      );
      expect(queue.queueLength, 1);

      final raw = storage.readList(OfflineQueueService.storageKey)!;
      final action = OfflineAction.tryParse(Map<String, dynamic>.from(raw.first as Map));
      expect(action, isA<OfflineVisitAction>());
      expect((action as OfflineVisitAction).propertyId, 5);
      expect(action.scheduledDate, '2025-06-01T10:00:00.000Z');
      expect(action.specialRequirements, 'Need elevator');
    });

    test('processQueue replays visit and clears storage', () async {
      when(
        () => visits.scheduleVisit(
          propertyId: any(named: 'propertyId'),
          scheduledDate: any(named: 'scheduledDate'),
          specialRequirements: any(named: 'specialRequirements'),
        ),
      ).thenAnswer(
        (_) async => VisitModel(
          id: 1,
          propertyId: 8,
          userId: 1,
          status: VisitStatus.scheduled,
          scheduledDate: DateTime.parse('2025-07-01T09:00:00.000Z'),
          createdAt: DateTime.parse('2025-07-01T09:00:00.000Z'),
        ),
      );

      await queue.enqueueVisit(propertyId: 8, scheduledDate: '2025-07-01T09:00:00.000Z');
      await queue.processQueue();

      verify(
        () => visits.scheduleVisit(
          propertyId: 8,
          scheduledDate: '2025-07-01T09:00:00.000Z',
          specialRequirements: null,
        ),
      ).called(1);
      expect(queue.queueLength, 0);
    });
  });

  group('OfflineQueueService — error handling', () {
    test('non-network AppException drops action without retry', () async {
      when(
        () => swipes.swipeProperty(
          propertyId: any(named: 'propertyId'),
          isLiked: any(named: 'isLiked'),
        ),
      ).thenThrow(ServerException('server error'));

      await queue.enqueueSwipe(propertyId: 15, isLiked: true);
      await queue.processQueue();

      expect(queue.queueLength, 0);
    });

    test('unexpected error increments retries, keeps action, and stops flush', () async {
      when(
        () => swipes.swipeProperty(
          propertyId: any(named: 'propertyId'),
          isLiked: any(named: 'isLiked'),
        ),
      ).thenThrow(StateError('unexpected'));

      await queue.enqueueSwipe(propertyId: 20, isLiked: false);
      await queue.enqueueSwipe(propertyId: 21, isLiked: true);
      await queue.processQueue();

      // Fail-fast: both the failed item and the unprocessed tail remain.
      expect(queue.queueLength, 2);
      final raw = storage.readList(OfflineQueueService.storageKey)!;
      final first = OfflineAction.tryParse(Map<String, dynamic>.from(raw.first as Map))!;
      expect(first.retries, 1);
      expect((first as OfflineSwipeAction).propertyId, 20);
      // Second item never attempted (still retries 0).
      final second = OfflineAction.tryParse(Map<String, dynamic>.from(raw[1] as Map))!;
      expect(second.retries, 0);
      verify(
        () => swipes.swipeProperty(
          propertyId: any(named: 'propertyId'),
          isLiked: any(named: 'isLiked'),
        ),
      ).called(1);
    });

    test('missing timestamp is dropped as unparseable', () {
      expect(OfflineAction.tryParse({'type': 'swipe', 'propertyId': 1, 'isLiked': true}), isNull);
      expect(
        OfflineAction.tryParse({
          'type': 'swipe',
          'propertyId': 1,
          'isLiked': true,
          'ts': 'not-a-date',
        }),
        isNull,
      );
    });

    test('clearQueue during processQueue does not restore actions', () async {
      final completer = Completer<void>();
      when(
        () => swipes.swipeProperty(
          propertyId: any(named: 'propertyId'),
          isLiked: any(named: 'isLiked'),
        ),
      ).thenAnswer((_) async {
        await completer.future;
      });

      await queue.enqueueSwipe(propertyId: 30, isLiked: true);
      final processing = queue.processQueue();
      // Let processQueue acquire the mutex and start the network call.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      queue.clearQueue();
      completer.complete();
      await processing;
      // Allow clearQueue's deferred exclusive re-clear to finish.
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(queue.queueLength, 0);
    });

    test('clearQueue during enqueue does not restore cleared queue', () async {
      // Fill queue work so enqueue holds the mutex long enough to interleave.
      for (var i = 0; i < 5; i++) {
        await queue.enqueueSwipe(propertyId: i, isLiked: true);
      }

      // Start an enqueue that will wait if process is busy; clear mid-flight
      // via generation should prevent a stale write.
      final enqueuing = queue.enqueueSwipe(propertyId: 99, isLiked: false);
      queue.clearQueue();
      await enqueuing;
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(queue.queueLength, 0);
    });
  });

  group('OfflineQueueService — init and connectivity', () {
    test('init processes existing queue', () async {
      await queue.enqueueSwipe(propertyId: 99, isLiked: true);
      expect(queue.queueLength, 1);

      await queue.init();

      verify(() => swipes.swipeProperty(propertyId: 99, isLiked: true)).called(1);
      expect(queue.queueLength, 0);
    });

    test('connectivity restored triggers processQueue', () async {
      await queue.init();
      await queue.enqueueSwipe(propertyId: 50, isLiked: true);

      connectivity.add([ConnectivityResult.wifi]);
      // Allow async stream listener to run
      await Future.delayed(const Duration(milliseconds: 100));

      verify(() => swipes.swipeProperty(propertyId: 50, isLiked: true)).called(1);
    });

    test('connectivity none does not trigger processQueue', () async {
      await queue.init();
      await queue.enqueueSwipe(propertyId: 60, isLiked: false);

      connectivity.add([ConnectivityResult.none]);
      await Future.delayed(const Duration(milliseconds: 100));

      verifyNever(
        () => swipes.swipeProperty(
          propertyId: any(named: 'propertyId'),
          isLiked: any(named: 'isLiked'),
        ),
      );
    });

    test('onClose cancels connectivity subscription', () async {
      await queue.init();
      queue.onClose();

      // After onClose, adding to stream should not trigger processing
      await queue.enqueueSwipe(propertyId: 70, isLiked: true);
      connectivity.add([ConnectivityResult.wifi]);
      await Future.delayed(const Duration(milliseconds: 100));

      verifyNever(() => swipes.swipeProperty(propertyId: 70, isLiked: true));
    });
  });

  group('OfflineQueueService — re-entrancy guard', () {
    test('concurrent processQueue calls do not double-process', () async {
      await queue.enqueueSwipe(propertyId: 1, isLiked: true);
      await queue.enqueueSwipe(propertyId: 2, isLiked: false);

      await Future.wait([queue.processQueue(), queue.processQueue()]);

      // Each swipe should be called exactly once
      verify(() => swipes.swipeProperty(propertyId: 1, isLiked: true)).called(1);
      verify(() => swipes.swipeProperty(propertyId: 2, isLiked: false)).called(1);
    });
  });

  group('InMemoryOfflineQueueStorage', () {
    test('remove deletes stored data', () {
      final s = InMemoryOfflineQueueStorage();
      s.writeList('key', [1, 2, 3]);
      expect(s.readList('key'), [1, 2, 3]);

      s.remove('key');
      expect(s.readList('key'), isNull);
    });

    test('readList returns copy not reference', () {
      final s = InMemoryOfflineQueueStorage();
      s.writeList('key', [1, 2]);
      final first = s.readList('key')!;
      first.add(3);

      // Modifying the returned list should not affect stored data
      expect(s.readList('key'), [1, 2]);
    });

    test('writeList stores a copy not reference', () {
      final s = InMemoryOfflineQueueStorage();
      final original = [1, 2];
      s.writeList('key', original);
      original.add(3);

      expect(s.readList('key'), [1, 2]);
    });
  });
}
