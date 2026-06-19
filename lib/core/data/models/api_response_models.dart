import 'package:json_annotation/json_annotation.dart';

part 'api_response_models.g.dart';

// Sort options for property searches
enum SortBy {
  @JsonValue('distance')
  distance,
  @JsonValue('price_low')
  priceLow,
  @JsonValue('price_high')
  priceHigh,
  @JsonValue('newest')
  newest,
  @JsonValue('popular')
  popular,
  @JsonValue('relevance')
  relevance,
}

// Note: legacy page/offset-based PaginationParams, PaginatedResponse<T>, and
// SearchParams were removed during the cursor-pagination migration. All list
// endpoints now use the uniform `{items, next_cursor, has_more, limit}`
// envelope consumed by [UnifiedPropertyResponse].

@JsonSerializable()
class MessageResponse {
  final String message;
  final bool success;

  const MessageResponse({required this.message, this.success = true});

  factory MessageResponse.fromJson(Map<String, dynamic> json) => _$MessageResponseFromJson(json);

  Map<String, dynamic> toJson() => _$MessageResponseToJson(this);
}

@JsonSerializable()
class ErrorResponse {
  final String message;
  @JsonKey(name: 'error_code')
  final String? errorCode;
  final Map<String, dynamic>? details;

  const ErrorResponse({required this.message, this.errorCode, this.details});

  factory ErrorResponse.fromJson(Map<String, dynamic> json) => _$ErrorResponseFromJson(json);

  Map<String, dynamic> toJson() => _$ErrorResponseToJson(this);
}

@JsonSerializable()
class NotificationSettings {
  @JsonKey(name: 'email_notifications')
  final bool emailNotifications;
  @JsonKey(name: 'push_notifications')
  final bool pushNotifications;
  @JsonKey(name: 'sms_notifications')
  final bool smsNotifications;
  @JsonKey(name: 'visit_reminders')
  final bool visitReminders;
  @JsonKey(name: 'property_updates')
  final bool propertyUpdates;
  @JsonKey(name: 'promotional_emails')
  final bool promotionalEmails;

  const NotificationSettings({
    this.emailNotifications = true,
    this.pushNotifications = true,
    this.smsNotifications = false,
    this.visitReminders = true,
    this.propertyUpdates = true,
    this.promotionalEmails = false,
  });

  factory NotificationSettings.fromJson(Map<String, dynamic> json) =>
      _$NotificationSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$NotificationSettingsToJson(this);

  NotificationSettings copyWith({
    bool? emailNotifications,
    bool? pushNotifications,
    bool? smsNotifications,
    bool? visitReminders,
    bool? propertyUpdates,
    bool? promotionalEmails,
  }) {
    return NotificationSettings(
      emailNotifications: emailNotifications ?? this.emailNotifications,
      pushNotifications: pushNotifications ?? this.pushNotifications,
      smsNotifications: smsNotifications ?? this.smsNotifications,
      visitReminders: visitReminders ?? this.visitReminders,
      propertyUpdates: propertyUpdates ?? this.propertyUpdates,
      promotionalEmails: promotionalEmails ?? this.promotionalEmails,
    );
  }
}

@JsonSerializable()
class PrivacySettings {
  @JsonKey(name: 'profile_visibility')
  final String profileVisibility; // "public", "private"
  @JsonKey(name: 'location_sharing')
  final bool locationSharing;
  @JsonKey(name: 'contact_sharing')
  final bool contactSharing;

  const PrivacySettings({
    this.profileVisibility = 'public',
    this.locationSharing = true,
    this.contactSharing = true,
  });

  factory PrivacySettings.fromJson(Map<String, dynamic> json) => _$PrivacySettingsFromJson(json);

  Map<String, dynamic> toJson() => _$PrivacySettingsToJson(this);

  PrivacySettings copyWith({
    String? profileVisibility,
    bool? locationSharing,
    bool? contactSharing,
  }) {
    return PrivacySettings(
      profileVisibility: profileVisibility ?? this.profileVisibility,
      locationSharing: locationSharing ?? this.locationSharing,
      contactSharing: contactSharing ?? this.contactSharing,
    );
  }

  bool get isProfilePublic => profileVisibility == 'public';
  bool get isProfilePrivate => profileVisibility == 'private';
}

// Location update model
@JsonSerializable()
class LocationUpdate {
  final double latitude;
  final double longitude;

  const LocationUpdate({required this.latitude, required this.longitude});

  factory LocationUpdate.fromJson(Map<String, dynamic> json) => _$LocationUpdateFromJson(json);

  Map<String, dynamic> toJson() => _$LocationUpdateToJson(this);
}
