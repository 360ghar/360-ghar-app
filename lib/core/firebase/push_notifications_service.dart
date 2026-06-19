import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/firebase/firebase_initializer.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/core/utils/debug_logger.dart';

/// Callback type for when a notification is tapped
typedef NotificationTapCallback = void Function(Map<String, dynamic> data);

/// Callback type for registering FCM token with backend
typedef TokenRegistrationCallback = Future<void> Function(String token);

class PushNotificationsService {
  static final FlutterLocalNotificationsPlugin _fln = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
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
      settings,
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
    DebugLogger.info('🔔 Notification tapped: ${response.payload}');
    _handleNotificationPayload(response.payload);
  }

  /// Handle notification tap when app was terminated
  @pragma('vm:entry-point')
  static void _onBackgroundNotificationTapped(NotificationResponse response) {
    DebugLogger.info('🔔 Background notification tapped: ${response.payload}');
    _handleNotificationPayload(response.payload);
  }

  /// Process the notification payload and trigger callback
  static void _handleNotificationPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;

    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      onNotificationTap?.call(data);
      _navigateByPayload(data);
    } catch (e) {
      DebugLogger.warning('Failed to parse notification payload', e);
    }
  }

  /// Navigate based on notification data
  static void _navigateByPayload(Map<String, dynamic> data) {
    // Supports both an explicit `route` and a `property_id` (deep link to the
    // property details screen). Uses the canonical AppRoutes constant so the
    // deep-link path stays in sync with the route table.
    final route = data['route'] as String?;
    final propertyId = data['property_id'] as String? ?? data['propertyId'] as String?;

    if (route != null && route.isNotEmpty) {
      DebugLogger.info('🔔 Navigating to route: $route');
      Get.toNamed(route, arguments: data);
    } else if (propertyId != null && propertyId.isNotEmpty) {
      DebugLogger.info('🔔 Navigating to property: $propertyId');
      // Auth-protected details route; falls back to public deep-link routes
      // (AppRoutes.propertyDeepLink = '/property/:id') when unauthenticated.
      Get.toNamed(AppRoutes.propertyDeepLink.replaceAll(':id', propertyId));
    }
  }

  /// Initialize FCM handling for all app states
  static Future<void> initializeForegroundHandling() async {
    if (_initialized) {
      DebugLogger.debug('🔔 Push notifications already initialized');
      return;
    }

    if (!FirebaseInitializer.isFirebaseReady) {
      DebugLogger.info('🔔 FCM initialization skipped: Firebase is not ready');
      _initialized = true;
      return;
    }

    final messaging = _messaging;
    if (messaging == null) {
      DebugLogger.warning('🔔 FCM initialization skipped: messaging client unavailable');
      _initialized = true;
      return;
    }

    DebugLogger.info('🔔 Initializing FCM handling...');
    await initLocalNotifications();

    // Configure foreground notification presentation options (iOS)
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Handle messages when app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      DebugLogger.info('📩 [FCM][FOREGROUND] Message ID: ${message.messageId ?? 'no-id'}');
      DebugLogger.info('📩 [FCM][FOREGROUND] Title: ${message.notification?.title}');
      DebugLogger.info('📩 [FCM][FOREGROUND] Body: ${message.notification?.body}');
      DebugLogger.info('📩 [FCM][FOREGROUND] Data: ${message.data}');

      final notification = message.notification;
      if (notification != null) {
        await _showLocal(notification, message.data);
      }
    });

    // Handle notification tap when app is in background (but not terminated)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      DebugLogger.info('📩 [FCM][OPENED_APP] Message tapped from background: ${message.messageId}');
      _handleRemoteMessage(message);
    });

    // Handle notification tap that launched the app from terminated state
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      DebugLogger.info(
        '📩 [FCM][INITIAL] App launched via notification: ${initialMessage.messageId}',
      );
      // Delay navigation slightly to ensure app is fully loaded
      Future.delayed(const Duration(milliseconds: 500), () {
        _handleRemoteMessage(initialMessage);
      });
    }

    // Listen for token refresh
    messaging.onTokenRefresh.listen((newToken) async {
      DebugLogger.info('🔑 FCM token refreshed: ${_truncateToken(newToken)}');
      _currentToken = newToken;
      await _registerToken(newToken);
    });

    _initialized = true;
    DebugLogger.success('🔔 FCM handling initialized successfully');
  }

  /// Handle FCM remote message data
  static void _handleRemoteMessage(RemoteMessage message) {
    onNotificationTap?.call(message.data);
    _navigateByPayload(message.data);
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

    final request = _getTokenInternal();
    _tokenRequestInFlight = request;

    request.whenComplete(() {
      if (identical(_tokenRequestInFlight, request)) {
        _tokenRequestInFlight = null;
      }
    });

    return request;
  }

  static Future<String?> _getTokenInternal() async {
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

      if (token != null) {
        DebugLogger.success('🔑 FCM token retrieved: ${_truncateToken(token)}');
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
      // Log the full token in debug mode for manual testing
      if (kDebugMode) {
        DebugLogger.info('🔑 FULL FCM TOKEN (for testing): $token');
      }
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
      id,
      notification.title,
      notification.body,
      details,
      payload: data.isEmpty ? null : jsonEncode(data),
    );
    DebugLogger.info('🔔 Local notification displayed: ${notification.title}');
  }

  /// Truncate token for logging (security)
  static String _truncateToken(String token) {
    if (token.length <= 20) return token;
    return '${token.substring(0, 10)}...${token.substring(token.length - 10)}';
  }

  /// Check if notifications are enabled for the app
  static Future<bool> areNotificationsEnabled() async {
    try {
      if (Platform.isAndroid) {
        final androidPlugin = _fln
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        return await androidPlugin?.areNotificationsEnabled() ?? false;
      }
      return true; // iOS handles this differently
    } catch (e) {
      DebugLogger.warning('Failed to check notification enabled status', e);
      return false;
    }
  }

  /// Delete the FCM token (useful for logout)
  static Future<void> deleteToken() async {
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
