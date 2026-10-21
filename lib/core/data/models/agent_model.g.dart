// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AgentModel _$AgentModelFromJson(Map<String, dynamic> json) {
  $checkKeys(
    json,
    requiredKeys: const [
      'id',
      'name',
      'agent_type',
      'experience_level',
      'is_active',
      'is_available',
      'total_users_assigned',
      'user_satisfaction_rating',
      'created_at',
    ],
    disallowNullValues: const [
      'is_active',
      'is_available',
      'total_users_assigned',
      'user_satisfaction_rating',
      'created_at',
    ],
  );
  return AgentModel(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String,
    description: json['description'] as String?,
    avatarUrl: json['avatar_url'] as String?,
    contactNumber: json['contact_number'] as String?,
    languages: (json['languages'] as List<dynamic>?)?.map((e) => e as String).toList(),
    agentType: const AgentTypeConverter().fromJson(json['agent_type']),
    experienceLevel: const ExperienceLevelConverter().fromJson(json['experience_level']),
    isActive: json['is_active'] as bool? ?? true,
    isAvailable: json['is_available'] as bool? ?? true,
    workingHours: json['working_hours'] as Map<String, dynamic>?,
    totalUsersAssigned: (json['total_users_assigned'] as num?)?.toInt() ?? 0,
    userSatisfactionRating: (json['user_satisfaction_rating'] as num?)?.toDouble() ?? 0.0,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: json['updated_at'] == null ? null : DateTime.parse(json['updated_at'] as String),
  );
}

Map<String, dynamic> _$AgentModelToJson(AgentModel instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'description': instance.description,
  'avatar_url': instance.avatarUrl,
  'contact_number': instance.contactNumber,
  'languages': instance.languages,
  'agent_type': const AgentTypeConverter().toJson(instance.agentType),
  'experience_level': const ExperienceLevelConverter().toJson(instance.experienceLevel),
  'is_active': instance.isActive,
  'is_available': instance.isAvailable,
  'working_hours': instance.workingHours,
  'total_users_assigned': instance.totalUsersAssigned,
  'user_satisfaction_rating': instance.userSatisfactionRating,
  'created_at': instance.createdAt.toIso8601String(),
  'updated_at': instance.updatedAt?.toIso8601String(),
};
