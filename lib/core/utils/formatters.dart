// lib/core/utils/formatters.dart

/// Common formatter utilities used across the app.
///
/// Keep helpers pure and deterministic. Avoid side effects and UI concerns.
class Formatters {
  /// Whether [value] is usable as a positive amount: finite and strictly
  /// greater than zero. Shared by the calculator controllers for their
  /// `please_enter_valid_amounts` validation.
  static bool isPositiveFinite(num value) => value.isFinite && value > 0;

  /// Normalize Indian mobile numbers to E.164 where possible.
  ///
  /// Rules (conservative to match current behavior):
  /// - If input already starts with '+91', return as-is.
  /// - If input has exactly 10 digits, prefix with '+91'.
  /// - Otherwise, return input unchanged.
  ///
  /// Callers are expected to pass a trimmed string.
  static String normalizeIndianPhone(String phone) {
    if (phone.startsWith('+91')) {
      return phone;
    }
    if (phone.length == 10) {
      return '+91$phone';
    }
    return phone;
  }
}
