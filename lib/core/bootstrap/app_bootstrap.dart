import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ghar360/core/config/app_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Max wait for Supabase init so a dead network cannot pin the native splash.
const Duration kSupabaseInitTimeout = Duration(seconds: 15);

/// Result of the pre-`runApp` bootstrap sequence.
class BootstrapResult {
  const BootstrapResult.success() : ok = true, errorMessage = null;
  const BootstrapResult.failure(this.errorMessage) : ok = false;

  final bool ok;
  final String? errorMessage;
}

/// Initializes storage, config, and Supabase. Never throws — returns a result
/// so the caller can always `runApp` and dismiss the native splash.
///
/// Optional callbacks are seams for unit tests.
Future<BootstrapResult> bootstrapAppCore({
  Future<void> Function()? initializeStorage,
  void Function()? initializeConfig,
  Future<void> Function(String url, String key)? initializeSupabase,
  Duration supabaseTimeout = kSupabaseInitTimeout,
}) async {
  try {
    await (initializeStorage ??
        () async {
          await GetStorage.init();
        })();
  } catch (e, st) {
    debugPrint('Bootstrap: GetStorage.init failed: $e\n$st');
    return BootstrapResult.failure('Local storage failed to start: $e');
  }

  try {
    (initializeConfig ?? () => AppConfig.initialize())();
  } catch (e, st) {
    debugPrint('Bootstrap: AppConfig.initialize failed: $e\n$st');
    return BootstrapResult.failure('App configuration failed: $e');
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
    return const BootstrapResult.failure(message);
  }

  try {
    final init =
        initializeSupabase ??
        (String url, String key) => Supabase.initialize(
          url: url,
          publishableKey: key,
          authOptions: const FlutterAuthClientOptions(
            detectSessionInUri: false,
            autoRefreshToken: true,
          ),
        );
    await init(supabaseUrl, supabaseClientKey).timeout(supabaseTimeout);
  } on TimeoutException catch (e, st) {
    debugPrint('Bootstrap: Supabase.initialize timed out: $e\n$st');
    return BootstrapResult.failure(
      'Connecting to the server timed out. Check your network and try again.\n($e)',
    );
  } catch (e, st) {
    // Retry after a partial success can hit "already initialized".
    if (_isSupabaseAlreadyInitialized()) {
      debugPrint('Bootstrap: Supabase already initialized; treating as success');
      return const BootstrapResult.success();
    }
    debugPrint('Bootstrap: Supabase.initialize failed: $e\n$st');
    return BootstrapResult.failure('Could not connect to backend services: $e');
  }

  return const BootstrapResult.success();
}

bool _isSupabaseAlreadyInitialized() {
  try {
    // Accessing the client throws when Supabase.initialize has not completed.
    // ignore: unnecessary_statements
    Supabase.instance.client;
    return true;
  } catch (_) {
    return false;
  }
}
