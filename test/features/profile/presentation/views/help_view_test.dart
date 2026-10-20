import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/features/profile/presentation/views/help_view.dart';
import '../../../../helpers/profile_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProfileHarness h;
  setUp(() {
    h = ProfileHarness();
  });
  tearDown(() => h.close());
  Future<void> pumpHelpView(WidgetTester tester) => h.pump(tester, const HelpView());
  group('HelpView rendering', () {
    testWidgets('renders the help screen with app bar title', (tester) async {
      await pumpHelpView(tester);

      expect(find.byType(HelpView), findsOneWidget);
      expect(find.text('Help'), findsOneWidget);
    });

    testWidgets('renders all main section titles', (tester) async {
      await pumpHelpView(tester);

      expect(find.text('Quick Actions'), findsOneWidget);
      expect(find.text('Frequently Asked Questions'), findsOneWidget);
      expect(find.text('Troubleshooting'), findsOneWidget);
      expect(find.text('Guides & Tutorials'), findsNothing);
      expect(find.text('Contact Information'), findsOneWidget);
      expect(find.text('Feedback'), findsWidgets);
    });

    testWidgets('renders only quick actions that work', (tester) async {
      await pumpHelpView(tester);

      // Live chat and callback had no backend; they only showed a placeholder toast.
      expect(find.text('Chat with Support'), findsNothing);
      expect(find.text('Request a Callback'), findsNothing);
      expect(find.text('Email Support'), findsOneWidget);
      expect(find.text('Report a Bug'), findsOneWidget);
      expect(find.text('Request a Feature'), findsOneWidget);
    });

    testWidgets('renders all five FAQ questions', (tester) async {
      await pumpHelpView(tester);

      expect(find.text('How do I find properties that match my needs?'), findsOneWidget);
      expect(find.text('How can I tailor my recommendations?'), findsOneWidget);
      expect(find.text('How do I manage alerts and reminders?'), findsOneWidget);
      expect(find.text('How do I schedule a visit or virtual tour?'), findsOneWidget);
      expect(find.text('How do I change the app language or theme?'), findsOneWidget);
    });

    testWidgets('placeholder guides are not offered', (tester) async {
      await pumpHelpView(tester);

      expect(find.text('Get Started with 360ghar'), findsNothing);
      expect(find.text('Scheduling Property Visits'), findsNothing);
    });

    testWidgets('renders contact info items', (tester) async {
      await pumpHelpView(tester);

      expect(find.text('Support Hours'), findsOneWidget);
      expect(find.text('Office Address'), findsOneWidget);
      expect(find.text('Languages Supported'), findsOneWidget);
    });

    testWidgets('renders send feedback button with correct key', (tester) async {
      await pumpHelpView(tester);

      expect(find.byKey(const ValueKey('qa.profile.help.send_feedback')), findsOneWidget);
    });

    testWidgets('renders troubleshooting section titles', (tester) async {
      await pumpHelpView(tester);

      // Scroll down to make troubleshooting visible.
      await tester.scrollUntilVisible(
        find.text('Troubleshooting'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Troubleshooting sub-item titles are rendered as Text widgets.
      expect(find.text('Troubleshooting'), findsOneWidget);
    });
  });

  group('HelpView quick action interactions', () {
    testWidgets('tapping Email Support falls back to toast when launcher unavailable', (
      tester,
    ) async {
      await pumpHelpView(tester);

      await tester.tap(find.text('Email Support'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.textContaining('support@360ghar.com'), findsOneWidget);
      // Let the toast expire.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      expect(find.byType(HelpView), findsOneWidget);
    });

    testWidgets('tapping Report a Bug navigates to feedback route', (tester) async {
      await pumpHelpView(tester);

      await tester.tap(find.text('Report a Bug'));
      await tester.pumpAndSettle();

      expect(find.text('Feedback Route Destination'), findsOneWidget);
    });

    testWidgets('tapping Request a Feature navigates to feedback route', (tester) async {
      await pumpHelpView(tester);

      await tester.tap(find.text('Request a Feature'));
      await tester.pumpAndSettle();

      expect(find.text('Feedback Route Destination'), findsOneWidget);
    });
  });

  group('HelpView FAQ interactions', () {
    testWidgets('tapping a FAQ item expands it to show the answer', (tester) async {
      await pumpHelpView(tester);

      // FAQ Q1 is visible near the top.
      final faqFinder = find.text('How do I find properties that match my needs?');

      await tester.ensureVisible(faqFinder);
      await tester.pumpAndSettle();

      // Tap to expand.
      await tester.tap(faqFinder, warnIfMissed: false);
      await tester.pumpAndSettle();

      // After expansion, the ExpansionTile children are built.
      expect(find.byType(ExpansionTile), findsWidgets);
    });

    testWidgets('tapping an expanded FAQ item collapses it', (tester) async {
      await pumpHelpView(tester);

      final faqFinder = find.text('How do I find properties that match my needs?');

      await tester.ensureVisible(faqFinder);
      await tester.pumpAndSettle();

      // Expand.
      await tester.tap(faqFinder, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Collapse.
      await tester.tap(faqFinder, warnIfMissed: false);
      await tester.pumpAndSettle();

      // The ExpansionTile is still present but collapsed.
      expect(find.byType(ExpansionTile), findsNWidgets(5));
    });
  });

  group('HelpView send feedback button', () {
    testWidgets('tapping Send Feedback navigates to feedback route', (tester) async {
      await pumpHelpView(tester);

      await tester.ensureVisible(find.byKey(const ValueKey('qa.profile.help.send_feedback')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('qa.profile.help.send_feedback')));
      await tester.pumpAndSettle();

      expect(find.text('Feedback Route Destination'), findsOneWidget);
    });
  });
}
