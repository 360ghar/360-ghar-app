import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';
import 'package:ghar360/features/auth/data/models/auth_flow_args.dart';
import 'package:ghar360/features/auth/presentation/controllers/login_controller.dart';
import 'package:ghar360/features/auth/presentation/widgets/auth_form_fields.dart';
import 'package:ghar360/features/auth/presentation/widgets/auth_premium_shell.dart';
import 'package:ghar360/features/auth/presentation/widgets/otp_input_field.dart';
import 'package:go_router/go_router.dart';

class LoginView extends ConsumerStatefulWidget {
  const LoginView({super.key, this.args});
  final AuthFlowArgs? args;
  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _otp = TextEditingController();
  bool _visible = false;
  @override
  void dispose() {
    _password.dispose();
    _otp.dispose();
    super.dispose();
  }

  void _submit() {
    if (_form.currentState?.validate() ?? false) {
      ref.read(loginProvider(widget.args!).notifier).signIn(_password.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    if (args == null) return const AuthMissingIdentifier();
    final state = ref.watch(loginProvider(args));
    final controller = ref.read(loginProvider(args).notifier);
    final session = ref.watch(authProvider);
    final l = context.l10n;
    final isOtp = state.step == 1;
    return Semantics(
      identifier: 'qa.auth.login.screen',
      child: AuthPremiumShell(
        title: l.text(isOtp ? 'verify_your_account' : 'welcome_back'),
        subtitle: l.text('auth_login_subtitle'),
        onBack: () => context.go(authLocation(context, AppRoutes.phoneEntry)),
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(args.identifier),
              TextButton(
                onPressed: () => context.go(authLocation(context, AppRoutes.phoneEntry)),
                child: Text(l.text('change')),
              ),
              if (isOtp) ...[
                Text(l.text('otp_sent_to', params: {'identifier': args.identifier})),
                OtpInputField(
                  controller: _otp,
                  semanticsLabel: 'qa.auth.login.otp_input',
                  onCompleted: controller.verifyOtp,
                ),
                AuthResendButton(
                  countdown: state.otpCountdown,
                  loading: state.loading,
                  onPressed: controller.resendOtp,
                ),
                AuthSubmitButton(
                  identifier: 'qa.auth.login.verify',
                  label: l.text('verify_otp'),
                  loading: state.loading,
                  onPressed: () => controller.verifyOtp(_otp.text),
                ),
              ] else
                Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        identifier: 'qa.auth.login.password_input',
                        child: TextFormField(
                          key: const ValueKey('qa.auth.login.password_input'),
                          controller: _password,
                          autofocus: true,
                          obscureText: !_visible,
                          enabled: !state.loading,
                          autofillHints: const [AutofillHints.password],
                          textInputAction: TextInputAction.done,
                          validator: (value) => passwordValidation(context, value, login: true),
                          onFieldSubmitted: (_) => _submit(),
                          onChanged: (_) => controller.clearError(),
                          decoration: InputDecoration(
                            labelText: l.text('password'),
                            prefixIcon: const Padding(
                              padding: EdgeInsets.all(12),
                              child: PaperIcon(KnifeIcon.key, size: 20),
                            ),
                            suffixIcon: IconButton(
                              tooltip: l.text('password'),
                              onPressed: () => setState(() => _visible = !_visible),
                              icon: PaperIcon(
                                _visible ? KnifeIcon.eyeOff : KnifeIcon.eye,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Semantics(
                          identifier: 'qa.auth.login.forgot_password',
                          child: TextButton(
                            key: const ValueKey('qa.auth.login.forgot_password'),
                            onPressed: () => context.push(
                              authLocation(context, AppRoutes.forgotPassword),
                              extra: args.identifier,
                            ),
                            child: Text(l.text('forgot_password')),
                          ),
                        ),
                      ),
                      AuthSubmitButton(
                        identifier: 'qa.auth.login.submit',
                        label: l.text('sign_in'),
                        loading: state.loading,
                        onPressed: _submit,
                      ),
                    ],
                  ),
                ),
              AuthFormError(error: state.error),
              if (session.resolving)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(l.text('loading'))),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
