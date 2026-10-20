import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/data/models/user_model.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/widgets/paper/paper_vignette.dart';
import 'package:ghar360/features/auth/presentation/controllers/profile_completion_controller.dart';
import 'package:ghar360/features/auth/presentation/views/profile_completion_view.dart';
import 'package:ghar360/features/auth/presentation/widgets/auth_form_fields.dart';
import '../../../helpers/auth_form_harness.dart';
import '../../../helpers/auth_test_harness.dart' show profile, sdkUser;

void main() {
  late AuthFormHarness h;
  setUp(() {
    h = AuthFormHarness();
  });
  tearDown(() {
    h.close();
  });

  testWidgets('required fields block progression', (tester) async {
    try {
      await h.pump(tester, const ProfileCompletionView());
      final button = find.byKey(const ValueKey('qa.auth.profile_completion.submit'));
      await tester.ensureVisible(button);
      await tester.pump();
      await tester.tap(button);
      await tester.pump();
      expect(h.container.read(profileCompletionProvider).step, 0);
    } finally {
      await tester.pumpWidget(const SizedBox());
      h.close();
    }
  });
  testWidgets('prefills email from shared auth state', (tester) async {
    try {
      h.session.initial = AuthState(user: profile());
      await h.pump(tester, const ProfileCompletionView());
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('qa.auth.profile_completion.email_input')),
            )
            .controller!
            .text,
        'account-a@example.com',
      );
    } finally {
      await tester.pumpWidget(const SizedBox());
      h.close();
    }
  });
  testWidgets('purpose step renders choices and Complete', (tester) async {
    try {
      await h.pump(tester, const ProfileCompletionView());
      h.container.read(profileCompletionProvider.notifier).nextStep();
      await tester.pump();
      for (final purpose in ['buy', 'rent', 'short_stay']) {
        expect(find.byKey(ValueKey('qa.auth.profile_completion.purpose.$purpose')), findsOneWidget);
      }
      expect(find.byType(RawRadio<String>), findsNWidgets(3));
      expect(find.byType(PaperArtView), findsNWidgets(3));
      // Screen readers hear one group of radios with the chosen one checked.
      final handle = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.byKey(const ValueKey('qa.auth.profile_completion.purpose.buy'))),
        isSemantics(label: 'Buy', isChecked: true, isInMutuallyExclusiveGroup: true),
      );
      expect(
        tester.getSemantics(find.byKey(const ValueKey('qa.auth.profile_completion.purpose.rent'))),
        isSemantics(label: 'Rent', isChecked: false, isInMutuallyExclusiveGroup: true),
      );
      handle.dispose();
      expect(find.text('Complete'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox());
      h.close();
    }
  });
  testWidgets('back from purpose restores personal fields', (tester) async {
    try {
      await h.pump(tester, const ProfileCompletionView());
      final c = h.container.read(profileCompletionProvider.notifier);
      c.nextStep();
      await tester.pump();
      c.back();
      await tester.pump();
      expect(find.byType(TextFormField), findsNWidgets(3));
    } finally {
      await tester.pumpWidget(const SizedBox());
      h.close();
    }
  });
  testWidgets('Skip remains available and persists selected purpose', (tester) async {
    try {
      await h.pump(tester, const ProfileCompletionView());
      final skip = find.text('Skip for now');
      await tester.ensureVisible(skip);
      await tester.pump();
      await tester.tap(skip);
      await tester.pump();
      expect(h.container.read(profileCompletionProvider).step, 1);
      expect(h.container.read(authProvider).profileCompletionDeferred, false);
      verifyNever(() => h.profiles.updateUserPreferences(any()));
      await tester.tap(find.text('Rent'));
      await tester.ensureVisible(skip);
      await tester.pump();
      await tester.tap(skip);
      await tester.pump();
      verify(() => h.profiles.updateUserPreferences({'purpose': 'rent'})).called(1);
      expect(h.container.read(authProvider).profileCompletionDeferred, true);
      expect(h.session.profileWrites, 0);
    } finally {
      await tester.pumpWidget(const SizedBox());
      h.close();
    }
  });
  testWidgets('Google without phone shows skippable phone prompt', (tester) async {
    try {
      when(() => h.repository.currentUser).thenReturn(sdkUser('account-a', 'google'));
      await h.pump(tester, const ProfileCompletionView());
      expect(find.byKey(const ValueKey('qa.auth.profile_completion.phone_input')), findsOneWidget);
      expect(find.text('Skip for now'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox());
      h.close();
    }
  });
  testWidgets('Skip keeps its size, blocks duplicate save, and preserves purpose on failure', (
    tester,
  ) async {
    try {
      await h.pump(tester, const ProfileCompletionView());
      final skip = find.widgetWithText(TextButton, 'Skip for now');
      await tester.ensureVisible(skip);
      await tester.pump();
      await tester.tap(skip);
      await tester.pump();
      await tester.tap(find.text('Rent'));
      await tester.ensureVisible(skip);
      await tester.pump();
      final size = tester.getSize(skip);
      final pending = Completer<UserPreferences>();
      when(() => h.profiles.updateUserPreferences(any())).thenAnswer((_) => pending.future);
      await tester.tap(skip);
      await tester.pump();
      expect(tester.widget<TextButton>(skip).onPressed, isNull);
      expect(tester.getSize(skip), size);
      expect(h.container.read(authProvider).profileCompletionDeferred, false);
      pending.completeError(NetworkException('offline'));
      await tester.pump();
      expect(tester.widget<TextButton>(skip).onPressed, isNotNull);
      expect(tester.widget<RadioGroup<String>>(find.byType(RadioGroup<String>)).groupValue, 'rent');
      expect(h.container.read(authProvider).profileCompletionDeferred, false);
      verify(() => h.profiles.updateUserPreferences({'purpose': 'rent'})).called(1);
      expect(h.session.profileWrites, 0);
    } finally {
      await tester.pumpWidget(const SizedBox());
      h.close();
    }
  });
  testWidgets('Continue after skipping details saves purpose without an empty profile write', (
    tester,
  ) async {
    try {
      await h.pump(tester, const ProfileCompletionView());
      final skip = find.text('Skip for now');
      await tester.ensureVisible(skip);
      await tester.pump();
      await tester.tap(skip);
      await tester.pump();
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Complete'), findsNothing);
      final button = find.byKey(const ValueKey('qa.auth.profile_completion.submit'));
      await tester.ensureVisible(button);
      await tester.pump();
      await tester.tap(button);
      await tester.pump();
      verify(() => h.profiles.updateUserPreferences({'purpose': 'buy'})).called(1);
      expect(h.container.read(authProvider).profileCompletionDeferred, true);
      expect(h.session.profileWrites, 0);
    } finally {
      await tester.pumpWidget(const SizedBox());
      h.close();
    }
  });
  testWidgets('phone OTP request shows OTP input and cooldown', (tester) async {
    try {
      when(() => h.repository.currentUser).thenReturn(sdkUser('account-a', 'google'));
      await h.pump(tester, const ProfileCompletionView());
      await h.container.read(profileCompletionProvider.notifier).sendAddPhoneOtp('9876543210');
      await tester.pump();
      expect(find.byKey(const ValueKey('qa.auth.profile_completion.otp_input')), findsOneWidget);
      expect(find.textContaining('30'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox());
      h.close();
    }
  });
  testWidgets('profile preference failure leaves form actionable', (tester) async {
    try {
      await h.pump(tester, const ProfileCompletionView());
      when(() => h.profiles.updateUserPreferences(any())).thenThrow(NetworkException('offline'));
      await h.container.read(profileCompletionProvider.notifier).completeProfile({}, 'buy');
      await tester.pump();
      expect(h.container.read(profileCompletionProvider).loading, false);
      expect(find.byType(AuthFormError), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox());
      h.close();
    }
  });
}
