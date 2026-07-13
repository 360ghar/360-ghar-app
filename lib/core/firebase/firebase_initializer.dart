import 'dart:async';
import 'dart:convert';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_in_app_messaging/firebase_in_app_messaging.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ghar360/core/config/app_config.dart';
import 'package:ghar360/core/firebase/firebase_runtime_state.dart';
import 'package:ghar360/core/firebase/remote_config_service.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/firebase_options.dart';

/// Background FCM handler (required to be a top-level function)
/// This handles data-only messages and displays notifications when the system doesn't auto-display
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    DebugLogger.info('📩 [FCM][BG] Message received: ${message.messageId ?? 'no-id'}');

    // Extract notification content from either notification payload or data payload
    String? title = message.notification?.title;
    String? body = message.notification?.body;

    // Fallback to data payload if notification payload is empty/missing
    if ((title == null || title.isEmpty) && message.data.isNotEmpty) {
      title = message.data['title'] as String? ?? message.data['notification_title'] as String?;
      body = message.data['body'] as String? ?? message.data['notification_body'] as String?;
    }

    // If we have content to display and system didn't show it, display locally
    if (title != null && title.isNotEmpty) {
      await _showBackgroundNotification(title, body, message.data);
    }
  } catch (e, st) {
    DebugLogger.error('Failed to handle FCM background message', e, st);
  }
}

/// Display a local notification from background handler
Future<void> _showBackgroundNotification(
  String title,
  String? body,
  Map<String, dynamic> data,
) async {
  try {
    final fln = FlutterLocalNotificationsPlugin();

    // Initialize with minimal settings for background
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await fln.initialize(settings: settings);

    // Create channel if needed
    const channel = AndroidNotificationChannel(
      'high_importance_channel',
      'General Notifications',
      description: 'General updates and alerts',
      importance: Importance.max,
    );

    final androidPlugin = fln
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(channel);

    // Show the notification
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'high_importance_channel',
        'General Notifications',
        channelDescription: 'General updates and alerts',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
      ),
    );

    final id = DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
    await fln.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
      payload: jsonEncode(data),
    );

    DebugLogger.info('📩 [FCM][BG] Local notification displayed: $title');
  } catch (e, st) {
    DebugLogger.error('Failed to show background notification', e, st);
  }
}

class FirebaseInitializer {
  static bool _initialized = false;

  static bool get isFirebaseEnabled => FirebaseRuntimeState.isEnabled;
  static bool get isFirebaseReady => FirebaseRuntimeState.isReady;

  static Future<void> init() async {
    if (_initialized) return;

    final config = AppConfig.isInitialized ? AppConfig.instance : null;
    final shouldInit = config?.firebaseEnabled ?? true;
    FirebaseRuntimeState.isEnabled = shouldInit;
    if (!shouldInit) {
      FirebaseRuntimeState.isReady = false;
      _initialized = true;
      DebugLogger.startup('Firebase initialization skipped (FIREBASE_ENABLED=false)');
      return;
    }

    FirebaseRuntimeState.isReady = false;
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseRuntimeState.isReady = true;
    DebugLogger.startup('Firebase initialized');

    // App Check (Play Integrity / DeviceCheck). Web uses reCAPTCHA v3 if provided.
    final appCheckEnabled = config?.firebaseAppCheck ?? true;
    if (appCheckEnabled) {
      try {
        if (kIsWeb) {
          final siteKey = config?.recaptchaV3SiteKey ?? '';
          if (siteKey.isNotEmpty) {
            await FirebaseAppCheck.instance.activate(providerWeb: ReCaptchaV3Provider(siteKey));
            DebugLogger.startup('App Check (Web) activated with reCAPTCHA v3');
          } else {
            DebugLogger.warning(
              'App Check (Web) site key missing; skipping web App Check activation',
            );
          }
        } else {
          final debugMode = config?.firebaseAppCheckDebug ?? !kReleaseMode;
          await FirebaseAppCheck.instance.activate(
            providerAndroid: debugMode
                ? const AndroidDebugProvider()
                : const AndroidPlayIntegrityProvider(),
            providerApple: debugMode
                ? const AppleDebugProvider()
                : const AppleDeviceCheckProvider(),
          );
          await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
          DebugLogger.startup('Firebase App Check activated (debugMode=$debugMode)');
        }
      } catch (e, st) {
        DebugLogger.warning('App Check activation failed', e, st);
      }
    }

    // Crashlytics minimal setup: enable in debug too for QA builds
    final crashlyticsEnabled = config?.firebaseCrashlytics ?? true;
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(crashlyticsEnabled);
    DebugLogger.startup('Crashlytics enabled: $crashlyticsEnabled');

    // Analytics disabled by default (privacy-by-default)
    final analyticsEnabled = config?.firebaseAnalytics ?? false;
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(analyticsEnabled);
    DebugLogger.startup('Analytics enabled: $analyticsEnabled');

    // Performance disabled by default, can be toggled remotely later
    final perfEnabled = config?.firebasePerformance ?? false;
    await FirebasePerformance.instance.setPerformanceCollectionEnabled(perfEnabled);
    DebugLogger.startup('Performance enabled: $perfEnabled');

    // In-App Messaging collection disabled by default
    await FirebaseInAppMessaging.instance.setAutomaticDataCollectionEnabled(
      config?.firebaseIam ?? false,
    );

    // Remote Config bootstrap with safe defaults
    bool rcFetched = false;
    try {
      await RemoteConfigService.initializeAndFetch();
      rcFetched = true;
    } catch (e, st) {
      DebugLogger.warning('Remote Config fetch failed; keeping env flags', e, st);
    }

    // Apply Remote Config toggles post-fetch and honor user consent when available
    try {
      if (!rcFetched) {
        // Preserve env-based settings if RC not fetched
        DebugLogger.debug('Skip RC toggles application (no fresh config)');
        _initialized = true;
        return;
      }
      final storage = GetStorage();
      bool consent(String key) {
        final v = storage.read(key);
        return v is bool ? v : true; // Default allow until explicit choice
      }

      final analyticsOn = RemoteConfigService.analyticsEnabled && consent('consent_analytics');
      final perfOn = RemoteConfigService.performanceEnabled && consent('consent_performance');

      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(analyticsOn);
      await FirebasePerformance.instance.setPerformanceCollectionEnabled(perfOn);
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
        RemoteConfigService.crashlyticsEnabled,
      );
      await FirebaseInAppMessaging.instance.setAutomaticDataCollectionEnabled(
        RemoteConfigService.iamEnabled,
      );
      DebugLogger.startup('Consent gating → analytics=$analyticsOn, performance=$perfOn');
    } catch (e, st) {
      DebugLogger.warning('Failed applying Remote Config toggles', e, st);
    }

    // FCM background handler registration. Foreground permission prompt is opt-in.
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    _initialized = true;
  }

  /// No-op holder for future extensions
  static void wireGlobalErrorHandlers() {}
}
