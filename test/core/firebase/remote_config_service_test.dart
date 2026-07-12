import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/firebase/firebase_runtime_state.dart';
import 'package:ghar360/core/firebase/remote_config_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RemoteConfigService (Firebase not ready)', () {
    late bool prevEnabled;
    late bool prevReady;

    setUp(() {
      prevEnabled = FirebaseRuntimeState.isEnabled;
      prevReady = FirebaseRuntimeState.isReady;
      FirebaseRuntimeState.isEnabled = false;
      FirebaseRuntimeState.isReady = false;
    });

    tearDown(() {
      FirebaseRuntimeState.isEnabled = prevEnabled;
      FirebaseRuntimeState.isReady = prevReady;
    });

    test('forceFetch returns false when Firebase not ready', () async {
      expect(await RemoteConfigService.forceFetch(), isFalse);
    });

    test('initializeAndFetch is a no-op when Firebase not ready', () async {
      await expectLater(RemoteConfigService.initializeAndFetch(), completes);
    });

    // Feature toggles
    test('analyticsEnabled defaults to false', () {
      expect(RemoteConfigService.analyticsEnabled, isFalse);
    });

    test('performanceEnabled defaults to false', () {
      expect(RemoteConfigService.performanceEnabled, isFalse);
    });

    test('crashlyticsEnabled defaults to true', () {
      expect(RemoteConfigService.crashlyticsEnabled, isTrue);
    });

    test('iamEnabled defaults to false', () {
      expect(RemoteConfigService.iamEnabled, isFalse);
    });

    test('pushEnabled defaults to true', () {
      expect(RemoteConfigService.pushEnabled, isTrue);
    });

    // Sampling ratios
    test('perfHttpSampling defaults to 0.0', () {
      expect(RemoteConfigService.perfHttpSampling, 0.0);
    });

    test('perfTraceSampling defaults to 0.0', () {
      expect(RemoteConfigService.perfTraceSampling, 0.0);
    });

    // Android version management
    test('androidLatestVersion defaults to 1.0.0', () {
      expect(RemoteConfigService.androidLatestVersion, '1.0.0');
    });

    test('androidMinVersion defaults to 1.0.0', () {
      expect(RemoteConfigService.androidMinVersion, '1.0.0');
    });

    test('androidForceUpdate defaults to false', () {
      expect(RemoteConfigService.androidForceUpdate, isFalse);
    });

    test('androidUpdateUrl defaults to Play Store URL', () {
      expect(
        RemoteConfigService.androidUpdateUrl,
        'https://play.google.com/store/apps/details?id=com.ghar360.app',
      );
    });

    test('androidReleaseNotes defaults to empty string', () {
      expect(RemoteConfigService.androidReleaseNotes, '');
    });

    // iOS version management
    test('iosLatestVersion defaults to 1.0.0', () {
      expect(RemoteConfigService.iosLatestVersion, '1.0.0');
    });

    test('iosMinVersion defaults to 1.0.0', () {
      expect(RemoteConfigService.iosMinVersion, '1.0.0');
    });

    test('iosForceUpdate defaults to false', () {
      expect(RemoteConfigService.iosForceUpdate, isFalse);
    });

    test('iosUpdateUrl defaults to App Store URL', () {
      expect(
        RemoteConfigService.iosUpdateUrl,
        'https://apps.apple.com/app/id123456789',
      );
    });

    test('iosReleaseNotes defaults to empty string', () {
      expect(RemoteConfigService.iosReleaseNotes, '');
    });
  });

  group('RemoteConfigService getters are stable across calls', () {
    setUp(() {
      FirebaseRuntimeState.isEnabled = false;
      FirebaseRuntimeState.isReady = false;
    });

    test('repeated reads return the same default value', () {
      final first = RemoteConfigService.androidLatestVersion;
      final second = RemoteConfigService.androidLatestVersion;
      expect(first, second);
      expect(first, '1.0.0');
    });

    test('all bool getters return consistent defaults', () {
      expect(RemoteConfigService.analyticsEnabled, isFalse);
      expect(RemoteConfigService.performanceEnabled, isFalse);
      expect(RemoteConfigService.crashlyticsEnabled, isTrue);
      expect(RemoteConfigService.iamEnabled, isFalse);
      expect(RemoteConfigService.pushEnabled, isTrue);
      expect(RemoteConfigService.androidForceUpdate, isFalse);
      expect(RemoteConfigService.iosForceUpdate, isFalse);
    });

    test('all string getters return non-null defaults', () {
      expect(RemoteConfigService.androidLatestVersion, isNotEmpty);
      expect(RemoteConfigService.androidMinVersion, isNotEmpty);
      expect(RemoteConfigService.androidUpdateUrl, isNotEmpty);
      expect(RemoteConfigService.iosLatestVersion, isNotEmpty);
      expect(RemoteConfigService.iosMinVersion, isNotEmpty);
      expect(RemoteConfigService.iosUpdateUrl, isNotEmpty);
    });
  });
}
