import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/features/auth/presentation/widgets/auth_premium_shell.dart';
import '../../../../helpers/provider_test_app.dart';

void main() {
  testWidgets('static title dismisses keyboard without losing text or intercepting controls', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final focus = FocusNode();
    final text = TextEditingController();
    var submissions = 0;
    try {
      await tester.pumpProviderApp(
        AuthPremiumShell(
          title: 'Sign in or create your account',
          subtitle: '',
          child: Column(
            children: [
              TextField(controller: text, focusNode: focus),
              FilledButton(onPressed: () => submissions++, child: const Text('Continue')),
            ],
          ),
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'draft@example.com');
      await tester.pump();
      expect(focus.hasFocus, true);
      expect(tester.testTextInput.isVisible, true);

      final title = find.bySemanticsIdentifier('qa.auth.shell.title');
      expect(title, findsOneWidget);
      expect(tester.getSemantics(title).label, 'Sign in or create your account');
      expect(find.bySemanticsLabel('qa.auth.shell.title'), findsNothing);
      await tester.tap(title);
      await tester.pump();
      expect(focus.hasFocus, false);
      expect(tester.testTextInput.isVisible, false);
      expect(text.text, 'draft@example.com');
      expect(submissions, 0);

      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(focus.hasFocus, true);
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(submissions, 1);
      expect(text.text, 'draft@example.com');
    } finally {
      semantics.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      focus.dispose();
      text.dispose();
    }
  });

  testWidgets('scroll drag dismisses keyboard and retains the form draft', (tester) async {
    final focus = FocusNode();
    final text = TextEditingController();
    try {
      await tester.pumpProviderApp(
        AuthPremiumShell(
          title: 'Complete your profile',
          subtitle: '',
          child: Column(
            children: [
              TextField(controller: text, focusNode: focus),
              const SizedBox(height: 900),
            ],
          ),
        ),
      );
      await tester.ensureVisible(find.byType(TextField));
      await tester.pump();
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'retained draft');
      await tester.pump();
      expect(focus.hasFocus, true);
      expect(
        tester.widget<CustomScrollView>(find.byType(CustomScrollView)).keyboardDismissBehavior,
        ScrollViewKeyboardDismissBehavior.onDrag,
      );
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -150));
      await tester.pump();
      expect(focus.hasFocus, false);
      expect(tester.testTextInput.isVisible, false);
      expect(text.text, 'retained draft');
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      focus.dispose();
      text.dispose();
    }
  });
}
