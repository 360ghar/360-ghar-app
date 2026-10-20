import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/providers/auth_providers.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/auth/data/identifier_utils.dart';
import 'package:ghar360/features/auth/presentation/controllers/auth_form_state.dart';

final forgotPasswordProvider =
    NotifierProvider.autoDispose<ForgotPasswordController, AuthFormState>(
      ForgotPasswordController.new,
    );

class ForgotPasswordController extends AuthFormController {
  String _identifier = '';
  @override
  AuthFormState build() {
    initializeCooldown();
    return const AuthFormState();
  }

  Future<bool> sendResetOtp(String raw) => run(() async {
    final repository = ref.read(authRepositoryProvider);
    final identifier = IdentifierUtils.normalize(raw.trim());
    final status = await repository.checkIdentifierStatus(identifier);
    if (!status.exists) {
      throw ValidationException('Account not found.', code: 'no_account_found_error');
    }
    if (status.isEmail) {
      await repository.sendEmailOtp(identifier);
    } else {
      await repository.sendPhoneOtp(identifier);
    }
    _identifier = identifier;
    if (ref.mounted) {
      state = state.copyWith(step: 1);
      cooldown.start();
    }
  });
  Future<bool> verifyResetOtp(String code) async {
    if (!RegExp(r'^\d{6}$').hasMatch(code.trim())) {
      invalid('invalid_otp');
      return false;
    }
    final session = ref.read(authProvider.notifier);
    return run(() async {
      final repository = ref.read(authRepositoryProvider);
      session.markRequiresPasswordSetup();
      try {
        if (IdentifierUtils.isEmail(_identifier)) {
          await repository.verifyEmailOtp(email: _identifier, token: code.trim());
        } else {
          await repository.verifyPhoneOtp(phone: _identifier, token: code.trim());
        }
        // Router now sends this verified session to the mandatory password screen.
        if (ref.mounted) state = state.copyWith(step: 2);
      } catch (_) {
        session.clearRequiresPasswordSetup();
        rethrow;
      }
    });
  }

  Future<bool> updatePassword(String password) async {
    final session = ref.read(authProvider.notifier);
    return run(() async {
      if (!await session.completePasswordSetup(password)) {
        throw ref.read(authProvider).mutation.error!;
      }
    });
  }

  Future<bool> resendOtp() async {
    if (!state.canResendOtp) return false;
    return run(() async {
      final repository = ref.read(authRepositoryProvider);
      if (IdentifierUtils.isEmail(_identifier)) {
        await repository.sendEmailOtp(_identifier);
      } else {
        await repository.sendPhoneOtp(_identifier);
      }
      if (ref.mounted) cooldown.start();
    });
  }
}
