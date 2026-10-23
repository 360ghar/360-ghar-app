// test/features/explore/data/properties_remote_datasource_test.dart
//
// Unit tests for [PropertiesRemoteDatasource].
// Mocks [ApiClient] to verify property fetching, single-property detail,
// and strict response parsing: a `CursorPage[Property]` body, no data envelope, no bare list.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/network/api_paths.dart';
import 'package:ghar360/core/network/auth_header_provider.dart';
import 'package:ghar360/core/network/cache_policy.dart';
import 'package:ghar360/core/network/etag_cache.dart';
import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/properties/data/datasources/properties_remote_datasource.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mocks.dart';
import '../../../helpers/test_data.dart';

void main() {
  late MockApiClient apiClient;
  late PropertiesRemoteDatasource datasource;

  setUp(() {
    apiClient = MockApiClient();
    when(() => apiClient.signedIn).thenReturn(true);
    datasource = PropertiesRemoteDatasource(apiClient);
  });

  /// Stubs a GET request to the properties endpoint (any query params).
  void stubPropertiesGet(dynamic body) {
    when(
      () => apiClient.get(
        ApiPaths.properties,
        queryParams: any(named: 'queryParams'),
        useCache: any(named: 'useCache'),
        requireAuth: any(named: 'requireAuth'),
      ),
    ).thenAnswer((_) async => ApiResponse(statusCode: 200, body: body, headers: {}));
  }

  test('a guest lists and searches without requiring auth, a signed-in user requires it', () async {
    stubPropertiesGet(testPropertyPage(count: 1));
    Future<void> run() async {
      await datasource.fetchProperties(
        latitude: 28.6,
        longitude: 77.2,
        radiusKm: 10,
        filters: const UnifiedFilterModel(),
      );
      await datasource.searchProperties(query: 'dlf');
    }

    when(() => apiClient.signedIn).thenReturn(false);
    await run();
    verify(
      () => apiClient.get(
        ApiPaths.properties,
        queryParams: any(named: 'queryParams'),
        useCache: any(named: 'useCache'),
        requireAuth: false,
      ),
    ).called(2);
    when(() => apiClient.signedIn).thenReturn(true);
    await run();
    verify(
      () => apiClient.get(
        ApiPaths.properties,
        queryParams: any(named: 'queryParams'),
        useCache: any(named: 'useCache'),
        requireAuth: true,
      ),
    ).called(2);
  });

  group('fetchProperties', () {
    test('returns parsed properties on success', () async {
      stubPropertiesGet(testPropertyPage(count: 3));

      final response = await datasource.fetchProperties(
        latitude: 28.6139,
        longitude: 77.2090,
        radiusKm: 10,
        filters: const UnifiedFilterModel(),
      );

      expect(response.items.length, 3);
      expect(response.items.first.title, 'Property 1');
      expect(response.hasMore, isFalse);
    });

    test('keeps the paging keys of the page', () async {
      stubPropertiesGet(
        testPropertyPage(count: 2, hasMore: true, nextCursor: 'abc123', limit: 2, total: 9),
      );

      final response = await datasource.fetchProperties(
        latitude: 28.6139,
        longitude: 77.2090,
        radiusKm: 10,
        filters: const UnifiedFilterModel(),
      );

      expect(response.items.length, 2);
      expect(response.hasMore, isTrue);
      expect(response.nextCursor, 'abc123');
      expect(response.limit, 2);
      expect(response.total, 9);
    });

    test('propagates API exception', () async {
      when(
        () => apiClient.get(
          ApiPaths.properties,
          queryParams: any(named: 'queryParams'),
          useCache: any(named: 'useCache'),
          requireAuth: any(named: 'requireAuth'),
        ),
      ).thenThrow(ServerException('Server down', statusCode: 500));

      expect(
        () => datasource.fetchProperties(
          latitude: 28.6139,
          longitude: 77.2090,
          radiusKm: 10,
          filters: const UnifiedFilterModel(),
        ),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('strict property list response contract', () {
    final malformed = <String, Object?>{
      'null': null,
      'scalar': 'private-response',
      'number': 12,
      'bare list': testPropertyJsonList(count: 1),
      'empty map': <String, Object?>{},
      'unrecognized map': {'error': 'private-response'},
      'null items': {...testPropertyPage(), 'items': null},
      'scalar items': {...testPropertyPage(), 'items': 'private-response'},
      'data envelope': {'data': testPropertyPage(count: 1)},
      'scalar nested data': {'data': 'private-response'},
      'malformed row': {
        ...testPropertyPage(),
        'items': [testPropertyJson(), 'private-row'],
      },
      'missing identity': testPropertyPage(items: [<String, dynamic>{}]),
      'negative identity': testPropertyPage(items: [testPropertyJson(id: -1)]),
      'invalid property field': testPropertyPage(
        items: [
          {...testPropertyJson(), 'title': []},
        ],
      ),
      'row without a required key': testPropertyPage(
        items: [testPropertyJson()..remove('owner_id')],
      ),
      'invalid pagination': {...testPropertyPage(), 'has_more': 'yes'},
      'missing next_cursor': testPropertyPage()..remove('next_cursor'),
    };
    for (final entry in malformed.entries) {
      for (final request in ['fetch', 'search']) {
        test('$request rejects ${entry.key} instead of successful empty content', () async {
          stubPropertiesGet(entry.value);
          final Future<Object> result = switch (request) {
            'search' => datasource.searchProperties(query: 'home'),
            _ => datasource.fetchProperties(
              latitude: 28,
              longitude: 77,
              radiusKm: 10,
              filters: const UnifiedFilterModel(),
            ),
          };
          await expectLater(
            result,
            throwsA(
              isA<ServerException>()
                  .having((error) => error.code, 'code', 'MALFORMED_RESPONSE')
                  .having((error) => error.details, 'details', isNull),
            ),
          );
        });
      }
    }
    test('an explicit empty page is a valid empty result', () async {
      stubPropertiesGet(testPropertyPage(count: 0));
      final result = await datasource.searchProperties(query: 'home');
      expect(result.items, isEmpty);
      expect(result.hasMore, false);
    });
    test('the page keeps its own paging keys', () async {
      stubPropertiesGet(
        testPropertyPage(
          items: [testPropertyJson(id: 1)],
          hasMore: true,
          nextCursor: 'opaque',
          limit: 7,
          total: 99,
        ),
      );
      final result = await datasource.searchProperties(query: 'home');
      expect(result.items.single.id, 1);
      expect(result.nextCursor, 'opaque');
      expect(result.limit, 7);
      expect(result.total, 99);
    });
  });

  group('fetchPropertyById', () {
    test('returns a PropertyModel on success', () async {
      when(
        () => apiClient.get(ApiPaths.propertyById('42'), useCache: false, requireAuth: false),
      ).thenAnswer(
        (_) async => ApiResponse(
          statusCode: 200,
          body: testPropertyJson(id: 42, title: 'Sea View Villa'),
          headers: {},
        ),
      );

      final property = await datasource.fetchPropertyById('42');

      expect(property.title, 'Sea View Villa');
      expect(property.id, 42);
      // Public deep link: the request must be allowed without a session, and
      // must not be cached (the ETag cache keys on URL alone, so one entry
      // would serve a signed-in user's liked-status to a guest).
      verify(
        () => apiClient.get(ApiPaths.propertyById('42'), useCache: false, requireAuth: false),
      ).called(1);
    });

    test('a signed-in response marked no-store carries the mark, a public one does not', () async {
      Future<void> answer(Map<String, String> headers, int id) async {
        when(
          () => apiClient.get(ApiPaths.propertyById('$id'), useCache: false, requireAuth: false),
        ).thenAnswer(
          (_) async => ApiResponse(
            statusCode: 200,
            body: testPropertyJson(id: id),
            headers: headers,
          ),
        );
      }

      await answer({'cache-control': 'private, no-store'}, 7);
      await answer({'cache-control': 'public, max-age=60'}, 8);

      expect(isNoStoreResponse(await datasource.fetchPropertyById('7')), isTrue);
      expect(isNoStoreResponse(await datasource.fetchPropertyById('8')), isFalse);
    });

    test('a page marked no-store carries the mark', () async {
      when(
        () => apiClient.get(
          ApiPaths.properties,
          queryParams: any(named: 'queryParams'),
          useCache: any(named: 'useCache'),
          requireAuth: any(named: 'requireAuth'),
        ),
      ).thenAnswer(
        (_) async => ApiResponse(
          statusCode: 200,
          body: testPropertyPage(count: 1),
          headers: {'cache-control': 'private, no-store'},
        ),
      );

      final page = await datasource.searchProperties(query: 'home');

      expect(isNoStoreResponse(page), isTrue);
    });

    test('does not unwrap a data envelope: the contract has none', () async {
      when(
        () => apiClient.get(ApiPaths.propertyById('99'), useCache: false, requireAuth: false),
      ).thenAnswer(
        (_) async => ApiResponse(
          statusCode: 200,
          body: {'data': testPropertyJson(id: 99, title: 'Penthouse')},
          headers: {},
        ),
      );

      expect(
        () => datasource.fetchPropertyById('99'),
        throwsA(isA<ServerException>().having((e) => e.code, 'code', 'MALFORMED_RESPONSE')),
      );
    });

    test('throws typed malformed failure when detail response is empty', () async {
      when(
        () => apiClient.get(ApiPaths.propertyById('1'), useCache: false, requireAuth: false),
      ).thenAnswer(
        (_) async => const ApiResponse(statusCode: 200, body: <String, dynamic>{}, headers: {}),
      );

      expect(
        () => datasource.fetchPropertyById('1'),
        throwsA(isA<ServerException>().having((e) => e.code, 'code', 'MALFORMED_RESPONSE')),
      );
    });
  });

  // End-to-end over a real ApiClient and a real ETag cache. The dispatcher
  // always offers an ETag, so any URL-keyed caching shows up as a second call
  // carrying If-None-Match and being answered 304 from the first user's entry.
  group('auth isolation over a real ApiClient', () {
    late _SwitchableAuthProvider auth;
    late List<String?> ifNoneMatchSeen;
    late List<String?> authorizationSeen;

    setUp(() {
      auth = _SwitchableAuthProvider();
      ifNoneMatchSeen = <String?>[];
      authorizationSeen = <String?>[];
    });

    PropertiesRemoteDatasource buildDatasource(
      Map<String, dynamic> Function(Map<String, String> headers) payloadFor,
    ) {
      final client = ApiClient(
        baseUrl: 'http://localhost:9999',
        authProvider: auth,
        etagCache: _InMemoryETagCache(),
        enablePerformanceMetrics: false,
        maxGetRetries: 0,
        requestDispatcher: (method, url, {body, required headers}) async {
          ifNoneMatchSeen.add(headers['If-None-Match']);
          authorizationSeen.add(headers['Authorization']);
          if (headers['If-None-Match'] != null) {
            return const ApiResponse(statusCode: 304, headers: <String, String>{});
          }
          final payload = payloadFor(headers);
          return ApiResponse(
            statusCode: 200,
            body: payload,
            headers: const <String, String>{'etag': 'v1', 'content-type': 'application/json'},
          );
        },
      );
      return PropertiesRemoteDatasource(client);
    }

    test('fetchPropertyById: guest is not served the signed-in user liked-status', () async {
      auth.allowGetAuthHeader = false; // optional auth must never refresh
      final realDatasource = buildDatasource(
        (headers) =>
            testPropertyJson(id: 42, title: 'Sea View Villa')
              ..['liked'] = headers.containsKey('Authorization'),
      );

      auth.cached = {'Authorization': 'Bearer user-token'};
      expect((await realDatasource.fetchPropertyById('42')).liked, isTrue);

      auth.cached = null; // user signs out
      expect((await realDatasource.fetchPropertyById('42')).liked, isFalse);

      expect(ifNoneMatchSeen, [null, null], reason: 'the detail endpoint must not be cached');
      expect(authorizationSeen, ['Bearer user-token', null]);
    });
  });
}

/// An [AuthHeaderProvider] whose header can be flipped to model a sign-out or
/// an account switch.
class _SwitchableAuthProvider extends AuthHeaderProvider {
  Map<String, String>? cached;

  /// Optional-auth requests must never reach [getAuthHeader]; set false there
  /// so a refresh attempt fails loudly instead of silently passing.
  bool allowGetAuthHeader = true;

  @override
  Map<String, String>? get cachedAuthHeader => cached;

  @override
  Future<Map<String, String>?> getAuthHeader({bool forceRefresh = false}) async {
    if (!allowGetAuthHeader) {
      throw StateError('optional-auth requests must not refresh the session');
    }
    return cached;
  }
}

class _InMemoryETagCache extends Mock implements ETagCache {
  final Map<String, ({String etag, String body})> entries = {};

  @override
  StorageScope get scope => _MockStorageScope();

  @override
  Future<CachedEntry?> read(String key, {required StorageScope scope}) async {
    final value = entries[key];
    if (value == null) return null;
    final now = DateTime.now();
    return CachedEntry(
      value: jsonDecode(value.body),
      etag: value.etag,
      createdAt: now,
      freshUntil: now.add(const Duration(minutes: 5)),
      expiresAt: now.add(const Duration(hours: 24)),
      schemaVersion: 1,
    );
  }

  @override
  Future<void> cacheResponse(
    String key,
    ApiResponse response, {
    required StorageScope scope,
  }) async {
    final etag = response.headers['etag'];
    if (etag == null) return;
    entries[key] = (etag: etag, body: jsonEncode(response.body));
  }

  @override
  Future<void> clear() async => entries.clear();
}

class _MockStorageScope extends Mock implements StorageScope {}
