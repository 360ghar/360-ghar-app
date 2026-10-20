import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:ghar360/core/firebase/firebase_initializer.dart';
import 'package:ghar360/core/utils/debug_logger.dart';

/// Callback type for when a notification is tapped
typedef NotificationTapCallback = void Function(Map<String, dynamic> data);

/// Callback type for registering FCM token with backend
typedef TokenRegistrationCallback = Future<void> Function(String token);

class PushNotificationsService {
  static final FlutterLocalNotificationsPlugin _fln = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static Future<void>? _initializing;
  static int _generation = 0;
  static final List<StreamSubscription<dynamic>> _subscriptions = [];

  static String? _currentToken;
  static Future<String?>? _tokenRequestInFlight;

  static const int _maxApnsReadyChecks = 8;
  static const Duration _apnsReadyCheckDelay = Duration(milliseconds: 800);

  /// Callback to handle notification taps
  static NotificationTapCallback? onNotificationTap;

  /// Callback to register token with backend
  static TokenRegistrationCallback? onTokenRegistration;

  /// Get the current FCM token (may be null if not yet retrieved)
  static String? get currentToken => _currentToken;

  static FirebaseMessaging? get _messaging {
    if (!FirebaseInitializer.isFirebaseReady) return null;
    try {
      return FirebaseMessaging.instance;
    } catch (e, st) {
      DebugLogger.warning('🔔 FirebaseMessaging instance unavailable', e, st);
      return null;
    }
  }

  /// Initialize local notifications with proper channel setup
  static Future<void> initLocalNotifications() async {
    DebugLogger.info('🔔 Initializing local notifications...');

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(android: android, iOS: ios);

    await _fln.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationTapped,
    );

    // Create a high-importance default channel for Android 8+
    try {
      const channel = AndroidNotificationChannel(
        'high_importance_channel',
        'General Notifications',
        description: 'General updates and alerts',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );

      final androidPlugin = _fln
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(channel);
      DebugLogger.success('🔔 Notification channel "high_importance_channel" created');
    } catch (e, st) {
      DebugLogger.warning('Failed to create Android notification channel', e, st);
    }
  }

  /// Handle notification tap when app is in foreground or background
  static void _onNotificationTapped(NotificationResponse response) {
    DebugLogger.info('Notification tapped');
    _handleNotificationPayload(response.payload);
  }

  /// Handle notification tap when app was terminated
  @pragma('vm:entry-point')
  static void _onBackgroundNotificationTapped(NotificationResponse response) {
    DebugLogger.info('Background notification tapped');
    _handleNotificationPayload(response.payload);
  }

  /// Process the notification payload and trigger callback
  static void _handleNotificationPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;

    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      onNotificationTap?.call(data);
    } catch (e, stack) {
      DebugLogger.warning('Failed to parse notification payload', e, stack);
    }
  }

  /// Initialize FCM handling for all app states
  static Future<void> initializeForegroundHandling() {
    final existing = _initializing;
    if (existing != null) return existing;
    late final Future<void> request;
    request = _initializeForegroundHandling(_generation).whenComplete(() {
      if (identical(_initializing, request)) _initializing = null;
    });
    _initializing = request;
    return request;
  }

  static Future<void> _initializeForegroundHandling(int generation) async {
    if (_initialized) {
      DebugLogger.debug('🔔 Push notifications already initialized');
      return;
    }

    if (!FirebaseInitializer.isFirebaseReady) {
      DebugLogger.info('🔔 FCM initialization skipped: Firebase is not ready');
      return;
    }

    final messaging = _messaging;
    if (messaging == null) {
      DebugLogger.warning('🔔 FCM initialization skipped: messaging client unavailable');
      return;
    }

    DebugLogger.info('🔔 Initializing FCM handling...');
    await initLocalNotifications();
    if (generation != _generation) return;

    // Configure foreground notification presentation options (iOS)
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    if (generation != _generation) return;
    final launch = await _fln.getNotificationAppLaunchDetails();
    if (generation != _generation) return;
    if (launch?.didNotificationLaunchApp == true) {
      _handleNotificationPayload(launch?.notificationResponse?.payload);
    }

    // Handle messages when app is in foreground
    _subscriptions.add(
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        DebugLogger.info('Foreground notification received');

        final notification = message.notification;
        if (notification != null) {
          await _showLocal(notification, message.data);
        }
      }),
    );

    // Handle notification tap when app is in background (but not terminated)
    _subscriptions.add(
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        DebugLogger.info('Notification opened from background');
        _handleRemoteMessage(message);
      }),
    );

    // Handle notification tap that launched the app from terminated state
    final initialMessage = await messaging.getInitialMessage();
    if (generation != _generation) return;
    if (initialMessage != null) {
      DebugLogger.info('Notification opened at launch');
      _handleRemoteMessage(initialMessage);
    }

    // Listen for token refresh
    _subscriptions.add(
      messaging.onTokenRefresh.listen((newToken) async {
        DebugLogger.info('Notification token refreshed');
        _currentToken = newToken;
        await _registerToken(newToken);
      }),
    );

    _initialized = true;
    DebugLogger.success('🔔 FCM handling initialized successfully');
  }

  /// Handle FCM remote message data
  static void _handleRemoteMessage(RemoteMessage message) {
    onNotificationTap?.call(message.data);
  }

  /// Request notification permissions from the user
  static Future<NotificationSettings?> requestUserPermission({bool provisional = false}) async {
    if (!FirebaseInitializer.isFirebaseReady) {
      DebugLogger.info('🔔 Permission request skipped: Firebase is not ready');
      return null;
    }
    final messaging = _messaging;
    if (messaging == null) {
      DebugLogger.warning('🔔 Permission request skipped: messaging client unavailable');
      return null;
    }

    DebugLogger.info('🔔 Requesting FCM permission...');

    // iOS/Apple platforms - request permission via FCM
    final settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: provisional,
      sound: true,
    );

    final status = settings.authorizationStatus;
    switch (status) {
      case AuthorizationStatus.authorized:
        DebugLogger.success('🔔 FCM permission: AUTHORIZED');
        break;
      case AuthorizationStatus.provisional:
        DebugLogger.info('🔔 FCM permission: PROVISIONAL');
        break;
      case AuthorizationStatus.denied:
        DebugLogger.warning('🔔 FCM permission: DENIED - notifications will not work!');
        break;
      case AuthorizationStatus.notDetermined:
        DebugLogger.warning('🔔 FCM permission: NOT DETERMINED');
        break;
    }

    // Android 13+ requires runtime permission for notifications
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final androidPlugin = _fln
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        final granted = await androidPlugin?.requestNotificationsPermission();
        if (granted == true) {
          DebugLogger.success('🔔 Android notification permission: GRANTED');
        } else {
          DebugLogger.warning('🔔 Android notification permission: DENIED or not requested');
        }
      } catch (e, st) {
        DebugLogger.warning('Android notifications permission request failed', e, st);
      }
    }

    return settings;
  }

  /// Get the FCM token and optionally register it with the backend
  static Future<String?> getToken() {
    final inFlight = _tokenRequestInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final generation = _generation;
    final request = _getTokenInternal(generation);
    _tokenRequestInFlight = request;

    request.whenComplete(() {
      if (identical(_tokenRequestInFlight, request)) {
        _tokenRequestInFlight = null;
      }
    });

    return request;
  }

  static Future<String?> _getTokenInternal(int generation) async {
    try {
      if (!FirebaseInitializer.isFirebaseReady) {
        DebugLogger.info('🔑 FCM token request skipped: Firebase is not ready');
        return null;
      }
      final messaging = _messaging;
      if (messaging == null) {
        DebugLogger.warning('🔑 FCM token request skipped: messaging client unavailable');
        return null;
      }

      String? token;
      if (kIsWeb) {
        // For web, you may need a VAPID key
        token = await messaging.getToken(vapidKey: null);
      } else if (Platform.isIOS || Platform.isMacOS) {
        token = await _getAppleTokenWithRetry(messaging);
      } else {
        token = await messaging.getToken();
      }

      if (generation != _generation) return null;
      if (token != null) {
        DebugLogger.success('Notification token available');
        _currentToken = token;
        await _registerToken(token);
      } else {
        DebugLogger.warning('🔑 FCM token is null - notifications will not work!');
      }

      return token;
    } catch (e, st) {
      DebugLogger.error('FCM getToken failed', e, st);
      return null;
    }
  }

  static Future<String?> _getAppleTokenWithRetry(FirebaseMessaging messaging) async {
    final apnsReady = await _waitForApnsToken(messaging);
    if (!apnsReady) {
      DebugLogger.warning('🍎 APNS token not ready yet. Skipping FCM token request for now.');
      return null;
    }

    try {
      final token = await messaging.getToken();
      if (token == null) {
        DebugLogger.warning('🍎 FCM token is null even though APNS token is ready.');
      }
      return token;
    } on FirebaseException catch (e, st) {
      if (e.code != 'apns-token-not-set') {
        rethrow;
      }

      DebugLogger.warning('🍎 APNS token still not set while requesting FCM token.', e, st);
      return null;
    }
  }

  static Future<bool> _waitForApnsToken(FirebaseMessaging messaging) async {
    for (var attempt = 1; attempt <= _maxApnsReadyChecks; attempt++) {
      final apnsToken = await messaging.getAPNSToken();
      if (apnsToken != null && apnsToken.isNotEmpty) {
        DebugLogger.info('🍎 APNS token ready on check $attempt/$_maxApnsReadyChecks');
        return true;
      }

      DebugLogger.debug('🍎 APNS token not ready on check $attempt/$_maxApnsReadyChecks');
      if (attempt < _maxApnsReadyChecks) {
        await Future<void>.delayed(_apnsReadyCheckDelay);
      }
    }

    DebugLogger.warning('🍎 APNS token not ready after $_maxApnsReadyChecks checks.');
    return false;
  }

  /// Register the FCM token with the backend
  static Future<void> _registerToken(String token) async {
    if (onTokenRegistration != null) {
      try {
        await onTokenRegistration!(token);
        DebugLogger.success('🔑 FCM token registered with backend');
      } catch (e, st) {
        DebugLogger.warning('Failed to register FCM token with backend', e, st);
      }
    } else {
      DebugLogger.debug('🔑 No token registration callback set - token not sent to backend');
    }
  }

  /// Show a local notification for foreground FCM messages
  static Future<void> _showLocal(RemoteNotification notification, Map<String, dynamic> data) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'high_importance_channel',
        'General Notifications',
        channelDescription: 'General updates and alerts',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
    );

    final id = (DateTime.now().millisecondsSinceEpoch & 0x7fffffff);
    await _fln.show(
      id: id,
      title: notification.title,
      body: notification.body,
      notificationDetails: details,
      payload: data.isEmpty ? null : jsonEncode(data),
    );
    DebugLogger.info('Local notification displayed');
  }

  /// Check if notifications are enabled for the app
  static Future<bool> areNotificationsEnabled() async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final androidPlugin = _fln
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        return await androidPlugin?.areNotificationsEnabled() ?? false;
      }
      return true; // iOS handles this differently
    } catch (e, stack) {
      DebugLogger.warning('Failed to check notification enabled status', e, stack);
      return false;
    }
  }

  /// Application ownership ends here, including all Firebase stream listeners.
  static Future<void> dispose() async {
    _generation++;
    _initialized = false;
    _initializing = null;
    _currentToken = null;
    _tokenRequestInFlight = null;
    onNotificationTap = null;
    onTokenRegistration = null;
    final subscriptions = List<StreamSubscription<dynamic>>.of(_subscriptions);
    _subscriptions.clear();
    await Future.wait(subscriptions.map((subscription) => subscription.cancel()));
  }

  /// Delete the FCM token (useful for logout)
  static Future<void> deleteToken() async {
    _generation++;
    _tokenRequestInFlight = null;
    try {
      if (!FirebaseInitializer.isFirebaseReady) {
        _currentToken = null;
        return;
      }
      final messaging = _messaging;
      if (messaging == null) {
        _currentToken = null;
        return;
      }

      await messaging.deleteToken();
      _currentToken = null;
      DebugLogger.info('🔑 FCM token deleted');
    } catch (e, st) {
      DebugLogger.warning('Failed to delete FCM token', e, st);
    }
  }
}
