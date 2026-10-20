import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/profile/presentation/controllers/change_password_controller.dart';
import '../../../../helpers/auth_test_harness.dart' show MockAuthRepository;
import '../../../../helpers/profile_test_harness.dart';

class _FakeUser extends Fake implements User {
  _FakeUser({this.email, this.phone});
  @override
  final String? email;
  @override
  final String? phone;
  @override
  String get id => 'user-1';
}

void main() {
  late ProfileHarness h;
  late MockAuthRepository auth;
  late ChangePasswordController controller;
  late _FakeUser user;

  setUp(() {
    h = ProfileHarness();
    auth = h.repository;
    h.listen(changePasswordProvider);
    controller = h.container.read(changePasswordProvider.notifier);
    user = _FakeUser(email: 'a@b.com');
  });

  tearDown(() => h.close());

  group('ChangePasswordController', () {
    test('success path verifies email then updates password', () async {
      when(() => auth.currentUser).thenReturn(user);
      when(
        () => auth.signInWithEmailPassword('a@b.com', 'old-pass'),
      ).thenAnswer((_) async => AuthResponse(user: user));
      when(() => auth.updateUserPassword('new-pass-1')).thenAnswer((_) async => user);

      final result = await controller.changePassword(
        currentPassword: 'old-pass',
        newPassword: 'new-pass-1',
      );

      expect(result, ChangePasswordResult.success);
      verify(() => auth.signInWithEmailPassword('a@b.com', 'old-pass')).called(1);
      verify(() => auth.updateUserPassword('new-pass-1')).called(1);
    });

    test('incorrect current password', () async {
      when(() => auth.currentUser).thenReturn(user);
      when(
        () => auth.signInWithEmailPassword('a@b.com', 'wrong'),
      ).thenThrow(Exception('Invalid login credentials'));

      final result = await controller.changePassword(
        currentPassword: 'wrong',
        newPassword: 'new-pass-1',
      );

      expect(result, ChangePasswordResult.incorrectCurrent);
      verifyNever(() => auth.updateUserPassword(any()));
    });

    test('verification unavailable without email or phone', () async {
      when(() => auth.currentUser).thenReturn(_FakeUser());

      final result = await controller.changePassword(
        currentPassword: 'x',
        newPassword: 'new-pass-1',
      );

      expect(result, ChangePasswordResult.verificationUnavailable);
    });

    // ── updateFailed when password update throws ──────────────────────────

    test('updateFailed when updateUserPassword throws', () async {
      when(() => auth.currentUser).thenReturn(user);
      when(
        () => auth.signInWithEmailPassword('a@b.com', 'old-pass'),
      ).thenAnswer((_) async => AuthResponse(user: user));
      when(() => auth.updateUserPassword('new-pass')).thenThrow(Exception('Update failed'));

      final result = await controller.changePassword(
        currentPassword: 'old-pass',
        newPassword: 'new-pass',
      );

      expect(result, ChangePasswordResult.updateFailed);
    });

    // ── Phone-based verification ──────────────────────────────────────────

    test('success path verifies via phone then updates password', () async {
      final phoneUser = _FakeUser(phone: '+919876543210');
      when(() => auth.currentUser).thenReturn(phoneUser);
      when(
        () => auth.signInWithPhonePassword('+919876543210', 'old-pass'),
      ).thenAnswer((_) async => AuthResponse(user: phoneUser));
      when(() => auth.updateUserPassword('new-pass')).thenAnswer((_) async => phoneUser);

      final result = await controller.changePassword(
        currentPassword: 'old-pass',
        newPassword: 'new-pass',
      );

      expect(result, ChangePasswordResult.success);
      verify(() => auth.signInWithPhonePassword('+919876543210', 'old-pass')).called(1);
      verify(() => auth.updateUserPassword('new-pass')).called(1);
    });

    // ── Phone-based verification failure ──────────────────────────────────

    test('incorrect password via phone returns incorrectCurrent', () async {
      final phoneUser = _FakeUser(phone: '+919876543210');
      when(() => auth.currentUser).thenReturn(phoneUser);
      when(
        () => auth.signInWithPhonePassword('+919876543210', 'wrong'),
      ).thenThrow(Exception('Invalid credentials'));

      final result = await controller.changePassword(
        currentPassword: 'wrong',
        newPassword: 'new-pass',
      );

      expect(result, ChangePasswordResult.incorrectCurrent);
      verifyNever(() => auth.updateUserPassword(any()));
    });

    // ── isLoading toggles correctly ───────────────────────────────────────

    test('isLoading is true during operation and false after', () async {
      final completer = Completer<AuthResponse>();
      when(() => auth.currentUser).thenReturn(user);
      when(
        () => auth.signInWithEmailPassword('a@b.com', 'old-pass'),
      ).thenAnswer((_) => completer.future);
      when(() => auth.updateUserPassword('new-pass')).thenAnswer((_) async => user);

      final future = controller.changePassword(
        currentPassword: 'old-pass',
        newPassword: 'new-pass',
      );

      // While the signIn is pending, isLoading should be true
      expect(h.container.read(changePasswordProvider).loading, isTrue);

      completer.complete(AuthResponse(user: user));
      await future;

      expect(h.container.read(changePasswordProvider).loading, isFalse);
    });

    // ── isLoading reset on error ──────────────────────────────────────────

    test('isLoading is false after error', () async {
      when(() => auth.currentUser).thenReturn(user);
      when(
        () => auth.signInWithEmailPassword('a@b.com', 'wrong'),
      ).thenThrow(Exception('Invalid credentials'));

      await controller.changePassword(currentPassword: 'wrong', newPassword: 'new-pass');

      expect(h.container.read(changePasswordProvider).loading, isFalse);
    });

    // ── errorMessage is set on incorrect password ─────────────────────────

    test('errorMessage is set on incorrect password', () async {
      when(() => auth.currentUser).thenReturn(user);
      when(
        () => auth.signInWithEmailPassword('a@b.com', 'wrong'),
      ).thenThrow(Exception('Invalid credentials'));

      await controller.changePassword(currentPassword: 'wrong', newPassword: 'new-pass');

      expect(h.container.read(changePasswordProvider).error?.message ?? '', isNotEmpty);
    });

    // ── errorMessage is set on verification unavailable ───────────────────

    test('errorMessage is set on verification unavailable', () async {
      when(() => auth.currentUser).thenReturn(_FakeUser());

      await controller.changePassword(currentPassword: 'x', newPassword: 'new-pass');

      expect(h.container.read(changePasswordProvider).error?.message ?? '', isNotEmpty);
    });

    // ── errorMessage is set on update failed ──────────────────────────────

    test('errorMessage is set on update failed', () async {
      when(() => auth.currentUser).thenReturn(user);
      when(
        () => auth.signInWithEmailPassword('a@b.com', 'old-pass'),
      ).thenAnswer((_) async => AuthResponse(user: user));
      when(() => auth.updateUserPassword('new-pass')).thenThrow(Exception('Update failed'));

      await controller.changePassword(currentPassword: 'old-pass', newPassword: 'new-pass');

      expect(h.container.read(changePasswordProvider).error?.message ?? '', isNotEmpty);
    });

    // ── errorMessage is cleared on new attempt ────────────────────────────

    test('errorMessage is cleared at start of new attempt', () async {
      when(() => auth.currentUser).thenReturn(user);
      when(
        () => auth.signInWithEmailPassword('a@b.com', 'wrong'),
      ).thenThrow(Exception('Invalid credentials'));

      // First attempt fails
      await controller.changePassword(currentPassword: 'wrong', newPassword: 'new-pass');
      expect(h.container.read(changePasswordProvider).error?.message ?? '', isNotEmpty);

      // Second attempt succeeds
      when(
        () => auth.signInWithEmailPassword('a@b.com', 'old-pass'),
      ).thenAnswer((_) async => AuthResponse(user: user));
      when(() => auth.updateUserPassword('new-pass')).thenAnswer((_) async => user);

      final result = await controller.changePassword(
        currentPassword: 'old-pass',
        newPassword: 'new-pass',
      );

      expect(result, ChangePasswordResult.success);
      expect(h.container.read(changePasswordProvider).error?.message ?? '', isEmpty);
    });

    // ── Email with whitespace is trimmed ──────────────────────────────────

    test('email is trimmed before verification', () async {
      final whitespaceUser = _FakeUser(email: '  a@b.com  ');
      when(() => auth.currentUser).thenReturn(whitespaceUser);
      when(
        () => auth.signInWithEmailPassword('a@b.com', 'old-pass'),
      ).thenAnswer((_) async => AuthResponse(user: whitespaceUser));
      when(() => auth.updateUserPassword('new-pass')).thenAnswer((_) async => whitespaceUser);

      final result = await controller.changePassword(
        currentPassword: 'old-pass',
        newPassword: 'new-pass',
      );

      expect(result, ChangePasswordResult.success);
      verify(() => auth.signInWithEmailPassword('a@b.com', 'old-pass')).called(1);
    });

    // ── Phone with whitespace is trimmed ──────────────────────────────────

    test('phone is trimmed before verification', () async {
      final whitespaceUser = _FakeUser(phone: '  +919876543210  ');
      when(() => auth.currentUser).thenReturn(whitespaceUser);
      when(
        () => auth.signInWithPhonePassword('+919876543210', 'old-pass'),
      ).thenAnswer((_) async => AuthResponse(user: whitespaceUser));
      when(() => auth.updateUserPassword('new-pass')).thenAnswer((_) async => whitespaceUser);

      final result = await controller.changePassword(
        currentPassword: 'old-pass',
        newPassword: 'new-pass',
      );

      expect(result, ChangePasswordResult.success);
      verify(() => auth.signInWithPhonePassword('+919876543210', 'old-pass')).called(1);
    });

    // ── Email takes priority over phone ───────────────────────────────────

    test('email is used for verification when both email and phone exist', () async {
      final bothUser = _FakeUser(email: 'a@b.com', phone: '+919876543210');
      when(() => auth.currentUser).thenReturn(bothUser);
      when(
        () => auth.signInWithEmailPassword('a@b.com', 'old-pass'),
      ).thenAnswer((_) async => AuthResponse(user: bothUser));
      when(() => auth.updateUserPassword('new-pass')).thenAnswer((_) async => bothUser);

      final result = await controller.changePassword(
        currentPassword: 'old-pass',
        newPassword: 'new-pass',
      );

      expect(result, ChangePasswordResult.success);
      verify(() => auth.signInWithEmailPassword('a@b.com', 'old-pass')).called(1);
      verifyNever(() => auth.signInWithPhonePassword(any(), any()));
    });

    // ── Empty email falls back to phone ───────────────────────────────────

    test('empty email falls back to phone verification', () async {
      final phoneUser = _FakeUser(email: '', phone: '+919876543210');
      when(() => auth.currentUser).thenReturn(phoneUser);
      when(
        () => auth.signInWithPhonePassword('+919876543210', 'old-pass'),
      ).thenAnswer((_) async => AuthResponse(user: phoneUser));
      when(() => auth.updateUserPassword('new-pass')).thenAnswer((_) async => phoneUser);

      final result = await controller.changePassword(
        currentPassword: 'old-pass',
        newPassword: 'new-pass',
      );

      expect(result, ChangePasswordResult.success);
      verifyNever(() => auth.signInWithEmailPassword(any(), any()));
      verify(() => auth.signInWithPhonePassword('+919876543210', 'old-pass')).called(1);
    });

    // ── Null currentUser returns verificationUnavailable ──────────────────

    test('null currentUser returns verificationUnavailable', () async {
      when(() => auth.currentUser).thenReturn(null);

      final result = await controller.changePassword(currentPassword: 'x', newPassword: 'new-pass');

      expect(result, ChangePasswordResult.verificationUnavailable);
    });
  });
  test('offline verification is unavailable, not an incorrect password', () async {
    when(() => auth.signInWithEmailPassword(any(), any())).thenThrow(NetworkException('offline'));
    expect(
      await controller.changePassword(currentPassword: 'old', newPassword: 'new'),
      ChangePasswordResult.verificationUnavailable,
    );
    verifyNever(() => auth.updateUserPassword(any()));
  });
  test('a second request is blocked while verification is pending', () async {
    final pending = Completer<AuthResponse>();
    when(() => auth.signInWithEmailPassword(any(), any())).thenAnswer((_) => pending.future);
    final first = controller.changePassword(currentPassword: 'old', newPassword: 'new');
    expect(
      await controller.changePassword(currentPassword: 'old', newPassword: 'new'),
      ChangePasswordResult.busy,
    );
    pending.complete(AuthResponse(user: user));
    await first;
    verify(() => auth.signInWithEmailPassword(any(), any())).called(1);
  });
  test('account change during verification prevents password update', () async {
    final pending = Completer<AuthResponse>();
    when(() => auth.signInWithEmailPassword(any(), any())).thenAnswer((_) => pending.future);
    final first = controller.changePassword(currentPassword: 'old', newPassword: 'new');
    when(() => auth.currentUser).thenReturn(sdkUser('account-b'));
    h.session.set(h.container.read(authProvider).copyWith(user: profile('account-b')));
    await h.container.pump();
    pending.complete(AuthResponse(user: user));
    expect(await first, ChangePasswordResult.verificationUnavailable);
    verifyNever(() => auth.updateUserPassword(any()));
  });
}
