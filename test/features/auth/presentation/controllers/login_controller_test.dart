import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException, AuthResponse;

import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/auth/data/auth_method.dart';
import 'package:ghar360/features/auth/presentation/controllers/login_controller.dart';
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
    test('${email ? 'email' : 'phone'} password login records its method', () async {
      final args = flowArgs(email: email);
      final p = loginProvider(args);
      h.listen(p);
      final c = h.container.read(p.notifier);
      expect(await c.signIn('password123'), true);
      verify(
        () => h.repository.recordLastMethod(
          email ? AuthMethod.emailPassword : AuthMethod.phonePassword,
          identifier: args.identifier,
        ),
      ).called(1);
    });
    test(
      '${email ? 'email' : 'phone'} OTP-first sends automatically and starts cooldown',
      () async {
        final args = flowArgs(email: email, otp: true);
        final p = loginProvider(args);
        h.listen(p);
        await Future<void>.delayed(Duration.zero);
        expect(h.container.read(p).step, 1);
        expect(h.container.read(p).otpCountdown, 30);
        expect(await h.container.read(p.notifier).resendOtp(), false);
      },
    );
    test('${email ? 'email' : 'phone'} OTP verifies trimmed token and records method', () async {
      final args = flowArgs(email: email);
      final p = loginProvider(args);
      h.listen(p);
      expect(await h.container.read(p.notifier).verifyOtp(' 123456 '), true);
      verify(
        () => h.repository.recordLastMethod(
          email ? AuthMethod.emailOtp : AuthMethod.phoneOtp,
          identifier: args.identifier,
        ),
      ).called(1);
    });
    test('${email ? 'email' : 'phone'} resend failure remains typed and retryable', () async {
      final args = flowArgs(email: email);
      final p = loginProvider(args);
      h.listen(p);
      if (email) {
        when(() => h.repository.sendEmailOtp(any())).thenThrow(NetworkException('offline'));
      } else {
        when(() => h.repository.sendPhoneOtp(any())).thenThrow(NetworkException('offline'));
      }
      expect(await h.container.read(p.notifier).resendOtp(), false);
      expect(h.container.read(p).error, isA<NetworkException>());
      expect(h.container.read(p).canResendOtp, true);
    });
  }
  for (final token in ['', '123', '1234567', 'abcdef']) {
    test('rejects invalid OTP "$token"', () async {
      final p = loginProvider(flowArgs());
      h.listen(p);
      expect(await h.container.read(p.notifier).verifyOtp(token), false);
      expect(h.container.read(p).error?.code, 'invalid_otp');
    });
  }
  test('passwordless verification sets password gate before session callback', () async {
    final args = flowArgs(password: false);
    final p = loginProvider(args);
    h.listen(p);
    when(
      () => h.repository.verifyEmailOtp(
        email: any(named: 'email'),
        token: any(named: 'token'),
      ),
    ).thenAnswer((_) async {
      expect(h.session.gate, true);
      return AuthResponse();
    });
    expect(await h.container.read(p.notifier).verifyOtp('123456'), true);
    expect(h.session.gate, true);
  });
  test('failed verification clears pending password gate', () async {
    final p = loginProvider(flowArgs(password: false));
    h.listen(p);
    when(
      () => h.repository.verifyEmailOtp(
        email: any(named: 'email'),
        token: any(named: 'token'),
      ),
    ).thenThrow(const AuthException('bad otp'));
    expect(await h.container.read(p.notifier).verifyOtp('123456'), false);
    expect(h.session.gate, false);
    expect(h.container.read(p).error, isA<AuthenticationException>());
  });
  test('password edits clear prior error through explicit action', () {
    final p = loginProvider(flowArgs());
    h.listen(p);
    final c = h.container.read(p.notifier);
    c.invalid('invalid_otp');
    c.clearError();
    expect(h.container.read(p).error, isNull);
  });
  test('duplicate password submission calls repository once', () async {
    final p = loginProvider(flowArgs());
    h.listen(p);
    final pending = Completer<AuthResponse>();
    when(
      () => h.repository.signInWithEmailPassword(any(), any()),
    ).thenAnswer((_) => pending.future);
    final c = h.container.read(p.notifier);
    final first = c.signIn('x');
    expect(await c.signIn('x'), false);
    pending.complete(AuthResponse());
    await first;
    verify(() => h.repository.signInWithEmailPassword(any(), any())).called(1);
  });
}
