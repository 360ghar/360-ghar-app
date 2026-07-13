import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/data/models/bug_report_model.dart';

void main() {
  group('BugType.fromValue', () {
    test('maps all known values correctly', () {
      expect(BugType.fromValue('ui_bug'), BugType.uiBug);
      expect(BugType.fromValue('functionality_bug'), BugType.functionalityBug);
      expect(BugType.fromValue('performance_issue'), BugType.performanceIssue);
      expect(BugType.fromValue('crash'), BugType.crash);
      expect(BugType.fromValue('feature_request'), BugType.featureRequest);
      expect(BugType.fromValue('other'), BugType.other);
    });

    test('returns other for null', () {
      expect(BugType.fromValue(null), BugType.other);
    });

    test('returns other for unknown values', () {
      expect(BugType.fromValue('unknown_type'), BugType.other);
      expect(BugType.fromValue(''), BugType.other);
    });

    test('is case insensitive', () {
      expect(BugType.fromValue('UI_BUG'), BugType.uiBug);
      expect(BugType.fromValue('Crash'), BugType.crash);
      expect(BugType.fromValue('FEATURE_REQUEST'), BugType.featureRequest);
    });

    test('value getter returns the wire value', () {
      expect(BugType.uiBug.value, 'ui_bug');
      expect(BugType.crash.value, 'crash');
      expect(BugType.other.value, 'other');
    });
  });

  group('BugSeverity.fromValue', () {
    test('maps all known values correctly', () {
      expect(BugSeverity.fromValue('low'), BugSeverity.low);
      expect(BugSeverity.fromValue('medium'), BugSeverity.medium);
      expect(BugSeverity.fromValue('high'), BugSeverity.high);
      expect(BugSeverity.fromValue('critical'), BugSeverity.critical);
    });

    test('returns medium for null', () {
      expect(BugSeverity.fromValue(null), BugSeverity.medium);
    });

    test('returns medium for unknown values', () {
      expect(BugSeverity.fromValue('unknown'), BugSeverity.medium);
      expect(BugSeverity.fromValue(''), BugSeverity.medium);
    });

    test('is case insensitive', () {
      expect(BugSeverity.fromValue('LOW'), BugSeverity.low);
      expect(BugSeverity.fromValue('Critical'), BugSeverity.critical);
    });

    test('value getter returns the wire value', () {
      expect(BugSeverity.low.value, 'low');
      expect(BugSeverity.critical.value, 'critical');
    });
  });

  group('BugTypeConverter', () {
    const converter = BugTypeConverter();

    test('fromJson delegates to BugType.fromValue', () {
      expect(converter.fromJson('crash'), BugType.crash);
      expect(converter.fromJson('unknown'), BugType.other);
    });

    test('toJson returns the enum value', () {
      expect(converter.toJson(BugType.crash), 'crash');
      expect(converter.toJson(BugType.uiBug), 'ui_bug');
    });
  });

  group('BugSeverityConverter', () {
    const converter = BugSeverityConverter();

    test('fromJson delegates to BugSeverity.fromValue', () {
      expect(converter.fromJson('high'), BugSeverity.high);
      expect(converter.fromJson('unknown'), BugSeverity.medium);
    });

    test('toJson returns the enum value', () {
      expect(converter.toJson(BugSeverity.high), 'high');
      expect(converter.toJson(BugSeverity.critical), 'critical');
    });
  });

  group('BugReportRequest', () {
    test('fromJson parses snake_case fields with enum converters', () {
      final json = <String, dynamic>{
        'source': 'mobile',
        'bug_type': 'crash',
        'severity': 'high',
        'title': 'App crashes on startup',
        'description': 'The app crashes immediately after launch',
        'steps_to_reproduce': 'Open the app',
        'expected_behavior': 'App should open',
        'actual_behavior': 'App crashes',
        'device_info': {'os': 'iOS 17', 'model': 'iPhone 14'},
        'app_version': '1.2.3',
        'tags': ['crash', 'startup'],
      };

      final request = BugReportRequest.fromJson(json);

      expect(request.source, 'mobile');
      expect(request.bugType, BugType.crash);
      expect(request.severity, BugSeverity.high);
      expect(request.title, 'App crashes on startup');
      expect(request.description, 'The app crashes immediately after launch');
      expect(request.stepsToReproduce, 'Open the app');
      expect(request.expectedBehavior, 'App should open');
      expect(request.actualBehavior, 'App crashes');
      expect(request.deviceInfo, {'os': 'iOS 17', 'model': 'iPhone 14'});
      expect(request.appVersion, '1.2.3');
      expect(request.tags, ['crash', 'startup']);
    });

    test('fromJson handles null optional fields', () {
      final json = <String, dynamic>{
        'source': 'web',
        'bug_type': 'ui_bug',
        'severity': 'low',
        'title': 'Button misaligned',
        'description': 'The submit button is off-center',
      };

      final request = BugReportRequest.fromJson(json);

      expect(request.stepsToReproduce, isNull);
      expect(request.expectedBehavior, isNull);
      expect(request.actualBehavior, isNull);
      expect(request.deviceInfo, isNull);
      expect(request.appVersion, isNull);
      expect(request.tags, isNull);
    });

    test('toJson renames fields to snake_case', () {
      const request = BugReportRequest(
        source: 'mobile',
        bugType: BugType.crash,
        severity: BugSeverity.critical,
        title: 'Crash',
        description: 'Crashes',
      );

      final json = request.toJson();

      expect(json['source'], 'mobile');
      expect(json['bug_type'], 'crash');
      expect(json['severity'], 'critical');
      expect(json['title'], 'Crash');
      expect(json['description'], 'Crashes');
    });

    test('toJson excludes null optional fields due to includeIfNull false', () {
      const request = BugReportRequest(
        source: 'mobile',
        bugType: BugType.crash,
        severity: BugSeverity.high,
        title: 'Crash',
        description: 'Crashes',
      );

      final json = request.toJson();

      expect(json.containsKey('steps_to_reproduce'), false);
      expect(json.containsKey('expected_behavior'), false);
      expect(json.containsKey('actual_behavior'), false);
      expect(json.containsKey('device_info'), false);
      expect(json.containsKey('app_version'), false);
      expect(json.containsKey('tags'), false);
    });

    test('toJson includes non-null optional fields', () {
      const request = BugReportRequest(
        source: 'mobile',
        bugType: BugType.crash,
        severity: BugSeverity.high,
        title: 'Crash',
        description: 'Crashes',
        stepsToReproduce: 'Open app',
        appVersion: '1.0.0',
        tags: ['crash'],
      );

      final json = request.toJson();

      expect(json['steps_to_reproduce'], 'Open app');
      expect(json['app_version'], '1.0.0');
      expect(json['tags'], ['crash']);
    });

    test('toJson roundtrip preserves all fields', () {
      final original = const BugReportRequest(
        source: 'mobile',
        bugType: BugType.functionalityBug,
        severity: BugSeverity.medium,
        title: 'Login fails',
        description: 'Cannot login with valid credentials',
        stepsToReproduce: 'Enter credentials and tap login',
        expectedBehavior: 'Should log in',
        actualBehavior: 'Shows error',
        deviceInfo: {'platform': 'android'},
        appVersion: '2.1.0',
        tags: ['login', 'auth'],
      );

      final json = original.toJson();
      final restored = BugReportRequest.fromJson(json);

      expect(restored.source, original.source);
      expect(restored.bugType, original.bugType);
      expect(restored.severity, original.severity);
      expect(restored.title, original.title);
      expect(restored.description, original.description);
      expect(restored.stepsToReproduce, original.stepsToReproduce);
      expect(restored.expectedBehavior, original.expectedBehavior);
      expect(restored.actualBehavior, original.actualBehavior);
      expect(restored.deviceInfo, original.deviceInfo);
      expect(restored.appVersion, original.appVersion);
      expect(restored.tags, original.tags);
    });
  });

  group('BugReportResponse', () {
    test('fromJson parses full JSON correctly', () {
      final json = <String, dynamic>{
        'id': 101,
        'user_id': 5,
        'source': 'mobile',
        'bug_type': 'performance_issue',
        'severity': 'high',
        'status': 'open',
        'title': 'Slow loading',
        'description': 'List takes too long to load',
        'steps_to_reproduce': 'Open discover page',
        'expected_behavior': 'Loads in under 1s',
        'actual_behavior': 'Takes 5s',
        'device_info': {'os': 'Android 13'},
        'app_version': '1.5.0',
        'media_urls': ['https://example.com/screenshot.png'],
        'tags': ['performance'],
        'assigned_to': 7,
        'resolution': null,
        'resolved_at': null,
        'created_at': '2024-06-01T10:00:00.000Z',
        'updated_at': '2024-06-02T12:00:00.000Z',
      };

      final response = BugReportResponse.fromJson(json);

      expect(response.id, 101);
      expect(response.userId, 5);
      expect(response.source, 'mobile');
      expect(response.bugType, BugType.performanceIssue);
      expect(response.severity, BugSeverity.high);
      expect(response.status, 'open');
      expect(response.title, 'Slow loading');
      expect(response.description, 'List takes too long to load');
      expect(response.stepsToReproduce, 'Open discover page');
      expect(response.expectedBehavior, 'Loads in under 1s');
      expect(response.actualBehavior, 'Takes 5s');
      expect(response.deviceInfo, {'os': 'Android 13'});
      expect(response.appVersion, '1.5.0');
      expect(response.mediaUrls, ['https://example.com/screenshot.png']);
      expect(response.tags, ['performance']);
      expect(response.assignedTo, 7);
      expect(response.resolution, isNull);
      expect(response.resolvedAt, isNull);
      expect(response.createdAt, DateTime.parse('2024-06-01T10:00:00.000Z'));
      expect(response.updatedAt, DateTime.parse('2024-06-02T12:00:00.000Z'));
    });

    test('fromJson applies defaults for missing list fields', () {
      final json = <String, dynamic>{
        'id': 200,
        'source': 'web',
        'bug_type': 'other',
        'severity': 'low',
        'status': 'new',
        'title': 'Minor issue',
        'description': 'Small typo',
      };

      final response = BugReportResponse.fromJson(json);

      expect(response.mediaUrls, [], reason: 'media_urls defaults to empty list');
      expect(response.tags, [], reason: 'tags defaults to empty list');
      expect(response.userId, isNull);
      expect(response.assignedTo, isNull);
    });

    test('fromJson throws FormatException for non-numeric id', () {
      final json = <String, dynamic>{
        'id': 'not-a-number',
        'source': 'mobile',
        'bug_type': 'crash',
        'severity': 'high',
        'status': 'open',
        'title': 'Crash',
        'description': 'Crashes',
      };

      expect(() => BugReportResponse.fromJson(json), throwsA(isA<FormatException>()));
    });

    test('fromJson throws FormatException for missing id', () {
      final json = <String, dynamic>{
        'source': 'mobile',
        'bug_type': 'crash',
        'severity': 'high',
        'status': 'open',
        'title': 'Crash',
        'description': 'Crashes',
      };

      expect(() => BugReportResponse.fromJson(json), throwsA(isA<FormatException>()));
    });

    test('toJson roundtrip preserves all fields', () {
      final original = BugReportResponse(
        id: 300,
        userId: 10,
        source: 'mobile',
        bugType: BugType.uiBug,
        severity: BugSeverity.low,
        status: 'resolved',
        title: 'UI glitch',
        description: 'Button overlaps',
        stepsToReproduce: 'Open settings',
        expectedBehavior: 'No overlap',
        actualBehavior: 'Overlap visible',
        deviceInfo: {'os': 'iOS 17'},
        appVersion: '1.0.0',
        mediaUrls: ['https://example.com/1.png', 'https://example.com/2.png'],
        tags: ['ui', 'cosmetic'],
        assignedTo: 3,
        resolution: 'Fixed in v1.1.0',
        resolvedAt: DateTime.parse('2024-07-01T09:00:00.000Z'),
        createdAt: DateTime.parse('2024-06-15T10:00:00.000Z'),
        updatedAt: DateTime.parse('2024-07-01T09:00:00.000Z'),
      );

      final json = original.toJson();
      final restored = BugReportResponse.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.userId, original.userId);
      expect(restored.source, original.source);
      expect(restored.bugType, original.bugType);
      expect(restored.severity, original.severity);
      expect(restored.status, original.status);
      expect(restored.title, original.title);
      expect(restored.description, original.description);
      expect(restored.stepsToReproduce, original.stepsToReproduce);
      expect(restored.expectedBehavior, original.expectedBehavior);
      expect(restored.actualBehavior, original.actualBehavior);
      expect(restored.deviceInfo, original.deviceInfo);
      expect(restored.appVersion, original.appVersion);
      expect(restored.mediaUrls, original.mediaUrls);
      expect(restored.tags, original.tags);
      expect(restored.assignedTo, original.assignedTo);
      expect(restored.resolution, original.resolution);
      expect(restored.resolvedAt, original.resolvedAt);
      expect(restored.createdAt, original.createdAt);
      expect(restored.updatedAt, original.updatedAt);
    });
  });
}
