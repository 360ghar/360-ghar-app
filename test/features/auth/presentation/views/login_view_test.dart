import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthResponse;

import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';
import 'package:ghar360/features/auth/presentation/controllers/login_controller.dart';
import 'package:ghar360/features/auth/presentation/views/login_view.dart';
import 'package:ghar360/features/auth/presentation/widgets/auth_form_fields.dart';
import '../../../../helpers/auth_form_harness.dart';

Finder _knife(KnifeIcon icon) =>
    find.byWidgetPredicate((widget) => widget is PaperIcon && widget.icon == icon);

void main() {
  late AuthFormHarness h;
  setUp(() {
    h = AuthFormHarness();
  });
  tearDown(() {
    h.close();
  });

  testWidgets('password login renders identifier and submit', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final args = flowArgs();
      await h.pump(tester, LoginView(args: args));
      expect(find.text(args.identifier), findsOneWidget);
      expect(find.byKey(const ValueKey('qa.auth.login.password_input')), findsOneWidget);
      expect(find.byKey(const ValueKey('qa.auth.login.submit')), findsOneWidget);
      expect(find.bySemanticsIdentifier('qa.auth.login.password_input'), findsOneWidget);
      expect(find.bySemanticsIdentifier('qa.auth.login.forgot_password'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('qa\\.auth')), findsNothing);
    } finally {
      semantics.dispose();
      await tester.pumpWidget(const SizedBox());
      h.close();
    }
  });
  testWidgets('missing identifier shows recoverable entry action', (tester) async {
    try {
      await h.pump(tester, const LoginView());
      expect(find.byType(AuthMissingIdentifier), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox());
      h.close();
    }
  });
  testWidgets('password visibility is local and toggles', (tester) async {
    try {
      await h.pump(tester, LoginView(args: flowArgs()));
      expect(tester.widget<TextFormField>(find.byType(TextFormField)).controller, isNotNull);
      await tester.tap(_knife(KnifeIcon.eye));
      await tester.pump();
      expect(_knife(KnifeIcon.eyeOff), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox());
      h.close();
    }
  });
  testWidgets('empty password is rejected and existing short password is accepted', (tester) async {
    try {
      await h.pump(tester, LoginView(args: flowArgs()));
      final submit = find.byKey(const ValueKey('qa.auth.login.submit'));
      await tester.ensureVisible(submit);
      await tester.pump();
      await tester.tap(submit);
      await tester.pump();
      verifyNever(() => h.repository.signInWithEmailPassword(any(), any()));
      await tester.enterText(find.byType(TextFormField), 'old');
      await tester.ensureVisible(submit);
      await tester.pump();
      await tester.tap(submit);
      await tester.pump();
      verify(() => h.repository.signInWithEmailPassword('test@example.com', 'old')).called(1);
    } finally {
      await tester.pumpWidget(const SizedBox());
      h.close();
    }
  });
  testWidgets('password submit stays same height while loading', (tester) async {
    try {
      final pending = Completer<AuthResponse>();
      when(
        () => h.repository.signInWithEmailPassword(any(), any()),
      ).thenAnswer((_) => pending.future);
      final args = flowArgs();
      await h.pump(tester, LoginView(args: args));
      final button = find.byKey(const ValueKey('qa.auth.login.submit'));
      final size = tester.getSize(button);
      final request = h.container.read(loginProvider(args).notifier).signIn('x');
      await tester.pump();
      expect(tester.getSize(button), size);
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      pending.complete(AuthResponse());
      await request;
      await tester.pump();
    } finally {
      await tester.pumpWidget(const SizedBox());
      h.close();
    }
  });
  testWidgets('OTP login renders code input, verify, countdown', (tester) async {
    try {
      await h.pump(tester, LoginView(args: flowArgs(otp: true)));
      await tester.pump();
      expect(find.byKey(const ValueKey('qa.auth.login.otp_input')), findsOneWidget);
      expect(find.byKey(const ValueKey('qa.auth.login.verify')), findsOneWidget);
      expect(find.textContaining('30'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox());
      h.close();
    }
  });
  testWidgets('OTP completion calls verify once', (tester) async {
    try {
      final args = flowArgs(otp: true);
      await h.pump(tester, LoginView(args: args));
      await tester.pump();
      await tester.enterText(find.byKey(const ValueKey('qa.auth.login.otp_input')), '123456');
      await tester.pump();
      verify(() => h.repository.verifyEmailOtp(email: args.identifier, token: '123456')).called(1);
    } finally {
      await tester.pumpWidget(const SizedBox());
      h.close();
    }
  });
  testWidgets('session resolving shows progress without hiding form', (tester) async {
    try {
      await h.pump(tester, LoginView(args: flowArgs()));
      h.session.set(const AuthState(resolving: true));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox());
      h.close();
    }
  });
  testWidgets('idle login has no resolving spinner', (tester) async {
    try {
      await h.pump(tester, LoginView(args: flowArgs()));
      expect(find.byType(CircularProgressIndicator), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox());
      h.close();
    }
  });
  testWidgets('inline login error stays on screen', (tester) async {
    try {
      final args = flowArgs();
      await h.pump(tester, LoginView(args: args));
      h.container.read(loginProvider(args).notifier).invalid('invalid_credentials');
      await tester.pump();
      expect(find.byType(AuthFormError), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox());
      h.close();
    }
  });
}
