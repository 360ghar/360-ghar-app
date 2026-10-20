import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/auth/data/auth_method.dart';
import 'package:ghar360/features/auth/presentation/controllers/signup_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../../../../helpers/auth_form_harness.dart';

void main() {
  late AuthFormHarness h;
  setUp(() {
    h = AuthFormHarness();
  });
  tearDown(() {
    h.close();
  });

  for (final email in [true, false]) {
    test('${email ? 'email' : 'phone'} signup retains metadata and moves to OTP', () async {
      final args = flowArgs(email: email, exists: false);
      final p = signUpProvider(args);
      h.listen(p);
      final c = h.container.read(p.notifier);
      expect(h.container.read(p).step, 0);
      c.nextStep();
      expect(h.container.read(p).step, 1);
      expect(await c.signUp(password: 'Password123', userData: {'full_name': 'Test User'}), true);
      expect(h.container.read(p).step, 2);
      expect(h.container.read(p).otpCountdown, 30);
      expect(await c.resendOtp(), false);
      expect(await c.verifyOtp('123456'), true);
      expect(h.session.passwordWrites, email ? 1 : 0);
      verify(
        () => h.repository.recordLastMethod(
          email ? AuthMethod.emailPassword : AuthMethod.phonePassword,
          identifier: args.identifier,
        ),
      ).called(1);
    });
    test('${email ? 'email' : 'phone'} signup failure preserves step and error', () async {
      final args = flowArgs(email: email);
      final p = signUpProvider(args);
      h.listen(p);
      if (email) {
        when(
          () => h.repository.signUpWithEmailOtp(any(), data: any(named: 'data')),
        ).thenThrow(NetworkException('offline'));
      } else {
        when(
          () => h.repository.signUpWithPhonePassword(any(), any(), data: any(named: 'data')),
        ).thenThrow(NetworkException('offline'));
      }
      final c = h.container.read(p.notifier);
      c.nextStep();
      expect(await c.signUp(password: 'Password123', userData: {}), false);
      expect(h.container.read(p).step, 1);
      expect(h.container.read(p).error, isA<NetworkException>());
    });
    test('${email ? 'email' : 'phone'} resend uses signup channel', () async {
      final p = signUpProvider(flowArgs(email: email));
      h.listen(p);
      expect(await h.container.read(p.notifier).resendOtp(), true);
      if (email) {
        verify(() => h.repository.signUpWithEmailOtp(any(), data: any(named: 'data'))).called(1);
      } else {
        verify(() => h.repository.sendPhoneOtp(any())).called(1);
      }
    });
  }
  for (final token in ['', '123', '1234567', 'abcdef']) {
    test('signup rejects invalid OTP "$token"', () async {
      final p = signUpProvider(flowArgs());
      h.listen(p);
      expect(await h.container.read(p.notifier).verifyOtp(token), false);
      expect(h.container.read(p).error?.code, 'invalid_otp');
    });
  }
  test('OTP failure clears pending password gate', () async {
    final p = signUpProvider(flowArgs());
    h.listen(p);
    when(
      () => h.repository.verifyEmailOtp(
        email: any(named: 'email'),
        token: any(named: 'token'),
      ),
    ).thenThrow(const AuthException('failed'));
    expect(await h.container.read(p.notifier).verifyOtp('123456'), false);
    expect(h.session.gate, false);
  });
  test('verified email with failed password write retains required gate', () async {
    final p = signUpProvider(flowArgs());
    h.listen(p);
    final c = h.container.read(p.notifier);
    await c.signUp(password: 'Password123', userData: {});
    h.session.passwordSuccess = false;
    expect(await c.verifyOtp('123456'), false);
    expect(h.session.gate, true);
  });
  test('back never moves before personal step and clears form error', () {
    final p = signUpProvider(flowArgs());
    h.listen(p);
    final c = h.container.read(p.notifier);
    c.back();
    expect(h.container.read(p).step, 0);
    c.nextStep();
    c.invalid('terms_consent_required');
    c.back();
    expect(h.container.read(p).step, 0);
    expect(h.container.read(p).error, isNull);
  });
}
