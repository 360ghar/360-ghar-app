import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/providers/auth_providers.dart';
import 'package:ghar360/features/auth/data/auth_method.dart';
import 'package:ghar360/features/auth/data/models/auth_flow_args.dart';
import 'package:ghar360/features/auth/presentation/controllers/auth_form_state.dart';

final signUpProvider = NotifierProvider.autoDispose
    .family<SignUpController, AuthFormState, AuthFlowArgs>(SignUpController.new);

class SignUpController extends AuthFormController {
  SignUpController(this.args);
  final AuthFlowArgs args;
  String? _pendingPassword;
  Map<String, dynamic> _userData = const {};
  @override
  AuthFormState build() {
    initializeCooldown();
    ref.onDispose(() {
      _pendingPassword = null;
    });
    return const AuthFormState();
  }

  void nextStep() {
    if (!state.loading && state.step == 0) state = state.copyWith(step: 1, clearError: true);
  }

  Future<bool> signUp({required String password, required Map<String, dynamic> userData}) =>
      run(() async {
        final repository = ref.read(authRepositoryProvider);
        _pendingPassword = password;
        _userData = Map.of(userData);
        if (args.status.isEmail) {
          await repository.signUpWithEmailOtp(args.identifier, data: _userData);
        } else {
          await repository.signUpWithPhonePassword(args.identifier, password, data: _userData);
        }
        if (ref.mounted) {
          state = state.copyWith(step: 2);
          cooldown.start();
        }
      });
  Future<bool> verifyOtp(String code) async {
    if (!RegExp(r'^\d{6}$').hasMatch(code.trim())) {
      invalid('invalid_otp');
      return false;
    }
    final session = ref.read(authProvider.notifier);
    return run(() async {
      final repository = ref.read(authRepositoryProvider);
      if (args.status.isEmail) session.markRequiresPasswordSetup();
      var verified = false;
      try {
        if (args.status.isEmail) {
          await repository.verifyEmailOtp(email: args.identifier, token: code.trim());
          verified = true;
          // The session gate remains until the password write succeeds.
          final password = _pendingPassword;
          if (password != null && password.isNotEmpty) {
            final saved = await session.completePasswordSetup(password);
            if (!saved) throw ref.read(authProvider).mutation.error!;
          }
        } else {
          await repository.verifyPhoneOtp(phone: args.identifier, token: code.trim());
          verified = true;
        }
        _pendingPassword = null;
        await repository.recordLastMethod(
          args.status.isEmail ? AuthMethod.emailPassword : AuthMethod.phonePassword,
          identifier: args.identifier,
        );
      } catch (_) {
        if (!verified && args.status.isEmail) session.clearRequiresPasswordSetup();
        rethrow;
      }
    });
  }

  Future<bool> resendOtp() async {
    if (!state.canResendOtp) return false;
    return run(() async {
      final repository = ref.read(authRepositoryProvider);
      if (args.status.isEmail) {
        await repository.signUpWithEmailOtp(args.identifier, data: _userData);
      } else {
        await repository.sendPhoneOtp(args.identifier);
      }
      if (ref.mounted) cooldown.start();
    });
  }
}
