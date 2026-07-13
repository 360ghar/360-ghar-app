import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/data/models/api_response_models.dart';

void main() {
  group('SortBy enum', () {
    test('has all expected values', () {
      expect(SortBy.values.length, 6);
      expect(SortBy.values, contains(SortBy.distance));
      expect(SortBy.values, contains(SortBy.priceLow));
      expect(SortBy.values, contains(SortBy.priceHigh));
      expect(SortBy.values, contains(SortBy.newest));
      expect(SortBy.values, contains(SortBy.popular));
      expect(SortBy.values, contains(SortBy.relevance));
    });
  });

  group('MessageResponse', () {
    test('fromJson parses message and success', () {
      final json = <String, dynamic>{'message': 'Operation completed', 'success': false};

      final response = MessageResponse.fromJson(json);

      expect(response.message, 'Operation completed');
      expect(response.success, false);
    });

    test('fromJson defaults success to true when missing', () {
      final response = MessageResponse.fromJson({'message': 'Hello'});

      expect(response.message, 'Hello');
      expect(response.success, true);
    });

    test('toJson roundtrip preserves fields', () {
      const original = MessageResponse(message: 'Saved', success: false);

      final json = original.toJson();
      final restored = MessageResponse.fromJson(json);

      expect(restored.message, original.message);
      expect(restored.success, original.success);
    });
  });

  group('ErrorResponse', () {
    test('fromJson parses full JSON with errorCode and details', () {
      final json = <String, dynamic>{
        'message': 'Not found',
        'error_code': 'NOT_FOUND',
        'details': {'resource': 'property', 'id': 42},
      };

      final response = ErrorResponse.fromJson(json);

      expect(response.message, 'Not found');
      expect(response.errorCode, 'NOT_FOUND');
      expect(response.details, {'resource': 'property', 'id': 42});
    });

    test('fromJson handles missing errorCode and details', () {
      final response = ErrorResponse.fromJson({'message': 'Something went wrong'});

      expect(response.message, 'Something went wrong');
      expect(response.errorCode, isNull);
      expect(response.details, isNull);
    });

    test('toJson roundtrip preserves all fields', () {
      final original = const ErrorResponse(
        message: 'Validation failed',
        errorCode: 'VALIDATION_ERROR',
        details: {'field': 'email'},
      );

      final json = original.toJson();
      final restored = ErrorResponse.fromJson(json);

      expect(restored.message, original.message);
      expect(restored.errorCode, original.errorCode);
      expect(restored.details, original.details);
    });

    test('toJson roundtrip works without optional fields', () {
      const original = ErrorResponse(message: 'Error');

      final json = original.toJson();
      final restored = ErrorResponse.fromJson(json);

      expect(restored.message, 'Error');
      expect(restored.errorCode, isNull);
      expect(restored.details, isNull);
    });
  });

  group('NotificationSettings', () {
    test('fromJson applies defaults for missing fields', () {
      final settings = NotificationSettings.fromJson({});

      expect(settings.emailNotifications, true);
      expect(settings.pushNotifications, true);
      expect(settings.smsNotifications, false);
      expect(settings.visitReminders, true);
      expect(settings.propertyUpdates, true);
      expect(settings.promotionalEmails, false);
    });

    test('fromJson parses provided values', () {
      final json = <String, dynamic>{
        'email_notifications': false,
        'push_notifications': false,
        'sms_notifications': true,
        'visit_reminders': false,
        'property_updates': false,
        'promotional_emails': true,
      };

      final settings = NotificationSettings.fromJson(json);

      expect(settings.emailNotifications, false);
      expect(settings.pushNotifications, false);
      expect(settings.smsNotifications, true);
      expect(settings.visitReminders, false);
      expect(settings.propertyUpdates, false);
      expect(settings.promotionalEmails, true);
    });

    test('toJson roundtrip preserves all fields', () {
      final original = const NotificationSettings(
        emailNotifications: false,
        pushNotifications: true,
        smsNotifications: true,
        visitReminders: false,
        propertyUpdates: true,
        promotionalEmails: true,
      );

      final json = original.toJson();
      final restored = NotificationSettings.fromJson(json);

      expect(restored.emailNotifications, original.emailNotifications);
      expect(restored.pushNotifications, original.pushNotifications);
      expect(restored.smsNotifications, original.smsNotifications);
      expect(restored.visitReminders, original.visitReminders);
      expect(restored.propertyUpdates, original.propertyUpdates);
      expect(restored.promotionalEmails, original.promotionalEmails);
    });

    test('copyWith updates only specified fields', () {
      const original = NotificationSettings();

      final copy = original.copyWith(smsNotifications: true, promotionalEmails: true);

      expect(copy.smsNotifications, true);
      expect(copy.promotionalEmails, true);
      expect(copy.emailNotifications, original.emailNotifications, reason: 'unmodified preserved');
      expect(copy.pushNotifications, original.pushNotifications);
      expect(copy.visitReminders, original.visitReminders);
      expect(copy.propertyUpdates, original.propertyUpdates);
    });
  });

  group('PrivacySettings', () {
    test('fromJson applies defaults for missing fields', () {
      final settings = PrivacySettings.fromJson({});

      expect(settings.profileVisibility, 'public');
      expect(settings.locationSharing, true);
      expect(settings.contactSharing, true);
    });

    test('fromJson parses provided values', () {
      final json = <String, dynamic>{
        'profile_visibility': 'private',
        'location_sharing': false,
        'contact_sharing': false,
      };

      final settings = PrivacySettings.fromJson(json);

      expect(settings.profileVisibility, 'private');
      expect(settings.locationSharing, false);
      expect(settings.contactSharing, false);
    });

    test('toJson roundtrip preserves all fields', () {
      const original = PrivacySettings(
        profileVisibility: 'private',
        locationSharing: false,
        contactSharing: false,
      );

      final json = original.toJson();
      final restored = PrivacySettings.fromJson(json);

      expect(restored.profileVisibility, original.profileVisibility);
      expect(restored.locationSharing, original.locationSharing);
      expect(restored.contactSharing, original.contactSharing);
    });

    test('copyWith updates only specified fields', () {
      const original = PrivacySettings();

      final copy = original.copyWith(profileVisibility: 'private');

      expect(copy.profileVisibility, 'private');
      expect(copy.locationSharing, original.locationSharing);
      expect(copy.contactSharing, original.contactSharing);
    });

    test('isProfilePublic is true when visibility is public', () {
      expect(const PrivacySettings(profileVisibility: 'public').isProfilePublic, true);
      expect(const PrivacySettings(profileVisibility: 'private').isProfilePublic, false);
    });

    test('isProfilePrivate is true when visibility is private', () {
      expect(const PrivacySettings(profileVisibility: 'private').isProfilePrivate, true);
      expect(const PrivacySettings(profileVisibility: 'public').isProfilePrivate, false);
    });
  });

  group('LocationUpdate', () {
    test('fromJson parses latitude and longitude', () {
      final json = <String, dynamic>{'latitude': 28.6139, 'longitude': 77.2090};

      final location = LocationUpdate.fromJson(json);

      expect(location.latitude, 28.6139);
      expect(location.longitude, 77.2090);
    });

    test('toJson roundtrip preserves fields', () {
      const original = LocationUpdate(latitude: 19.0760, longitude: 72.8777);

      final json = original.toJson();
      final restored = LocationUpdate.fromJson(json);

      expect(restored.latitude, original.latitude);
      expect(restored.longitude, original.longitude);
    });
  });
}
