import 'dart:async';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:ghar360/core/firebase/firebase_runtime_state.dart';
import 'package:ghar360/core/utils/debug_logger.dart';

class RemoteConfigService {
  static FirebaseRemoteConfig get _rc => FirebaseRemoteConfig.instance;

  static const _defaults = <String, dynamic>{
    'analytics_enabled': false,
    'performance_enabled': false,
    'crashlytics_enabled': true,
    'iam_enabled': false,
    'push_enabled': true,
    // sampling ratios (0.0 - 1.0)
    'perf_http_sampling': 0.0,
    'perf_trace_sampling': 0.0,
  };

  static Future<void> initializeAndFetch() async {
    if (!FirebaseRuntimeState.isReady) {
      DebugLogger.debug('Remote Config init skipped: Firebase is not ready');
      return;
    }
    try {
      await _rc.setDefaults(_defaults);
      await _rc.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 15),
          minimumFetchInterval: kReleaseMode
              ? const Duration(hours: 1)
              : const Duration(minutes: 1),
        ),
      );
      await _rc.fetchAndActivate();
      DebugLogger.startup('Remote Config fetched.');
    } catch (e, st) {
      DebugLogger.warning('Remote Config init failed', e, st);
    }
  }

  /// Force-fetch Remote Config (bypasses cache interval)
  /// Use this when you need the latest values immediately (e.g., on app resume)
  static Future<bool> forceFetch() async {
    if (!FirebaseRuntimeState.isReady) {
      DebugLogger.debug('Remote Config force-fetch skipped: Firebase is not ready');
      return false;
    }
    try {
      final activated = await _rc.fetchAndActivate();
      DebugLogger.debug('Remote Config force-fetched, activated: $activated');
      return activated;
    } catch (e, st) {
      DebugLogger.warning('Remote Config force-fetch failed', e, st);
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Feature Toggles
  // ─────────────────────────────────────────────────────────────────────────
  static bool get analyticsEnabled => _getBool('analytics_enabled');
  static bool get performanceEnabled => _getBool('performance_enabled');
  static bool get crashlyticsEnabled => _getBool('crashlytics_enabled');
  static bool get iamEnabled => _getBool('iam_enabled');
  static bool get pushEnabled => _getBool('push_enabled');

  static double get perfHttpSampling => _getDouble('perf_http_sampling');
  static double get perfTraceSampling => _getDouble('perf_trace_sampling');

  static bool _getBool(String key) {
    if (!FirebaseRuntimeState.isReady) {
      return (_defaults[key] as bool?) ?? false;
    }

    try {
      return _rc.getBool(key);
    } catch (e, st) {
      DebugLogger.warning('Remote Config bool read failed for "$key"', e, st);
      return (_defaults[key] as bool?) ?? false;
    }
  }

  static double _getDouble(String key) {
    if (!FirebaseRuntimeState.isReady) {
      return (_defaults[key] as num?)?.toDouble() ?? 0.0;
    }

    try {
      return _rc.getDouble(key);
    } catch (e, st) {
      DebugLogger.warning('Remote Config double read failed for "$key"', e, st);
      return (_defaults[key] as num?)?.toDouble() ?? 0.0;
    }
  }
}
