import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import 'package:smart_auth/smart_auth.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/widgets/common/loading_states.dart';
import 'package:ghar360/features/auth/data/auth_failure.dart';
import 'package:ghar360/features/auth/data/identifier_utils.dart';
import 'package:ghar360/features/auth/presentation/widgets/auth_premium_shell.dart';

String authLocation(BuildContext context, String route) {
  final from = GoRouterState.of(context).uri.queryParameters['from'];
  return Uri(path: route, queryParameters: from == null ? null : {'from': from}).toString();
}

String? identifierValidation(BuildContext context, String? value) {
  final raw = (value ?? '').trim();
  if (raw.isEmpty) return context.l10n.text('identifier_required');
  if (!IdentifierUtils.isEmail(raw) && !IdentifierUtils.isPhone(raw)) {
    return context.l10n.text('identifier_invalid');
  }
  return null;
}

String? passwordValidation(BuildContext context, String? value, {bool login = false}) {
  if (value == null || value.isEmpty) return context.l10n.text('password_required');
  if (!login && value.length < 8) return context.l10n.text('password_min_length');
  return null;
}

String? confirmPasswordValidation(BuildContext context, String? value, String original) =>
    value == null || value.isEmpty
    ? context.l10n.text('confirm_password_required')
    : value != original
    ? context.l10n.text('passwords_dont_match')
    : null;
Future<String?> phoneNumberHint() async {
  if (kIsWeb || !Platform.isAndroid) return null;
  try {
    final result = await SmartAuth.instance.requestPhoneNumberHint();
    return result.hasData ? result.data : null;
  } catch (_) {
    return null;
  }
}

Future<DateTime?> selectBirthDate(BuildContext context, DateTime? selected) {
  final now = DateTime.now();
  return showDatePicker(
    context: context,
    initialDate: selected ?? DateTime(now.year - 25, now.month, now.day),
    firstDate: DateTime(now.year - 100, now.month, now.day),
    lastDate: DateTime(now.year - 13, now.month, now.day),
  );
}

String dateDisplay(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
String? dateValue(DateTime? date) => date?.toIso8601String().split('T').first;

class AuthFormError extends StatelessWidget {
  const AuthFormError({super.key, this.error, this.fallback = 'login_error'});
  final AppException? error;
  final String fallback;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: AuthInlineError(
      message: error == null
          ? ''
          : context.l10n.text(
              error is ValidationException
                  ? error!.code ?? fallback
                  : authFailureMessageKey(error, fallback: fallback),
            ),
    ),
  );
}

class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({
    super.key,
    required this.label,
    required this.loading,
    required this.onPressed,
    this.identifier,
  });
  final String label;
  final bool loading;
  final VoidCallback? onPressed;
  final String? identifier;
  @override
  Widget build(BuildContext context) => Semantics(
    identifier: identifier,
    button: true,
    // A height floor, not a fixed height: large text must not shave the
    // Devanagari vowel signs.
    child: ConstrainedBox(
      constraints: const BoxConstraints(minWidth: double.infinity, minHeight: 56),
      child: FilledButton(
        key: identifier == null ? null : ValueKey<String>(identifier!),
        onPressed: loading ? null : onPressed,
        child: loading
            // Ink on the disabled fill: teal on it was 2.6:1 at night.
            ? LoadingStates.buttonSpinner(size: 20, color: context.design.textPrimary)
            : Text(label, textAlign: TextAlign.center),
      ),
    ),
  );
}

class AuthResendButton extends StatelessWidget {
  const AuthResendButton({
    super.key,
    required this.countdown,
    required this.loading,
    required this.onPressed,
  });
  final int countdown;
  final bool loading;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: countdown > 0 || loading ? null : onPressed,
    child: Text(
      countdown > 0
          ? '${context.l10n.text('resend_in')} ${countdown}s'
          : context.l10n.text('resend_code'),
    ),
  );
}

class AuthMissingIdentifier extends StatelessWidget {
  const AuthMissingIdentifier({super.key});
  @override
  Widget build(BuildContext context) => AuthPremiumShell(
    title: context.l10n.text('auth_entry_title'),
    subtitle: '',
    child: AuthSubmitButton(
      label: context.l10n.text('continue_btn'),
      loading: false,
      onPressed: () => context.go(authLocation(context, AppRoutes.phoneEntry)),
    ),
  );
}

class PasswordStrength extends StatelessWidget {
  const PasswordStrength({super.key, required this.password});
  final String password;
  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();
    final score = [
      password.length >= 8,
      RegExp(r'[A-Z]').hasMatch(password),
      RegExp(r'[0-9]').hasMatch(password),
      RegExp(r'[^a-zA-Z0-9]').hasMatch(password),
    ].where((v) => v).length;
    final key = score <= 1
        ? 'password_strength_weak'
        : score < 4
        ? 'password_strength_medium'
        : 'password_strength_strong';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(context.l10n.text(key)),
    );
  }
}
