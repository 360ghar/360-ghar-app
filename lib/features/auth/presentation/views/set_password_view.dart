import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/providers/auth_providers.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';
import 'package:ghar360/features/auth/data/identifier_utils.dart';
import 'package:ghar360/features/auth/presentation/controllers/set_password_controller.dart';
import 'package:ghar360/features/auth/presentation/widgets/auth_form_fields.dart';
import 'package:ghar360/features/auth/presentation/widgets/auth_premium_shell.dart';

class SetPasswordView extends ConsumerStatefulWidget {
  const SetPasswordView({super.key});
  @override
  ConsumerState<SetPasswordView> createState() => _SetPasswordViewState();
}

class _SetPasswordViewState extends ConsumerState<SetPasswordView> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _visible = false, _confirmVisible = false;
  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(setPasswordProvider);
    final user = ref.watch(authRepositoryProvider).currentUser;
    final identifier = user?.email?.isNotEmpty == true ? user?.email : user?.phone;
    final l = context.l10n;
    return PopScope(
      canPop: false,
      child: Semantics(
        identifier: 'qa.auth.set_password.screen',
        child: AuthPremiumShell(
          title: l.text('set_password_title'),
          subtitle: l.text('set_password_subtitle'),
          child: AutofillGroup(
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (identifier != null && identifier.isNotEmpty)
                    Text(
                      l.text(
                        'set_password_for_account',
                        params: {'identifier': IdentifierUtils.mask(identifier)},
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('qa.auth.set_password.password_input'),
                    controller: _password,
                    obscureText: !_visible,
                    enabled: !state.loading,
                    autofillHints: const [AutofillHints.newPassword],
                    validator: (value) => passwordValidation(context, value),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: l.text('new_password'),
                      suffixIcon: IconButton(
                        tooltip: l.text('new_password'),
                        onPressed: () => setState(() => _visible = !_visible),
                        icon: PaperIcon(_visible ? KnifeIcon.eyeOff : KnifeIcon.eye, size: 20),
                      ),
                    ),
                  ),
                  PasswordStrength(password: _password.text),
                  TextFormField(
                    key: const ValueKey('qa.auth.set_password.confirm_input'),
                    controller: _confirm,
                    obscureText: !_confirmVisible,
                    enabled: !state.loading,
                    autofillHints: const [AutofillHints.newPassword],
                    validator: (value) => confirmPasswordValidation(context, value, _password.text),
                    decoration: InputDecoration(
                      labelText: l.text('confirm_password'),
                      suffixIcon: IconButton(
                        tooltip: l.text('confirm_password'),
                        onPressed: () => setState(() => _confirmVisible = !_confirmVisible),
                        icon: PaperIcon(
                          _confirmVisible ? KnifeIcon.eyeOff : KnifeIcon.eye,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  AuthFormError(error: state.error, fallback: 'set_password_error'),
                  const SizedBox(height: 20),
                  AuthSubmitButton(
                    identifier: 'qa.auth.set_password.submit',
                    label: l.text('set_password_cta'),
                    loading: state.loading,
                    onPressed: () {
                      if (_form.currentState?.validate() ?? false) {
                        ref.read(setPasswordProvider.notifier).submit(_password.text);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
