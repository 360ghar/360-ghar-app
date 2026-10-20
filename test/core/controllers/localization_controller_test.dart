import 'dart:async';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/controllers/localization_controller.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/storage/app_database.dart';
import '../../helpers/settings_test_database.dart';

void main() {
  late SettingsTestDatabase database;
  late ProviderContainer container;
  setUp(() {
    database = SettingsTestDatabase();
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        deviceLocaleProvider.overrideWithValue(const Locale('en', 'US')),
      ],
    );
  });
  tearDown(() => container.dispose());

  test('supports English and Hindi with canonical countries', () {
    expect(LocalizationController.supportedLocales, [
      const Locale('en', 'US'),
      const Locale('hi', 'IN'),
    ]);
    expect(container.read(localizationProvider).locale, const Locale('en', 'US'));
    expect(container.read(localizationProvider).languageName, 'English');
  });

  for (final entry in {'en': 'English', 'hi': 'हिंदी'}.entries) {
    test('loads saved ${entry.key} and normalizes country', () {
      database.values.addAll({'language_code': entry.key, 'country_code': 'ZZ'});
      expect(
        container.read(localizationProvider).locale,
        Locale(entry.key, entry.key == 'hi' ? 'IN' : 'US'),
      );
      expect(container.read(localizationProvider).languageName, entry.value);
    });
  }

  test('incomplete saved locale falls back to the device', () {
    database.values['language_code'] = 'hi';
    expect(container.read(localizationProvider).locale, const Locale('en', 'US'));
  });

  test('Hindi device locale is used when there is no saved preference', () {
    container.updateOverrides([
      appDatabaseProvider.overrideWithValue(database),
      deviceLocaleProvider.overrideWithValue(const Locale('hi', 'IN')),
    ]);
    expect(container.read(localizationProvider).languageName, 'हिंदी');
  });

  test('language change persists both codes atomically and survives rebuild', () async {
    final notifier = container.read(localizationProvider.notifier);
    expect(await notifier.changeLanguage('hi', 'IN'), true);
    expect(container.read(localizationProvider).locale, const Locale('hi', 'IN'));
    expect(container.read(localizationProvider).languageName, 'हिंदी');
    expect(database.values, {'language_code': 'hi', 'country_code': 'IN'});
    expect(database.writeCount, 1);
    container.invalidate(localizationProvider);
    expect(container.read(localizationProvider).locale, const Locale('hi', 'IN'));
    expect(await container.read(localizationProvider.notifier).changeLanguage('en', 'US'), true);
    expect(container.read(localizationProvider).languageName, 'English');
  });

  test('unsupported language requests normalize and persist English', () async {
    await container.read(localizationProvider.notifier).changeLanguage('fr', 'FR');
    expect(container.read(localizationProvider).locale, const Locale('en', 'US'));
    expect(database.values, {'language_code': 'en', 'country_code': 'US'});
  });

  test('failed write retains the effective locale and explicit retry commits both codes', () async {
    database.writeFailure = StorageFailure('write locale');
    final notifier = container.read(localizationProvider.notifier);
    expect(await notifier.changeLanguage('hi', 'IN'), false);
    expect(container.read(localizationProvider).locale, const Locale('en', 'US'));
    expect(container.read(localizationProvider).persistence.hasError, true);
    expect(database.values, isEmpty);
    database.writeFailure = null;
    expect(await notifier.retry(), true);
    expect(container.read(localizationProvider).locale, const Locale('hi', 'IN'));
  });

  test('duplicate change is blocked and disposal prevents a late state update', () async {
    final write = Completer<void>();
    database.beforeWrite = () => write.future;
    final notifier = container.read(localizationProvider.notifier);
    final first = notifier.changeLanguage('hi', 'IN');
    expect(container.read(localizationProvider).persistence.isLoading, true);
    expect(await notifier.changeLanguage('en', 'US'), false);
    container.dispose();
    write.complete();
    expect(await first, false);
  });
}
