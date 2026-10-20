// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserPreferences _$UserPreferencesFromJson(Map<String, dynamic> json) => UserPreferences(
  propertyType: _propertyTypesFromJson(json['property_type']),
  purpose: const PropertyPurposeConverter().fromJson(json['purpose']),
  budgetMin: (json['budget_min'] as num?)?.toDouble(),
  budgetMax: (json['budget_max'] as num?)?.toDouble(),
  bedroomsMin: (json['bedrooms_min'] as num?)?.toInt(),
  bedroomsMax: (json['bedrooms_max'] as num?)?.toInt(),
  areaMin: (json['area_min'] as num?)?.toDouble(),
  areaMax: (json['area_max'] as num?)?.toDouble(),
  locationPreference: _placesFromJson(json['location_preference']),
  maxDistanceKm: (json['max_distance_km'] as num?)?.toInt(),
);

Map<String, dynamic> _$UserPreferencesToJson(UserPreferences instance) => <String, dynamic>{
  'property_type': _propertyTypesToJson(instance.propertyType),
  'purpose': const PropertyPurposeConverter().toJson(instance.purpose),
  'budget_min': instance.budgetMin,
  'budget_max': instance.budgetMax,
  'bedrooms_min': instance.bedroomsMin,
  'bedrooms_max': instance.bedroomsMax,
  'area_min': instance.areaMin,
  'area_max': instance.areaMax,
  'location_preference': instance.locationPreference,
  'max_distance_km': instance.maxDistanceKm,
};

UserNotificationSettings _$UserNotificationSettingsFromJson(Map<String, dynamic> json) {
  $checkKeys(
    json,
    requiredKeys: const [
      'push_notifications',
      'email_notifications',
      'sms_notifications',
      'promotional_emails',
    ],
  );
  return UserNotificationSettings(
    pushNotifications: json['push_notifications'] as bool? ?? true,
    emailNotifications: json['email_notifications'] as bool? ?? true,
    smsNotifications: json['sms_notifications'] as bool? ?? false,
    promotionalEmails: json['promotional_emails'] as bool? ?? false,
  );
}

Map<String, dynamic> _$UserNotificationSettingsToJson(UserNotificationSettings instance) =>
    <String, dynamic>{
      'push_notifications': instance.pushNotifications,
      'email_notifications': instance.emailNotifications,
      'sms_notifications': instance.smsNotifications,
      'promotional_emails': instance.promotionalEmails,
    };

UserPrivacySettings _$UserPrivacySettingsFromJson(Map<String, dynamic> json) {
  $checkKeys(
    json,
    requiredKeys: const [
      'profile_visibility',
      'location_sharing',
      'contact_sharing',
      'search_history_tracking',
      'hide_last_name',
      'show_phone',
      'show_email',
      'allow_location_tracking',
      'data_sharing_consent',
    ],
  );
  return UserPrivacySettings(
    profileVisibility: json['profile_visibility'] == null
        ? ProfileVisibility.public
        : const ProfileVisibilityConverter().fromJson(json['profile_visibility']),
    locationSharing: json['location_sharing'] as bool? ?? true,
    contactSharing: json['contact_sharing'] as bool? ?? true,
    searchHistoryTracking: json['search_history_tracking'] as bool? ?? true,
    hideLastName: json['hide_last_name'] as bool? ?? false,
    showPhone: json['show_phone'] as bool? ?? false,
    showEmail: json['show_email'] as bool? ?? false,
    allowLocationTracking: json['allow_location_tracking'] as bool? ?? true,
    dataSharingConsent: json['data_sharing_consent'] as bool? ?? false,
  );
}

Map<String, dynamic> _$UserPrivacySettingsToJson(UserPrivacySettings instance) => <String, dynamic>{
  'profile_visibility': const ProfileVisibilityConverter().toJson(instance.profileVisibility),
  'location_sharing': instance.locationSharing,
  'contact_sharing': instance.contactSharing,
  'search_history_tracking': instance.searchHistoryTracking,
  'hide_last_name': instance.hideLastName,
  'show_phone': instance.showPhone,
  'show_email': instance.showEmail,
  'allow_location_tracking': instance.allowLocationTracking,
  'data_sharing_consent': instance.dataSharingConsent,
};

UserModel _$UserModelFromJson(Map<String, dynamic> json) {
  $checkKeys(
    json,
    requiredKeys: const [
      'id',
      'supabase_user_id',
      'role',
      'is_active',
      'is_verified',
      'phone_verified',
      'email_verified',
      'preferences',
      'notification_settings',
      'privacy_settings',
      'created_at',
    ],
  );
  return UserModel(
    id: (json['id'] as num).toInt(),
    supabaseUserId: json['supabase_user_id'] as String,
    email: json['email'] as String?,
    fullName: json['full_name'] as String?,
    phone: json['phone'] as String?,
    dateOfBirth: json['date_of_birth'] as String?,
    role: json['role'] == null ? UserRole.user : const UserRoleConverter().fromJson(json['role']),
    isActive: json['is_active'] as bool,
    isVerified: json['is_verified'] as bool,
    phoneVerified: json['phone_verified'] as bool? ?? false,
    emailVerified: json['email_verified'] as bool? ?? false,
    profileImageUrl: json['profile_image_url'] as String?,
    preferences: json['preferences'] == null
        ? const UserPreferences()
        : UserPreferences.fromJson(json['preferences'] as Map<String, dynamic>),
    currentLatitude: (json['current_latitude'] as num?)?.toDouble(),
    currentLongitude: (json['current_longitude'] as num?)?.toDouble(),
    notificationSettings: json['notification_settings'] == null
        ? const UserNotificationSettings()
        : UserNotificationSettings.fromJson(json['notification_settings'] as Map<String, dynamic>),
    privacySettings: json['privacy_settings'] == null
        ? const UserPrivacySettings()
        : UserPrivacySettings.fromJson(json['privacy_settings'] as Map<String, dynamic>),
    agentId: (json['agent_id'] as num?)?.toInt(),
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: json['updated_at'] == null ? null : DateTime.parse(json['updated_at'] as String),
  );
}

Map<String, dynamic> _$UserModelToJson(UserModel instance) => <String, dynamic>{
  'id': instance.id,
  'supabase_user_id': instance.supabaseUserId,
  'email': instance.email,
  'full_name': instance.fullName,
  'phone': instance.phone,
  'date_of_birth': instance.dateOfBirth,
  'role': const UserRoleConverter().toJson(instance.role),
  'is_active': instance.isActive,
  'is_verified': instance.isVerified,
  'phone_verified': instance.phoneVerified,
  'email_verified': instance.emailVerified,
  'profile_image_url': instance.profileImageUrl,
  'preferences': instance.preferences.toJson(),
  'current_latitude': instance.currentLatitude,
  'current_longitude': instance.currentLongitude,
  'notification_settings': instance.notificationSettings.toJson(),
  'privacy_settings': instance.privacySettings.toJson(),
  'agent_id': instance.agentId,
  'created_at': instance.createdAt.toIso8601String(),
  'updated_at': instance.updatedAt?.toIso8601String(),
};
