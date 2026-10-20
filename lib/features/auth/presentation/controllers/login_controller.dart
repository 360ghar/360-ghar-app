import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/providers/auth_providers.dart';
import 'package:ghar360/features/auth/data/auth_method.dart';
import 'package:ghar360/features/auth/data/models/auth_flow_args.dart';
import 'package:ghar360/features/auth/presentation/controllers/auth_form_state.dart';

enum LoginStep { password, otp }

final loginProvider = NotifierProvider.autoDispose
    .family<LoginController, AuthFormState, AuthFlowArgs>(LoginController.new);

class LoginController extends AuthFormController {
  LoginController(this.args);
  final AuthFlowArgs args;
  @override
  AuthFormState build() {
    initializeCooldown();
    if (args.status.isOtpStep) {
      Future.microtask(() {
        if (ref.mounted) unawaited(sendOtp());
      });
    }
    return AuthFormState(step: args.status.isOtpStep ? 1 : 0);
  }

  Future<bool> signIn(String password) => run(() async {
    final repository = ref.read(authRepositoryProvider);
    if (args.status.isEmail) {
      await repository.signInWithEmailPassword(args.identifier, password);
    } else {
      await repository.signInWithPhonePassword(args.identifier, password);
    }
    await repository.recordLastMethod(
      args.status.isEmail ? AuthMethod.emailPassword : AuthMethod.phonePassword,
      identifier: args.identifier,
    );
  });
  Future<bool> sendOtp() => run(() async {
    final repository = ref.read(authRepositoryProvider);
    if (args.status.isEmail) {
      await repository.sendEmailOtp(args.identifier);
    } else {
      await repository.sendPhoneOtp(args.identifier);
    }
    if (ref.mounted) cooldown.start();
  });
  Future<bool> resendOtp() async => state.canResendOtp && await sendOtp();
  Future<bool> verifyOtp(String code) async {
    if (!RegExp(r'^\d{6}$').hasMatch(code.trim())) {
      invalid('invalid_otp');
      return false;
    }
    final session = ref.read(authProvider.notifier);
    return run(() async {
      final repository = ref.read(authRepositoryProvider);
      final needsPassword = !args.status.exists || !args.status.hasPassword;
      if (needsPassword) session.markRequiresPasswordSetup();
      try {
        if (args.status.isEmail) {
          await repository.verifyEmailOtp(email: args.identifier, token: code.trim());
        } else {
          await repository.verifyPhoneOtp(phone: args.identifier, token: code.trim());
        }
        await repository.recordLastMethod(
          args.status.isEmail ? AuthMethod.emailOtp : AuthMethod.phoneOtp,
          identifier: args.identifier,
        );
      } catch (_) {
        if (needsPassword) session.clearRequiresPasswordSetup();
        rethrow;
      }
    });
  }
}
