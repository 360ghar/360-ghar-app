import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ghar360/core/providers/auth_providers.dart';
import 'package:ghar360/features/auth/data/identifier_utils.dart';
import 'package:ghar360/features/auth/data/models/auth_flow_args.dart';
import 'package:ghar360/features/auth/presentation/controllers/auth_form_state.dart';

final phoneEntryProvider = NotifierProvider.autoDispose<PhoneEntryController, AuthFormState>(
  PhoneEntryController.new,
);

class PhoneEntryController extends AuthFormController {
  @override
  AuthFormState build() {
    initializeRequests();
    return const AuthFormState();
  }

  Future<AuthFlowArgs?> checkIdentifier(String raw) async {
    AuthFlowArgs? result;
    await run(() async {
      final identifier = IdentifierUtils.normalize(raw.trim());
      final status = await ref.read(authRepositoryProvider).checkIdentifierStatus(identifier);
      result = AuthFlowArgs(identifier: identifier, status: status);
    }, operation: 'identifier');
    return ref.mounted ? result : null;
  }

  Future<bool> signInWithGoogle() =>
      _social('google', () => ref.read(authRepositoryProvider).signInWithGoogle());
  Future<bool> signInWithApple() =>
      _social('apple', () => ref.read(authRepositoryProvider).signInWithApple());
  Future<bool> _social(String method, Future<void> Function() action) => run(() async {
    try {
      await action();
    } on AuthException catch (error) {
      if (!error.message.toLowerCase().contains('cancel')) rethrow;
    }
  }, operation: method);
}
