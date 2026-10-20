import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/auth/data/auth_method.dart';
import 'package:ghar360/features/auth/presentation/controllers/profile_completion_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/auth_form_harness.dart';
import '../../../../helpers/auth_test_harness.dart' show sdkUser;

void main() {
  late AuthFormHarness h;
  setUp(() {
    h = AuthFormHarness();
  });
  tearDown(() {
    h.close();
  });

  test('regular login hides optional OAuth phone prompt', () {
    h.listen(profileCompletionProvider);
    expect(h.container.read(profileCompletionProvider).showAddPhone, false);
  });
  for (final provider in ['google', 'apple']) {
    test('$provider account without phone sees optional add-phone prompt', () {
      when(() => h.repository.currentUser).thenReturn(sdkUser('account-a', provider));
      h.listen(profileCompletionProvider);
      expect(h.container.read(profileCompletionProvider).showAddPhone, true);
    });
    test('$provider skip records original OAuth method', () async {
      when(() => h.repository.currentUser).thenReturn(sdkUser('account-a', provider));
      h.listen(profileCompletionProvider);
      expect(await h.container.read(profileCompletionProvider.notifier).skipAddPhone(), true);
      expect(h.container.read(profileCompletionProvider).showAddPhone, false);
      verify(
        () => h.repository.recordLastMethod(
          provider == 'google' ? AuthMethod.google : AuthMethod.apple,
          identifier: any(named: 'identifier'),
        ),
      ).called(1);
    });
  }
  test('phone send starts cooldown, verification hides optional prompt', () async {
    h.listen(profileCompletionProvider);
    final c = h.container.read(profileCompletionProvider.notifier);
    expect(await c.sendAddPhoneOtp('9876543210'), true);
    expect(h.container.read(profileCompletionProvider).phoneOtpStage, true);
    expect(h.container.read(profileCompletionProvider).otpCountdown, 30);
    expect(await c.resendAddPhoneOtp(), false);
    expect(await c.verifyAddPhoneOtp('123456'), true);
    expect(h.container.read(profileCompletionProvider).showAddPhone, false);
  });
  for (final token in ['', '123', '1234567', 'abcdef']) {
    test('add-phone rejects invalid OTP "$token"', () async {
      h.listen(profileCompletionProvider);
      expect(
        await h.container.read(profileCompletionProvider.notifier).verifyAddPhoneOtp(token),
        false,
      );
      expect(h.container.read(profileCompletionProvider).error?.code, 'invalid_otp');
    });
  }
  test('purpose saves before profile completion', () async {
    h.listen(profileCompletionProvider);
    expect(
      await h.container.read(profileCompletionProvider.notifier).completeProfile({
        'full_name': 'Test',
      }, 'rent'),
      true,
    );
    verify(() => h.profiles.updateUserPreferences({'purpose': 'rent'})).called(1);
    expect(h.session.profileWrites, 1);
  });
  test('purpose write failure blocks profile completion and Skip', () async {
    h.listen(profileCompletionProvider);
    when(() => h.profiles.updateUserPreferences(any())).thenThrow(NetworkException('offline'));
    final c = h.container.read(profileCompletionProvider.notifier);
    expect(await c.completeProfile({}, 'buy'), false);
    expect(h.session.profileWrites, 0);
    expect(await c.skipProfile('buy'), false);
    expect(h.container.read(authProvider).profileCompletionDeferred, false);
  });
  test('Skip persists purpose and sets session-owned completion flag', () async {
    h.listen(profileCompletionProvider);
    expect(await h.container.read(profileCompletionProvider.notifier).skipProfile('rent'), true);
    expect(h.container.read(authProvider).profileCompletionDeferred, true);
    verify(() => h.profiles.updateUserPreferences({'purpose': 'rent'})).called(1);
  });
  test('previous step stays within bounds', () {
    h.listen(profileCompletionProvider);
    final c = h.container.read(profileCompletionProvider.notifier);
    c.back();
    expect(h.container.read(profileCompletionProvider).step, 0);
    c.nextStep();
    expect(h.container.read(profileCompletionProvider).step, 1);
    c.back();
    expect(h.container.read(profileCompletionProvider).step, 0);
  });
}
