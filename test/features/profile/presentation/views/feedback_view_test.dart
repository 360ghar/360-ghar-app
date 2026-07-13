// test/features/profile/presentation/views/feedback_view_test.dart
//
// Widget tests for [FeedbackView]. Covers rendering of the feedback form
// (dropdowns, text fields, submit button), form validation, dropdown
// interactions, and the submitting/loading state.

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:ghar360/core/data/models/bug_report_model.dart';
import 'package:ghar360/features/profile/presentation/controllers/feedback_controller.dart';
import 'package:ghar360/features/profile/presentation/views/feedback_view.dart';
import '../../../../helpers/getx_test_binding.dart';
import '../../../../helpers/mocks.dart';
import '../../../../helpers/pump_app.dart';

// ---------------------------------------------------------------------------
// Stub controller
// ---------------------------------------------------------------------------

class _StubFeedbackController extends GetxServiceMock implements FeedbackController {
  @override
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  @override
  final TextEditingController titleController = TextEditingController();

  @override
  final TextEditingController descriptionController = TextEditingController();

  @override
  final TextEditingController stepsController = TextEditingController();

  @override
  final TextEditingController expectedController = TextEditingController();

  @override
  final TextEditingController actualController = TextEditingController();

  @override
  final TextEditingController tagsController = TextEditingController();

  @override
  final Rx<BugType> selectedBugType = BugType.uiBug.obs;

  @override
  final Rx<BugSeverity> selectedSeverity = BugSeverity.medium.obs;

  @override
  final RxBool isSubmitting = false.obs;

  bool submitCalled = false;
  bool submitValidationPassed = false;

  @override
  Future<void> submitFeedback() async {
    submitCalled = true;
    submitValidationPassed = formKey.currentState?.validate() ?? false;
  }

  @override
  void setBugType(BugType? type) {
    if (type != null) {
      selectedBugType.value = type;
    }
  }

  @override
  void setSeverity(BugSeverity? severity) {
    if (severity != null) {
      selectedSeverity.value = severity;
    }
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _StubFeedbackController controller;

  setUp(() {
    GetxTestBinding.init();
    controller = _StubFeedbackController();
    Get.put<FeedbackController>(controller);
  });

  tearDown(() => GetxTestBinding.reset());

  Future<void> pumpView(WidgetTester tester) async {
    await tester.pumpApp(const FeedbackView());
    await tester.pump();
  }

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

      expect(controller.selectedBugType.value, BugType.crash);
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

      expect(controller.selectedSeverity.value, BugSeverity.critical);
    });
  });

  group('FeedbackView text input', () {
    testWidgets('entering text in title field updates the controller', (tester) async {
      await pumpView(tester);

      await tester.enterText(
        find.byKey(const ValueKey('qa.profile.feedback.title_input')),
        'Test bug title',
      );
      await tester.pump();

      expect(controller.titleController.text, 'Test bug title');
    });

    testWidgets('entering text in description field updates the controller', (tester) async {
      await pumpView(tester);

      await tester.enterText(
        find.byKey(const ValueKey('qa.profile.feedback.description_input')),
        'This is a description of the issue.',
      );
      await tester.pump();

      expect(controller.descriptionController.text, 'This is a description of the issue.');
    });

    testWidgets('entering text in steps field updates the controller', (tester) async {
      await pumpView(tester);

      // The form has 6 TextFormFields: title, description, steps, expected,
      // actual, tags. Steps is at index 2.
      final fields = find.byType(TextFormField);
      expect(fields, findsNWidgets(6));

      await tester.enterText(fields.at(2), '1. Open app\n2. Tap search');
      await tester.pump();

      expect(controller.stepsController.text, '1. Open app\n2. Tap search');
    });

    testWidgets('entering text in tags field updates the controller', (tester) async {
      await pumpView(tester);

      // Tags is the last TextFormField (index 5).
      final fields = find.byType(TextFormField);

      await tester.enterText(fields.at(5), 'login, search');
      await tester.pump();

      expect(controller.tagsController.text, 'login, search');
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

      expect(controller.submitCalled, isTrue);
      expect(controller.submitValidationPassed, isTrue);
    });
  });

  group('FeedbackView submitting state', () {
    testWidgets('shows progress indicator and disables button when submitting', (tester) async {
      controller.isSubmitting.value = true;
      await pumpView(tester);

      // Use pump (not pumpAndSettle) because CircularProgressIndicator is an
      // infinite animation that never settles.
      await tester.pump();

      final button = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey('qa.profile.feedback.submit')),
      );
      expect(button.onPressed, isNull); // Disabled when submitting.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Sending feedback...'), findsOneWidget);
    });

    testWidgets('shows send feedback text and enables button when not submitting', (tester) async {
      await pumpView(tester);

      await tester.ensureVisible(find.byKey(const ValueKey('qa.profile.feedback.submit')));
      await tester.pumpAndSettle();

      final button = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey('qa.profile.feedback.submit')),
      );
      expect(button.onPressed, isNotNull); // Enabled when not submitting.
      // 'Send Feedback' appears in both the app bar and the button.
      expect(find.text('Send Feedback'), findsWidgets);
    });
  });
}
