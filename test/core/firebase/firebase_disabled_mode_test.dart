import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/firebase/analytics_service.dart';
import 'package:ghar360/core/firebase/firebase_runtime_state.dart';
import 'package:ghar360/core/firebase/remote_config_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Firebase disabled mode guards', () {
    late bool prevEnabled;
    late bool prevReady;

    setUp(() {
      prevEnabled = FirebaseRuntimeState.isEnabled;
      prevReady = FirebaseRuntimeState.isReady;
      FirebaseRuntimeState.isEnabled = false;
      FirebaseRuntimeState.isReady = false;
      AnalyticsService.clearSessionState();
    });

    tearDown(() {
      FirebaseRuntimeState.isEnabled = prevEnabled;
      FirebaseRuntimeState.isReady = prevReady;
      AnalyticsService.clearSessionState();
    });

    test('RemoteConfig forceFetch and getters are safe defaults when Firebase not ready', () async {
      final fetched = await RemoteConfigService.forceFetch();

      expect(fetched, isFalse);
      expect(RemoteConfigService.analyticsEnabled, isFalse);
      expect(RemoteConfigService.androidLatestVersion, '1.0.0');
      expect(RemoteConfigService.iosForceUpdate, isFalse);
    });

    test('Analytics logVital is a no-op when Firebase not ready', () async {
      await expectLater(
        AnalyticsService.logVital('unit_test_event', params: {'value': 1}),
        completes,
      );
      await expectLater(AnalyticsService.setUserId('user-1'), completes);
    });

    test('RemoteConfig initializeAndFetch is a no-op when not ready', () async {
      await expectLater(RemoteConfigService.initializeAndFetch(), completes);
    });

    test('RemoteConfig all feature-toggle getters return defaults when not ready', () {
      expect(RemoteConfigService.analyticsEnabled, isFalse);
      expect(RemoteConfigService.performanceEnabled, isFalse);
      expect(RemoteConfigService.crashlyticsEnabled, isTrue);
      expect(RemoteConfigService.iamEnabled, isFalse);
      expect(RemoteConfigService.pushEnabled, isTrue);
    });

    test('RemoteConfig sampling getters return 0.0 when not ready', () {
      expect(RemoteConfigService.perfHttpSampling, 0.0);
      expect(RemoteConfigService.perfTraceSampling, 0.0);
    });

    test('RemoteConfig android version getters return defaults when not ready', () {
      expect(RemoteConfigService.androidLatestVersion, '1.0.0');
      expect(RemoteConfigService.androidMinVersion, '1.0.0');
      expect(RemoteConfigService.androidForceUpdate, isFalse);
      expect(RemoteConfigService.androidReleaseNotes, '');
      expect(
        RemoteConfigService.androidUpdateUrl,
        'https://play.google.com/store/apps/details?id=com.ghar360.app',
      );
    });

    test('RemoteConfig ios version getters return defaults when not ready', () {
      expect(RemoteConfigService.iosLatestVersion, '1.0.0');
      expect(RemoteConfigService.iosMinVersion, '1.0.0');
      expect(RemoteConfigService.iosForceUpdate, isFalse);
      expect(RemoteConfigService.iosReleaseNotes, '');
      expect(RemoteConfigService.iosUpdateUrl, 'https://apps.apple.com/app/id123456789');
    });

    test('Analytics all event methods are no-ops when Firebase not ready', () async {
      await expectLater(AnalyticsService.login(method: 'phone'), completes);
      await expectLater(AnalyticsService.signUp(method: 'google'), completes);
      await expectLater(AnalyticsService.viewProperty('p-1'), completes);
      await expectLater(AnalyticsService.likeProperty('p-1'), completes);
      await expectLater(AnalyticsService.scheduleVisit('p-1'), completes);
      await expectLater(
        AnalyticsService.applyFilter(<String, Object>{'type': 'rent'}),
        completes,
      );
      await expectLater(
        AnalyticsService.filterApplied(activeCount: 2, pageType: 'discover'),
        completes,
      );
      await expectLater(AnalyticsService.locationChanged(source: 'gps'), completes);
    });

    test('Analytics viewPropertyOnce dedup is a no-op when Firebase not ready', () async {
      // Even with dedup, both calls complete because Firebase is disabled.
      await expectLater(AnalyticsService.viewPropertyOnce('p-dup'), completes);
      await expectLater(AnalyticsService.viewPropertyOnce('p-dup'), completes);
    });

    test('Analytics clearSessionState is safe when Firebase not ready', () {
      expect(() => AnalyticsService.clearSessionState(), returnsNormally);
    });

    test('Analytics setUserProperty is a no-op when Firebase not ready', () async {
      await expectLater(
        AnalyticsService.setUserProperty('role', 'agent'),
        completes,
      );
    });

    test('Analytics setUserId with null is a no-op when Firebase not ready', () async {
      await expectLater(AnalyticsService.setUserId(null), completes);
    });

    test('RemoteConfig forceFetch returns false even when enabled but not ready', () async {
      FirebaseRuntimeState.isEnabled = true;
      FirebaseRuntimeState.isReady = false;
      expect(await RemoteConfigService.forceFetch(), isFalse);
    });
  });
}

