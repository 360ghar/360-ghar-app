import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/bootstrap/app_bootstrap.dart';
import 'package:ghar360/core/config/app_config.dart';

void main() {
  setUp(() {
    AppConfig.resetForTest();
  });

  tearDown(() {
    AppConfig.resetForTest();
  });

  test('bootstrapAppCore fails clearly when Supabase keys are missing', () async {
    final result = await bootstrapAppCore(
      initializeStorage: () async {},
      initializeConfig: () {
        // Empty debugEnv so a filled local dev_env.g.dart cannot mask missing keys.
        AppConfig.initialize(overrides: const {}, debugEnv: const {});
      },
      initializeSupabase: (_, _) async {
        fail('Supabase init should not be called without keys');
      },
    );

    expect(result.ok, isFalse);
    expect(result.errorMessage, contains('SUPABASE_URL'));
    expect(result.errorMessage, contains('sync_dev_env'));
  });

  test('bootstrapAppCore succeeds when storage, config, and Supabase init', () async {
    final result = await bootstrapAppCore(
      initializeStorage: () async {},
      initializeConfig: () {
        AppConfig.initialize(
          overrides: {
            'SUPABASE_URL': 'https://example.supabase.co',
            'SUPABASE_PUBLISHABLE_KEY': 'test-key',
          },
        );
      },
      initializeSupabase: (url, key) async {
        expect(url, 'https://example.supabase.co');
        expect(key, 'test-key');
      },
    );

    expect(result.ok, isTrue);
    expect(result.errorMessage, isNull);
  });

  test('bootstrapAppCore maps Supabase timeout to a user-facing failure', () async {
    final result = await bootstrapAppCore(
      initializeStorage: () async {},
      initializeConfig: () {
        AppConfig.initialize(
          overrides: {
            'SUPABASE_URL': 'https://example.supabase.co',
            'SUPABASE_PUBLISHABLE_KEY': 'test-key',
          },
        );
      },
      initializeSupabase: (_, _) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      },
      supabaseTimeout: const Duration(milliseconds: 1),
    );

    expect(result.ok, isFalse);
    expect(result.errorMessage?.toLowerCase(), contains('timed out'));
  });

  test('bootstrapAppCore maps storage failure', () async {
    final result = await bootstrapAppCore(
      initializeStorage: () async {
        throw StateError('disk full');
      },
      initializeConfig: () {
        fail('config should not run after storage failure');
      },
    );

    expect(result.ok, isFalse);
    expect(result.errorMessage, contains('Local storage'));
  });
}
