import 'package:ghar360/core/data/models/app_update_models.dart';
import 'package:ghar360/core/data/models/wire_enums.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/network/api_paths.dart';
import 'package:ghar360/core/network/response_parser.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/utils/debug_logger.dart';

/// The app update check: `POST /versions/check` (`AppVersionCheckRequest`). The backend
/// `app_versions` table is the only source of release data. The server compares the versions and
/// decides `update_available` and `is_mandatory`; the client does not compare them.
class AppUpdateRepository {
  const AppUpdateRepository({required this._apiClient});

  final ApiClient _apiClient;

  /// The store listing of this app, used when the matching `app_versions` row has no
  /// `download_url`.
  static const storeUrls = {
    DevicePlatform.android: 'https://play.google.com/store/apps/details?id=com.the360ghar.ghar360',
    DevicePlatform.ios: 'https://apps.apple.com/app/id6794866216',
  };

  /// A failed request stays a failure: it is never read as "no update". The route is public and
  /// a pure read, so one retry of a transient failure is safe.
  Future<AppVersionCheckResponse> checkForUpdates(AppVersionCheckRequest request) async {
    final response = await _apiClient.post(
      ApiPaths.versionsCheck,
      body: request.toJson(),
      idempotent: true,
      requireAuth: false,
    );
    final AppVersionCheckResponse check;
    try {
      check = AppVersionCheckResponse.fromJson(ResponseParser.object(response.body));
    } catch (error, stack) {
      DebugLogger.error('Version check response rejected', error.runtimeType, stack);
      throw ServerException(
        'The service returned an invalid version response.',
        code: 'MALFORMED_RESPONSE',
      );
    }
    if (check.updateAvailable && !check.hasDownloadUrl) {
      return check.copyWith(downloadUrl: storeUrls[request.platform]);
    }
    return check;
  }
}
