import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ghar360/core/config/app_config.dart';
import 'package:ghar360/core/storage/app_database.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Max wait for Supabase init so a dead network cannot pin the native splash.
const Duration kSupabaseInitTimeout = Duration(seconds: 15);

enum BootstrapFailure { storage, configuration, connection }

/// Owns the complete SDK initialization, including its asynchronous session store.
/// A caller timing out does not cancel that work or permit a second SDK attempt.
class SupabaseBootstrap {
  SupabaseBootstrap({
    this._authOptions = const FlutterAuthClientOptions(
      detectSessionInUri: false,
      autoRefreshToken: true,
    ),
  });

  final FlutterAuthClientOptions _authOptions;
  Future<void>? _initialization;
  bool _disposeBeforeRetry = false;

  Future<void> initialize(String url, String key) => _initialization ??= _initialize(url, key);

  Future<void> _initialize(String url, String key) async {
    try {
      if (_disposeBeforeRetry) {
        await _disposePartialInitialization();
        _disposeBeforeRetry = false;
      }
      try {
        await Supabase.initialize(
          url: url,
          publishableKey: key,
          authOptions: _authOptions,
          debug: false,
        );
      } catch (_) {
        // The SDK sets isInitialized before awaiting session storage. Only a
        // fully completed future is ready; a partially initialized client must
        // be disposed before Supabase.initialize can run again.
        _disposeBeforeRetry = true;
        await _disposePartialInitialization();
        _disposeBeforeRetry = false;
        rethrow;
      }
    } catch (_) {
      _initialization = null;
      rethrow;
    }
  }

  Future<void> _disposePartialInitialization() async {
    Supabase? instance;
    try {
      instance = Supabase.instance;
    } on AssertionError {
      // Failure before the SDK creates its client has no resources to dispose.
      return;
    }
    if (instance.isInitialized) await instance.dispose();
  }
}

final _supabaseBootstrap = SupabaseBootstrap();

/// Result of the pre-`runApp` bootstrap sequence.
class BootstrapResult {
  const BootstrapResult.success(this.database) : ok = true, errorMessage = null, failure = null;
  const BootstrapResult.failure(this.errorMessage, this.failure) : ok = false, database = null;

  final bool ok;
  final String? errorMessage;
  final BootstrapFailure? failure;

  /// Ownership passes to ProviderScope only after every startup step succeeds.
  final AppDatabase? database;
}

/// Initializes storage, config, and Supabase. Never throws — returns a result
/// so the caller can always `runApp` and dismiss the native splash.
///
/// Optional callbacks are seams for unit tests.
Future<BootstrapResult> bootstrapAppCore({
  Future<void> Function()? initializeStorage,
  Future<AppDatabase> Function()? openDatabase,
  void Function()? initializeConfig,
  Future<void> Function(String url, String key)? initializeSupabase,
  Duration supabaseTimeout = kSupabaseInitTimeout,
}) async {
  AppDatabase? database;
  Future<BootstrapResult> failed(String message, BootstrapFailure failure) async {
    try {
      await database?.close();
    } catch (error, stack) {
      debugPrint('Bootstrap: local storage close failed: ${error.runtimeType}\n$stack');
    }
    return BootstrapResult.failure(message, failure);
  }

  try {
    // Import legacy values transactionally before any preferences are read.
    database = await (openDatabase ?? AppDatabase.open)();
    await initializeStorage?.call();
  } catch (e, st) {
    debugPrint('Bootstrap: local storage failed: ${e.runtimeType}\n$st');
    return failed('Local storage failed to start. Please try again.', BootstrapFailure.storage);
  }

  try {
    (initializeConfig ?? () => AppConfig.initialize())();
  } catch (e, st) {
    debugPrint('Bootstrap: AppConfig.initialize failed: ${e.runtimeType}\n$st');
    return failed('App configuration failed. Please try again.', BootstrapFailure.configuration);
  }

  final config = AppConfig.instance;
  final supabaseUrl = config.supabaseUrl;
  final supabaseClientKey = config.supabasePublishableKey;
  if (supabaseUrl.isEmpty || supabaseClientKey.isEmpty) {
    const message =
        'Missing SUPABASE_URL or SUPABASE_PUBLISHABLE_KEY.\n'
        'Local dev:\n'
        '  1) cp .env.development.example .env.development  (fill values)\n'
        '  2) dart run tool/sync_dev_env.dart\n'
        '  3) flutter run\n'
        'Or: ./tool/run_with_env.sh .env.development\n'
        'Or: flutter run --dart-define-from-file=.env.development';
    debugPrint('Bootstrap: $message');
    return failed(message, BootstrapFailure.configuration);
  }

  try {
    final init = initializeSupabase ?? _supabaseBootstrap.initialize;
    await init(supabaseUrl, supabaseClientKey).timeout(supabaseTimeout);
  } on TimeoutException catch (e, st) {
    debugPrint('Bootstrap: Supabase.initialize timed out: ${e.runtimeType}\n$st');
    return failed(
      'Connecting to the server timed out. Check your network and try again.',
      BootstrapFailure.connection,
    );
  } catch (e, st) {
    debugPrint('Bootstrap: Supabase.initialize failed: ${e.runtimeType}\n$st');
    return failed(
      'Could not connect to backend services. Please try again.',
      BootstrapFailure.connection,
    );
  }

  return BootstrapResult.success(database);
}
