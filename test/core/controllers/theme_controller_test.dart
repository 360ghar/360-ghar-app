import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/controllers/theme_controller.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/storage/app_database.dart';
import '../../helpers/settings_test_database.dart';

void main() {
  late SettingsTestDatabase database;
  late ProviderContainer container;
  setUp(() {
    database = SettingsTestDatabase();
    container = ProviderContainer(overrides: [appDatabaseProvider.overrideWithValue(database)]);
  });
  tearDown(() => container.dispose());

  test('defaults to system mode and Flutter owns system brightness', () {
    final settings = container.read(themeProvider);
    expect(settings.mode, AppThemeMode.system);
    expect(settings.flutterMode, ThemeMode.system);
    expect(settings.persistence.hasError, false);
  });

  test('all legacy string and index values retain their meaning', () {
    for (final mode in AppThemeMode.values) {
      expect(ThemeController.parseStoredThemeMode(mode.name), mode);
      expect(ThemeController.parseStoredThemeMode(mode.index), mode);
    }
    for (final invalid in [null, 'nope', 99, -1, true]) {
      expect(ThemeController.parseStoredThemeMode(invalid), AppThemeMode.system);
    }
  });

  for (final mode in AppThemeMode.values) {
    test('loads persisted ${mode.name} and reports matching Flutter mode and label', () {
      database.values['themeMode'] = mode.name;
      final state = container.read(themeProvider);
      expect(state.mode, mode);
      expect(state.flutterMode.name, mode.name);
      expect(state.nameKey, '${mode.name}_mode');
    });
    test('sets and persists ${mode.name} as an enum name', () async {
      expect(await container.read(themeProvider.notifier).setThemeMode(mode), true);
      expect(container.read(themeProvider).mode, mode);
      expect(database.values['themeMode'], mode.name);
      container.invalidate(themeProvider);
      expect(container.read(themeProvider).mode, mode);
    });
  }

  test('failed persistence retains the effective theme and supports retry', () async {
    database.writeFailure = StorageFailure('write');
    final notifier = container.read(themeProvider.notifier);
    expect(await notifier.setThemeMode(AppThemeMode.dark), false);
    expect(container.read(themeProvider).mode, AppThemeMode.system);
    expect(container.read(themeProvider).persistence.error, isA<StorageFailure>());
    expect(database.values.containsKey('themeMode'), false);
    database.writeFailure = null;
    expect(await notifier.retry(), true);
    expect(container.read(themeProvider).mode, AppThemeMode.dark);
  });

  test('duplicate change is blocked and no provider update occurs after disposal', () async {
    final write = Completer<void>();
    database.beforeWrite = () => write.future;
    final notifier = container.read(themeProvider.notifier);
    final first = notifier.setThemeMode(AppThemeMode.dark);
    expect(container.read(themeProvider).persistence.isLoading, true);
    expect(await notifier.setThemeMode(AppThemeMode.light), false);
    expect(database.writeCount, 1);
    container.dispose();
    write.complete();
    expect(await first, false);
  });

  testWidgets('system mode follows brightness changes without a controller observer', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, child) => MaterialApp(
            themeMode: ref.watch(themeProvider).flutterMode,
            theme: ThemeData.light(),
            darkTheme: ThemeData.dark(),
            home: Builder(builder: (context) => Text(Theme.of(context).brightness.name)),
          ),
        ),
      ),
    );
    expect(find.text('light'), findsOneWidget);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    expect(find.text('dark'), findsOneWidget);
  });
}
