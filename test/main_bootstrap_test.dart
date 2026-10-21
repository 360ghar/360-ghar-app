import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/bootstrap/app_bootstrap.dart';
import 'package:ghar360/core/config/app_config.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers/settings_test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SettingsTestDatabase database;
  setUp(() {
    database = SettingsTestDatabase();
    AppConfig.resetForTest();
  });

  tearDown(() {
    AppConfig.resetForTest();
  });

  test('bootstrapAppCore fails clearly when Supabase keys are missing', () async {
    final result = await bootstrapAppCore(
      openDatabase: () async => database,
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
    expect(result.database, isNull);
    expect(database.closeCount, 1);
    expect(result.errorMessage, contains('SUPABASE_URL'));
    expect(result.failure, BootstrapFailure.configuration);
    expect(result.errorMessage, contains('sync_dev_env'));
  });

  test('bootstrapAppCore succeeds when storage, config, and Supabase init', () async {
    final result = await bootstrapAppCore(
      openDatabase: () async => database,
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
    expect(result.database, same(database));
    expect(database.closeCount, 0);
    expect(result.errorMessage, isNull);
  });

  test('bootstrapAppCore maps Supabase timeout to a user-facing failure', () async {
    final result = await bootstrapAppCore(
      openDatabase: () async => database,
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
    expect(result.database, isNull);
    expect(database.closeCount, 1);
    expect(result.errorMessage?.toLowerCase(), contains('timed out'));
    expect(result.failure, BootstrapFailure.connection);
  });

  group('actual Supabase initialization ownership', () {
    void configure() => AppConfig.initialize(
      overrides: {
        'SUPABASE_URL': 'https://example.supabase.co',
        'SUPABASE_PUBLISHABLE_KEY': 'test-key',
      },
      debugEnv: const {},
    );

    tearDown(() async {
      try {
        await Supabase.instance.dispose();
      } on AssertionError {
        // Failed attempts have already disposed the partial SDK instance.
      }
    });

    test('session-storage failure closes partial SDK and database before a real retry', () async {
      SupabaseClient? partialClient;
      final storage = _ControlledSessionStorage(() async {
        partialClient = Supabase.instance.client;
        throw StateError('session storage unavailable');
      });
      final owner = SupabaseBootstrap(authOptions: _authOptions(storage));
      final failed = await bootstrapAppCore(
        openDatabase: () async => database,
        initializeConfig: configure,
        initializeSupabase: owner.initialize,
      );
      expect(partialClient, isNotNull);
      expect(failed.ok, false);
      expect(failed.failure, BootstrapFailure.connection);
      expect(database.closeCount, 1);
      expect(() => Supabase.instance, throwsAssertionError);

      storage.onInitialize = () async {};
      final retryDatabase = SettingsTestDatabase();
      final recovered = await bootstrapAppCore(
        openDatabase: () async => retryDatabase,
        initializeConfig: configure,
        initializeSupabase: owner.initialize,
      );
      expect(recovered.ok, true);
      expect(recovered.database, same(retryDatabase));
      expect(retryDatabase.closeCount, 0);
      expect(storage.initializations, 2);
      expect(Supabase.instance.client, isNot(same(partialClient)));
      await retryDatabase.close();
    });

    test('timeout retry waits for the original SDK session-store initialization', () async {
      final pending = Completer<void>();
      final storage = _ControlledSessionStorage(() => pending.future);
      final owner = SupabaseBootstrap(authOptions: _authOptions(storage));
      final first = await bootstrapAppCore(
        openDatabase: () async => database,
        initializeConfig: configure,
        initializeSupabase: owner.initialize,
        supabaseTimeout: const Duration(milliseconds: 1),
      );
      expect(first.ok, false);
      expect(database.closeCount, 1);
      expect(Supabase.instance.isInitialized, true);

      final retryDatabase = SettingsTestDatabase();
      var retryCompleted = false;
      final retry =
          bootstrapAppCore(
            openDatabase: () async => retryDatabase,
            initializeConfig: configure,
            initializeSupabase: owner.initialize,
          ).then((result) {
            retryCompleted = true;
            return result;
          });
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(retryCompleted, false);
      expect(storage.initializations, 1);
      pending.complete();
      expect((await retry).ok, true);
      expect(retryDatabase.closeCount, 0);
      expect(storage.initializations, 1);
      await retryDatabase.close();
    });
  });

  test('bootstrapAppCore maps storage failure', () async {
    final result = await bootstrapAppCore(
      openDatabase: () async => database,
      initializeStorage: () async {
        throw StateError('disk full');
      },
      initializeConfig: () {
        fail('config should not run after storage failure');
      },
    );

    expect(result.ok, isFalse);
    expect(result.database, isNull);
    expect(database.closeCount, 1);
    expect(result.errorMessage, contains('Local storage'));
    expect(result.failure, BootstrapFailure.storage);
  });

  test('database failure returns a retryable startup result before legacy storage', () async {
    final result = await bootstrapAppCore(
      openDatabase: () async => throw StorageFailure('open'),
      initializeStorage: () async => fail('legacy initialization must not run'),
    );
    expect(result.ok, false);
    expect(result.errorMessage, contains('Local storage'));
    expect(result.database, isNull);
  });

  test('config failure closes storage and retry transfers a fresh database to providers', () async {
    final failure = await bootstrapAppCore(
      openDatabase: () async => database,
      initializeStorage: () async {},
      initializeConfig: () => throw StateError('invalid config'),
    );
    expect(failure.ok, false);
    expect(database.closeCount, 1);
    final retryDatabase = SettingsTestDatabase();
    final success = await bootstrapAppCore(
      openDatabase: () async => retryDatabase,
      initializeStorage: () async {},
      initializeConfig: () => AppConfig.initialize(
        overrides: {
          'SUPABASE_URL': 'https://example.supabase.co',
          'SUPABASE_PUBLISHABLE_KEY': 'test-key',
        },
      ),
      initializeSupabase: (_, _) async {},
    );
    expect(success.ok, true);
    final container = ProviderContainer(overrides: [ownedAppDatabaseOverride(success.database!)]);
    expect(container.read(appDatabaseProvider), same(retryDatabase));
    container.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(retryDatabase.closeCount, 1);
    expect(database.closeCount, 1);
  });

  testWidgets('retry button prevents parallel bootstrap attempts', (tester) async {
    final pending = Completer<void>();
    var attempts = 0;
    await tester.pumpWidget(
      BootstrapErrorApp(
        error: 'startup failed',
        retryBootstrap: () {
          attempts++;
          return pending.future;
        },
      ),
    );
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.tap(find.text('Retry'));
    expect(attempts, 1);
    pending.complete();
    await tester.pumpAndSettle();
  });

  group('BootstrapErrorApp', () {
    testWidgets('storage recovery names local storage instead of the network', (tester) async {
      await tester.pumpWidget(
        const BootstrapErrorApp(
          error: 'private diagnostic',
          failure: BootstrapFailure.storage,
          showDevHelp: false,
        ),
      );
      expect(find.textContaining('Check free space'), findsOneWidget);
      expect(find.textContaining('internet'), findsNothing);
      expect(find.text('private diagnostic'), findsNothing);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('configuration recovery is localized before preferences are available', (
      tester,
    ) async {
      await tester.pumpWidget(
        const BootstrapErrorApp(
          error: 'private diagnostic',
          failure: BootstrapFailure.configuration,
          locale: Locale('hi', 'IN'),
          showDevHelp: false,
        ),
      );
      expect(find.text('ऐप शुरू नहीं हो सका'), findsOneWidget);
      expect(find.textContaining('सेटअप'), findsOneWidget);
      expect(find.text('private diagnostic'), findsNothing);
      expect(find.text('Retry'), findsNothing);
      expect(tester.takeException(), isNull);
    });

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

    testWidgets('failure shell renders without app providers or localization state', (
      tester,
    ) async {
      await tester.pumpWidget(const BootstrapErrorApp(error: 'startup', showDevHelp: false));
      expect(find.text('Unable to start'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

FlutterAuthClientOptions _authOptions(LocalStorage storage) => FlutterAuthClientOptions(
  localStorage: storage,
  pkceAsyncStorage: _MemoryPkceStorage(),
  detectSessionInUri: false,
  autoRefreshToken: false,
);

class _ControlledSessionStorage extends EmptyLocalStorage {
  _ControlledSessionStorage(this.onInitialize);
  Future<void> Function() onInitialize;
  int initializations = 0;
  @override
  Future<void> initialize() {
    initializations++;
    return onInitialize();
  }
}

class _MemoryPkceStorage extends GotrueAsyncStorage {
  @override
  Future<String?> getItem({required String key}) async => null;
  @override
  Future<void> removeItem({required String key}) async {}
  @override
  Future<void> setItem({required String key, required String value}) async {}
}
