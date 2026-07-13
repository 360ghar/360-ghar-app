// test/features/profile/presentation/controllers/feedback_controller_test.dart
//
// Unit tests for [FeedbackController]. The controller depends on
// [SupportRepository] (mocked), uses GetX for navigation/toasts, and reads
// [PackageInfo] from the platform. Tests cover bug type/severity selection,
// form validation guards, submission success/error paths, and disposal.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/data/models/bug_report_model.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/profile/data/support_repository.dart';
import 'package:ghar360/features/profile/presentation/controllers/feedback_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/getx_test_binding.dart';
import '../../../../helpers/mocks.dart';

class MockSupportRepository extends GetxServiceMock implements SupportRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(
      const BugReportRequest(
        source: 'mobile',
        bugType: BugType.uiBug,
        severity: BugSeverity.medium,
        title: 'fallback',
        description: 'fallback',
      ),
    );

    // Mock the package_info_plus method channel so PackageInfo.fromPlatform()
    // doesn't hang waiting for a platform response in widget tests.
    const packageInfoChannel = MethodChannel('dev.fluttercommunity.plus/package_info');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      packageInfoChannel,
      (MethodCall call) async {
        if (call.method == 'getAll') {
          return <String, dynamic>{
            'appName': 'ghar360',
            'packageName': 'com.ghar360.app',
            'version': '1.0.0',
            'buildNumber': '1',
            'buildSignature': '',
            'installerStore': null,
          };
        }
        return null;
      },
    );
  });

  late MockSupportRepository supportRepo;

  setUp(() {
    GetxTestBinding.init();
    Get.locale = const Locale('en', 'US');
    Get.addTranslations({
      'en_US': {
        'feedback_sent': 'Feedback sent',
        'thanks_for_feedback': 'Thanks for feedback',
        'feedback_failed': 'Feedback failed',
        'feedback_send_error': 'Send error',
      },
    });

    supportRepo = MockSupportRepository();
    GetxTestBinding.bind().register<SupportRepository>(supportRepo);
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  FeedbackController createController() {
    // Reset arguments to null for each controller creation.
    Get.routing.update((r) => r.args = null);
    final controller = FeedbackController(supportRepository: supportRepo);
    Get.put<FeedbackController>(controller, permanent: true);
    return controller;
  }

  /// Set Get.arguments by manipulating the routing state directly.
  void setArguments(dynamic args) {
    Get.routing.update((r) => r.args = args);
  }

  group('FeedbackController initial state', () {
    test('defaults to uiBug and medium severity', () {
      final controller = createController();

      expect(controller.selectedBugType.value, BugType.uiBug);
      expect(controller.selectedSeverity.value, BugSeverity.medium);
      expect(controller.isSubmitting.value, isFalse);

      Get.delete<FeedbackController>();
    });

    test('reads initialBugType from Get.arguments when provided', () {
      setArguments({'initialBugType': BugType.crash});

      final controller = FeedbackController(supportRepository: supportRepo);
      Get.put<FeedbackController>(controller, permanent: true);

      expect(controller.selectedBugType.value, BugType.crash);

      Get.delete<FeedbackController>();
    });

    test('ignores Get.arguments when initialBugType is not a BugType', () {
      setArguments({'initialBugType': 'not-a-bug-type'});

      final controller = FeedbackController(supportRepository: supportRepo);
      Get.put<FeedbackController>(controller, permanent: true);

      expect(controller.selectedBugType.value, BugType.uiBug);

      Get.delete<FeedbackController>();
    });

    test('ignores Get.arguments when it is not a Map', () {
      setArguments('string-argument');

      final controller = FeedbackController(supportRepository: supportRepo);
      Get.put<FeedbackController>(controller, permanent: true);

      expect(controller.selectedBugType.value, BugType.uiBug);

      Get.delete<FeedbackController>();
    });
  });

  group('setBugType', () {
    test('updates the selected bug type when non-null', () {
      final controller = createController();

      controller.setBugType(BugType.featureRequest);
      expect(controller.selectedBugType.value, BugType.featureRequest);

      Get.delete<FeedbackController>();
    });

    test('ignores null', () {
      final controller = createController();

      controller.setBugType(null);
      expect(controller.selectedBugType.value, BugType.uiBug);

      Get.delete<FeedbackController>();
    });

    test('can set all bug types', () {
      final controller = createController();

      for (final type in BugType.values) {
        controller.setBugType(type);
        expect(controller.selectedBugType.value, type);
      }

      Get.delete<FeedbackController>();
    });
  });

  group('setSeverity', () {
    test('updates the selected severity when non-null', () {
      final controller = createController();

      controller.setSeverity(BugSeverity.critical);
      expect(controller.selectedSeverity.value, BugSeverity.critical);

      Get.delete<FeedbackController>();
    });

    test('ignores null', () {
      final controller = createController();

      controller.setSeverity(null);
      expect(controller.selectedSeverity.value, BugSeverity.medium);

      Get.delete<FeedbackController>();
    });

    test('can set all severities', () {
      final controller = createController();

      for (final severity in BugSeverity.values) {
        controller.setSeverity(severity);
        expect(controller.selectedSeverity.value, severity);
      }

      Get.delete<FeedbackController>();
    });
  });

  group('submitFeedback guards', () {
    test('returns early when already submitting', () async {
      final controller = createController();
      controller.isSubmitting.value = true;

      await controller.submitFeedback();

      verifyNever(() => supportRepo.submitBugReport(any()));

      Get.delete<FeedbackController>();
    });

    test('returns early when form state is null (no widget tree)', () async {
      final controller = createController();

      await controller.submitFeedback();

      // formKey.currentState is null → validate() is skipped → early return.
      verifyNever(() => supportRepo.submitBugReport(any()));
      expect(controller.isSubmitting.value, isFalse);

      Get.delete<FeedbackController>();
    });
  });

  group('onClose', () {
    test('disposes text controllers without throwing', () {
      final controller = createController();

      expect(controller.onClose, returnsNormally);

      Get.delete<FeedbackController>();
    });
  });

  group('BugType enum', () {
    test('fromValue returns the correct type for known values', () {
      expect(BugType.fromValue('ui_bug'), BugType.uiBug);
      expect(BugType.fromValue('functionality_bug'), BugType.functionalityBug);
      expect(BugType.fromValue('performance_issue'), BugType.performanceIssue);
      expect(BugType.fromValue('crash'), BugType.crash);
      expect(BugType.fromValue('feature_request'), BugType.featureRequest);
      expect(BugType.fromValue('other'), BugType.other);
    });

    test('fromValue is case-insensitive', () {
      expect(BugType.fromValue('UI_BUG'), BugType.uiBug);
      expect(BugType.fromValue('Crash'), BugType.crash);
    });

    test('fromValue defaults to other for unknown values', () {
      expect(BugType.fromValue('unknown'), BugType.other);
      expect(BugType.fromValue(null), BugType.other);
    });

    test('value property returns the wire format', () {
      expect(BugType.uiBug.value, 'ui_bug');
      expect(BugType.crash.value, 'crash');
      expect(BugType.featureRequest.value, 'feature_request');
    });
  });

  group('BugSeverity enum', () {
    test('fromValue returns the correct severity for known values', () {
      expect(BugSeverity.fromValue('low'), BugSeverity.low);
      expect(BugSeverity.fromValue('medium'), BugSeverity.medium);
      expect(BugSeverity.fromValue('high'), BugSeverity.high);
      expect(BugSeverity.fromValue('critical'), BugSeverity.critical);
    });

    test('fromValue is case-insensitive', () {
      expect(BugSeverity.fromValue('HIGH'), BugSeverity.high);
      expect(BugSeverity.fromValue('Critical'), BugSeverity.critical);
    });

    test('fromValue defaults to medium for unknown values', () {
      expect(BugSeverity.fromValue('unknown'), BugSeverity.medium);
      expect(BugSeverity.fromValue(null), BugSeverity.medium);
    });

    test('value property returns the wire format', () {
      expect(BugSeverity.low.value, 'low');
      expect(BugSeverity.critical.value, 'critical');
    });
  });

  group('BugReportRequest serialization', () {
    test('toJson includes required fields and excludes null optional fields', () {
      const request = BugReportRequest(
        source: 'mobile',
        bugType: BugType.uiBug,
        severity: BugSeverity.high,
        title: 'Test title',
        description: 'Test description',
      );

      final json = request.toJson();

      expect(json['source'], 'mobile');
      expect(json['bug_type'], 'ui_bug');
      expect(json['severity'], 'high');
      expect(json['title'], 'Test title');
      expect(json['description'], 'Test description');
      // Optional fields should be excluded when null.
      expect(json.containsKey('steps_to_reproduce'), isFalse);
      expect(json.containsKey('expected_behavior'), isFalse);
      expect(json.containsKey('actual_behavior'), isFalse);
      expect(json.containsKey('device_info'), isFalse);
      expect(json.containsKey('app_version'), isFalse);
      expect(json.containsKey('tags'), isFalse);
    });

    test('toJson includes optional fields when provided', () {
      const request = BugReportRequest(
        source: 'mobile',
        bugType: BugType.crash,
        severity: BugSeverity.critical,
        title: 'Crash',
        description: 'App crashed',
        stepsToReproduce: 'Open app',
        expectedBehavior: 'App loads',
        actualBehavior: 'App crashes',
        appVersion: '1.0.0+1',
        tags: ['ghar360', 'test'],
      );

      final json = request.toJson();

      expect(json['steps_to_reproduce'], 'Open app');
      expect(json['expected_behavior'], 'App loads');
      expect(json['actual_behavior'], 'App crashes');
      expect(json['app_version'], '1.0.0+1');
      expect(json['tags'], ['ghar360', 'test']);
    });
  });

  group('BugReportResponse parsing', () {
    test('fromJson parses a valid response', () {
      final json = {
        'id': 42,
        'source': 'mobile',
        'bug_type': 'ui_bug',
        'severity': 'medium',
        'status': 'open',
        'title': 'Test',
        'description': 'Description',
      };

      final response = BugReportResponse.fromJson(json);

      expect(response.id, 42);
      expect(response.source, 'mobile');
      expect(response.bugType, BugType.uiBug);
      expect(response.severity, BugSeverity.medium);
      expect(response.status, 'open');
      expect(response.title, 'Test');
      expect(response.description, 'Description');
    });

    test('fromJson throws FormatException for missing id', () {
      expect(
        () => BugReportResponse.fromJson({'source': 'mobile'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('fromJson throws FormatException for non-numeric id', () {
      expect(
        () => BugReportResponse.fromJson({'id': 'not-a-number'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('fromJson parses with optional fields', () {
      final json = {
        'id': 1,
        'source': 'mobile',
        'bug_type': 'crash',
        'severity': 'critical',
        'status': 'resolved',
        'title': 'T',
        'description': 'D',
        'tags': ['tag1', 'tag2'],
        'media_urls': ['url1'],
        'user_id': 10,
      };

      final response = BugReportResponse.fromJson(json);

      expect(response.tags, ['tag1', 'tag2']);
      expect(response.mediaUrls, ['url1']);
      expect(response.userId, 10);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // submitFeedback with a real FormState (widget test harness)
  // ─────────────────────────────────────────────────────────────────────
  // The controller guards on `formKey.currentState?.validate()`. Without a
  // widget tree the GlobalKey has no attached FormState, so the guard returns
  // early. These tests pump a minimal GetMaterialApp+Form with the controller's
  // formKey so the FormState is live and validate() succeeds. GetMaterialApp
  // is used so Get.back() and AppToast work correctly. A /home route is
  // provided so Get.back() has a route to pop.

  BugReportResponse bugResponse({int id = 1}) => BugReportResponse(
    id: id,
    source: 'mobile',
    bugType: BugType.uiBug,
    severity: BugSeverity.medium,
    status: 'open',
    title: 'Test',
    description: 'Test desc',
  );

  /// Pumps a minimal MaterialApp with the controller's formKey in a Form.
  /// Uses MaterialApp (not GetMaterialApp) so Get.back() is a no-op (Navigator
  /// pop with one route) and AppToast returns early (Get.overlayContext is
  /// null without GetMaterialApp), avoiding snackbar animation ticker leaks.
  /// The Form has no validators so validate() returns true.
  Future<void> withFormState(
    WidgetTester tester,
    FeedbackController controller,
    Future<void> Function() action,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(key: controller.formKey, child: const SizedBox.shrink()),
        ),
      ),
    );
    await tester.pump();
    await action();
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('submitFeedback — success path', () {
    testWidgets('submits bug report and navigates back on success', (tester) async {
      final supportRepo = MockSupportRepository();

      final controller = FeedbackController(supportRepository: supportRepo);
      controller.titleController.text = 'Test title';
      controller.descriptionController.text = 'Test description';
      controller.tagsController.text = 'bug, urgent';

      when(() => supportRepo.submitBugReport(any())).thenAnswer((_) async => bugResponse(id: 42));

      await withFormState(tester, controller, () async {
        await controller.submitFeedback();
      });

      verify(() => supportRepo.submitBugReport(any())).called(1);
      expect(controller.isSubmitting.value, isFalse);
    });

    testWidgets('includes ghar360 tag and user-entered tags in request', (tester) async {
      final supportRepo = MockSupportRepository();

      final controller = FeedbackController(supportRepository: supportRepo);
      controller.titleController.text = 'Title';
      controller.descriptionController.text = 'Desc';
      controller.tagsController.text = 'custom, tag';

      BugReportRequest? capturedRequest;
      when(() => supportRepo.submitBugReport(any())).thenAnswer((invocation) async {
        capturedRequest = invocation.positionalArguments[0] as BugReportRequest;
        return bugResponse();
      });

      await withFormState(tester, controller, () async {
        await controller.submitFeedback();
      });

      expect(capturedRequest, isNotNull);
      expect(capturedRequest!.tags, contains('ghar360'));
      expect(capturedRequest!.tags, contains('custom'));
      expect(capturedRequest!.tags, contains('tag'));
    });

    testWidgets('parses tags with newlines and commas, deduplicates', (tester) async {
      final supportRepo = MockSupportRepository();

      final controller = FeedbackController(supportRepository: supportRepo);
      controller.titleController.text = 'Title';
      controller.descriptionController.text = 'Desc';
      // Include duplicates and mixed separators
      controller.tagsController.text = 'tag1\ntag2,tag1, ,tag3';

      BugReportRequest? capturedRequest;
      when(() => supportRepo.submitBugReport(any())).thenAnswer((invocation) async {
        capturedRequest = invocation.positionalArguments[0] as BugReportRequest;
        return bugResponse();
      });

      await withFormState(tester, controller, () async {
        await controller.submitFeedback();
      });

      // Deduplicated: ghar360, tag1, tag2, tag3 (empty entries filtered)
      final tags = capturedRequest!.tags!;
      expect(tags, containsAll(['ghar360', 'tag1', 'tag2', 'tag3']));
      // No duplicates
      expect(tags.toSet().length, tags.length);
    });

    testWidgets('includes optional fields when provided', (tester) async {
      final supportRepo = MockSupportRepository();

      final controller = FeedbackController(supportRepository: supportRepo);
      controller.titleController.text = 'Title';
      controller.descriptionController.text = 'Desc';
      controller.stepsController.text = 'Step 1';
      controller.expectedController.text = 'Expected';
      controller.actualController.text = 'Actual';

      BugReportRequest? capturedRequest;
      when(() => supportRepo.submitBugReport(any())).thenAnswer((invocation) async {
        capturedRequest = invocation.positionalArguments[0] as BugReportRequest;
        return bugResponse();
      });

      await withFormState(tester, controller, () async {
        await controller.submitFeedback();
      });

      expect(capturedRequest!.stepsToReproduce, 'Step 1');
      expect(capturedRequest!.expectedBehavior, 'Expected');
      expect(capturedRequest!.actualBehavior, 'Actual');
    });

    testWidgets('excludes optional fields when controllers are empty', (tester) async {
      final supportRepo = MockSupportRepository();

      final controller = FeedbackController(supportRepository: supportRepo);
      controller.titleController.text = 'Title';
      controller.descriptionController.text = 'Desc';
      // Leave optional controllers empty

      BugReportRequest? capturedRequest;
      when(() => supportRepo.submitBugReport(any())).thenAnswer((invocation) async {
        capturedRequest = invocation.positionalArguments[0] as BugReportRequest;
        return bugResponse();
      });

      await withFormState(tester, controller, () async {
        await controller.submitFeedback();
      });

      expect(capturedRequest!.stepsToReproduce, isNull);
      expect(capturedRequest!.expectedBehavior, isNull);
      expect(capturedRequest!.actualBehavior, isNull);
    });
  });

  group('submitFeedback — error paths', () {
    testWidgets('shows field-error message on ValidationException', (tester) async {
      final supportRepo = MockSupportRepository();

      final controller = FeedbackController(supportRepository: supportRepo);
      controller.titleController.text = 'Title';
      controller.descriptionController.text = 'Desc';

      when(() => supportRepo.submitBugReport(any())).thenThrow(
        ValidationException(
          'Invalid',
          fieldErrors: {
            'title': ['too short'],
          },
        ),
      );

      await withFormState(tester, controller, () async {
        await controller.submitFeedback();
      });

      // Should not be submitting anymore
      expect(controller.isSubmitting.value, isFalse);
      // The repository was called
      verify(() => supportRepo.submitBugReport(any())).called(1);
    });

    testWidgets('shows message on ValidationException without field errors', (tester) async {
      final supportRepo = MockSupportRepository();

      final controller = FeedbackController(supportRepository: supportRepo);
      controller.titleController.text = 'Title';
      controller.descriptionController.text = 'Desc';

      when(
        () => supportRepo.submitBugReport(any()),
      ).thenThrow(ValidationException('Something went wrong'));

      await withFormState(tester, controller, () async {
        await controller.submitFeedback();
      });

      expect(controller.isSubmitting.value, isFalse);
      verify(() => supportRepo.submitBugReport(any())).called(1);
    });

    testWidgets('shows message on generic AppException', (tester) async {
      final supportRepo = MockSupportRepository();

      final controller = FeedbackController(supportRepository: supportRepo);
      controller.titleController.text = 'Title';
      controller.descriptionController.text = 'Desc';

      when(
        () => supportRepo.submitBugReport(any()),
      ).thenThrow(ServerException('Server error', statusCode: 500));

      await withFormState(tester, controller, () async {
        await controller.submitFeedback();
      });

      expect(controller.isSubmitting.value, isFalse);
      verify(() => supportRepo.submitBugReport(any())).called(1);
    });

    testWidgets('shows generic error on unexpected exception', (tester) async {
      final supportRepo = MockSupportRepository();

      final controller = FeedbackController(supportRepository: supportRepo);
      controller.titleController.text = 'Title';
      controller.descriptionController.text = 'Desc';

      when(() => supportRepo.submitBugReport(any())).thenThrow(Exception('Unexpected'));

      await withFormState(tester, controller, () async {
        await controller.submitFeedback();
      });

      expect(controller.isSubmitting.value, isFalse);
      verify(() => supportRepo.submitBugReport(any())).called(1);
    });
  });

  group('submitFeedback — device info and app version', () {
    testWidgets('includes device info in request', (tester) async {
      final supportRepo = MockSupportRepository();

      final controller = FeedbackController(supportRepository: supportRepo);
      controller.titleController.text = 'Title';
      controller.descriptionController.text = 'Desc';

      BugReportRequest? capturedRequest;
      when(() => supportRepo.submitBugReport(any())).thenAnswer((invocation) async {
        capturedRequest = invocation.positionalArguments[0] as BugReportRequest;
        return bugResponse();
      });

      await withFormState(tester, controller, () async {
        await controller.submitFeedback();
      });

      // deviceInfo should be non-null (platform label is set in test env)
      expect(capturedRequest!.deviceInfo, isNotNull);
      // The 'os' key should be present
      expect(capturedRequest!.deviceInfo!.containsKey('os'), isTrue);
    });

    testWidgets('sets source to mobile in request', (tester) async {
      final supportRepo = MockSupportRepository();

      final controller = FeedbackController(supportRepository: supportRepo);
      controller.titleController.text = 'Title';
      controller.descriptionController.text = 'Desc';

      BugReportRequest? capturedRequest;
      when(() => supportRepo.submitBugReport(any())).thenAnswer((invocation) async {
        capturedRequest = invocation.positionalArguments[0] as BugReportRequest;
        return bugResponse();
      });

      await withFormState(tester, controller, () async {
        await controller.submitFeedback();
      });

      expect(capturedRequest!.source, 'mobile');
    });

    testWidgets('uses selected bug type and severity in request', (tester) async {
      final supportRepo = MockSupportRepository();

      final controller = FeedbackController(supportRepository: supportRepo);
      controller.titleController.text = 'Title';
      controller.descriptionController.text = 'Desc';
      controller.setBugType(BugType.crash);
      controller.setSeverity(BugSeverity.critical);

      BugReportRequest? capturedRequest;
      when(() => supportRepo.submitBugReport(any())).thenAnswer((invocation) async {
        capturedRequest = invocation.positionalArguments[0] as BugReportRequest;
        return bugResponse();
      });

      await withFormState(tester, controller, () async {
        await controller.submitFeedback();
      });

      expect(capturedRequest!.bugType, BugType.crash);
      expect(capturedRequest!.severity, BugSeverity.critical);
    });
  });
}
