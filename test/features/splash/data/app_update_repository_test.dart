// Unit tests for [AppUpdateRepository]: the body of `POST /versions/check`, the typed answer and
// the failures that must never read as "no update".

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/data/models/app_update_models.dart';
import 'package:ghar360/core/data/models/wire_enums.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/splash/data/app_update_repository.dart';
import '../../../contract/contract_support.dart';

void main() {
  Map<String, dynamic> answer({
    bool update = true,
    bool mandatory = false,
    String? latest = '3.3.0',
    String? url = 'https://example.com/app',
  }) => {
    'update_available': update,
    'is_mandatory': mandatory,
    'latest_version': latest,
    'download_url': url,
    'release_notes': null,
    'min_supported_version': null,
  };

  const request = AppVersionCheckRequest(
    app: AppKey.ghar,
    platform: DevicePlatform.ios,
    currentVersion: '1.2.3',
    buildNumber: 45,
  );

  test(
    'POST /versions/check sends app, platform, current_version and an integer build_number',
    () async {
      final api = RecordingApi((_) => jsonResponse(answer()));

      await AppUpdateRepository(apiClient: api.client).checkForUpdates(request);

      expect(api.calls, hasLength(1));
      expect(api.calls.single.method, 'POST');
      expect(api.calls.single.path, '/api/v1/versions/check');
      expect(api.calls.single.body, {
        'app': 'ghar',
        'platform': 'ios',
        'current_version': '1.2.3',
        'build_number': 45,
      });
      expect((api.calls.single.body as Map)['build_number'], isA<int>());
    },
  );

  test('an unknown build number is left out, never sent as a string or zero', () async {
    final api = RecordingApi((_) => jsonResponse(answer(update: false)));

    await AppUpdateRepository(apiClient: api.client).checkForUpdates(
      const AppVersionCheckRequest(
        app: AppKey.ghar,
        platform: DevicePlatform.android,
        currentVersion: '1.2.3',
      ),
    );

    expect(api.calls.single.body, {
      'app': 'ghar',
      'platform': 'android',
      'current_version': '1.2.3',
    });
  });

  test('the server decides: update_available, is_mandatory and the version policy', () async {
    final api = RecordingApi((_) => jsonResponse(answer(mandatory: true)));

    final result = await AppUpdateRepository(apiClient: api.client).checkForUpdates(request);

    expect(result.updateAvailable, isTrue);
    expect(result.isMandatory, isTrue);
    expect(result.latestVersion, '3.3.0');
    expect(result.downloadUrl, 'https://example.com/app');
  });

  test('a release row without a download_url opens the store listing of the platform', () async {
    final api = RecordingApi((_) => jsonResponse(answer(url: null)));
    final repository = AppUpdateRepository(apiClient: api.client);

    final ios = await repository.checkForUpdates(request);
    final android = await repository.checkForUpdates(
      const AppVersionCheckRequest(
        app: AppKey.ghar,
        platform: DevicePlatform.android,
        currentVersion: '1.2.3',
      ),
    );

    expect(ios.downloadUrl, AppUpdateRepository.storeUrls[DevicePlatform.ios]);
    expect(android.downloadUrl, AppUpdateRepository.storeUrls[DevicePlatform.android]);
  });

  test('no update leaves the answer as sent', () async {
    final api = RecordingApi((_) => jsonResponse(answer(update: false, latest: null, url: null)));

    final result = await AppUpdateRepository(apiClient: api.client).checkForUpdates(request);

    expect(result.updateAvailable, isFalse);
    expect(result.downloadUrl, isNull);
  });

  test('a version name over 20 characters is refused before any request', () async {
    final api = RecordingApi((_) => jsonResponse(answer()));

    await expectLater(
      AppUpdateRepository(apiClient: api.client).checkForUpdates(
        const AppVersionCheckRequest(
          app: AppKey.ghar,
          platform: DevicePlatform.ios,
          currentVersion: '1.2.3-beta.1234567890abcdef',
        ),
      ),
      throwsFormatException,
    );
    expect(api.calls, isEmpty);
  });

  test('a rejected request stays a failure instead of reading as no update', () async {
    final api = RecordingApi(
      (_) => jsonResponse({
        'error': {
          'code': 'VALIDATION_ERROR',
          'message': 'Request validation failed',
          'details': {
            'fields': [
              {'field': 'body.app', 'msg': 'bad', 'type': 'enum'},
            ],
          },
        },
      }, status: 422),
    );

    await expectLater(
      AppUpdateRepository(apiClient: api.client).checkForUpdates(request),
      throwsA(isA<ValidationException>()),
    );
  });

  test('a body without update_available is a malformed response', () async {
    final api = RecordingApi((_) => jsonResponse({'latest_version': '3.3.0'}));

    await expectLater(
      AppUpdateRepository(apiClient: api.client).checkForUpdates(request),
      throwsA(isA<ServerException>().having((e) => e.code, 'code', 'MALFORMED_RESPONSE')),
    );
  });
}
