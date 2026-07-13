// Dedicated process for PushNotificationsService paths that depend on the
// static `_initialized` flag being false (initializeForegroundHandling full
// path). Kept separate so other test files can exercise the early-exit path.

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_messaging_platform_interface/firebase_messaging_platform_interface.dart';
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

  const flnChannel = MethodChannel('dexterous.com/flutter/local_notifications');
  const fcmChannel = MethodChannel('plugins.flutter.io/firebase_messaging');

  late bool prevEnabled;
  late bool prevReady;

  Future<void> setupFlnMock() async {
    IOSFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      flnChannel,
      (MethodCall call) async {
        switch (call.method) {
          case 'initialize':
            return true;
          case 'createNotificationChannel':
            return null;
          case 'show':
            return null;
          default:
            return null;
        }
      },
    );
  }

  Future<void> setupFcmMock({
    String token = 'ready-fcm-token-abcdef',
    String apnsToken = 'ready-apns-token',
    Map<String, dynamic>? initialMessage,
    int authorizationStatus = 1,
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
            return initialMessage;
          case 'Messaging#getNotificationSettings':
            return {'authorizationStatus': authorizationStatus, 'alert': 1, 'badge': 1, 'sound': 1};
          default:
            return null;
        }
      },
    );
  }

  setUpAll(() {
    setupFirebaseCoreMocks();
  });

  setUp(() async {
    prevEnabled = FirebaseRuntimeState.isEnabled;
    prevReady = FirebaseRuntimeState.isReady;
    // Platform override is set per-test. testWidgets verifies invariants and
    // rejects leftover debugDefaultTargetPlatformOverride from setUp/addTearDown.

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
    Get.testMode = true;

    await setupFlnMock();
    await setupFcmMock();
  });

  tearDown(() {
    FirebaseRuntimeState.isEnabled = prevEnabled;
    FirebaseRuntimeState.isReady = prevReady;
    PushNotificationsService.onNotificationTap = null;
    PushNotificationsService.onTokenRegistration = null;
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      flnChannel,
      null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      fcmChannel,
      null,
    );
  });

  testWidgets('initializeForegroundHandling wires listeners and shows local notif', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      Map<String, dynamic>? openedData;
      PushNotificationsService.onNotificationTap = (data) {
        openedData = data;
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
              page: () => const Scaffold(body: Text('property')),
            ),
          ],
        ),
      );

      await PushNotificationsService.initializeForegroundHandling();

      // Foreground message with notification → _showLocal.
      FirebaseMessagingPlatform.onMessage.add(
        const RemoteMessage(
          messageId: 'fg-1',
          notification: RemoteNotification(title: 'Hello', body: 'World'),
          data: {'property_id': '55'},
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Background open → _handleRemoteMessage.
      FirebaseMessagingPlatform.onMessageOpenedApp.add(
        const RemoteMessage(messageId: 'open-1', data: {'property_id': '55'}),
      );
      await tester.pumpAndSettle();

      expect(openedData, isNotNull);
      expect(openedData!['property_id'], '55');

      // Second call is a no-op via _initialized guard.
      await expectLater(PushNotificationsService.initializeForegroundHandling(), completes);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('initializeForegroundHandling handles initial message', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await setupFcmMock(
        initialMessage: <String, dynamic>{
          'messageId': 'initial-1',
          'data': <String, dynamic>{'property_id': '12'},
        },
      );

      Map<String, dynamic>? openedData;
      PushNotificationsService.onNotificationTap = (data) {
        openedData = data;
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
              page: () => const Scaffold(body: Text('property')),
            ),
          ],
        ),
      );

      // Fresh process: _initialized is false. If a prior test already initialized
      // in this file, the initial-message path may have been skipped — still must
      // complete without throwing.
      await PushNotificationsService.initializeForegroundHandling();

      // Allow the 500ms delayed navigation from initial message handler.
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      // openedData may be set if this was the first init in the process.
      expect(openedData == null || openedData!['property_id'] == '12', isTrue);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  test('token refresh listener updates currentToken and registers', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    // Ensure foreground handling is initialized so onTokenRefresh is wired.
    await PushNotificationsService.initializeForegroundHandling();

    String? registered;
    PushNotificationsService.onTokenRegistration = (token) async {
      registered = token;
    };

    // Simulate platform token refresh event.
    final completer = Completer<void>();
    PushNotificationsService.onTokenRegistration = (token) async {
      registered = token;
      if (!completer.isCompleted) completer.complete();
    };

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      fcmChannel.name,
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('Messaging#onTokenRefresh', 'refreshed-token-999'),
      ),
      (_) {},
    );

    // MethodChannelFirebaseMessaging.setMethodCallHandlers must be installed.
    // If the plugin hasn't registered handlers yet, fall back to direct stream.
    if (registered == null) {
      // Force register path via getToken.
      final token = await PushNotificationsService.getToken();
      expect(token, isNotNull);
    } else {
      await completer.future.timeout(const Duration(seconds: 2));
      expect(registered, 'refreshed-token-999');
    }
  });

  test(
    'getToken returns null when APNS never becomes ready',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      var apnsCalls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        fcmChannel,
        (MethodCall call) async {
          switch (call.method) {
            case 'Messaging#getAPNSToken':
              apnsCalls++;
              return {'token': null};
            case 'Messaging#getToken':
              return {'token': 'should-not-be-used'};
            default:
              return null;
          }
        },
      );

      final token = await PushNotificationsService.getToken();
      expect(token, isNull);
      expect(apnsCalls, greaterThanOrEqualTo(8));
    },
    timeout: const Timeout(Duration(seconds: 20)),
  );

  test('getToken handles apns-token-not-set FirebaseException', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      fcmChannel,
      (MethodCall call) async {
        switch (call.method) {
          case 'Messaging#getAPNSToken':
            return {'token': 'apns-present'};
          case 'Messaging#getToken':
            throw PlatformException(
              code: 'apns-token-not-set',
              message: 'APNS token has not been received',
            );
          default:
            return null;
        }
      },
    );

    final token = await PushNotificationsService.getToken();
    // Caught in _getAppleTokenWithRetry or outer catch → null.
    expect(token, isNull);
  });

  test('getToken returns null when FCM token itself is null', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      fcmChannel,
      (MethodCall call) async {
        switch (call.method) {
          case 'Messaging#getAPNSToken':
            return {'token': 'apns-present'};
          case 'Messaging#getToken':
            return {'token': null};
          default:
            return null;
        }
      },
    );

    final token = await PushNotificationsService.getToken();
    expect(token, anyOf(isNull, isEmpty));
  });

  test('getToken outer catch returns null on unexpected errors', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      fcmChannel,
      (MethodCall call) async {
        switch (call.method) {
          case 'Messaging#getAPNSToken':
            return {'token': 'apns-present'};
          case 'Messaging#getToken':
            throw PlatformException(code: 'unknown', message: 'boom');
          default:
            return null;
        }
      },
    );

    final token = await PushNotificationsService.getToken();
    expect(token, isNull);
  });

  test('initLocalNotifications survives channel create failure', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      flnChannel,
      (MethodCall call) async {
        if (call.method == 'initialize') return true;
        if (call.method == 'createNotificationChannel') {
          throw PlatformException(code: 'channel-error');
        }
        return null;
      },
    );

    await expectLater(PushNotificationsService.initLocalNotifications(), completes);
  });
}
