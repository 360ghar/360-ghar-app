// lib/features/auth/presentation/controllers/otp_resend_timer.dart

import 'dart:async';

import 'package:get/get.dart';

/// Reusable 30-second resend-OTP countdown for auth controllers.
///
/// Standardizes every OTP step (signup OTP, login OTP-first, add-phone) to a
/// 30-second cooldown after an OTP is sent: [canResendOtp] is false and
/// [otpCountdown] ticks down each second; once it reaches 0 the resend control
/// becomes enabled.
mixin OtpResendTimer on GetxController {
  /// Standard resend cooldown for all OTP steps.
  static const int resendCooldownSeconds = 30;

  final RxBool canResendOtp = false.obs;
  final RxInt otpCountdown = 0.obs;

  Timer? _otpTimer;
  bool _otpTimerDisposed = false;

  /// Starts (or restarts) the 30-second resend countdown.
  void startOtpCountdown() {
    cancelOtpTimer();
    canResendOtp.value = false;
    otpCountdown.value = resendCooldownSeconds;
    _otpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_otpTimerDisposed) {
        timer.cancel();
        return;
      }
      if (otpCountdown.value > 0) {
        otpCountdown.value--;
      }
      if (otpCountdown.value <= 0) {
        canResendOtp.value = true;
        timer.cancel();
        _otpTimer = null;
      }
    });
  }

  void cancelOtpTimer() {
    _otpTimer?.cancel();
    _otpTimer = null;
  }

  /// Call from the host controller's onClose/dispose to stop the timer.
  void disposeOtpTimer() {
    _otpTimerDisposed = true;
    cancelOtpTimer();
  }
}
