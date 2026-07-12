// lib/features/auth/presentation/controllers/signup_controller.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/firebase/analytics_service.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/core/utils/app_toast.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/core/utils/error_handler.dart';
import 'package:ghar360/core/utils/password_validators.dart';
import 'package:ghar360/features/auth/data/auth_method.dart';
import 'package:ghar360/features/auth/data/auth_repository.dart';
import 'package:ghar360/features/auth/data/identifier_utils.dart';
import 'package:ghar360/features/auth/data/models/identifier_status.dart';
import 'package:ghar360/features/auth/presentation/controllers/otp_resend_timer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Signup for new users (identifier-status `exists == false`).
///
/// Step 0: personal info (name/email-or-phone/dob); Step 1: set password
/// (required for email/phone signup); Step 2: OTP verification.
class SignUpController extends GetxController with OtpResendTimer {
  final AuthRepository _authRepository = Get.find();
  final personalInfoFormKey = GlobalKey<FormState>();
  final securityFormKey = GlobalKey<FormState>();

  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final otpController = TextEditingController();
  final fullNameController = TextEditingController();
  // Secondary identifier field: email (when signing up by phone) OR
  // phone (when signing up by email). Optional.
  final secondaryIdentifierController = TextEditingController();
  final dateOfBirthController = TextEditingController();

  final isLoading = false.obs;
  final isPasswordVisible = false.obs;
  final isConfirmPasswordVisible = false.obs;
  final isTermsAccepted = false.obs;
  final RxInt currentStep = 0.obs; // 0: personal info, 1: security, 2: OTP
  final RxString errorMessage = ''.obs;
  final RxInt passwordStrength = 0.obs;

  /// The primary identifier (email or phone) carried from the entry screen.
  final RxString identifier = ''.obs;
  final Rx<IdentifierChannel> channel = IdentifierChannel.phone.obs;

  // OTP resend countdown (canResendOtp / otpCountdown) provided by OtpResendTimer.
  bool _disposed = false;

  /// Stored password set during signup; applied after OTP verification.
  String? _pendingPassword;

  DateTime? selectedDateOfBirth;

  bool get isEmailSignup => channel.value == IdentifierChannel.email;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is Map && args['identifier'] != null) {
      identifier.value = args['identifier'] as String;
      channel.value = (args['channel'] == 'email')
          ? IdentifierChannel.email
          : IdentifierChannel.phone;
    } else {
      DebugLogger.warning('SignUpView accessed without identifier; redirecting to entry');
      Future.microtask(() => Get.offNamed(AppRoutes.phoneEntry));
    }

    passwordController.addListener(_updatePasswordStrength);
  }

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

  /// Validator for the optional secondary identifier field.
  String? validateSecondaryIdentifier(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return null; // optional
    if (isEmailSignup) {
      // Signing up by email → secondary is a phone.
      if (!IdentifierUtils.isPhone(v)) return 'phone_invalid'.tr;
    } else {
      // Signing up by phone → secondary is an email.
      if (!IdentifierUtils.isEmail(v)) return 'email_invalid'.tr;
    }
    return null;
  }

  void togglePasswordVisibility() {
    isPasswordVisible.value = !isPasswordVisible.value;
  }

  void toggleConfirmPasswordVisibility() {
    isConfirmPasswordVisible.value = !isConfirmPasswordVisible.value;
  }

  void nextStep() {
    errorMessage.value = '';
    if (currentStep.value == 0) {
      if (personalInfoFormKey.currentState?.validate() ?? false) {
        currentStep.value = 1;
      }
    } else if (currentStep.value == 1) {
      if (securityFormKey.currentState?.validate() ?? false) {
        if (!isTermsAccepted.value) {
          errorMessage.value = 'terms_consent_required'.tr;
          return;
        }
        signUp();
      }
    }
  }

  void previousStep() {
    errorMessage.value = '';
    if (currentStep.value > 0) {
      currentStep.value--;
    }
  }

  Future<void> selectDateOfBirth() async {
    final DateTime? pickedDate = await showDatePicker(
      context: Get.context!,
      initialDate: selectedDateOfBirth ?? DateTime.now().subtract(const Duration(days: 365 * 25)),
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 100)),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 13)),
    );

    if (pickedDate != null) {
      selectedDateOfBirth = pickedDate;
      dateOfBirthController.text =
          '${pickedDate.day.toString().padLeft(2, '0')}/'
          '${pickedDate.month.toString().padLeft(2, '0')}/'
          '${pickedDate.year}';
    }
  }

  Map<String, dynamic> _buildUserData() {
    final dob = selectedDateOfBirth != null
        ? '${selectedDateOfBirth!.year.toString().padLeft(4, '0')}-'
              '${selectedDateOfBirth!.month.toString().padLeft(2, '0')}-'
              '${selectedDateOfBirth!.day.toString().padLeft(2, '0')}'
        : null;
    final secondary = secondaryIdentifierController.text.trim();
    return {
      'full_name': fullNameController.text.trim(),
      'date_of_birth': dob,
      if (isEmailSignup)
        'email': identifier.value
      else if (secondary.isNotEmpty)
        'email': secondary,
    };
  }

  Future<void> signUp() async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      final id = identifier.value;
      _pendingPassword = passwordController.text;
      final userData = _buildUserData();

      if (isEmailSignup) {
        // Sends a 6-digit OTP via Supabase Magic Link / OTP template.
        // The user is created without a password; password is set after OTP.
        await _authRepository.signUpWithEmailOtp(id, data: userData);
      } else {
        await _authRepository.signUpWithPhonePassword(id, _pendingPassword!, data: userData);
      }

      currentStep.value = 2; // Move to OTP step
      startOtpCountdown();
      AppToast.success('verify_account'.tr, 'otp_sent_message'.tr);
      DebugLogger.success('Sign up initiated');
    } on AuthException catch (e) {
      if (e.message == 'User already registered') {
        DebugLogger.warning('User already registered, redirecting to login');
        ErrorHandler.handleAuthError(e);
        Get.offNamed(
          AppRoutes.login,
          arguments: {
            'identifier': identifier.value,
            'channel': channel.value.name,
            'next_step': 'password',
            'exists': true,
            'has_password': true,
            'verified': false,
          },
        );
        return;
      }
      errorMessage.value = e.message;
      ErrorHandler.handleAuthError(e);
      DebugLogger.error('Sign up failed', e);
    } catch (e) {
      errorMessage.value = 'signup_error'.tr;
      ErrorHandler.handleNetworkError(e);
      DebugLogger.error('Unexpected signup error', e);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> verifyOtp([String? code]) async {
    final token = (code ?? otpController.text).trim();
    if (token.length != 6) {
      errorMessage.value = 'invalid_otp'.tr;
      return;
    }
    if (isLoading.value) return;

    isLoading.value = true;
    errorMessage.value = '';

    try {
      final id = identifier.value;
      if (isEmailSignup) {
        await _authRepository.verifyEmailOtp(email: id, token: token);
        // Set the password collected during signup now that OTP is verified.
        if (_pendingPassword != null && _pendingPassword!.isNotEmpty) {
          await _authRepository.updateUserPassword(_pendingPassword!);
        }
        await _authRepository.recordLastMethod(AuthMethod.emailPassword, identifier: id);
      } else {
        await _authRepository.verifyPhoneOtp(phone: id, token: token);
        await _authRepository.recordLastMethod(AuthMethod.phonePassword, identifier: id);
      }
      AnalyticsService.authOtpVerified();
      // Success! The AuthController navigates to profile completion / home.
      DebugLogger.success('OTP verification successful');
    } on AuthException catch (e) {
      errorMessage.value = e.message;
      ErrorHandler.handleAuthError(e);
      DebugLogger.error('OTP verification failed', e);
    } catch (e) {
      errorMessage.value = 'otp_verification_error'.tr;
      ErrorHandler.handleNetworkError(e);
      DebugLogger.error('Unexpected OTP verification error', e);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> resendOtp() async {
    if (!canResendOtp.value) return;
    try {
      isLoading.value = true;
      final id = identifier.value;
      if (isEmailSignup) {
        await _authRepository.signUpWithEmailOtp(id);
      } else {
        await _authRepository.sendPhoneOtp(id);
      }
      startOtpCountdown();
      AppToast.success('otp_sent'.tr, 'otp_resent_message'.tr);
      DebugLogger.info('OTP resent for signup');
    } catch (e) {
      ErrorHandler.handleAuthError(e);
      DebugLogger.error('Failed to resend OTP', e);
    } finally {
      isLoading.value = false;
    }
  }

  void goBackToForm() {
    if (currentStep.value == 2) {
      currentStep.value = 1;
    } else if (currentStep.value > 0) {
      currentStep.value--;
    }
    otpController.clear();
    errorMessage.value = '';
    cancelOtpTimer();
  }

  @override
  void onClose() {
    _disposeController();
    super.onClose();
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  void _disposeController() {
    if (_disposed) return;
    _disposed = true;
    disposeOtpTimer();
    try {
      passwordController.dispose();
      confirmPasswordController.dispose();
      otpController.dispose();
      fullNameController.dispose();
      secondaryIdentifierController.dispose();
      dateOfBirthController.dispose();
    } catch (e) {
      DebugLogger.error('Error disposing text controllers', e);
    }
  }
}
