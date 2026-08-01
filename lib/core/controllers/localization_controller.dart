import 'dart:ui';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'package:ghar360/core/utils/app_toast.dart';

class LocalizationController extends GetxController {
  final GetStorage _storage = GetStorage();

  // Supported languages
  static const List<Locale> supportedLocales = [
    Locale('en', 'US'), // English
    Locale('hi', 'IN'), // Hindi
  ];

  // Current locale
  final Rx<Locale> _currentLocale = const Locale('en', 'US').obs;
  Locale get currentLocale => _currentLocale.value;

  // Language names for display
  final Map<String, String> languageNames = {'en_US': 'English', 'hi_IN': 'हिंदी'};

  @override
  void onInit() {
    super.onInit();
    _loadLocale();
  }

  void _loadLocale() {
    String? languageCode = _storage.read('language_code');
    String? countryCode = _storage.read('country_code');

    if (languageCode != null && countryCode != null) {
      final savedLocale = Locale(languageCode, countryCode);
      _currentLocale.value = supportedLocales.firstWhere(
        (locale) => locale == savedLocale,
        orElse: () => _normalizeToSupported(savedLocale),
      );
      Get.updateLocale(_currentLocale.value);
    } else {
      // No saved preference: normalize device locale to a supported one
      final device = Get.deviceLocale;
      final normalized = _normalizeToSupported(device);
      _currentLocale.value = normalized;
      Get.updateLocale(normalized);
    }
  }

  // Map arbitrary device locales to the closest supported locale
  Locale _normalizeToSupported(Locale? device) {
    if (device == null) return const Locale('en', 'US');

    switch (device.languageCode) {
      case 'hi':
        return const Locale('hi', 'IN');
      case 'en':
        return const Locale('en', 'US');
      default:
        return const Locale('en', 'US');
    }
  }

  void changeLanguage(String languageCode, String countryCode) {
    final requestedLocale = Locale(languageCode, countryCode);
    final newLocale = supportedLocales.firstWhere(
      (locale) => locale == requestedLocale,
      orElse: () => _normalizeToSupported(requestedLocale),
    );
    _currentLocale.value = newLocale;

    // Persist the effective locale, not an unsupported request.
    _storage.write('language_code', newLocale.languageCode);
    _storage.write('country_code', newLocale.countryCode);

    // Update GetX locale
    Get.updateLocale(newLocale);

    AppToast.success('language_changed'.tr, 'language_changed_message'.tr);
  }

  String getCurrentLanguageName() {
    String localeKey = '${_currentLocale.value.languageCode}_${_currentLocale.value.countryCode}';
    return languageNames[localeKey] ?? 'English';
  }

  bool get isEnglish => _currentLocale.value.languageCode == 'en';
  bool get isHindi => _currentLocale.value.languageCode == 'hi';
}
