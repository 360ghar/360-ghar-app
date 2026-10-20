import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/providers/auth_providers.dart';
import 'package:ghar360/features/auth/data/auth_method.dart';
import 'package:ghar360/features/auth/presentation/controllers/auth_form_state.dart';

final setPasswordProvider = NotifierProvider.autoDispose<SetPasswordController, AuthFormState>(
  SetPasswordController.new,
);

class SetPasswordController extends AuthFormController {
  @override
  AuthFormState build() {
    ref.watch(authProvider.select((value) => value.user?.supabaseUserId));
    initializeRequests();
    return const AuthFormState();
  }

  Future<bool> submit(String password) async {
    final session = ref.read(authProvider.notifier);
    final repository = ref.read(authRepositoryProvider);
    final user = repository.currentUser;
    return run(() async {
      if (!await session.completePasswordSetup(password)) {
        throw ref.read(authProvider).mutation.error!;
      }
      await repository.recordLastMethod(
        user?.email?.isNotEmpty == true ? AuthMethod.emailPassword : AuthMethod.phonePassword,
        identifier: user?.email?.isNotEmpty == true ? user?.email : user?.phone,
      );
    });
  }
}
