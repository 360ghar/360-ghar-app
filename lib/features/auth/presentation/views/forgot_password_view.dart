import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';
import 'package:ghar360/features/auth/presentation/controllers/forgot_password_controller.dart';
import 'package:ghar360/features/auth/presentation/widgets/auth_form_fields.dart';
import 'package:ghar360/features/auth/presentation/widgets/auth_premium_shell.dart';
import 'package:ghar360/features/auth/presentation/widgets/otp_input_field.dart';
import 'package:go_router/go_router.dart';

class ForgotPasswordView extends ConsumerStatefulWidget {
  const ForgotPasswordView({super.key, this.identifier});
  final String? identifier;
  @override
  ConsumerState<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends ConsumerState<ForgotPasswordView> {
  final _form = GlobalKey<FormState>();
  late final _identifier = TextEditingController(text: widget.identifier);
  final _otp = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _visible = false;
  @override
  void dispose() {
    _identifier.dispose();
    _otp.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(forgotPasswordProvider);
    final controller = ref.read(forgotPasswordProvider.notifier);
    final l = context.l10n;
    return Semantics(
      identifier: 'qa.auth.forgot_password.screen',
      child: AuthPremiumShell(
        title: l.text(
          state.step == 0
              ? 'reset_password'
              : state.step == 1
              ? 'enter_otp'
              : 'set_new_password',
        ),
        subtitle: l.text('reset_password_subtitle'),
        onBack: state.step > 0 && state.step != 2
            ? controller.back
            : () => context.go(authLocation(context, AppRoutes.phoneEntry)),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state.step == 0)
                Semantics(
                  identifier: 'qa.auth.forgot_password.identifier_input',
                  child: TextFormField(
                    controller: _identifier,
                    key: const ValueKey('qa.auth.forgot_password.identifier_input'),
                    keyboardType: TextInputType.emailAddress,
                    enabled: !state.loading,
                    autofillHints: const [AutofillHints.email, AutofillHints.telephoneNumber],
                    validator: (value) => identifierValidation(context, value),
                    decoration: InputDecoration(
                      labelText: l.text('identifier_label'),
                      hintText: l.text('identifier_hint'),
                    ),
                  ),
                ),
              if (state.step == 1) ...[
                OtpInputField(
                  controller: _otp,
                  semanticsLabel: 'qa.auth.forgot_password.otp_input',
                  onCompleted: controller.verifyResetOtp,
                ),
                AuthResendButton(
                  countdown: state.otpCountdown,
                  loading: state.loading,
                  onPressed: controller.resendOtp,
                ),
              ],
              if (state.step == 2) ...[
                TextFormField(
                  controller: _password,
                  obscureText: !_visible,
                  validator: (value) => passwordValidation(context, value),
                  decoration: InputDecoration(
                    labelText: l.text('new_password'),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _visible = !_visible),
                      icon: PaperIcon(_visible ? KnifeIcon.eyeOff : KnifeIcon.eye, size: 20),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirm,
                  obscureText: !_visible,
                  validator: (value) => confirmPasswordValidation(context, value, _password.text),
                  decoration: InputDecoration(labelText: l.text('confirm_password')),
                ),
              ],
              AuthFormError(
                error: state.error,
                fallback: state.step == 0
                    ? 'failed_to_send_otp'
                    : state.step == 1
                    ? 'otp_verification_error'
                    : 'failed_to_update_password',
              ),
              const SizedBox(height: 20),
              AuthSubmitButton(
                identifier: 'qa.auth.forgot_password.submit',
                label: l.text(
                  state.step == 0
                      ? 'send_otp'
                      : state.step == 1
                      ? 'verify_otp'
                      : 'update_password',
                ),
                loading: state.loading,
                onPressed: () {
                  if (!(_form.currentState?.validate() ?? false)) return;
                  if (state.step == 0) {
                    controller.sendResetOtp(_identifier.text);
                  } else if (state.step == 1) {
                    controller.verifyResetOtp(_otp.text);
                  } else {
                    controller.updatePassword(_password.text);
                  }
                },
              ),
              TextButton(
                onPressed: () => context.go(authLocation(context, AppRoutes.phoneEntry)),
                child: Text(l.text('back_to_login')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
