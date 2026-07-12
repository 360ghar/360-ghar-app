import 'package:get/get.dart';

/// Shared password rules so auth and profile change-password stay consistent.
class PasswordValidators {
  PasswordValidators._();

  /// Minimum length enforced app-wide (signup, login set-password, change password).
  static const int minLength = 8;

  static String? validate(String? value) {
    if (value == null || value.isEmpty) {
      return 'password_required'.tr;
    }
    if (value.length < minLength) {
      return 'password_min_length'.tr;
    }
    return null;
  }

  static String? validateConfirm(String? value, String original) {
    if (value == null || value.isEmpty) {
      return 'password_required'.tr;
    }
    if (value != original) {
      return 'passwords_dont_match'.tr;
    }
    return null;
  }
}
