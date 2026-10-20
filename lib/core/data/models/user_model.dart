import 'package:flutter/foundation.dart';
import 'package:ghar360/core/data/models/wire_enums.dart';
import 'package:json_annotation/json_annotation.dart';

export 'package:ghar360/core/data/models/wire_enums.dart' show UserRole;

part 'user_model.g.dart';

/// `UserPreferences`: what the user looks for. Every key is optional; an absent key is null.
@immutable
@JsonSerializable()
class UserPreferences {
  const UserPreferences({
    this.propertyType,
    this.purpose,
    this.budgetMin,
    this.budgetMax,
    this.bedroomsMin,
    this.bedroomsMax,
    this.areaMin,
    this.areaMax,
    this.locationPreference,
    this.maxDistanceKm,
  });

  factory UserPreferences.fromJson(Map<String, dynamic> json) => _$UserPreferencesFromJson(json);

  /// Types this app does not know are left out.
  @JsonKey(name: 'property_type', fromJson: _propertyTypesFromJson, toJson: _propertyTypesToJson)
  final List<PropertyType>? propertyType;
  @PropertyPurposeConverter()
  final PropertyPurpose? purpose;
  @JsonKey(name: 'budget_min')
  final double? budgetMin;
  @JsonKey(name: 'budget_max')
  final double? budgetMax;
  @JsonKey(name: 'bedrooms_min')
  final int? bedroomsMin;
  @JsonKey(name: 'bedrooms_max')
  final int? bedroomsMax;
  @JsonKey(name: 'area_min')
  final double? areaMin;
  @JsonKey(name: 'area_max')
  final double? areaMax;
  @JsonKey(name: 'location_preference', fromJson: _placesFromJson)
  final List<String>? locationPreference;
  @JsonKey(name: 'max_distance_km')
  final int? maxDistanceKm;

  Map<String, dynamic> toJson() => _$UserPreferencesToJson(this);

  /// The first saved place, shown as "location" on the profile.
  String? get location {
    final places = locationPreference;
    return places == null || places.isEmpty ? null : places.first;
  }
}

List<PropertyType>? _propertyTypesFromJson(Object? value) {
  if (value == null) return null;
  if (value is! List) throw FormatException('Expected a list, got ${value.runtimeType}');
  return List.unmodifiable([for (final item in value) ?PropertyType.fromJson(item)]);
}

List<String>? _placesFromJson(Object? value) {
  if (value == null) return null;
  if (value is! List) throw FormatException('Expected a list, got ${value.runtimeType}');
  return List.unmodifiable(value.cast<String>());
}

List<String>? _propertyTypesToJson(List<PropertyType>? value) =>
    value?.map((type) => type.wire).toList();

/// `NotificationSettings`: the four switches the backend keeps.
@immutable
@JsonSerializable()
class UserNotificationSettings {
  const UserNotificationSettings({
    this.pushNotifications = true,
    this.emailNotifications = true,
    this.smsNotifications = false,
    this.promotionalEmails = false,
  });

  factory UserNotificationSettings.fromJson(Map<String, dynamic> json) =>
      _$UserNotificationSettingsFromJson(json);

  @JsonKey(name: 'push_notifications', required: true)
  final bool pushNotifications;
  @JsonKey(name: 'email_notifications', required: true)
  final bool emailNotifications;
  @JsonKey(name: 'sms_notifications', required: true)
  final bool smsNotifications;
  @JsonKey(name: 'promotional_emails', required: true)
  final bool promotionalEmails;

  Map<String, dynamic> toJson() => _$UserNotificationSettingsToJson(this);

  /// The value of one backend key, or null for a key that is not a notification switch.
  bool? operator [](String key) => switch (key) {
    'push_notifications' => pushNotifications,
    'email_notifications' => emailNotifications,
    'sms_notifications' => smsNotifications,
    'promotional_emails' => promotionalEmails,
    _ => null,
  };

  /// A copy with one switch changed. [key] is a backend name from [keys].
  UserNotificationSettings withSwitch(String key, bool value) => UserNotificationSettings(
    pushNotifications: key == 'push_notifications' ? value : pushNotifications,
    emailNotifications: key == 'email_notifications' ? value : emailNotifications,
    smsNotifications: key == 'sms_notifications' ? value : smsNotifications,
    promotionalEmails: key == 'promotional_emails' ? value : promotionalEmails,
  );

  /// The backend names of the four switches.
  static const keys = [
    'push_notifications',
    'email_notifications',
    'sms_notifications',
    'promotional_emails',
  ];
}

/// `PrivacySettings`.
@immutable
@JsonSerializable()
class UserPrivacySettings {
  const UserPrivacySettings({
    this.profileVisibility = ProfileVisibility.public,
    this.locationSharing = true,
    this.contactSharing = true,
    this.searchHistoryTracking = true,
    this.hideLastName = false,
    this.showPhone = false,
    this.showEmail = false,
    this.allowLocationTracking = true,
    this.dataSharingConsent = false,
  });

  factory UserPrivacySettings.fromJson(Map<String, dynamic> json) =>
      _$UserPrivacySettingsFromJson(json);

  /// `public`, `agents_only` or `private`. Null for a value this app does not know.
  @JsonKey(name: 'profile_visibility', required: true)
  @ProfileVisibilityConverter()
  final ProfileVisibility? profileVisibility;
  @JsonKey(name: 'location_sharing', required: true)
  final bool locationSharing;
  @JsonKey(name: 'contact_sharing', required: true)
  final bool contactSharing;
  @JsonKey(name: 'search_history_tracking', required: true)
  final bool searchHistoryTracking;
  @JsonKey(name: 'hide_last_name', required: true)
  final bool hideLastName;
  @JsonKey(name: 'show_phone', required: true)
  final bool showPhone;
  @JsonKey(name: 'show_email', required: true)
  final bool showEmail;
  @JsonKey(name: 'allow_location_tracking', required: true)
  final bool allowLocationTracking;
  @JsonKey(name: 'data_sharing_consent', required: true)
  final bool dataSharingConsent;

  Map<String, dynamic> toJson() => _$UserPrivacySettingsToJson(this);
}

/// `SelfUser`: the signed-in user's own record. It is the only user shape with
/// `supabase_user_id`.
@immutable
@JsonSerializable(explicitToJson: true)
class UserModel {
  const UserModel({
    required this.id,
    required this.supabaseUserId,
    this.email,
    this.fullName,
    this.phone,
    this.dateOfBirth,
    this.role = UserRole.user,
    required this.isActive,
    required this.isVerified,
    this.phoneVerified = false,
    this.emailVerified = false,
    this.profileImageUrl,
    this.preferences = const UserPreferences(),
    this.currentLatitude,
    this.currentLongitude,
    this.notificationSettings = const UserNotificationSettings(),
    this.privacySettings = const UserPrivacySettings(),
    this.agentId,
    required this.createdAt,
    this.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => _$UserModelFromJson(json);

  @JsonKey(required: true)
  final int id;
  @JsonKey(name: 'supabase_user_id', required: true)
  final String supabaseUserId;

  /// Null for a phone-only account.
  final String? email;
  @JsonKey(name: 'full_name')
  final String? fullName;
  final String? phone;

  /// `YYYY-MM-DD`.
  @JsonKey(name: 'date_of_birth')
  final String? dateOfBirth;
  @JsonKey(required: true)
  @UserRoleConverter()
  final UserRole? role;
  @JsonKey(name: 'is_active', required: true)
  final bool isActive;
  @JsonKey(name: 'is_verified', required: true)
  final bool isVerified;
  @JsonKey(name: 'phone_verified', required: true)
  final bool phoneVerified;
  @JsonKey(name: 'email_verified', required: true)
  final bool emailVerified;
  @JsonKey(name: 'profile_image_url')
  final String? profileImageUrl;
  @JsonKey(required: true)
  final UserPreferences preferences;
  @JsonKey(name: 'current_latitude')
  final double? currentLatitude;
  @JsonKey(name: 'current_longitude')
  final double? currentLongitude;
  @JsonKey(name: 'notification_settings', required: true)
  final UserNotificationSettings notificationSettings;
  @JsonKey(name: 'privacy_settings', required: true)
  final UserPrivacySettings privacySettings;
  @JsonKey(name: 'agent_id')
  final int? agentId;
  @JsonKey(name: 'created_at', required: true)
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => _$UserModelToJson(this);

  UserModel copyWith({
    int? id,
    String? supabaseUserId,
    String? email,
    String? fullName,
    String? phone,
    String? dateOfBirth,
    UserRole? role,
    bool? isActive,
    bool? isVerified,
    bool? phoneVerified,
    bool? emailVerified,
    String? profileImageUrl,
    UserPreferences? preferences,
    double? currentLatitude,
    double? currentLongitude,
    UserNotificationSettings? notificationSettings,
    UserPrivacySettings? privacySettings,
    int? agentId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      supabaseUserId: supabaseUserId ?? this.supabaseUserId,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      isVerified: isVerified ?? this.isVerified,
      phoneVerified: phoneVerified ?? this.phoneVerified,
      emailVerified: emailVerified ?? this.emailVerified,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      preferences: preferences ?? this.preferences,
      currentLatitude: currentLatitude ?? this.currentLatitude,
      currentLongitude: currentLongitude ?? this.currentLongitude,
      notificationSettings: notificationSettings ?? this.notificationSettings,
      privacySettings: privacySettings ?? this.privacySettings,
      agentId: agentId ?? this.agentId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Helper methods for date of birth
  DateTime? get dateOfBirthAsDate {
    if (dateOfBirth == null) return null;
    try {
      return DateTime.parse(dateOfBirth!);
    } catch (e) {
      return null;
    }
  }

  int? get age {
    final dob = dateOfBirthAsDate;
    if (dob == null) return null;
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  // Helper methods for location
  double? get latitudeAsDouble {
    return currentLatitude;
  }

  double? get longitudeAsDouble {
    return currentLongitude;
  }

  bool get hasLocation => currentLatitude != null && currentLongitude != null;

  // Convenience getters for UI consumption.
  /// Empty when the account has no name yet; the UI shows localized text for that.
  String get name => fullName ?? '';
  String? get profileImage => profileImageUrl;
  DateTime get lastLogin => updatedAt ?? createdAt;

  // Profile completion percentage
  int get profileCompletionPercentage {
    int completedFields = 0;
    const int totalFields = 5; // email, fullName, dateOfBirth, phone, profileImageUrl

    if (email != null && email!.isNotEmpty) completedFields++;
    if (fullName != null && fullName!.isNotEmpty) completedFields++;
    if (dateOfBirth != null && dateOfBirth!.isNotEmpty) completedFields++;
    if (phone != null && phone!.isNotEmpty) completedFields++;
    if (profileImageUrl != null && profileImageUrl!.isNotEmpty) {
      completedFields++;
    }

    return ((completedFields / totalFields) * 100).round();
  }

  // Check if profile is complete
  bool get isProfileComplete {
    final hasName = fullName != null && fullName!.isNotEmpty;
    final hasDob = dateOfBirth != null && dateOfBirth!.isNotEmpty;
    return hasName && hasDob;
  }
}
