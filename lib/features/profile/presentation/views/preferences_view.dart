import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:ghar360/core/controllers/theme_controller.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/mixins/theme_mixin.dart';
import 'package:ghar360/features/profile/presentation/controllers/preferences_controller.dart';

class PreferencesView extends GetView<PreferencesController> with ThemeMixin {
  const PreferencesView({super.key});

  @override
  Widget build(BuildContext context) {
    return buildThemeAwareScaffold(
      title: 'my_preferences'.tr,
      body: Semantics(
        label: 'qa.profile.preferences.screen',
        identifier: 'qa.profile.preferences.screen',
        child: SingleChildScrollView(
          key: const ValueKey('qa.profile.preferences.screen'),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSection(context, 'property_preferences'.tr, [
                Obx(
                  () => _buildSwitchTile(
                    context,
                    'push_notifications'.tr,
                    'push_notifications_desc'.tr,
                    controller.pushNotifications.value,
                    (value) => controller.pushNotifications.value = value,
                  ),
                ),
                Obx(
                  () => _buildSwitchTile(
                    context,
                    'email_notifications'.tr,
                    'email_notifications_desc'.tr,
                    controller.emailNotifications.value,
                    (value) => controller.emailNotifications.value = value,
                  ),
                ),
                Obx(
                  () => _buildSwitchTile(
                    context,
                    'similar_properties'.tr,
                    'similar_properties_desc'.tr,
                    controller.similarProperties.value,
                    (value) => controller.similarProperties.value = value,
                  ),
                ),
              ]),
              const SizedBox(height: 24),
              _buildSection(context, 'display_preferences'.tr, [
                Obx(() => _buildThemeSelector(context)),
              ]),
              const SizedBox(height: 24),
              _buildSection(context, 'language_preferences'.tr, [
                Obx(() => _buildLanguageSelector(context)),
              ]),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                // Observed so the disabled state and spinner render while
                // preferences are being saved.
                child: Obx(
                  () => ElevatedButton(
                    key: const ValueKey('qa.profile.preferences.save'),
                    onPressed: controller.isSaving.value ? null : controller.savePreferences,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppDesign.primaryYellow,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: controller.isSaving.value
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            'save_preferences'.tr,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    BuildContext context,
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: theme.colorScheme.primary,
            activeTrackColor: theme.colorScheme.primary.withValues(alpha: 0.3),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSelector(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'select_language'.tr,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'select_language_desc'.tr,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Semantics(
            label: 'qa.profile.preferences.language_selector',
            identifier: 'qa.profile.preferences.language_selector',
            child: GestureDetector(
              key: const ValueKey('qa.profile.preferences.language_selector'),
              onTap: () => _showLanguageDialog(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: AppDesign.primaryYellow),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      controller.getCurrentLanguage(),
                      style: const TextStyle(
                        color: AppDesign.primaryYellow,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.keyboard_arrow_down, color: AppDesign.primaryYellow, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog() {
    Get.dialog(
      AlertDialog(
        title: Text('select_language'.tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLanguageOption('English', 'en', 'US'),
            const SizedBox(height: 8),
            _buildLanguageOption('हिंदी', 'hi', 'IN'),
          ],
        ),
        actions: [TextButton(onPressed: () => Get.back(), child: Text('cancel'.tr))],
      ),
    );
  }

  Widget _buildLanguageOption(String languageName, String langCode, String countryCode) {
    return ListTile(
      title: Text(languageName),
      onTap: () {
        controller.changeLanguage(langCode, countryCode);
        Get.back();
      },
      trailing: controller.getCurrentLanguage() == languageName
          ? const Icon(Icons.check, color: AppDesign.primaryYellow)
          : null,
    );
  }

  Widget _buildThemeSelector(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'app_theme'.tr,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'app_theme_desc'.tr,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Semantics(
            label: 'qa.profile.preferences.theme_selector',
            identifier: 'qa.profile.preferences.theme_selector',
            child: GestureDetector(
              key: const ValueKey('qa.profile.preferences.theme_selector'),
              onTap: () => _showThemeDialog(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: AppDesign.primaryYellow),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      controller.currentThemeNameKey.tr,
                      style: const TextStyle(
                        color: AppDesign.primaryYellow,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.keyboard_arrow_down, color: AppDesign.primaryYellow, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showThemeDialog() {
    Get.dialog(
      AlertDialog(
        title: Text('app_theme'.tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThemeOption('light_mode'.tr, AppThemeMode.light, Icons.light_mode),
            const SizedBox(height: 8),
            _buildThemeOption('dark_mode'.tr, AppThemeMode.dark, Icons.dark_mode),
            const SizedBox(height: 8),
            _buildThemeOption(
              'system_mode'.tr,
              AppThemeMode.system,
              Icons.settings_system_daydream,
            ),
          ],
        ),
        actions: [TextButton(onPressed: () => Get.back(), child: Text('cancel'.tr))],
      ),
    );
  }

  Widget _buildThemeOption(String themeName, AppThemeMode mode, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: AppDesign.primaryYellow),
      title: Text(themeName),
      onTap: () {
        controller.updateTheme(mode);
        Get.back();
      },
      trailing: controller.currentThemeMode == mode
          ? const Icon(Icons.check, color: AppDesign.primaryYellow)
          : null,
    );
  }
}
