// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'visit_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VisitAgentInfo _$VisitAgentInfoFromJson(Map<String, dynamic> json) => VisitAgentInfo(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  phone: json['phone'] as String?,
  avatarUrl: json['avatar_url'] as String?,
);

Map<String, dynamic> _$VisitAgentInfoToJson(VisitAgentInfo instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'phone': instance.phone,
  'avatar_url': instance.avatarUrl,
};

PublicUserRef _$PublicUserRefFromJson(Map<String, dynamic> json) => PublicUserRef(
  id: (json['id'] as num).toInt(),
  displayName: json['display_name'] as String?,
  avatarUrl: json['avatar_url'] as String?,
);

Map<String, dynamic> _$PublicUserRefToJson(PublicUserRef instance) => <String, dynamic>{
  'id': instance.id,
  'display_name': instance.displayName,
  'avatar_url': instance.avatarUrl,
};

VisitModel _$VisitModelFromJson(Map<String, dynamic> json) => $checkedCreate(
  'VisitModel',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'id',
        'property_id',
        'user_id',
        'scheduled_date',
        'status',
        'visit_context',
        'follow_up_required',
        'created_at',
      ],
      disallowNullValues: const ['visit_context'],
    );
    final val = VisitModel(
      id: $checkedConvert('id', (v) => (v as num).toInt()),
      propertyId: $checkedConvert('property_id', (v) => (v as num).toInt()),
      userId: $checkedConvert('user_id', (v) => (v as num).toInt()),
      agentId: $checkedConvert('agent_id', (v) => (v as num?)?.toInt()),
      scheduledDate: $checkedConvert('scheduled_date', (v) => DateTime.parse(v as String)),
      timeSlotLabel: $checkedConvert('time_slot_label', (v) => v as String?),
      actualDate: $checkedConvert(
        'actual_date',
        (v) => v == null ? null : DateTime.parse(v as String),
      ),
      status: $checkedConvert('status', (v) => const VisitStatusConverter().fromJson(v)),
      visitContext: $checkedConvert(
        'visit_context',
        (v) => v == null ? VisitContext.propertyTour : const VisitContextConverter().fromJson(v),
      ),
      conversationId: $checkedConvert('conversation_id', (v) => (v as num?)?.toInt()),
      matchId: $checkedConvert('match_id', (v) => (v as num?)?.toInt()),
      specialRequirements: $checkedConvert('special_requirements', (v) => v as String?),
      visitNotes: $checkedConvert('visit_notes', (v) => v as String?),
      visitorFeedback: $checkedConvert('visitor_feedback', (v) => v as String?),
      interestLevel: $checkedConvert('interest_level', (v) => v as String?),
      followUpRequired: $checkedConvert('follow_up_required', (v) => v as bool? ?? false),
      followUpDate: $checkedConvert(
        'follow_up_date',
        (v) => v == null ? null : DateTime.parse(v as String),
      ),
      cancellationReason: $checkedConvert('cancellation_reason', (v) => v as String?),
      rescheduledFrom: $checkedConvert(
        'rescheduled_from',
        (v) => v == null ? null : DateTime.parse(v as String),
      ),
      createdAt: $checkedConvert('created_at', (v) => DateTime.parse(v as String)),
      updatedAt: $checkedConvert(
        'updated_at',
        (v) => v == null ? null : DateTime.parse(v as String),
      ),
      property: $checkedConvert(
        'property',
        (v) => v == null ? null : PropertyModel.fromJson(v as Map<String, dynamic>),
      ),
      agents: $checkedConvert(
        'agents',
        (v) => v == null ? null : VisitAgentInfo.fromJson(v as Map<String, dynamic>),
      ),
      user: $checkedConvert(
        'user',
        (v) => v == null ? null : PublicUserRef.fromJson(v as Map<String, dynamic>),
      ),
      counterpartyUser: $checkedConvert(
        'counterparty_user',
        (v) => v == null ? null : PublicUserRef.fromJson(v as Map<String, dynamic>),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'propertyId': 'property_id',
    'userId': 'user_id',
    'agentId': 'agent_id',
    'scheduledDate': 'scheduled_date',
    'timeSlotLabel': 'time_slot_label',
    'actualDate': 'actual_date',
    'visitContext': 'visit_context',
    'conversationId': 'conversation_id',
    'matchId': 'match_id',
    'specialRequirements': 'special_requirements',
    'visitNotes': 'visit_notes',
    'visitorFeedback': 'visitor_feedback',
    'interestLevel': 'interest_level',
    'followUpRequired': 'follow_up_required',
    'followUpDate': 'follow_up_date',
    'cancellationReason': 'cancellation_reason',
    'rescheduledFrom': 'rescheduled_from',
    'createdAt': 'created_at',
    'updatedAt': 'updated_at',
    'counterpartyUser': 'counterparty_user',
  },
);

Map<String, dynamic> _$VisitModelToJson(VisitModel instance) => <String, dynamic>{
  'id': instance.id,
  'property_id': instance.propertyId,
  'user_id': instance.userId,
  'agent_id': instance.agentId,
  'scheduled_date': instance.scheduledDate.toIso8601String(),
  'time_slot_label': instance.timeSlotLabel,
  'actual_date': instance.actualDate?.toIso8601String(),
  'status': const VisitStatusConverter().toJson(instance.status),
  'visit_context': ?const VisitContextConverter().toJson(instance.visitContext),
  'conversation_id': instance.conversationId,
  'match_id': instance.matchId,
  'special_requirements': instance.specialRequirements,
  'visit_notes': instance.visitNotes,
  'visitor_feedback': instance.visitorFeedback,
  'interest_level': instance.interestLevel,
  'follow_up_required': instance.followUpRequired,
  'follow_up_date': instance.followUpDate?.toIso8601String(),
  'cancellation_reason': instance.cancellationReason,
  'rescheduled_from': instance.rescheduledFrom?.toIso8601String(),
  'created_at': instance.createdAt.toIso8601String(),
  'updated_at': instance.updatedAt?.toIso8601String(),
  'property': instance.property?.toJson(),
  'agents': instance.agents?.toJson(),
  'user': instance.user?.toJson(),
  'counterparty_user': instance.counterpartyUser?.toJson(),
};
