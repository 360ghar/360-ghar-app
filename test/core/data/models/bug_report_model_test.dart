import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/data/models/bug_report_model.dart';
import 'package:ghar360/core/data/models/wire_enums.dart';

/// A `BugReportResponse` body: every key is present, a key that can be empty is null.
Map<String, dynamic> _body({Map<String, dynamic> overrides = const {}}) => {
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
  'created_at': '2024-06-01T10:00:00Z',
  'updated_at': '2024-06-02T12:00:00Z',
  ...overrides,
};

void main() {
  group('BugType', () {
    test('maps every wire value', () {
      expect(BugType.fromJson('ui_bug'), BugType.uiBug);
      expect(BugType.fromJson('functionality_bug'), BugType.functionalityBug);
      expect(BugType.fromJson('performance_issue'), BugType.performanceIssue);
      expect(BugType.fromJson('crash'), BugType.crash);
      expect(BugType.fromJson('feature_request'), BugType.featureRequest);
      expect(BugType.fromJson('other'), BugType.other);
    });

    test('an unknown or missing value is null, not a real value', () {
      expect(BugType.fromJson(null), isNull);
      expect(BugType.fromJson('unknown_type'), isNull);
      expect(BugType.fromJson(''), isNull);
    });

    test('the wire match is exact', () {
      expect(BugType.fromJson('UI_BUG'), isNull);
      expect(BugType.fromJson('Crash'), isNull);
    });

    test('wire is the value on the wire', () {
      expect(BugType.uiBug.wire, 'ui_bug');
      expect(BugType.crash.wire, 'crash');
      expect(BugType.other.wire, 'other');
    });
  });

  group('BugSeverity', () {
    test('maps every wire value', () {
      expect(BugSeverity.fromJson('low'), BugSeverity.low);
      expect(BugSeverity.fromJson('medium'), BugSeverity.medium);
      expect(BugSeverity.fromJson('high'), BugSeverity.high);
      expect(BugSeverity.fromJson('critical'), BugSeverity.critical);
    });

    test('an unknown or missing value is null', () {
      expect(BugSeverity.fromJson(null), isNull);
      expect(BugSeverity.fromJson('unknown'), isNull);
      expect(BugSeverity.fromJson('LOW'), isNull);
    });
  });

  group('converters', () {
    test('BugTypeConverter reads and writes the wire value', () {
      const converter = BugTypeConverter();
      expect(converter.fromJson('crash'), BugType.crash);
      expect(converter.fromJson('unknown'), isNull);
      expect(converter.toJson(BugType.uiBug), 'ui_bug');
      expect(converter.toJson(null), isNull);
    });

    test('BugSeverityConverter reads and writes the wire value', () {
      const converter = BugSeverityConverter();
      expect(converter.fromJson('high'), BugSeverity.high);
      expect(converter.fromJson('unknown'), isNull);
      expect(converter.toJson(BugSeverity.critical), 'critical');
    });

    test('BugStatusConverter reads the wire value', () {
      const converter = BugStatusConverter();
      expect(converter.fromJson('open'), BugStatus.open);
      expect(converter.fromJson('new'), isNull);
    });
  });

  group('BugReportRequest', () {
    test('toJson writes snake_case keys and wire enum values', () {
      const request = BugReportRequest(
        source: 'mobile',
        bugType: BugType.crash,
        severity: BugSeverity.critical,
        title: 'Crash',
        description: 'Crashes',
      );

      expect(request.toJson(), {
        'source': 'mobile',
        'bug_type': 'crash',
        'severity': 'critical',
        'title': 'Crash',
        'description': 'Crashes',
      });
    });

    test('toJson leaves out optional fields that are null', () {
      const request = BugReportRequest(
        source: 'mobile',
        bugType: BugType.crash,
        severity: BugSeverity.high,
        title: 'Crash',
        description: 'Crashes',
      );

      final keys = request.toJson().keys;
      for (final optional in [
        'steps_to_reproduce',
        'expected_behavior',
        'actual_behavior',
        'device_info',
        'app_version',
        'tags',
      ]) {
        expect(keys, isNot(contains(optional)));
      }
    });

    test('toJson includes optional fields that are set', () {
      const request = BugReportRequest(
        source: 'mobile',
        bugType: BugType.crash,
        severity: BugSeverity.high,
        title: 'Crash',
        description: 'Crashes',
        stepsToReproduce: 'Open app',
        expectedBehavior: 'Opens',
        actualBehavior: 'Closes',
        deviceInfo: {'platform': 'android'},
        appVersion: '1.0.0',
        tags: ['crash'],
      );

      final json = request.toJson();

      expect(json['steps_to_reproduce'], 'Open app');
      expect(json['expected_behavior'], 'Opens');
      expect(json['actual_behavior'], 'Closes');
      expect(json['device_info'], {'platform': 'android'});
      expect(json['app_version'], '1.0.0');
      expect(json['tags'], ['crash']);
    });

    test('the body holds only keys of BugReportCreate', () {
      const declared = {
        'source',
        'bug_type',
        'severity',
        'title',
        'description',
        'steps_to_reproduce',
        'expected_behavior',
        'actual_behavior',
        'device_info',
        'app_version',
        'media_urls',
        'tags',
      };
      const request = BugReportRequest(
        source: 'mobile',
        bugType: BugType.other,
        severity: BugSeverity.low,
        title: 'T',
        description: 'D',
        stepsToReproduce: 's',
        expectedBehavior: 'e',
        actualBehavior: 'a',
        deviceInfo: {},
        appVersion: '1',
        tags: [],
      );

      expect(declared.containsAll(request.toJson().keys), isTrue);
    });

    test('limits match the backend column sizes', () {
      expect(BugReportLimits.source, 50);
      expect(BugReportLimits.title, 200);
      expect(BugReportLimits.appVersion, 50);
    });
  });

  group('BugReportResponse', () {
    test('fromJson reads a full body', () {
      final response = BugReportResponse.fromJson(_body());

      expect(response.id, 101);
      expect(response.userId, 5);
      expect(response.source, 'mobile');
      expect(response.bugType, BugType.performanceIssue);
      expect(response.severity, BugSeverity.high);
      expect(response.status, BugStatus.open);
      expect(response.title, 'Slow loading');
      expect(response.description, 'List takes too long to load');
      expect(response.stepsToReproduce, 'Open discover page');
      expect(response.deviceInfo, {'os': 'Android 13'});
      expect(response.appVersion, '1.5.0');
      expect(response.mediaUrls, ['https://example.com/screenshot.png']);
      expect(response.tags, ['performance']);
      expect(response.assignedTo, 7);
      expect(response.resolution, isNull);
      expect(response.resolvedAt, isNull);
      expect(response.createdAt, DateTime.utc(2024, 6, 1, 10));
      expect(response.updatedAt, DateTime.utc(2024, 6, 2, 12));
    });

    test('null list keys stay null: the app invents no default', () {
      final response = BugReportResponse.fromJson(
        _body(overrides: {'media_urls': null, 'tags': null, 'user_id': null}),
      );

      expect(response.mediaUrls, isNull);
      expect(response.tags, isNull);
      expect(response.userId, isNull);
    });

    test('an unknown enum value reads as null', () {
      final response = BugReportResponse.fromJson(
        _body(overrides: {'status': 'reopened', 'severity': 'blocker', 'bug_type': 'typo'}),
      );

      expect(response.status, isNull);
      expect(response.severity, isNull);
      expect(response.bugType, isNull);
    });

    test('a key the backend always sends is required', () {
      for (final key in _body().keys) {
        final body = _body()..remove(key);
        expect(() => BugReportResponse.fromJson(body), throwsA(anything), reason: 'missing $key');
      }
    });

    test('a non-numeric id is a contract break', () {
      expect(() => BugReportResponse.fromJson(_body(overrides: {'id': 'x'})), throwsA(anything));
    });

    test('toJson roundtrip keeps the fields', () {
      final original = BugReportResponse.fromJson(_body());
      final restored = BugReportResponse.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.bugType, original.bugType);
      expect(restored.status, original.status);
      expect(restored.mediaUrls, original.mediaUrls);
      expect(restored.createdAt, original.createdAt);
      expect(restored.updatedAt, original.updatedAt);
    });
  });
}
