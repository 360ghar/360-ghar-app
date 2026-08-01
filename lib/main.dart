import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ghar360/core/bindings/initial_binding.dart';
import 'package:ghar360/core/bootstrap/app_bootstrap.dart';
import 'package:ghar360/core/config/app_config.dart';
import 'package:ghar360/core/controllers/localization_controller.dart';
import 'package:ghar360/core/controllers/theme_controller.dart';
import 'package:ghar360/core/design/app_design_theme.dart';
import 'package:ghar360/core/firebase/analytics_service.dart';
import 'package:ghar360/core/firebase/firebase_initializer.dart';
import 'package:ghar360/core/firebase/push_notifications_service.dart';
import 'package:ghar360/core/routes/app_pages.dart';
import 'package:ghar360/core/translations/app_translations.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/core/utils/null_check_trap.dart';
import 'package:ghar360/core/utils/storage_keys.dart';
import 'package:ghar360/core/utils/webview_helper.dart';
import 'package:ghar360/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:ghar360/features/notifications/data/datasources/notifications_remote_datasource.dart';
import 'package:ghar360/root.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  runZonedGuarded(
    () async {
      // CRITICAL PATH ONLY - Do absolute minimum before first frame
      WidgetsFlutterBinding.ensureInitialized();

      final bootstrap = await bootstrapAppCore();
      if (!bootstrap.ok) {
        // Always paint a Flutter frame so the native splash is dismissed and
        // the user sees a recoverable error instead of a frozen logo screen.
        runApp(BootstrapErrorApp(error: bootstrap.errorMessage ?? 'Unknown startup error'));
        return;
      }

      // Setup global error handlers (lightweight, no I/O)
      FlutterError.onError = (FlutterErrorDetails details) {
        NullCheckTrap.captureFlutterError(details);
        if (FirebaseInitializer.isFirebaseReady) {
          try {
            FirebaseCrashlytics.instance.recordFlutterFatalError(details);
          } catch (_) {
            // Crashlytics may not be initialized yet
          }
        }
        FlutterError.presentError(details);
      };

      // START THE APP NOW - Everything else can wait
      runApp(const MyApp());

      // === DEFER NON-CRITICAL INIT TO POST-FRAME ===
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final launchStart = DateTime.now();

        // Initialize DebugLogger (deferred)
        DebugLogger.initialize();

        // System UI setup (deferred)
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        WebViewHelper.ensureInitialized();

        // Log environment status (deferred) — never log secret material
        try {
          DebugLogger.success('AppConfig ready: ${AppConfig.instance}');
          DebugLogger.info('API Base URL: ${AppConfig.instance.apiBaseUrl}');
          DebugLogger.success('Supabase initialized successfully');
        } catch (e) {
          DebugLogger.warning('Failed to log AppConfig status', e);
        }

        // Initialize Firebase (deferred - not critical for startup)
        try {
          await FirebaseInitializer.init();
          DebugLogger.success('Firebase initialized');
        } catch (e, st) {
          DebugLogger.warning('Failed to initialize Firebase', e, st);
        }

        // Track app launch duration (deferred)
        final launchDuration = DateTime.now().difference(launchStart);
        AnalyticsService.appLaunchComplete(durationMs: launchDuration.inMilliseconds);

        // Setup notifications (already deferred, keep as-is)
        _setupNotifications();
      });
    },
    (error, stack) {
      // Always surface uncaught startup/runtime errors — DebugLogger may not be ready.
      debugPrint('Uncaught zone error: $error\n$stack');

      // One-time first null-check trap capture for unhandled async errors
      if (error.toString().contains('Null check operator used on a null value')) {
        NullCheckTrap.capture(error, stack, source: 'zone');
      }
      // Report to Crashlytics if available
      if (FirebaseInitializer.isFirebaseReady) {
        try {
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        } catch (_) {
          // Crashlytics may not be initialized yet
        }
      }
    },
  );
}

/// Minimal error shell with no GetX / Supabase dependencies so startup failures
/// always replace the native splash with a recoverable UI.
class BootstrapErrorApp extends StatelessWidget {
  const BootstrapErrorApp({super.key, required this.error, this.showDevHelp = kDebugMode});

  final String error;

  /// Shows build-tool instructions and the raw error dump. Defaults to
  /// [kDebugMode]; overridable only so the release rendering stays testable
  /// (the test process always runs with `kDebugMode == true`).
  final bool showDevHelp;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF5B400),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF9FAFB),
      ),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/icons/splash_logo.png',
                      width: 96,
                      height: 96,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.home_work_outlined, size: 64, color: Color(0xFFF5B400)),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Unable to start',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF121417),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      showDevHelp
                          ? 'The app could not finish startup.\n\n'
                                'Local dev:\n'
                                '1) Fill .env.development\n'
                                '2) dart run tool/sync_dev_env.dart\n'
                                '3) flutter run\n\n'
                                'Or: ./tool/run_with_env.sh'
                          // Bootstrap failure is usually a dead/captive network.
                          // Mirrors the `connection_error_message` translation
                          // key, but hardcoded: this shell is a plain
                          // MaterialApp built before GetMaterialApp, so GetX
                          // translations are unset and `.tr` renders the raw key.
                          : 'Please check your internet connection and try again.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, height: 1.45, color: Color(0xFF6C757D)),
                    ),
                    if (showDevHelp) ...[
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F3F5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          error,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: Color(0xFF2B2F36),
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    FilledButton.icon(
                      onPressed: () {
                        // Hot-restart is not available in-app; re-run bootstrap
                        // and swap the root widget if services come up.
                        unawaited(_retryBootstrapFromError());
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF5B400),
                        foregroundColor: const Color(0xFF121417),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _retryBootstrapFromError() async {
  final result = await bootstrapAppCore();
  if (result.ok) {
    runApp(const MyApp());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DebugLogger.initialize();
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
      WebViewHelper.ensureInitialized();
      unawaited(
        FirebaseInitializer.init().then((_) {
          _setupNotifications();
        }),
      );
    });
  } else {
    runApp(BootstrapErrorApp(error: result.errorMessage ?? 'Unknown startup error'));
  }
}

/// Deferred notifications setup - runs after first frame
void _setupNotifications() {
  try {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (!FirebaseInitializer.isFirebaseReady) {
          DebugLogger.info('🔔 Skipping deferred notifications setup (Firebase disabled)');
          return;
        }

        DebugLogger.info('🔔 Starting deferred notifications setup...');

        // Configure token registration callback to send token to backend
        PushNotificationsService.onTokenRegistration = (token) async {
          try {
            final auth = Supabase.instance.client.auth;
            final session = auth.currentSession;

            if (session == null || session.accessToken.isEmpty) {
              DebugLogger.info('🔔 Skipping token registration until authenticated session exists');
              return;
            }

            final userId = auth.currentUser?.id;
            if (userId == null || userId.isEmpty) {
              DebugLogger.info('🔔 Skipping token registration until authenticated user exists');
              return;
            }

            if (Get.isRegistered<NotificationsRemoteDatasource>()) {
              final datasource = Get.find<NotificationsRemoteDatasource>();
              await datasource.registerDeviceToken(token: token, userId: userId);
            } else {
              DebugLogger.warning('🔔 NotificationsRemoteDatasource not registered yet');
            }
          } catch (e, st) {
            DebugLogger.warning('🔔 Failed to register token with backend', e, st);
          }
        };

        // Initialize FCM handling (foreground, background, terminated states)
        await PushNotificationsService.initializeForegroundHandling();

        // Request notification permissions
        final settings = await PushNotificationsService.requestUserPermission(provisional: false);
        if (settings == null) {
          DebugLogger.info('🔔 Notification permission flow skipped');
          return;
        }
        final authorizationStatus = settings.authorizationStatus;
        DebugLogger.info('🔔 Permission status: $authorizationStatus');

        final canRequestToken =
            authorizationStatus == AuthorizationStatus.authorized ||
            authorizationStatus == AuthorizationStatus.provisional;
        if (!canRequestToken) {
          DebugLogger.warning(
            '🔔 Notifications permission not granted yet; skipping token retrieval.',
          );
          return;
        }

        final isApplePlatform =
            !kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.iOS ||
                defaultTargetPlatform == TargetPlatform.macOS);

        // Get and log FCM token (this will also trigger registration with backend)
        String? token = await PushNotificationsService.getToken();
        if (token == null && !isApplePlatform) {
          DebugLogger.info('🔔 FCM token not available yet; retrying once shortly...');
          await Future<void>.delayed(const Duration(seconds: 2));
          token = await PushNotificationsService.getToken();
        }

        if (token != null) {
          DebugLogger.success('🔔 Notifications setup complete. Token available.');
          // Check if notifications are actually enabled on the device
          final enabled = await PushNotificationsService.areNotificationsEnabled();
          DebugLogger.info('🔔 Notifications enabled on device: $enabled');
        } else if (isApplePlatform) {
          DebugLogger.warning(
            '🔔 Notifications setup incomplete - no FCM token. On iOS simulator this can be expected; on a real device verify APNS entitlements/provisioning.',
          );
        } else {
          DebugLogger.warning('🔔 Notifications setup incomplete - no FCM token!');
        }
      } catch (e, st) {
        DebugLogger.error('🔔 Deferred notifications setup failed', e, st);
      }
    });
  } catch (e) {
    // Fallback if DebugLogger not ready
    // Ignore silently - notifications will be setup on next launch
  }
}

/// Reads the persisted theme mode from GetStorage synchronously.
/// GetStorage.init() is already awaited in main() before runApp().
///
/// Accepts both canonical string names and legacy int indexes so a bad
/// PreferencesController write cannot crash MyApp on rebuild.
ThemeMode _readInitialThemeMode() {
  final stored = GetStorage().read(StorageKeys.themeMode);
  final mode = ThemeController.parseStoredThemeMode(stored);
  // Heal legacy int storage so later typed readers stay safe.
  if (stored is int || (stored is String && stored != mode.name)) {
    GetStorage().write(StorageKeys.themeMode, mode.name);
  }
  return ThemeController.toFlutterThemeMode(mode);
}

/// Reads the persisted locale from GetStorage synchronously.
/// After init, LocalizationController manages via Get.updateLocale().
Locale _readInitialLocale() {
  final storage = GetStorage();
  final langCode = storage.read<String>('language_code');
  final countryCode = storage.read<String>('country_code');
  if (langCode != null && countryCode != null) {
    return Locale(langCode, countryCode);
  }
  return const Locale('en', 'US');
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: '360 Ghar',
      theme: AppDesignTheme.light(),
      darkTheme: AppDesignTheme.dark(),
      themeMode: _readInitialThemeMode(),
      locale: _readInitialLocale(),
      defaultTransition: Transition.native,
      transitionDuration: AppDesignTheme.defaultTransitionDuration,
      popGesture: true,
      supportedLocales: LocalizationController.supportedLocales,
      translations: AppTranslations(),
      fallbackLocale: const Locale('en', 'US'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const Root(),
      getPages: AppPages.routes,
      initialBinding: InitialBinding(),
      debugShowCheckedModeBanner: false,
      routingCallback: (routing) {
        DebugLogger.debug('Routing to: ${routing?.current}');

        if (Get.isRegistered<DashboardController>()) {
          final currentRoute = routing?.current ?? '';
          Get.find<DashboardController>().syncTabWithRoute(currentRoute);
        }
      },
    );
  }
}
