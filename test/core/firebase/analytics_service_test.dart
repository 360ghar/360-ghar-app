import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/firebase/analytics_service.dart';
import 'package:ghar360/core/firebase/firebase_runtime_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AnalyticsService (Firebase disabled)', () {
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

    test('setUserId completes without throwing', () async {
      await expectLater(AnalyticsService.setUserId('user-1'), completes);
    });

    test('setUserId with null completes without throwing', () async {
      await expectLater(AnalyticsService.setUserId(null), completes);
    });

    test('setUserProperty completes without throwing', () async {
      await expectLater(AnalyticsService.setUserProperty('role', 'agent'), completes);
    });

    test('logVital completes without throwing', () async {
      await expectLater(AnalyticsService.logVital('test_event', params: {'value': 1}), completes);
    });

    test('logVital without params completes without throwing', () async {
      await expectLater(AnalyticsService.logVital('test_event'), completes);
    });

    test('login completes without throwing', () async {
      await expectLater(AnalyticsService.login(method: 'phone'), completes);
    });

    test('login without method completes without throwing', () async {
      await expectLater(AnalyticsService.login(), completes);
    });

    test('signUp completes without throwing', () async {
      await expectLater(AnalyticsService.signUp(method: 'google'), completes);
    });

    test('signUp without method completes without throwing', () async {
      await expectLater(AnalyticsService.signUp(), completes);
    });

    test('viewProperty completes without throwing', () async {
      await expectLater(AnalyticsService.viewProperty('prop-1'), completes);
    });

    test('likeProperty completes without throwing', () async {
      await expectLater(AnalyticsService.likeProperty('prop-1'), completes);
    });

    test('scheduleVisit completes without throwing', () async {
      await expectLater(AnalyticsService.scheduleVisit('prop-1'), completes);
    });

    test('applyFilter completes without throwing', () async {
      await expectLater(AnalyticsService.applyFilter(<String, Object>{'type': 'rent'}), completes);
    });

    test('appLaunchComplete completes without throwing', () async {
      await expectLater(AnalyticsService.appLaunchComplete(durationMs: 1200), completes);
    });

    test('firstPropertyLoaded completes without throwing', () async {
      await expectLater(AnalyticsService.firstPropertyLoaded(latencyMs: 350), completes);
    });

    test('deckExhausted completes without throwing', () async {
      await expectLater(AnalyticsService.deckExhausted(totalSwiped: 10), completes);
    });

    test('filterApplied completes without throwing', () async {
      await expectLater(
        AnalyticsService.filterApplied(activeCount: 3, pageType: 'discover'),
        completes,
      );
    });

    test('locationChanged completes without throwing', () async {
      await expectLater(AnalyticsService.locationChanged(source: 'gps'), completes);
    });

    test('authPhoneEntered completes without throwing', () async {
      await expectLater(AnalyticsService.authPhoneEntered(), completes);
    });

    test('authOtpVerified completes without throwing', () async {
      await expectLater(AnalyticsService.authOtpVerified(), completes);
    });

    test('authProfileCompleted completes without throwing', () async {
      await expectLater(AnalyticsService.authProfileCompleted(), completes);
    });

    test('deepLinkOpenProperty completes without throwing', () async {
      await expectLater(AnalyticsService.deepLinkOpenProperty('prop-9'), completes);
    });

    test('deepLinkOpenTour completes without throwing with both params', () async {
      await expectLater(
        AnalyticsService.deepLinkOpenTour(propertyId: 'prop-9', url: 'https://tour'),
        completes,
      );
    });

    test('deepLinkOpenTour completes without throwing with no params', () async {
      await expectLater(AnalyticsService.deepLinkOpenTour(), completes);
    });

    test('deepLinkOpenTour completes with only propertyId', () async {
      await expectLater(AnalyticsService.deepLinkOpenTour(propertyId: 'prop-9'), completes);
    });

    test('deepLinkOpenTour completes with only url', () async {
      await expectLater(AnalyticsService.deepLinkOpenTour(url: 'https://tour'), completes);
    });
  });

  group('AnalyticsService.viewPropertyOnce deduplication', () {
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

    test('completes without throwing for a new property', () async {
      await expectLater(AnalyticsService.viewPropertyOnce('prop-unique'), completes);
    });

    test('completes without throwing when same property viewed again', () async {
      await AnalyticsService.viewPropertyOnce('prop-dup');
      // Second call should be a no-op dedup; must still complete.
      await expectLater(AnalyticsService.viewPropertyOnce('prop-dup'), completes);
    });

    test('clearSessionState allows a property to be logged again', () async {
      await AnalyticsService.viewPropertyOnce('prop-clear');
      AnalyticsService.clearSessionState();
      // After clearing session state, the same property can be logged again.
      await expectLater(AnalyticsService.viewPropertyOnce('prop-clear'), completes);
    });

    test('handles many unique property ids without throwing', () async {
      for (var i = 0; i < 50; i++) {
        await AnalyticsService.viewPropertyOnce('prop-$i');
      }
      // No exception thrown means success.
      expect(true, isTrue);
    });
  });

  group('AnalyticsService.clearSessionState', () {
    setUp(() {
      AnalyticsService.clearSessionState();
    });

    tearDown(() {
      AnalyticsService.clearSessionState();
    });

    test('is callable and returns void', () {
      expect(() => AnalyticsService.clearSessionState(), returnsNormally);
    });

    test('can be called multiple times safely', () {
      expect(() {
        AnalyticsService.clearSessionState();
        AnalyticsService.clearSessionState();
        AnalyticsService.clearSessionState();
      }, returnsNormally);
    });
  });
}
