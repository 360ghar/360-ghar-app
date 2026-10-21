import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/api_date_time.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';
import 'package:ghar360/features/auth/data/identifier_utils.dart';
import 'package:ghar360/features/auth/data/models/auth_flow_args.dart';
import 'package:ghar360/features/auth/presentation/controllers/signup_controller.dart';
import 'package:ghar360/features/auth/presentation/widgets/auth_form_fields.dart';
import 'package:ghar360/features/auth/presentation/widgets/auth_premium_shell.dart';
import 'package:ghar360/features/auth/presentation/widgets/otp_input_field.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class SignUpView extends ConsumerStatefulWidget {
  const SignUpView({super.key, this.args});
  final AuthFlowArgs? args;
  @override
  ConsumerState<SignUpView> createState() => _SignUpViewState();
}

class _SignUpViewState extends ConsumerState<SignUpView> {
  final _personalForm = GlobalKey<FormState>();
  final _securityForm = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _secondary = TextEditingController(),
      _dob = TextEditingController();
  final _password = TextEditingController(),
      _confirm = TextEditingController(),
      _otp = TextEditingController();
  DateTime? _birthDate;
  bool _visible = false, _confirmVisible = false, _terms = false;
  String? _linkError;
  @override
  void dispose() {
    for (final field in [_name, _secondary, _dob, _password, _confirm, _otp]) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _selectDate() async {
    final date = await selectBirthDate(context, _birthDate);
    if (mounted && date != null) {
      setState(() {
        _birthDate = date;
        _dob.text = formatDisplayDate(date);
      });
    }
  }

  Future<void> _termsLink() async {
    try {
      if (!await launchUrl(
            Uri.parse('https://360ghar.com/policies'),
            mode: LaunchMode.externalApplication,
          ) &&
          mounted) {
        setState(() => _linkError = 'unable_to_open_link');
      }
    } catch (_) {
      if (mounted) setState(() => _linkError = 'unable_to_open_link');
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    if (args == null) return const AuthMissingIdentifier();
    final state = ref.watch(signUpProvider(args));
    final controller = ref.read(signUpProvider(args).notifier);
    final l = context.l10n;
    return Semantics(
      identifier: 'qa.auth.signup.screen',
      child: AuthPremiumShell(
        title: l.text(
          state.step == 0
              ? 'create_account'
              : state.step == 1
              ? 'auth_signup_security_title'
              : 'verify_your_account',
        ),
        subtitle: '',
        onBack: state.loading
            ? null
            : state.step == 0
            ? () => context.go(authLocation(context, AppRoutes.phoneEntry))
            : controller.back,
        footer: state.step == 0
            ? TextButton(
                onPressed: () => context.go(authLocation(context, AppRoutes.phoneEntry)),
                child: Text('${l.text('already_have_account')} ${l.text('sign_in')}'),
              )
            : null,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(value: (state.step + 1) / 3),
              const SizedBox(height: 8),
              Text(l.text('step_of', params: {'step': '${state.step + 1}', 'total': '3'})),
              const SizedBox(height: 20),
              if (state.step == 0)
                Form(
                  key: _personalForm,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(args.identifier),
                      TextButton(
                        onPressed: () => context.go(authLocation(context, AppRoutes.phoneEntry)),
                        child: Text(l.text('change')),
                      ),
                      TextFormField(
                        key: const ValueKey('qa.auth.signup.full_name_input'),
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [AutofillHints.name],
                        validator: (value) =>
                            value?.trim().isNotEmpty == true ? null : l.text('full_name_required'),
                        decoration: InputDecoration(
                          labelText: l.text('full_name'),
                          prefixIcon: const Padding(
                            padding: EdgeInsets.all(12),
                            child: PaperIcon(KnifeIcon.user, size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const ValueKey('qa.auth.signup.secondary_identifier_input'),
                        controller: _secondary,
                        keyboardType: args.status.isEmail
                            ? TextInputType.phone
                            : TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return null;
                          return (args.status.isEmail
                                  ? IdentifierUtils.isPhone(value)
                                  : IdentifierUtils.isEmail(value))
                              ? null
                              : l.text(args.status.isEmail ? 'phone_invalid' : 'email_invalid');
                        },
                        decoration: InputDecoration(
                          labelText: l.text(
                            args.status.isEmail ? 'phone_optional' : 'email_optional',
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const ValueKey('qa.auth.signup.dob_input'),
                        controller: _dob,
                        readOnly: true,
                        onTap: _selectDate,
                        validator: (_) => _birthDate == null ? l.text('dob_required') : null,
                        decoration: InputDecoration(
                          labelText: l.text('date_of_birth'),
                          hintText: l.text('dob_format_hint'),
                          suffixIcon: const Padding(
                            padding: EdgeInsets.all(12),
                            child: PaperIcon(KnifeIcon.calendar, size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      AuthSubmitButton(
                        identifier: 'qa.auth.signup.next',
                        label: l.text('next'),
                        loading: false,
                        onPressed: () {
                          if (_personalForm.currentState?.validate() ?? false) {
                            controller.nextStep();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              if (state.step == 1)
                Form(
                  key: _securityForm,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        key: const ValueKey('qa.auth.signup.password_input'),
                        controller: _password,
                        obscureText: !_visible,
                        enabled: !state.loading,
                        autofillHints: const [AutofillHints.newPassword],
                        validator: (value) => passwordValidation(context, value),
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: l.text('password'),
                          suffixIcon: IconButton(
                            tooltip: l.text('password'),
                            onPressed: () => setState(() => _visible = !_visible),
                            icon: PaperIcon(_visible ? KnifeIcon.eyeOff : KnifeIcon.eye, size: 20),
                          ),
                        ),
                      ),
                      PasswordStrength(password: _password.text),
                      TextFormField(
                        key: const ValueKey('qa.auth.signup.confirm_password_input'),
                        controller: _confirm,
                        obscureText: !_confirmVisible,
                        enabled: !state.loading,
                        autofillHints: const [AutofillHints.newPassword],
                        validator: (value) =>
                            confirmPasswordValidation(context, value, _password.text),
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
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _terms,
                        onChanged: state.loading
                            ? null
                            : (value) => setState(() => _terms = value ?? false),
                        title: Text(l.text('i_agree_to_the')),
                      ),
                      TextButton(
                        onPressed: _termsLink,
                        child: Text(l.text('terms_and_conditions')),
                      ),
                      if (_linkError != null) AuthInlineError(message: l.text(_linkError!)),
                      AuthSubmitButton(
                        identifier: 'qa.auth.signup.submit',
                        label: l.text('create_account'),
                        loading: state.loading,
                        onPressed: () {
                          if (!(_securityForm.currentState?.validate() ?? false)) return;
                          if (!_terms) {
                            controller.invalid('terms_consent_required');
                            return;
                          }
                          controller.signUp(
                            password: _password.text,
                            userData: {
                              'full_name': _name.text.trim(),
                              'date_of_birth': dateValue(_birthDate),
                              if (args.status.isEmail)
                                'email': args.identifier
                              else if (_secondary.text.trim().isNotEmpty)
                                'email': _secondary.text.trim(),
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              if (state.step == 2) ...[
                Text(l.text('otp_sent_to', params: {'identifier': args.identifier})),
                OtpInputField(
                  controller: _otp,
                  semanticsLabel: 'qa.auth.signup.otp_input',
                  onCompleted: controller.verifyOtp,
                ),
                AuthResendButton(
                  countdown: state.otpCountdown,
                  loading: state.loading,
                  onPressed: controller.resendOtp,
                ),
                AuthSubmitButton(
                  identifier: 'qa.auth.signup.verify',
                  label: l.text('verify_otp'),
                  loading: state.loading,
                  onPressed: () => controller.verifyOtp(_otp.text),
                ),
              ],
              if ([
                'user_already_exists',
                'email_exists',
                'phone_exists',
              ].contains(state.error?.code))
                TextButton(
                  onPressed: () => context.go(authLocation(context, AppRoutes.phoneEntry)),
                  child: Text(l.text('sign_in')),
                ),
              AuthFormError(
                error: state.error,
                fallback: state.step == 2 ? 'otp_verification_error' : 'signup_error',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
