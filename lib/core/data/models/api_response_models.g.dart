// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api_response_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MessageResponse _$MessageResponseFromJson(Map<String, dynamic> json) =>
    MessageResponse(message: json['message'] as String, success: json['success'] as bool? ?? true);

Map<String, dynamic> _$MessageResponseToJson(MessageResponse instance) => <String, dynamic>{
  'message': instance.message,
  'success': instance.success,
};

ErrorResponse _$ErrorResponseFromJson(Map<String, dynamic> json) => ErrorResponse(
  message: json['message'] as String,
  errorCode: json['error_code'] as String?,
  details: json['details'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$ErrorResponseToJson(ErrorResponse instance) => <String, dynamic>{
  'message': instance.message,
  'error_code': instance.errorCode,
  'details': instance.details,
};

NotificationSettings _$NotificationSettingsFromJson(Map<String, dynamic> json) =>
    NotificationSettings(
      emailNotifications: json['email_notifications'] as bool? ?? true,
      pushNotifications: json['push_notifications'] as bool? ?? true,
      smsNotifications: json['sms_notifications'] as bool? ?? false,
      visitReminders: json['visit_reminders'] as bool? ?? true,
      propertyUpdates: json['property_updates'] as bool? ?? true,
      promotionalEmails: json['promotional_emails'] as bool? ?? false,
    );

Map<String, dynamic> _$NotificationSettingsToJson(NotificationSettings instance) =>
    <String, dynamic>{
      'email_notifications': instance.emailNotifications,
      'push_notifications': instance.pushNotifications,
      'sms_notifications': instance.smsNotifications,
      'visit_reminders': instance.visitReminders,
      'property_updates': instance.propertyUpdates,
      'promotional_emails': instance.promotionalEmails,
    };

PrivacySettings _$PrivacySettingsFromJson(Map<String, dynamic> json) => PrivacySettings(
  profileVisibility: json['profile_visibility'] as String? ?? 'public',
  locationSharing: json['location_sharing'] as bool? ?? true,
  contactSharing: json['contact_sharing'] as bool? ?? true,
);

Map<String, dynamic> _$PrivacySettingsToJson(PrivacySettings instance) => <String, dynamic>{
  'profile_visibility': instance.profileVisibility,
  'location_sharing': instance.locationSharing,
  'contact_sharing': instance.contactSharing,
};

LocationUpdate _$LocationUpdateFromJson(Map<String, dynamic> json) => LocationUpdate(
  latitude: (json['latitude'] as num).toDouble(),
  longitude: (json['longitude'] as num).toDouble(),
);

Map<String, dynamic> _$LocationUpdateToJson(LocationUpdate instance) => <String, dynamic>{
  'latitude': instance.latitude,
  'longitude': instance.longitude,
};
