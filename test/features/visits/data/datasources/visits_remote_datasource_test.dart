import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/data/models/agent_model.dart';
import 'package:ghar360/core/data/models/visit_model.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/network/api_paths.dart';
import 'package:ghar360/features/visits/data/datasources/visits_remote_datasource.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/mocks.dart';

void main() {
  late MockApiClient apiClient;
  late VisitsRemoteDatasource datasource;

  setUp(() {
    apiClient = MockApiClient();
    datasource = VisitsRemoteDatasource(apiClient);
  });

  /// Builds a minimal visit JSON map matching the backend wire format.
  Map<String, dynamic> visitJson({
    int id = 1,
    int propertyId = 100,
    int userId = 50,
    String status = 'requested',
  }) {
    return {
      'id': id,
      'property_id': propertyId,
      'user_id': userId,
      'status': status,
      'scheduled_date': '2025-06-01T10:00:00.000Z',
      'created_at': '2025-01-15T10:00:00.000Z',
    };
  }

  /// Builds a minimal agent JSON map.
  Map<String, dynamic> agentJson({int id = 7}) {
    return {
      'id': id,
      'name': 'Ravi Kumar',
      'agent_type': 'general',
      'experience_level': 'intermediate',
      'is_active': true,
      'is_available': true,
      'created_at': '2024-01-01T00:00:00.000Z',
    };
  }

  group('VisitsRemoteDatasource.fetchVisitsSummary', () {
    test('parses visits list from data-wrapped envelope', () async {
      when(() => apiClient.get(any(), queryParams: any(named: 'queryParams'), useCache: any(named: 'useCache')))
          .thenAnswer((_) async => ApiResponse(
                statusCode: 200,
                body: {
                  'data': [visitJson(id: 1), visitJson(id: 2)],
                  'has_more': true,
                  'next_cursor': 'cursor-abc',
                },
                headers: const {},
              ));

      final payload = await datasource.fetchVisitsSummary();

      expect(payload.visits.length, 2);
      expect(payload.visits[0].id, 1);
      expect(payload.visits[1].id, 2);
      expect(payload.hasMore, isTrue);
      expect(payload.nextCursor, 'cursor-abc');
    });

    test('parses visits list from items envelope', () async {
      when(() => apiClient.get(any(), queryParams: any(named: 'queryParams'), useCache: any(named: 'useCache')))
          .thenAnswer((_) async => ApiResponse(
                statusCode: 200,
                body: {
                  'items': [visitJson(id: 5)],
                  'has_more': false,
                },
                headers: const {},
              ));

      final payload = await datasource.fetchVisitsSummary();

      expect(payload.visits.length, 1);
      expect(payload.visits[0].id, 5);
      expect(payload.hasMore, isFalse);
      expect(payload.nextCursor, isNull);
    });

    test('parses visits list from visits fallback key', () async {
      when(() => apiClient.get(any(), queryParams: any(named: 'queryParams'), useCache: any(named: 'useCache')))
          .thenAnswer((_) async => ApiResponse(
                statusCode: 200,
                body: {
                  'visits': [visitJson(id: 9)],
                },
                headers: const {},
              ));

      final payload = await datasource.fetchVisitsSummary();

      expect(payload.visits.length, 1);
      expect(payload.visits[0].id, 9);
    });

    test('includes cursor query param when provided', () async {
      Map<String, dynamic>? capturedQuery;
      when(() => apiClient.get(any(), queryParams: any(named: 'queryParams'), useCache: any(named: 'useCache')))
          .thenAnswer((invocation) async {
        capturedQuery = invocation.namedArguments[#queryParams] as Map<String, dynamic>?;
        return ApiResponse(
          statusCode: 200,
          body: {'items': <dynamic>[]},
          headers: const {},
        );
      });

      await datasource.fetchVisitsSummary(cursor: 'next-page');

      expect(capturedQuery!['cursor'], 'next-page');
      expect(capturedQuery!['limit'], '50');
    });

    test('omits cursor query param when null', () async {
      Map<String, dynamic>? capturedQuery;
      when(() => apiClient.get(any(), queryParams: any(named: 'queryParams'), useCache: any(named: 'useCache')))
          .thenAnswer((invocation) async {
        capturedQuery = invocation.namedArguments[#queryParams] as Map<String, dynamic>?;
        return ApiResponse(
          statusCode: 200,
          body: {'items': <dynamic>[]},
          headers: const {},
        );
      });

      await datasource.fetchVisitsSummary();

      expect(capturedQuery!.containsKey('cursor'), isFalse);
    });

    test('omits cursor query param when empty string', () async {
      Map<String, dynamic>? capturedQuery;
      when(() => apiClient.get(any(), queryParams: any(named: 'queryParams'), useCache: any(named: 'useCache')))
          .thenAnswer((invocation) async {
        capturedQuery = invocation.namedArguments[#queryParams] as Map<String, dynamic>?;
        return ApiResponse(
          statusCode: 200,
          body: {'items': <dynamic>[]},
          headers: const {},
        );
      });

      await datasource.fetchVisitsSummary(cursor: '');

      expect(capturedQuery!.containsKey('cursor'), isFalse);
    });

    test('uses custom limit value', () async {
      Map<String, dynamic>? capturedQuery;
      when(() => apiClient.get(any(), queryParams: any(named: 'queryParams'), useCache: any(named: 'useCache')))
          .thenAnswer((invocation) async {
        capturedQuery = invocation.namedArguments[#queryParams] as Map<String, dynamic>?;
        return ApiResponse(
          statusCode: 200,
          body: {'items': <dynamic>[]},
          headers: const {},
        );
      });

      await datasource.fetchVisitsSummary(limit: 10);

      expect(capturedQuery!['limit'], '10');
    });

    test('passes useCache false to apiClient', () async {
      bool? capturedUseCache;
      when(() => apiClient.get(any(), queryParams: any(named: 'queryParams'), useCache: any(named: 'useCache')))
          .thenAnswer((invocation) async {
        capturedUseCache = invocation.namedArguments[#useCache] as bool;
        return ApiResponse(
          statusCode: 200,
          body: {'items': <dynamic>[]},
          headers: const {},
        );
      });

      await datasource.fetchVisitsSummary();

      expect(capturedUseCache, isFalse);
    });

    test('uses ApiPaths.visits endpoint', () async {
      String? capturedEndpoint;
      when(() => apiClient.get(any(), queryParams: any(named: 'queryParams'), useCache: any(named: 'useCache')))
          .thenAnswer((invocation) async {
        capturedEndpoint = invocation.positionalArguments[0] as String;
        return ApiResponse(
          statusCode: 200,
          body: {'items': <dynamic>[]},
          headers: const {},
        );
      });

      await datasource.fetchVisitsSummary();

      expect(capturedEndpoint, ApiPaths.visits);
    });

    test('returns empty visits for empty items list', () async {
      when(() => apiClient.get(any(), queryParams: any(named: 'queryParams'), useCache: any(named: 'useCache')))
          .thenAnswer((_) async => ApiResponse(
                statusCode: 200,
                body: {'items': <dynamic>[]},
                headers: const {},
              ));

      final payload = await datasource.fetchVisitsSummary();

      expect(payload.visits, isEmpty);
      expect(payload.hasMore, isFalse);
    });

    test('rethrows on parse failure (invalid body type)', () async {
      when(() => apiClient.get(any(), queryParams: any(named: 'queryParams'), useCache: any(named: 'useCache')))
          .thenAnswer((_) async => ApiResponse(
                statusCode: 200,
                body: 'not a map',
                headers: const {},
              ));

      await expectLater(
        datasource.fetchVisitsSummary(),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('VisitsRemoteDatasource.scheduleVisit', () {
    test('returns parsed VisitModel from data-wrapped response', () async {
      when(() => apiClient.post(any(), body: any(named: 'body'), idempotent: any(named: 'idempotent')))
          .thenAnswer((_) async => ApiResponse(
                statusCode: 201,
                body: {'data': visitJson(id: 42, status: 'confirmed')},
                headers: const {},
              ));

      final visit = await datasource.scheduleVisit(
        propertyId: 100,
        scheduledDate: '2025-06-01T10:00:00.000Z',
      );

      expect(visit.id, 42);
      expect(visit.status, VisitStatus.confirmed);
    });

    test('returns parsed VisitModel from unwrapped response', () async {
      when(() => apiClient.post(any(), body: any(named: 'body'), idempotent: any(named: 'idempotent')))
          .thenAnswer((_) async => ApiResponse(
                statusCode: 201,
                body: visitJson(id: 77),
                headers: const {},
              ));

      final visit = await datasource.scheduleVisit(
        propertyId: 100,
        scheduledDate: '2025-06-01T10:00:00.000Z',
      );

      expect(visit.id, 77);
    });

    test('sends correct body with property_id and scheduled_date', () async {
      Map<String, dynamic>? capturedBody;
      when(() => apiClient.post(any(), body: any(named: 'body'), idempotent: any(named: 'idempotent')))
          .thenAnswer((invocation) async {
        capturedBody = invocation.namedArguments[#body] as Map<String, dynamic>?;
        return ApiResponse(
          statusCode: 201,
          body: visitJson(),
          headers: const {},
        );
      });

      await datasource.scheduleVisit(
        propertyId: 55,
        scheduledDate: '2025-07-01T14:00:00.000Z',
        specialRequirements: 'Need parking',
      );

      expect(capturedBody!['property_id'], 55);
      expect(capturedBody!['scheduled_date'], '2025-07-01T14:00:00.000Z');
      expect(capturedBody!['special_requirements'], 'Need parking');
    });

    test('defaults special_requirements to empty string when null', () async {
      Map<String, dynamic>? capturedBody;
      when(() => apiClient.post(any(), body: any(named: 'body'), idempotent: any(named: 'idempotent')))
          .thenAnswer((invocation) async {
        capturedBody = invocation.namedArguments[#body] as Map<String, dynamic>?;
        return ApiResponse(
          statusCode: 201,
          body: visitJson(),
          headers: const {},
        );
      });

      await datasource.scheduleVisit(
        propertyId: 55,
        scheduledDate: '2025-07-01T14:00:00.000Z',
      );

      expect(capturedBody!['special_requirements'], '');
    });

    test('passes idempotent true to apiClient', () async {
      bool? capturedIdempotent;
      when(() => apiClient.post(any(), body: any(named: 'body'), idempotent: any(named: 'idempotent')))
          .thenAnswer((invocation) async {
        capturedIdempotent = invocation.namedArguments[#idempotent] as bool;
        return ApiResponse(
          statusCode: 201,
          body: visitJson(),
          headers: const {},
        );
      });

      await datasource.scheduleVisit(
        propertyId: 55,
        scheduledDate: '2025-07-01T14:00:00.000Z',
      );

      expect(capturedIdempotent, isTrue);
    });

    test('throws FormatException on empty response object', () async {
      when(() => apiClient.post(any(), body: any(named: 'body'), idempotent: any(named: 'idempotent')))
          .thenAnswer((_) async => ApiResponse(
                statusCode: 201,
                body: <String, dynamic>{},
                headers: const {},
              ));

      await expectLater(
        datasource.scheduleVisit(propertyId: 1, scheduledDate: '2025-01-01'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('VisitsRemoteDatasource.cancelVisit', () {
    test('returns true when body has success=true', () async {
      when(() => apiClient.post(any(), body: any(named: 'body'), idempotent: any(named: 'idempotent')))
          .thenAnswer((_) async => ApiResponse(
                statusCode: 200,
                body: {'success': true},
                headers: const {},
              ));

      final result = await datasource.cancelVisit(5, reason: 'Not interested');

      expect(result, isTrue);
    });

    test('returns true when status code is 200 even without success field', () async {
      when(() => apiClient.post(any(), body: any(named: 'body'), idempotent: any(named: 'idempotent')))
          .thenAnswer((_) async => ApiResponse(
                statusCode: 200,
                body: {'message': 'cancelled'},
                headers: const {},
              ));

      final result = await datasource.cancelVisit(5, reason: 'Not interested');

      expect(result, isTrue);
    });

    test('returns true when body is not a Map and status is 200', () async {
      when(() => apiClient.post(any(), body: any(named: 'body'), idempotent: any(named: 'idempotent')))
          .thenAnswer((_) async => ApiResponse(
                statusCode: 200,
                body: 'ok',
                headers: const {},
              ));

      final result = await datasource.cancelVisit(5, reason: 'Not interested');

      expect(result, isTrue);
    });

    test('sends reason in body', () async {
      Map<String, dynamic>? capturedBody;
      when(() => apiClient.post(any(), body: any(named: 'body'), idempotent: any(named: 'idempotent')))
          .thenAnswer((invocation) async {
        capturedBody = invocation.namedArguments[#body] as Map<String, dynamic>?;
        return ApiResponse(
          statusCode: 200,
          body: {'success': true},
          headers: const {},
        );
      });

      await datasource.cancelVisit(9, reason: 'Schedule conflict');

      expect(capturedBody!['reason'], 'Schedule conflict');
    });

    test('uses visitCancel endpoint with visit id', () async {
      String? capturedEndpoint;
      when(() => apiClient.post(any(), body: any(named: 'body'), idempotent: any(named: 'idempotent')))
          .thenAnswer((invocation) async {
        capturedEndpoint = invocation.positionalArguments[0] as String;
        return ApiResponse(
          statusCode: 200,
          body: {'success': true},
          headers: const {},
        );
      });

      await datasource.cancelVisit(12, reason: 'test');

      expect(capturedEndpoint, ApiPaths.visitCancel(12));
    });
  });

  group('VisitsRemoteDatasource.rescheduleVisit', () {
    test('returns true when body has success=true', () async {
      when(() => apiClient.post(any(), body: any(named: 'body'), idempotent: any(named: 'idempotent')))
          .thenAnswer((_) async => ApiResponse(
                statusCode: 200,
                body: {'success': true},
                headers: const {},
              ));

      final result = await datasource.rescheduleVisit(5, newDate: '2025-08-01T10:00:00.000Z');

      expect(result, isTrue);
    });

    test('returns true when status code is 200 without success field', () async {
      when(() => apiClient.post(any(), body: any(named: 'body'), idempotent: any(named: 'idempotent')))
          .thenAnswer((_) async => ApiResponse(
                statusCode: 200,
                body: {'message': 'rescheduled'},
                headers: const {},
              ));

      final result = await datasource.rescheduleVisit(5, newDate: '2025-08-01T10:00:00.000Z');

      expect(result, isTrue);
    });

    test('sends new_date and reason in body', () async {
      Map<String, dynamic>? capturedBody;
      when(() => apiClient.post(any(), body: any(named: 'body'), idempotent: any(named: 'idempotent')))
          .thenAnswer((invocation) async {
        capturedBody = invocation.namedArguments[#body] as Map<String, dynamic>?;
        return ApiResponse(
          statusCode: 200,
          body: {'success': true},
          headers: const {},
        );
      });

      await datasource.rescheduleVisit(7, newDate: '2025-09-01T10:00:00.000Z', reason: 'Time change');

      expect(capturedBody!['new_date'], '2025-09-01T10:00:00.000Z');
      expect(capturedBody!['reason'], 'Time change');
    });

    test('defaults reason to empty string when null', () async {
      Map<String, dynamic>? capturedBody;
      when(() => apiClient.post(any(), body: any(named: 'body'), idempotent: any(named: 'idempotent')))
          .thenAnswer((invocation) async {
        capturedBody = invocation.namedArguments[#body] as Map<String, dynamic>?;
        return ApiResponse(
          statusCode: 200,
          body: {'success': true},
          headers: const {},
        );
      });

      await datasource.rescheduleVisit(7, newDate: '2025-09-01T10:00:00.000Z');

      expect(capturedBody!['reason'], '');
    });

    test('uses visitReschedule endpoint with visit id', () async {
      String? capturedEndpoint;
      when(() => apiClient.post(any(), body: any(named: 'body'), idempotent: any(named: 'idempotent')))
          .thenAnswer((invocation) async {
        capturedEndpoint = invocation.positionalArguments[0] as String;
        return ApiResponse(
          statusCode: 200,
          body: {'success': true},
          headers: const {},
        );
      });

      await datasource.rescheduleVisit(15, newDate: '2025-08-01');

      expect(capturedEndpoint, ApiPaths.visitReschedule(15));
    });

    test('returns true when body is not a Map and status is 200', () async {
      when(() => apiClient.post(any(), body: any(named: 'body'), idempotent: any(named: 'idempotent')))
          .thenAnswer((_) async => ApiResponse(
                statusCode: 200,
                body: 42,
                headers: const {},
              ));

      final result = await datasource.rescheduleVisit(5, newDate: '2025-08-01');

      expect(result, isTrue);
    });
  });

  group('VisitsRemoteDatasource.fetchRelationshipManager', () {
    test('returns parsed AgentModel from data-wrapped response', () async {
      when(() => apiClient.get(any(), useCache: any(named: 'useCache')))
          .thenAnswer((_) async => ApiResponse(
                statusCode: 200,
                body: {'data': agentJson(id: 3)},
                headers: const {},
              ));

      final agent = await datasource.fetchRelationshipManager();

      expect(agent.id, 3);
      expect(agent.name, 'Ravi Kumar');
      expect(agent.agentType, AgentType.general);
    });

    test('returns parsed AgentModel from unwrapped response', () async {
      when(() => apiClient.get(any(), useCache: any(named: 'useCache')))
          .thenAnswer((_) async => ApiResponse(
                statusCode: 200,
                body: agentJson(id: 8),
                headers: const {},
              ));

      final agent = await datasource.fetchRelationshipManager();

      expect(agent.id, 8);
    });

    test('uses agentsAssigned endpoint', () async {
      String? capturedEndpoint;
      when(() => apiClient.get(any(), useCache: any(named: 'useCache')))
          .thenAnswer((invocation) async {
        capturedEndpoint = invocation.positionalArguments[0] as String;
        return ApiResponse(
          statusCode: 200,
          body: agentJson(),
          headers: const {},
        );
      });

      await datasource.fetchRelationshipManager();

      expect(capturedEndpoint, ApiPaths.agentsAssigned);
    });

    test('passes useCache false to apiClient', () async {
      bool? capturedUseCache;
      when(() => apiClient.get(any(), useCache: any(named: 'useCache')))
          .thenAnswer((invocation) async {
        capturedUseCache = invocation.namedArguments[#useCache] as bool;
        return ApiResponse(
          statusCode: 200,
          body: agentJson(),
          headers: const {},
        );
      });

      await datasource.fetchRelationshipManager();

      expect(capturedUseCache, isFalse);
    });
  });

  group('VisitsPayload', () {
    test('constructor stores values correctly', () {
      const payload = VisitsPayload(
        visits: [],
        hasMore: true,
        nextCursor: 'abc',
      );

      expect(payload.visits, isEmpty);
      expect(payload.hasMore, isTrue);
      expect(payload.nextCursor, 'abc');
    });

    test('nextCursor defaults to null', () {
      const payload = VisitsPayload(visits: [], hasMore: false);

      expect(payload.nextCursor, isNull);
    });
  });
}
