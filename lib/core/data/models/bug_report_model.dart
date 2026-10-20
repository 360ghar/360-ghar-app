import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

import 'package:ghar360/core/data/models/wire_enums.dart';

export 'package:ghar360/core/data/models/wire_enums.dart' show BugSeverity, BugStatus, BugType;

part 'bug_report_model.g.dart';

/// Length limits of `BugReportCreate`. The backend stays the authority; these keep the form from
/// sending a value it will refuse.
class BugReportLimits {
  const BugReportLimits._();
  static const source = 50;
  static const title = 200;
  static const appVersion = 50;
}

/// Request payload for creating a new bug report (`BugReportCreate`). The body is strict:
/// every key sent is a key the backend declares.
@immutable
class BugReportRequest {
  const BugReportRequest({
    required this.source,
    required this.bugType,
    required this.severity,
    required this.title,
    required this.description,
    this.stepsToReproduce,
    this.expectedBehavior,
    this.actualBehavior,
    this.deviceInfo,
    this.appVersion,
    this.tags,
  });

  final String source;
  final BugType bugType;
  final BugSeverity severity;
  final String title;
  final String description;
  final String? stepsToReproduce;
  final String? expectedBehavior;
  final String? actualBehavior;
  final Map<String, dynamic>? deviceInfo;
  final String? appVersion;
  final List<String>? tags;

  Map<String, dynamic> toJson() => {
    'source': source,
    'bug_type': bugType.wire,
    'severity': severity.wire,
    'title': title,
    'description': description,
    'steps_to_reproduce': ?stepsToReproduce,
    'expected_behavior': ?expectedBehavior,
    'actual_behavior': ?actualBehavior,
    'device_info': ?deviceInfo,
    'app_version': ?appVersion,
    'tags': ?tags,
  };
}

/// `BugReportResponse`: returned with 201 after a report is stored. The backend sends every key;
/// a key that can be empty is null, and an empty list is `[]` or null. A missing key is a
/// contract break.
@JsonSerializable(fieldRename: FieldRename.snake)
class BugReportResponse {
  const BugReportResponse({
    required this.id,
    required this.source,
    required this.bugType,
    required this.severity,
    required this.status,
    required this.title,
    required this.description,
    this.userId,
    this.stepsToReproduce,
    this.expectedBehavior,
    this.actualBehavior,
    this.deviceInfo,
    this.appVersion,
    this.mediaUrls,
    this.tags,
    this.assignedTo,
    this.resolution,
    this.resolvedAt,
    required this.createdAt,
    this.updatedAt,
  });

  factory BugReportResponse.fromJson(Map<String, dynamic> json) =>
      _$BugReportResponseFromJson(json);

  @JsonKey(required: true)
  final int id;
  @JsonKey(required: true)
  final int? userId;
  @JsonKey(required: true)
  final String source;

  /// Null for a value this app does not know.
  @JsonKey(required: true)
  @BugTypeConverter()
  final BugType? bugType;
  @JsonKey(required: true)
  @BugSeverityConverter()
  final BugSeverity? severity;
  @JsonKey(required: true)
  @BugStatusConverter()
  final BugStatus? status;
  @JsonKey(required: true)
  final String title;
  @JsonKey(required: true)
  final String description;
  @JsonKey(required: true)
  final String? stepsToReproduce;
  @JsonKey(required: true)
  final String? expectedBehavior;
  @JsonKey(required: true)
  final String? actualBehavior;
  @JsonKey(required: true)
  final Map<String, dynamic>? deviceInfo;
  @JsonKey(required: true)
  final String? appVersion;
  @JsonKey(required: true)
  final List<String>? mediaUrls;
  @JsonKey(required: true)
  final List<String>? tags;
  @JsonKey(required: true)
  final int? assignedTo;
  @JsonKey(required: true)
  final String? resolution;
  @JsonKey(required: true)
  final DateTime? resolvedAt;
  @JsonKey(required: true)
  final DateTime createdAt;
  @JsonKey(required: true)
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => _$BugReportResponseToJson(this);
}
