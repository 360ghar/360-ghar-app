// Separate process so FirebaseInitializer's private static `_initialized`
// starts false, allowing the enabled init() path to run end-to-end with
// mocked Firebase platform interfaces (no real Firebase / network).

import 'package:firebase_analytics_platform_interface/firebase_analytics_platform_interface.dart';
import 'package:firebase_app_check_platform_interface/firebase_app_check_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_crashlytics_platform_interface/firebase_crashlytics_platform_interface.dart';
import 'package:firebase_in_app_messaging_platform_interface/firebase_in_app_messaging_platform_interface.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_performance_platform_interface/firebase_performance_platform_interface.dart';
import 'package:firebase_remote_config_platform_interface/firebase_remote_config_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/config/app_config.dart';
import 'package:ghar360/core/firebase/firebase_initializer.dart';
import 'package:ghar360/core/firebase/firebase_runtime_state.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

// ---------------------------------------------------------------------------
// Firebase core mock with Crashlytics plugin constants
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Platform fakes
// ---------------------------------------------------------------------------

class _EmptyFirebaseCore extends MockFirebaseApp {
  int initializations = 0;
  @override
  Future<List<CoreInitializeResponse>> initializeCore() async => [];
  @override
  Future<CoreInitializeResponse> initializeApp(String appName, CoreFirebaseOptions options) async {
    initializations++;
    return CoreInitializeResponse(
      name: appName,
      options: options,
      pluginConstants: {
        'plugins.flutter.io/firebase_crashlytics': {'isCrashlyticsCollectionEnabled': true},
      },
    );
  }
}

class _FakeCrashlytics extends Fake
    with MockPlatformInterfaceMixin
    implements FirebaseCrashlyticsPlatform {
  bool collectionEnabled = true;
  final collectionChanges = <bool>[];

  @override
  FirebaseApp get appInstance => Firebase.app();

  @override
  bool get isCrashlyticsCollectionEnabled => collectionEnabled;

  @override
  FirebaseCrashlyticsPlatform setInitialValues({required bool isCrashlyticsCollectionEnabled}) {
    collectionEnabled = isCrashlyticsCollectionEnabled;
    return this;
  }

  @override
  Future<void> setCrashlyticsCollectionEnabled(bool enabled) async {
    collectionEnabled = enabled;
    collectionChanges.add(enabled);
  }
}

class _FakeAnalytics extends Fake
    with MockPlatformInterfaceMixin
    implements FirebaseAnalyticsPlatform {
  @override
  FirebaseAnalyticsPlatform delegateFor({
    required FirebaseApp app,
    Map<String, dynamic>? webOptions,
  }) => this;

  FirebaseAnalyticsPlatform setInitialValues({required Map<dynamic, dynamic> pluginConstants}) =>
      this;

  final collectionChanges = <bool>[];
  @override
  Future<void> setAnalyticsCollectionEnabled(bool enabled) async {
    collectionChanges.add(enabled);
  }
}

class _FakePerformance extends Fake
    with MockPlatformInterfaceMixin
    implements FirebasePerformancePlatform {
  @override
  FirebasePerformancePlatform delegateFor({required FirebaseApp app}) => this;

  final collectionChanges = <bool>[];
  @override
  Future<void> setPerformanceCollectionEnabled(bool enabled) async {
    collectionChanges.add(enabled);
  }
}

class _FakeInAppMessaging extends Fake
    with MockPlatformInterfaceMixin
    implements FirebaseInAppMessagingPlatform {
  @override
  FirebaseInAppMessagingPlatform delegateFor({FirebaseApp? app}) => this;

  @override
  Future<void> setAutomaticDataCollectionEnabled(bool enabled) async {}
}

class _FakeAppCheck extends Fake
    with MockPlatformInterfaceMixin
    implements FirebaseAppCheckPlatform {
  @override
  FirebaseAppCheckPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAppCheckPlatform setInitialValues() => this;

  @override
  Future<void> activate({
    WebProvider? webProvider,
    AndroidProvider? androidProvider,
    AppleProvider? appleProvider,
    AndroidAppCheckProvider? providerAndroid,
    AppleAppCheckProvider? providerApple,
    WindowsAppCheckProvider? providerWindows,
  }) async {}

  @override
  Future<void> setTokenAutoRefreshEnabled(bool isTokenAutoRefreshEnabled) async {}
}

class _FakeRemoteConfig extends Fake
    with MockPlatformInterfaceMixin
    implements FirebaseRemoteConfigPlatform {
  final Map<String, Object?> _defaults = <String, Object?>{};

  @override
  FirebaseRemoteConfigPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseRemoteConfigPlatform setInitialValues({
    required Map<dynamic, dynamic> remoteConfigValues,
  }) => this;

  @override
  DateTime get lastFetchTime => DateTime.fromMillisecondsSinceEpoch(0);

  @override
  RemoteConfigFetchStatus get lastFetchStatus => RemoteConfigFetchStatus.success;

  @override
  RemoteConfigSettings get settings => RemoteConfigSettings(
    fetchTimeout: const Duration(seconds: 15),
    minimumFetchInterval: const Duration(minutes: 1),
  );

  @override
  Future<void> setConfigSettings(RemoteConfigSettings remoteConfigSettings) async {}

  @override
  Future<void> setDefaults(Map<String, dynamic> defaultParameters) async {
    _defaults.addAll(defaultParameters);
  }

  @override
  Future<bool> fetchAndActivate() async => true;

  @override
  Future<void> ensureInitialized() async {}

  @override
  Map<String, RemoteConfigValue> getAll() => <String, RemoteConfigValue>{};

  @override
  bool getBool(String key) {
    final v = key == 'analytics_enabled' || key == 'performance_enabled' ? true : _defaults[key];
    if (v is bool) return v;
    if (v is String) return v == 'true' || v == '1';
    return false;
  }

  @override
  double getDouble(String key) {
    final v = _defaults[key];
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  @override
  int getInt(String key) {
    final v = _defaults[key];
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  @override
  String getString(String key) => _defaults[key]?.toString() ?? '';

  @override
  RemoteConfigValue getValue(String key) {
    // Construct via a dynamic call path that platform code uses; if unavailable
    // throw — getBool/getString are what RemoteConfigService uses.
    throw UnimplementedError('getValue not needed in this fake');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final core = _EmptyFirebaseCore();
  late _FakeAnalytics analytics;
  late _FakePerformance performance;
  late _FakeCrashlytics crashlytics;
  late bool prevEnabled;
  late bool prevReady;

  setUpAll(() {
    TestFirebaseCoreHostApi.setUp(core);
  });

  setUp(() async {
    prevEnabled = FirebaseRuntimeState.isEnabled;
    prevReady = FirebaseRuntimeState.isReady;

    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    FirebaseCrashlyticsPlatform.instance = crashlytics = _FakeCrashlytics();
    FirebaseAnalyticsPlatform.instance = analytics = _FakeAnalytics();
    FirebasePerformancePlatform.instance = performance = _FakePerformance();
    FirebaseInAppMessagingPlatform.instance = _FakeInAppMessaging();
    FirebaseAppCheckPlatform.instance = _FakeAppCheck();
    FirebaseRemoteConfigPlatform.instance = _FakeRemoteConfig();
  });

  tearDown(() async {
    FirebaseRuntimeState.isEnabled = prevEnabled;
    FirebaseRuntimeState.isReady = prevReady;
    AppConfig.resetForTest();
  });

  test('init with Firebase enabled activates services and marks ready', () async {
    AppConfig.initialize(
      overrides: {
        'SUPABASE_URL': 'https://example.supabase.co',
        'SUPABASE_PUBLISHABLE_KEY': 'test-key',
        'FIREBASE_ENABLED': 'true',
        'FIREBASE_APPCHECK': 'true',
        'FIREBASE_APPCHECK_DEBUG': 'true',
        'FIREBASE_CRASHLYTICS': 'true',
        'FIREBASE_ANALYTICS': 'false',
        'FIREBASE_PERFORMANCE': 'false',
        'FIREBASE_IAM': 'false',
      },
    );

    await FirebaseInitializer.init(readConsent: (key) => key == 'consent_analytics');
    expect(FirebaseInitializer.isFirebaseEnabled, isTrue);
    expect(FirebaseInitializer.isFirebaseReady, isTrue);
    expect(core.initializations, 1);
    expect(analytics.collectionChanges, [false, true]);
    expect(performance.collectionChanges, [false, false]);
    expect(crashlytics.collectionChanges, [true, true]);

    await FirebaseInitializer.init(readConsent: (_) => false);
    expect(core.initializations, 1);
    expect(analytics.collectionChanges, [false, true]);
    expect(FirebaseInitializer.isFirebaseReady, isTrue);
  });

  test('background handler completes with notification payload', () async {
    // Handler calls Firebase.initializeApp; if already inited by prior test,
    // duplicate-app is caught and still completes.
    final message = const RemoteMessage(
      messageId: 'bg-enabled-1',
      notification: RemoteNotification(title: 'From enabled suite', body: 'Body'),
      data: <String, dynamic>{'k': 'v'},
    );

    await expectLater(firebaseMessagingBackgroundHandler(message), completes);
  });
}
