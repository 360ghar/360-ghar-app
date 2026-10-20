import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/data/models/agent_model.dart';

void main() {
  group('AgentModel.fromJson', () {
    test('parses full JSON correctly', () {
      final json = <String, dynamic>{
        'id': 1,
        'name': 'Ravi Kumar',
        'description': 'Expert in residential properties',
        'avatar_url': 'https://example.com/avatar.jpg',
        'contact_number': '+91-9876543210',
        'languages': ['English', 'Hindi', 'Tamil'],
        'agent_type': 'specialist',
        'experience_level': 'expert',
        'is_active': true,
        'is_available': true,
        'working_hours': {'mon': '9-5', 'tue': '9-5'},
        'total_users_assigned': 42,
        'user_satisfaction_rating': 4.8,
        'created_at': '2024-06-01T10:00:00.000Z',
        'updated_at': '2025-01-15T12:00:00.000Z',
      };

      final model = AgentModel.fromJson(json);

      expect(model.id, 1);
      expect(model.name, 'Ravi Kumar');
      expect(model.description, 'Expert in residential properties');
      expect(model.avatarUrl, 'https://example.com/avatar.jpg');
      expect(model.contactNumber, '+91-9876543210');
      expect(model.languages, ['English', 'Hindi', 'Tamil']);
      expect(model.agentType, AgentType.specialist);
      expect(model.experienceLevel, ExperienceLevel.expert);
      expect(model.isActive, true);
      expect(model.isAvailable, true);
      expect(model.workingHours, {'mon': '9-5', 'tue': '9-5'});
      expect(model.totalUsersAssigned, 42);
      expect(model.userSatisfactionRating, 4.8);
      expect(model.createdAt, DateTime.parse('2024-06-01T10:00:00.000Z'));
      expect(model.updatedAt, DateTime.parse('2025-01-15T12:00:00.000Z'));
    });

    test('optional keys that are absent read as null', () {
      final json = <String, dynamic>{
        'id': 2,
        'name': 'Priya',
        'agent_type': 'general',
        'experience_level': 'beginner',
        'is_active': true,
        'is_available': false,
        'total_users_assigned': 0,
        'user_satisfaction_rating': 0,
        'created_at': '2024-01-01T00:00:00.000Z',
      };

      final model = AgentModel.fromJson(json);

      expect(model.description, isNull);
      expect(model.avatarUrl, isNull);
      expect(model.contactNumber, isNull);
      expect(model.languages, isNull);
      expect(model.isAvailable, false);
      expect(model.workingHours, isNull);
      expect(model.userSatisfactionRating, 0.0);
      expect(model.updatedAt, isNull);
    });

    test('a key the backend always sends is required', () {
      const required = [
        'id',
        'name',
        'agent_type',
        'experience_level',
        'is_active',
        'is_available',
        'total_users_assigned',
        'user_satisfaction_rating',
        'created_at',
      ];
      final full = <String, dynamic>{
        'id': 2,
        'name': 'Priya',
        'agent_type': 'general',
        'experience_level': 'beginner',
        'is_active': true,
        'is_available': true,
        'total_users_assigned': 1,
        'user_satisfaction_rating': 4.5,
        'created_at': '2024-01-01T00:00:00.000Z',
      };
      for (final key in required) {
        final body = {...full}..remove(key);
        expect(() => AgentModel.fromJson(body), throwsA(anything), reason: 'missing $key');
      }
    });

    test('reads an unrecognized enum value as null', () {
      final json = <String, dynamic>{
        'id': 3,
        'name': 'Test Agent',
        'agent_type': 'future_type',
        'experience_level': 'super_expert',
        'is_active': true,
        'is_available': true,
        'total_users_assigned': 0,
        'user_satisfaction_rating': 1,
        'created_at': '2024-01-01T00:00:00.000Z',
      };

      final model = AgentModel.fromJson(json);

      expect(model.agentType, isNull);
      expect(model.experienceLevel, isNull);
    });
  });

  group('AgentModel convenience getters', () {
    AgentModel make({
      AgentType? agentType = AgentType.general,
      ExperienceLevel? experienceLevel = ExperienceLevel.beginner,
      List<String>? languages,
      Map<String, dynamic>? workingHours,
    }) {
      return AgentModel(
        id: 1,
        name: 'Test Agent',
        agentType: agentType,
        experienceLevel: experienceLevel,
        languages: languages,
        workingHours: workingHours,
        createdAt: DateTime(2024, 1, 1),
      );
    }

    test('agentTypeString maps all enum values', () {
      expect(make(agentType: AgentType.general).agentTypeString, 'General');
      expect(make(agentType: AgentType.specialist).agentTypeString, 'Specialist');
      expect(make(agentType: AgentType.senior).agentTypeString, 'Senior');
      expect(make(agentType: null).agentTypeString, isNull);
    });

    test('experienceLevelString maps all enum values', () {
      expect(make(experienceLevel: ExperienceLevel.beginner).experienceLevelString, 'Beginner');
      expect(
        make(experienceLevel: ExperienceLevel.intermediate).experienceLevelString,
        'Intermediate',
      );
      expect(make(experienceLevel: ExperienceLevel.expert).experienceLevelString, 'Expert');
      expect(make(experienceLevel: null).experienceLevelString, isNull);
    });

    test('languagesDisplay joins languages or shows fallback', () {
      expect(make(languages: ['English', 'Hindi']).languagesDisplay, 'English, Hindi');
      expect(make(languages: ['Tamil']).languagesDisplay, 'Tamil');
      expect(make(languages: []).languagesDisplay, '', reason: 'Empty list joins to empty string');
      expect(make().languagesDisplay, 'Not specified');
    });

    test('hasWorkingHours checks for non-null non-empty map', () {
      expect(make(workingHours: {'mon': '9-5'}).hasWorkingHours, true);
      expect(make(workingHours: {}).hasWorkingHours, false);
      expect(make().hasWorkingHours, false);
    });
  });

  group('AgentModel.toJson roundtrip', () {
    test('roundtrip preserves all fields', () {
      final original = AgentModel.fromJson({
        'id': 10,
        'name': 'Roundtrip Agent',
        'description': 'Test agent',
        'avatar_url': 'https://example.com/a.jpg',
        'contact_number': '9999999999',
        'languages': ['English'],
        'agent_type': 'senior',
        'experience_level': 'intermediate',
        'is_active': false,
        'is_available': true,
        'working_hours': {'fri': '10-6'},
        'total_users_assigned': 15,
        'user_satisfaction_rating': 4.5,
        'created_at': '2024-03-15T08:30:00.000Z',
        'updated_at': '2024-12-01T14:00:00.000Z',
      });

      final json = original.toJson();
      final restored = AgentModel.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.description, original.description);
      expect(restored.avatarUrl, original.avatarUrl);
      expect(restored.contactNumber, original.contactNumber);
      expect(restored.languages, original.languages);
      expect(restored.agentType, original.agentType);
      expect(restored.experienceLevel, original.experienceLevel);
      expect(restored.isActive, original.isActive);
      expect(restored.isAvailable, original.isAvailable);
      expect(restored.totalUsersAssigned, original.totalUsersAssigned);
      expect(restored.userSatisfactionRating, original.userSatisfactionRating);
    });
  });
}
