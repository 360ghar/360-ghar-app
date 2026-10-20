// Native messaging lifecycle contracts. Each test releases all subscriptions
// and callbacks through the same disposal path used by the application.

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_messaging_platform_interface/firebase_messaging_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/firebase/firebase_runtime_state.dart';
import 'package:ghar360/core/firebase/push_notifications_service.dart';

import '../../helpers/log_capture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(PushNotificationsService.dispose);
  tearDown(PushNotificationsService.dispose);

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

      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));

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

      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));

      await PushNotificationsService.initializeForegroundHandling();
      await tester.pumpAndSettle();
      expect(openedData, {'property_id': '12'});
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

    await completer.future.timeout(const Duration(seconds: 2));
    expect(registered, 'refreshed-token-999');
    expect(PushNotificationsService.currentToken, 'refreshed-token-999');
  });

  test('dispose cancels stream callbacks and a later owner gets one listener', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    var opens = 0;
    var tokens = 0;
    PushNotificationsService.onNotificationTap = (_) => opens++;
    PushNotificationsService.onTokenRegistration = (_) async {
      tokens++;
    };
    final first = PushNotificationsService.initializeForegroundHandling();
    final duplicate = PushNotificationsService.initializeForegroundHandling();
    expect(duplicate, same(first));
    await first;
    FirebaseMessagingPlatform.onMessageOpenedApp.add(
      const RemoteMessage(data: {'property_id': '1'}),
    );
    await Future<void>.delayed(Duration.zero);
    expect(opens, 1);

    await PushNotificationsService.dispose();
    // New callbacks must not revive listeners owned by the previous lifecycle.
    PushNotificationsService.onNotificationTap = (_) => opens++;
    PushNotificationsService.onTokenRegistration = (_) async {
      tokens++;
    };
    FirebaseMessagingPlatform.onMessageOpenedApp.add(
      const RemoteMessage(data: {'property_id': '2'}),
    );
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      fcmChannel.name,
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('Messaging#onTokenRefresh', 'old-owner-token'),
      ),
      (_) {},
    );
    await Future<void>.delayed(Duration.zero);
    expect(opens, 1);
    expect(tokens, 0);
    expect(PushNotificationsService.currentToken, isNull);

    await PushNotificationsService.initializeForegroundHandling();
    FirebaseMessagingPlatform.onMessageOpenedApp.add(
      const RemoteMessage(data: {'property_id': '3'}),
    );
    await Future<void>.delayed(Duration.zero);
    expect(opens, 2);
  });

  test('late token response after dispose cannot restore token or register', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final response = Completer<Map<String, dynamic>>();
    final requested = Completer<void>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      fcmChannel,
      (call) async {
        if (call.method == 'Messaging#getAPNSToken') return {'token': 'apns-present'};
        if (call.method == 'Messaging#getToken') {
          requested.complete();
          return response.future;
        }
        return null;
      },
    );
    var registrations = 0;
    PushNotificationsService.onTokenRegistration = (_) async {
      registrations++;
    };
    final request = PushNotificationsService.getToken();
    expect(PushNotificationsService.getToken(), same(request));
    await requested.future;
    await PushNotificationsService.dispose();
    PushNotificationsService.onTokenRegistration = (_) async {
      registrations++;
    };
    response.complete({'token': 'expired-owner-token'});
    expect(await request, isNull);
    expect(PushNotificationsService.currentToken, isNull);
    expect(registrations, 0);
  });

  test('late initialization cannot break a new owner initialization guard', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final firstResponse = Completer<bool>();
    final secondResponse = Completer<bool>();
    var initializes = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      flnChannel,
      (call) async {
        if (call.method == 'initialize') {
          initializes++;
          return initializes == 1 ? firstResponse.future : secondResponse.future;
        }
        return null;
      },
    );
    final oldOwner = PushNotificationsService.initializeForegroundHandling();
    await Future<void>.delayed(Duration.zero);
    expect(initializes, 1);
    await PushNotificationsService.dispose();
    final currentOwner = PushNotificationsService.initializeForegroundHandling();
    await Future<void>.delayed(Duration.zero);
    expect(initializes, 2);
    firstResponse.complete(true);
    await oldOwner;
    final duplicate = PushNotificationsService.initializeForegroundHandling();
    // Release all requests before asserting, even if an obsolete completion
    // incorrectly started a third native initialization.
    secondResponse.complete(true);
    await Future.wait([currentOwner, duplicate]);
    expect(duplicate, same(currentOwner));
    expect(initializes, 2);
  });

  test('getToken returns null when APNS never becomes ready', () async {
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
  }, timeout: const Timeout(Duration(seconds: 20)));

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

  test('token registration failure logs type without token or server message', () async {
    final logs = LogCapture();
    addTearDown(logs.close);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await setupFcmMock(token: 'private-fcm-token');
    PushNotificationsService.onTokenRegistration = (_) async =>
        throw StateError('private-fcm-token private-server-response');
    expect(await PushNotificationsService.getToken(), 'private-fcm-token');
    expect(logs.text, contains('StateError'));
    expect(logs.text, isNot(contains('private-')));
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
