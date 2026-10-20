import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/data/models/user_model.dart';
import 'package:ghar360/core/data/models/wire_enums.dart';

Map<String, dynamic> _privacy() => {
  'profile_visibility': 'agents_only',
  'location_sharing': true,
  'contact_sharing': true,
  'search_history_tracking': true,
  'hide_last_name': false,
  'show_phone': false,
  'show_email': false,
  'allow_location_tracking': true,
  'data_sharing_consent': false,
};

/// A `SelfUser` body as the backend sends it.
Map<String, dynamic> _selfUser({Map<String, dynamic> overrides = const {}}) => {
  'id': 1,
  'supabase_user_id': 'abc-123',
  'email': 'test@example.com',
  'full_name': 'John Doe',
  'phone': '+919876543210',
  'date_of_birth': '1990-06-15',
  'role': 'user',
  'is_active': true,
  'is_verified': true,
  'phone_verified': true,
  'email_verified': false,
  'profile_image_url': 'http://example.com/photo.jpg',
  'preferences': {
    'purpose': 'rent',
    'property_type': ['apartment'],
    'budget_min': 2500000.5,
    'location_preference': ['Gurugram'],
    'max_distance_km': 5,
  },
  'current_latitude': 28.6139,
  'current_longitude': 77.2090,
  'notification_settings': {
    'push_notifications': true,
    'email_notifications': true,
    'sms_notifications': false,
    'promotional_emails': false,
  },
  'privacy_settings': _privacy(),
  'agent_id': 4,
  'created_at': '2025-01-01T00:00:00Z',
  'updated_at': '2025-02-01T00:00:00Z',
  ...overrides,
};

void main() {
  group('UserModel.fromJson (SelfUser)', () {
    test('reads a full body', () {
      final model = UserModel.fromJson(_selfUser());

      expect(model.id, 1);
      expect(model.supabaseUserId, 'abc-123');
      expect(model.email, 'test@example.com');
      expect(model.fullName, 'John Doe');
      expect(model.phone, '+919876543210');
      expect(model.dateOfBirth, '1990-06-15');
      expect(model.role, UserRole.user);
      expect(model.isActive, true);
      expect(model.isVerified, true);
      expect(model.phoneVerified, true);
      expect(model.emailVerified, false);
      expect(model.profileImageUrl, 'http://example.com/photo.jpg');
      expect(model.currentLatitude, 28.6139);
      expect(model.currentLongitude, 77.2090);
      expect(model.agentId, 4);
      expect(model.createdAt, DateTime.utc(2025));
    });

    test('keys that can be empty read as null', () {
      final model = UserModel.fromJson(
        _selfUser(
          overrides: {
            'email': null,
            'full_name': null,
            'phone': null,
            'date_of_birth': null,
            'profile_image_url': null,
            'current_latitude': null,
            'current_longitude': null,
            'agent_id': null,
            'updated_at': null,
          },
        ),
      );

      expect(model.email, isNull);
      expect(model.fullName, isNull);
      expect(model.phone, isNull);
      expect(model.hasLocation, isFalse);
      expect(model.updatedAt, isNull);
    });

    test('a key the backend always sends is required', () {
      for (final key in [
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
      ]) {
        final body = _selfUser()..remove(key);
        expect(() => UserModel.fromJson(body), throwsA(anything), reason: 'missing $key');
      }
    });

    test('an unknown role reads as null: the app does not invent one', () {
      expect(UserModel.fromJson(_selfUser(overrides: {'role': 'superuser'})).role, isNull);
    });

    test('keys the app does not model are ignored', () {
      final model = UserModel.fromJson(
        _selfUser(overrides: {'last_auth_method': 'phone_otp', 'last_auth_method_at': null}),
      );

      expect(model.id, 1);
    });
  });

  group('UserPreferences', () {
    test('reads the backend keys', () {
      final preferences = UserModel.fromJson(_selfUser()).preferences;

      expect(preferences.purpose, PropertyPurpose.rent);
      expect(preferences.propertyType, [PropertyType.apartment]);
      expect(preferences.budgetMin, 2500000.5);
      expect(preferences.locationPreference, ['Gurugram']);
      expect(preferences.location, 'Gurugram');
      expect(preferences.maxDistanceKm, 5);
    });

    test('an unknown purpose reads as null and an unknown property type is left out', () {
      final preferences = UserPreferences.fromJson({
        'purpose': 'lease',
        'property_type': ['apartment', 'castle'],
      });

      expect(preferences.purpose, isNull);
      expect(preferences.propertyType, [PropertyType.apartment]);
    });

    test('an empty body is a valid set of preferences', () {
      final preferences = UserPreferences.fromJson({});

      expect(preferences.purpose, isNull);
      expect(preferences.location, isNull);
    });

    test('toJson writes wire values', () {
      const preferences = UserPreferences(
        purpose: PropertyPurpose.shortStay,
        propertyType: [PropertyType.builderFloor],
      );

      final json = preferences.toJson();

      expect(json['purpose'], 'short_stay');
      expect(json['property_type'], ['builder_floor']);
    });
  });

  group('UserNotificationSettings', () {
    test('reads the four switches', () {
      final settings = UserModel.fromJson(_selfUser()).notificationSettings;

      expect(settings.pushNotifications, true);
      expect(settings.emailNotifications, true);
      expect(settings.smsNotifications, false);
      expect(settings.promotionalEmails, false);
    });

    test('the removed keys are not read or written', () {
      final settings = UserNotificationSettings.fromJson({
        'push_notifications': false,
        'email_notifications': true,
        'sms_notifications': false,
        'promotional_emails': true,
        'visit_reminders': true,
        'quietHours': {'start': '22:00'},
      });

      expect(settings.toJson().keys, UserNotificationSettings.keys);
      expect(settings['visit_reminders'], isNull);
    });

    test('withSwitch changes one switch', () {
      const settings = UserNotificationSettings();

      final changed = settings.withSwitch('promotional_emails', true);

      expect(changed.promotionalEmails, true);
      expect(changed.pushNotifications, settings.pushNotifications);
    });

    test('a missing switch is a contract break', () {
      expect(
        () => UserNotificationSettings.fromJson({'push_notifications': true}),
        throwsA(anything),
      );
    });
  });

  group('UserPrivacySettings', () {
    test('reads profile_visibility as an enum', () {
      final settings = UserModel.fromJson(_selfUser()).privacySettings;

      expect(settings.profileVisibility, ProfileVisibility.agentsOnly);
      expect(settings.hideLastName, false);
    });

    test('an unknown visibility reads as null', () {
      final settings = UserPrivacySettings.fromJson({
        ..._privacy(),
        'profile_visibility': 'friends',
      });

      expect(settings.profileVisibility, isNull);
    });
  });

  group('UserModel helper getters', () {
    UserModel make({
      String? email = 'test@example.com',
      String? fullName,
      String? phone,
      String? dateOfBirth,
      String? profileImageUrl,
      double? currentLatitude,
      double? currentLongitude,
    }) {
      return UserModel(
        id: 1,
        supabaseUserId: 'abc',
        email: email,
        fullName: fullName,
        phone: phone,
        dateOfBirth: dateOfBirth,
        profileImageUrl: profileImageUrl,
        currentLatitude: currentLatitude,
        currentLongitude: currentLongitude,
        isActive: true,
        isVerified: false,
        createdAt: DateTime(2025, 1, 1),
      );
    }

    test('name is empty when the account has none, so the UI shows its own text', () {
      expect(make(fullName: 'Alice').name, 'Alice');
      expect(make().name, isEmpty);
    });

    test('hasLocation requires both coordinates', () {
      expect(make(currentLatitude: 28.0, currentLongitude: 77.0).hasLocation, true);
      expect(make(currentLatitude: 28.0).hasLocation, false);
      expect(make().hasLocation, false);
    });

    test('dateOfBirthAsDate parses valid date string', () {
      final model = make(dateOfBirth: '1990-06-15');
      expect(model.dateOfBirthAsDate, DateTime(1990, 6, 15));
    });

    test('dateOfBirthAsDate returns null for invalid string', () {
      expect(make(dateOfBirth: 'not-a-date').dateOfBirthAsDate, isNull);
      expect(make().dateOfBirthAsDate, isNull);
    });

    test('age returns null when dateOfBirth is null', () {
      expect(make().age, isNull);
    });

    test('age calculates correctly for known birthdate', () {
      // Use a fixed date far in the past for deterministic testing
      final age = make(dateOfBirth: '2000-01-01').age;
      expect(age, isNotNull);
      expect(age!, greaterThanOrEqualTo(25));
    });

    test('profileCompletionPercentage counts filled fields', () {
      // 0 of 5 (email is 'unknown@example.com' default but still non-empty)
      // Actually: email defaults to 'unknown@example.com' which is non-empty → 20%
      expect(make(email: null).profileCompletionPercentage, 0);
      expect(make().profileCompletionPercentage, 20); // email only

      // 3 of 5: email + fullName + phone
      expect(make(fullName: 'Alice', phone: '123').profileCompletionPercentage, 60);

      // 5 of 5: all fields
      expect(
        make(
          fullName: 'Alice',
          phone: '123',
          dateOfBirth: '1990-01-01',
          profileImageUrl: 'http://img.png',
        ).profileCompletionPercentage,
        100,
      );
    });

    test('isProfileComplete requires only fullName and dateOfBirth', () {
      expect(make(fullName: 'Alice', dateOfBirth: '1990-01-01').isProfileComplete, true);
      expect(make(fullName: 'Alice').isProfileComplete, false, reason: 'Missing dateOfBirth');
      expect(make(dateOfBirth: '1990-01-01').isProfileComplete, false, reason: 'Missing fullName');
      expect(
        make(fullName: '', dateOfBirth: '1990-01-01').isProfileComplete,
        false,
        reason: 'Empty fullName',
      );
      expect(
        make(fullName: 'Alice', dateOfBirth: '').isProfileComplete,
        false,
        reason: 'Empty dateOfBirth',
      );
    });

    test('isProfileComplete does not require email', () {
      expect(
        make(email: null, fullName: 'Alice', dateOfBirth: '1990-01-01').isProfileComplete,
        true,
        reason: 'Email should not affect profile completion',
      );
    });

    test('lastLogin returns updatedAt if present, else createdAt', () {
      final base = make();
      expect(base.lastLogin, DateTime(2025, 1, 1));

      final withUpdate = base.copyWith(updatedAt: DateTime(2025, 6, 1));
      expect(withUpdate.lastLogin, DateTime(2025, 6, 1));
    });
  });

  group('UserModel profileCompletionPercentage edge cases', () {
    UserModel make({
      String? email = 'test@example.com',
      String? fullName,
      String? phone,
      String? dateOfBirth,
      String? profileImageUrl,
    }) {
      return UserModel(
        id: 1,
        supabaseUserId: 'abc',
        email: email,
        fullName: fullName,
        phone: phone,
        dateOfBirth: dateOfBirth,
        profileImageUrl: profileImageUrl,
        isActive: true,
        isVerified: false,
        createdAt: DateTime(2025, 1, 1),
      );
    }

    test('returns 0% when all fields are empty', () {
      expect(make(email: null).profileCompletionPercentage, 0);
    });

    test('returns 100% when all 5 fields are filled', () {
      expect(
        make(
          fullName: 'Alice',
          phone: '1234567890',
          dateOfBirth: '1990-01-01',
          profileImageUrl: 'https://example.com/photo.jpg',
        ).profileCompletionPercentage,
        100,
      );
    });

    test('returns correct partial percentages', () {
      // 1 of 5 (email only) = 20%
      expect(make().profileCompletionPercentage, 20);

      // 2 of 5 (email + fullName) = 40%
      expect(make(fullName: 'Alice').profileCompletionPercentage, 40);

      // 3 of 5 (email + fullName + phone) = 60%
      expect(make(fullName: 'Alice', phone: '123').profileCompletionPercentage, 60);

      // 4 of 5 (email + fullName + phone + dob) = 80%
      expect(
        make(
          fullName: 'Alice',
          phone: '123',
          dateOfBirth: '1990-01-01',
        ).profileCompletionPercentage,
        80,
      );
    });
  });

  group('UserModel.copyWith', () {
    test('overrides specified fields and preserves others', () {
      final original = UserModel(
        id: 1,
        supabaseUserId: 'abc',
        email: 'test@example.com',
        fullName: 'John',
        isActive: true,
        isVerified: false,
        createdAt: DateTime(2025, 1, 1),
      );

      final updated = original.copyWith(fullName: 'Jane', isVerified: true);

      expect(updated.fullName, 'Jane');
      expect(updated.isVerified, true);
      expect(updated.id, 1, reason: 'Unchanged fields preserved');
      expect(updated.email, 'test@example.com');
    });
  });
  group('UserModel JSON', () {
    test('round trip keeps the typed objects', () {
      final user = UserModel.fromJson(_selfUser());

      final restored = UserModel.fromJson(user.toJson());

      expect(restored.toJson(), user.toJson());
      expect(restored.preferences.purpose, PropertyPurpose.rent);
      expect(restored.privacySettings.profileVisibility, ProfileVisibility.agentsOnly);
    });

    test('copyWith keeps the typed objects', () {
      final user = UserModel.fromJson(_selfUser());

      final updated = user.copyWith(
        fullName: 'Updated',
        preferences: const UserPreferences(purpose: PropertyPurpose.buy),
      );

      expect(updated.fullName, 'Updated');
      expect(updated.preferences.purpose, PropertyPurpose.buy);
      expect(updated.notificationSettings.pushNotifications, true);
    });
  });
}
