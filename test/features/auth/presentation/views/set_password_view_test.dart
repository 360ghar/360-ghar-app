import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';
import 'package:ghar360/features/auth/presentation/controllers/set_password_controller.dart';
import 'package:ghar360/features/auth/presentation/views/set_password_view.dart';
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

  testWidgets('renders two password fields, masked account, submit', (tester) async {
    try {
      await h.pump(tester, const SetPasswordView());
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.byKey(const ValueKey('qa.auth.set_password.submit')), findsOneWidget);
      expect(find.textContaining('a***@example.com'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox());
      h.close();
    }
  });
  for (final pair in [('', ''), ('short', 'short'), ('Password123', 'different')]) {
    testWidgets('invalid password pair ${pair.$1.length}/${pair.$2.length} blocks mutation', (
      tester,
    ) async {
      try {
        await h.pump(tester, const SetPasswordView());
        await tester.enterText(find.byType(TextFormField).at(0), pair.$1);
        await tester.enterText(find.byType(TextFormField).at(1), pair.$2);
        final button = find.byKey(const ValueKey('qa.auth.set_password.submit'));
        await tester.ensureVisible(button);
        await tester.pump();
        await tester.tap(button);
        await tester.pump();
        expect(h.session.passwordWrites, 0);
      } finally {
        await tester.pumpWidget(const SizedBox());
        h.close();
      }
    });
  }
  testWidgets('valid matching password calls session mutation', (tester) async {
    try {
      await h.pump(tester, const SetPasswordView());
      await tester.enterText(find.byType(TextFormField).at(0), 'Password123!');
      await tester.enterText(find.byType(TextFormField).at(1), 'Password123!');
      final button = find.byKey(const ValueKey('qa.auth.set_password.submit'));
      await tester.ensureVisible(button);
      await tester.pump();
      await tester.tap(button);
      await tester.pump();
      expect(h.session.passwordWrites, 1);
    } finally {
      await tester.pumpWidget(const SizedBox());
      h.close();
    }
  });
  testWidgets('visibility toggles separately for each field', (tester) async {
    try {
      await h.pump(tester, const SetPasswordView());
      await tester.tap(_knife(KnifeIcon.eye).first);
      await tester.pump();
      expect(_knife(KnifeIcon.eyeOff), findsOneWidget);
      expect(_knife(KnifeIcon.eye), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox());
      h.close();
    }
  });
  testWidgets('strength changes with local password edits', (tester) async {
    try {
      await h.pump(tester, const SetPasswordView());
      await tester.enterText(find.byType(TextFormField).first, 'Password123!');
      await tester.pump();
      expect(find.text('Strong'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, '');
      await tester.pump();
      expect(find.text('Strong'), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox());
      h.close();
    }
  });
  testWidgets('failed save renders inline feedback', (tester) async {
    try {
      await h.pump(tester, const SetPasswordView());
      h.session.passwordSuccess = false;
      await h.container.read(setPasswordProvider.notifier).submit('Password123');
      await tester.pump();
      expect(h.container.read(setPasswordProvider).error, isNotNull);
      expect(find.byType(AuthFormError), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox());
      h.close();
    }
  });
  testWidgets('mandatory password screen disallows back navigation', (tester) async {
    try {
      await h.pump(tester, const SetPasswordView());
      expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, false);
    } finally {
      await tester.pumpWidget(const SizedBox());
      h.close();
    }
  });
}
