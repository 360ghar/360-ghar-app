import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/features/profile/presentation/controllers/change_password_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../helpers/mocks.dart';

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
  late MockAuthRepository auth;
  late ChangePasswordController controller;
  late _FakeUser user;

  setUp(() {
    auth = MockAuthRepository();
    controller = ChangePasswordController(authRepository: auth);
    user = _FakeUser(email: 'a@b.com');
  });

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
      expect(controller.isLoading.value, isTrue);

      completer.complete(AuthResponse(user: user));
      await future;

      expect(controller.isLoading.value, isFalse);
    });

    // ── isLoading reset on error ──────────────────────────────────────────

    test('isLoading is false after error', () async {
      when(() => auth.currentUser).thenReturn(user);
      when(
        () => auth.signInWithEmailPassword('a@b.com', 'wrong'),
      ).thenThrow(Exception('Invalid credentials'));

      await controller.changePassword(
        currentPassword: 'wrong',
        newPassword: 'new-pass',
      );

      expect(controller.isLoading.value, isFalse);
    });

    // ── errorMessage is set on incorrect password ─────────────────────────

    test('errorMessage is set on incorrect password', () async {
      when(() => auth.currentUser).thenReturn(user);
      when(
        () => auth.signInWithEmailPassword('a@b.com', 'wrong'),
      ).thenThrow(Exception('Invalid credentials'));

      await controller.changePassword(
        currentPassword: 'wrong',
        newPassword: 'new-pass',
      );

      expect(controller.errorMessage.value, isNotEmpty);
    });

    // ── errorMessage is set on verification unavailable ───────────────────

    test('errorMessage is set on verification unavailable', () async {
      when(() => auth.currentUser).thenReturn(_FakeUser());

      await controller.changePassword(
        currentPassword: 'x',
        newPassword: 'new-pass',
      );

      expect(controller.errorMessage.value, isNotEmpty);
    });

    // ── errorMessage is set on update failed ──────────────────────────────

    test('errorMessage is set on update failed', () async {
      when(() => auth.currentUser).thenReturn(user);
      when(
        () => auth.signInWithEmailPassword('a@b.com', 'old-pass'),
      ).thenAnswer((_) async => AuthResponse(user: user));
      when(() => auth.updateUserPassword('new-pass')).thenThrow(Exception('Update failed'));

      await controller.changePassword(
        currentPassword: 'old-pass',
        newPassword: 'new-pass',
      );

      expect(controller.errorMessage.value, isNotEmpty);
    });

    // ── errorMessage is cleared on new attempt ────────────────────────────

    test('errorMessage is cleared at start of new attempt', () async {
      when(() => auth.currentUser).thenReturn(user);
      when(
        () => auth.signInWithEmailPassword('a@b.com', 'wrong'),
      ).thenThrow(Exception('Invalid credentials'));

      // First attempt fails
      await controller.changePassword(
        currentPassword: 'wrong',
        newPassword: 'new-pass',
      );
      expect(controller.errorMessage.value, isNotEmpty);

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
      expect(controller.errorMessage.value, isEmpty);
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

      final result = await controller.changePassword(
        currentPassword: 'x',
        newPassword: 'new-pass',
      );

      expect(result, ChangePasswordResult.verificationUnavailable);
    });
  });
}
