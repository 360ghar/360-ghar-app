import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/auth/presentation/controllers/forgot_password_controller.dart';
import 'package:ghar360/features/auth/presentation/views/forgot_password_view.dart';
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

  testWidgets('reset renders prefilled identifier and send button', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await h.pump(tester, const ForgotPasswordView(identifier: 'test@example.com'));
      expect(
        tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text,
        'test@example.com',
      );
      expect(find.byKey(const ValueKey('qa.auth.forgot_password.submit')), findsOneWidget);
      expect(
        find.bySemanticsIdentifier('qa.auth.forgot_password.identifier_input'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp('qa\\.auth')), findsNothing);
    } finally {
      semantics.dispose();
      await tester.pumpWidget(const SizedBox());
      h.close();
    }
  });
  testWidgets('empty reset identifier does not request OTP', (tester) async {
    try {
      await h.pump(tester, const ForgotPasswordView());
      final button = find.byKey(const ValueKey('qa.auth.forgot_password.submit'));
      await tester.ensureVisible(button);
      await tester.pump();
      await tester.tap(button);
      await tester.pump();
      verifyNever(() => h.repository.checkIdentifierStatus(any()));
    } finally {
      await tester.pumpWidget(const SizedBox());
      h.close();
    }
  });
  testWidgets('successful request shows OTP and cooldown', (tester) async {
    try {
      await h.pump(tester, const ForgotPasswordView());
      await h.container.read(forgotPasswordProvider.notifier).sendResetOtp('test@example.com');
      await tester.pump();
      expect(find.byKey(const ValueKey('qa.auth.forgot_password.otp_input')), findsOneWidget);
      expect(find.textContaining('30'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox());
      h.close();
    }
  });
  testWidgets('verified reset session shows password fields while router resolves', (tester) async {
    try {
      await h.pump(tester, const ForgotPasswordView());
      final c = h.container.read(forgotPasswordProvider.notifier);
      await c.sendResetOtp('test@example.com');
      await c.verifyResetOtp('123456');
      await tester.pump();
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(h.session.gate, true);
    } finally {
      await tester.pumpWidget(const SizedBox());
      h.close();
    }
  });
  testWidgets('back from OTP allows correcting identifier', (tester) async {
    try {
      await h.pump(tester, const ForgotPasswordView(identifier: 'test@example.com'));
      final c = h.container.read(forgotPasswordProvider.notifier);
      await c.sendResetOtp('test@example.com');
      await tester.pump();
      c.back();
      await tester.pump();
      expect(
        tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text,
        'test@example.com',
      );
    } finally {
      await tester.pumpWidget(const SizedBox());
      h.close();
    }
  });
  testWidgets('reset request error remains visible', (tester) async {
    try {
      await h.pump(tester, const ForgotPasswordView());
      when(() => h.repository.checkIdentifierStatus(any())).thenThrow(NetworkException('offline'));
      await h.container.read(forgotPasswordProvider.notifier).sendResetOtp('test@example.com');
      await tester.pump();
      expect(find.byType(AuthFormError), findsOneWidget);
      expect(h.container.read(forgotPasswordProvider).error, isA<NetworkException>());
    } finally {
      await tester.pumpWidget(const SizedBox());
      h.close();
    }
  });
}
