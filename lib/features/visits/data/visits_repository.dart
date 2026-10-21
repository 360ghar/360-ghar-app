import 'package:ghar360/core/controllers/offline_queue_service.dart';
import 'package:ghar360/core/data/models/agent_model.dart';
import 'package:ghar360/core/data/models/visit_model.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/visits/data/datasources/visits_remote_datasource.dart';

export 'package:ghar360/features/visits/data/datasources/visits_remote_datasource.dart'
    show VisitsPayload;

sealed class VisitRequestResult {
  const VisitRequestResult();
}

class VisitConfirmed extends VisitRequestResult {
  const VisitConfirmed(this.visit);
  final VisitModel visit;
}

class VisitUnresolved extends VisitRequestResult {
  const VisitUnresolved(this.action, {this.failure});
  final PendingAction action;
  final AppException? failure;
}

class VisitFailed extends VisitRequestResult {
  const VisitFailed(this.failure, {this.savedAction});
  final AppException failure;
  final PendingAction? savedAction;
}

class VisitsRepository {
  VisitsRepository({
    required VisitsRemoteDatasource remoteDatasource,
    required OfflineQueueService offlineQueue,
  }) : _remote = remoteDatasource,
       _queue = offlineQueue;
  final VisitsRemoteDatasource _remote;
  final OfflineQueueService _queue;
  final _bookings = <(StorageScope, int), Future<VisitRequestResult>>{};

  Future<VisitsPayload> fetchVisitsSummary({String? cursor, int limit = 50}) =>
      _remote.fetchVisitsSummary(cursor: cursor, limit: limit);
  Future<AgentModel?> fetchRelationshipManager() => _remote.fetchRelationshipManager();

  /// Record the intent before opening a connection. A killed process therefore
  /// leaves a reviewable operation, never an invisible or blindly replayed POST.
  Future<VisitRequestResult> scheduleVisit({
    required int propertyId,
    required String scheduledDate,
    String? specialRequirements,
  }) {
    final scope = _queue.scope;
    final key = (scope, propertyId);
    final existing = _bookings[key];
    if (existing != null) return existing;
    final request = _scheduleVisit(
      scope: scope,
      propertyId: propertyId,
      scheduledDate: scheduledDate,
      specialRequirements: specialRequirements,
    );
    _bookings[key] = request;
    request.whenComplete(() {
      if (identical(_bookings[key], request)) _bookings.remove(key);
    });
    return request;
  }

  Future<VisitRequestResult> _scheduleVisit({
    required StorageScope scope,
    required int propertyId,
    required String scheduledDate,
    String? specialRequirements,
  }) async {
    PendingAction action;
    try {
      final existing = await _queue.list(scope: scope);
      for (final item in existing) {
        if (item.kind == 'visit' &&
            item.payload['property_id'] == propertyId &&
            item.status != PendingActionStatus.confirmed) {
          return VisitUnresolved(item);
        }
      }
      action = await _queue.create(
        scope: scope,
        kind: 'visit',
        status: PendingActionStatus.needsReconciliation,
        payload: {
          'property_id': propertyId,
          'scheduled_date': scheduledDate,
          'special_requirements': specialRequirements ?? '',
        },
      );
    } catch (error) {
      return VisitFailed(_failure(error));
    }
    if (!identical(scope, _queue.scope)) {
      return VisitFailed(AuthenticationException('Account changed.', code: 'CANCELLED'));
    }
    try {
      final visit = await _remote.scheduleVisit(
        propertyId: propertyId,
        scheduledDate: scheduledDate,
        specialRequirements: specialRequirements,
      );
      try {
        await _queue.update(
          action,
          scope: scope,
          status: PendingActionStatus.confirmed,
          attempted: true,
        );
      } catch (_) {
        // The server result is authoritative. The durable record remains
        // unresolved and reconciliation can identify this same booking later.
      }
      return VisitConfirmed(visit);
    } catch (error) {
      final failure = _failure(error);
      // Network, malformed responses, and 5xx can follow a committed POST.
      final rejected =
          failure is ValidationException ||
          failure is AuthenticationException ||
          failure is NotFoundException ||
          (failure is ApiException &&
              failure.statusCode != null &&
              failure.statusCode! >= 400 &&
              failure.statusCode! < 500);
      try {
        await _queue.update(
          action,
          scope: scope,
          status: rejected ? PendingActionStatus.failed : PendingActionStatus.needsReconciliation,
          failureCode: failure.code,
          attempted: true,
        );
      } catch (_) {
        // Keep the already durable intent if status persistence fails.
      }
      return rejected
          ? VisitFailed(failure, savedAction: action)
          : VisitUnresolved(action, failure: failure);
    }
  }

  /// GET-only reconciliation. Absence is not proof that an in-flight POST cannot
  /// still commit, so no booking is automatically resubmitted after this check.
  Future<VisitModel?> reconcile(PendingAction action) async {
    final scope = _queue.scope;
    if (scope.key != action.scopeKey) {
      throw AuthenticationException('Account changed', code: 'CANCELLED');
    }
    final expected = DateTime.tryParse(action.payload['scheduled_date']?.toString() ?? '');
    String? cursor;
    final seen = <String>{};
    do {
      final page = await fetchVisitsSummary(cursor: cursor);
      for (final visit in page.visits) {
        if (visit.propertyId == action.payload['property_id'] &&
            expected != null &&
            visit.scheduledDate.isAtSameMomentAs(expected)) {
          await _queue.update(action, scope: scope, status: PendingActionStatus.confirmed);
          return visit;
        }
      }
      cursor = page.hasMore ? page.nextCursor : null;
    } while (cursor != null && cursor.isNotEmpty && seen.add(cursor));
    return null;
  }

  /// The updated `Visit` the server answers with.
  Future<VisitModel> cancelVisit(int visitId, {required String reason}) =>
      _remote.cancelVisit(visitId, reason: reason);
  Future<VisitModel> rescheduleVisit(int visitId, {required String newDate, String? reason}) =>
      _remote.rescheduleVisit(visitId, newDate: newDate, reason: reason);

  static AppException _failure(Object error) => error is AppException
      ? error
      : ServerException('The visit request could not be completed.', code: 'VISIT_REQUEST_FAILED');
}
