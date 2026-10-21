// Provider containers replace global onboarding registration.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/features/splash/presentation/controllers/splash_controller.dart';
import '../../../../helpers/settings_test_database.dart';

void main() {
  test('separate app scopes use their own onboarding preferences', () async {
    final firstDb = SettingsTestDatabase();
    final secondDb = SettingsTestDatabase();
    final first = ProviderContainer(overrides: [appDatabaseProvider.overrideWithValue(firstDb)]);
    final second = ProviderContainer(overrides: [appDatabaseProvider.overrideWithValue(secondDb)]);
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    await first.read(onboardingProvider.notifier).complete();
    expect(first.read(onboardingProvider).completed, true);
    expect(second.read(onboardingProvider).completed, false);
    expect(secondDb.values, isEmpty);
  });
}
