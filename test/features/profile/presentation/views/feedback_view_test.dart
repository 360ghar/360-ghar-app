import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/data/models/bug_report_model.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/profile/presentation/controllers/feedback_controller.dart';
import 'package:ghar360/features/profile/presentation/views/feedback_view.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/profile_test_harness.dart';

void main() {
  late ProfileHarness h;
  setUp(() => h = ProfileHarness());
  tearDown(() => h.close());
  Future<void> pumpView(WidgetTester tester) => h.pump(tester, const FeedbackView());
  group('FeedbackView rendering', () {
    testWidgets('renders the feedback screen with app bar title', (tester) async {
      await pumpView(tester);

      expect(find.byType(FeedbackView), findsOneWidget);
      expect(find.text('Send Feedback'), findsWidgets);
    });

    testWidgets('renders feedback subtitle text', (tester) async {
      await pumpView(tester);

      expect(
        find.text('Help our team fix issues faster by sharing a few details.'),
        findsOneWidget,
      );
    });

    testWidgets('renders issue type and severity dropdowns', (tester) async {
      await pumpView(tester);

      expect(find.text('Issue type'), findsOneWidget);
      expect(find.text('Severity'), findsOneWidget);
    });

    testWidgets('renders all text input fields with labels', (tester) async {
      await pumpView(tester);

      expect(find.text('Title'), findsOneWidget);
      expect(find.text('What happened?'), findsOneWidget);
      expect(find.text('Steps to reproduce (optional)'), findsOneWidget);
      expect(find.text('Expected behaviour (optional)'), findsOneWidget);
      expect(find.text('Actual behaviour (optional)'), findsOneWidget);
      expect(find.text('Tags (optional)'), findsOneWidget);
    });

    testWidgets('renders submit button with correct key', (tester) async {
      await pumpView(tester);

      await tester.ensureVisible(find.byKey(const ValueKey('qa.profile.feedback.submit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('qa.profile.feedback.submit')), findsOneWidget);
    });

    testWidgets('renders text input hints', (tester) async {
      await pumpView(tester);

      expect(find.text('Give a short summary (e.g. Search filters not working)'), findsOneWidget);
      expect(find.text('Share what you expected and what you saw'), findsOneWidget);
    });
  });

  group('FeedbackView dropdown interactions', () {
    testWidgets('bug type dropdown shows all bug type options when tapped', (tester) async {
      await pumpView(tester);

      await tester.tap(find.byType(DropdownButtonFormField<BugType>).first);
      await tester.pumpAndSettle();

      // 'UI bug' appears both as the selected value and in the menu.
      expect(find.text('UI bug'), findsNWidgets(2));
      expect(find.text('Functionality bug'), findsOneWidget);
      expect(find.text('Performance issue'), findsOneWidget);
      expect(find.text('App crash'), findsOneWidget);
      expect(find.text('Feature request'), findsOneWidget);
      expect(find.text('Other'), findsOneWidget);

      // Dismiss the dropdown menu.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
    });

    testWidgets('selecting a different bug type calls setBugType', (tester) async {
      await pumpView(tester);

      await tester.tap(find.byType(DropdownButtonFormField<BugType>).first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('App crash').last);
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<DropdownButtonFormField<BugType>>(find.byType(DropdownButtonFormField<BugType>))
            .initialValue,
        BugType.crash,
      );
    });

    testWidgets('severity dropdown shows all severity options when tapped', (tester) async {
      await pumpView(tester);

      await tester.tap(find.byType(DropdownButtonFormField<BugSeverity>).first);
      await tester.pumpAndSettle();

      // 'Medium - impacts experience' appears both as selected value and in menu.
      expect(find.text('Low - minor inconvenience'), findsOneWidget);
      expect(find.text('Medium - impacts experience'), findsNWidgets(2));
      expect(find.text('High - major issue'), findsOneWidget);
      expect(find.text('Critical - blocking issue'), findsOneWidget);

      // Dismiss the dropdown menu.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
    });

    testWidgets('selecting a different severity calls setSeverity', (tester) async {
      await pumpView(tester);

      await tester.tap(find.byType(DropdownButtonFormField<BugSeverity>).first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Critical - blocking issue').last);
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<DropdownButtonFormField<BugSeverity>>(
              find.byType(DropdownButtonFormField<BugSeverity>),
            )
            .initialValue,
        BugSeverity.critical,
      );
    });
  });

  group('FeedbackView text input', () {
    testWidgets('the title field stops at 200 characters, the limit of the backend', (
      tester,
    ) async {
      await pumpView(tester);

      await tester.enterText(
        find.byKey(const ValueKey('qa.profile.feedback.title_input')),
        'x' * 260,
      );
      await tester.pump();

      expect(
        tester.widget<TextFormField>(find.byType(TextFormField).at(0)).controller!.text,
        hasLength(200),
      );
    });

    testWidgets('entering text in title field updates the controller', (tester) async {
      await pumpView(tester);

      await tester.enterText(
        find.byKey(const ValueKey('qa.profile.feedback.title_input')),
        'Test bug title',
      );
      await tester.pump();

      expect(
        tester.widget<TextFormField>(find.byType(TextFormField).at(0)).controller!.text,
        'Test bug title',
      );
    });

    testWidgets('entering text in description field updates the controller', (tester) async {
      await pumpView(tester);

      await tester.enterText(
        find.byKey(const ValueKey('qa.profile.feedback.description_input')),
        'This is a description of the issue.',
      );
      await tester.pump();

      expect(
        tester.widget<TextFormField>(find.byType(TextFormField).at(1)).controller!.text,
        'This is a description of the issue.',
      );
    });

    testWidgets('entering text in steps field updates the controller', (tester) async {
      await pumpView(tester);

      // The form has 6 TextFormFields: title, description, steps, expected,
      // actual, tags. Steps is at index 2.
      final fields = find.byType(TextFormField);
      expect(fields, findsNWidgets(6));

      await tester.enterText(fields.at(2), '1. Open app\n2. Tap search');
      await tester.pump();

      expect(
        tester.widget<TextFormField>(find.byType(TextFormField).at(2)).controller!.text,
        '1. Open app\n2. Tap search',
      );
    });

    testWidgets('entering text in tags field updates the controller', (tester) async {
      await pumpView(tester);

      // Tags is the last TextFormField (index 5).
      final fields = find.byType(TextFormField);

      await tester.enterText(fields.at(5), 'login, search');
      await tester.pump();

      expect(
        tester.widget<TextFormField>(find.byType(TextFormField).at(5)).controller!.text,
        'login, search',
      );
    });
  });

  group('FeedbackView form validation', () {
    testWidgets('submitting with empty title shows validation error', (tester) async {
      await pumpView(tester);

      await tester.ensureVisible(find.byKey(const ValueKey('qa.profile.feedback.submit')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('qa.profile.feedback.submit')));
      await tester.pumpAndSettle();

      expect(find.text('Please describe the issue in a short title'), findsOneWidget);
    });

    testWidgets('submitting with empty description shows validation error', (tester) async {
      await pumpView(tester);

      // Fill in the title so only description validation fails.
      await tester.enterText(
        find.byKey(const ValueKey('qa.profile.feedback.title_input')),
        'Valid title',
      );
      await tester.pump();

      await tester.ensureVisible(find.byKey(const ValueKey('qa.profile.feedback.submit')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('qa.profile.feedback.submit')));
      await tester.pumpAndSettle();

      expect(find.text('Please provide a short description of the problem'), findsOneWidget);
    });

    testWidgets('submitting with valid data calls submitFeedback', (tester) async {
      await pumpView(tester);

      await tester.enterText(
        find.byKey(const ValueKey('qa.profile.feedback.title_input')),
        'Valid title',
      );
      await tester.enterText(
        find.byKey(const ValueKey('qa.profile.feedback.description_input')),
        'Valid description',
      );
      await tester.pump();

      await tester.ensureVisible(find.byKey(const ValueKey('qa.profile.feedback.submit')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('qa.profile.feedback.submit')));
      await tester.pumpAndSettle();

      verify(() => h.support.submitBugReport(any())).called(1);
    });
  });

  group('FeedbackView submitting state', () {
    testWidgets('shows progress indicator and disables button when submitting', (tester) async {
      h.listen(feedbackProvider);
      final pending = Completer<BugReportResponse>();
      when(() => h.support.submitBugReport(any())).thenAnswer((_) => pending.future);
      final result = h.container
          .read(feedbackProvider.notifier)
          .submitFeedback(
            type: BugType.uiBug,
            severity: BugSeverity.medium,
            title: 'Title',
            description: 'Description',
          );
      await pumpView(tester);

      // Use pump (not pumpAndSettle) because CircularProgressIndicator is an
      // infinite animation that never settles.
      await tester.pump();

      final button = tester.widget<FilledButton>(
        find.byKey(const ValueKey('qa.profile.feedback.submit')),
      );
      expect(button.onPressed, isNull); // Disabled when submitting.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester
            .widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator))
            .semanticsLabel,
        'Sending feedback...',
      );
      pending.complete(bugResponse());
      await tester.pump();
      await result;
    });

    testWidgets('shows send feedback text and enables button when not submitting', (tester) async {
      await pumpView(tester);

      await tester.ensureVisible(find.byKey(const ValueKey('qa.profile.feedback.submit')));
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(
        find.byKey(const ValueKey('qa.profile.feedback.submit')),
      );
      expect(button.onPressed, isNotNull); // Enabled when not submitting.
      // 'Send Feedback' appears in both the app bar and the button.
      expect(find.text('Send Feedback'), findsWidgets);
    });
  });
  testWidgets('failed feedback preserves draft then retry succeeds', (tester) async {
    when(() => h.support.submitBugReport(any())).thenThrow(NetworkException('offline'));
    await pumpView(tester);
    await tester.enterText(
      find.byKey(const ValueKey('qa.profile.feedback.title_input')),
      'Draft title',
    );
    await tester.enterText(
      find.byKey(const ValueKey('qa.profile.feedback.description_input')),
      'Draft description',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('qa.profile.feedback.submit')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('qa.profile.feedback.submit')));
    await tester.pumpAndSettle();
    expect(find.byType(FeedbackView), findsOneWidget);
    expect(find.text('Draft title'), findsOneWidget);
    expect(find.text('Draft description'), findsOneWidget);
    when(() => h.support.submitBugReport(any())).thenAnswer((_) async => bugResponse());
    await tester.ensureVisible(find.byKey(const ValueKey('qa.profile.feedback.submit')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('qa.profile.feedback.submit')));
    await tester.pumpAndSettle();
    expect(find.text('Back destination'), findsOneWidget);
  });
  testWidgets('submit dimensions stay fixed while loading', (tester) async {
    final pending = Completer<BugReportResponse>();
    when(() => h.support.submitBugReport(any())).thenAnswer((_) => pending.future);
    await pumpView(tester);
    await tester.enterText(find.byKey(const ValueKey('qa.profile.feedback.title_input')), 'Title');
    await tester.enterText(
      find.byKey(const ValueKey('qa.profile.feedback.description_input')),
      'Description',
    );
    final button = find.byKey(const ValueKey('qa.profile.feedback.submit'));
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    final size = tester.getSize(button);
    await tester.tap(button);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    verify(() => h.support.submitBugReport(any())).called(1);
    expect(tester.getSize(button), size);
    pending.complete(bugResponse());
    await tester.pumpAndSettle();
  });
  testWidgets('typed feature request route argument starts selected', (tester) async {
    await h.pump(tester, const FeedbackView(initialBugType: BugType.featureRequest));
    expect(
      tester
          .widget<DropdownButtonFormField<BugType>>(find.byType(DropdownButtonFormField<BugType>))
          .initialValue,
      BugType.featureRequest,
    );
  });
  testWidgets('severity menu fits a narrow phone with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await h.pump(tester, const FeedbackView(), scale: 2);
    final field = find.byType(DropdownButtonFormField<BugSeverity>);
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.tap(field);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Critical - blocking issue').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('server field errors show under their fields and keep the draft', (tester) async {
    when(() => h.support.submitBugReport(any())).thenThrow(
      ValidationException(
        'The request was not valid.',
        code: 'VALIDATION_ERROR',
        fieldErrors: {
          'title': ['string_too_long'],
          'description': ['missing'],
        },
      ),
    );
    await pumpView(tester);
    await tester.enterText(
      find.byKey(const ValueKey('qa.profile.feedback.title_input')),
      'Draft title',
    );
    await tester.enterText(
      find.byKey(const ValueKey('qa.profile.feedback.description_input')),
      'Draft description',
    );
    // Focus scrolls the last field into view; let that finish first.
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('qa.profile.feedback.submit')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('qa.profile.feedback.submit')));
    await tester.pumpAndSettle();

    expect(find.text('Draft title'), findsOneWidget);
    expect(find.text('Draft description'), findsOneWidget);
    expect(find.text(tr('field_error_too_long')), findsOneWidget);
    expect(find.text(tr('field_error_required')), findsOneWidget);
    expect(find.text(tr('form_check_fields')), findsOneWidget);
    expect(find.text('VALIDATION_ERROR'), findsNothing);
  });
}
