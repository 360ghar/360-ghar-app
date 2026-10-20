import 'package:flutter/material.dart';

import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/widgets/common/error_states.dart';
import 'package:ghar360/features/auth/data/auth_failure.dart';

/// Localized text for the server's first validation error on [field]
/// (`ValidationException.fieldErrors`, keyed by the request field), or null.
/// Nested keys count too: `preferences.location` belongs to `preferences`.
String? serverFieldError(BuildContext context, Object? error, String field) {
  if (error is! ValidationException) return null;
  final types = [
    for (final MapEntry(:key, :value) in (error.fieldErrors ?? const {}).entries)
      if (key == field || key.startsWith('$field.')) ...value,
  ];
  if (types.isEmpty) return null;
  final type = types.first;
  return context.l10n.text(
    type == 'missing'
        ? 'field_error_required'
        : type.contains('too_long')
        ? 'field_error_too_long'
        : 'field_error_invalid',
  );
}

/// The form-level failure line under a profile form. Field errors point to
/// the marked fields; other failures use their localized text.
class ProfileFormError extends StatelessWidget {
  const ProfileFormError({super.key, required this.error, required this.fallback});
  final AppException? error;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    final failure = error;
    if (failure == null) return const SizedBox.shrink();
    final key = switch (failure) {
      ValidationException(fieldErrors: final fields?) when fields.isNotEmpty => 'form_check_fields',
      ValidationException() => fallback,
      _ => authFailureMessageKey(failure, fallback: fallback),
    };
    return KeyedSubtree(
      key: const ValueKey('qa.profile.form_error'),
      child: ErrorStates.inlineError(message: context.l10n.text(key)),
    );
  }
}
