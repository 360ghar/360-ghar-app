import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/features/splash/presentation/controllers/splash_controller.dart';
import '../../../../helpers/settings_test_database.dart';

void main() {
  late SettingsTestDatabase database;
  late ProviderContainer container;
  setUp(() {
    database = SettingsTestDatabase();
    container = ProviderContainer(overrides: [appDatabaseProvider.overrideWithValue(database)]);
  });
  tearDown(() => container.dispose());
  test('new installation has not completed onboarding', () {
    expect(container.read(onboardingProvider).completed, false);
    expect(container.read(onboardingProvider).save.hasValue, true);
  });
  test('migrated completion flag prevents onboarding from appearing again', () {
    database.values['has_seen_onboarding'] = true;
    expect(container.read(onboardingProvider).completed, true);
  });
  for (final invalid in ['true', 1, null, false]) {
    test('invalid or false legacy value $invalid does not skip onboarding', () {
      database.values['has_seen_onboarding'] = invalid;
      expect(container.read(onboardingProvider).completed, false);
    });
  }
  test('completion awaits the durable write before updating state', () async {
    final write = Completer<void>();
    database.beforeWrite = () => write.future;
    final result = container.read(onboardingProvider.notifier).complete();
    expect(container.read(onboardingProvider).completed, false);
    expect(container.read(onboardingProvider).save.isLoading, true);
    write.complete();
    expect(await result, true);
    expect(database.values['has_seen_onboarding'], isTrue);
    expect(container.read(onboardingProvider).completed, true);
    container.invalidate(onboardingProvider);
    expect(container.read(onboardingProvider).completed, true);
  });
  test('failed write stays on onboarding and can be retried', () async {
    database.writeFailure = StorageFailure('disk full');
    final actions = container.read(onboardingProvider.notifier);
    expect(await actions.complete(), false);
    expect(container.read(onboardingProvider).completed, false);
    expect(container.read(onboardingProvider).save.hasError, true);
    database.writeFailure = null;
    expect(await actions.complete(), true);
    expect(database.values['has_seen_onboarding'], isTrue);
  });
  test('duplicate taps do not issue concurrent writes', () async {
    final write = Completer<void>();
    database.beforeWrite = () => write.future;
    final actions = container.read(onboardingProvider.notifier);
    final result = actions.complete();
    expect(await actions.complete(), false);
    expect(database.writeCount, 1);
    write.complete();
    expect(await result, true);
    expect(await actions.complete(), true);
    expect(database.writeCount, 1);
  });
  test('disposal rejects completion of an old write', () async {
    final write = Completer<void>();
    database.beforeWrite = () => write.future;
    final result = container.read(onboardingProvider.notifier).complete();
    container.dispose();
    write.complete();
    expect(await result, false);
  });
}
