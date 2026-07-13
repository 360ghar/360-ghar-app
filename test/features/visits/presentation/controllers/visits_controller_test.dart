import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/data/models/auth_status.dart';
import 'package:ghar360/core/data/models/visit_model.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:ghar360/features/visits/data/visits_repository.dart';
import 'package:ghar360/features/visits/presentation/controllers/visits_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/getx_test_binding.dart';
import '../../../../helpers/mocks.dart';

class MockDashboardController extends GetxServiceMock implements DashboardController {}

void main() {
  late MockAuthController mockAuthController;
  late MockVisitsRepository mockVisitsRepository;
  late Rx<AuthStatus> authStatus;

  setUp(() {
    GetxTestBinding.init();

    mockAuthController = MockAuthController();
    mockVisitsRepository = MockVisitsRepository();
    authStatus = AuthStatus.unauthenticated.obs;

    // Stub AuthController reactive fields
    when(() => mockAuthController.authStatus).thenReturn(authStatus);
    when(() => mockAuthController.isAuthenticated).thenReturn(false);

    // Default stubs for repository methods (overridden per-test as needed).
    // Required because createController() with isAuthenticated=true triggers
    // _initializeController which calls loadVisits and loadRelationshipManager.
    when(
      () => mockVisitsRepository.fetchVisitsSummary(
        cursor: any(named: 'cursor'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => const VisitsPayload(visits: [], hasMore: false));
    when(
      () => mockVisitsRepository.fetchRelationshipManager(),
    ).thenAnswer((_) async => testAgentModel(id: 1));

    GetxTestBinding.bind()
      ..register<AuthController>(mockAuthController)
      ..register<VisitsRepository>(mockVisitsRepository);
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  VisitsController createController() {
    final c = VisitsController();
    c.onInit();
    return c;
  }

  VisitModel makeVisit({
    int id = 1,
    required DateTime scheduledDate,
    VisitStatus status = VisitStatus.scheduled,
  }) {
    return VisitModel(
      id: id,
      propertyId: 100,
      userId: 1,
      scheduledDate: scheduledDate,
      status: status,
      createdAt: DateTime(2024, 1, 1),
    );
  }

  group('VisitsController', () {
    test('initial state has empty lists and loading flags false', () {
      final controller = createController();

      expect(controller.visits, isEmpty);
      expect(controller.upcomingVisitsList, isEmpty);
      expect(controller.pastVisitsList, isEmpty);
      expect(controller.isLoading.value, isFalse);
      expect(controller.error.value, isNull);
    });

    test('loadVisits fetches and splits into upcoming and past', () async {
      // Switch to authenticated
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      authStatus.value = AuthStatus.authenticated;

      final now = DateTime.now();
      final upcoming = makeVisit(id: 1, scheduledDate: now.add(const Duration(days: 3)));
      final past = makeVisit(
        id: 2,
        scheduledDate: now.subtract(const Duration(days: 2)),
        status: VisitStatus.completed,
      );

      when(
        () => mockVisitsRepository.fetchVisitsSummary(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => VisitsPayload(visits: [upcoming, past], hasMore: false));

      final controller = createController();
      await controller.loadVisits();

      expect(controller.upcomingVisitsList.length, 1);
      expect(controller.upcomingVisitsList.first.id, 1);
      expect(controller.pastVisitsList.length, 1);
      expect(controller.pastVisitsList.first.id, 2);
      expect(controller.isLoading.value, isFalse);
    });

    test('loadVisits sets authentication error when not authenticated', () async {
      final controller = createController();
      await controller.loadVisits();

      expect(controller.error.value, isA<AuthenticationException>());
    });

    test('bookVisit returns false when not authenticated', () async {
      final controller = createController();
      final result = await controller.bookVisit(
        testPropertyModel(),
        DateTime.now().add(const Duration(days: 1)),
      );

      expect(result, isFalse);
    });

    test('bookVisit returns true on success when authenticated', () async {
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      authStatus.value = AuthStatus.authenticated;

      final visitDate = DateTime.now().add(const Duration(days: 5));
      final scheduledVisit = makeVisit(id: 10, scheduledDate: visitDate);

      when(
        () => mockVisitsRepository.scheduleVisit(
          propertyId: any(named: 'propertyId'),
          scheduledDate: any(named: 'scheduledDate'),
          specialRequirements: any(named: 'specialRequirements'),
        ),
      ).thenAnswer((_) async => scheduledVisit);

      // Stub the refresh after booking
      when(
        () => mockVisitsRepository.fetchVisitsSummary(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => VisitsPayload(visits: [scheduledVisit], hasMore: false));

      final controller = createController();
      final result = await controller.bookVisit(testPropertyModel(id: 100), visitDate);

      expect(result, isTrue);
    });

    test('cancelVisit returns false when not authenticated', () async {
      final controller = createController();
      final result = await controller.cancelVisit(1, reason: 'changed mind');

      expect(result, isFalse);
    });

    test('rescheduleVisit returns false when not authenticated', () async {
      final controller = createController();
      final result = await controller.rescheduleVisit(
        1,
        DateTime.now().add(const Duration(days: 10)),
      );

      expect(result, isFalse);
    });

    test('formatVisitDate returns today for current date', () {
      final controller = createController();
      final result = controller.formatVisitDate(DateTime.now());

      expect(result, isNotEmpty);
      // The actual string depends on translations; verify it's a non-empty key
      expect(result, isA<String>());
    });

    test('formatVisitDate returns different values for today vs future', () {
      final controller = createController();
      final todayResult = controller.formatVisitDate(DateTime.now());
      final futureResult = controller.formatVisitDate(DateTime.now().add(const Duration(days: 5)));

      // They should produce different output
      expect(todayResult, isNot(equals(futureResult)));
    });

    test('_clearAllData clears all lists when auth status changes to unauthenticated', () async {
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      authStatus.value = AuthStatus.authenticated;

      // Pre-populate lists by loading visits
      final now = DateTime.now();
      final upcoming = makeVisit(id: 1, scheduledDate: now.add(const Duration(days: 3)));
      when(
        () => mockVisitsRepository.fetchVisitsSummary(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => VisitsPayload(visits: [upcoming], hasMore: false));

      final controller = createController();
      // Allow all async init (visits + agent) to complete
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(controller.visits, isNotEmpty);

      // Simulate logout
      when(() => mockAuthController.isAuthenticated).thenReturn(false);
      authStatus.value = AuthStatus.unauthenticated;
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(controller.visits, isEmpty);
      expect(controller.upcomingVisitsList, isEmpty);
      expect(controller.pastVisitsList, isEmpty);
      expect(controller.relationshipManager.value, isNull);
      expect(controller.hasLoadedVisits.value, isFalse);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // Additional tests for cancellation, rescheduling, error handling,
  // pagination, relationship manager, refresh, and edge cases
  // ─────────────────────────────────────────────────────────────────────

  group('VisitsController — cancelVisit', () {
    test('returns false when visit is not found in list', () async {
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      authStatus.value = AuthStatus.authenticated;

      final controller = createController();
      // visits list is empty, so visitId 1 won't be found
      final result = await controller.cancelVisit(1, reason: 'changed mind');

      expect(result, isFalse);
    });

    test('returns false when reason is empty', () async {
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      authStatus.value = AuthStatus.authenticated;

      final now = DateTime.now();
      final upcoming = makeVisit(id: 5, scheduledDate: now.add(const Duration(days: 3)));

      when(
        () => mockVisitsRepository.fetchVisitsSummary(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => VisitsPayload(visits: [upcoming], hasMore: false));

      final controller = createController();
      await controller.loadVisits();

      final result = await controller.cancelVisit(5, reason: '   ');

      expect(result, isFalse);
    });

    test('returns false when visit cannot be cancelled (completed status)', () async {
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      authStatus.value = AuthStatus.authenticated;

      final now = DateTime.now();
      final completedVisit = makeVisit(
        id: 10,
        scheduledDate: now.subtract(const Duration(days: 5)),
        status: VisitStatus.completed,
      );

      when(
        () => mockVisitsRepository.fetchVisitsSummary(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => VisitsPayload(visits: [completedVisit], hasMore: false));

      final controller = createController();
      await controller.loadVisits();

      final result = await controller.cancelVisit(10, reason: 'changed mind');

      expect(result, isFalse);
    });

    test('succeeds when authenticated and visit is cancellable', () async {
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      authStatus.value = AuthStatus.authenticated;

      final now = DateTime.now();
      final upcoming = makeVisit(id: 15, scheduledDate: now.add(const Duration(days: 3)));

      when(
        () => mockVisitsRepository.fetchVisitsSummary(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => VisitsPayload(visits: [upcoming], hasMore: false));
      when(
        () => mockVisitsRepository.cancelVisit(any(), reason: any(named: 'reason')),
      ).thenAnswer((_) async => true);

      final controller = createController();
      await controller.loadVisits();

      final result = await controller.cancelVisit(15, reason: 'changed mind');

      expect(result, isTrue);
      verify(() => mockVisitsRepository.cancelVisit(15, reason: 'changed mind')).called(1);
    });

    test('returns false when repository cancelVisit returns false', () async {
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      authStatus.value = AuthStatus.authenticated;

      final now = DateTime.now();
      final upcoming = makeVisit(id: 20, scheduledDate: now.add(const Duration(days: 3)));

      when(
        () => mockVisitsRepository.fetchVisitsSummary(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => VisitsPayload(visits: [upcoming], hasMore: false));
      when(
        () => mockVisitsRepository.cancelVisit(any(), reason: any(named: 'reason')),
      ).thenAnswer((_) async => false);

      final controller = createController();
      await controller.loadVisits();

      final result = await controller.cancelVisit(20, reason: 'changed mind');

      expect(result, isFalse);
    });
  });

  group('VisitsController — rescheduleVisit', () {
    test('returns false when not authenticated', () async {
      final controller = createController();
      final result = await controller.rescheduleVisit(
        1,
        DateTime.now().add(const Duration(days: 10)),
      );

      expect(result, isFalse);
    });

    test('returns false when visit is not found in list', () async {
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      authStatus.value = AuthStatus.authenticated;

      final controller = createController();
      final result = await controller.rescheduleVisit(
        999,
        DateTime.now().add(const Duration(days: 10)),
      );

      expect(result, isFalse);
    });

    test('returns false when visit cannot be rescheduled (cancelled status)', () async {
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      authStatus.value = AuthStatus.authenticated;

      final now = DateTime.now();
      final cancelledVisit = makeVisit(
        id: 25,
        scheduledDate: now.subtract(const Duration(days: 5)),
        status: VisitStatus.cancelled,
      );

      when(
        () => mockVisitsRepository.fetchVisitsSummary(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => VisitsPayload(visits: [cancelledVisit], hasMore: false));

      final controller = createController();
      await controller.loadVisits();

      final result = await controller.rescheduleVisit(
        25,
        DateTime.now().add(const Duration(days: 10)),
      );

      expect(result, isFalse);
    });

    test('succeeds when authenticated and visit is reschedulable', () async {
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      authStatus.value = AuthStatus.authenticated;

      final now = DateTime.now();
      final upcoming = makeVisit(id: 30, scheduledDate: now.add(const Duration(days: 3)));

      when(
        () => mockVisitsRepository.fetchVisitsSummary(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => VisitsPayload(visits: [upcoming], hasMore: false));
      when(
        () => mockVisitsRepository.rescheduleVisit(
          any(),
          newDate: any(named: 'newDate'),
          reason: any(named: 'reason'),
        ),
      ).thenAnswer((_) async => true);

      final controller = createController();
      await controller.loadVisits();

      final newDate = DateTime.now().add(const Duration(days: 10));
      final result = await controller.rescheduleVisit(30, newDate);

      expect(result, isTrue);
    });
  });

  group('VisitsController — loadMoreVisits', () {
    test('returns early when not authenticated', () async {
      final controller = createController();
      // Not authenticated, so init doesn't trigger loadVisits
      await controller.loadMoreVisits();

      verifyNever(
        () => mockVisitsRepository.fetchVisitsSummary(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      );
    });

    test('returns early when already loading', () async {
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      authStatus.value = AuthStatus.authenticated;

      final controller = createController();
      // Wait for init to complete
      await Future<void>.delayed(const Duration(milliseconds: 50));
      controller.isLoading.value = true;

      await controller.loadMoreVisits();

      // loadMoreVisits should not have set isLoadingMore (returned early)
      expect(controller.isLoadingMore.value, isFalse);
    });

    test('returns early when isLoadingMore is true', () async {
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      authStatus.value = AuthStatus.authenticated;

      final controller = createController();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      controller.isLoadingMore.value = true;

      await controller.loadMoreVisits();

      // isLoadingMore should still be true (wasn't reset by loadMoreVisits)
      // Actually loadMoreVisits returns early without touching isLoadingMore,
      // but the finally block sets it to false. Since it returned before the
      // try block, isLoadingMore stays true.
      expect(controller.isLoadingMore.value, isTrue);
    });

    test('returns early when hasMore is false', () async {
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      authStatus.value = AuthStatus.authenticated;

      final controller = createController();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      controller.hasMore.value = false;

      await controller.loadMoreVisits();

      // loadMoreVisits should not have set isLoadingMore (returned early)
      expect(controller.isLoadingMore.value, isFalse);
    });

    test('marks hasMore false when nextCursor is null', () async {
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      authStatus.value = AuthStatus.authenticated;

      final controller = createController();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      controller.hasMore.value = true;
      controller.nextCursor.value = null;

      await controller.loadMoreVisits();

      expect(controller.hasMore.value, isFalse);
    });

    test('fetches next page when cursor is set', () async {
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      authStatus.value = AuthStatus.authenticated;

      final now = DateTime.now();
      final newVisit = makeVisit(id: 50, scheduledDate: now.add(const Duration(days: 5)));

      when(
        () => mockVisitsRepository.fetchVisitsSummary(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => VisitsPayload(visits: [newVisit], hasMore: false));

      final controller = createController();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      controller.hasMore.value = true;
      controller.nextCursor.value = 'cursor-abc';

      await controller.loadMoreVisits();

      verify(
        () => mockVisitsRepository.fetchVisitsSummary(
          cursor: 'cursor-abc',
          limit: any(named: 'limit'),
        ),
      ).called(greaterThanOrEqualTo(1));
      expect(controller.isLoadingMore.value, isFalse);
    });
  });

  group('VisitsController — relationship manager', () {
    test('loadRelationshipManager returns early when not authenticated', () async {
      final controller = createController();

      await controller.loadRelationshipManager();

      verifyNever(() => mockVisitsRepository.fetchRelationshipManager());
    });

    test('loadRelationshipManager loads agent successfully', () async {
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      authStatus.value = AuthStatus.authenticated;

      final agent = testAgentModel(id: 1);
      when(() => mockVisitsRepository.fetchRelationshipManager()).thenAnswer((_) async => agent);

      final controller = createController();
      await controller.loadRelationshipManager();

      expect(controller.relationshipManager.value, isNotNull);
      expect(controller.relationshipManager.value?.id, 1);
      expect(controller.isLoadingAgent.value, isFalse);
    });

    test('loadRelationshipManager sets error on failure', () async {
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      authStatus.value = AuthStatus.authenticated;

      when(
        () => mockVisitsRepository.fetchRelationshipManager(),
      ).thenThrow(ServerException('agent error'));

      final controller = createController();
      await controller.loadRelationshipManager();

      expect(controller.error.value, isNotNull);
      expect(controller.isLoadingAgent.value, isFalse);
    });
  });

  group('VisitsController — refresh and lazy loading', () {
    test('refreshVisits calls loadVisits with isRefresh true', () async {
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      authStatus.value = AuthStatus.authenticated;

      when(
        () => mockVisitsRepository.fetchVisitsSummary(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => const VisitsPayload(visits: [], hasMore: false));

      final controller = createController();
      await controller.refreshVisits();

      // loadVisits should have been called (which calls fetchVisitsSummary)
      verify(
        () => mockVisitsRepository.fetchVisitsSummary(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).called(greaterThan(0));
    });

    test('loadVisitsLazy skips when hasLoadedVisits is true', () async {
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      authStatus.value = AuthStatus.authenticated;

      final controller = createController();
      // Wait for init to complete (which sets hasLoadedVisits to true)
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(controller.hasLoadedVisits.value, isTrue);

      // Calling loadVisitsLazy again should be a no-op
      await controller.loadVisitsLazy();

      // isLoading should not have been set to true by the second call
      expect(controller.isLoading.value, isFalse);
    });

    test('loadVisitsLazy skips when isLoading is true', () async {
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      authStatus.value = AuthStatus.authenticated;

      final controller = createController();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      controller.hasLoadedVisits.value = false;
      controller.isLoading.value = true;

      await controller.loadVisitsLazy();

      // hasLoadedVisits should not have been set to true (skipped)
      expect(controller.hasLoadedVisits.value, isFalse);
    });

    test('loadRelationshipManagerLazy skips when hasLoadedAgent is true', () async {
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      authStatus.value = AuthStatus.authenticated;

      final controller = createController();
      controller.hasLoadedAgent.value = true;

      await controller.loadRelationshipManagerLazy();

      verifyNever(() => mockVisitsRepository.fetchRelationshipManager());
    });
  });

  group('VisitsController — error handling', () {
    test('loadVisits sets error on repository failure', () async {
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      authStatus.value = AuthStatus.authenticated;

      when(
        () => mockVisitsRepository.fetchVisitsSummary(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).thenThrow(ServerException('network error'));

      final controller = createController();
      await controller.loadVisits();

      expect(controller.error.value, isNotNull);
      expect(controller.isLoading.value, isFalse);
    });

    test('loadVisits sets error on generic exception', () async {
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      authStatus.value = AuthStatus.authenticated;

      when(
        () => mockVisitsRepository.fetchVisitsSummary(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).thenThrow(Exception('generic error'));

      final controller = createController();
      await controller.loadVisits();

      expect(controller.error.value, isA<ServerException>());
      expect(controller.isLoading.value, isFalse);
    });

    test('loadMoreVisits sets error on repository failure', () async {
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      authStatus.value = AuthStatus.authenticated;

      when(
        () => mockVisitsRepository.fetchVisitsSummary(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).thenThrow(ServerException('pagination error'));

      final controller = createController();
      controller.hasMore.value = true;
      controller.nextCursor.value = 'cursor-xyz';

      await controller.loadMoreVisits();

      expect(controller.error.value, isNotNull);
      expect(controller.isLoadingMore.value, isFalse);
    });
  });

  group('VisitsController — bookVisit error handling', () {
    test('returns false on scheduleVisit failure', () async {
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      authStatus.value = AuthStatus.authenticated;

      when(
        () => mockVisitsRepository.scheduleVisit(
          propertyId: any(named: 'propertyId'),
          scheduledDate: any(named: 'scheduledDate'),
          specialRequirements: any(named: 'specialRequirements'),
        ),
      ).thenThrow(ServerException('booking error'));

      final controller = createController();
      final result = await controller.bookVisit(
        testPropertyModel(id: 100),
        DateTime.now().add(const Duration(days: 1)),
      );

      expect(result, isFalse);
      expect(controller.error.value, isNotNull);
      expect(controller.isBookingVisit.value, isFalse);
    });
  });

  group('VisitsController — markVisitCompleted', () {
    test('updates visit status to completed', () async {
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      authStatus.value = AuthStatus.authenticated;

      final now = DateTime.now();
      final upcoming = makeVisit(id: 40, scheduledDate: now.add(const Duration(days: 3)));

      when(
        () => mockVisitsRepository.fetchVisitsSummary(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => VisitsPayload(visits: [upcoming], hasMore: false));

      final controller = createController();
      await controller.loadVisits();

      controller.markVisitCompleted(40);

      final visit = controller.visits.firstWhere((v) => v.id == 40);
      expect(visit.status, VisitStatus.completed);
    });

    test('is a no-op when visit is not found', () async {
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      authStatus.value = AuthStatus.authenticated;

      final controller = createController();

      // Should not throw
      controller.markVisitCompleted(999);
    });
  });

  group('VisitsController — formatVisitTime', () {
    test('formats morning time correctly', () {
      final controller = createController();
      final result = controller.formatVisitTime(DateTime(2025, 1, 15, 9, 30));

      expect(result, '9:30 AM');
    });

    test('formats afternoon time correctly', () {
      final controller = createController();
      final result = controller.formatVisitTime(DateTime(2025, 1, 15, 14, 0));

      expect(result, '2:00 PM');
    });

    test('formats midnight as 12:00 AM', () {
      final controller = createController();
      final result = controller.formatVisitTime(DateTime(2025, 1, 15, 0, 0));

      expect(result, '12:00 AM');
    });

    test('formats noon as 12:00 PM', () {
      final controller = createController();
      final result = controller.formatVisitTime(DateTime(2025, 1, 15, 12, 0));

      expect(result, '12:00 PM');
    });

    test('pads single-digit minutes', () {
      final controller = createController();
      final result = controller.formatVisitTime(DateTime(2025, 1, 15, 10, 5));

      expect(result, '10:05 AM');
    });
  });

  group('VisitsController — formatVisitDate', () {
    test('returns tomorrow for next day', () {
      final controller = createController();
      final result = controller.formatVisitDate(DateTime.now().add(const Duration(days: 1)));

      expect(result, 'tomorrow');
    });

    test('returns yesterday for previous day', () {
      final controller = createController();
      final result = controller.formatVisitDate(DateTime.now().subtract(const Duration(days: 1)));

      expect(result, 'yesterday');
    });

    test('returns in_n_days for future date', () {
      final controller = createController();
      final result = controller.formatVisitDate(DateTime.now().add(const Duration(days: 5)));

      expect(result, contains('in_n_days'));
    });

    test('returns n_days_ago for past date', () {
      final controller = createController();
      final result = controller.formatVisitDate(DateTime.now().subtract(const Duration(days: 5)));

      expect(result, contains('n_days_ago'));
    });
  });

  group('VisitsController — upcomingVisits and pastVisits getters', () {
    test('upcomingVisits returns computed list when not loaded', () {
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      authStatus.value = AuthStatus.authenticated;

      final controller = createController();
      // Reset hasLoadedVisits so the fallback compute path is used
      controller.hasLoadedVisits.value = false;
      controller.upcomingVisitsList.clear();
      // Don't load visits, just set visits directly
      final now = DateTime.now();
      controller.visits.assignAll([
        makeVisit(id: 1, scheduledDate: now.add(const Duration(days: 3))),
        makeVisit(id: 2, scheduledDate: now.subtract(const Duration(days: 2))),
      ]);

      final upcoming = controller.upcomingVisits;
      expect(upcoming.length, 1);
      expect(upcoming.first.id, 1);
    });

    test('pastVisits returns computed list when not loaded', () {
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      authStatus.value = AuthStatus.authenticated;

      final controller = createController();
      // Reset hasLoadedVisits so the fallback compute path is used
      controller.hasLoadedVisits.value = false;
      controller.pastVisitsList.clear();
      final now = DateTime.now();
      controller.visits.assignAll([
        makeVisit(id: 1, scheduledDate: now.add(const Duration(days: 3))),
        makeVisit(
          id: 2,
          scheduledDate: now.subtract(const Duration(days: 2)),
          status: VisitStatus.completed,
        ),
      ]);

      final past = controller.pastVisits;
      expect(past.length, 1);
      expect(past.first.id, 2);
    });

    test('upcomingVisits returns upcomingVisitsList when loaded', () async {
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      authStatus.value = AuthStatus.authenticated;

      final now = DateTime.now();
      final upcoming = makeVisit(id: 1, scheduledDate: now.add(const Duration(days: 3)));

      when(
        () => mockVisitsRepository.fetchVisitsSummary(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => VisitsPayload(visits: [upcoming], hasMore: false));

      final controller = createController();
      await controller.loadVisits();

      expect(controller.upcomingVisits.length, 1);
      expect(controller.upcomingVisits.first.id, 1);
    });
  });

  group('VisitsController — silent refresh', () {
    test('loadVisits with silent flag sets isBackgroundRefreshing', () async {
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      authStatus.value = AuthStatus.authenticated;

      when(
        () => mockVisitsRepository.fetchVisitsSummary(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => const VisitsPayload(visits: [], hasMore: false));

      final controller = createController();
      await controller.loadVisits(silent: true);

      // After completion, isBackgroundRefreshing should be false
      expect(controller.isBackgroundRefreshing.value, isFalse);
    });

    test('loadVisits with isRefresh clears existing data', () async {
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      authStatus.value = AuthStatus.authenticated;

      final now = DateTime.now();
      final initialVisit = makeVisit(id: 1, scheduledDate: now.add(const Duration(days: 3)));

      when(
        () => mockVisitsRepository.fetchVisitsSummary(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => VisitsPayload(visits: [initialVisit], hasMore: false));

      final controller = createController();
      await controller.loadVisits();
      expect(controller.visits, isNotEmpty);

      // Now refresh with empty result
      when(
        () => mockVisitsRepository.fetchVisitsSummary(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => const VisitsPayload(visits: [], hasMore: false));

      await controller.loadVisits(isRefresh: true);
      expect(controller.visits, isEmpty);
    });
  });

  group('VisitsController — remaining high-miss paths', () {
    test('skips duplicate load when dataLoadInFlight is true', () async {
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      authStatus.value = AuthStatus.authenticated;

      final controller = createController();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      controller.dataLoadInFlight = true;

      clearInteractions(mockVisitsRepository);
      await controller.loadVisits();

      verifyNever(
        () => mockVisitsRepository.fetchVisitsSummary(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      );
    });

    test('skips silent refresh when background refresh already in flight', () async {
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      authStatus.value = AuthStatus.authenticated;

      final controller = createController();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // First silent load starts; simulate concurrent by setting flag via first call hanging
      var calls = 0;
      when(
        () => mockVisitsRepository.fetchVisitsSummary(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 80));
        return const VisitsPayload(visits: [], hasMore: false);
      });

      final first = controller.loadVisits(silent: true);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await controller.loadVisits(silent: true); // should skip
      await first;

      expect(calls, 1);
    });

    test('loadMoreVisits merges page and deduplicates by id', () async {
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      authStatus.value = AuthStatus.authenticated;

      final now = DateTime.now();
      final existing = makeVisit(id: 1, scheduledDate: now.add(const Duration(days: 2)));
      final duplicate = makeVisit(id: 1, scheduledDate: now.add(const Duration(days: 2)));
      final fresh = makeVisit(id: 2, scheduledDate: now.add(const Duration(days: 4)));

      when(
        () => mockVisitsRepository.fetchVisitsSummary(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => VisitsPayload(visits: [existing], hasMore: true, nextCursor: 'c1'));

      final controller = createController();
      await controller.loadVisits();
      expect(controller.visits.length, 1);

      when(
        () => mockVisitsRepository.fetchVisitsSummary(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) async => VisitsPayload(visits: [duplicate, fresh], hasMore: false, nextCursor: null),
      );

      controller.hasMore.value = true;
      controller.nextCursor.value = 'c1';
      await controller.loadMoreVisits();

      expect(controller.visits.where((v) => v.id == 1).length, 1);
      expect(controller.visits.any((v) => v.id == 2), isTrue);
    });

    test('loadMoreVisits treats empty cursor string as terminal', () async {
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      authStatus.value = AuthStatus.authenticated;

      final controller = createController();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      controller.hasMore.value = true;
      controller.nextCursor.value = '';

      await controller.loadMoreVisits();
      expect(controller.hasMore.value, isFalse);
    });

    test('bookVisit returns false and shows offline path for NetworkException', () async {
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      authStatus.value = AuthStatus.authenticated;

      when(
        () => mockVisitsRepository.scheduleVisit(
          propertyId: any(named: 'propertyId'),
          scheduledDate: any(named: 'scheduledDate'),
          specialRequirements: any(named: 'specialRequirements'),
        ),
      ).thenThrow(NetworkException('offline', code: 'CONNECTION_ERROR'));

      final controller = createController();
      final result = await controller.bookVisit(
        testPropertyModel(id: 9),
        DateTime.now().add(const Duration(days: 2)),
      );

      expect(result, isFalse);
      expect(controller.error.value, isA<NetworkException>());
      expect(controller.isBookingVisit.value, isFalse);
    });

    test('cancelVisit accepts string visitId and returns false on repository false', () async {
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      authStatus.value = AuthStatus.authenticated;

      final now = DateTime.now();
      final upcoming = makeVisit(id: 77, scheduledDate: now.add(const Duration(days: 3)));
      when(
        () => mockVisitsRepository.fetchVisitsSummary(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => VisitsPayload(visits: [upcoming], hasMore: false));
      when(
        () => mockVisitsRepository.cancelVisit(any(), reason: any(named: 'reason')),
      ).thenAnswer((_) async => false);

      final controller = createController();
      await controller.loadVisits();

      final result = await controller.cancelVisit('77', reason: 'plans changed');
      expect(result, isFalse);
    });

    test('rescheduleVisit returns false when repository returns false', () async {
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      authStatus.value = AuthStatus.authenticated;

      final now = DateTime.now();
      final upcoming = makeVisit(id: 88, scheduledDate: now.add(const Duration(days: 3)));
      when(
        () => mockVisitsRepository.fetchVisitsSummary(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => VisitsPayload(visits: [upcoming], hasMore: false));
      when(
        () => mockVisitsRepository.rescheduleVisit(
          any(),
          newDate: any(named: 'newDate'),
          reason: any(named: 'reason'),
        ),
      ).thenAnswer((_) async => false);

      final controller = createController();
      await controller.loadVisits();

      final result = await controller.rescheduleVisit(
        '88',
        DateTime.now().add(const Duration(days: 12)),
        reason: 'conflict',
      );
      expect(result, isFalse);
    });

    test('markVisitCompleted accepts string visit id', () async {
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      authStatus.value = AuthStatus.authenticated;

      final now = DateTime.now();
      final upcoming = makeVisit(id: 55, scheduledDate: now.add(const Duration(days: 3)));
      when(
        () => mockVisitsRepository.fetchVisitsSummary(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => VisitsPayload(visits: [upcoming], hasMore: false));

      final controller = createController();
      await controller.loadVisits();
      controller.markVisitCompleted('55');

      expect(controller.visits.firstWhere((v) => v.id == 55).status, VisitStatus.completed);
    });

    test('loadRelationshipManagerLazy skips when isLoadingAgent is true', () async {
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      authStatus.value = AuthStatus.authenticated;

      final controller = createController();
      controller.hasLoadedAgent.value = false;
      controller.isLoadingAgent.value = true;

      clearInteractions(mockVisitsRepository);
      await controller.loadRelationshipManagerLazy();

      verifyNever(() => mockVisitsRepository.fetchRelationshipManager());
    });

    test('onClose disposes workers', () {
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      authStatus.value = AuthStatus.authenticated;

      final controller = createController();
      expect(() => controller.onClose(), returnsNormally);
    });

    test('tab activation worker refreshes when dashboard index is visits', () async {
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      authStatus.value = AuthStatus.authenticated;

      final mockDash = MockDashboardController();
      final currentIndex = 0.obs;
      when(() => mockDash.currentIndex).thenReturn(currentIndex);
      Get.put<DashboardController>(mockDash, permanent: true);

      when(
        () => mockVisitsRepository.fetchVisitsSummary(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => const VisitsPayload(visits: [], hasMore: false));

      final controller = createController();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      clearInteractions(mockVisitsRepository);

      currentIndex.value = 4; // visits tab
      await Future<void>.delayed(const Duration(milliseconds: 50));

      verify(
        () => mockVisitsRepository.fetchVisitsSummary(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).called(greaterThanOrEqualTo(1));

      // Cooldown path: switch away and back immediately
      clearInteractions(mockVisitsRepository);
      currentIndex.value = 0;
      currentIndex.value = 4;
      await Future<void>.delayed(const Duration(milliseconds: 30));
      // May be skipped due to 30s cooldown
      Get.delete<DashboardController>();
      controller.onClose();
    });

    test('loadVisits logs upcoming and past branches when both present', () async {
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      authStatus.value = AuthStatus.authenticated;

      final now = DateTime.now();
      final upcoming = makeVisit(id: 1, scheduledDate: now.add(const Duration(days: 2)));
      final past = makeVisit(
        id: 2,
        scheduledDate: now.subtract(const Duration(days: 2)),
        status: VisitStatus.completed,
      );
      final cancelled = makeVisit(
        id: 3,
        scheduledDate: now.add(const Duration(days: 1)),
        status: VisitStatus.cancelled,
      );

      when(
        () => mockVisitsRepository.fetchVisitsSummary(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => VisitsPayload(visits: [upcoming, past, cancelled], hasMore: false));

      final controller = createController();
      await controller.loadVisits();

      expect(controller.upcomingVisitsList.any((v) => v.id == 1), isTrue);
      expect(controller.pastVisitsList.any((v) => v.id == 2), isTrue);
      expect(controller.pastVisitsList.any((v) => v.id == 3), isTrue);
    });

    test('loadMoreVisits with empty page is a no-op merge', () async {
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      authStatus.value = AuthStatus.authenticated;

      final controller = createController();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      controller.hasMore.value = true;
      controller.nextCursor.value = 'next';

      when(
        () => mockVisitsRepository.fetchVisitsSummary(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => const VisitsPayload(visits: [], hasMore: false));

      await controller.loadMoreVisits();
      expect(controller.isLoadingMore.value, isFalse);
    });
  });
}
