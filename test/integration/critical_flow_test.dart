// Real provider session, repositories, and SQLite persistence with injected
// network responses. No native services or live account is required.

import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/controllers/offline_queue_service.dart';
import 'package:ghar360/core/data/models/auth_status.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/data/models/visit_model.dart';
import 'package:ghar360/core/data/ports/swipes_port.dart';
import 'package:ghar360/core/network/api_paths.dart';
import 'package:ghar360/core/network/api_response.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/properties/data/datasources/properties_remote_datasource.dart';
import 'package:ghar360/features/properties/data/properties_repository.dart';
import 'package:ghar360/features/swipes/data/swipes_repository.dart';
import 'package:ghar360/features/visits/data/datasources/visits_remote_datasource.dart';
import 'package:ghar360/features/visits/data/visits_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/auth_test_harness.dart';
import '../helpers/mocks.dart' show MockApiClient;
import '../helpers/test_data.dart';

class _MockVisitsRemote extends Mock implements VisitsRemoteDatasource {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AuthHarness session;
  late MockApiClient api;
  late OfflineQueueService queue;
  late SwipesRepository swipes;
  late _MockVisitsRemote remote;
  late VisitsRepository visits;
  final scheduled = DateTime.utc(2026, 10, 1, 10);

  VisitModel bookedVisit(int propertyId) => VisitModel(
    id: 99,
    propertyId: propertyId,
    userId: 1,
    scheduledDate: scheduled,
    status: VisitStatus.scheduled,
    createdAt: DateTime.utc(2026, 9, 25),
  );

  setUp(() async {
    session = AuthHarness();
    await session.open();
    await session.authenticate();
    queue = session.container.read(offlineQueueServiceProvider);
    api = MockApiClient();
    swipes = SwipesRepository(apiClient: api, offlineQueue: queue);
    remote = _MockVisitsRemote();
    visits = VisitsRepository(remoteDatasource: remote, offlineQueue: queue);
  });
  tearDown(() => session.close());

  test('login, discover, like, and book preserve confirmed server results', () async {
    expect(session.state.status, AuthStatus.authenticated);
    when(() => api.signedIn).thenReturn(true);
    when(
      () => api.get(
        ApiPaths.properties,
        queryParams: any(named: 'queryParams'),
        useCache: any(named: 'useCache'),
        requireAuth: true,
      ),
    ).thenAnswer(
      (_) async =>
          ApiResponse(statusCode: 200, body: testPropertyPage(items: [testPropertyJson(id: 100)])),
    );
    when(() => api.post(ApiPaths.swipes, body: any(named: 'body'), idempotent: false)).thenAnswer(
      (_) async =>
          const ApiResponse(statusCode: 201, body: {'id': 5, 'property_id': 100, 'is_liked': true}),
    );
    when(
      () => remote.scheduleVisit(
        propertyId: 100,
        scheduledDate: scheduled.toIso8601String(),
        specialRequirements: 'morning',
      ),
    ).thenAnswer((_) async => bookedVisit(100));
    final properties = PropertiesRepository(
      remoteDatasource: PropertiesRemoteDatasource(api),
      apiClient: api,
    );

    final deck = await properties.searchProperties(
      filters: const UnifiedFilterModel(),
      cursor: null,
      limit: 20,
      latitude: 28.6,
      longitude: 77.2,
    );
    expect(deck.items.single.id, 100);
    final swipe = await swipes.recordSwipe(propertyId: deck.items.single.id, isLiked: true);
    expect(swipe, isA<ConfirmedSwipe>());
    final booking = await visits.scheduleVisit(
      propertyId: 100,
      scheduledDate: scheduled.toIso8601String(),
      specialRequirements: 'morning',
    );
    expect(booking, isA<VisitConfirmed>());
    expect((booking as VisitConfirmed).visit.status, VisitStatus.scheduled);
    expect(booking.visit.propertyId, 100);
    final receipts = await queue.list();
    expect(receipts.map((action) => action.kind), containsAll(['swipe', 'visit']));
    expect(receipts.every((action) => action.status == PendingActionStatus.confirmed), isTrue);
    verify(
      () => api.post(
        ApiPaths.swipes,
        body: {'property_id': 100, 'is_liked': true},
        idempotent: false,
      ),
    ).called(1);
  });

  test('offline swipe has one durable identity across logout and account return', () async {
    when(
      () => api.post(ApiPaths.swipes, body: any(named: 'body'), idempotent: false),
    ).thenThrow(NetworkException('offline', code: 'CONNECTION_ERROR'));
    final outcome = await swipes.recordSwipe(propertyId: 7, isLiked: true) as PendingSwipe;
    final operationId = outcome.action.operationId;
    expect(operationId, isNotEmpty);
    expect((await queue.list()).single.status, PendingActionStatus.pending);

    await session.controller.signOut();
    await session.settle();
    expect(await queue.list(), isEmpty);
    await session.authenticate(account: 'account-b');
    expect(await queue.list(), isEmpty);
    await session.authenticate(account: 'account-a');
    final restored = (await queue.list()).single;
    expect(restored.operationId, operationId);
    expect(restored.payload, {'property_id': 7, 'is_liked': true});
    expect(restored.attempts, 1);
    verify(() => api.post(ApiPaths.swipes, body: any(named: 'body'), idempotent: false)).called(1);
  });

  test('ambiguous booking stays reviewable and reconciles without another POST', () async {
    when(
      () => remote.scheduleVisit(
        propertyId: 7,
        scheduledDate: scheduled.toIso8601String(),
        specialRequirements: null,
      ),
    ).thenThrow(NetworkException('response lost', code: 'TIMEOUT'));
    final first =
        await visits.scheduleVisit(propertyId: 7, scheduledDate: scheduled.toIso8601String())
            as VisitUnresolved;
    final persisted = (await queue.list()).single;
    expect(persisted.operationId, first.action.operationId);
    expect(persisted.status, PendingActionStatus.needsReconciliation);
    expect(persisted.attempts, 1);

    final repeat =
        await visits.scheduleVisit(propertyId: 7, scheduledDate: scheduled.toIso8601String())
            as VisitUnresolved;
    expect(repeat.action.operationId, first.action.operationId);
    when(
      () => remote.fetchVisitsSummary(cursor: null, limit: 50),
    ).thenAnswer((_) async => VisitsPayload(visits: [bookedVisit(7)], hasMore: false));
    final reconciled = await visits.reconcile(repeat.action);
    expect(reconciled?.id, 99);
    expect((await queue.list()).single.status, PendingActionStatus.confirmed);
    verify(
      () => remote.scheduleVisit(
        propertyId: 7,
        scheduledDate: scheduled.toIso8601String(),
        specialRequirements: null,
      ),
    ).called(1);
  });
}
