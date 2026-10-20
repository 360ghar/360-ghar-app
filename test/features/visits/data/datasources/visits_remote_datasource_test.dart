import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/data/models/agent_model.dart';
import 'package:ghar360/core/data/models/visit_model.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/network/api_paths.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/visits/data/datasources/visits_remote_datasource.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/api_fixtures.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MockApiClient apiClient;
  late VisitsRemoteDatasource datasource;

  setUp(() {
    apiClient = MockApiClient();
    datasource = VisitsRemoteDatasource(apiClient);
  });

  final visits = asObject(apiFixture('visits'));
  Map<String, dynamic> visit([Map<String, dynamic> overrides = const {}]) => {
    ...asObject(visits['created']),
    ...overrides,
  };
  Map<String, dynamic> page({
    List<Map<String, dynamic>>? items,
    bool hasMore = false,
    String? nextCursor,
  }) => {
    'items': items ?? [visit()],
    'next_cursor': nextCursor,
    'has_more': hasMore,
    'limit': 50,
    'total': null,
  };
  Map<String, dynamic> agent([Map<String, dynamic> overrides = const {}]) => {
    ...asObject(apiFixture('agents')['assigned']),
    ...overrides,
  };

  void stubGet(Object? body) {
    when(
      () => apiClient.get(
        any(),
        queryParams: any(named: 'queryParams'),
        useCache: any(named: 'useCache'),
      ),
    ).thenAnswer((_) async => ApiResponse(statusCode: 200, body: body, headers: const {}));
  }

  void stubPost(Object? body, {int statusCode = 200}) {
    when(
      () => apiClient.post(
        any(),
        body: any(named: 'body'),
        idempotent: any(named: 'idempotent'),
      ),
    ).thenAnswer((_) async => ApiResponse(statusCode: statusCode, body: body, headers: const {}));
  }

  Map<String, dynamic> postedBody() =>
      verify(
            () => apiClient.post(
              any(),
              body: captureAny(named: 'body'),
              idempotent: any(named: 'idempotent'),
            ),
          ).captured.single
          as Map<String, dynamic>;

  Map<String, dynamic> queryOfGet() =>
      verify(
            () => apiClient.get(
              any(),
              queryParams: captureAny(named: 'queryParams'),
              useCache: any(named: 'useCache'),
            ),
          ).captured.single
          as Map<String, dynamic>;

  group('fetchVisitsSummary', () {
    test('reads the CursorPage of visits with its paging keys', () async {
      stubGet(
        page(
          items: [
            visit({'id': 1}),
            visit({'id': 2}),
          ],
          hasMore: true,
          nextCursor: 'cursor-abc',
        ),
      );

      final payload = await datasource.fetchVisitsSummary();

      expect(payload.visits.map((v) => v.id), [1, 2]);
      expect(payload.hasMore, isTrue);
      expect(payload.nextCursor, 'cursor-abc');
    });

    test('the recorded list fixture parses, counterparty included', () async {
      stubGet(visits['list_page']);

      final payload = await datasource.fetchVisitsSummary();

      expect(payload.visits, isNotEmpty);
      expect(payload.visits.first.counterpartyUser?.displayName, 'Karan Mehta');
    });

    test('a last page has no cursor', () async {
      stubGet(page());

      final payload = await datasource.fetchVisitsSummary();

      expect(payload.hasMore, isFalse);
      expect(payload.nextCursor, isNull);
    });

    test('sends the cursor and the limit', () async {
      stubGet(page());

      await datasource.fetchVisitsSummary(cursor: 'next-page', limit: 10);

      final query = queryOfGet();
      expect(query['cursor'], 'next-page');
      expect(query['limit'], '10');
    });

    test('omits the cursor on the first page, null or empty', () async {
      stubGet(page());

      await datasource.fetchVisitsSummary();
      await datasource.fetchVisitsSummary(cursor: '');

      for (final query in verify(
        () => apiClient.get(
          any(),
          queryParams: captureAny(named: 'queryParams'),
          useCache: any(named: 'useCache'),
        ),
      ).captured) {
        expect((query as Map).containsKey('cursor'), isFalse);
      }
    });

    test('the limit stays between 1 and 100', () async {
      stubGet(page());

      await datasource.fetchVisitsSummary(limit: 500);

      expect(queryOfGet()['limit'], '100');
    });

    test('reads from the visits route and skips the cache', () async {
      stubGet(page());

      await datasource.fetchVisitsSummary();

      verify(
        () =>
            apiClient.get(ApiPaths.visits, queryParams: any(named: 'queryParams'), useCache: false),
      ).called(1);
    });

    for (final entry in <String, Object?>{
      'a bare string': 'not a map',
      'a bare list': [visit()],
      'a data envelope': {'data': page()},
      'the visits key': {
        'visits': [visit()],
      },
      'a page with no next_cursor': page()..remove('next_cursor'),
      'a row that is not a visit': {
        ...page(),
        'items': [visit(), 'x'],
      },
      'a visit with no id': page(items: [visit()..remove('id')]),
    }.entries) {
      test('${entry.key} is a malformed response', () async {
        stubGet(entry.value);

        await expectLater(
          datasource.fetchVisitsSummary(),
          throwsA(isA<ApiException>().having((e) => e.code, 'code', 'MALFORMED_RESPONSE')),
        );
      });
    }
  });

  group('scheduleVisit', () {
    test('reads the Visit of a 201', () async {
      stubPost(visit({'id': 42, 'status': 'confirmed'}), statusCode: 201);

      final created = await datasource.scheduleVisit(
        propertyId: 100,
        scheduledDate: '2026-10-01T10:00:00Z',
      );

      expect(created.id, 42);
      expect(created.status, VisitStatus.confirmed);
    });

    test(
      'sends property_id and scheduled_date, and the requirements when there are some',
      () async {
        stubPost(visit(), statusCode: 201);

        await datasource.scheduleVisit(
          propertyId: 55,
          scheduledDate: '2026-10-01T14:00:00Z',
          specialRequirements: '  Need parking  ',
        );

        expect(postedBody(), {
          'property_id': 55,
          'scheduled_date': '2026-10-01T14:00:00Z',
          'special_requirements': 'Need parking',
        });
      },
    );

    test('omits special_requirements when there are none', () async {
      stubPost(visit(), statusCode: 201);

      await datasource.scheduleVisit(
        propertyId: 55,
        scheduledDate: '2026-10-01T14:00:00Z',
        specialRequirements: '   ',
      );

      expect(postedBody().containsKey('special_requirements'), isFalse);
    });

    test('the body holds only keys of VisitCreate', () async {
      stubPost(visit(), statusCode: 201);

      await datasource.scheduleVisit(
        propertyId: 55,
        scheduledDate: '2026-10-01T14:00:00Z',
        specialRequirements: 'x',
      );

      const declared = {
        'property_id',
        'scheduled_date',
        'special_requirements',
        'conversation_id',
        'counterparty_user_id',
        'match_id',
        'time_slot_label',
        'user_id',
      };
      expect(declared.containsAll(postedBody().keys), isTrue);
    });

    test('does not retry the POST by itself', () async {
      stubPost(visit(), statusCode: 201);

      await datasource.scheduleVisit(propertyId: 55, scheduledDate: '2026-10-01T14:00:00Z');

      verify(
        () => apiClient.post(ApiPaths.visits, body: any(named: 'body'), idempotent: false),
      ).called(1);
    });

    for (final entry in <String, Object?>{
      'an empty object': <String, dynamic>{},
      'a data envelope': {'data': visit()},
      'a visit with no status': visit()..remove('status'),
    }.entries) {
      test('${entry.key} is a malformed response', () async {
        stubPost(entry.value, statusCode: 201);

        await expectLater(
          datasource.scheduleVisit(propertyId: 1, scheduledDate: '2026-10-01T14:00:00Z'),
          throwsA(isA<ApiException>().having((e) => e.code, 'code', 'MALFORMED_RESPONSE')),
        );
      });
    }
  });

  group('cancelVisit', () {
    test('returns the updated Visit', () async {
      stubPost(visits['cancelled']);

      final cancelled = await datasource.cancelVisit(92, reason: 'Plans changed');

      expect(cancelled.id, 92);
      expect(cancelled.status, VisitStatus.cancelled);
      expect(cancelled.cancellationReason, 'Plans changed');
    });

    test('sends the trimmed reason to the cancel route of the visit', () async {
      stubPost(visits['cancelled']);

      await datasource.cancelVisit(12, reason: '  Schedule conflict  ');

      verify(
        () => apiClient.post(
          ApiPaths.visitCancel(12),
          body: {'reason': 'Schedule conflict'},
          idempotent: any(named: 'idempotent'),
        ),
      ).called(1);
    });

    test('a reason with no text or more than 1000 characters is not sent', () async {
      for (final reason in ['', '   ', 'x' * 1001]) {
        await expectLater(
          datasource.cancelVisit(5, reason: reason),
          throwsA(isA<ValidationException>().having((e) => e.code, 'code', 'INVALID_REASON')),
        );
      }
      verifyNever(
        () => apiClient.post(
          any(),
          body: any(named: 'body'),
          idempotent: any(named: 'idempotent'),
        ),
      );
    });

    test('a reason of exactly 1000 characters is sent', () async {
      stubPost(visits['cancelled']);

      await datasource.cancelVisit(5, reason: 'x' * 1000);

      expect((postedBody()['reason'] as String).length, 1000);
    });

    for (final entry in <String, Object?>{
      'a success flag': {'success': true},
      'a plain string': 'ok',
      'an empty object': <String, dynamic>{},
    }.entries) {
      test('${entry.key} is not a Visit and fails', () async {
        stubPost(entry.value);

        await expectLater(
          datasource.cancelVisit(5, reason: 'Not interested'),
          throwsA(isA<ApiException>().having((e) => e.code, 'code', 'MALFORMED_RESPONSE')),
        );
      });
    }
  });

  group('rescheduleVisit', () {
    test('returns the updated Visit', () async {
      stubPost(visits['rescheduled']);

      final moved = await datasource.rescheduleVisit(92, newDate: '2026-11-01T10:00:00Z');

      expect(moved.id, 92);
    });

    test('sends new_date and the trimmed reason', () async {
      stubPost(visits['rescheduled']);

      await datasource.rescheduleVisit(
        7,
        newDate: '2026-11-01T10:00:00Z',
        reason: '  Time change  ',
      );

      expect(postedBody(), {'new_date': '2026-11-01T10:00:00Z', 'reason': 'Time change'});
    });

    test('omits the reason when it has no text', () async {
      stubPost(visits['rescheduled']);

      await datasource.rescheduleVisit(7, newDate: '2026-11-01T10:00:00Z');
      await datasource.rescheduleVisit(7, newDate: '2026-11-01T10:00:00Z', reason: '  ');

      final bodies = verify(
        () => apiClient.post(
          any(),
          body: captureAny(named: 'body'),
          idempotent: any(named: 'idempotent'),
        ),
      ).captured;
      for (final body in bodies) {
        expect((body as Map).containsKey('reason'), isFalse);
      }
    });

    test('uses the reschedule route of the visit', () async {
      stubPost(visits['rescheduled']);

      await datasource.rescheduleVisit(15, newDate: '2026-11-01T10:00:00Z');

      verify(
        () => apiClient.post(
          ApiPaths.visitReschedule(15),
          body: any(named: 'body'),
          idempotent: any(named: 'idempotent'),
        ),
      ).called(1);
    });

    for (final entry in <String, Object?>{
      'a success flag': {'success': true},
      'a number': 42,
    }.entries) {
      test('${entry.key} is not a Visit and fails', () async {
        stubPost(entry.value);

        await expectLater(
          datasource.rescheduleVisit(5, newDate: '2026-11-01T10:00:00Z'),
          throwsA(isA<ApiException>().having((e) => e.code, 'code', 'MALFORMED_RESPONSE')),
        );
      });
    }
  });

  group('fetchRelationshipManager', () {
    void stubAgent(Object? body) {
      when(
        () => apiClient.get(any(), useCache: any(named: 'useCache')),
      ).thenAnswer((_) async => ApiResponse(statusCode: 200, body: body, headers: const {}));
    }

    test('reads the assigned agent', () async {
      stubAgent(agent({'id': 3}));

      final manager = await datasource.fetchRelationshipManager();

      expect(manager!.id, 3);
      expect(manager.name, 'Ravi Kumar');
      expect(manager.agentType, AgentType.general);
      expect(manager.contactNumber, '+919811111111');
    });

    test('reads from the assigned route and skips the cache', () async {
      stubAgent(agent());

      await datasource.fetchRelationshipManager();

      verify(() => apiClient.get(ApiPaths.agentsAssigned, useCache: false)).called(1);
    });

    test('a data envelope is a malformed response', () async {
      stubAgent({'data': agent()});

      await expectLater(
        datasource.fetchRelationshipManager(),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'MALFORMED_RESPONSE')),
      );
    });

    test('404 "No agent assigned yet" means no manager, not a failure', () async {
      when(
        () => apiClient.get(any(), useCache: any(named: 'useCache')),
      ).thenThrow(NotFoundException('No agent assigned yet'));

      expect(await datasource.fetchRelationshipManager(), isNull);
    });

    test('a 404 shaped as an ApiException also means no manager', () async {
      when(() => apiClient.get(any(), useCache: any(named: 'useCache'))).thenThrow(
        ApiException('The request could not be completed.', code: 'NOT_FOUND', statusCode: 404),
      );

      expect(await datasource.fetchRelationshipManager(), isNull);
    });

    test('other agent failures still throw', () async {
      when(
        () => apiClient.get(any(), useCache: any(named: 'useCache')),
      ).thenThrow(ApiException('Forbidden', statusCode: 403));

      await expectLater(datasource.fetchRelationshipManager(), throwsA(isA<ApiException>()));
    });
  });

  group('VisitsPayload', () {
    test('constructor stores values correctly', () {
      const payload = VisitsPayload(visits: [], hasMore: true, nextCursor: 'abc');

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
