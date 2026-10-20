import 'package:flutter/foundation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/providers/auth_providers.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/auth/data/auth_failure.dart';

enum ChangePasswordResult { success, incorrectCurrent, verificationUnavailable, updateFailed, busy }

@immutable
class ChangePasswordState {
  const ChangePasswordState({this.loading = false, this.error, this.result});
  final bool loading;
  final AppException? error;
  final ChangePasswordResult? result;
}

final changePasswordProvider =
    NotifierProvider.autoDispose<ChangePasswordController, ChangePasswordState>(
      ChangePasswordController.new,
    );

class ChangePasswordController extends Notifier<ChangePasswordState> {
  int _generation = 0;
  @override
  ChangePasswordState build() {
    ref.watch(authProvider.select((value) => value.user?.supabaseUserId));
    _generation++;
    ref.onDispose(() {
      _generation++;
    });
    return const ChangePasswordState();
  }

  Future<ChangePasswordResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (state.loading) return ChangePasswordResult.busy;
    final repository = ref.read(authRepositoryProvider);
    final user = repository.currentUser;
    final generation = _generation;
    bool current() =>
        ref.mounted && generation == _generation && repository.currentUser?.id == user?.id;
    state = const ChangePasswordState(loading: true);
    var result = ChangePasswordResult.verificationUnavailable;
    AppException? failure;
    try {
      final email = user?.email?.trim();
      final phone = user?.phone?.trim();
      if (email?.isNotEmpty == true) {
        await repository.signInWithEmailPassword(email!, currentPassword);
      } else if (phone?.isNotEmpty == true) {
        await repository.signInWithPhonePassword(phone!, currentPassword);
      } else {
        throw AuthenticationException(
          'Password verification is unavailable.',
          code: 'PASSWORD_VERIFICATION_UNAVAILABLE',
        );
      }
      if (!current()) return ChangePasswordResult.verificationUnavailable;
      result = ChangePasswordResult.updateFailed;
      await repository.updateUserPassword(newPassword);
      result = ChangePasswordResult.success;
    } catch (error) {
      failure = authFailure(error);
      if (result == ChangePasswordResult.verificationUnavailable &&
          failure.code != 'PASSWORD_VERIFICATION_UNAVAILABLE' &&
          failure is! NetworkException) {
        result = ChangePasswordResult.incorrectCurrent;
      }
    } finally {
      if (current()) state = ChangePasswordState(error: failure, result: result);
    }
    return current() ? result : ChangePasswordResult.verificationUnavailable;
  }
}
