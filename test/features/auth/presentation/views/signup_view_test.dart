import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/features/auth/presentation/controllers/signup_controller.dart';
import 'package:ghar360/features/auth/presentation/views/signup_view.dart';
import 'package:ghar360/features/auth/presentation/widgets/auth_form_fields.dart';
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

  testWidgets('personal form renders name, secondary identifier, DOB, next', (tester) async {
    try {
      await h.pump(tester, SignUpView(args: flowArgs()));
      expect(find.byType(TextFormField), findsNWidgets(3));
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byKey(const ValueKey('qa.auth.signup.next')), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox());
      h.close();
    }
  });
  testWidgets('missing identifier provides entry action', (tester) async {
    try {
      await h.pump(tester, const SignUpView());
      expect(find.byType(AuthMissingIdentifier), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox());
      h.close();
    }
  });
  testWidgets('empty personal fields block progression', (tester) async {
    try {
      final args = flowArgs();
      await h.pump(tester, SignUpView(args: args));
      final button = find.byKey(const ValueKey('qa.auth.signup.next'));
      await tester.ensureVisible(button);
      await tester.pump();
      await tester.tap(button);
      await tester.pump();
      expect(h.container.read(signUpProvider(args)).step, 0);
    } finally {
      await tester.pumpWidget(const SizedBox());
      h.close();
    }
  });
  testWidgets('security step renders passwords, terms, create account', (tester) async {
    try {
      final args = flowArgs();
      await h.pump(tester, SignUpView(args: args));
      h.container.read(signUpProvider(args).notifier).nextStep();
      await tester.pump();
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.byType(CheckboxListTile), findsOneWidget);
      expect(find.byKey(const ValueKey('qa.auth.signup.submit')), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox());
      h.close();
    }
  });
  testWidgets('matching passwords still require consent', (tester) async {
    try {
      final args = flowArgs();
      await h.pump(tester, SignUpView(args: args));
      h.container.read(signUpProvider(args).notifier).nextStep();
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).at(0), 'Password123!');
      await tester.enterText(find.byType(TextFormField).at(1), 'Password123!');
      final button = find.byKey(const ValueKey('qa.auth.signup.submit'));
      await tester.ensureVisible(button);
      await tester.pump();
      await tester.tap(button);
      await tester.pump();
      expect(h.container.read(signUpProvider(args)).error?.code, 'terms_consent_required');
      verifyNever(() => h.repository.signUpWithEmailOtp(any(), data: any(named: 'data')));
    } finally {
      await tester.pumpWidget(const SizedBox());
      h.close();
    }
  });
  testWidgets('back returns to personal form without losing local text', (tester) async {
    try {
      final args = flowArgs();
      await h.pump(tester, SignUpView(args: args));
      await tester.enterText(find.byType(TextFormField).first, 'Test User');
      final c = h.container.read(signUpProvider(args).notifier);
      c.nextStep();
      await tester.pump();
      c.back();
      await tester.pump();
      expect(
        tester.widget<TextFormField>(find.byType(TextFormField).first).controller!.text,
        'Test User',
      );
    } finally {
      await tester.pumpWidget(const SizedBox());
      h.close();
    }
  });
  testWidgets('OTP step renders verify and cooldown', (tester) async {
    try {
      final args = flowArgs();
      await h.pump(tester, SignUpView(args: args));
      await h.container
          .read(signUpProvider(args).notifier)
          .signUp(password: 'Password123', userData: {});
      await tester.pump();
      expect(find.byKey(const ValueKey('qa.auth.signup.otp_input')), findsOneWidget);
      expect(find.byKey(const ValueKey('qa.auth.signup.verify')), findsOneWidget);
      expect(find.textContaining('30'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox());
      h.close();
    }
  });
  testWidgets('OTP completion verifies signup and applies collected password', (tester) async {
    try {
      final args = flowArgs();
      await h.pump(tester, SignUpView(args: args));
      await h.container
          .read(signUpProvider(args).notifier)
          .signUp(password: 'Password123', userData: {});
      await tester.pump();
      await tester.enterText(find.byKey(const ValueKey('qa.auth.signup.otp_input')), '123456');
      await tester.pump();
      expect(h.session.passwordWrites, 1);
    } finally {
      await tester.pumpWidget(const SizedBox());
      h.close();
    }
  });
}
