// lib/features/auth/presentation/controllers/forgot_password_controller.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/core/utils/app_toast.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/core/utils/error_handler.dart';
import 'package:ghar360/features/auth/data/auth_repository.dart';
import 'package:ghar360/features/auth/data/identifier_utils.dart';
import 'package:ghar360/features/auth/presentation/controllers/otp_resend_timer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ForgotPasswordController extends GetxController with OtpResendTimer {
  final AuthRepository _authRepository = Get.find();
  final formKey = GlobalKey<FormState>();

  final identifierController = TextEditingController();
  final otpController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  final isLoading = false.obs;
  final isPasswordVisible = false.obs;
  final isConfirmPasswordVisible = false.obs;
  final RxInt currentStep = 0.obs; // 0: identifier, 1: OTP, 2: new password
  final RxString errorMessage = ''.obs;
  final RxBool looksLikeEmail = false.obs;

  bool get isEmail => looksLikeEmail.value;

  /// Masked form of the reset target (email/phone), for display on the
  /// set-new-password step so the user can confirm which account is being reset.
  String get maskedIdentifier {
    final id = identifierController.text;
    return id.isEmpty ? '' : IdentifierUtils.mask(id);
  }

  void togglePasswordVisibility() {
    isPasswordVisible.value = !isPasswordVisible.value;
  }

  void toggleConfirmPasswordVisibility() {
    isConfirmPasswordVisible.value = !isConfirmPasswordVisible.value;
  }

  String? validateIdentifier(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) {
      return 'identifier_required'.tr;
    }
    if (IdentifierUtils.isEmail(raw) || IdentifierUtils.isPhone(raw)) {
      return null;
    }
    return 'identifier_invalid'.tr;
  }

  // Step 1: Send OTP for password reset
  Future<void> sendResetOtp() async {
    if (!formKey.currentState!.validate()) return;

    isLoading.value = true;
    errorMessage.value = '';

    try {
      final id = IdentifierUtils.normalize(identifierController.text.trim());
      if (isEmail) {
        await _authRepository.sendEmailOtp(id);
      } else {
        await _authRepository.sendPhoneOtp(id);
      }

      currentStep.value = 1; // Move to OTP step
      startOtpCountdown();

      AppToast.success('otp_sent'.tr, 'password_reset_otp_sent'.tr);

      DebugLogger.success('Password reset OTP sent to $id');
    } catch (e) {
      errorMessage.value = 'failed_to_send_otp'.tr;
      ErrorHandler.handleAuthError(e);
      DebugLogger.error('Failed to send password reset OTP', e);
    } finally {
      isLoading.value = false;
    }
  }

  // Step 2: Verify OTP and create temporary session
  Future<void> verifyResetOtp() async {
    if (otpController.text.trim().length != 6) {
      errorMessage.value = 'invalid_otp'.tr;
      return;
    }

    isLoading.value = true;
    errorMessage.value = '';

    try {
      final id = IdentifierUtils.normalize(identifierController.text.trim());
      if (isEmail) {
        await _authRepository.verifyEmailOtp(email: id, token: otpController.text.trim());
      } else {
        await _authRepository.verifyPhoneOtp(phone: id, token: otpController.text.trim());
      }

      // This creates a temporary session for password reset
      currentStep.value = 2; // Move to password reset step

      DebugLogger.success('OTP verification successful for password reset');
    } on AuthException catch (e) {
      errorMessage.value = e.message;
      ErrorHandler.handleAuthError(e);
      DebugLogger.error('OTP verification failed for password reset', e);
    } catch (e) {
      errorMessage.value = 'otp_verification_error'.tr;
      ErrorHandler.handleNetworkError(e);
      DebugLogger.error('Unexpected OTP verification error', e);
    } finally {
      isLoading.value = false;
    }
  }

  // Step 3: Update password using the temporary session
  Future<void> updatePassword() async {
    final newPassword = newPasswordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (newPassword.isEmpty) {
      errorMessage.value = 'password_required'.tr;
      return;
    }

    if (newPassword.length < 6) {
      errorMessage.value = 'password_min_length'.tr;
      return;
    }

    if (newPassword != confirmPassword) {
      errorMessage.value = 'passwords_dont_match'.tr;
      return;
    }

    isLoading.value = true;
    errorMessage.value = '';

    try {
      await _authRepository.updateUserPassword(newPassword);

      AppToast.success('success'.tr, 'password_updated_successfully'.tr);

      // Navigate to login screen
      Get.offAllNamed(AppRoutes.login);

      DebugLogger.success('Password updated successfully');
    } catch (e) {
      errorMessage.value = 'failed_to_update_password'.tr;
      ErrorHandler.handleAuthError(e);
      DebugLogger.error('Failed to update password', e);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> resendOtp() async {
    if (canResendOtp.value) {
      try {
        isLoading.value = true;
        final id = IdentifierUtils.normalize(identifierController.text.trim());
        if (isEmail) {
          await _authRepository.sendEmailOtp(id);
        } else {
          await _authRepository.sendPhoneOtp(id);
        }

        startOtpCountdown();
        AppToast.success('otp_sent'.tr, 'otp_resent_message'.tr);

        DebugLogger.info('Password reset OTP resent to $id');
      } catch (e) {
        ErrorHandler.handleAuthError(e);
        DebugLogger.error('Failed to resend password reset OTP', e);
      } finally {
        isLoading.value = false;
      }
    }
  }

  void goBackToStep(int step) {
    if (step >= 0 && step < currentStep.value) {
      currentStep.value = step;
      errorMessage.value = '';

      // Clear appropriate fields
      if (step < 1) {
        otpController.clear();
        cancelOtpTimer();
      }
      if (step < 2) {
        newPasswordController.clear();
        confirmPasswordController.clear();
      }
    }
  }

  @override
  void onInit() {
    super.onInit();
    identifierController.addListener(() {
      looksLikeEmail.value = IdentifierUtils.looksLikeEmail(identifierController.text);
    });
  }

  @override
  void onClose() {
    disposeOtpTimer();
    identifierController.dispose();
    otpController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }
}
