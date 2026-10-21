import 'package:ghar360/core/data/models/bug_report_model.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/network/api_paths.dart';
import 'package:ghar360/core/network/response_parser.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/utils/debug_logger.dart';

/// Repository responsible for support and feedback related network calls.
class SupportRepository {
  SupportRepository({required this._apiClient});

  final ApiClient _apiClient;

  /// `POST /bugs` answers 201 with the stored `BugReportResponse`. The route needs a signed-in
  /// user.
  Future<BugReportResponse> submitBugReport(BugReportRequest request) async {
    try {
      DebugLogger.info('📝 Submitting bug report: ${request.bugType.wire}');
      final apiResponse = await _apiClient.post(ApiPaths.bugs, body: request.toJson());
      final response = BugReportResponse.fromJson(ResponseParser.object(apiResponse.body));
      DebugLogger.success('✅ Bug report submitted (id=${response.id})');
      return response;
    } on AppException catch (e, stackTrace) {
      DebugLogger.error('Support request failed', e.runtimeType, stackTrace);
      rethrow;
    } catch (e, st) {
      DebugLogger.error('Support request failed', e.runtimeType, st);
      throw ServerException(
        'Unexpected error occurred while submitting bug report',
        code: 'SUPPORT_REQUEST_FAILED',
      );
    }
  }
}
