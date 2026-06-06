import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/mixins/theme_mixin.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/network/api_paths.dart';
import 'package:ghar360/core/utils/app_toast.dart';
import 'package:ghar360/features/profile/presentation/views/policy_page_view.dart';

class PrivacyView extends StatelessWidget with ThemeMixin {
  const PrivacyView({super.key});

  static const String _supportEmail = 'info@360ghar.com';
  static const String _deletionRequestSubject = 'Account Deletion Request';

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
    AppToast.info('change_password_snackbar_title'.tr, 'change_password_snackbar_message'.tr);
  }

  void _showDeleteAccountDialog() {
    final AuthController authController = Get.find<AuthController>();
    final String registeredEmail =
        authController.userEmail ?? authController.currentUser.value?.email ?? 'Not available';

    Get.dialog(
      AlertDialog(
        backgroundColor: AppDesign.surface,
        title: Text(
          'delete_account_dialog_title'.tr,
          style: const TextStyle(color: AppDesign.errorRed),
        ),
        content: Text(
          'delete_account_dialog_content'.tr,
          style: TextStyle(color: AppDesign.textSecondary),
        ),
        actions: [
          TextButton(
            key: const ValueKey('qa.profile.privacy.delete_account.cancel'),
            onPressed: () => Get.back(),
            child: Text('cancel'.tr, style: TextStyle(color: AppDesign.textSecondary)),
          ),
          TextButton(
            key: const ValueKey('qa.profile.privacy.delete_account.confirm'),
            onPressed: () {
              Get.back();
              _sendDeletionEmail(registeredEmail);
            },
            child: Text('delete'.tr, style: const TextStyle(color: AppDesign.errorRed)),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  Future<void> _sendDeletionEmail(String registeredEmail) async {
    final String body = 'Hello 360 Ghar Support,\n\n'
        'I would like to request the deletion of my account.\n\n'
        'Registered email: $registeredEmail\n\n'
        'Thank you.';

    final Uri mailtoUri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      queryParameters: <String, String>{
        'subject': _deletionRequestSubject,
        'body': body,
      },
    );

    try {
      final bool launched = await launchUrl(mailtoUri, mode: LaunchMode.externalApplication);
      if (launched) {
        AppToast.success(
          'delete_account_request_initiated'.tr,
          'delete_account_email_body'.tr,
        );
      } else {
        AppToast.error(
          'Could not open email',
          'Please email $_supportEmail with subject "$_deletionRequestSubject"',
        );
      }
    } catch (_) {
      AppToast.error(
        'Could not open email',
        'Please email $_supportEmail with subject "$_deletionRequestSubject"',
      );
    }
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
