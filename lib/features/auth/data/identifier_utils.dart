import 'package:ghar360/core/utils/formatters.dart';

// lib/features/auth/data/identifier_utils.dart

/// Helpers for auto-detecting whether a free-form identifier is an email or a
/// phone number, normalizing it for the backend / Supabase, and masking it for
/// display (e.g. last-used-method hint).
class IdentifierUtils {
  const IdentifierUtils._();

  static final RegExp _digits = RegExp(r'[0-9]');
  static final RegExp _tenDigits = RegExp(r'^[0-9]{10}$');
  static final RegExp _e164In = RegExp(r'^\+91[0-9]{10}$');

  static final RegExp _email = RegExp(
    r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$',
  );

  /// True when the trimmed [value] looks like an email address.
  static bool isEmail(String value) => _email.hasMatch(value.trim());

  /// True when the trimmed [value] looks like a (10-digit or +91) phone number.
  static bool isPhone(String value) {
    final cleaned = value.trim().replaceAll(RegExp(r'\s+'), '');
    return _tenDigits.hasMatch(cleaned) || _e164In.hasMatch(cleaned);
  }

  /// Heuristic used while the user is still typing: contains an '@' OR
  /// contains a letter → treat as email; otherwise treat as phone.
  static bool looksLikeEmail(String value) {
    final v = value.trim();
    if (v.isEmpty) return false;
    if (v.contains('@')) return true;
    // If it has any non-digit, non-plus, non-space char, lean email.
    return RegExp(r'[a-zA-Z]').hasMatch(v);
  }

  /// Normalizes the identifier into the canonical form expected by the backend
  /// and Supabase: emails are lower-cased + trimmed; phones become E.164 (+91).
  static String normalize(String value) {
    final v = value.trim();
    if (looksLikeEmail(v)) {
      return v.toLowerCase();
    }
    final cleaned = v.replaceAll(RegExp(r'\s+'), '');
    return Formatters.normalizeIndianPhone(cleaned);
  }

  /// Masks an identifier for display in last-used-method hints.
  /// Email: `j***@gmail.com`; Phone: `+91 ******1234`.
  static String mask(String value) {
    final v = value.trim();
    if (v.isEmpty) return '';
    if (v.contains('@')) {
      final parts = v.split('@');
      final local = parts.first;
      final domain = parts.length > 1 ? parts[1] : '';
      final visible = local.isNotEmpty ? local[0] : '';
      return '$visible***@$domain';
    }
    // Phone: keep the last 4 digits.
    final digitsOnly = v.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length <= 4) return v;
    final last4 = digitsOnly.substring(digitsOnly.length - 4);
    return '+91 ******$last4';
  }

  /// Returns true if [value] contains at least one digit (used for keyboard
  /// type hints in the unified field).
  static bool containsDigit(String value) => _digits.hasMatch(value);
}
