import 'package:ghar360/core/data/models/agent_model.dart';
import 'package:ghar360/core/data/models/visit_model.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/network/api_paths.dart';
import 'package:ghar360/core/network/response_parser.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';

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

  /// The longest cancel reason the backend takes (`VisitCancel.reason`): a longer one is a 422.
  static const maxReasonLength = 1000;

  /// Fetches visits summary payload.
  Future<VisitsPayload> fetchVisitsSummary({String? cursor, int limit = 50}) async {
    final queryParams = <String, dynamic>{'limit': limit.clamp(1, 100).toString()};
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

  /// Schedules a new visit. [scheduledDate] is an ISO 8601 time with a UTC offset (a naive time
  /// is a 422). The route answers 201 with the `Visit`.
  Future<VisitModel> scheduleVisit({
    required int propertyId,
    required String scheduledDate,
    String? specialRequirements,
  }) async {
    final response = await _apiClient.post(
      ApiPaths.visits,
      body: {
        'property_id': propertyId,
        'scheduled_date': scheduledDate,
        if (specialRequirements?.trim().isNotEmpty == true)
          'special_requirements': specialRequirements!.trim(),
      },
    );
    return _parseVisit(response.body);
  }

  /// Cancels a visit. The reason is required: 1 to 1000 characters after trimming. The route
  /// answers 200 with the updated `Visit`.
  Future<VisitModel> cancelVisit(int visitId, {required String reason}) async {
    final text = reason.trim();
    if (text.isEmpty || text.length > maxReasonLength) {
      throw ValidationException(
        'The reason must have 1 to $maxReasonLength characters.',
        code: 'INVALID_REASON',
      );
    }
    final response = await _apiClient.post(ApiPaths.visitCancel(visitId), body: {'reason': text});
    return _parseVisit(response.body);
  }

  /// Reschedules a visit to [newDate] (an ISO 8601 time with a UTC offset). The optional reason is
  /// sent only when it has text. The route answers 200 with the updated `Visit`.
  Future<VisitModel> rescheduleVisit(int visitId, {required String newDate, String? reason}) async {
    final response = await _apiClient.post(
      ApiPaths.visitReschedule(visitId),
      body: {'new_date': newDate, if (reason?.trim().isNotEmpty == true) 'reason': reason!.trim()},
    );
    return _parseVisit(response.body);
  }

  /// The assigned relationship manager, or null when none is assigned yet.
  /// The backend answers `404 NOT_FOUND` ("No agent assigned yet") for that.
  Future<AgentModel?> fetchRelationshipManager() async {
    final ApiResponse response;
    try {
      response = await _apiClient.get(ApiPaths.agentsAssigned, useCache: false);
    } on NotFoundException {
      return null;
    } on ApiException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
    try {
      return AgentModel.fromJson(ResponseParser.object(response.body));
    } catch (_) {
      throw ApiException('Invalid agent response.', code: 'MALFORMED_RESPONSE');
    }
  }

  VisitModel _parseVisit(dynamic body) {
    try {
      return VisitModel.fromJson(ResponseParser.object(body));
    } catch (_) {
      throw ApiException('Invalid visit response.', code: 'MALFORMED_RESPONSE');
    }
  }

  /// A `CursorPage[Visit]`. A row that cannot be read fails the page.
  VisitsPayload _parseVisitsPayload(dynamic body) {
    try {
      final page = ResponseParser.cursorPage(body, VisitModel.fromJson);
      return VisitsPayload(
        visits: page.items,
        hasMore: page.hasMorePages,
        nextCursor: page.nextCursor,
      );
    } catch (_) {
      throw ApiException('Invalid visit response.', code: 'MALFORMED_RESPONSE');
    }
  }
}
