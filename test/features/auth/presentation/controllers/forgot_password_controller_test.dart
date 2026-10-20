import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/auth/presentation/controllers/forgot_password_controller.dart';
import 'package:mocktail/mocktail.dart';

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
    test(
      '${email ? 'email' : 'phone'} reset checks account and advances through verified steps',
      () async {
        final args = flowArgs(email: email);
        when(() => h.repository.checkIdentifierStatus(any())).thenAnswer((_) async => args.status);
        h.listen(forgotPasswordProvider);
        final c = h.container.read(forgotPasswordProvider.notifier);
        expect(await c.sendResetOtp(args.identifier), true);
        expect(h.container.read(forgotPasswordProvider).step, 1);
        expect(h.container.read(forgotPasswordProvider).otpCountdown, 30);
        expect(await c.verifyResetOtp('123456'), true);
        expect(h.session.gate, true);
        expect(h.container.read(forgotPasswordProvider).step, 2);
        expect(await c.updatePassword('Password123'), true);
        expect(h.session.passwordWrites, 1);
        expect(h.session.gate, false);
      },
    );
  }
  test('missing account is typed validation error and sends no OTP', () async {
    h.listen(forgotPasswordProvider);
    when(
      () => h.repository.checkIdentifierStatus(any()),
    ).thenAnswer((_) async => flowArgs(exists: false).status);
    expect(
      await h.container.read(forgotPasswordProvider.notifier).sendResetOtp('test@example.com'),
      false,
    );
    expect(h.container.read(forgotPasswordProvider).error?.code, 'no_account_found_error');
    verifyNever(() => h.repository.sendEmailOtp(any()));
  });
  for (final token in ['', '123', '1234567', 'abcdef']) {
    test('reset rejects invalid OTP "$token"', () async {
      h.listen(forgotPasswordProvider);
      expect(await h.container.read(forgotPasswordProvider.notifier).verifyResetOtp(token), false);
      expect(h.container.read(forgotPasswordProvider).error?.code, 'invalid_otp');
    });
  }
  test('OTP verification failure clears pending password gate', () async {
    h.listen(forgotPasswordProvider);
    final c = h.container.read(forgotPasswordProvider.notifier);
    await c.sendResetOtp('test@example.com');
    when(
      () => h.repository.verifyEmailOtp(
        email: any(named: 'email'),
        token: any(named: 'token'),
      ),
    ).thenThrow(NetworkException('offline'));
    expect(await c.verifyResetOtp('123456'), false);
    expect(h.session.gate, false);
    expect(h.container.read(forgotPasswordProvider).error, isA<NetworkException>());
  });
  test('resend during cooldown performs no additional request', () async {
    h.listen(forgotPasswordProvider);
    final c = h.container.read(forgotPasswordProvider.notifier);
    await c.sendResetOtp('test@example.com');
    expect(await c.resendOtp(), false);
    verify(() => h.repository.sendEmailOtp(any())).called(1);
  });
  test('back clears error and permits identifier correction', () async {
    h.listen(forgotPasswordProvider);
    final c = h.container.read(forgotPasswordProvider.notifier);
    await c.sendResetOtp('test@example.com');
    c.invalid('invalid_otp');
    c.back();
    expect(h.container.read(forgotPasswordProvider).step, 0);
    expect(h.container.read(forgotPasswordProvider).error, isNull);
    c.back();
    expect(h.container.read(forgotPasswordProvider).step, 0);
  });
}
