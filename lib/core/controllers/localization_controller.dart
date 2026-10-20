import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/storage_keys.dart';

@immutable
class LocaleSettings {
  const LocaleSettings({required this.locale, this.persistence = const AsyncData(null)});
  final Locale locale;
  final AsyncValue<void> persistence;
  String get languageName => locale.languageCode == 'hi' ? 'हिंदी' : 'English';
}

final deviceLocaleProvider = Provider<Locale>((ref) => PlatformDispatcher.instance.locale);
final localizationProvider = NotifierProvider<LocalizationController, LocaleSettings>(
  LocalizationController.new,
);

class LocalizationController extends Notifier<LocaleSettings> {
  static const supportedLocales = AppLocalizations.supportedLocales;
  late AppDatabase _database;
  Locale? _requestedLocale;

  @override
  LocaleSettings build() {
    _database = ref.watch(appDatabaseProvider);
    final language = _database.readPreference<String>(StorageKeys.languageCode);
    final country = _database.readPreference<String>(StorageKeys.countryCode);
    return LocaleSettings(
      locale: normalize(
        language != null && country != null
            ? Locale(language, country)
            : ref.watch(deviceLocaleProvider),
      ),
    );
  }

  static Locale normalize(Locale locale) =>
      locale.languageCode == 'hi' ? const Locale('hi', 'IN') : const Locale('en', 'US');

  Future<bool> changeLanguage(String languageCode, String countryCode) async {
    if (state.persistence.isLoading) return false;
    final locale = normalize(Locale(languageCode, countryCode));
    _requestedLocale = locale;
    state = LocaleSettings(locale: state.locale, persistence: const AsyncLoading());
    try {
      await _database.writePreferences({
        StorageKeys.languageCode: locale.languageCode,
        StorageKeys.countryCode: locale.countryCode,
      });
      if (!ref.mounted) return false;
      state = LocaleSettings(locale: locale);
      return true;
    } catch (error, stack) {
      if (ref.mounted) {
        state = LocaleSettings(locale: state.locale, persistence: AsyncError(error, stack));
      }
      return false;
    }
  }

  Future<bool> retry() {
    final locale = _requestedLocale ?? state.locale;
    return changeLanguage(locale.languageCode, locale.countryCode ?? '');
  }
}
