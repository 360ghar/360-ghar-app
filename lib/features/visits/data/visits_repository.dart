import 'package:get/get.dart';
import 'package:ghar360/core/controllers/offline_queue_service.dart';
import 'package:ghar360/core/data/models/agent_model.dart';
import 'package:ghar360/core/data/models/visit_model.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/features/visits/data/datasources/visits_remote_datasource.dart';

export 'package:ghar360/features/visits/data/datasources/visits_remote_datasource.dart'
    show VisitsPayload;

/// Repository for visit scheduling. Controllers depend on this rather than the
/// remote datasource so offline queueing and logging stay in one place.
class VisitsRepository extends GetxService {
  VisitsRepository({VisitsRemoteDatasource? remoteDatasource, this.offlineQueue})
    : _remote = remoteDatasource ?? Get.find<VisitsRemoteDatasource>();

  final VisitsRemoteDatasource _remote;

  /// Optional injected queue (tests); production resolves from GetX when null.
  final OfflineQueueService? offlineQueue;

  OfflineQueueService? get _queue {
    if (offlineQueue != null) return offlineQueue;
    if (Get.isRegistered<OfflineQueueService>()) {
      return Get.find<OfflineQueueService>();
    }
    return null;
  }

  Future<VisitsPayload> fetchVisitsSummary({String? cursor, int limit = 50}) {
    return _remote.fetchVisitsSummary(cursor: cursor, limit: limit);
  }

  Future<AgentModel> fetchRelationshipManager() {
    return _remote.fetchRelationshipManager();
  }

  /// Schedules a visit. On [NetworkException], enqueues for offline replay and
  /// rethrows so callers can show a "queued offline" message.
  Future<VisitModel> scheduleVisit({
    required int propertyId,
    required String scheduledDate,
    String? specialRequirements,
  }) async {
    try {
      return await _remote.scheduleVisit(
        propertyId: propertyId,
        scheduledDate: scheduledDate,
        specialRequirements: specialRequirements,
      );
    } on NetworkException catch (e) {
      DebugLogger.warning('🌐 Network error, queuing visit for retry: ${e.message}');
      final queue = _queue;
      if (queue != null) {
        await queue.enqueueVisit(
          propertyId: propertyId,
          scheduledDate: scheduledDate,
          specialRequirements: specialRequirements,
        );
      } else {
        DebugLogger.error('💥 OfflineQueueService not registered; cannot enqueue visit');
      }
      rethrow;
    }
  }

  Future<bool> cancelVisit(int visitId, {required String reason}) {
    return _remote.cancelVisit(visitId, reason: reason);
  }

  Future<bool> rescheduleVisit(int visitId, {required String newDate, String? reason}) {
    return _remote.rescheduleVisit(visitId, newDate: newDate, reason: reason);
  }
}
