import 'package:get/get.dart';

import 'package:ghar360/core/data/models/static_page_model.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/network/api_paths.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/utils/debug_logger.dart';

class StaticPageRepository extends GetxService {
  StaticPageRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? Get.find<ApiClient>();

  final ApiClient _apiClient;

  Future<StaticPageModel> fetchPublicPage(String uniqueName) async {
    try {
      final response = await _apiClient.get(
        ApiPaths.staticPagePublic(uniqueName),
        useCache: true,
        requireAuth: false,
        notifyUnauthorized: false,
      );
      final body = response.body;
      if (body is! Map<String, dynamic>) {
        throw const FormatException('Unexpected static page response payload');
      }
      return StaticPageModel.fromDynamic(body, fallbackTitle: uniqueName);
    } on AppException {
      rethrow;
    } catch (e, stackTrace) {
      DebugLogger.error('Failed to fetch static page: $uniqueName', e, stackTrace);
      rethrow;
    }
  }
}
