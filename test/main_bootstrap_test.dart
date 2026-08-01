import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:ghar360/core/bootstrap/app_bootstrap.dart';
import 'package:ghar360/core/config/app_config.dart';
import 'package:ghar360/main.dart';

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

  group('BootstrapErrorApp', () {
    // `showDevHelp` defaults to kDebugMode, which is always true in the test
    // process — so it is passed explicitly to exercise both renderings.
    testWidgets('shows dev instructions and the raw error in debug', (tester) async {
      await tester.pumpWidget(
        const BootstrapErrorApp(error: 'SUPABASE_URL missing', showDevHelp: true),
      );

      expect(find.textContaining('sync_dev_env.dart'), findsOneWidget);
      expect(find.textContaining('run_with_env.sh'), findsOneWidget);
      expect(find.text('SUPABASE_URL missing'), findsOneWidget);
    });

    testWidgets('shows a plain connection message and no dev output in release', (tester) async {
      await tester.pumpWidget(
        const BootstrapErrorApp(error: 'SUPABASE_URL missing', showDevHelp: false),
      );

      expect(find.textContaining('sync_dev_env.dart'), findsNothing);
      expect(find.textContaining('run_with_env.sh'), findsNothing);
      expect(find.textContaining('.env.development'), findsNothing);
      // The raw error dump is developer output too and must stay hidden.
      expect(find.text('SUPABASE_URL missing'), findsNothing);

      expect(find.text('Please check your internet connection and try again.'), findsOneWidget);
      // Retry affordance survives in both modes.
      expect(find.text('Retry'), findsOneWidget);
    });

    test('GetX translations are not installed by the BootstrapErrorApp shell', () {
      // `translations:` is only ever passed to GetMaterialApp in MyApp, and the
      // bootstrap failure path returns before MyApp is ever constructed
      // (main.dart:37-43). BootstrapErrorApp is a plain MaterialApp, so nothing
      // installs a translation map and `.tr` renders the raw key — which is why
      // the shell hardcodes English instead of calling `.tr`.
      expect(Get.translations, isEmpty);
      expect(Get.locale, isNull);
      expect('connection_error_message'.tr, 'connection_error_message');
    });
  });
}
