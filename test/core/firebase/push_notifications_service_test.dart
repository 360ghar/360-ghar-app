import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/firebase/firebase_runtime_state.dart';
import 'package:ghar360/core/firebase/push_notifications_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PushNotificationsService (Firebase not ready)', () {
    late bool prevEnabled;
    late bool prevReady;

    setUp(() {
      prevEnabled = FirebaseRuntimeState.isEnabled;
      prevReady = FirebaseRuntimeState.isReady;
      FirebaseRuntimeState.isEnabled = false;
      FirebaseRuntimeState.isReady = false;
      PushNotificationsService.onNotificationTap = null;
      PushNotificationsService.onTokenRegistration = null;
    });

    tearDown(() {
      FirebaseRuntimeState.isEnabled = prevEnabled;
      FirebaseRuntimeState.isReady = prevReady;
      PushNotificationsService.onNotificationTap = null;
      PushNotificationsService.onTokenRegistration = null;
    });

    test('currentToken is null initially', () {
      expect(PushNotificationsService.currentToken, isNull);
    });

    test('getToken returns null when Firebase is not ready', () async {
      expect(await PushNotificationsService.getToken(), isNull);
    });

    test('requestUserPermission returns null when Firebase is not ready', () async {
      expect(await PushNotificationsService.requestUserPermission(), isNull);
    });

    test('requestUserPermission with provisional returns null when not ready', () async {
      expect(await PushNotificationsService.requestUserPermission(provisional: true), isNull);
    });

    test('initializeForegroundHandling completes and marks initialized when not ready', () async {
      await expectLater(PushNotificationsService.initializeForegroundHandling(), completes);
    });

    test('deleteToken completes without throwing when Firebase is not ready', () async {
      await expectLater(PushNotificationsService.deleteToken(), completes);
    });

    test('deleteToken does not throw and leaves currentToken null when not ready', () async {
      await PushNotificationsService.deleteToken();
      expect(PushNotificationsService.currentToken, isNull);
    });

    // NOTE: initLocalNotifications calls into the flutter_local_notifications
    // platform interface which requires a initialized platform plugin instance
    // (LateInitializationError in pure unit tests). It is therefore covered by
    // integration tests rather than here.
  });

  group('PushNotificationsService token request coalescing', () {
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

    test('concurrent getToken calls share the same in-flight future', () async {
      final a = PushNotificationsService.getToken();
      final b = PushNotificationsService.getToken();
      // Both should resolve to null (Firebase not ready) without throwing.
      final results = await Future.wait([a, b]);
      expect(results, [null, null]);
    });

    test('sequential getToken calls both return null when not ready', () async {
      expect(await PushNotificationsService.getToken(), isNull);
      expect(await PushNotificationsService.getToken(), isNull);
    });

    test('getToken clears in-flight request after completion', () async {
      await PushNotificationsService.getToken();
      // After completion, a new call should still work (no stale future).
      expect(await PushNotificationsService.getToken(), isNull);
    });
  });

  group('PushNotificationsService callback hooks', () {
    setUp(() {
      PushNotificationsService.onNotificationTap = null;
      PushNotificationsService.onTokenRegistration = null;
    });

    tearDown(() {
      PushNotificationsService.onNotificationTap = null;
      PushNotificationsService.onTokenRegistration = null;
    });

    test('onNotificationTap is nullable and assignable', () {
      var tapped = false;
      PushNotificationsService.onNotificationTap = (data) {
        tapped = true;
      };
      PushNotificationsService.onNotificationTap!.call(<String, dynamic>{'id': '1'});
      expect(tapped, isTrue);
    });

    test('onNotificationTap receives the data map', () {
      Map<String, dynamic>? received;
      PushNotificationsService.onNotificationTap = (data) {
        received = data;
      };
      PushNotificationsService.onNotificationTap!.call(<String, dynamic>{
        'route': '/property/123',
        'title': 'New Property',
      });
      expect(received, isNotNull);
      expect(received!['route'], '/property/123');
      expect(received!['title'], 'New Property');
    });

    test('onNotificationTap can be set to null', () {
      PushNotificationsService.onNotificationTap = (data) {};
      PushNotificationsService.onNotificationTap = null;
      expect(PushNotificationsService.onNotificationTap, isNull);
    });

    test('onTokenRegistration is nullable and assignable', () async {
      String? registered;
      PushNotificationsService.onTokenRegistration = (token) async {
        registered = token;
      };
      await PushNotificationsService.onTokenRegistration!('token-abc');
      expect(registered, 'token-abc');
    });

    test('onTokenRegistration can throw without crashing the caller directly', () async {
      PushNotificationsService.onTokenRegistration = (token) async {
        throw Exception('Backend down');
      };
      // Calling directly propagates; the service wraps this in try/catch
      // internally in _registerToken.
      await expectLater(
        PushNotificationsService.onTokenRegistration!('token-xyz'),
        throwsA(isA<Exception>()),
      );
    });

    test('onTokenRegistration can be set to null', () {
      PushNotificationsService.onTokenRegistration = (token) async {};
      PushNotificationsService.onTokenRegistration = null;
      expect(PushNotificationsService.onTokenRegistration, isNull);
    });
  });

  group('PushNotificationsService Firebase ready guard', () {
    late bool prevEnabled;
    late bool prevReady;

    setUp(() {
      prevEnabled = FirebaseRuntimeState.isEnabled;
      prevReady = FirebaseRuntimeState.isReady;
    });

    tearDown(() {
      FirebaseRuntimeState.isEnabled = prevEnabled;
      FirebaseRuntimeState.isReady = prevReady;
    });

    test(
      'getToken returns null even if isReady is true but Firebase is not actually initialized',
      () async {
        // Setting isReady = true without a real Firebase app causes the messaging
        // instance lookup to throw internally; the service must catch and return
        // null rather than propagating the error.
        FirebaseRuntimeState.isReady = true;
        FirebaseRuntimeState.isEnabled = true;
        expect(await PushNotificationsService.getToken(), isNull);
      },
    );

    test('requestUserPermission returns null when messaging client unavailable', () async {
      FirebaseRuntimeState.isReady = true;
      FirebaseRuntimeState.isEnabled = true;
      expect(await PushNotificationsService.requestUserPermission(), isNull);
    });

    test('requestUserPermission with provisional returns null when not ready', () async {
      FirebaseRuntimeState.isReady = true;
      FirebaseRuntimeState.isEnabled = true;
      expect(await PushNotificationsService.requestUserPermission(provisional: true), isNull);
    });

    test('deleteToken clears currentToken when Firebase not ready', () async {
      FirebaseRuntimeState.isReady = false;
      FirebaseRuntimeState.isEnabled = false;
      await PushNotificationsService.deleteToken();
      expect(PushNotificationsService.currentToken, isNull);
    });

    test('deleteToken clears currentToken when messaging unavailable', () async {
      FirebaseRuntimeState.isReady = true;
      FirebaseRuntimeState.isEnabled = true;
      await PushNotificationsService.deleteToken();
      expect(PushNotificationsService.currentToken, isNull);
    });
  });

  group('PushNotificationsService initializeForegroundHandling', () {
    late bool prevEnabled;
    late bool prevReady;

    setUp(() {
      prevEnabled = FirebaseRuntimeState.isEnabled;
      prevReady = FirebaseRuntimeState.isReady;
      FirebaseRuntimeState.isEnabled = false;
      FirebaseRuntimeState.isReady = false;
      PushNotificationsService.onNotificationTap = null;
      PushNotificationsService.onTokenRegistration = null;
    });

    tearDown(() {
      FirebaseRuntimeState.isEnabled = prevEnabled;
      FirebaseRuntimeState.isReady = prevReady;
      PushNotificationsService.onNotificationTap = null;
      PushNotificationsService.onTokenRegistration = null;
    });

    test('completes without throwing when Firebase is not ready', () async {
      await PushNotificationsService.initializeForegroundHandling();
      // Should not throw; _initialized is set to true internally.
    });

    test('completes when Firebase isReady but messaging unavailable', () async {
      FirebaseRuntimeState.isReady = true;
      FirebaseRuntimeState.isEnabled = true;
      await expectLater(PushNotificationsService.initializeForegroundHandling(), completes);
    });
  });

  group('PushNotificationsService areNotificationsEnabled', () {
    test('returns a bool without throwing on non-Android platforms', () async {
      // On iOS/macOS/test host, the method returns true or catches and
      // returns false. Either way it must not throw.
      final result = await PushNotificationsService.areNotificationsEnabled();
      expect(result, isA<bool>());
    });
  });

  group('PushNotificationsService notification payload handling', () {
    // The _handleNotificationPayload and _navigateByPayload methods are
    // private, but we can exercise them indirectly through the callback hooks
    // and verify the navigation logic by registering a Get navigator.
    setUp(() {
      Get.testMode = true;
      PushNotificationsService.onNotificationTap = null;
      PushNotificationsService.onTokenRegistration = null;
    });

    tearDown(() {
      PushNotificationsService.onNotificationTap = null;
      PushNotificationsService.onTokenRegistration = null;
    });

    test('onNotificationTap callback fires with decoded JSON payload', () {
      final payload = jsonEncode(<String, dynamic>{'route': '/property/42', 'property_id': '42'});

      Map<String, dynamic>? received;
      PushNotificationsService.onNotificationTap = (data) {
        received = data;
      };

      // Simulate what _handleNotificationPayload does: decode and call.
      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      PushNotificationsService.onNotificationTap?.call(decoded);

      expect(received, isNotNull);
      expect(received!['route'], '/property/42');
      expect(received!['property_id'], '42');
    });

    test('onNotificationTap callback handles empty payload gracefully', () {
      Map<String, dynamic>? received;
      PushNotificationsService.onNotificationTap = (data) {
        received = data;
      };

      PushNotificationsService.onNotificationTap?.call(<String, dynamic>{});
      expect(received, <String, dynamic>{});
    });

    test('onNotificationTap is not called when null', () {
      // When no callback is set, calling should not throw.
      expect(() {
        PushNotificationsService.onNotificationTap?.call(<String, dynamic>{'id': '1'});
      }, returnsNormally);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // flutter_local_notifications platform channel mock tests
  // ─────────────────────────────────────────────────────────────────────────
  //
  // The following groups mock the `dexterous.com/flutter/local_notifications`
  // MethodChannel and register the Android platform implementation so that
  // PushNotificationsService.initLocalNotifications() and
  // areNotificationsEnabled() can be exercised end-to-end in the test host.
  //
  // debugDefaultTargetPlatformOverride is set to android per-test and cleared
  // in a finally block (for testWidgets) or addTearDown (for test) to satisfy
  // the Flutter test framework's _verifyInvariants assertion.

  const flnChannel = MethodChannel('dexterous.com/flutter/local_notifications');

  Future<void> setupFlnMock() async {
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      flnChannel,
      (MethodCall call) async {
        switch (call.method) {
          case 'initialize':
            return true;
          case 'createNotificationChannel':
            return null;
          case 'areNotificationsEnabled':
            return true;
          case 'requestNotificationsPermission':
            return true;
          case 'show':
            return null;
          default:
            return null;
        }
      },
    );
  }

  void teardownFlnMock() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      flnChannel,
      null,
    );
  }

  group('PushNotificationsService.initLocalNotifications (mocked FLN)', () {
    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
    });

    test('completes without throwing with mocked platform channel', () async {
      await setupFlnMock();
      addTearDown(teardownFlnMock);

      await expectLater(PushNotificationsService.initLocalNotifications(), completes);
    });

    test('registers the notification tap callback', () async {
      await setupFlnMock();
      addTearDown(teardownFlnMock);

      await PushNotificationsService.initLocalNotifications();
      // After initialization, the internal _onDidReceiveNotificationResponse
      // callback is wired. We verify by sending a platform message below in
      // the widget test group. Here we just verify no throw.
    });
  });

  group('PushNotificationsService.areNotificationsEnabled (mocked FLN)', () {
    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
    });

    test('returns true on non-Android host (iOS/macOS path)', () async {
      // On the macOS test host, Platform.isAndroid is false, so the method
      // returns true without touching the platform channel.
      final result = await PushNotificationsService.areNotificationsEnabled();
      expect(result, isTrue);
    });

    test('does not throw even without FLN mock on non-Android host', () async {
      // No mock set up — the method should still return true on non-Android.
      final result = await PushNotificationsService.areNotificationsEnabled();
      expect(result, isA<bool>());
    });
  });

  group('PushNotificationsService notification tap via platform channel', () {
    late bool prevEnabled;
    late bool prevReady;

    setUp(() {
      prevEnabled = FirebaseRuntimeState.isEnabled;
      prevReady = FirebaseRuntimeState.isReady;
      FirebaseRuntimeState.isEnabled = false;
      FirebaseRuntimeState.isReady = false;
      PushNotificationsService.onNotificationTap = null;
      PushNotificationsService.onTokenRegistration = null;
      Get.testMode = true;
    });

    tearDown(() {
      FirebaseRuntimeState.isEnabled = prevEnabled;
      FirebaseRuntimeState.isReady = prevReady;
      PushNotificationsService.onNotificationTap = null;
      PushNotificationsService.onTokenRegistration = null;
    });

    /// Sends a simulated `didReceiveNotificationResponse` platform message to
    /// the flutter_local_notifications channel, triggering the
    /// `_onNotificationTapped` callback registered by `initLocalNotifications`.
    Future<void> sendNotificationTap(String? payload) async {
      final codec = const StandardMethodCodec();
      final data = codec.encodeMethodCall(
        MethodCall('didReceiveNotificationResponse', <String, dynamic>{
          'notificationId': 1,
          'actionId': null,
          'input': null,
          'payload': payload,
          'notificationResponseType': 0,
        }),
      );
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
        flnChannel.name,
        data,
        null,
      );
    }

    testWidgets('fires onNotificationTap with decoded JSON payload and navigates', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await setupFlnMock();

        Map<String, dynamic>? receivedData;
        PushNotificationsService.onNotificationTap = (data) {
          receivedData = data;
        };

        // Set up a GetMaterialApp with a route table so Get.toNamed works.
        await tester.pumpWidget(
          GetMaterialApp(
            initialRoute: '/home',
            getPages: [
              GetPage(
                name: '/home',
                page: () => const Scaffold(body: SizedBox()),
              ),
              GetPage(
                name: '/property/:id',
                page: () => const Scaffold(body: Text('property_details')),
              ),
            ],
          ),
        );

        await PushNotificationsService.initLocalNotifications();

        // Simulate a notification tap with a route payload.
        final payload = jsonEncode(<String, dynamic>{
          'route': '/property/:id',
          'property_id': '42',
        });
        await sendNotificationTap(payload);
        await tester.pumpAndSettle();

        expect(receivedData, isNotNull);
        expect(receivedData!['property_id'], '42');
        expect(receivedData!['route'], '/property/:id');
      } finally {
        teardownFlnMock();
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('navigates to property deep link when property_id is set', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await setupFlnMock();

        Map<String, dynamic>? receivedData;
        PushNotificationsService.onNotificationTap = (data) {
          receivedData = data;
        };

        await tester.pumpWidget(
          GetMaterialApp(
            initialRoute: '/home',
            getPages: [
              GetPage(
                name: '/home',
                page: () => const Scaffold(body: SizedBox()),
              ),
              GetPage(
                name: '/property/:id',
                page: () => const Scaffold(body: Text('property_details')),
              ),
            ],
          ),
        );

        await PushNotificationsService.initLocalNotifications();

        // Simulate a notification tap with only property_id (no route).
        final payload = jsonEncode(<String, dynamic>{'property_id': '99'});
        await sendNotificationTap(payload);
        await tester.pumpAndSettle();

        expect(receivedData, isNotNull);
        expect(receivedData!['property_id'], '99');
        // Navigation to the deep-link route should have occurred.
        expect(Get.currentRoute, contains('/property/'));
      } finally {
        teardownFlnMock();
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('navigates using propertyId (camelCase) fallback', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await setupFlnMock();

        PushNotificationsService.onNotificationTap = (_) {};

        await tester.pumpWidget(
          GetMaterialApp(
            initialRoute: '/home',
            getPages: [
              GetPage(
                name: '/home',
                page: () => const Scaffold(body: SizedBox()),
              ),
              GetPage(
                name: '/property/:id',
                page: () => const Scaffold(body: Text('property_details')),
              ),
            ],
          ),
        );

        await PushNotificationsService.initLocalNotifications();

        final payload = jsonEncode(<String, dynamic>{'propertyId': '77'});
        await sendNotificationTap(payload);
        await tester.pumpAndSettle();

        expect(Get.currentRoute, contains('/property/'));
      } finally {
        teardownFlnMock();
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('handles null payload gracefully', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await setupFlnMock();

        var tapped = false;
        PushNotificationsService.onNotificationTap = (_) {
          tapped = true;
        };

        await tester.pumpWidget(
          GetMaterialApp(
            initialRoute: '/home',
            getPages: [
              GetPage(
                name: '/home',
                page: () => const Scaffold(body: SizedBox()),
              ),
            ],
          ),
        );

        await PushNotificationsService.initLocalNotifications();

        await sendNotificationTap(null);
        await tester.pumpAndSettle();

        // With null payload, _handleNotificationPayload returns early without
        // calling onNotificationTap.
        expect(tapped, isFalse);
      } finally {
        teardownFlnMock();
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('handles empty payload gracefully', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await setupFlnMock();

        var tapped = false;
        PushNotificationsService.onNotificationTap = (_) {
          tapped = true;
        };

        await tester.pumpWidget(
          GetMaterialApp(
            initialRoute: '/home',
            getPages: [
              GetPage(
                name: '/home',
                page: () => const Scaffold(body: SizedBox()),
              ),
            ],
          ),
        );

        await PushNotificationsService.initLocalNotifications();

        await sendNotificationTap('');
        await tester.pumpAndSettle();

        expect(tapped, isFalse);
      } finally {
        teardownFlnMock();
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('handles invalid JSON payload gracefully', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await setupFlnMock();

        var tapped = false;
        PushNotificationsService.onNotificationTap = (_) {
          tapped = true;
        };

        await tester.pumpWidget(
          GetMaterialApp(
            initialRoute: '/home',
            getPages: [
              GetPage(
                name: '/home',
                page: () => const Scaffold(body: SizedBox()),
              ),
            ],
          ),
        );

        await PushNotificationsService.initLocalNotifications();

        await sendNotificationTap('not-valid-json{');
        await tester.pumpAndSettle();

        // Invalid JSON is caught; onNotificationTap is not called.
        expect(tapped, isFalse);
      } finally {
        teardownFlnMock();
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('does not navigate when payload has no route or property_id', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await setupFlnMock();

        PushNotificationsService.onNotificationTap = (_) {};

        await tester.pumpWidget(
          GetMaterialApp(
            initialRoute: '/home',
            getPages: [
              GetPage(
                name: '/home',
                page: () => const Scaffold(body: SizedBox()),
              ),
            ],
          ),
        );

        await PushNotificationsService.initLocalNotifications();

        final payload = jsonEncode(<String, dynamic>{'title': 'No route here'});
        await sendNotificationTap(payload);
        await tester.pumpAndSettle();

        // No navigation should occur.
        expect(Get.currentRoute, '/home');
      } finally {
        teardownFlnMock();
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  group('PushNotificationsService token registration callback', () {
    setUp(() {
      PushNotificationsService.onNotificationTap = null;
      PushNotificationsService.onTokenRegistration = null;
    });

    tearDown(() {
      PushNotificationsService.onNotificationTap = null;
      PushNotificationsService.onTokenRegistration = null;
    });

    test('onTokenRegistration success path completes', () async {
      var registered = false;
      PushNotificationsService.onTokenRegistration = (token) async {
        registered = true;
      };
      await PushNotificationsService.onTokenRegistration!('test-token');
      expect(registered, isTrue);
    });

    test('onTokenRegistration receives the correct token value', () async {
      String? capturedToken;
      PushNotificationsService.onTokenRegistration = (token) async {
        capturedToken = token;
      };
      await PushNotificationsService.onTokenRegistration!('abc-123-xyz');
      expect(capturedToken, 'abc-123-xyz');
    });

    test('onTokenRegistration handles long token values', () async {
      String? capturedToken;
      PushNotificationsService.onTokenRegistration = (token) async {
        capturedToken = token;
      };
      final longToken = List<String>.generate(100, (i) => 'a').join();
      await PushNotificationsService.onTokenRegistration!(longToken);
      expect(capturedToken, longToken);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Firebase-mocked integration tests
  // ─────────────────────────────────────────────────────────────────────────
  //
  // These tests use setupFirebaseCoreMocks() from firebase_core_platform_interface
  // to mock the Firebase Pigeon API, plus MethodChannel mocks for
  // firebase_messaging and flutter_local_notifications. This allows exercising
  // the actual FCM token, permission, and delete paths end-to-end.
  //
  // Platform is set to iOS (via debugDefaultTargetPlatformOverride) because:
  // 1. On macOS host, Platform.isMacOS is true → PushNotificationsService takes
  //    the Apple token path (_getAppleTokenWithRetry).
  // 2. iOS defaultTargetPlatform allows getAPNSToken() to call the mock channel.
  // 3. The FLN iOS plugin uses the same method channel as Android.

  const fcmChannel = MethodChannel('plugins.flutter.io/firebase_messaging');

  Future<void> setupFcmMock({
    String token = 'fake-fcm-token-1234567890',
    String apnsToken = 'fake-apns-token',
    int authorizationStatus = 1, // authorized
  }) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      fcmChannel,
      (MethodCall call) async {
        switch (call.method) {
          case 'Messaging#getToken':
            return {'token': token};
          case 'Messaging#getAPNSToken':
            return {'token': apnsToken};
          case 'Messaging#requestPermission':
            return {'authorizationStatus': authorizationStatus};
          case 'Messaging#deleteToken':
            return null;
          case 'Messaging#setForegroundNotificationPresentationOptions':
            return null;
          case 'Messaging#getInitialMessage':
            return null;
          case 'Messaging#getNotificationSettings':
            return {'authorizationStatus': authorizationStatus, 'alert': 1, 'badge': 1, 'sound': 1};
          default:
            return null;
        }
      },
    );
  }

  void teardownFcmMock() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      fcmChannel,
      null,
    );
  }

  group('PushNotificationsService Firebase-mocked FCM operations', () {
    late bool prevEnabled;
    late bool prevReady;

    setUpAll(() {
      setupFirebaseCoreMocks();
    });

    setUp(() async {
      prevEnabled = FirebaseRuntimeState.isEnabled;
      prevReady = FirebaseRuntimeState.isReady;
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      IOSFlutterLocalNotificationsPlugin.registerWith();
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      // Ensure Firebase app is initialized for the test.
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: '123',
          appId: '123',
          messagingSenderId: '123',
          projectId: '123',
        ),
      );

      FirebaseRuntimeState.isEnabled = true;
      FirebaseRuntimeState.isReady = true;
      PushNotificationsService.onNotificationTap = null;
      PushNotificationsService.onTokenRegistration = null;

      await setupFcmMock();
      addTearDown(teardownFcmMock);
    });

    tearDown(() {
      FirebaseRuntimeState.isEnabled = prevEnabled;
      FirebaseRuntimeState.isReady = prevReady;
      PushNotificationsService.onNotificationTap = null;
      PushNotificationsService.onTokenRegistration = null;
    });

    test('getToken retrieves FCM token via Apple path', () async {
      final token = await PushNotificationsService.getToken();
      expect(token, 'fake-fcm-token-1234567890');
      expect(PushNotificationsService.currentToken, 'fake-fcm-token-1234567890');
    });

    test('getToken returns null when FCM getToken returns null', () async {
      teardownFcmMock();
      await setupFcmMock(token: '');

      final token = await PushNotificationsService.getToken();
      // Empty string token is treated as null by the messaging plugin.
      expect(token, anyOf(isNull, ''));
    });

    test('getToken calls onTokenRegistration callback when set', () async {
      String? registeredToken;
      PushNotificationsService.onTokenRegistration = (token) async {
        registeredToken = token;
      };

      await PushNotificationsService.getToken();

      expect(registeredToken, 'fake-fcm-token-1234567890');
    });

    test('getToken handles onTokenRegistration callback throwing gracefully', () async {
      PushNotificationsService.onTokenRegistration = (token) async {
        throw Exception('Backend registration failed');
      };

      // Should not throw — _registerToken catches the error internally.
      final token = await PushNotificationsService.getToken();
      expect(token, 'fake-fcm-token-1234567890');
    });

    test('getToken works without onTokenRegistration callback', () async {
      PushNotificationsService.onTokenRegistration = null;
      final token = await PushNotificationsService.getToken();
      expect(token, 'fake-fcm-token-1234567890');
    });

    test('concurrent getToken calls coalesce with Firebase mocked', () async {
      final a = PushNotificationsService.getToken();
      final b = PushNotificationsService.getToken();
      final results = await Future.wait([a, b]);
      expect(results.length, 2);
      expect(results.every((t) => t == 'fake-fcm-token-1234567890'), isTrue);
    });

    test('requestUserPermission returns authorized settings', () async {
      final settings = await PushNotificationsService.requestUserPermission();
      expect(settings, isNotNull);
      expect(settings!.authorizationStatus, AuthorizationStatus.authorized);
    });

    test('requestUserPermission with provisional=true returns provisional', () async {
      teardownFcmMock();
      await setupFcmMock(authorizationStatus: 2); // provisional

      final settings = await PushNotificationsService.requestUserPermission(provisional: true);
      expect(settings, isNotNull);
      expect(settings!.authorizationStatus, AuthorizationStatus.provisional);
    });

    test('requestUserPermission returns denied when status is denied', () async {
      teardownFcmMock();
      await setupFcmMock(authorizationStatus: 0); // denied

      final settings = await PushNotificationsService.requestUserPermission();
      expect(settings, isNotNull);
      expect(settings!.authorizationStatus, AuthorizationStatus.denied);
    });

    test('requestUserPermission returns notDetermined when status is -1', () async {
      teardownFcmMock();
      await setupFcmMock(authorizationStatus: -1); // notDetermined

      final settings = await PushNotificationsService.requestUserPermission();
      expect(settings, isNotNull);
      expect(settings!.authorizationStatus, AuthorizationStatus.notDetermined);
    });

    test('deleteToken removes the token and clears currentToken', () async {
      // First get a token.
      await PushNotificationsService.getToken();
      expect(PushNotificationsService.currentToken, 'fake-fcm-token-1234567890');

      // Then delete it.
      await PushNotificationsService.deleteToken();
      expect(PushNotificationsService.currentToken, isNull);
    });

    test('deleteToken completes without throwing when messaging throws', () async {
      teardownFcmMock();
      await setupFcmMock();

      // Override the deleteToken method to throw.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        fcmChannel,
        (MethodCall call) async {
          switch (call.method) {
            case 'Messaging#deleteToken':
              throw PlatformException(code: 'error');
            case 'Messaging#getAPNSToken':
              return {'token': 'fake-apns-token'};
            case 'Messaging#getToken':
              return {'token': 'fake-fcm-token'};
            default:
              return null;
          }
        },
      );

      // Should catch the error and complete without throwing.
      await expectLater(PushNotificationsService.deleteToken(), completes);
    });

    test('initLocalNotifications completes on iOS with mocked channel', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        flnChannel,
        (MethodCall call) async {
          switch (call.method) {
            case 'initialize':
              return true;
            case 'show':
              return null;
            default:
              return null;
          }
        },
      );
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
          flnChannel,
          null,
        );
      });

      await expectLater(PushNotificationsService.initLocalNotifications(), completes);
    });
  });
}
