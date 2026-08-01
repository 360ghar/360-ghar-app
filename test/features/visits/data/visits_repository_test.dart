import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/controllers/offline_queue_service.dart';
import 'package:ghar360/core/data/models/visit_model.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/visits/data/datasources/visits_remote_datasource.dart';
import 'package:ghar360/features/visits/data/visits_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mocks.dart';

class _MockVisitsRemote extends Mock implements VisitsRemoteDatasource {}

class _MockOfflineQueue extends Mock implements OfflineQueueService {}

void main() {
  late _MockVisitsRemote remote;
  late _MockOfflineQueue queue;
  late VisitsRepository repository;

  setUp(() {
    remote = _MockVisitsRemote();
    queue = _MockOfflineQueue();
    repository = VisitsRepository(remoteDatasource: remote, offlineQueue: queue);
  });

  VisitModel visit() => VisitModel(
    id: 1,
    propertyId: 10,
    userId: 1,
    scheduledDate: DateTime.utc(2024, 6, 1),
    status: VisitStatus.scheduled,
    createdAt: DateTime.utc(2024, 1, 1),
  );

  group('VisitsRepository.scheduleVisit', () {
    test('returns remote visit on success', () async {
      when(
        () => remote.scheduleVisit(
          propertyId: 10,
          scheduledDate: '2024-06-01T00:00:00.000Z',
          specialRequirements: null,
        ),
      ).thenAnswer((_) async => visit());

      final result = await repository.scheduleVisit(
        propertyId: 10,
        scheduledDate: '2024-06-01T00:00:00.000Z',
      );

      expect(result.id, 1);
      verifyNever(
        () => queue.enqueueVisit(
          propertyId: any(named: 'propertyId'),
          scheduledDate: any(named: 'scheduledDate'),
          specialRequirements: any(named: 'specialRequirements'),
        ),
      );
    });

    test('enqueues and rethrows on NetworkException', () async {
      when(
        () => remote.scheduleVisit(
          propertyId: 10,
          scheduledDate: '2024-06-01T00:00:00.000Z',
          specialRequirements: 'notes',
        ),
      ).thenThrow(NetworkException('down', code: 'CONNECTION_ERROR'));
      when(
        () => queue.enqueueVisit(
          propertyId: 10,
          scheduledDate: '2024-06-01T00:00:00.000Z',
          specialRequirements: 'notes',
        ),
      ).thenAnswer((_) async {});

      await expectLater(
        () => repository.scheduleVisit(
          propertyId: 10,
          scheduledDate: '2024-06-01T00:00:00.000Z',
          specialRequirements: 'notes',
        ),
        throwsA(isA<NetworkException>()),
      );

      verify(
        () => queue.enqueueVisit(
          propertyId: 10,
          scheduledDate: '2024-06-01T00:00:00.000Z',
          specialRequirements: 'notes',
        ),
      ).called(1);
    });

    test('enqueues and rethrows on AuthenticationException(MISSING_AUTH_HEADER)', () async {
      // Offline + expired cached token: ApiClient throws before any socket is
      // opened, so the booking must still reach the offline queue.
      when(
        () => remote.scheduleVisit(
          propertyId: 10,
          scheduledDate: '2024-06-01T00:00:00.000Z',
          specialRequirements: 'notes',
        ),
      ).thenThrow(
        AuthenticationException(
          'Authentication required but no auth header available',
          code: 'MISSING_AUTH_HEADER',
        ),
      );
      when(
        () => queue.enqueueVisit(
          propertyId: 10,
          scheduledDate: '2024-06-01T00:00:00.000Z',
          specialRequirements: 'notes',
        ),
      ).thenAnswer((_) async {});

      await expectLater(
        () => repository.scheduleVisit(
          propertyId: 10,
          scheduledDate: '2024-06-01T00:00:00.000Z',
          specialRequirements: 'notes',
        ),
        throwsA(isA<AuthenticationException>()),
      );

      verify(
        () => queue.enqueueVisit(
          propertyId: 10,
          scheduledDate: '2024-06-01T00:00:00.000Z',
          specialRequirements: 'notes',
        ),
      ).called(1);
    });

    test('rethrows AuthenticationException with a non-offline code without enqueueing', () async {
      when(
        () => remote.scheduleVisit(
          propertyId: 10,
          scheduledDate: '2024-06-01T00:00:00.000Z',
          specialRequirements: null,
        ),
      ).thenThrow(AuthenticationException('Unauthorized', code: 'UNAUTHORIZED'));

      await expectLater(
        () => repository.scheduleVisit(propertyId: 10, scheduledDate: '2024-06-01T00:00:00.000Z'),
        throwsA(isA<AuthenticationException>()),
      );

      verifyNever(
        () => queue.enqueueVisit(
          propertyId: any(named: 'propertyId'),
          scheduledDate: any(named: 'scheduledDate'),
          specialRequirements: any(named: 'specialRequirements'),
        ),
      );
    });
  });

  group('VisitsRepository.fetchVisitsSummary', () {
    test('delegates to remote datasource and returns payload', () async {
      final payload = VisitsPayload(visits: [visit()], hasMore: true, nextCursor: 'next');
      when(
        () => remote.fetchVisitsSummary(cursor: null, limit: 50),
      ).thenAnswer((_) async => payload);

      final result = await repository.fetchVisitsSummary();

      expect(result.visits.length, 1);
      expect(result.hasMore, isTrue);
      expect(result.nextCursor, 'next');
      verify(() => remote.fetchVisitsSummary(cursor: null, limit: 50)).called(1);
    });

    test('forwards cursor and limit to remote', () async {
      final payload = const VisitsPayload(visits: [], hasMore: false);
      when(
        () => remote.fetchVisitsSummary(cursor: 'abc', limit: 10),
      ).thenAnswer((_) async => payload);

      final result = await repository.fetchVisitsSummary(cursor: 'abc', limit: 10);

      expect(result.visits, isEmpty);
      verify(() => remote.fetchVisitsSummary(cursor: 'abc', limit: 10)).called(1);
    });

    test('propagates exceptions from remote', () async {
      when(
        () => remote.fetchVisitsSummary(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).thenThrow(NetworkException('down'));

      expect(() => repository.fetchVisitsSummary(), throwsA(isA<NetworkException>()));
    });
  });

  group('VisitsRepository.fetchRelationshipManager', () {
    test('delegates to remote datasource and returns agent', () async {
      final agent = testAgentModel(id: 7);
      when(() => remote.fetchRelationshipManager()).thenAnswer((_) async => agent);

      final result = await repository.fetchRelationshipManager();

      expect(result.id, 7);
      expect(result.name, 'Test Agent');
      verify(() => remote.fetchRelationshipManager()).called(1);
    });

    test('propagates exceptions from remote', () async {
      when(
        () => remote.fetchRelationshipManager(),
      ).thenThrow(ServerException('Down', statusCode: 500));

      expect(() => repository.fetchRelationshipManager(), throwsA(isA<ServerException>()));
    });
  });

  group('VisitsRepository.cancelVisit', () {
    test('delegates to remote and returns its result', () async {
      when(() => remote.cancelVisit(5, reason: 'not interested')).thenAnswer((_) async => true);

      final result = await repository.cancelVisit(5, reason: 'not interested');

      expect(result, isTrue);
      verify(() => remote.cancelVisit(5, reason: 'not interested')).called(1);
    });

    test('returns false when remote returns false', () async {
      when(() => remote.cancelVisit(5, reason: 'any')).thenAnswer((_) async => false);

      expect(await repository.cancelVisit(5, reason: 'any'), isFalse);
    });

    test('propagates exceptions from remote', () async {
      when(() => remote.cancelVisit(5, reason: 'any')).thenThrow(NetworkException('down'));

      expect(() => repository.cancelVisit(5, reason: 'any'), throwsA(isA<NetworkException>()));
    });
  });

  group('VisitsRepository.rescheduleVisit', () {
    test('delegates to remote with new date and reason', () async {
      when(
        () => remote.rescheduleVisit(8, newDate: '2024-07-01', reason: 'conflict'),
      ).thenAnswer((_) async => true);

      final result = await repository.rescheduleVisit(8, newDate: '2024-07-01', reason: 'conflict');

      expect(result, isTrue);
      verify(() => remote.rescheduleVisit(8, newDate: '2024-07-01', reason: 'conflict')).called(1);
    });

    test('forwards null reason to remote', () async {
      when(
        () => remote.rescheduleVisit(8, newDate: '2024-07-01', reason: null),
      ).thenAnswer((_) async => true);

      final result = await repository.rescheduleVisit(8, newDate: '2024-07-01');

      expect(result, isTrue);
      verify(() => remote.rescheduleVisit(8, newDate: '2024-07-01', reason: null)).called(1);
    });

    test('propagates exceptions from remote', () async {
      when(
        () => remote.rescheduleVisit(
          8,
          newDate: '2024-07-01',
          reason: any(named: 'reason'),
        ),
      ).thenThrow(ServerException('Down', statusCode: 500));

      expect(
        () => repository.rescheduleVisit(8, newDate: '2024-07-01'),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('VisitsRepository.scheduleVisit (no offline queue)', () {
    test('rethrows NetworkException without enqueueing when no queue available', () async {
      final repo = VisitsRepository(remoteDatasource: remote, offlineQueue: null);
      when(
        () => remote.scheduleVisit(
          propertyId: 10,
          scheduledDate: '2024-06-01T00:00:00.000Z',
          specialRequirements: null,
        ),
      ).thenThrow(NetworkException('down', code: 'CONNECTION_ERROR'));

      await expectLater(
        () => repo.scheduleVisit(propertyId: 10, scheduledDate: '2024-06-01T00:00:00.000Z'),
        throwsA(isA<NetworkException>()),
      );

      verifyNever(
        () => queue.enqueueVisit(
          propertyId: any(named: 'propertyId'),
          scheduledDate: any(named: 'scheduledDate'),
          specialRequirements: any(named: 'specialRequirements'),
        ),
      );
    });

    test('rethrows non-network exceptions without touching the queue', () async {
      when(
        () => remote.scheduleVisit(
          propertyId: 10,
          scheduledDate: '2024-06-01T00:00:00.000Z',
          specialRequirements: null,
        ),
      ).thenThrow(ServerException('Down', statusCode: 500));

      await expectLater(
        () => repository.scheduleVisit(propertyId: 10, scheduledDate: '2024-06-01T00:00:00.000Z'),
        throwsA(isA<ServerException>()),
      );

      verifyNever(
        () => queue.enqueueVisit(
          propertyId: any(named: 'propertyId'),
          scheduledDate: any(named: 'scheduledDate'),
          specialRequirements: any(named: 'specialRequirements'),
        ),
      );
    });
  });
}
