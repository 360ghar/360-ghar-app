// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bug_report_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BugReportResponse _$BugReportResponseFromJson(Map<String, dynamic> json) {
  $checkKeys(
    json,
    requiredKeys: const [
      'id',
      'user_id',
      'source',
      'bug_type',
      'severity',
      'status',
      'title',
      'description',
      'steps_to_reproduce',
      'expected_behavior',
      'actual_behavior',
      'device_info',
      'app_version',
      'media_urls',
      'tags',
      'assigned_to',
      'resolution',
      'resolved_at',
      'created_at',
      'updated_at',
    ],
  );
  return BugReportResponse(
    id: (json['id'] as num).toInt(),
    source: json['source'] as String,
    bugType: const BugTypeConverter().fromJson(json['bug_type']),
    severity: const BugSeverityConverter().fromJson(json['severity']),
    status: const BugStatusConverter().fromJson(json['status']),
    title: json['title'] as String,
    description: json['description'] as String,
    userId: (json['user_id'] as num?)?.toInt(),
    stepsToReproduce: json['steps_to_reproduce'] as String?,
    expectedBehavior: json['expected_behavior'] as String?,
    actualBehavior: json['actual_behavior'] as String?,
    deviceInfo: json['device_info'] as Map<String, dynamic>?,
    appVersion: json['app_version'] as String?,
    mediaUrls: (json['media_urls'] as List<dynamic>?)?.map((e) => e as String).toList(),
    tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList(),
    assignedTo: (json['assigned_to'] as num?)?.toInt(),
    resolution: json['resolution'] as String?,
    resolvedAt: json['resolved_at'] == null ? null : DateTime.parse(json['resolved_at'] as String),
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: json['updated_at'] == null ? null : DateTime.parse(json['updated_at'] as String),
  );
}

Map<String, dynamic> _$BugReportResponseToJson(BugReportResponse instance) => <String, dynamic>{
  'id': instance.id,
  'user_id': instance.userId,
  'source': instance.source,
  'bug_type': const BugTypeConverter().toJson(instance.bugType),
  'severity': const BugSeverityConverter().toJson(instance.severity),
  'status': const BugStatusConverter().toJson(instance.status),
  'title': instance.title,
  'description': instance.description,
  'steps_to_reproduce': instance.stepsToReproduce,
  'expected_behavior': instance.expectedBehavior,
  'actual_behavior': instance.actualBehavior,
  'device_info': instance.deviceInfo,
  'app_version': instance.appVersion,
  'media_urls': instance.mediaUrls,
  'tags': instance.tags,
  'assigned_to': instance.assignedTo,
  'resolution': instance.resolution,
  'resolved_at': instance.resolvedAt?.toIso8601String(),
  'created_at': instance.createdAt.toIso8601String(),
  'updated_at': instance.updatedAt?.toIso8601String(),
};
