import 'package:get/get.dart';

import 'package:ghar360/core/data/models/bug_report_model.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/network/api_paths.dart';
import 'package:ghar360/core/network/response_parser.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/utils/debug_logger.dart';

/// Repository responsible for support and feedback related network calls.
class SupportRepository extends GetxService {
  SupportRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? Get.find<ApiClient>();

  final ApiClient _apiClient;

  Future<BugReportResponse> submitBugReport(BugReportRequest request) async {
    try {
      DebugLogger.info('📝 Submitting bug report: ${request.bugType.value}');
      final apiResponse = await _apiClient.post(ApiPaths.bugs, body: request.toJson());
      final payload = ResponseParser.unwrapObject(apiResponse.body);
      if (payload.isEmpty) {
        throw const FormatException('Unexpected bug report response payload');
      }
      final response = BugReportResponse.fromJson(payload);
      DebugLogger.success('✅ Bug report submitted (id=${response.id})');
      return response;
    } on AppException catch (e, stackTrace) {
      DebugLogger.error('❌ Failed to submit bug report: ${e.message}', e, stackTrace);
      rethrow;
    } catch (e, st) {
      DebugLogger.error('❌ Unexpected error submitting bug report: $e', e, st);
      throw ServerException(
        'Unexpected error occurred while submitting bug report',
        details: 'Original error: $e',
      );
    }
  }
}
