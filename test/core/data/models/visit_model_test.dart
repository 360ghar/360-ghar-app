import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/data/models/visit_model.dart';

void main() {
  group('VisitModel.fromJson', () {
    Map<String, dynamic> baseJson({String? visitDate, String? visitTime, String? scheduledDate}) {
      return {
        'id': 1,
        'property_id': 100,
        'user_id': 50,
        'status': 'requested',
        'created_at': '2025-01-15T10:00:00.000Z',
        ...{'visit_date': visitDate, 'visit_time': visitTime, 'scheduled_date': scheduledDate}
          ..removeWhere((k, v) => v == null),
      };
    }

    test('parses date from visit_date + visit_time', () {
      final model = VisitModel.fromJson(baseJson(visitDate: '2025-03-20', visitTime: '14:30:00'));

      expect(model.scheduledDate.year, 2025);
      expect(model.scheduledDate.month, 3);
      expect(model.scheduledDate.day, 20);
      expect(model.scheduledDate.hour, 14);
      expect(model.scheduledDate.minute, 30);
    });

    test('parses from scheduled_date when visit_date/time missing', () {
      final model = VisitModel.fromJson(baseJson(scheduledDate: '2025-04-10T09:00:00.000Z'));

      expect(model.scheduledDate.year, 2025);
      expect(model.scheduledDate.month, 4);
      expect(model.scheduledDate.day, 10);
      expect(model.scheduledDate.isUtc, true);
    });

    test('prefers scheduled_date when both scheduled_date and visit_date/time exist', () {
      final model = VisitModel.fromJson(
        baseJson(
          visitDate: '2025-03-20',
          visitTime: '14:30:00',
          scheduledDate: '2025-04-10T09:00:00+00:00',
        ),
      );

      expect(model.scheduledDate.toIso8601String(), '2025-04-10T09:00:00.000Z');
    });

    test('falls back to just visit_date when time parse fails', () {
      final model = VisitModel.fromJson(baseJson(visitDate: '2025-05-15', visitTime: 'not-a-time'));

      // Should fall back to parsing just the date
      expect(model.scheduledDate.year, 2025);
      expect(model.scheduledDate.month, 5);
      expect(model.scheduledDate.day, 15);
      expect(model.scheduledDate.isUtc, true);
    });

    test('parses aware scheduled_date values with +00:00 offsets', () {
      final model = VisitModel.fromJson(baseJson(scheduledDate: '2025-04-10T09:00:00+00:00'));

      expect(model.scheduledDate.isUtc, true);
      expect(model.scheduledDate.toIso8601String(), '2025-04-10T09:00:00.000Z');
    });

    test('falls back to DateTime.now when no date fields present', () {
      final before = DateTime.now();
      final model = VisitModel.fromJson(baseJson());
      final after = DateTime.now();

      expect(model.scheduledDate.isAfter(before.subtract(const Duration(seconds: 1))), true);
      expect(model.scheduledDate.isBefore(after.add(const Duration(seconds: 1))), true);
    });

    test('parses all backend status wire values', () {
      const wireToStatus = {
        'requested': VisitStatus.scheduled,
        'confirmed': VisitStatus.confirmed,
        'completed': VisitStatus.completed,
        'cancelled': VisitStatus.cancelled,
        'reschedule_suggested': VisitStatus.rescheduled,
      };
      wireToStatus.forEach((wire, expected) {
        final json = baseJson(scheduledDate: '2025-06-01T10:00:00.000Z');
        json['status'] = wire;
        final model = VisitModel.fromJson(json);
        expect(model.status, expected, reason: 'wire value: $wire');
      });
    });

    test('falls back to scheduled on unknown status values', () {
      final json = baseJson(scheduledDate: '2025-06-01T10:00:00.000Z');
      json['status'] = 'some_future_status';
      final model = VisitModel.fromJson(json);
      expect(model.status, VisitStatus.scheduled);
    });

    test('parses nested agents object with nullable phone', () {
      final json = baseJson(scheduledDate: '2025-06-01T10:00:00.000Z');
      json['agents'] = {'id': 7, 'name': 'Ravi', 'phone': null, 'avatar_url': null};
      final model = VisitModel.fromJson(json);
      expect(model.agents?.name, 'Ravi');
      expect(model.agentName, 'Ravi');
      expect(model.agentPhone, '');
    });

    test('parses optional fields correctly', () {
      final json = baseJson(scheduledDate: '2025-06-01T10:00:00.000Z');
      json['agent_id'] = 5;
      json['special_requirements'] = 'Need parking';
      json['visit_notes'] = 'Checked 2nd floor';
      json['property_title'] = 'My Flat';

      final model = VisitModel.fromJson(json);

      expect(model.agentId, 5);
      expect(model.specialRequirements, 'Need parking');
      expect(model.visitNotes, 'Checked 2nd floor');
      expect(model.propertyTitleApi, 'My Flat');
    });
  });

  group('VisitModel convenience getters', () {
    VisitModel make({
      VisitStatus status = VisitStatus.scheduled,
      DateTime? scheduledDate,
      String? visitNotes,
      String? propertyTitleApi,
      String? agentNameApi,
    }) {
      return VisitModel(
        id: 1,
        propertyId: 100,
        userId: 50,
        scheduledDate: scheduledDate ?? DateTime(2099, 1, 1),
        status: status,
        createdAt: DateTime(2025, 1, 1),
        visitNotes: visitNotes,
        propertyTitleApi: propertyTitleApi,
        agentNameApi: agentNameApi,
      );
    }

    test('propertyTitle falls back through options', () {
      expect(make(propertyTitleApi: 'API Title').propertyTitle, 'API Title');
      expect(make().propertyTitle, 'Property #100');
    });

    test('agentName falls back to Unknown Agent', () {
      expect(make(agentNameApi: 'John').agentName, 'John');
      expect(make().agentName, 'Unknown Agent');
    });

    test('notes returns visitNotes or empty string', () {
      expect(make(visitNotes: 'Some notes').notes, 'Some notes');
      expect(make().notes, '');
    });

    test('isUpcoming requires future date and active status', () {
      expect(
        make(status: VisitStatus.scheduled, scheduledDate: DateTime(2099, 1, 1)).isUpcoming,
        true,
      );
      expect(
        make(status: VisitStatus.confirmed, scheduledDate: DateTime(2099, 1, 1)).isUpcoming,
        true,
      );
      expect(
        make(status: VisitStatus.completed, scheduledDate: DateTime(2099, 1, 1)).isUpcoming,
        false,
        reason: 'Completed visits are not upcoming',
      );
      expect(
        make(status: VisitStatus.cancelled, scheduledDate: DateTime(2099, 1, 1)).isUpcoming,
        false,
        reason: 'Cancelled visits are not upcoming',
      );
      expect(
        make(status: VisitStatus.scheduled, scheduledDate: DateTime(2020, 1, 1)).isUpcoming,
        false,
        reason: 'Past dates are not upcoming',
      );
    });

    test('canReschedule allows scheduled, confirmed, rescheduled', () {
      expect(make(status: VisitStatus.scheduled).canReschedule, true);
      expect(make(status: VisitStatus.confirmed).canReschedule, true);
      expect(make(status: VisitStatus.rescheduled).canReschedule, true);
      expect(make(status: VisitStatus.completed).canReschedule, false);
      expect(make(status: VisitStatus.cancelled).canReschedule, false);
    });

    test('canCancel matches canReschedule logic', () {
      expect(make(status: VisitStatus.scheduled).canCancel, true);
      expect(make(status: VisitStatus.completed).canCancel, false);
      expect(make(status: VisitStatus.cancelled).canCancel, false);
    });

    test('statusStringKey returns translation keys for all statuses', () {
      expect(make(status: VisitStatus.scheduled).statusStringKey, 'visit_status_scheduled');
      expect(make(status: VisitStatus.confirmed).statusStringKey, 'visit_status_confirmed');
      expect(make(status: VisitStatus.completed).statusStringKey, 'visit_status_completed');
      expect(make(status: VisitStatus.cancelled).statusStringKey, 'visit_status_cancelled');
      expect(make(status: VisitStatus.rescheduled).statusStringKey, 'visit_status_rescheduled');
    });

    test('isCompleted is true only for completed status', () {
      expect(make(status: VisitStatus.completed).isCompleted, true);
      expect(make(status: VisitStatus.scheduled).isCompleted, false);
      expect(make(status: VisitStatus.confirmed).isCompleted, false);
      expect(make(status: VisitStatus.cancelled).isCompleted, false);
      expect(make(status: VisitStatus.rescheduled).isCompleted, false);
    });

    test('isCancelled is true only for cancelled status', () {
      expect(make(status: VisitStatus.cancelled).isCancelled, true);
      expect(make(status: VisitStatus.scheduled).isCancelled, false);
      expect(make(status: VisitStatus.confirmed).isCancelled, false);
      expect(make(status: VisitStatus.completed).isCancelled, false);
      expect(make(status: VisitStatus.rescheduled).isCancelled, false);
    });

    test('canReschedule is false for completed and cancelled, true otherwise', () {
      expect(make(status: VisitStatus.scheduled).canReschedule, true);
      expect(make(status: VisitStatus.confirmed).canReschedule, true);
      expect(make(status: VisitStatus.rescheduled).canReschedule, true);
      expect(make(status: VisitStatus.completed).canReschedule, false);
      expect(make(status: VisitStatus.cancelled).canReschedule, false);
    });

    test('canCancel is false for completed and cancelled, true otherwise', () {
      expect(make(status: VisitStatus.scheduled).canCancel, true);
      expect(make(status: VisitStatus.confirmed).canCancel, true);
      expect(make(status: VisitStatus.rescheduled).canCancel, true);
      expect(make(status: VisitStatus.completed).canCancel, false);
      expect(make(status: VisitStatus.cancelled).canCancel, false);
    });
  });

  group('VisitModel.copyWith', () {
    test('preserves all fields when no overrides given', () {
      final original = VisitModel(
        id: 1,
        propertyId: 100,
        userId: 50,
        scheduledDate: DateTime(2025, 6, 1),
        status: VisitStatus.scheduled,
        createdAt: DateTime(2025, 1, 1),
        specialRequirements: 'Need parking',
      );

      final copy = original.copyWith();

      expect(copy.id, original.id);
      expect(copy.propertyId, original.propertyId);
      expect(copy.status, original.status);
      expect(copy.specialRequirements, original.specialRequirements);
    });

    test('overrides specified fields', () {
      final original = VisitModel(
        id: 1,
        propertyId: 100,
        userId: 50,
        scheduledDate: DateTime(2025, 6, 1),
        status: VisitStatus.scheduled,
        createdAt: DateTime(2025, 1, 1),
      );

      final updated = original.copyWith(
        status: VisitStatus.confirmed,
        visitNotes: 'Confirmed by agent',
      );

      expect(updated.status, VisitStatus.confirmed);
      expect(updated.visitNotes, 'Confirmed by agent');
      expect(updated.id, original.id, reason: 'Non-overridden fields preserved');
    });
  });

  group('VisitModel.toJson', () {
    test('serializes all fields correctly', () {
      final model = VisitModel(
        id: 10,
        propertyId: 200,
        userId: 60,
        agentId: 5,
        scheduledDate: DateTime.utc(2025, 6, 1, 10, 0),
        actualDate: DateTime.utc(2025, 6, 1, 11, 0),
        status: VisitStatus.confirmed,
        specialRequirements: 'Wheelchair access',
        visitNotes: 'Great property',
        visitorFeedback: 'Very interested',
        interestLevel: 'high',
        followUpRequired: true,
        followUpDate: DateTime.utc(2025, 6, 5),
        cancellationReason: null,
        rescheduledFrom: DateTime.utc(2025, 5, 28),
        createdAt: DateTime.utc(2025, 1, 1),
        updatedAt: DateTime.utc(2025, 1, 2),
        propertyTitleApi: 'My Flat',
        agentNameApi: 'Agent Smith',
      );

      final json = model.toJson();

      expect(json['id'], 10);
      expect(json['property_id'], 200);
      expect(json['user_id'], 60);
      expect(json['agent_id'], 5);
      expect(json['scheduled_date'], '2025-06-01T10:00:00.000Z');
      expect(json['actual_date'], '2025-06-01T11:00:00.000Z');
      expect(json['status'], 'confirmed');
      expect(json['special_requirements'], 'Wheelchair access');
      expect(json['visit_notes'], 'Great property');
      expect(json['visitor_feedback'], 'Very interested');
      expect(json['interest_level'], 'high');
      expect(json['follow_up_required'], true);
      expect(json['follow_up_date'], '2025-06-05T00:00:00.000Z');
      expect(json['cancellation_reason'], isNull);
      expect(json['rescheduled_from'], '2025-05-28T00:00:00.000Z');
      expect(json['created_at'], '2025-01-01T00:00:00.000Z');
      expect(json['updated_at'], '2025-01-02T00:00:00.000Z');
      expect(json['property_title'], 'My Flat');
      expect(json['agent_name'], 'Agent Smith');
    });

    test('serializes null optional fields as null', () {
      final model = VisitModel(
        id: 1,
        propertyId: 100,
        userId: 50,
        scheduledDate: DateTime.utc(2025, 6, 1),
        status: VisitStatus.scheduled,
        createdAt: DateTime.utc(2025, 1, 1),
      );

      final json = model.toJson();

      expect(json['agent_id'], isNull);
      expect(json['actual_date'], isNull);
      expect(json['special_requirements'], isNull);
      expect(json['visit_notes'], isNull);
      expect(json['visitor_feedback'], isNull);
      expect(json['interest_level'], isNull);
      expect(json['follow_up_required'], false);
      expect(json['follow_up_date'], isNull);
      expect(json['cancellation_reason'], isNull);
      expect(json['rescheduled_from'], isNull);
      expect(json['updated_at'], isNull);
      expect(json['property'], isNull);
      expect(json['agents'], isNull);
      expect(json['property_title'], isNull);
      expect(json['agent_name'], isNull);
    });

    test('serializes all status enum values to wire format', () {
      const statusToWire = {
        VisitStatus.scheduled: 'requested',
        VisitStatus.confirmed: 'confirmed',
        VisitStatus.completed: 'completed',
        VisitStatus.cancelled: 'cancelled',
        VisitStatus.rescheduled: 'reschedule_suggested',
      };

      statusToWire.forEach((status, wire) {
        final model = VisitModel(
          id: 1,
          propertyId: 100,
          userId: 50,
          scheduledDate: DateTime.utc(2025, 6, 1),
          status: status,
          createdAt: DateTime.utc(2025, 1, 1),
        );
        expect(model.toJson()['status'], wire, reason: 'status: $status');
      });
    });

    test('round-trip toJson then fromJson preserves data', () {
      final original = VisitModel(
        id: 42,
        propertyId: 300,
        userId: 70,
        agentId: 8,
        scheduledDate: DateTime.utc(2025, 7, 15, 14, 30),
        status: VisitStatus.completed,
        specialRequirements: 'Parking',
        visitNotes: 'Went well',
        followUpRequired: true,
        createdAt: DateTime.utc(2025, 1, 10),
        updatedAt: DateTime.utc(2025, 1, 12),
        propertyTitleApi: 'Test Property',
        agentNameApi: 'Test Agent',
      );

      final json = original.toJson();
      // fromJson needs scheduled_date which toJson provides
      final restored = VisitModel.fromJson(json);

      expect(restored.id, 42);
      expect(restored.propertyId, 300);
      expect(restored.userId, 70);
      expect(restored.agentId, 8);
      expect(restored.status, VisitStatus.completed);
      expect(restored.specialRequirements, 'Parking');
      expect(restored.visitNotes, 'Went well');
      expect(restored.followUpRequired, isTrue);
      expect(restored.propertyTitleApi, 'Test Property');
      expect(restored.agentNameApi, 'Test Agent');
    });
  });

  group('VisitAgentInfo', () {
    test('fromJson parses all fields', () {
      final json = {
        'id': 5,
        'name': 'Ravi Kumar',
        'phone': '+919876543210',
        'avatar_url': 'https://example.com/avatar.jpg',
      };

      final agent = VisitAgentInfo.fromJson(json);

      expect(agent.id, 5);
      expect(agent.name, 'Ravi Kumar');
      expect(agent.phone, '+919876543210');
      expect(agent.avatarUrl, 'https://example.com/avatar.jpg');
    });

    test('fromJson handles null optional fields', () {
      final json = {'id': 3, 'name': 'Jane'};

      final agent = VisitAgentInfo.fromJson(json);

      expect(agent.id, 3);
      expect(agent.name, 'Jane');
      expect(agent.phone, isNull);
      expect(agent.avatarUrl, isNull);
    });

    test('toJson serializes all fields', () {
      const agent = VisitAgentInfo(
        id: 7,
        name: 'Test Agent',
        phone: '+1234567890',
        avatarUrl: 'https://example.com/pic.png',
      );

      final json = agent.toJson();

      expect(json['id'], 7);
      expect(json['name'], 'Test Agent');
      expect(json['phone'], '+1234567890');
      expect(json['avatar_url'], 'https://example.com/pic.png');
    });

    test('toJson handles null optional fields', () {
      const agent = VisitAgentInfo(id: 1, name: 'NoPhone');

      final json = agent.toJson();

      expect(json['id'], 1);
      expect(json['name'], 'NoPhone');
      expect(json['phone'], isNull);
      expect(json['avatar_url'], isNull);
    });

    test('round-trip fromJson then toJson preserves data', () {
      final json = {
        'id': 10,
        'name': 'Round Trip',
        'phone': '+999',
        'avatar_url': 'https://example.com/rt.jpg',
      };

      final agent = VisitAgentInfo.fromJson(json);
      final restored = agent.toJson();

      expect(restored, json);
    });
  });
}
