import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'package:ghar360/core/controllers/localization_controller.dart';
import 'package:ghar360/core/controllers/theme_controller.dart';
import 'package:ghar360/core/utils/app_toast.dart';
import 'package:ghar360/features/profile/data/profile_repository.dart';

class PreferencesController extends GetxController {
  final GetStorage _storage = GetStorage();
  // Resolved lazily on access so onInit() can never crash on a re-init.
  ThemeController get _themeController => Get.find<ThemeController>();
  LocalizationController get _localizationController => Get.find<LocalizationController>();

  final RxBool pushNotifications = true.obs;
  final RxBool emailNotifications = true.obs;
  final RxBool similarProperties = true.obs;

  final Rx<AppThemeMode> themeMode = AppThemeMode.system.obs;

  @override
  void onInit() {
    super.onInit();
    _loadPreferences();
  }

  void _loadPreferences() {
    pushNotifications.value = _storage.read('pushNotifications') ?? true;
    emailNotifications.value = _storage.read('emailNotifications') ?? true;
    similarProperties.value = _storage.read('similarProperties') ?? true;
    themeMode.value = _themeController.currentThemeMode;
  }

  void updateTheme(AppThemeMode mode) {
    // ThemeController owns persistence (canonical string enum name).
    _themeController.setThemeMode(mode);
    themeMode.value = mode;
  }

  void updateThemeFromBoolean(bool isDark) {
    updateTheme(isDark ? AppThemeMode.dark : AppThemeMode.light);
  }

  void changeLanguage(String languageCode, String countryCode) {
    _localizationController.changeLanguage(languageCode, countryCode);
  }

  String getCurrentLanguage() {
    return _localizationController.getCurrentLanguageName();
  }

  void savePreferences() async {
    try {
      _storage.write('pushNotifications', pushNotifications.value);
      _storage.write('emailNotifications', emailNotifications.value);
      _storage.write('similarProperties', similarProperties.value);

      _themeController.setThemeMode(themeMode.value);

      // Sync notification preferences to backend (fire-and-forget)
      try {
        final profileRepository = Get.find<ProfileRepository>();
        await profileRepository.updateUserPreferences({
          'push_notifications': pushNotifications.value,
          'email_notifications': emailNotifications.value,
          'similar_properties': similarProperties.value,
        });
      } catch (_) {
        // Backend sync failure is non-critical; local save succeeded above
      }

      AppToast.success('success'.tr, 'preferences_saved'.tr);
    } catch (e) {
      AppToast.error('error'.tr, 'preferences_save_error'.tr);
    }
  }

  bool get isPushNotificationsEnabled => pushNotifications.value;
  bool get isEmailNotificationsEnabled => emailNotifications.value;
  bool get isSimilarPropertiesEnabled => similarProperties.value;
  AppThemeMode get currentThemeMode => themeMode.value;

  /// Returns translation key for current theme name
  String get currentThemeNameKey {
    switch (themeMode.value) {
      case AppThemeMode.light:
        return 'light_mode';
      case AppThemeMode.dark:
        return 'dark_mode';
      case AppThemeMode.system:
        return 'system_mode';
    }
  }

  @Deprecated('Use currentThemeNameKey with .tr for localized text')
  String get currentThemeName => currentThemeNameKey;
}
