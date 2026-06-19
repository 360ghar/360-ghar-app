import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/mixins/theme_mixin.dart';
import 'package:ghar360/core/utils/app_toast.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/core/utils/error_handler.dart';
import 'package:ghar360/core/widgets/common/max_content_width.dart';
import 'package:ghar360/features/auth/data/auth_repository.dart';
import 'package:ghar360/features/profile/presentation/views/policy_page_view.dart';

class PrivacyView extends StatelessWidget with ThemeMixin {
  const PrivacyView({super.key});

  static final List<_PolicyItem> _policyItems = const [
    _PolicyItem(
      titleKey: 'privacy_terms_of_service_title',
      subtitleKey: 'privacy_terms_of_service_subtitle',
      uniqueName: 'terms-of-service',
      icon: Icons.description_outlined,
    ),
    _PolicyItem(
      titleKey: 'privacy_policy_item_title',
      subtitleKey: 'privacy_policy_item_subtitle',
      uniqueName: 'privacy-policy',
      icon: Icons.privacy_tip_outlined,
    ),
    _PolicyItem(
      titleKey: 'privacy_content_guidelines_title',
      subtitleKey: 'privacy_content_guidelines_subtitle',
      uniqueName: 'content-guidelines',
      icon: Icons.rule_folder_outlined,
    ),
    _PolicyItem(
      titleKey: 'privacy_content_takedown_title',
      subtitleKey: 'privacy_content_takedown_subtitle',
      uniqueName: 'content-takedown-policy',
      icon: Icons.remove_circle_outline,
    ),
    _PolicyItem(
      titleKey: 'privacy_grievance_redressal_title',
      subtitleKey: 'privacy_grievance_redressal_subtitle',
      uniqueName: 'grievance-redressal-mechanism',
      icon: Icons.support_agent,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return buildThemeAwareScaffold(
      title: 'privacy_security'.tr,
      body: Semantics(
        label: 'qa.profile.privacy.screen',
        identifier: 'qa.profile.privacy.screen',
        child: MaxContentWidth(
          // Center the settings cards and cap width on tablet/desktop. No-op on
          // compact (phone) widths so the phone layout is visually unchanged.
          maxWidth: 720,
          child: SingleChildScrollView(
            key: const ValueKey('qa.profile.privacy.screen'),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildThemeAwareCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      buildSectionTitle('account_security'.tr),
                      const SizedBox(height: 16),
                      _buildSecurityItem(
                        qaKey: 'qa.profile.privacy.change_password',
                        icon: Icons.lock_outline,
                        title: 'change_password'.tr,
                        subtitle: 'update_account_password'.tr,
                        onTap: _changePassword,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                buildThemeAwareCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      buildSectionTitle('policies_legal'.tr),
                      const SizedBox(height: 16),
                      ..._policyItems.map(
                        (item) => _buildPolicyItem(
                          icon: item.icon,
                          title: item.titleKey.tr,
                          subtitle: item.subtitleKey.tr,
                          uniqueName: item.uniqueName,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                buildThemeAwareCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      buildSectionTitle('account_management'.tr),
                      const SizedBox(height: 12),
                      Text(
                        'delete_account_description'.tr,
                        style: TextStyle(fontSize: 14, color: AppDesign.textSecondary, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          key: const ValueKey('qa.profile.privacy.delete_account'),
                          onPressed: _showDeleteAccountDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppDesign.errorRed,
                            foregroundColor: Theme.of(context).colorScheme.onError,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            'delete_account'.tr,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityItem({
    String? qaKey,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Semantics(
      label: qaKey,
      identifier: qaKey,
      child: ListTile(
        key: qaKey != null ? ValueKey(qaKey) : null,
        contentPadding: EdgeInsets.zero,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppDesign.primaryYellow.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppDesign.primaryYellow, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppDesign.textPrimary),
        ),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 14, color: AppDesign.textSecondary)),
        trailing: Icon(Icons.chevron_right, color: AppDesign.iconColor),
        onTap: onTap,
      ),
    );
  }

  Widget _buildPolicyItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String uniqueName,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppDesign.primaryYellow.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppDesign.primaryYellow, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppDesign.textPrimary),
      ),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 14, color: AppDesign.textSecondary)),
      trailing: Icon(Icons.arrow_forward_ios, color: AppDesign.iconColor, size: 16),
      onTap: () => _openPolicy(uniqueName, title),
    );
  }

  void _changePassword() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final currentVisible = false.obs;
    final newVisible = false.obs;
    final confirmVisible = false.obs;
    final isLoading = false.obs;
    final errorMessage = ''.obs;
    final formKey = GlobalKey<FormState>();

    Get.dialog<void>(
      Obx(
        () => AlertDialog(
          backgroundColor: AppDesign.surface,
          title: Text('change_password'.tr),
          content: SingleChildScrollView(
            child: SizedBox(
              width: (MediaQuery.of(Get.context!).size.width - 80).clamp(0.0, 420.0),
              child: Form(
                key: formKey,
                child: AutofillGroup(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Obx(
                        () => TextFormField(
                          controller: currentPasswordController,
                          obscureText: !currentVisible.value,
                          autofillHints: const [AutofillHints.password],
                          decoration: InputDecoration(
                            labelText: 'current_password'.tr,
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () => currentVisible.value = !currentVisible.value,
                              icon: Icon(
                                currentVisible.value ? Icons.visibility_off : Icons.visibility,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'password_required'.tr;
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                      Obx(
                        () => TextFormField(
                          controller: newPasswordController,
                          obscureText: !newVisible.value,
                          autofillHints: const [AutofillHints.newPassword],
                          decoration: InputDecoration(
                            labelText: 'new_password'.tr,
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () => newVisible.value = !newVisible.value,
                              icon: Icon(
                                newVisible.value ? Icons.visibility_off : Icons.visibility,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'password_required'.tr;
                            }
                            if (value.length < 8) {
                              return 'password_min_length_8'.tr;
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                      Obx(
                        () => TextFormField(
                          controller: confirmPasswordController,
                          obscureText: !confirmVisible.value,
                          autofillHints: const [AutofillHints.newPassword],
                          decoration: InputDecoration(
                            labelText: 'confirm_password'.tr,
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () => confirmVisible.value = !confirmVisible.value,
                              icon: Icon(
                                confirmVisible.value ? Icons.visibility_off : Icons.visibility,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'confirm_password_required'.tr;
                            }
                            if (value != newPasswordController.text) {
                              return 'passwords_dont_match'.tr;
                            }
                            return null;
                          },
                        ),
                      ),
                      Obx(() {
                        final error = errorMessage.value;
                        if (error.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            error,
                            style: const TextStyle(color: AppDesign.errorRed, fontSize: 13),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading.value ? null : () => Get.back(),
              child: Text('cancel'.tr, style: TextStyle(color: AppDesign.textSecondary)),
            ),
            TextButton(
              onPressed: isLoading.value
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;

                      isLoading.value = true;
                      errorMessage.value = '';

                      try {
                        final authRepository = Get.find<AuthRepository>();
                        await authRepository.updateUserPassword(newPasswordController.text);
                        Get.back();
                        AppToast.success('success'.tr, 'password_updated_successfully'.tr);
                        DebugLogger.success('Password changed from profile');
                      } catch (e) {
                        errorMessage.value = 'failed_to_update_password'.tr;
                        ErrorHandler.handleAuthError(e);
                        DebugLogger.error('Failed to change password from profile', e);
                      } finally {
                        isLoading.value = false;
                      }
                    },
              child: isLoading.value
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'update_password'.tr,
                      style: const TextStyle(
                        color: AppDesign.primaryYellow,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ],
        ),
      ),
    ).then((_) {
      currentPasswordController.dispose();
      newPasswordController.dispose();
      confirmPasswordController.dispose();
    });
  }

  void _showDeleteAccountDialog() {
    final confirmController = TextEditingController();
    const confirmWord = 'DELETE';
    final canDelete = false.obs;
    final authController = Get.find<AuthController>();

    Get.dialog<void>(
      Obx(
        () => AlertDialog(
          backgroundColor: AppDesign.surface,
          title: Text(
            'delete_account_dialog_title'.tr,
            style: const TextStyle(color: AppDesign.errorRed),
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: (MediaQuery.of(Get.context!).size.width - 80).clamp(0.0, 420.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'delete_account_dialog_content'.tr,
                    style: TextStyle(color: AppDesign.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'delete_account_type_delete_hint'.trParams({'word': confirmWord}),
                    style: TextStyle(color: AppDesign.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: confirmController,
                    autocorrect: false,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: confirmWord,
                      prefixIcon: Icon(Icons.warning_amber_rounded),
                    ),
                    onChanged: (value) =>
                        canDelete.value = value.trim().toUpperCase() == confirmWord,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: authController.isDeleting.value ? null : () => Get.back(),
              child: Text('cancel'.tr, style: TextStyle(color: AppDesign.textSecondary)),
            ),
            TextButton(
              onPressed: (authController.isDeleting.value || !canDelete.value)
                  ? null
                  : () async {
                      final deleted = await authController.deleteAccount();
                      if (deleted && (Get.isDialogOpen ?? false)) Get.back();
                    },
              child: authController.isDeleting.value
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'delete'.tr,
                      style: TextStyle(
                        color: canDelete.value ? AppDesign.errorRed : AppDesign.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ],
        ),
      ),
    ).then((_) {
      confirmController.dispose();
    });
  }

  void _openPolicy(String uniqueName, String title) {
    Get.to(() => PolicyPageView(uniqueName: uniqueName, titleText: title));
  }
}

class _PolicyItem {
  final String titleKey;
  final String subtitleKey;
  final String uniqueName;
  final IconData icon;

  const _PolicyItem({
    required this.titleKey,
    required this.subtitleKey,
    required this.uniqueName,
    required this.icon,
  });
}
