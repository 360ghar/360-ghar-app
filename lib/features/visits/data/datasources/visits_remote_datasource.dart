import 'package:ghar360/core/data/models/agent_model.dart';
import 'package:ghar360/core/data/models/visit_model.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/network/api_paths.dart';
import 'package:ghar360/core/network/response_parser.dart';
import 'package:ghar360/core/utils/debug_logger.dart';

class VisitsPayload {
  final List<VisitModel> visits;
  final bool hasMore;
  final String? nextCursor;

  const VisitsPayload({required this.visits, required this.hasMore, this.nextCursor});
}

/// Remote datasource for visit operations.
class VisitsRemoteDatasource {
  final ApiClient _apiClient;

  VisitsRemoteDatasource(this._apiClient);

  /// Fetches visits summary payload.
  Future<VisitsPayload> fetchVisitsSummary({String? cursor, int limit = 50}) async {
    final queryParams = <String, dynamic>{'limit': limit.toString()};
    if (cursor != null && cursor.isNotEmpty) {
      queryParams['cursor'] = cursor;
    }
    final response = await _apiClient.get(
      ApiPaths.visits,
      queryParams: queryParams,
      useCache: false,
    );
    return _parseVisitsPayload(response.body);
  }

  /// Schedules a new visit.
  Future<VisitModel> scheduleVisit({
    required int propertyId,
    required String scheduledDate,
    String? specialRequirements,
  }) async {
    DebugLogger.debug('📅 Scheduling visit for property $propertyId');
    final response = await _apiClient.post(
      ApiPaths.visits,
      body: {
        'property_id': propertyId,
        'scheduled_date': scheduledDate,
        'special_requirements': specialRequirements ?? '',
      },
      idempotent: true,
    );
    return _parseVisit(response.body);
  }

  /// Cancels a visit.
  Future<bool> cancelVisit(int visitId, {required String reason}) async {
    DebugLogger.debug('❌ Cancelling visit $visitId');
    final response = await _apiClient.post(
      ApiPaths.visitCancel(visitId),
      body: {'reason': reason},
      idempotent: true,
    );
    final body = response.body;
    if (body is Map<String, dynamic>) {
      return body['success'] == true || response.statusCode == 200;
    }
    return response.statusCode == 200;
  }

  /// Reschedules a visit.
  Future<bool> rescheduleVisit(int visitId, {required String newDate, String? reason}) async {
    DebugLogger.debug('📅 Rescheduling visit $visitId');
    final response = await _apiClient.post(
      ApiPaths.visitReschedule(visitId),
      body: {'new_date': newDate, 'reason': reason ?? ''},
      idempotent: true,
    );
    final body = response.body;
    if (body is Map<String, dynamic>) {
      return body['success'] == true || response.statusCode == 200;
    }
    return response.statusCode == 200;
  }

  Future<AgentModel> fetchRelationshipManager() async {
    final response = await _apiClient.get(ApiPaths.agentsAssigned, useCache: false);
    final payload = ResponseParser.unwrapObject(response.body);
    return AgentModel.fromJson(Map<String, dynamic>.from(payload));
  }

  List<VisitModel> _parseVisitsResponse(dynamic body) {
    try {
      final list = ResponseParser.unwrapList(body, fallbackKeys: ['visits']);
      return list.map((json) => VisitModel.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e, stackTrace) {
      DebugLogger.error('Failed to parse visits response: $e', e, stackTrace);
      rethrow;
    }
  }

  VisitModel _parseVisit(dynamic body) {
    final payload = ResponseParser.unwrapObject(body);
    if (payload.isEmpty) {
      throw const FormatException('Unexpected visit response');
    }
    return VisitModel.fromJson(Map<String, dynamic>.from(payload));
  }

  VisitsPayload _parseVisitsPayload(dynamic body) {
    final visits = _parseVisitsResponse(body);
    final hasMore = ResponseParser.extractHasMore(body);
    final nextCursor = ResponseParser.extractNextCursor(body);
    return VisitsPayload(visits: visits, hasMore: hasMore, nextCursor: nextCursor);
  }
}
