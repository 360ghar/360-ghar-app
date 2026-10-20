import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/data/models/app_update_models.dart';
import 'package:ghar360/core/data/models/wire_enums.dart';

void main() {
  group('AppVersionCheckRequest', () {
    test('toJson sends app and platform as enum values and the build number as an integer', () {
      const request = AppVersionCheckRequest(
        app: AppKey.ghar,
        platform: DevicePlatform.ios,
        currentVersion: '1.2.3',
        buildNumber: 10,
      );

      expect(request.toJson(), {
        'app': 'ghar',
        'platform': 'ios',
        'current_version': '1.2.3',
        'build_number': 10,
      });
    });

    test('toJson leaves out an unknown build number', () {
      const request = AppVersionCheckRequest(
        app: AppKey.ghar,
        platform: DevicePlatform.android,
        currentVersion: '2.0.0',
      );

      expect(request.toJson().containsKey('build_number'), isFalse);
    });

    test('the retired app value ghar360 is not an AppKey', () {
      expect(AppKey.fromJson('ghar360'), isNull);
      expect(AppKey.fromJson('ghar'), AppKey.ghar);
    });

    test('current_version is 1 to 20 characters', () {
      const empty = AppVersionCheckRequest(
        app: AppKey.ghar,
        platform: DevicePlatform.ios,
        currentVersion: '  ',
      );
      final long = AppVersionCheckRequest(
        app: AppKey.ghar,
        platform: DevicePlatform.ios,
        currentVersion: '1' * 21,
      );

      expect(empty.toJson, throwsFormatException);
      expect(long.toJson, throwsFormatException);
    });
  });

  group('AppVersionCheckResponse', () {
    test('fromJson parses full JSON', () {
      final json = <String, dynamic>{
        'update_available': true,
        'is_mandatory': false,
        'latest_version': '2.0.0',
        'download_url': 'https://example.com/download',
        'release_notes': 'Bug fixes and improvements',
        'min_supported_version': '1.0.0',
      };

      final response = AppVersionCheckResponse.fromJson(json);

      expect(response.updateAvailable, true);
      expect(response.isMandatory, false);
      expect(response.latestVersion, '2.0.0');
      expect(response.downloadUrl, 'https://example.com/download');
      expect(response.releaseNotes, 'Bug fixes and improvements');
      expect(response.minSupportedVersion, '1.0.0');
    });

    test('fromJson handles null optional fields', () {
      final json = <String, dynamic>{'update_available': false, 'is_mandatory': false};

      final response = AppVersionCheckResponse.fromJson(json);

      expect(response.updateAvailable, false);
      expect(response.isMandatory, false);
      expect(response.latestVersion, isNull);
      expect(response.downloadUrl, isNull);
      expect(response.releaseNotes, isNull);
      expect(response.minSupportedVersion, isNull);
    });

    test('toJson renames fields to snake_case', () {
      const response = AppVersionCheckResponse(
        updateAvailable: true,
        isMandatory: true,
        latestVersion: '2.0.0',
        downloadUrl: 'https://example.com/download',
        releaseNotes: 'Notes',
        minSupportedVersion: '1.0.0',
      );

      final json = response.toJson();

      expect(json['update_available'], true);
      expect(json['is_mandatory'], true);
      expect(json['latest_version'], '2.0.0');
      expect(json['download_url'], 'https://example.com/download');
      expect(json['release_notes'], 'Notes');
      expect(json['min_supported_version'], '1.0.0');
    });

    test('toJson roundtrip preserves all fields', () {
      const original = AppVersionCheckResponse(
        updateAvailable: true,
        isMandatory: false,
        latestVersion: '2.0.0',
        downloadUrl: 'https://example.com/download',
        releaseNotes: 'Notes',
        minSupportedVersion: '1.0.0',
      );

      final json = original.toJson();
      final restored = AppVersionCheckResponse.fromJson(json);

      expect(restored.updateAvailable, original.updateAvailable);
      expect(restored.isMandatory, original.isMandatory);
      expect(restored.latestVersion, original.latestVersion);
      expect(restored.downloadUrl, original.downloadUrl);
      expect(restored.releaseNotes, original.releaseNotes);
      expect(restored.minSupportedVersion, original.minSupportedVersion);
    });

    test('hasDownloadUrl is true when downloadUrl is non-empty', () {
      expect(
        const AppVersionCheckResponse(
          updateAvailable: true,
          isMandatory: false,
          downloadUrl: 'https://example.com/download',
        ).hasDownloadUrl,
        true,
      );
    });

    test('hasDownloadUrl is false when downloadUrl is null', () {
      expect(
        const AppVersionCheckResponse(updateAvailable: true, isMandatory: false).hasDownloadUrl,
        false,
      );
    });

    test('hasDownloadUrl is false when downloadUrl is empty', () {
      expect(
        const AppVersionCheckResponse(
          updateAvailable: true,
          isMandatory: false,
          downloadUrl: '',
        ).hasDownloadUrl,
        false,
      );
    });

    test('copyWith updates only specified fields', () {
      const original = AppVersionCheckResponse(
        updateAvailable: false,
        isMandatory: false,
        latestVersion: '1.0.0',
      );

      final copy = original.copyWith(updateAvailable: true, downloadUrl: 'https://example.com/dl');

      expect(copy.updateAvailable, true);
      expect(copy.downloadUrl, 'https://example.com/dl');
      expect(copy.isMandatory, original.isMandatory, reason: 'unmodified preserved');
      expect(copy.latestVersion, original.latestVersion, reason: 'unmodified preserved');
      expect(copy.releaseNotes, original.releaseNotes);
      expect(copy.minSupportedVersion, original.minSupportedVersion);
    });
  });

  group('AppVersionInfo', () {
    test('fromJson parses version and buildNumber', () {
      final json = <String, dynamic>{'version': '1.2.3', 'build_number': 45};

      final info = AppVersionInfo.fromJson(json);

      expect(info.version, '1.2.3');
      expect(info.buildNumber, 45);
    });

    test('fromJson handles null buildNumber', () {
      final info = AppVersionInfo.fromJson({'version': '2.0.0'});

      expect(info.version, '2.0.0');
      expect(info.buildNumber, isNull);
    });

    test('toJson renames buildNumber to snake_case', () {
      const info = AppVersionInfo(version: '1.2.3', buildNumber: 45);

      final json = info.toJson();

      expect(json['version'], '1.2.3');
      expect(json['build_number'], 45);
    });

    test('toJson roundtrip preserves all fields', () {
      const original = AppVersionInfo(version: '3.0.0', buildNumber: 100);

      final json = original.toJson();
      final restored = AppVersionInfo.fromJson(json);

      expect(restored.version, original.version);
      expect(restored.buildNumber, original.buildNumber);
    });
  });
}
