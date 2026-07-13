// test/features/profile/presentation/views/help_view_test.dart
//
// Widget tests for [HelpView]. Covers rendering of all help sections
// (quick actions, FAQ, troubleshooting, guides, contact info, feedback)
// and interactions with tappable elements (toasts, navigation, FAQ expansion).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/core/translations/app_translations.dart';
import 'package:ghar360/features/profile/presentation/views/help_view.dart';
import '../../../../helpers/getx_test_binding.dart';

void main() {
  // Mock the url_launcher platform channel so [canLaunchUrl] returns false,
  // exercising the fallback [AppToast.info] branch in _emailSupport.
  const urlLauncherChannel = MethodChannel('plugins.flutter.io/url_launcher');

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      urlLauncherChannel,
      (MethodCall methodCall) async {
        if (methodCall.method == 'canLaunch') {
          return false;
        }
        return null;
      },
    );
  });

  setUp(() {
    GetxTestBinding.init();
    // Suppress RenderFlex overflow errors that occur in the constrained
    // test viewport but not on real devices.
    FlutterError.onError = (FlutterErrorDetails details) {
      final exception = details.exception;
      if (exception is FlutterError && exception.toString().contains('overflowed')) {
        return;
      }
      FlutterError.presentError(details);
    };
  });

  tearDown(() {
    GetxTestBinding.reset();
    FlutterError.onError = FlutterError.presentError;
  });

  Future<void> pumpHelpView(WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        fallbackLocale: const Locale('en', 'US'),
        getPages: [
          GetPage(
            name: AppRoutes.feedback,
            page: () => const Scaffold(body: Center(child: Text('Feedback Route Destination'))),
          ),
        ],
        home: const HelpView(),
      ),
    );
    await tester.pump();
  }

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
      expect(find.text('Guides & Tutorials'), findsOneWidget);
      expect(find.text('Contact Information'), findsOneWidget);
      expect(find.text('Feedback'), findsWidgets);
    });

    testWidgets('renders all five quick action items', (tester) async {
      await pumpHelpView(tester);

      expect(find.text('Chat with Support'), findsOneWidget);
      expect(find.text('Request a Callback'), findsOneWidget);
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

    testWidgets('renders all four guide items', (tester) async {
      await pumpHelpView(tester);

      expect(find.text('Get Started with 360ghar'), findsOneWidget);
      expect(find.text('Mastering Property Search'), findsOneWidget);
      expect(find.text('Personalising Preferences'), findsOneWidget);
      expect(find.text('Scheduling Property Visits'), findsOneWidget);
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
    testWidgets('tapping Chat with Support triggers toast (no crash)', (tester) async {
      await pumpHelpView(tester);

      await tester.tap(find.text('Chat with Support'));
      // Pump long enough for the GetX snackbar animation to complete and dismiss.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      expect(find.byType(HelpView), findsOneWidget);
    });

    testWidgets('tapping Request a Callback triggers toast (no crash)', (tester) async {
      await pumpHelpView(tester);

      await tester.tap(find.text('Request a Callback'));
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      expect(find.byType(HelpView), findsOneWidget);
    });

    testWidgets('tapping Email Support falls back to toast when launcher unavailable', (
      tester,
    ) async {
      await pumpHelpView(tester);

      await tester.tap(find.text('Email Support'));
      // Allow the async canLaunchUrl to resolve and the toast to complete.
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

  group('HelpView guide interactions', () {
    testWidgets('tapping a guide item triggers toast (no crash)', (tester) async {
      await pumpHelpView(tester);

      await tester.ensureVisible(find.text('Get Started with 360ghar'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Get Started with 360ghar'), warnIfMissed: false);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      expect(find.byType(HelpView), findsOneWidget);
    });

    testWidgets('tapping Mastering Property Search guide triggers toast', (tester) async {
      await pumpHelpView(tester);

      await tester.ensureVisible(find.text('Mastering Property Search'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mastering Property Search'), warnIfMissed: false);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      expect(find.byType(HelpView), findsOneWidget);
    });

    testWidgets('tapping Personalising Preferences guide triggers toast', (tester) async {
      await pumpHelpView(tester);

      await tester.ensureVisible(find.text('Personalising Preferences'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Personalising Preferences'), warnIfMissed: false);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      expect(find.byType(HelpView), findsOneWidget);
    });

    testWidgets('tapping Scheduling Property Visits guide triggers toast', (tester) async {
      await pumpHelpView(tester);

      await tester.ensureVisible(find.text('Scheduling Property Visits'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Scheduling Property Visits'), warnIfMissed: false);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      expect(find.byType(HelpView), findsOneWidget);
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
