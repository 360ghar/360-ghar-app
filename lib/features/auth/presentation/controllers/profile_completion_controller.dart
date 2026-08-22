// lib/features/auth/presentation/controllers/profile_completion_controller.dart

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/controllers/page_state_service.dart';
import 'package:ghar360/core/data/models/auth_status.dart';
import 'package:ghar360/core/firebase/analytics_service.dart';
import 'package:ghar360/core/utils/app_toast.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/core/utils/error_handler.dart';
import 'package:ghar360/features/auth/data/auth_method.dart';
import 'package:ghar360/features/auth/data/auth_repository.dart';
import 'package:ghar360/features/auth/data/identifier_utils.dart';
import 'package:ghar360/features/auth/presentation/controllers/otp_resend_timer.dart';
import 'package:ghar360/features/profile/data/profile_repository.dart';
import 'package:smart_auth/smart_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileCompletionController extends GetxController with OtpResendTimer {
  final formKey = GlobalKey<FormState>();
  final fullNameController = TextEditingController();
  final emailController = TextEditingController();
  final dateOfBirthController = TextEditingController();

  // Add-phone (Google users without a phone) capture + OTP.
  final phoneFormKey = GlobalKey<FormState>();
  final phoneController = TextEditingController();
  final phoneOtpController = TextEditingController();

  final isLoading = false.obs;
  final RxInt currentStep = 0.obs;
  final RxString selectedPropertyPurpose = 'buy'.obs;
  final List<String> propertyPurposes = ['buy', 'rent', 'short_stay'];

  /// True when a passwordless Google user has no verified phone yet → show a
  /// skippable add-phone step before the profile steps.
  final RxBool showAddPhone = false.obs;

  /// Within the add-phone step: false = enter phone, true = enter OTP.
  final RxBool isPhoneOtpStage = false.obs;
  final RxString addPhoneError = ''.obs;

  DateTime? selectedDateOfBirth;

  // Resolved lazily on access so onInit() can never crash on a re-init.
  AuthController get authController => Get.find<AuthController>();
  AuthRepository get _authRepository => Get.find<AuthRepository>();
  PageStateService? get pageStateService =>
      Get.isRegistered<PageStateService>() ? Get.find<PageStateService>() : null;

  @override
  void onInit() {
    super.onInit();
    emailController.text = authController.userEmail ?? '';
    _evaluateAddPhone();
  }

  /// The OAuth method (google/apple) the user signed in with, if any.
  /// Drives the skippable add-phone prompt and which last_auth_method to record.
  AuthMethod? _oauthMethod;

  /// Detects a passwordless OAuth (Google/Apple) user without a phone.
  void _evaluateAddPhone() {
    final supabaseUser = _authRepository.currentUser;
    final hasPhone =
        (supabaseUser?.phone?.isNotEmpty ?? false) ||
        (authController.currentUser.value?.phone?.isNotEmpty ?? false);
    _oauthMethod = _oauthMethodOf(supabaseUser);
    showAddPhone.value = _oauthMethod != null && !hasPhone;
    if (showAddPhone.value) {
      DebugLogger.auth(
        '${_oauthMethod?.wireValue} user without phone → showing skippable add-phone step',
      );
    }
  }

  AuthMethod? _oauthMethodOf(User? user) {
    if (user == null) return null;
    final providers = user.appMetadata['providers'];
    bool hasProvider(String name) {
      if (providers is List && providers.contains(name)) return true;
      if (user.appMetadata['provider'] == name) return true;
      return (user.identities ?? []).any((i) => i.provider == name);
    }

    if (hasProvider('google')) return AuthMethod.google;
    if (hasProvider('apple')) return AuthMethod.apple;
    return null;
  }

  /// last_auth_method to record for the OAuth user (defaults to google).
  AuthMethod get _oauthLastMethod => _oauthMethod ?? AuthMethod.google;

  // --- ADD-PHONE FLOW (skippable; always records the OAuth last_auth_method) ---

  String? validateAddPhone(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'phone_required'.tr;
    if (!IdentifierUtils.isPhone(v)) return 'phone_invalid'.tr;
    return null;
  }

  Future<void> requestPhoneNumberHint() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final res = await SmartAuth.instance.requestPhoneNumberHint();
      if (res.hasData && res.data != null && res.data!.isNotEmpty) {
        phoneController.text = res.data!;
      }
    } catch (e) {
      DebugLogger.debug('Phone number hint unavailable: $e');
    }
  }

  Future<void> sendAddPhoneOtp() async {
    if (!(phoneFormKey.currentState?.validate() ?? false)) return;
    await _requestAddPhoneOtp();
  }

  /// Resends the add-phone OTP once the 30s cooldown has elapsed.
  Future<void> resendAddPhoneOtp() async {
    if (!canResendOtp.value) return;
    await _requestAddPhoneOtp(isResend: true);
  }

  Future<void> _requestAddPhoneOtp({bool isResend = false}) async {
    try {
      isLoading.value = true;
      addPhoneError.value = '';
      final phone = IdentifierUtils.normalize(phoneController.text.trim());
      await _authRepository.startAddPhone(phone);
      isPhoneOtpStage.value = true;
      startOtpCountdown();
      AppToast.success('otp_sent'.tr, isResend ? 'otp_resent_message'.tr : 'otp_sent_message'.tr);
    } on AuthException catch (e) {
      addPhoneError.value = e.message;
      ErrorHandler.handleAuthError(e);
    } catch (e) {
      addPhoneError.value = 'otp_send_error'.tr;
      ErrorHandler.handleNetworkError(e);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> verifyAddPhoneOtp([String? code]) async {
    final token = (code ?? phoneOtpController.text).trim();
    if (token.length != 6) {
      addPhoneError.value = 'invalid_otp'.tr;
      return;
    }
    if (isLoading.value) return;
    try {
      isLoading.value = true;
      addPhoneError.value = '';
      final phone = IdentifierUtils.normalize(phoneController.text.trim());
      await _authRepository.addAndVerifyPhone(phone: phone, token: token);
      // Phone added: keep last_auth_method as the OAuth provider (google/apple).
      await _authRepository.recordLastMethod(
        _oauthLastMethod,
        identifier: authController.userEmail,
      );
      showAddPhone.value = false;
      isPhoneOtpStage.value = false;
      AppToast.success('success'.tr, 'phone_verified_message'.tr);
    } on AuthException catch (e) {
      addPhoneError.value = e.message;
      ErrorHandler.handleAuthError(e);
    } catch (e) {
      addPhoneError.value = 'otp_verification_error'.tr;
      ErrorHandler.handleNetworkError(e);
    } finally {
      isLoading.value = false;
    }
  }

  /// Skips the add-phone prompt. Always records the OAuth last_auth_method.
  void skipAddPhone() {
    _authRepository.recordLastMethod(_oauthLastMethod, identifier: authController.userEmail);
    showAddPhone.value = false;
    isPhoneOtpStage.value = false;
  }

  // --- PROFILE STEPS ---

  Future<void> completeProfile() async {
    if (isLoading.value) return;

    final isValid = formKey.currentState?.validate() ?? false;
    if (!isValid) {
      if (currentStep.value != 0) {
        currentStep.value = 0;
        update();
      }
      return;
    }

    try {
      isLoading.value = true;
      update();

      final profileData = {
        'full_name': fullNameController.text.trim(),
        'email': emailController.text.trim(),
        'date_of_birth': selectedDateOfBirth != null
            ? '${selectedDateOfBirth!.year.toString().padLeft(4, '0')}-'
                  '${selectedDateOfBirth!.month.toString().padLeft(2, '0')}-'
                  '${selectedDateOfBirth!.day.toString().padLeft(2, '0')}'
            : null,
      };

      final success = await authController.updateUserProfile(profileData);

      if (success) {
        // Purpose preference is a profile write, not an auth-state change.
      try {
        await Get.find<ProfileRepository>().updateUserPreferences({
          'purpose': selectedPropertyPurpose.value,
        });
      } catch (e) {
        DebugLogger.warning('Failed to persist purpose preference: $e');
      }
        AnalyticsService.authProfileCompleted();
        if (Get.isRegistered<PageStateService>()) {
          (pageStateService ?? Get.find<PageStateService>()).setPurposeForAllPages(
            selectedPropertyPurpose.value,
          );
        }
      }
    } catch (e) {
      ErrorHandler.handleNetworkError(e);
    } finally {
      isLoading.value = false;
      update();
    }
  }

  void skipToHome() {
    authController.authStatus.value = AuthStatus.authenticated;
  }

  void nextStep() {
    if (currentStep.value == 0) {
      final isValid = formKey.currentState?.validate() ?? false;
      if (!isValid) return;
    }

    if (currentStep.value < 1) {
      currentStep.value++;
      update();
    }
  }

  void previousStep() {
    if (currentStep.value > 0) {
      currentStep.value--;
      update();
    }
  }

  Future<void> selectDateOfBirth() async {
    final DateTime? pickedDate = await showDatePicker(
      context: Get.context!,
      initialDate: selectedDateOfBirth ?? DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 100)),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 13)),
    );

    if (pickedDate != null) {
      selectedDateOfBirth = pickedDate;
      dateOfBirthController.text =
          '${pickedDate.day.toString().padLeft(2, '0')}/'
          '${pickedDate.month.toString().padLeft(2, '0')}/'
          '${pickedDate.year}';

      update();
      formKey.currentState?.validate();
    }
  }

  @override
  void onClose() {
    disposeOtpTimer();
    fullNameController.dispose();
    emailController.dispose();
    dateOfBirthController.dispose();
    phoneController.dispose();
    phoneOtpController.dispose();
    super.onClose();
  }
}
