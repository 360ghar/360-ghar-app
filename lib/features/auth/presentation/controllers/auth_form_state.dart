import 'package:flutter/foundation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/auth/data/auth_failure.dart';
import 'package:ghar360/features/auth/presentation/controllers/otp_resend_timer.dart';

@immutable
class AuthFormState {
  const AuthFormState({
    this.loading = false,
    this.error,
    this.step = 0,
    this.otpCountdown = 0,
    this.showAddPhone = false,
    this.phoneOtpStage = false,
    this.operation = '',
  });
  final bool loading;
  final AppException? error;
  final int step;
  final int otpCountdown;
  final bool showAddPhone;
  final bool phoneOtpStage;
  final String operation;
  bool get canResendOtp => otpCountdown == 0 && !loading;
  AuthFormState copyWith({
    bool? loading,
    AppException? error,
    bool clearError = false,
    int? step,
    int? otpCountdown,
    bool? showAddPhone,
    bool? phoneOtpStage,
    String? operation,
  }) => AuthFormState(
    loading: loading ?? this.loading,
    error: clearError ? null : error ?? this.error,
    step: step ?? this.step,
    otpCountdown: otpCountdown ?? this.otpCountdown,
    showAddPhone: showAddPhone ?? this.showAddPhone,
    phoneOtpStage: phoneOtpStage ?? this.phoneOtpStage,
    operation: operation ?? this.operation,
  );
}

/// Common request guard and countdown; form fields stay in the widget.
abstract class AuthFormController extends Notifier<AuthFormState> {
  late OtpResendTimer cooldown;
  int _generation = 0;
  void initializeRequests() {
    _generation++;
    ref.onDispose(() {
      _generation++;
    });
  }

  bool Function() captureGuard() {
    final generation = _generation;
    return () => ref.mounted && generation == _generation;
  }

  void initializeCooldown() {
    initializeRequests();
    cooldown = OtpResendTimer((seconds) {
      if (ref.mounted) state = state.copyWith(otpCountdown: seconds);
    });
    ref.onDispose(cooldown.cancel);
  }

  Future<bool> run(Future<void> Function() request, {String operation = ''}) async {
    if (state.loading) return false;
    final isCurrent = captureGuard();
    state = state.copyWith(loading: true, clearError: true, operation: operation);
    try {
      await request();
      return isCurrent();
    } catch (error) {
      if (isCurrent()) state = state.copyWith(error: authFailure(error));
      return false;
    } finally {
      if (isCurrent()) state = state.copyWith(loading: false);
    }
  }

  void clearError() {
    if (state.error != null) state = state.copyWith(clearError: true);
  }

  void invalid(String code) {
    state = state.copyWith(error: ValidationException('Check the form.', code: code));
  }

  void back() {
    if (!state.loading && state.step > 0) {
      state = state.copyWith(step: state.step - 1, clearError: true);
    }
  }
}
