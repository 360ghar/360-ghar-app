import 'package:ghar360/core/data/models/static_page_model.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/network/api_paths.dart';
import 'package:ghar360/core/network/response_parser.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/utils/debug_logger.dart';

/// `GET /pages/public/{unique_name}`: a `PagePublicResponse`. The route takes no sign-in.
class StaticPageRepository {
  StaticPageRepository({required this._apiClient});

  final ApiClient _apiClient;

  Future<StaticPageModel> fetchPublicPage(String uniqueName) async {
    try {
      final response = await _apiClient.get(
        ApiPaths.staticPagePublic(uniqueName),
        useCache: true,
        requireAuth: false,
        notifyUnauthorized: false,
      );
      return StaticPageModel.fromJson(ResponseParser.object(response.body));
    } on AppException {
      rethrow;
    } catch (e, stackTrace) {
      DebugLogger.error('Static page response rejected', e.runtimeType, stackTrace);
      throw ServerException('The page could not be read.', code: 'MALFORMED_RESPONSE');
    }
  }
}
