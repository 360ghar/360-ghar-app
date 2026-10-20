// Every request the app sends is declared by the backend: the path and method exist in the OpenAPI
// document, every query key is declared and in range, and every body key is declared by the
// request schema with the right type and length. `tool/api_fixtures.py` writes the operations and
// request schemas from `360ghar-backend/docs/openapi.json` and the backend's Pydantic models.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/controllers/offline_queue_service.dart';
import 'package:ghar360/core/data/models/app_update_models.dart';
import 'package:ghar360/core/data/models/bug_report_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/data/models/wire_enums.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/assistant/data/assistant_repository.dart';
import 'package:ghar360/features/notifications/data/datasources/notifications_remote_datasource.dart';
import 'package:ghar360/features/profile/data/notification_settings_repository.dart';
import 'package:ghar360/features/profile/data/profile_repository.dart';
import 'package:ghar360/features/profile/data/static_page_repository.dart';
import 'package:ghar360/features/profile/data/support_repository.dart';
import 'package:ghar360/features/properties/application/amenities.dart';
import 'package:ghar360/features/properties/data/datasources/properties_remote_datasource.dart';
import 'package:ghar360/features/splash/data/app_update_repository.dart';
import 'package:ghar360/features/swipes/data/swipes_repository.dart';
import 'package:ghar360/features/visits/data/datasources/visits_remote_datasource.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../helpers/mocks.dart';
import '../helpers/property_query_test_support.dart';
import 'contract_support.dart';

final _operations = asObject(apiFixture('operations'));
final _requests = asObject(apiFixture('requests'));

/// The operation a recorded call belongs to, or null when the backend has no such route.
String? _operationKey(RecordedCall call) {
  for (final key in _operations.keys) {
    final space = key.indexOf(' ');
    if (key.substring(0, space) != call.method) continue;
    final template = key.substring(space + 1);
    final pattern = RegExp('^${template.replaceAll(RegExp(r'\{[^}]+\}'), r'[^/]+')}\$');
    if (pattern.hasMatch(call.path)) return key;
  }
  return null;
}

/// A body key against its request schema: the key is declared, its value has the declared
/// type, enum value and length.
void _expectBodyMatches(String schemaName, Object? body) {
  final schema = asObject(_requests[schemaName]);
  final properties = asObject(schema['properties']);
  final map = asObject(body);
  for (final key in map.keys) {
    expect(properties.keys, contains(key), reason: '$schemaName has no key $key');
  }
  for (final required in List<String>.from(schema['required'] as List)) {
    expect(map.keys, contains(required), reason: '$schemaName requires $required');
  }
  map.forEach((key, value) {
    final rule = asObject(properties[key]);
    if (value == null) {
      expect(rule['nullable'], isTrue, reason: '$schemaName.$key is not nullable');
      return;
    }
    switch (rule['type']) {
      case 'string':
        expect(value, isA<String>(), reason: '$schemaName.$key');
        final text = value as String;
        if (rule['maxLength'] != null) {
          expect(text.length, lessThanOrEqualTo(rule['maxLength'] as int), reason: key);
        }
        if (rule['minLength'] != null) {
          expect(text.length, greaterThanOrEqualTo(rule['minLength'] as int), reason: key);
        }
      case 'integer':
        expect(value, isA<int>(), reason: '$schemaName.$key must be an integer');
      case 'number':
        expect(value, isA<num>(), reason: '$schemaName.$key');
      case 'boolean':
        expect(value, isA<bool>(), reason: '$schemaName.$key');
      case 'array':
        expect(value, isA<List>(), reason: '$schemaName.$key');
      case 'object':
        expect(value, isA<Map>(), reason: '$schemaName.$key');
    }
    if (rule['enum'] != null) {
      expect(rule['enum'], contains(value), reason: '$schemaName.$key is not an enum value');
    }
    if (rule['maximum'] != null && value is num) {
      expect(value, lessThanOrEqualTo(rule['maximum'] as num), reason: key);
    }
    if (rule['minimum'] != null && value is num) {
      expect(value, greaterThanOrEqualTo(rule['minimum'] as num), reason: key);
    }
  });
}

/// A call against its operation: declared route, declared and in-range query, declared body
/// schema (and no body on a route that takes none).
void _expectDeclared(RecordedCall call, {String? bodySchema}) {
  final key = _operationKey(call);
  expect(key, isNotNull, reason: 'the backend has no route for $call');
  final operation = asObject(_operations[key]);
  final query = asObject(operation['query']);
  for (final entry in call.query.entries) {
    expect(query.keys, contains(entry.key), reason: '$key does not declare query ${entry.key}');
    final bounds = asObject(query[entry.key]);
    final value = num.tryParse(entry.value.first);
    if (value != null) {
      if (bounds['maximum'] != null) {
        expect(value, lessThanOrEqualTo(bounds['maximum'] as num), reason: entry.key);
      }
      if (bounds['minimum'] != null) {
        expect(value, greaterThanOrEqualTo(bounds['minimum'] as num), reason: entry.key);
      }
    }
  }
  if (bodySchema == null) {
    expect(operation['body'], isNull, reason: '$key declares a body the app does not send');
    expect(call.body, isNull, reason: 'the app sends a body to $key, which takes none');
  } else {
    expect(operation['body'], bodySchema, reason: '$key takes ${operation['body']}');
    _expectBodyMatches(bodySchema, call.body);
  }
}

RecordedCall _only(RecordingApi api) {
  expect(api.calls, hasLength(1));
  return api.calls.single;
}

void main() {
  group('operations the app calls', () {
    test('GET /properties: filters, paging and location keys are declared and in range', () async {
      final api = RecordingApi(
        (_) => jsonResponse(asObject(apiFixture('properties')['list_page'])),
      );
      final filters = UnifiedFilterModel(
        purpose: 'rent',
        propertyType: const ['apartment', 'pg'],
        priceMin: 10000,
        priceMax: 90000,
        bedroomsMin: 1,
        bedroomsMax: 4,
        bathroomsMin: 1,
        bathroomsMax: 3,
        areaMin: 300,
        areaMax: 4000,
        parkingSpacesMin: 1,
        floorNumberMin: 0,
        floorNumberMax: 20,
        ageMax: 10,
        amenities: const ['Swimming Pool'],
        features: const ['Corner unit'],
        genderPreference: 'female',
        sharingType: 'master_bedroom',
        availableFrom: DateTime(2026, 11, 1),
        checkInDate: DateTime(2026, 11, 2),
        checkOutDate: DateTime(2026, 11, 5),
        guests: 2,
        sortBy: SortBy.priceLow,
        searchQuery: 'sector 51',
        radiusKm: 2000,
      );

      await PropertiesRemoteDatasource(api.client).fetchProperties(
        latitude: 28.4231,
        longitude: 77.0851,
        radiusKm: 2000,
        filters: filters,
        cursor: 'abc',
        limit: 500,
        excludeSwiped: true,
        useCache: false,
      );

      final call = _only(api);
      _expectDeclared(call);
      expect(call.query['limit']!.single, '100');
      expect(call.query['radius']!.single, '100');
      expect(call.query['sort_by']!.single, 'price_low');
    });

    test('GET /properties/{id}', () async {
      final api = RecordingApi((_) => jsonResponse(asObject(apiFixture('properties')['detail'])));

      await PropertiesRemoteDatasource(api.client).fetchPropertyById('1');

      _expectDeclared(_only(api));
    });

    test('GET /swipes carries the property filters and is_liked, and no excluded key', () async {
      final api = RecordingApi((_) => jsonResponse(asObject(apiFixture('swipes')['history_page'])));
      final h = await PropertyQueryHarness.create();
      addTearDown(h.close);
      final scope = h.container.read(storageScopeProvider);
      final queue = OfflineQueueService(database: h.database, scope: () => scope);
      addTearDown(queue.close);

      await SwipesRepository(apiClient: api.client, offlineQueue: queue).getSwipeHistoryProperties(
        filters: UnifiedFilterModel(
          purpose: 'buy',
          propertyType: const ['house'],
          genderPreference: 'any',
          sharingType: 'entire_flat',
          availableFrom: DateTime(2026, 11, 1),
          propertyIds: const [1, 2],
          radiusKm: 12,
        ),
        latitude: 28.4,
        longitude: 77.0,
        cursor: 'abc',
        limit: 200,
        isLiked: true,
      );

      final call = _only(api);
      _expectDeclared(call);
      expect(call.query['is_liked']!.single, 'true');
      expect(call.query.keys, isNot(contains('exclude_swiped')));
      expect(call.query.keys, isNot(contains('semantic_search')));
    });

    test('POST /swipes sends SwipeCreate and reads SwipeOut', () async {
      final api = RecordingApi(
        (_) => jsonResponse(asObject(apiFixture('swipes')['recorded']), status: 201),
      );
      final h = await PropertyQueryHarness.create();
      addTearDown(h.close);
      final scope = h.container.read(storageScopeProvider);
      final queue = OfflineQueueService(database: h.database, scope: () => scope);
      addTearDown(queue.close);

      await SwipesRepository(
        apiClient: api.client,
        offlineQueue: queue,
      ).recordSwipe(propertyId: 3, isLiked: true);

      _expectDeclared(_only(api), bodySchema: 'SwipeCreate');
    });

    test('visits: list, schedule, cancel and reschedule', () async {
      final visits = asObject(apiFixture('visits'));
      final api = RecordingApi((call) {
        if (call.method == 'GET') return jsonResponse(visits['list_page']);
        if (call.path.endsWith('/cancel')) return jsonResponse(visits['cancelled']);
        if (call.path.endsWith('/reschedule')) return jsonResponse(visits['rescheduled']);
        return jsonResponse(visits['created'], status: 201);
      });
      final remote = VisitsRemoteDatasource(api.client);

      await remote.fetchVisitsSummary(cursor: 'abc', limit: 500);
      await remote.scheduleVisit(
        propertyId: 1,
        scheduledDate: '2026-10-04T05:30:00.000Z',
        specialRequirements: 'Need parking',
      );
      await remote.cancelVisit(92, reason: '  Plans changed ');
      await remote.rescheduleVisit(92, newDate: '2026-10-06T09:00:00.000Z', reason: 'Traffic');

      expect(api.calls, hasLength(4));
      _expectDeclared(api.calls[0]);
      _expectDeclared(api.calls[1], bodySchema: 'VisitCreate');
      _expectDeclared(api.calls[2], bodySchema: 'VisitCancel');
      _expectDeclared(api.calls[3], bodySchema: 'VisitReschedule');
      expect(api.calls[2].body, {'reason': 'Plans changed'});
      expect(api.calls[0].query['limit']!.single, '100');
    });

    test('a visit date goes out with a UTC offset, never as a naive time', () async {
      final api = RecordingApi((_) => jsonResponse(apiFixture('visits')['created'], status: 201));
      await VisitsRemoteDatasource(api.client).scheduleVisit(
        propertyId: 1,
        scheduledDate: DateTime(2026, 10, 4, 11).toUtc().toIso8601String(),
      );

      final date = asObject(api.calls.single.body)['scheduled_date'] as String;
      expect(date, endsWith('Z'));
    });

    test('GET /agents/assigned', () async {
      final api = RecordingApi((_) => jsonResponse(apiFixture('agents')['assigned']));

      await VisitsRemoteDatasource(api.client).fetchRelationshipManager();

      _expectDeclared(_only(api));
    });

    test('profile: GET, PUT /users/profile, PUT /users/preferences, PUT /users/location', () async {
      final users = asObject(apiFixture('users'));
      final api = RecordingApi((call) {
        if (call.path.endsWith('/preferences')) return jsonResponse(users['preferences']);
        if (call.path.endsWith('/location')) return jsonResponse(users['location']);
        return jsonResponse(users['profile']);
      });
      final repository = ProfileRepository(apiClient: api.client);

      await repository.getCurrentUserProfile();
      await repository.updateUserProfile({'full_name': 'Asha Verma', 'date_of_birth': null});
      await repository.updateUserPreferences({
        'purpose': 'rent',
        'location_preference': ['Gurugram'],
      });
      await repository.updateUserLocation(latitude: 28.4, longitude: 77.0);

      expect(api.calls, hasLength(4));
      _expectDeclared(api.calls[0]);
      _expectDeclared(api.calls[1], bodySchema: 'UserUpdate');
      _expectDeclared(api.calls[2], bodySchema: 'UserPreferencesPatch');
      _expectDeclared(api.calls[3], bodySchema: 'LocationUpdate');
    });

    test('notification settings: GET and a one-key PUT', () async {
      final users = asObject(apiFixture('users'));
      final api = RecordingApi((_) => jsonResponse(users['notification_settings']));
      final repository = NotificationSettingsRepository(apiClient: api.client);

      await repository.fetch();
      await repository.set('promotional_emails', true);

      _expectDeclared(api.calls[0]);
      _expectDeclared(api.calls[1], bodySchema: 'NotificationSettingsWrite');
      expect(asObject(api.calls[1].body), {'promotional_emails': true});
    });

    test('device register carries app_key and no user_id; unregister has a token body', () async {
      final api = RecordingApi((call) {
        if (call.method == 'DELETE') return jsonResponse(null, status: 204);
        return jsonResponse(apiFixture('notifications')['registration'], status: 201);
      });
      PackageInfo.setMockInitialValues(
        appName: 'Ghar',
        packageName: 'com.ghar360',
        version: '1.2.3',
        buildNumber: '45',
        buildSignature: '',
      );
      final notifications = NotificationsRemoteDatasource(api.client);

      expect(await notifications.registerDeviceToken(token: 'fcm-token'), isTrue);
      expect(await notifications.unregisterDeviceToken('fcm-token'), isTrue);

      _expectDeclared(api.calls[0], bodySchema: 'DeviceRegisterIn');
      _expectDeclared(api.calls[1], bodySchema: 'DeviceUnregisterIn');
      expect(api.calls[0].body, containsPair('app_key', 'ghar'));
      expect(api.calls[1].query, isEmpty, reason: 'the token is never in the URL');
    });

    test('POST /versions/check sends AppVersionCheckRequest and reads the typed answer', () async {
      final api = RecordingApi((_) => jsonResponse(apiFixture('versions')['check_response']));

      final result = await AppUpdateRepository(apiClient: api.client).checkForUpdates(
        const AppVersionCheckRequest(
          app: AppKey.ghar,
          platform: DevicePlatform.android,
          currentVersion: '3.2.0',
          buildNumber: 41,
        ),
      );

      _expectDeclared(_only(api), bodySchema: 'AppVersionCheckRequest');
      expect(result.updateAvailable, isTrue);
      expect(result.latestVersion, '3.3.0');
    });

    test('POST /bugs sends BugReportCreate', () async {
      final api = RecordingApi((_) => jsonResponse(apiFixture('support')['bug'], status: 201));

      await SupportRepository(apiClient: api.client).submitBugReport(
        const BugReportRequest(
          source: 'mobile',
          bugType: BugType.uiBug,
          severity: BugSeverity.low,
          title: 'Map pin overlaps',
          description: 'On 320 px width.',
          deviceInfo: {'os': 'iOS'},
          appVersion: '3.2.0+41',
          tags: ['ghar360'],
        ),
      );

      _expectDeclared(_only(api), bodySchema: 'BugReportCreate');
    });

    test('GET /pages/{name}/public', () async {
      final api = RecordingApi((_) => jsonResponse(apiFixture('pages')['privacy']));

      await StaticPageRepository(apiClient: api.client).fetchPublicPage('privacy-policy');

      _expectDeclared(_only(api));
    });

    test('GET /amenities follows next_cursor with limit 100', () async {
      final page = asObject(apiFixture('amenities')['page']);
      var served = 0;
      final api = RecordingApi((call) {
        served++;
        return jsonResponse(served == 1 ? page : {...page, 'next_cursor': null, 'has_more': false});
      });
      final container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(api.client)],
      );
      addTearDown(container.dispose);

      final amenities = await container.read(amenitiesFetchProvider)();

      expect(api.calls, hasLength(2));
      for (final call in api.calls) {
        _expectDeclared(call);
        expect(call.query['limit']!.single, '100');
      }
      expect(api.calls[1].query['cursor'], isNotNull);
      expect(amenities, hasLength(4));
    });

    test('assistant: conversations, messages page, widget html and delete', () async {
      final assistant = asObject(apiFixture('assistant'));
      final api = RecordingApi((call) {
        if (call.method == 'DELETE') return jsonResponse(null, status: 204);
        if (call.path.contains('/widgets/')) return jsonResponse('<html></html>');
        if (call.path.endsWith('/page')) return jsonResponse(assistant['messages_page']);
        return jsonResponse(assistant['conversations_page']);
      });
      final repository = AssistantRepository(sseClient: MockSseClient(), apiClient: api.client);

      await repository.getConversations(cursor: 'abc', limit: 500);
      await repository.getMessagesPage(42, cursor: 'abc', limit: 500);
      await repository.getWidgetHtml('PropertySearchWidget');
      await repository.deleteConversation(42);

      expect(api.calls, hasLength(4));
      for (final call in api.calls) {
        _expectDeclared(call);
      }
      expect(
        api.calls.map((c) => c.path),
        isNot(contains('/api/v1/agent/conversations/42/messages')),
      );
    });

    test('auth: identifier-status, last-method', () async {
      final api = RecordingApi((call) {
        if (call.path.endsWith('last-method')) return jsonResponse(null, status: 204);
        return jsonResponse(apiFixture('auth')['identifier_status']);
      });
      await api.client.post(
        '/auth/identifier-status',
        body: {'identifier': '+919800000000'},
        requireAuth: false,
      );
      await api.client.post('/auth/last-method', body: {'method': AuthMethod.phoneOtp.wire});

      _expectDeclared(api.calls[0], bodySchema: 'IdentifierStatusRequest');
      _expectDeclared(api.calls[1], bodySchema: 'LastMethodRequest');
    });

    test('account deletion is DELETE /users/me with no body', () async {
      final api = RecordingApi((_) => jsonResponse(null, status: 204));

      final response = await api.client.delete('/users/me');

      expect(response.statusCode, 204);
      _expectDeclared(_only(api));
    });

    test('a failed request is a typed failure, not a success flag', () async {
      final api = RecordingApi((_) => jsonResponse(apiFixture('errors')['not_found'], status: 404));

      await expectLater(
        api.client.get('/pages/missing/public', requireAuth: false, useCache: false),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'PAGE_NOT_FOUND')),
      );
    });
  });
}
