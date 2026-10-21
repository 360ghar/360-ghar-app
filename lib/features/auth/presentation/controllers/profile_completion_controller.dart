import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/providers/auth_providers.dart';
import 'package:ghar360/features/auth/data/auth_method.dart';
import 'package:ghar360/features/auth/data/identifier_utils.dart';
import 'package:ghar360/features/auth/presentation/controllers/auth_form_state.dart';

/// Applies local browse-purpose defaults after the profile preference is saved.
final profilePurposeChangedProvider = Provider<void Function(String)>((ref) => (_) {});
final profileCompletionProvider =
    NotifierProvider.autoDispose<ProfileCompletionController, AuthFormState>(
      ProfileCompletionController.new,
    );

class ProfileCompletionController extends AuthFormController {
  AuthMethod? _oauthMethod;
  String _phone = '';
  @override
  AuthFormState build() {
    ref.watch(authProvider.select((value) => value.user?.supabaseUserId));
    initializeCooldown();
    _phone = '';
    final user = ref.read(authRepositoryProvider).currentUser;
    final providers = user?.appMetadata['providers'];
    bool has(String name) =>
        user?.appMetadata['provider'] == name ||
        providers is List && providers.contains(name) ||
        (user?.identities ?? []).any((identity) => identity.provider == name);
    _oauthMethod = has('google')
        ? AuthMethod.google
        : has('apple')
        ? AuthMethod.apple
        : null;
    final hasPhone =
        user?.phone?.isNotEmpty == true || ref.read(authProvider).user?.phone?.isNotEmpty == true;
    return AuthFormState(showAddPhone: _oauthMethod != null && !hasPhone);
  }

  Future<bool> sendAddPhoneOtp(String raw) => run(() async {
    final isCurrent = captureGuard();
    final phone = IdentifierUtils.normalize(raw.trim());
    await ref.read(authRepositoryProvider).startAddPhone(phone);
    if (!isCurrent()) return;
    _phone = phone;
    if (isCurrent()) {
      state = state.copyWith(phoneOtpStage: true);
      cooldown.start();
    }
  });
  Future<bool> resendAddPhoneOtp() async => state.canResendOtp && await sendAddPhoneOtp(_phone);
  Future<bool> verifyAddPhoneOtp(String code) async {
    if (!RegExp(r'^\d{6}$').hasMatch(code.trim())) {
      invalid('invalid_otp');
      return false;
    }
    return run(() async {
      final isCurrent = captureGuard();
      final repository = ref.read(authRepositoryProvider);
      await repository.addAndVerifyPhone(phone: _phone, token: code.trim());
      if (!isCurrent()) return;
      await repository.recordLastMethod(
        _oauthMethod ?? AuthMethod.google,
        identifier: repository.currentUser?.email,
      );
      if (isCurrent()) {
        cooldown.cancel();
        state = state.copyWith(showAddPhone: false, phoneOtpStage: false);
      }
    });
  }

  Future<bool> skipAddPhone() => run(() async {
    final isCurrent = captureGuard();
    final repository = ref.read(authRepositoryProvider);
    await repository.recordLastMethod(
      _oauthMethod ?? AuthMethod.google,
      identifier: repository.currentUser?.email,
    );
    if (isCurrent()) {
      cooldown.cancel();
      state = state.copyWith(showAddPhone: false, phoneOtpStage: false);
    }
  });
  void nextStep() {
    if (!state.loading) state = state.copyWith(step: 1, clearError: true);
  }

  Future<bool> skipProfile(String purpose) async {
    final isCurrent = captureGuard();
    final session = ref.read(authProvider.notifier);
    final profiles = ref.read(profileRepositoryProvider);
    final setPurpose = ref.read(profilePurposeChangedProvider);
    final accountId = ref.read(authProvider).user?.supabaseUserId;
    return run(() async {
      await profiles.updateUserPreferences({'purpose': purpose});
      if (!isCurrent() || ref.read(authProvider).user?.supabaseUserId != accountId) return;
      setPurpose(purpose);
      session.deferProfileCompletion();
    });
  }

  /// Saves the purpose, then the profile. [email] never goes to the profile route (it takes no
  /// email): a new address is requested from Supabase, which mails a confirmation link, and the
  /// account keeps its sign-in address until the link is opened.
  Future<bool> completeProfile(
    Map<String, dynamic> profileData,
    String purpose, {
    String? email,
  }) async {
    final isCurrent = captureGuard();
    final session = ref.read(authProvider.notifier);
    final profiles = ref.read(profileRepositoryProvider);
    final setPurpose = ref.read(profilePurposeChangedProvider);
    return run(() async {
      // Persist purpose before publishing completed profile, which can dispose this screen.
      await profiles.updateUserPreferences({'purpose': purpose});
      if (!isCurrent()) return;
      setPurpose(purpose);
      final address = email?.trim();
      if (address != null && address.isNotEmpty) {
        await ref.read(authRepositoryProvider).requestEmailChange(address);
        if (!isCurrent()) return;
      }
      if (!await session.updateUserProfile(profileData)) {
        throw ref.read(authProvider).mutation.error!;
      }
    });
  }
}
