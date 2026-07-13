// lib/features/auth/presentation/controllers/set_password_controller.dart

import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/data/models/auth_status.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/core/utils/password_validators.dart';
import 'package:ghar360/features/auth/data/auth_method.dart';
import 'package:ghar360/features/auth/data/auth_repository.dart';
import 'package:ghar360/features/auth/data/identifier_utils.dart';

/// Mandatory (non-skippable) set-password step shown after an OTP login when
/// the account has no password yet. Closes requirement 6.
class SetPasswordController extends GetxController {
  final AuthController _authController = Get.find();
  final AuthRepository _authRepository = Get.find();
  final formKey = GlobalKey<FormState>();

  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  final isLoading = false.obs;
  final isPasswordVisible = false.obs;
  final isConfirmPasswordVisible = false.obs;
  final RxString errorMessage = ''.obs;
  final RxInt passwordStrength = 0.obs;

  /// Which password method to record on success (email_password / phone_password).
  late final AuthMethod _method;
  String? _identifier;

  /// Masked identifier of the account being secured, shown on the screen
  /// (e.g. `j***@gmail.com` / `+91 ******3210`). Empty if unknown.
  String get maskedIdentifier =>
      (_identifier == null || _identifier!.isEmpty) ? '' : IdentifierUtils.mask(_identifier!);

  @override
  void onInit() {
    super.onInit();
    passwordController.addListener(_updatePasswordStrength);

    // Derive the password method from the current Supabase session so the
    // correct last_auth_method is recorded (the navigation service routes here
    // via offAllNamed without arguments).
    final user = _authRepository.currentUser;
    final email = user?.email;
    final phone = user?.phone;
    if (email != null && email.isNotEmpty) {
      _method = AuthMethod.emailPassword;
      _identifier = email;
    } else {
      _method = AuthMethod.phonePassword;
      _identifier = phone;
    }
  }

  void togglePasswordVisibility() => isPasswordVisible.value = !isPasswordVisible.value;
  void toggleConfirmPasswordVisibility() =>
      isConfirmPasswordVisible.value = !isConfirmPasswordVisible.value;

  void _updatePasswordStrength() {
    final password = passwordController.text;
    if (password.isEmpty) {
      passwordStrength.value = 0;
      return;
    }
    int strength = 0;
    if (password.length >= PasswordValidators.minLength) strength++;
    if (password.length >= 8) strength++;
    if (RegExp(r'[A-Z]').hasMatch(password)) strength++;
    if (RegExp(r'[0-9]').hasMatch(password)) strength++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) strength++;

    if (strength <= 2) {
      passwordStrength.value = 1;
    } else if (strength <= 4) {
      passwordStrength.value = 2;
    } else {
      passwordStrength.value = 3;
    }
  }

  Future<void> submit() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    if (isLoading.value) return;

    isLoading.value = true;
    errorMessage.value = '';
    try {
      final ok = await _authController.completePasswordSetup(passwordController.text);
      if (!ok) {
        errorMessage.value = 'set_password_error'.tr;
        return;
      }
      await _authRepository.recordLastMethod(_method, identifier: _identifier);
      DebugLogger.success('Password set after OTP login (${_method.wireValue})');
      // AuthController re-evaluated status; AuthNavigationService routes onward.
    } catch (e) {
      // Defensive: completePasswordSetup already surfaces auth errors.
      if (_authController.authStatus.value == AuthStatus.requiresPasswordSetup) {
        errorMessage.value = 'set_password_error'.tr;
      }
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }
}
