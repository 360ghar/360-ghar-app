import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/providers/auth_providers.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';
import 'package:ghar360/features/auth/data/auth_method.dart';
import 'package:ghar360/features/auth/presentation/controllers/phone_entry_controller.dart';
import 'package:ghar360/features/auth/presentation/widgets/auth_form_fields.dart';
import 'package:ghar360/features/auth/presentation/widgets/auth_premium_shell.dart';
import 'package:ghar360/features/auth/presentation/widgets/google_sign_in_button.dart';

class PhoneEntryView extends ConsumerStatefulWidget {
  const PhoneEntryView({super.key});
  @override
  ConsumerState<PhoneEntryView> createState() => _PhoneEntryViewState();
}

class _PhoneEntryViewState extends ConsumerState<PhoneEntryView> {
  final _form = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _focus = FocusNode();
  @override
  void dispose() {
    _identifier.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final args = await ref.read(phoneEntryProvider.notifier).checkIdentifier(_identifier.text);
    if (mounted && args != null) {
      context.push(
        authLocation(context, args.status.isNewUser ? AppRoutes.signup : AppRoutes.login),
        extra: args,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(phoneEntryProvider);
    final controller = ref.read(phoneEntryProvider.notifier);
    final repository = ref.watch(authRepositoryProvider);
    final method = repository.lastAuthMethodStore.lastMethod;
    final hint = repository.lastAuthMethodStore.lastIdentifierHint;
    final l = context.l10n;
    final methodKey = switch (method) {
      AuthMethod.google => 'auth_method_google',
      AuthMethod.apple => 'auth_method_apple',
      AuthMethod.emailPassword || AuthMethod.emailOtp => 'auth_method_email',
      _ => 'auth_method_phone',
    };
    return Semantics(
      identifier: 'qa.auth.phone_entry.screen',
      child: AuthPremiumShell(
        title: l.text('auth_entry_title'),
        subtitle: l.text('auth_entry_subtitle'),
        footer: Text(l.text('terms_footer'), textAlign: TextAlign.center),
        child: AutofillGroup(
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (method != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      l.text(
                        hint?.isNotEmpty == true
                            ? 'last_used_method_with_hint'
                            : 'last_used_method',
                        params: {'method': l.text(methodKey), 'hint': hint ?? ''},
                      ),
                    ),
                  ),
                if (repository.isAppleSignInSupported) ...[
                  Semantics(
                    identifier: 'qa.auth.apple_signin',
                    child: IgnorePointer(
                      ignoring: state.loading,
                      // The package sizes its label from the button height,
                      // so the height grows with the text size instead of
                      // the label growing past a fixed 52 px box.
                      child: MediaQuery.withNoTextScaling(
                        child: SignInWithAppleButton(
                          onPressed: controller.signInWithApple,
                          text: context.l10n.text('sign_in_with_apple'),
                          height: 52 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.5),
                          // Apple's rule: a white button on dark surfaces.
                          style: context.design.isDark
                              ? SignInWithAppleButtonStyle.white
                              : SignInWithAppleButtonStyle.black,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                GoogleSignInButton(
                  isLoading: state.loading && state.operation == 'google',
                  onPressed: state.loading ? null : controller.signInWithGoogle,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(l.text('or'), textAlign: TextAlign.center),
                ),
                Semantics(
                  identifier: 'qa.auth.phone_entry.identifier_input',
                  child: TextFormField(
                    key: const ValueKey('qa.auth.phone_entry.identifier_input'),
                    controller: _identifier,
                    focusNode: _focus,
                    autofocus: true,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.email, AutofillHints.telephoneNumber],
                    enabled: !state.loading,
                    validator: (value) => identifierValidation(context, value),
                    onFieldSubmitted: (_) => _continue(),
                    onTap: () async {
                      final hint = await phoneNumberHint();
                      if (mounted && hint != null) _identifier.text = hint;
                    },
                    onChanged: (_) => controller.clearError(),
                    decoration: InputDecoration(
                      labelText: l.text('identifier_label'),
                      hintText: l.text('identifier_hint'),
                      prefixIcon: const Padding(
                        padding: EdgeInsets.all(12),
                        child: PaperIcon(KnifeIcon.user, size: 20),
                      ),
                    ),
                  ),
                ),
                AuthFormError(
                  error: state.error,
                  fallback: state.operation == 'google'
                      ? 'google_signin_error'
                      : state.operation == 'apple'
                      ? 'apple_signin_error'
                      : 'network_error',
                ),
                const SizedBox(height: 20),
                AuthSubmitButton(
                  identifier: 'qa.auth.phone_entry.continue',
                  label: l.text('continue_btn'),
                  loading: state.loading,
                  onPressed: _continue,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
