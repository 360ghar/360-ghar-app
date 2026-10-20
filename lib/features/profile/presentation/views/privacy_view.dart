import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/app_toast.dart';
import 'package:ghar360/core/widgets/common/loading_states.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';
import 'package:ghar360/features/auth/presentation/widgets/auth_form_fields.dart';
import 'package:ghar360/features/profile/presentation/controllers/change_password_controller.dart';
import 'package:ghar360/features/profile/presentation/widgets/profile_sheet_page.dart';

class PrivacyView extends StatelessWidget {
  const PrivacyView({super.key});
  static final List<_PolicyItem> _policyItems = const [
    _PolicyItem(
      titleKey: 'privacy_terms_of_service_title',
      subtitleKey: 'privacy_terms_of_service_subtitle',
      uniqueName: 'terms-of-service',
      icon: KnifeIcon.document,
    ),
    _PolicyItem(
      titleKey: 'privacy_policy_item_title',
      subtitleKey: 'privacy_policy_item_subtitle',
      uniqueName: 'privacy-policy',
      icon: KnifeIcon.shield,
    ),
    _PolicyItem(
      titleKey: 'privacy_content_guidelines_title',
      subtitleKey: 'privacy_content_guidelines_subtitle',
      uniqueName: 'content-guidelines',
      icon: KnifeIcon.document,
    ),
    _PolicyItem(
      titleKey: 'privacy_content_takedown_title',
      subtitleKey: 'privacy_content_takedown_subtitle',
      uniqueName: 'content-takedown-policy',
      icon: KnifeIcon.minus,
    ),
    _PolicyItem(
      titleKey: 'privacy_grievance_redressal_title',
      subtitleKey: 'privacy_grievance_redressal_subtitle',
      uniqueName: 'grievance-redressal-mechanism',
      icon: KnifeIcon.chat,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final design = context.design;
    final text = Theme.of(context).textTheme;
    Widget row({
      Key? key,
      required KnifeIcon icon,
      required String titleKey,
      required String subtitleKey,
      required VoidCallback onTap,
    }) => ListTile(
      key: key,
      contentPadding: EdgeInsets.zero,
      titleAlignment: ListTileTitleAlignment.top,
      leading: PaperIcon(icon, color: design.accent, size: 22),
      title: Text(l.text(titleKey)),
      subtitle: Text(l.text(subtitleKey)),
      trailing: PaperIcon(KnifeIcon.chevronRight, color: design.textTertiary, size: 20),
      onTap: onTap,
    );
    return ProfileSheetPage(
      title: l.text('privacy_security'),
      identifier: 'qa.profile.privacy.screen',
      maxWidth: 720,
      children: [
        SheetSectionTitle(l.text('account_security'), top: 4),
        Semantics(
          identifier: 'qa.profile.privacy.change_password',
          child: row(
            key: const ValueKey('qa.profile.privacy.change_password'),
            icon: KnifeIcon.key,
            titleKey: 'change_password',
            subtitleKey: 'update_account_password',
            onTap: () => showDialog<void>(
              context: context,
              builder: (_) => Consumer(
                builder: (_, ref, _) => _ChangePasswordDialog(
                  key: ValueKey(
                    ref.watch(authProvider.select((state) => state.user?.supabaseUserId)),
                  ),
                ),
              ),
            ),
          ),
        ),
        SheetSectionTitle(l.text('policies_legal')),
        for (final item in _policyItems)
          row(
            icon: item.icon,
            titleKey: item.titleKey,
            subtitleKey: item.subtitleKey,
            onTap: () => context.push('/policy/${item.uniqueName}', extra: l.text(item.titleKey)),
          ),
        SheetSectionTitle(l.text('account_management')),
        Text(
          l.text('delete_account_description'),
          style: text.bodyMedium?.copyWith(color: design.textSecondary),
        ),
        const SizedBox(height: 12),
        // Destructive and rare: ink in the error colour, no fill.
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            key: const ValueKey('qa.profile.privacy.delete_account'),
            style: TextButton.styleFrom(
              foregroundColor: design.error,
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            onPressed: () => showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (_) => Consumer(
                builder: (_, ref, _) => _DeleteAccountDialog(
                  key: ValueKey(
                    ref.watch(authProvider.select((state) => state.user?.supabaseUserId)),
                  ),
                ),
              ),
            ),
            icon: const PaperIcon(KnifeIcon.trash, size: 20),
            label: Text(l.text('delete_account')),
          ),
        ),
      ],
    );
  }
}

class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog({super.key});
  @override
  ConsumerState<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  final _confirmation = TextEditingController();
  @override
  void dispose() {
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authProvider);
    final l = context.l10n;
    final busy = state.mutation.isLoading;
    final confirmed = state.user != null && _confirmation.text.trim().toUpperCase() == 'DELETE';
    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        title: Text(l.text('delete_account_dialog_title')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.text('delete_account_dialog_content')),
              const SizedBox(height: 16),
              Text(l.text('delete_account_type_delete_hint', params: {'word': 'DELETE'})),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('qa.profile.privacy.delete_confirm_input'),
                controller: _confirmation,
                enabled: !busy,
                autocorrect: false,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'DELETE'),
              ),
              if (state.mutation.hasError && state.mutationKind == AuthMutation.deleteAccount)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      l.text('something_went_wrong'),
                      style: TextStyle(color: context.design.error),
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.of(context).pop(),
            child: Text(l.text('cancel')),
          ),
          // A floor keeps the button steady while busy; a fixed box would
          // clip the label at large text.
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 112, minHeight: 48),
            child: TextButton(
              key: const ValueKey('qa.profile.privacy.delete_confirm'),
              onPressed: !confirmed || busy
                  ? null
                  : () async {
                      final deleted = await ref.read(authProvider.notifier).deleteAccount();
                      if (context.mounted && deleted) Navigator.of(context).pop();
                    },
              child: busy
                  ? LoadingStates.buttonSpinner(size: 18)
                  : Text(l.text('delete'), style: TextStyle(color: context.design.error)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog({super.key});
  @override
  ConsumerState<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController(),
      _new = TextEditingController(),
      _confirm = TextEditingController();
  final _visible = [false, false, false];
  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final result = await ref
        .read(changePasswordProvider.notifier)
        .changePassword(currentPassword: _current.text, newPassword: _new.text);
    if (!mounted || result != ChangePasswordResult.success) return;
    AppToast.success(
      context.l10n.text('success'),
      context.l10n.text('password_updated_successfully'),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(changePasswordProvider);
    final l = context.l10n;
    final labels = ['current_password', 'new_password', 'confirm_password'];
    final fields = [_current, _new, _confirm];
    final errorKey = switch (state.result) {
      ChangePasswordResult.incorrectCurrent => 'incorrect_password',
      ChangePasswordResult.verificationUnavailable => 'password_verification_unavailable',
      _ => 'failed_to_update_password',
    };
    return PopScope(
      canPop: !state.loading,
      child: AlertDialog(
        title: Text(l.text('change_password')),
        content: SingleChildScrollView(
          child: Form(
            key: _form,
            child: AutofillGroup(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var index = 0; index < fields.length; index++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: TextFormField(
                        controller: fields[index],
                        enabled: !state.loading,
                        obscureText: !_visible[index],
                        autofillHints: [
                          index == 0 ? AutofillHints.password : AutofillHints.newPassword,
                        ],
                        validator: (value) => index == 2
                            ? confirmPasswordValidation(context, value, _new.text)
                            : passwordValidation(context, value, login: index == 0),
                        decoration: InputDecoration(
                          labelText: l.text(labels[index]),
                          suffixIcon: IconButton(
                            tooltip: l.text(labels[index]),
                            onPressed: () => setState(() => _visible[index] = !_visible[index]),
                            icon: PaperIcon(_visible[index] ? KnifeIcon.eyeOff : KnifeIcon.eye),
                          ),
                        ),
                      ),
                    ),
                  if (state.error != null)
                    Semantics(
                      liveRegion: true,
                      child: Text(l.text(errorKey), style: TextStyle(color: context.design.error)),
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: state.loading ? null : () => Navigator.of(context).pop(),
            child: Text(l.text('cancel')),
          ),
          TextButton(
            onPressed: state.loading ? null : _submit,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Opacity(opacity: state.loading ? 0 : 1, child: Text(l.text('update_password'))),
                if (state.loading) LoadingStates.buttonSpinner(size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicyItem {
  final String titleKey;
  final String subtitleKey;
  final String uniqueName;
  final KnifeIcon icon;

  const _PolicyItem({
    required this.titleKey,
    required this.subtitleKey,
    required this.uniqueName,
    required this.icon,
  });
}
