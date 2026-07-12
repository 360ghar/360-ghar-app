import 'package:flutter/foundation.dart';
import 'package:ghar360/core/config/dev_env.g.dart';

/// Compile-time / bootstrap configuration for the app.
///
/// **Security:** Production values must be injected via `--dart-define` or
/// `--dart-define-from-file`. Do **not** package `.env` files as Flutter
/// assets — they land as extractable files in the binary.
///
/// **Local development (plain `flutter run`):**
/// ```bash
/// cp .env.development.example .env.development   # once
/// dart run tool/sync_dev_env.dart                 # once / after env edits
/// flutter run
/// ```
///
/// In debug mode, [AppConfig] falls back to `kDevEnv` (generated from
/// `.env.development`). Explicit dart-defines always win.
///
/// IDE: VS Code passes `--dart-define-from-file=.env.development` automatically.
/// Or use: `./tool/run_with_env.sh .env.development`
class AppConfig {
  AppConfig._({
    required this.apiBaseUrl,
    required this.supabaseUrl,
    required this.supabasePublishableKey,
    required this.googlePlacesApiKey,
    required this.googleWebClientId,
    required this.googleIosClientId,
    required this.defaultCountry,
    required this.placesRadiusMeters,
    required this.placesStrictBounds,
    required this.debugMode,
    required this.logApiCalls,
    required this.firebaseEnabled,
    required this.firebaseCrashlytics,
    required this.firebaseAnalytics,
    required this.firebasePerformance,
    required this.firebaseIam,
    required this.firebaseAppCheck,
    required this.firebaseAppCheckDebug,
    required this.recaptchaV3SiteKey,
  });

  static AppConfig? _instance;

  /// Global config. Call [initialize] from `main` before first use.
  static AppConfig get instance {
    final current = _instance;
    if (current == null) {
      throw StateError('AppConfig.initialize() must be called before accessing AppConfig.instance');
    }
    return current;
  }

  static bool get isInitialized => _instance != null;

  /// Test/bootstrap helper to replace config without dart-defines.
  @visibleForTesting
  static void resetForTest([AppConfig? config]) {
    _instance = config;
  }

  final String apiBaseUrl;
  final String supabaseUrl;
  final String supabasePublishableKey;
  final String googlePlacesApiKey;
  final String googleWebClientId;
  final String googleIosClientId;
  final String defaultCountry;
  final String placesRadiusMeters;
  final bool placesStrictBounds;
  final bool debugMode;
  final bool logApiCalls;
  final bool firebaseEnabled;
  final bool firebaseCrashlytics;
  final bool firebaseAnalytics;
  final bool firebasePerformance;
  final bool firebaseIam;
  final bool firebaseAppCheck;
  final bool firebaseAppCheckDebug;
  final String recaptchaV3SiteKey;

  /// Reads compile-time `--dart-define` values, optional [overrides] (tests),
  /// and in debug mode the generated [kDevEnv] map from `.env.development`.
  ///
  /// Precedence per key:
  /// 1. [overrides]
  /// 2. Non-empty `String.fromEnvironment`
  /// 3. Debug-only generated map ([debugEnv] or [kDevEnv] when [kDebugMode])
  /// 4. [defaultValue]
  static void initialize({
    Map<String, String>? overrides,
    @visibleForTesting Map<String, String>? debugEnv,
  }) {
    final Map<String, String> devFallback;
    if (debugEnv != null) {
      devFallback = debugEnv;
    } else if (kDebugMode) {
      devFallback = kDevEnv;
    } else {
      devFallback = const <String, String>{};
    }

    String read(String key, {String defaultValue = ''}) {
      final override = overrides?[key];
      if (override != null && override.trim().isNotEmpty) {
        return override.trim();
      }
      final fromDefine = _fromEnvironment(key).trim();
      if (fromDefine.isNotEmpty) return fromDefine;
      final fromDev = devFallback[key]?.trim();
      if (fromDev != null && fromDev.isNotEmpty) return fromDev;
      return defaultValue;
    }

    bool readBool(String key, {required bool defaultValue}) {
      final raw = read(key);
      if (raw.isEmpty) return defaultValue;
      final lower = raw.toLowerCase();
      return lower == '1' || lower == 'true' || lower == 'yes';
    }

    _instance = AppConfig._(
      apiBaseUrl: read('API_BASE_URL', defaultValue: 'https://api.360ghar.com'),
      supabaseUrl: read('SUPABASE_URL'),
      supabasePublishableKey: read('SUPABASE_PUBLISHABLE_KEY'),
      googlePlacesApiKey: read('GOOGLE_PLACES_API_KEY'),
      googleWebClientId: read('GOOGLE_WEB_CLIENT_ID'),
      googleIosClientId: read('GOOGLE_IOS_CLIENT_ID'),
      defaultCountry: read('DEFAULT_COUNTRY', defaultValue: 'in'),
      placesRadiusMeters: read('PLACES_RADIUS_METERS', defaultValue: '25000'),
      placesStrictBounds: readBool('PLACES_STRICT_BOUNDS', defaultValue: false),
      debugMode: readBool('DEBUG_MODE', defaultValue: kDebugMode),
      logApiCalls: readBool('LOG_API_CALLS', defaultValue: false),
      firebaseEnabled: readBool('FIREBASE_ENABLED', defaultValue: true),
      firebaseCrashlytics: readBool('FIREBASE_CRASHLYTICS', defaultValue: true),
      // Privacy-by-default: opt in via dart-define / Remote Config.
      firebaseAnalytics: readBool('FIREBASE_ANALYTICS', defaultValue: false),
      firebasePerformance: readBool('FIREBASE_PERFORMANCE', defaultValue: false),
      firebaseIam: readBool('FIREBASE_IAM', defaultValue: false),
      firebaseAppCheck: readBool('FIREBASE_APPCHECK', defaultValue: true),
      firebaseAppCheckDebug: readBool('FIREBASE_APPCHECK_DEBUG', defaultValue: !kReleaseMode),
      recaptchaV3SiteKey: read('RECAPTCHA_V3_SITE_KEY'),
    );
  }

  /// Never include secret material in [toString]/[runtimeType] dumps.
  @override
  String toString() =>
      'AppConfig(apiBaseUrl: $apiBaseUrl, supabaseConfigured: '
      '${supabaseUrl.isNotEmpty}, placesKeyConfigured: '
      '${googlePlacesApiKey.isNotEmpty}, debugMode: $debugMode)';

  /// Compile-time lookup. Keys must be string literals for [String.fromEnvironment].
  static String _fromEnvironment(String key) {
    switch (key) {
      case 'API_BASE_URL':
        return const String.fromEnvironment('API_BASE_URL');
      case 'SUPABASE_URL':
        return const String.fromEnvironment('SUPABASE_URL');
      case 'SUPABASE_PUBLISHABLE_KEY':
        return const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
      case 'GOOGLE_PLACES_API_KEY':
        return const String.fromEnvironment('GOOGLE_PLACES_API_KEY');
      case 'GOOGLE_WEB_CLIENT_ID':
        return const String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
      case 'GOOGLE_IOS_CLIENT_ID':
        return const String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
      case 'DEFAULT_COUNTRY':
        return const String.fromEnvironment('DEFAULT_COUNTRY');
      case 'PLACES_RADIUS_METERS':
        return const String.fromEnvironment('PLACES_RADIUS_METERS');
      case 'PLACES_STRICT_BOUNDS':
        return const String.fromEnvironment('PLACES_STRICT_BOUNDS');
      case 'DEBUG_MODE':
        return const String.fromEnvironment('DEBUG_MODE');
      case 'LOG_API_CALLS':
        return const String.fromEnvironment('LOG_API_CALLS');
      case 'FIREBASE_ENABLED':
        return const String.fromEnvironment('FIREBASE_ENABLED');
      case 'FIREBASE_CRASHLYTICS':
        return const String.fromEnvironment('FIREBASE_CRASHLYTICS');
      case 'FIREBASE_ANALYTICS':
        return const String.fromEnvironment('FIREBASE_ANALYTICS');
      case 'FIREBASE_PERFORMANCE':
        return const String.fromEnvironment('FIREBASE_PERFORMANCE');
      case 'FIREBASE_IAM':
        return const String.fromEnvironment('FIREBASE_IAM');
      case 'FIREBASE_APPCHECK':
        return const String.fromEnvironment('FIREBASE_APPCHECK');
      case 'FIREBASE_APPCHECK_DEBUG':
        return const String.fromEnvironment('FIREBASE_APPCHECK_DEBUG');
      case 'RECAPTCHA_V3_SITE_KEY':
        return const String.fromEnvironment('RECAPTCHA_V3_SITE_KEY');
      default:
        return '';
    }
  }
}
