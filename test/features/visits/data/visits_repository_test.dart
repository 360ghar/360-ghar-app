import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/controllers/offline_queue_service.dart';
import 'package:ghar360/core/data/models/visit_model.dart';
import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/visits/data/datasources/visits_remote_datasource.dart';
import 'package:ghar360/features/visits/data/visits_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/visits_test_support.dart';

class MockRemoteVisits extends Mock implements VisitsRemoteDatasource {}

void main() {
  late AppDatabase db;
  late StorageScope scope;
  late OfflineQueueService queue;
  late MockRemoteVisits remote;
  late VisitsRepository repo;
  final date = DateTime.utc(2030, 1, 1).toIso8601String();
  setUp(() async {
    db = await visitTestDatabase();
    scope = db.activateScope(environment: 'test', accountId: 'a');
    queue = OfflineQueueService(database: db, scope: () => scope);
    remote = MockRemoteVisits();
    repo = VisitsRepository(remoteDatasource: remote, offlineQueue: queue);
  });
  tearDown(() async {
    queue.close();
    await db.close();
  });
  void booking(Future<VisitModel> Function() action) {
    when(
      () => remote.scheduleVisit(
        propertyId: 100,
        scheduledDate: date,
        specialRequirements: any(named: 'specialRequirements'),
      ),
    ).thenAnswer((_) => action());
  }

  Future<VisitRequestResult> send() =>
      repo.scheduleVisit(propertyId: 100, scheduledDate: date, specialRequirements: 'notes');
  test(
    'successful booking persists intent before send and returns explicit confirmation',
    () async {
      booking(() async {
        expect((await queue.list()).single.status, PendingActionStatus.needsReconciliation);
        return visitFixture();
      });
      final result = await send();
      expect(result, isA<VisitConfirmed>());
      expect((result as VisitConfirmed).visit.id, 1);
      expect((await queue.list()).single.status, PendingActionStatus.confirmed);
    },
  );
  for (final failure in [
    NetworkException('offline'),
    ServerException('down', statusCode: 500),
    const FormatException('malformed'),
  ]) {
    test('${failure.runtimeType} remains durable and unresolved without replay', () async {
      booking(() async => throw failure);
      final result = await send();
      expect(result, isA<VisitUnresolved>());
      expect((await queue.list()).single.status, PendingActionStatus.needsReconciliation);
      final again = await send();
      expect(again, isA<VisitUnresolved>());
      verify(
        () => remote.scheduleVisit(
          propertyId: 100,
          scheduledDate: date,
          specialRequirements: 'notes',
        ),
      ).called(1);
    });
  }
  for (final failure in [
    AuthenticationException('expired', code: 'UNAUTHORIZED'),
    AuthenticationException('offline', code: AppException.missingAuthHeaderCode),
    ValidationException('bad'),
    ApiException('conflict', statusCode: 409),
  ]) {
    test('${failure.code ?? failure.runtimeType} records failed intent for review', () async {
      booking(() async => throw failure);
      expect(await send(), isA<VisitFailed>());
      expect((await queue.list()).single.status, PendingActionStatus.failed);
    });
  }
  test('persistence failure returns explicit failure and never sends POST', () async {
    await db.close();
    final result = await send();
    expect(result, isA<VisitFailed>());
    verifyNever(
      () => remote.scheduleVisit(
        propertyId: any(named: 'propertyId'),
        scheduledDate: any(named: 'scheduledDate'),
        specialRequirements: any(named: 'specialRequirements'),
      ),
    );
  });
  test('account switch before persistence cannot create action for another user', () async {
    scope = db.activateScope(environment: 'test');
    expect(await send(), isA<VisitFailed>());
    expect(await queue.list(), isEmpty);
  });
  test('account switch during POST cannot write new-account action status', () async {
    final pending = Completer<VisitModel>();
    booking(() => pending.future);
    final result = send();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    scope = db.activateScope(environment: 'test', accountId: 'b');
    pending.complete(visitFixture());
    await result;
    expect(await queue.list(), isEmpty);
    scope = db.activateScope(environment: 'test', accountId: 'a');
    expect((await queue.list()).single.status, PendingActionStatus.needsReconciliation);
  });
  test('reconciliation only GETs pages and confirms matching property and UTC instant', () async {
    booking(() async => throw NetworkException('offline'));
    final result = await send() as VisitUnresolved;
    when(
      () => remote.fetchVisitsSummary(cursor: null, limit: 50),
    ).thenAnswer((_) async => const VisitsPayload(visits: [], hasMore: true, nextCursor: 'page2'));
    when(() => remote.fetchVisitsSummary(cursor: 'page2', limit: 50)).thenAnswer(
      (_) async =>
          VisitsPayload(visits: [visitFixture(date: DateTime.parse(date))], hasMore: false),
    );
    expect((await repo.reconcile(result.action))!.id, 1);
    expect((await queue.list()).single.status, PendingActionStatus.confirmed);
    verify(
      () =>
          remote.scheduleVisit(propertyId: 100, scheduledDate: date, specialRequirements: 'notes'),
    ).called(1);
  });
  test('no reconciliation match retains request and stops repeated cursors', () async {
    booking(() async => throw NetworkException('offline'));
    final result = await send() as VisitUnresolved;
    when(
      () => remote.fetchVisitsSummary(cursor: any(named: 'cursor'), limit: 50),
    ).thenAnswer((_) async => const VisitsPayload(visits: [], hasMore: true, nextCursor: 'repeat'));
    expect(await repo.reconcile(result.action), isNull);
    expect((await queue.list()).single.status, PendingActionStatus.needsReconciliation);
    verify(() => remote.fetchVisitsSummary(cursor: 'repeat', limit: 50)).called(1);
  });
  test('reconciliation failure propagates and preserves pending record', () async {
    booking(() async => throw NetworkException('offline'));
    final result = await send() as VisitUnresolved;
    when(
      () => remote.fetchVisitsSummary(cursor: null, limit: 50),
    ).thenThrow(NetworkException('offline'));
    await expectLater(repo.reconcile(result.action), throwsA(isA<NetworkException>()));
    expect((await queue.list()).length, 1);
  });
  test('delegates visit listing cursor and limit and preserves typed failures', () async {
    final payload = VisitsPayload(visits: [visitFixture()], hasMore: true, nextCursor: 'next');
    when(
      () => remote.fetchVisitsSummary(cursor: 'cursor', limit: 12),
    ).thenAnswer((_) async => payload);
    expect(await repo.fetchVisitsSummary(cursor: 'cursor', limit: 12), same(payload));
    when(
      () => remote.fetchVisitsSummary(cursor: null, limit: 50),
    ).thenThrow(NetworkException('offline'));
    await expectLater(() => repo.fetchVisitsSummary(), throwsA(isA<NetworkException>()));
  });
  test('delegates relationship manager and propagates failure', () async {
    final agent = agentFixture();
    when(() => remote.fetchRelationshipManager()).thenAnswer((_) async => agent);
    expect(await repo.fetchRelationshipManager(), same(agent));
    when(() => remote.fetchRelationshipManager()).thenThrow(ServerException('down'));
    await expectLater(() => repo.fetchRelationshipManager(), throwsA(isA<ServerException>()));
  });
  test('cancel passes the reason, returns the updated visit and propagates failures', () async {
    final cancelled = visitFixture(status: VisitStatus.cancelled);
    when(() => remote.cancelVisit(1, reason: 'reason')).thenAnswer((_) async => cancelled);
    expect(await repo.cancelVisit(1, reason: 'reason'), same(cancelled));
    when(() => remote.cancelVisit(1, reason: 'reason')).thenThrow(NetworkException('offline'));
    await expectLater(
      () => repo.cancelVisit(1, reason: 'reason'),
      throwsA(isA<NetworkException>()),
    );
    when(() => remote.cancelVisit(1, reason: 'reason')).thenThrow(
      ApiException(
        'The request could not be completed.',
        code: 'VISIT_NOT_CANCELLABLE',
        statusCode: 400,
      ),
    );
    await expectLater(
      () => repo.cancelVisit(1, reason: 'reason'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'VISIT_NOT_CANCELLABLE')),
    );
  });
  test(
    'reschedule passes new date and optional reason, returns the visit, propagates failure',
    () async {
      final moved = visitFixture(status: VisitStatus.rescheduled);
      when(
        () => remote.rescheduleVisit(1, newDate: date, reason: null),
      ).thenAnswer((_) async => moved);
      expect(await repo.rescheduleVisit(1, newDate: date), same(moved));
      when(
        () => remote.rescheduleVisit(1, newDate: date, reason: 'reason'),
      ).thenThrow(NetworkException('offline'));
      await expectLater(
        () => repo.rescheduleVisit(1, newDate: date, reason: 'reason'),
        throwsA(isA<NetworkException>()),
      );
    },
  );
  test('concurrent booking calls share one persisted operation and one POST', () async {
    final pending = Completer<VisitModel>();
    booking(() => pending.future);
    final first = send();
    final second = send();
    expect(identical(first, second), true);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect((await queue.list()).length, 1);
    pending.complete(visitFixture());
    await Future.wait([first, second]);
    verify(
      () =>
          remote.scheduleVisit(propertyId: 100, scheduledDate: date, specialRequirements: 'notes'),
    ).called(1);
  });
}
