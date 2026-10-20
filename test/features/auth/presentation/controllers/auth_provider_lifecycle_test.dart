import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/features/auth/presentation/controllers/login_controller.dart';
import 'package:ghar360/features/auth/presentation/controllers/otp_resend_timer.dart';
import 'package:ghar360/features/auth/presentation/controllers/profile_completion_controller.dart';
import 'package:ghar360/features/auth/presentation/controllers/signup_controller.dart';
import '../../../../helpers/auth_form_harness.dart';
import '../../../../helpers/auth_test_harness.dart' show profile;

void main() {
  test('resend cooldown starts and dispose cancels its timer', () async {
    final h = AuthFormHarness();
    try {
      final p = loginProvider(flowArgs(otp: true));
      final sub = h.listen(p);
      await Future<void>.delayed(Duration.zero);
      expect(h.container.read(p).otpCountdown, 30);
      expect(h.container.read(p).canResendOtp, false);
      sub.close();
      await h.container.pump();
    } finally {
      h.close();
    }
  });
  testWidgets('countdown uses elapsed time after an app suspension', (tester) async {
    var now = DateTime(2026);
    var seconds = 0;
    final timer = OtpResendTimer((value) => seconds = value, now: () => now);
    try {
      timer.start();
      expect(seconds, 30);
      now = now.add(const Duration(minutes: 2));
      await tester.pump(const Duration(seconds: 1));
      expect(seconds, 0);
    } finally {
      timer.cancel();
    }
  });
  test('leaving signup stops countdown and reentry starts fresh', () async {
    final h = AuthFormHarness();
    try {
      final p = signUpProvider(flowArgs());
      final sub = h.listen(p);
      await h.container.read(p.notifier).signUp(password: 'Password123', userData: {});
      expect(h.container.read(p).otpCountdown, 30);
      sub.close();
      await h.container.pump();
      final reentered = h.listen(p);
      expect(h.container.read(p).step, 0);
      expect(h.container.read(p).otpCountdown, 0);
      reentered.close();
    } finally {
      h.close();
    }
  });
  test('account switch resets profile form and ignores old add-phone completion', () async {
    final h = AuthFormHarness();
    try {
      h.session.initial = AuthState(user: profile());
      final sub = h.listen(profileCompletionProvider);
      final pending = Completer<void>();
      when(() => h.repository.startAddPhone(any())).thenAnswer((_) => pending.future);
      final request = h.container
          .read(profileCompletionProvider.notifier)
          .sendAddPhoneOtp('9876543210');
      h.session.set(AuthState(user: profile('account-b')));
      h.container.read(profileCompletionProvider);
      pending.complete();
      expect(await request, false);
      expect(h.container.read(profileCompletionProvider).phoneOtpStage, false);
      expect(h.container.read(profileCompletionProvider).loading, false);
      sub.close();
    } finally {
      h.close();
    }
  });
}
