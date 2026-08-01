// test/features/explore/data/properties_remote_datasource_test.dart
//
// Unit tests for [PropertiesRemoteDatasource].
// Mocks [ApiClient] to verify property fetching, single-property detail,
// and response parsing (including envelope normalization).

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' as getx;
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/network/api_paths.dart';
import 'package:ghar360/core/network/auth_header_provider.dart';
import 'package:ghar360/core/network/etag_cache.dart';
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
    datasource = PropertiesRemoteDatasource(apiClient);
  });

  /// Stubs a GET request to the properties endpoint (any query params).
  void stubPropertiesGet(dynamic body) {
    when(
      () => apiClient.get(
        ApiPaths.properties,
        queryParams: any(named: 'queryParams'),
        useCache: any(named: 'useCache'),
      ),
    ).thenAnswer((_) async => ApiResponse(statusCode: 200, body: body, headers: {}));
  }

  group('fetchProperties', () {
    test('returns parsed properties on success', () async {
      final propertyJsonList = testPropertyJsonList(count: 3);
      stubPropertiesGet({'items': propertyJsonList, 'has_more': false, 'limit': 20});

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

    test('handles nested data envelope', () async {
      final propertyJsonList = testPropertyJsonList(count: 2);
      // Response wrapped in { data: { items: [...], has_more: true, ... } }
      stubPropertiesGet({
        'data': {'items': propertyJsonList, 'has_more': true, 'next_cursor': 'abc123', 'limit': 20},
      });

      final response = await datasource.fetchProperties(
        latitude: 28.6139,
        longitude: 77.2090,
        radiusKm: 10,
        filters: const UnifiedFilterModel(),
      );

      expect(response.items.length, 2);
      expect(response.hasMore, isTrue);
      expect(response.nextCursor, 'abc123');
    });

    test('handles bare list response gracefully', () async {
      final propertyJsonList = testPropertyJsonList(count: 1);
      stubPropertiesGet(propertyJsonList);

      final response = await datasource.fetchProperties(
        latitude: 28.6139,
        longitude: 77.2090,
        radiusKm: 10,
        filters: const UnifiedFilterModel(),
      );

      expect(response.items.length, 1);
    });

    test('propagates API exception', () async {
      when(
        () => apiClient.get(
          ApiPaths.properties,
          queryParams: any(named: 'queryParams'),
          useCache: any(named: 'useCache'),
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

    test('unwraps data envelope for single property', () async {
      when(
        () => apiClient.get(ApiPaths.propertyById('99'), useCache: false, requireAuth: false),
      ).thenAnswer(
        (_) async => ApiResponse(
          statusCode: 200,
          body: {'data': testPropertyJson(id: 99, title: 'Penthouse')},
          headers: {},
        ),
      );

      final property = await datasource.fetchPropertyById('99');
      expect(property.title, 'Penthouse');
    });

    test('throws FormatException when response body is empty', () async {
      when(
        () => apiClient.get(ApiPaths.propertyById('1'), useCache: false, requireAuth: false),
      ).thenAnswer(
        (_) async => ApiResponse(statusCode: 200, body: <String, dynamic>{}, headers: {}),
      );

      expect(() => datasource.fetchPropertyById('1'), throwsA(isA<FormatException>()));
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
            return const getx.Response<dynamic>(statusCode: 304, headers: <String, String>{});
          }
          final payload = payloadFor(headers);
          return getx.Response<dynamic>(
            statusCode: 200,
            body: payload,
            bodyString: jsonEncode(payload),
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

    test('fetchPropertiesByIds: account switch is not served the previous liked-status', () async {
      // This endpoint requires auth, so the leak is user A → user B on the
      // same `?ids=` URL rather than signed-in → guest.
      final realDatasource = buildDatasource(
        (headers) => {
          'items': [
            testPropertyJson(id: 42, title: 'Sea View Villa')
              ..['liked'] = headers['Authorization'] == 'Bearer user-a-token',
          ],
          'has_more': false,
          'limit': 20,
        },
      );

      auth.cached = {'Authorization': 'Bearer user-a-token'};
      expect((await realDatasource.fetchPropertiesByIds([42])).single.liked, isTrue);

      auth.cached = {'Authorization': 'Bearer user-b-token'};
      expect((await realDatasource.fetchPropertiesByIds([42])).single.liked, isFalse);

      expect(ifNoneMatchSeen, [null, null], reason: 'the batch endpoint must not be cached');
      expect(authorizationSeen, ['Bearer user-a-token', 'Bearer user-b-token']);
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
  String? getETag(String key) => entries[key]?.etag;

  @override
  String? getCachedBody(String key) => entries[key]?.body;

  @override
  void cacheResponse(String key, getx.Response response) {
    final etag = response.headers?['etag'];
    if (etag == null) return;
    entries[key] = (etag: etag, body: response.bodyString ?? jsonEncode(response.body));
  }

  @override
  void clear() => entries.clear();
}
