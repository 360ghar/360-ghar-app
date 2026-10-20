import 'package:json_annotation/json_annotation.dart';

import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/data/models/wire_enums.dart';

export 'package:ghar360/core/data/models/wire_enums.dart' show VisitContext, VisitStatus;

part 'visit_model.g.dart';

/// `VisitAgentInfo`: the agent who looks after the visit. The wire key for the number is `phone`.
@JsonSerializable()
class VisitAgentInfo {
  final int id;
  final String name;
  final String? phone;
  @JsonKey(name: 'avatar_url')
  final String? avatarUrl;

  const VisitAgentInfo({required this.id, required this.name, this.phone, this.avatarUrl});

  factory VisitAgentInfo.fromJson(Map<String, dynamic> json) => _$VisitAgentInfoFromJson(json);

  Map<String, dynamic> toJson() => _$VisitAgentInfoToJson(this);
}

/// `PublicUserRef`: another person on a visit. Name and avatar only; there is no phone, email or
/// location to read.
@JsonSerializable()
class PublicUserRef {
  final int id;
  @JsonKey(name: 'display_name')
  final String? displayName;
  @JsonKey(name: 'avatar_url')
  final String? avatarUrl;

  const PublicUserRef({required this.id, this.displayName, this.avatarUrl});

  factory PublicUserRef.fromJson(Map<String, dynamic> json) => _$PublicUserRefFromJson(json);

  Map<String, dynamic> toJson() => _$PublicUserRefToJson(this);
}

/// `Visit`. Timestamps are UTC with a `Z`.
@JsonSerializable(explicitToJson: true, checked: true)
class VisitModel {
  @JsonKey(required: true)
  final int id;
  @JsonKey(name: 'property_id', required: true)
  final int propertyId;
  @JsonKey(name: 'user_id', required: true)
  final int userId;
  @JsonKey(name: 'agent_id')
  final int? agentId;
  @JsonKey(name: 'scheduled_date', required: true)
  final DateTime scheduledDate;

  /// The slot the visitor picked (for example `morning`), if any.
  @JsonKey(name: 'time_slot_label')
  final String? timeSlotLabel;
  @JsonKey(name: 'actual_date')
  final DateTime? actualDate;

  /// Null for a status this app does not know.
  @JsonKey(required: true)
  @VisitStatusConverter()
  final VisitStatus? status;
  @JsonKey(name: 'visit_context', required: true)
  @VisitContextConverter()
  final VisitContext? visitContext;
  @JsonKey(name: 'conversation_id')
  final int? conversationId;
  @JsonKey(name: 'match_id')
  final int? matchId;
  @JsonKey(name: 'special_requirements')
  final String? specialRequirements;
  @JsonKey(name: 'visit_notes')
  final String? visitNotes;
  @JsonKey(name: 'visitor_feedback')
  final String? visitorFeedback;
  @JsonKey(name: 'interest_level')
  final String? interestLevel;
  @JsonKey(name: 'follow_up_required', required: true)
  final bool followUpRequired;
  @JsonKey(name: 'follow_up_date')
  final DateTime? followUpDate;

  /// The cancel reason. A reschedule reason is stored here too.
  @JsonKey(name: 'cancellation_reason')
  final String? cancellationReason;
  @JsonKey(name: 'rescheduled_from')
  final DateTime? rescheduledFrom;
  @JsonKey(name: 'created_at', required: true)
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;
  // The backend nests the full property, the assigned agent and the people on the visit.
  final PropertyModel? property;
  final VisitAgentInfo? agents;

  /// The visitor.
  final PublicUserRef? user;

  /// The other person on a flatmate meet. Null on a property tour.
  @JsonKey(name: 'counterparty_user')
  final PublicUserRef? counterpartyUser;

  const VisitModel({
    required this.id,
    required this.propertyId,
    required this.userId,
    this.agentId,
    required this.scheduledDate,
    this.timeSlotLabel,
    this.actualDate,
    required this.status,
    this.visitContext = VisitContext.propertyTour,
    this.conversationId,
    this.matchId,
    this.specialRequirements,
    this.visitNotes,
    this.visitorFeedback,
    this.interestLevel,
    this.followUpRequired = false,
    this.followUpDate,
    this.cancellationReason,
    this.rescheduledFrom,
    required this.createdAt,
    this.updatedAt,
    this.property,
    this.agents,
    this.user,
    this.counterpartyUser,
  });

  factory VisitModel.fromJson(Map<String, dynamic> json) => _$VisitModelFromJson(json);

  Map<String, dynamic> toJson() => _$VisitModelToJson(this);

  // Convenience getters
  /// Empty when the backend sent no nested property; the UI then shows a
  /// localized placeholder.
  String get propertyTitle => property?.title ?? '';
  String get agentPhone => agents?.phone ?? '';
  String get notes => visitNotes ?? '';

  /// A meeting with another flatmate, not a property tour.
  bool get isFlatmateMeet => visitContext == VisitContext.flatmateMeet;

  bool get isUpcoming => DateTime.now().isBefore(scheduledDate) && canCancel;
  bool get isCompleted => status == VisitStatus.completed;
  bool get isCancelled => status == VisitStatus.cancelled;

  /// Translation key of the status. A status this app does not know gets a neutral label.
  String get statusStringKey => switch (status) {
    VisitStatus.scheduled => 'visit_status_scheduled',
    VisitStatus.confirmed => 'visit_status_confirmed',
    VisitStatus.completed => 'visit_status_completed',
    VisitStatus.cancelled => 'visit_status_cancelled',
    VisitStatus.rescheduled => 'visit_status_rescheduled',
    null => 'visit_status_unknown',
  };

  @Deprecated('Use context.l10n.text(statusStringKey) for localized text')
  String get statusString => statusStringKey;

  bool get canReschedule =>
      status == VisitStatus.scheduled ||
      status == VisitStatus.confirmed ||
      status == VisitStatus.rescheduled;
  bool get canCancel => canReschedule;

  VisitModel copyWith({
    int? id,
    int? propertyId,
    int? userId,
    int? agentId,
    DateTime? scheduledDate,
    String? timeSlotLabel,
    DateTime? actualDate,
    VisitStatus? status,
    VisitContext? visitContext,
    int? conversationId,
    int? matchId,
    String? specialRequirements,
    String? visitNotes,
    String? visitorFeedback,
    String? interestLevel,
    bool? followUpRequired,
    DateTime? followUpDate,
    String? cancellationReason,
    DateTime? rescheduledFrom,
    DateTime? createdAt,
    DateTime? updatedAt,
    PropertyModel? property,
    VisitAgentInfo? agents,
    PublicUserRef? user,
    PublicUserRef? counterpartyUser,
  }) {
    return VisitModel(
      id: id ?? this.id,
      propertyId: propertyId ?? this.propertyId,
      userId: userId ?? this.userId,
      agentId: agentId ?? this.agentId,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      timeSlotLabel: timeSlotLabel ?? this.timeSlotLabel,
      actualDate: actualDate ?? this.actualDate,
      status: status ?? this.status,
      visitContext: visitContext ?? this.visitContext,
      conversationId: conversationId ?? this.conversationId,
      matchId: matchId ?? this.matchId,
      specialRequirements: specialRequirements ?? this.specialRequirements,
      visitNotes: visitNotes ?? this.visitNotes,
      visitorFeedback: visitorFeedback ?? this.visitorFeedback,
      interestLevel: interestLevel ?? this.interestLevel,
      followUpRequired: followUpRequired ?? this.followUpRequired,
      followUpDate: followUpDate ?? this.followUpDate,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      rescheduledFrom: rescheduledFrom ?? this.rescheduledFrom,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      property: property ?? this.property,
      agents: agents ?? this.agents,
      user: user ?? this.user,
      counterpartyUser: counterpartyUser ?? this.counterpartyUser,
    );
  }
}
