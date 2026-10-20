import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ghar360/core/data/models/visit_model.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/visits/data/visits_repository.dart';
import 'package:ghar360/features/visits/presentation/controllers/visits_controller.dart';
import '../../../../helpers/visits_test_support.dart';

void main() {
  late AppDatabase db;
  late MockVisitRepository repo;
  late ProviderContainer container;
  late TestVisitScope scope;
  VisitsController getController() => container.read(visitsProvider.notifier);
  VisitsState state() => container.read(visitsProvider);
  Future<void> settle() async {
    await container.pump();
    for (var i = 0; i < 20 && (state().isLoading || state().isRefreshing); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  setUp(() async {
    db = await visitTestDatabase();
    repo = MockVisitRepository();
    scope = TestVisitScope(db);
    when(
      () => repo.fetchVisitsSummary(
        cursor: any(named: 'cursor'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => const VisitsPayload(visits: [], hasMore: false));
    when(() => repo.fetchRelationshipManager()).thenAnswer((_) async => agentFixture());
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        storageScopeProvider.overrideWith(() => scope),
        visitsRepositoryProvider.overrideWithValue(repo),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });
  Future<void> load(List<VisitModel> visits, {String? cursor}) async {
    when(
      () => repo.fetchVisitsSummary(
        cursor: any(named: 'cursor'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer(
      (_) async => VisitsPayload(visits: visits, hasMore: cursor != null, nextCursor: cursor),
    );
    getController();
    await settle();
  }

  test('signed out does not fetch and owns empty immutable state', () async {
    container.read(storageScopeProvider);
    scope.change(null);
    getController();
    await container.pump();
    expect(state().visits, isEmpty);
    expect(state().phase, VisitLoadPhase.content);
    verifyNever(
      () => repo.fetchVisitsSummary(
        cursor: any(named: 'cursor'),
        limit: any(named: 'limit'),
      ),
    );
    expect(() => state().visits.add(visitFixture()), throwsUnsupportedError);
  });
  test('loads first page once and partitions every status exactly once', () async {
    final now = DateTime.now();
    final values = [
      visitFixture(id: 1, date: now.add(const Duration(days: 2))),
      visitFixture(id: 2, date: now.add(const Duration(days: 1))),
      visitFixture(id: 3, date: now.subtract(const Duration(days: 1))),
      visitFixture(id: 4, status: VisitStatus.cancelled),
      visitFixture(id: 5, status: VisitStatus.completed),
    ];
    await load(values);
    expect(state().upcoming.map((v) => v.id), [2, 1]);
    expect(state().past.map((v) => v.id).toSet(), {3, 4, 5});
    expect({...state().past, ...state().upcoming}.length, values.length);
    verify(() => repo.fetchVisitsSummary(cursor: null, limit: 25)).called(1);
  });
  test('refresh keeps content and cursor until replacement succeeds', () async {
    await load([visitFixture()], cursor: 'page2');
    final pending = Completer<VisitsPayload>();
    when(() => repo.fetchVisitsSummary(cursor: null, limit: 25)).thenAnswer((_) => pending.future);
    final result = getController().refreshVisits();
    expect(state().isRefreshing, true);
    expect(state().visits.single.id, 1);
    expect(state().nextCursor, 'page2');
    pending.complete(VisitsPayload(visits: [visitFixture(id: 2)], hasMore: false));
    await result;
    expect(state().visits.single.id, 2);
    expect(state().hasMore, false);
  });
  test('failed refresh retains appointments, cursor, and recoverable typed failure', () async {
    await load([visitFixture()], cursor: 'page2');
    final failure = NetworkException('private backend text');
    when(() => repo.fetchVisitsSummary(cursor: null, limit: 25)).thenThrow(failure);
    await getController().refreshVisits();
    expect(state().visits.single.id, 1);
    expect(state().nextCursor, 'page2');
    expect(state().failure, same(failure));
    expect(state().phase, VisitLoadPhase.content);
    expect(state().stale, true);
  });
  for (final failure in [NetworkException('offline'), Exception('raw secret')]) {
    test('initial failure ${failure.runtimeType} is typed and retryable', () async {
      when(() => repo.fetchVisitsSummary(cursor: null, limit: 25)).thenThrow(failure);
      getController();
      await settle();
      expect(state().phase, VisitLoadPhase.failed);
      expect(state().failure, isA<AppException>());
      expect(state().failure!.message, isNot(contains('raw secret')));
      when(
        () => repo.fetchVisitsSummary(cursor: null, limit: 25),
      ).thenAnswer((_) async => const VisitsPayload(visits: [], hasMore: false));
      await getController().loadVisits();
      expect(state().failure, isNull);
      expect(state().phase, VisitLoadPhase.content);
    });
  }
  test('concurrent refresh requests are deduplicated', () async {
    await load([visitFixture()]);
    clearInteractions(repo);
    final page = Completer<VisitsPayload>();
    when(() => repo.fetchVisitsSummary(cursor: null, limit: 25)).thenAnswer((_) => page.future);
    final first = getController().loadVisits();
    await getController().loadVisits();
    verify(() => repo.fetchVisitsSummary(cursor: null, limit: 25)).called(1);
    page.complete(const VisitsPayload(visits: [], hasMore: false));
    await first;
  });
  test('pagination deduplicates overlapping IDs and terminates repeated cursor', () async {
    await load([visitFixture()], cursor: 'next');
    when(() => repo.fetchVisitsSummary(cursor: 'next', limit: 25)).thenAnswer(
      (_) async => VisitsPayload(
        visits: [visitFixture(), visitFixture(id: 2), visitFixture(id: 2)],
        hasMore: true,
        nextCursor: 'next',
      ),
    );
    await getController().loadMoreVisits();
    expect(state().visits.map((v) => v.id), [1, 2]);
    expect(state().hasMore, false);
    await getController().loadMoreVisits();
    verify(() => repo.fetchVisitsSummary(cursor: 'next', limit: 25)).called(1);
  });
  test('pagination failure keeps content and retries the same position', () async {
    await load([visitFixture()], cursor: 'next');
    when(
      () => repo.fetchVisitsSummary(cursor: 'next', limit: 25),
    ).thenThrow(NetworkException('offline'));
    await getController().loadMoreVisits();
    expect(state().pagePhase, VisitPagePhase.failed);
    expect(state().failure, isNull);
    expect(state().visits.length, 1);
    expect(state().nextCursor, 'next');
    when(
      () => repo.fetchVisitsSummary(cursor: 'next', limit: 25),
    ).thenAnswer((_) async => VisitsPayload(visits: [visitFixture(id: 2)], hasMore: false));
    await getController().loadMoreVisits();
    expect(state().pageFailure, isNull);
    expect(state().visits.length, 2);
  });
  test('short page permits explicit load more and empty cursor terminates', () async {
    await load([], cursor: 'next');
    expect(state().hasMore, true);
    when(
      () => repo.fetchVisitsSummary(cursor: 'next', limit: 25),
    ).thenAnswer((_) async => const VisitsPayload(visits: [], hasMore: true, nextCursor: ''));
    await getController().loadMoreVisits();
    expect(state().hasMore, false);
  });
  test('late page cannot restore content after refresh', () async {
    await load([visitFixture()], cursor: 'next');
    final pending = Completer<VisitsPayload>();
    when(
      () => repo.fetchVisitsSummary(cursor: 'next', limit: 25),
    ).thenAnswer((_) => pending.future);
    final result = getController().loadMoreVisits();
    when(
      () => repo.fetchVisitsSummary(cursor: null, limit: 25),
    ).thenAnswer((_) async => VisitsPayload(visits: [visitFixture(id: 3)], hasMore: false));
    await getController().refreshVisits();
    pending.complete(VisitsPayload(visits: [visitFixture(id: 2)], hasMore: false));
    await result;
    expect(state().visits.map((v) => v.id), [3]);
  });
  test('agent failure remains independent of empty appointments and can retry', () async {
    when(() => repo.fetchRelationshipManager()).thenThrow(ServerException('down'));
    getController();
    await settle();
    expect(state().phase, VisitLoadPhase.content);
    expect(state().failure, isNull);
    expect(state().agent.hasError, true);
    when(() => repo.fetchRelationshipManager()).thenAnswer((_) async => agentFixture());
    await getController().loadRelationshipManager();
    expect(state().agent.value!.name, 'Test Agent');
    expect(state().agent.hasError, false);
  });
  test('agent refresh failure retains the loaded agent', () async {
    await load([]);
    when(() => repo.fetchRelationshipManager()).thenThrow(NetworkException('offline'));
    await getController().loadRelationshipManager();
    expect(state().agent.value!.name, 'Test Agent');
    expect(state().agent.hasError, true);
  });
  test('cached appointments appear during a pending network refresh', () async {
    final owner = container.read(storageScopeProvider);
    final now = DateTime.now();
    await db.writeCache(
      scope: owner,
      key: 'visits:first',
      value: [visitFixture().toJson()],
      freshUntil: now,
      expiresAt: now.add(const Duration(days: 1)),
    );
    final pending = Completer<VisitsPayload>();
    when(() => repo.fetchVisitsSummary(cursor: null, limit: 25)).thenAnswer((_) => pending.future);
    getController();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(state().visits.single.id, 1);
    expect(state().stale, true);
    expect(state().isRefreshing, true);
    pending.complete(const VisitsPayload(visits: [], hasMore: false));
    await settle();
    expect(state().stale, false);
  });
  test('logout rejects late list, agent, and pagination responses', () async {
    final list = Completer<VisitsPayload>();
    final agent = Completer<Never>();
    when(() => repo.fetchVisitsSummary(cursor: null, limit: 25)).thenAnswer((_) => list.future);
    when(() => repo.fetchRelationshipManager()).thenAnswer((_) => agent.future);
    getController();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    scope.change(null);
    await container.pump();
    list.complete(VisitsPayload(visits: [visitFixture()], hasMore: false));
    agent.completeError(NetworkException('offline'));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(state().visits, isEmpty);
    expect(state().agent.hasError, false);
  });
  test('dispose while loading does not write state or throw', () async {
    final pending = Completer<VisitsPayload>();
    when(() => repo.fetchVisitsSummary(cursor: null, limit: 25)).thenAnswer((_) => pending.future);
    getController();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    container.dispose();
    pending.complete(VisitsPayload(visits: [visitFixture()], hasMore: false));
    await Future<void>.delayed(const Duration(milliseconds: 10));
  });
  test('past dates and invalid property IDs do not submit mutations', () async {
    await load([]);
    expect(await getController().bookVisit(1, DateTime(2020)), isA<VisitFailed>());
    expect(
      await getController().bookVisit(0, DateTime.now().add(const Duration(days: 1))),
      isA<VisitFailed>(),
    );
    verifyNever(
      () => repo.scheduleVisit(
        propertyId: any(named: 'propertyId'),
        scheduledDate: any(named: 'scheduledDate'),
        specialRequirements: any(named: 'specialRequirements'),
      ),
    );
    expect(state().failure, isNull);
  });
  test('booking converts local time to UTC and prevents duplicate submit', () async {
    await load([]);
    final pending = Completer<VisitRequestResult>();
    when(
      () => repo.scheduleVisit(
        propertyId: 100,
        scheduledDate: any(named: 'scheduledDate'),
        specialRequirements: 'notes',
      ),
    ).thenAnswer((_) => pending.future);
    final local = DateTime.now().add(const Duration(days: 1));
    final result = getController().bookVisit(100, local, notes: 'notes');
    expect(state().booking.isLoading, true);
    expect(await getController().bookVisit(100, local), isA<VisitFailed>());
    pending.complete(VisitConfirmed(visitFixture()));
    expect(await result, isA<VisitConfirmed>());
    verify(
      () => repo.scheduleVisit(
        propertyId: 100,
        scheduledDate: local.toUtc().toIso8601String(),
        specialRequirements: 'notes',
      ),
    ).called(1);
  });
  test('booking failure does not replace screen failure or discard visits', () async {
    await load([visitFixture()]);
    when(
      () => repo.scheduleVisit(
        propertyId: 100,
        scheduledDate: any(named: 'scheduledDate'),
        specialRequirements: null,
      ),
    ).thenThrow(NetworkException('offline'));
    expect(
      await getController().bookVisit(100, DateTime.now().add(const Duration(days: 1))),
      isA<VisitFailed>(),
    );
    expect(state().failure, isNull);
    expect(state().visits.length, 1);
    expect(state().booking.value, isA<VisitFailed>());
  });
  for (final cancel in [true, false]) {
    test(
      '${cancel ? 'cancel' : 'reschedule'} validates visit and retains content on failed mutation',
      () async {
        await load([visitFixture()]);
        final rejection = ApiException(
          'The request could not be completed.',
          code: cancel ? 'VISIT_NOT_CANCELLABLE' : 'VISIT_NOT_RESCHEDULABLE',
          statusCode: 400,
        );
        if (cancel) {
          when(() => repo.cancelVisit(1, reason: 'reason')).thenThrow(rejection);
        } else {
          when(
            () => repo.rescheduleVisit(1, newDate: any(named: 'newDate'), reason: null),
          ).thenThrow(rejection);
        }
        final ok = cancel
            ? await getController().cancelVisit(1, reason: 'reason')
            : await getController().rescheduleVisit(1, DateTime.now().add(const Duration(days: 1)));
        expect(ok, false);
        expect(state().visits.length, 1);
        expect(state().failure, isNull);
        expect(state().mutations[1]!.hasError, true);
        expect(await getController().cancelVisit(99, reason: 'reason'), false);
        expect(await getController().cancelVisit(1, reason: '  '), false);
        expect(await getController().rescheduleVisit(1, DateTime(2020)), false);
      },
    );
  }
  test('completed visits cannot be cancelled or rescheduled', () async {
    await load([visitFixture(status: VisitStatus.completed)]);
    expect(await getController().cancelVisit(1, reason: 'reason'), false);
    expect(
      await getController().rescheduleVisit(1, DateTime.now().add(const Duration(days: 1))),
      false,
    );
  });
  test('mutation duplicate guard is per visit', () async {
    await load([visitFixture()]);
    final pending = Completer<VisitModel>();
    when(() => repo.cancelVisit(1, reason: 'reason')).thenAnswer((_) => pending.future);
    final first = getController().cancelVisit(1, reason: 'reason');
    expect(await getController().cancelVisit(1, reason: 'reason'), false);
    pending.complete(visitFixture(status: VisitStatus.cancelled));
    expect(await first, true);
    verify(() => repo.cancelVisit(1, reason: 'reason')).called(1);
  });
}
