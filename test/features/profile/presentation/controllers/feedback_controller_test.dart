import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/data/models/bug_report_model.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/profile/presentation/controllers/feedback_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../helpers/profile_test_harness.dart';

void main() {
  late ProfileHarness h;
  late FeedbackController controller;
  setUp(() {
    h = ProfileHarness();
    h.listen(feedbackProvider);
    controller = h.container.read(feedbackProvider.notifier);
  });
  tearDown(() => h.close());
  Future<BugReportResponse?> submit({
    String tags = '',
    String steps = '',
    String expected = '',
    String actual = '',
    BugType type = BugType.uiBug,
    BugSeverity severity = BugSeverity.medium,
  }) => controller.submitFeedback(
    type: type,
    severity: severity,
    title: ' Title ',
    description: ' Description ',
    tags: tags,
    steps: steps,
    expected: expected,
    actual: actual,
  );
  BugReportRequest sent() =>
      verify(() => h.support.submitBugReport(captureAny())).captured.last as BugReportRequest;
  test('defaults idle and returns successful response', () async {
    expect(h.container.read(feedbackProvider).isLoading, isFalse);
    expect((await submit())?.id, 42);
    expect(h.container.read(feedbackProvider).hasError, isFalse);
  });
  test('request trims title and description, uses mobile source and version metadata', () async {
    await submit();
    final request = sent();
    expect(request.title, 'Title');
    expect(request.description, 'Description');
    expect(request.source, 'mobile');
    expect(request.appVersion, '1.2.3+42');
    expect(request.deviceInfo!['app_version'], '1.2.3+42');
    expect(request.deviceInfo!['os'], isNotEmpty);
    expect(request.deviceInfo!['model'], isNotEmpty);
  });
  test('app_version never passes the 50 characters the backend takes', () async {
    h.info = PackageInfo(
      appName: 'Ghar',
      packageName: 'com.ghar360',
      version:
          '1.2.3-'
              'x' *
          60,
      buildNumber: '42',
      buildSignature: '',
    );
    await submit();
    expect(sent().appVersion, hasLength(BugReportLimits.appVersion));
  });
  test('parses tags by comma and newline, includes ghar360 once', () async {
    await submit(tags: ' search, login\nsearch,ghar360, ');
    expect(sent().tags, ['ghar360', 'search', 'login']);
  });
  test('retains optional fields after trimming', () async {
    await submit(steps: ' Open app ', expected: ' Works ', actual: ' Fails ');
    final request = sent();
    expect(request.stepsToReproduce, 'Open app');
    expect(request.expectedBehavior, 'Works');
    expect(request.actualBehavior, 'Fails');
  });
  test('omits empty optional fields', () async {
    await submit(steps: ' ', expected: '\n');
    final request = sent();
    expect(request.stepsToReproduce, isNull);
    expect(request.expectedBehavior, isNull);
    expect(request.actualBehavior, isNull);
    expect(request.tags, ['ghar360']);
  });
  test('respects each selected issue type and severity', () async {
    for (final type in BugType.values) {
      for (final severity in BugSeverity.values) {
        await submit(type: type, severity: severity);
        final request = sent();
        expect(request.bugType, type);
        expect(request.severity, severity);
      }
    }
  });
  test('package metadata failure does not block feedback', () async {
    h.info = null;
    expect(await submit(), isNotNull);
    expect(sent().appVersion, isNull);
  });
  for (final error in <Object>[
    ValidationException(
      'invalid',
      fieldErrors: {
        'title': ['too short'],
      },
    ),
    ValidationException('invalid'),
    NetworkException('offline'),
    Exception('sensitive payload'),
  ]) {
    test('exposes typed failure and permits retry for ${error.runtimeType}', () async {
      when(() => h.support.submitBugReport(any())).thenThrow(error);
      expect(await submit(), isNull);
      expect(h.container.read(feedbackProvider).error, isA<AppException>());
      expect(h.container.read(feedbackProvider).isLoading, isFalse);
      when(() => h.support.submitBugReport(any())).thenAnswer((_) async => bugResponse());
      expect(await submit(), isNotNull);
    });
  }
  test('duplicate submission cannot send a second request', () async {
    final pending = Completer<BugReportResponse>();
    when(() => h.support.submitBugReport(any())).thenAnswer((_) => pending.future);
    final first = submit();
    await Future<void>.delayed(Duration.zero);
    expect(await submit(), isNull);
    verify(() => h.support.submitBugReport(any())).called(1);
    pending.complete(bugResponse());
    await first;
  });
  test('account switch rejects a late response', () async {
    final pending = Completer<BugReportResponse>();
    when(() => h.support.submitBugReport(any())).thenAnswer((_) => pending.future);
    final first = submit();
    await Future<void>.delayed(Duration.zero);
    h.session.set(h.container.read(authProvider).copyWith(user: profile('account-b')));
    await h.container.pump();
    pending.complete(bugResponse());
    expect(await first, isNull);
    expect(h.container.read(feedbackProvider).isLoading, isFalse);
  });
  test('disposal rejects a late response', () async {
    final pending = Completer<BugReportResponse>();
    when(() => h.support.submitBugReport(any())).thenAnswer((_) => pending.future);
    final first = submit();
    await Future<void>.delayed(Duration.zero);
    h.container.invalidate(feedbackProvider);
    await h.container.pump();
    pending.complete(bugResponse());
    expect(await first, isNull);
  });
}
