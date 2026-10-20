import 'package:json_annotation/json_annotation.dart';

import 'package:ghar360/core/data/models/wire_enums.dart';

export 'package:ghar360/core/data/models/wire_enums.dart' show AgentType, ExperienceLevel;

part 'agent_model.g.dart';

/// `Agent`: the relationship manager assigned to the user.
@JsonSerializable()
class AgentModel {
  @JsonKey(required: true)
  final int id;
  @JsonKey(required: true)
  final String name;
  final String? description;
  @JsonKey(name: 'avatar_url')
  final String? avatarUrl;
  @JsonKey(name: 'contact_number')
  final String? contactNumber;
  final List<String>? languages;

  /// Null for a value this app does not know.
  @JsonKey(name: 'agent_type', required: true)
  @AgentTypeConverter()
  final AgentType? agentType;
  @JsonKey(name: 'experience_level', required: true)
  @ExperienceLevelConverter()
  final ExperienceLevel? experienceLevel;
  @JsonKey(name: 'is_active', required: true, disallowNullValue: true)
  final bool isActive;
  @JsonKey(name: 'is_available', required: true, disallowNullValue: true)
  final bool isAvailable;
  @JsonKey(name: 'working_hours')
  final Map<String, dynamic>? workingHours;
  @JsonKey(name: 'total_users_assigned', required: true, disallowNullValue: true)
  final int totalUsersAssigned;
  @JsonKey(name: 'user_satisfaction_rating', required: true, disallowNullValue: true)
  final double userSatisfactionRating;
  @JsonKey(name: 'created_at', required: true, disallowNullValue: true)
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  const AgentModel({
    required this.id,
    required this.name,
    this.description,
    this.avatarUrl,
    this.contactNumber,
    this.languages,
    required this.agentType,
    required this.experienceLevel,
    this.isActive = true,
    this.isAvailable = true,
    this.workingHours,
    this.totalUsersAssigned = 0,
    this.userSatisfactionRating = 0.0,
    required this.createdAt,
    this.updatedAt,
  });

  factory AgentModel.fromJson(Map<String, dynamic> json) => _$AgentModelFromJson(json);

  Map<String, dynamic> toJson() => _$AgentModelToJson(this);

  AgentModel copyWith({
    int? id,
    String? name,
    String? description,
    String? avatarUrl,
    String? contactNumber,
    List<String>? languages,
    AgentType? agentType,
    ExperienceLevel? experienceLevel,
    bool? isActive,
    bool? isAvailable,
    Map<String, dynamic>? workingHours,
    int? totalUsersAssigned,
    double? userSatisfactionRating,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AgentModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      contactNumber: contactNumber ?? this.contactNumber,
      languages: languages ?? this.languages,
      agentType: agentType ?? this.agentType,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      isActive: isActive ?? this.isActive,
      isAvailable: isAvailable ?? this.isAvailable,
      workingHours: workingHours ?? this.workingHours,
      totalUsersAssigned: totalUsersAssigned ?? this.totalUsersAssigned,
      userSatisfactionRating: userSatisfactionRating ?? this.userSatisfactionRating,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Convenience getters
  String? get agentTypeString => switch (agentType) {
    AgentType.general => 'General',
    AgentType.specialist => 'Specialist',
    AgentType.senior => 'Senior',
    null => null,
  };

  /// The l10n key of the experience level. Null for a level this app does not know.
  String? get experienceLevelString => switch (experienceLevel) {
    ExperienceLevel.beginner => 'Beginner',
    ExperienceLevel.intermediate => 'Intermediate',
    ExperienceLevel.expert => 'Expert',
    null => null,
  };

  String get languagesDisplay => languages?.join(', ') ?? 'Not specified';

  bool get hasWorkingHours => workingHours?.isNotEmpty == true;
}
