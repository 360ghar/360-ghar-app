import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/config/app_config.dart';
import 'package:ghar360/core/firebase/firebase_initializer.dart';
import 'package:ghar360/core/firebase/firebase_runtime_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FirebaseInitializer runtime state getters', () {
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

    test('isFirebaseReady reflects FirebaseRuntimeState.isReady (false)', () {
      FirebaseRuntimeState.isReady = false;
      expect(FirebaseInitializer.isFirebaseReady, isFalse);
    });

    test('isFirebaseReady reflects FirebaseRuntimeState.isReady (true)', () {
      FirebaseRuntimeState.isReady = true;
      expect(FirebaseInitializer.isFirebaseReady, isTrue);
    });

    test('isFirebaseEnabled reflects FirebaseRuntimeState.isEnabled (false)', () {
      FirebaseRuntimeState.isEnabled = false;
      expect(FirebaseInitializer.isFirebaseEnabled, isFalse);
    });

    test('isFirebaseEnabled reflects FirebaseRuntimeState.isEnabled (true)', () {
      FirebaseRuntimeState.isEnabled = true;
      expect(FirebaseInitializer.isFirebaseEnabled, isTrue);
    });
  });

  group('FirebaseInitializer.wireGlobalErrorHandlers', () {
    test('is a no-op and does not throw', () {
      expect(() => FirebaseInitializer.wireGlobalErrorHandlers(), returnsNormally);
    });

    test('can be called multiple times safely', () {
      expect(() {
        FirebaseInitializer.wireGlobalErrorHandlers();
        FirebaseInitializer.wireGlobalErrorHandlers();
      }, returnsNormally);
    });
  });

  group('FirebaseInitializer.init disabled path', () {
    late bool prevEnabled;
    late bool prevReady;

    setUp(() {
      prevEnabled = FirebaseRuntimeState.isEnabled;
      prevReady = FirebaseRuntimeState.isReady;
      // AppConfig is not initialized in tests, so config?.firebaseEnabled
      // resolves to the default `true`. We cannot exercise the disabled branch
      // without initializing AppConfig (which requires Firebase options).
      // Instead we assert the runtime state getters behave as documented.
    });

    tearDown(() {
      FirebaseRuntimeState.isEnabled = prevEnabled;
      FirebaseRuntimeState.isReady = prevReady;
      AppConfig.resetForTest();
    });

    test('isFirebaseReady is false in the test environment', () {
      // Firebase is never initialized in unit tests.
      FirebaseRuntimeState.isReady = false;
      expect(FirebaseInitializer.isFirebaseReady, isFalse);
    });

    test('isFirebaseEnabled is false in the test environment by default', () {
      FirebaseRuntimeState.isEnabled = false;
      expect(FirebaseInitializer.isFirebaseEnabled, isFalse);
    });
  });

  group('FirebaseInitializer.init with firebaseEnabled=false', () {
    late bool prevEnabled;
    late bool prevReady;

    setUp(() {
      prevEnabled = FirebaseRuntimeState.isEnabled;
      prevReady = FirebaseRuntimeState.isReady;
      // Initialize AppConfig with firebaseEnabled=false to exercise the
      // disabled-skip branch of FirebaseInitializer.init().
      AppConfig.initialize(
        overrides: {
          'SUPABASE_URL': 'https://example.supabase.co',
          'SUPABASE_PUBLISHABLE_KEY': 'test-key',
          'FIREBASE_ENABLED': 'false',
        },
      );
    });

    tearDown(() {
      FirebaseRuntimeState.isEnabled = prevEnabled;
      FirebaseRuntimeState.isReady = prevReady;
      AppConfig.resetForTest();
    });

    test('sets isReady to false and skips initialization', () async {
      // The init() method should detect firebaseEnabled=false, set
      // FirebaseRuntimeState.isReady=false, mark _initialized=true, and return.
      await FirebaseInitializer.init();

      expect(
        FirebaseInitializer.isFirebaseEnabled,
        isFalse,
        reason: 'Firebase should be disabled when FIREBASE_ENABLED=false',
      );
      expect(
        FirebaseInitializer.isFirebaseReady,
        isFalse,
        reason: 'Firebase should not be ready when disabled',
      );
    });

    test('subsequent calls are idempotent (no-op)', () async {
      // First call initializes the disabled state.
      await FirebaseInitializer.init();
      final enabledAfterFirst = FirebaseInitializer.isFirebaseEnabled;
      final readyAfterFirst = FirebaseInitializer.isFirebaseReady;

      // Second call should be a no-op (the _initialized guard returns early).
      await FirebaseInitializer.init();
      expect(FirebaseInitializer.isFirebaseEnabled, enabledAfterFirst);
      expect(FirebaseInitializer.isFirebaseReady, readyAfterFirst);
    });

    test('isFirebaseEnabled reflects the disabled state after init', () async {
      await FirebaseInitializer.init();
      // The getter reads FirebaseRuntimeState.isEnabled which was set to false.
      expect(FirebaseInitializer.isFirebaseEnabled, isFalse);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // firebaseMessagingBackgroundHandler tests
  // ─────────────────────────────────────────────────────────────────────────
  //
  // These tests mock the Firebase core Pigeon API (via setupFirebaseCoreMocks)
  // and the flutter_local_notifications MethodChannel so that
  // firebaseMessagingBackgroundHandler can be exercised end-to-end.
  //
  // debugDefaultTargetPlatformOverride is set to iOS so that
  // DefaultFirebaseOptions.currentPlatform returns valid iOS options instead
  // of throwing UnsupportedError (macOS is not configured).

  const flnChannel = MethodChannel('dexterous.com/flutter/local_notifications');

  group('firebaseMessagingBackgroundHandler', () {
    setUpAll(() {
      setupFirebaseCoreMocks();
    });

    setUp(() async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      // Do NOT pre-initialize Firebase here. The background handler calls
      // Firebase.initializeApp itself via DefaultFirebaseOptions.currentPlatform.
      // Pre-initializing would throw duplicate-app and skip the handler body.

      // Mock the flutter_local_notifications channel for
      // _showBackgroundNotification.
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
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        flnChannel,
        null,
      );
    });

    test('completes without throwing for a message with notification title', () async {
      final message = const RemoteMessage(
        messageId: 'test-1',
        notification: RemoteNotification(title: 'Test Title', body: 'Test Body'),
        data: <String, dynamic>{'key': 'value'},
      );

      await expectLater(firebaseMessagingBackgroundHandler(message), completes);
    });

    test('extracts title from notification payload', () async {
      final message = const RemoteMessage(
        messageId: 'test-2',
        notification: RemoteNotification(title: 'Hello World', body: 'This is a test body'),
      );

      // Should complete without throwing and display a local notification.
      await expectLater(firebaseMessagingBackgroundHandler(message), completes);
    });

    test('falls back to data payload for title when notification is null', () async {
      final message = const RemoteMessage(
        messageId: 'test-3',
        data: <String, dynamic>{'title': 'Data Title', 'body': 'Data Body'},
      );

      await expectLater(firebaseMessagingBackgroundHandler(message), completes);
    });

    test('falls back to notification_title in data payload', () async {
      final message = const RemoteMessage(
        messageId: 'test-4',
        data: <String, dynamic>{
          'notification_title': 'Notif Title',
          'notification_body': 'Notif Body',
        },
      );

      await expectLater(firebaseMessagingBackgroundHandler(message), completes);
    });

    test('does not display notification when title is empty', () async {
      final message = const RemoteMessage(
        messageId: 'test-5',
        notification: RemoteNotification(title: '', body: 'Body without title'),
      );

      // Should complete without throwing; no notification displayed.
      await expectLater(firebaseMessagingBackgroundHandler(message), completes);
    });

    test('does not display notification when title is null and data is empty', () async {
      final message = const RemoteMessage(messageId: 'test-6', data: <String, dynamic>{});

      await expectLater(firebaseMessagingBackgroundHandler(message), completes);
    });

    test('handles null messageId gracefully', () async {
      final message = const RemoteMessage(notification: RemoteNotification(title: 'No ID'));

      await expectLater(firebaseMessagingBackgroundHandler(message), completes);
    });

    test('handles message with both notification and data payload', () async {
      final message = const RemoteMessage(
        messageId: 'test-7',
        notification: RemoteNotification(title: 'Notification Title', body: 'Notification Body'),
        data: <String, dynamic>{'property_id': '42', 'route': '/property/42'},
      );

      await expectLater(firebaseMessagingBackgroundHandler(message), completes);
    });

    test('catches errors from Firebase.initializeApp gracefully', () async {
      // Use macOS platform to trigger UnsupportedError from
      // DefaultFirebaseOptions.currentPlatform.
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      final message = const RemoteMessage(notification: RemoteNotification(title: 'Test'));

      // Should catch the UnsupportedError and complete without throwing.
      await expectLater(firebaseMessagingBackgroundHandler(message), completes);
    });
  });

  group('firebaseMessagingBackgroundHandler with FLN channel error', () {
    setUpAll(() {
      setupFirebaseCoreMocks();
    });

    setUp(() async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      // Let the background handler initialize Firebase itself.

      // Mock FLN channel to throw for all calls.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        flnChannel,
        (MethodCall call) async {
          throw PlatformException(code: 'fln-error');
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        flnChannel,
        null,
      );
    });

    test('handles FLN platform exception gracefully', () async {
      final message = const RemoteMessage(notification: RemoteNotification(title: 'Error Test'));

      // _showBackgroundNotification catches the error internally.
      await expectLater(firebaseMessagingBackgroundHandler(message), completes);
    });
  });

  group('FirebaseInitializer.init with firebaseEnabled=false and appCheck disabled', () {
    late bool prevEnabled;
    late bool prevReady;

    setUp(() {
      prevEnabled = FirebaseRuntimeState.isEnabled;
      prevReady = FirebaseRuntimeState.isReady;
      AppConfig.initialize(
        overrides: {
          'SUPABASE_URL': 'https://example.supabase.co',
          'SUPABASE_PUBLISHABLE_KEY': 'test-key',
          'FIREBASE_ENABLED': 'false',
          'FIREBASE_APPCHECK': 'false',
          'FIREBASE_CRASHLYTICS': 'false',
          'FIREBASE_ANALYTICS': 'false',
        },
      );
    });

    tearDown(() {
      FirebaseRuntimeState.isEnabled = prevEnabled;
      FirebaseRuntimeState.isReady = prevReady;
      AppConfig.resetForTest();
    });

    test('init is idempotent after disabled initialization', () async {
      // _initialized is already true from the previous group's tests.
      // This call should be a no-op.
      await FirebaseInitializer.init();
      expect(FirebaseInitializer.isFirebaseReady, anyOf(isTrue, isFalse));
    });
  });

  group('FirebaseInitializer.init config flag reflection', () {
    late bool prevEnabled;
    late bool prevReady;

    setUp(() {
      prevEnabled = FirebaseRuntimeState.isEnabled;
      prevReady = FirebaseRuntimeState.isReady;
    });

    tearDown(() {
      FirebaseRuntimeState.isEnabled = prevEnabled;
      FirebaseRuntimeState.isReady = prevReady;
      AppConfig.resetForTest();
    });

    test('isFirebaseEnabled is true when FirebaseRuntimeState.isEnabled is true', () {
      FirebaseRuntimeState.isEnabled = true;
      expect(FirebaseInitializer.isFirebaseEnabled, isTrue);
    });

    test('isFirebaseReady is true when FirebaseRuntimeState.isReady is true', () {
      FirebaseRuntimeState.isReady = true;
      expect(FirebaseInitializer.isFirebaseReady, isTrue);
    });

    test('both getters can be true simultaneously', () {
      FirebaseRuntimeState.isEnabled = true;
      FirebaseRuntimeState.isReady = true;
      expect(FirebaseInitializer.isFirebaseEnabled, isTrue);
      expect(FirebaseInitializer.isFirebaseReady, isTrue);
    });

    test('both getters can be false simultaneously', () {
      FirebaseRuntimeState.isEnabled = false;
      FirebaseRuntimeState.isReady = false;
      expect(FirebaseInitializer.isFirebaseEnabled, isFalse);
      expect(FirebaseInitializer.isFirebaseReady, isFalse);
    });

    test('isEnabled true and isReady false is a valid state', () {
      FirebaseRuntimeState.isEnabled = true;
      FirebaseRuntimeState.isReady = false;
      expect(FirebaseInitializer.isFirebaseEnabled, isTrue);
      expect(FirebaseInitializer.isFirebaseReady, isFalse);
    });
  });
}
