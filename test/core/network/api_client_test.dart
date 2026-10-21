import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/network/auth_header_provider.dart';
import 'package:ghar360/core/network/etag_cache.dart';
import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeAuthHeaderProvider authProvider;
  late MockETagCache etagCache;

  setUpAll(() {
    registerFallbackValue(const ApiResponse(statusCode: 200, body: {}));
    registerFallbackValue(_MockStorageScope());
  });

  UnauthorizedHandler? onUnauthorized;
  setUp(() {
    onUnauthorized = null;
    authProvider = _FakeAuthHeaderProvider();
    etagCache = MockETagCache();
    when(() => etagCache.scope).thenReturn(_MockStorageScope());
    when(() => etagCache.read(any(), scope: any(named: 'scope'))).thenAnswer((_) async => null);
    when(
      () => etagCache.cacheResponse(any(), any(), scope: any(named: 'scope')),
    ).thenAnswer((_) async {});
    when(() => etagCache.clear()).thenAnswer((_) async {});
  });

  tearDown(() {
    onUnauthorized = null;
  });

  ApiClient buildClient({
    required Future<ApiResponse> Function(
      String method,
      String url, {
      Map<String, dynamic>? body,
      required Map<String, String> headers,
    })
    dispatcher,
    int maxGetRetries = 0,
  }) {
    return ApiClient(
      baseUrl: 'http://localhost:9999',
      authProvider: authProvider,
      etagCache: etagCache,
      enablePerformanceMetrics: false,
      maxGetRetries: maxGetRetries,
      requestDispatcher: dispatcher,
    )..onUnauthorized = onUnauthorized;
  }

  group('ApiClient.get', () {
    test('returns ApiResponse on 200 with parsed body', () async {
      final client = buildClient(
        dispatcher: (method, url, {body, required headers}) async => _okResponse({'data': 'hello'}),
      );

      final res = await client.get('/properties', useCache: false);

      expect(res.statusCode, 200);
      expect(res.body, {'data': 'hello'});
      expect(res.isSuccess, isTrue);
    });

    test('injects Authorization header from auth provider', () async {
      Map<String, String>? capturedHeaders;
      final client = buildClient(
        dispatcher: (method, url, {body, required headers}) async {
          capturedHeaders = headers;
          return _okResponse({'ok': true});
        },
      );

      await client.get('/properties', useCache: false);

      expect(capturedHeaders!['Authorization'], 'Bearer test-token');
      expect(capturedHeaders!['Content-Type'], 'application/json');
      expect(capturedHeaders!['Accept'], 'application/json');
    });

    test('throws AuthenticationException when requireAuth and no header', () async {
      authProvider.header = null;
      final client = buildClient(
        dispatcher: (method, url, {body, required headers}) async => _okResponse({'ok': true}),
      );

      await expectLater(
        client.get('/properties', useCache: false),
        throwsA(isA<AuthenticationException>()),
      );
    });

    test('does not require auth header when requireAuth is false', () async {
      authProvider.header = null;
      var dispatched = false;
      final client = buildClient(
        dispatcher: (method, url, {body, required headers}) async {
          dispatched = true;
          return _okResponse({'ok': true});
        },
      );

      final res = await client.get('/health', useCache: false, requireAuth: false);

      expect(dispatched, isTrue);
      expect(res.statusCode, 200);
    });

    test('throws ServerException on 500', () async {
      final client = buildClient(
        dispatcher: (method, url, {body, required headers}) async =>
            _response(500, {'error': 'boom'}),
      );

      await expectLater(
        client.get('/properties', useCache: false),
        throwsA(isA<ServerException>()),
      );
    });

    test('throws AuthenticationException on 403', () async {
      final client = buildClient(
        dispatcher: (method, url, {body, required headers}) async =>
            _response(403, {'error': 'forbidden'}),
      );

      await expectLater(
        client.get('/properties', useCache: false),
        throwsA(
          allOf(
            isA<AuthenticationException>(),
            predicate<AuthenticationException>((e) => e.code == 'FORBIDDEN'),
          ),
        ),
      );
    });

    test('throws ApiException on 404', () async {
      final client = buildClient(
        dispatcher: (method, url, {body, required headers}) async =>
            _response(404, {'error': 'not found'}),
      );

      await expectLater(client.get('/properties/1', useCache: false), throwsA(isA<ApiException>()));
    });

    test('preserves a typed transport failure', () async {
      final client = buildClient(
        dispatcher: (method, url, {body, required headers}) async =>
            throw NetworkException('The service could not be reached.'),
      );

      await expectLater(client.get('/properties', useCache: false), throwsA(isA<AppException>()));
    });

    test('serves cached body on 304 Not Modified', () async {
      when(
        () => etagCache.read(any(), scope: any(named: 'scope')),
      ).thenAnswer((_) async => _cachedEntry({'cached': true}, 'W/"abc"'));

      final client = buildClient(
        dispatcher: (method, url, {body, required headers}) async =>
            const ApiResponse(statusCode: 304, body: null, headers: <String, String>{}),
      );

      final res = await client.get('/properties', useCache: true);

      expect(res.statusCode, 200);
      expect(res.body, {'cached': true});
    });

    test('adds If-None-Match header when ETag is cached', () async {
      when(
        () => etagCache.read(any(), scope: any(named: 'scope')),
      ).thenAnswer((_) async => _cachedEntry({'old': true}, 'W/"abc"'));
      String? capturedIfNoneMatch;
      final client = buildClient(
        dispatcher: (method, url, {body, required headers}) async {
          capturedIfNoneMatch = headers['If-None-Match'];
          return _okResponse({'ok': true});
        },
      );

      await client.get('/properties', useCache: true);

      expect(capturedIfNoneMatch, 'W/"abc"');
    });

    test('caches successful GET response when useCache is true', () async {
      final client = buildClient(
        dispatcher: (method, url, {body, required headers}) async => const ApiResponse(
          statusCode: 200,
          body: {'ok': true},
          headers: <String, String>{'etag': 'W/"new"'},
        ),
      );

      await client.get('/properties', useCache: true);

      verify(() => etagCache.cacheResponse(any(), any(), scope: any(named: 'scope'))).called(1);
    });

    test('does not cache response when useCache is false', () async {
      final client = buildClient(
        dispatcher: (method, url, {body, required headers}) async => const ApiResponse(
          statusCode: 200,
          body: {'ok': true},
          headers: <String, String>{'etag': 'W/"new"'},
        ),
      );

      await client.get('/properties', useCache: false);

      verifyNever(() => etagCache.cacheResponse(any(), any(), scope: any(named: 'scope')));
    });

    test('deduplicates concurrent GET requests for the same URL', () async {
      var dispatchCount = 0;
      final client = buildClient(
        dispatcher: (method, url, {body, required headers}) async {
          dispatchCount++;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return _okResponse({'ok': true});
        },
      );

      final results = await Future.wait([
        client.get('/properties', useCache: false),
        client.get('/properties', useCache: false),
        client.get('/properties', useCache: false),
      ]);

      // Only one dispatch thanks to dedup.
      expect(dispatchCount, 1);
      expect(results.every((r) => r.statusCode == 200), isTrue);
    });

    test('bypasses dedup when dedupe is false', () async {
      var dispatchCount = 0;
      final client = buildClient(
        dispatcher: (method, url, {body, required headers}) async {
          dispatchCount++;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return _okResponse({'ok': true});
        },
      );

      final results = await Future.wait([
        client.get('/properties', useCache: false, dedupe: false),
        client.get('/properties', useCache: false, dedupe: false),
      ]);

      expect(dispatchCount, 2);
      expect(results.every((r) => r.statusCode == 200), isTrue);
    });

    test('retries GET on transient server error up to maxGetRetries', () async {
      var attempts = 0;
      final client = buildClient(
        maxGetRetries: 2,
        dispatcher: (method, url, {body, required headers}) async {
          attempts++;
          if (attempts < 3) return _response(503, {'error': 'unavailable'});
          return _okResponse({'ok': true});
        },
      );

      final res = await client.get('/properties', useCache: false);

      expect(attempts, 3);
      expect(res.statusCode, 200);
    });

    test('throws after exhausting GET retries', () async {
      var attempts = 0;
      final client = buildClient(
        maxGetRetries: 2,
        dispatcher: (method, url, {body, required headers}) async {
          attempts++;
          return _response(500, {'error': 'boom'});
        },
      );

      await expectLater(
        client.get('/properties', useCache: false),
        throwsA(isA<ServerException>()),
      );
      // 1 initial + 2 retries = 3 attempts.
      expect(attempts, 3);
    });
  });

  group('ApiClient.post', () {
    test('returns ApiResponse on 200', () async {
      Map<String, dynamic>? capturedBody;
      final client = buildClient(
        dispatcher: (method, url, {body, required headers}) async {
          capturedBody = body;
          return _okResponse({'created': true});
        },
      );

      final res = await client.post('/properties', body: {'name': 'test'});

      expect(res.statusCode, 200);
      expect(res.body, {'created': true});
      expect(capturedBody, {'name': 'test'});
    });

    test('does not retry non-idempotent POST on server error', () async {
      var attempts = 0;
      final client = buildClient(
        dispatcher: (method, url, {body, required headers}) async {
          attempts++;
          return _response(500, {'error': 'boom'});
        },
      );

      await expectLater(
        client.post('/properties', body: {'name': 'test'}),
        throwsA(isA<ServerException>()),
      );
      expect(attempts, 1);
    });

    test('retries idempotent POST once on transient error', () async {
      var attempts = 0;
      final client = buildClient(
        dispatcher: (method, url, {body, required headers}) async {
          attempts++;
          if (attempts == 1) return _response(503, {'error': 'unavailable'});
          return _okResponse({'ok': true});
        },
      );

      final res = await client.post('/properties', body: {'id': 1}, idempotent: true);

      expect(attempts, 2);
      expect(res.statusCode, 200);
    });

    test('throws ApiException on 400', () async {
      final client = buildClient(
        dispatcher: (method, url, {body, required headers}) async =>
            _response(400, {'error': 'bad request'}),
      );

      await expectLater(client.post('/properties', body: {}), throwsA(isA<ApiException>()));
    });
  });

  group('ApiClient.put', () {
    test('returns ApiResponse on 200', () async {
      final client = buildClient(
        dispatcher: (method, url, {body, required headers}) async => _okResponse({'updated': true}),
      );

      final res = await client.put('/properties/1', body: {'name': 'new'});

      expect(res.statusCode, 200);
      expect(res.body, {'updated': true});
    });

    test('retries idempotent PUT once on transient error', () async {
      var attempts = 0;
      final client = buildClient(
        dispatcher: (method, url, {body, required headers}) async {
          attempts++;
          if (attempts == 1) return _response(500, {'error': 'boom'});
          return _okResponse({'ok': true});
        },
      );

      final res = await client.put('/properties/1', body: {'name': 'new'}, idempotent: true);

      expect(attempts, 2);
      expect(res.statusCode, 200);
    });
  });

  group('ApiClient.delete', () {
    test('returns ApiResponse on 200', () async {
      final client = buildClient(
        dispatcher: (method, url, {body, required headers}) async => _okResponse({'deleted': true}),
      );

      final res = await client.delete('/properties/1');

      expect(res.statusCode, 200);
      expect(res.body, {'deleted': true});
    });

    test('throws on 404', () async {
      final client = buildClient(
        dispatcher: (method, url, {body, required headers}) async =>
            _response(404, {'error': 'not found'}),
      );

      await expectLater(client.delete('/properties/1'), throwsA(isA<ApiException>()));
    });
  });

  group('ApiClient.patch', () {
    test('returns ApiResponse on 200', () async {
      final client = buildClient(
        dispatcher: (method, url, {body, required headers}) async => _okResponse({'patched': true}),
      );

      final res = await client.patch('/properties/1', body: {'field': 'value'});

      expect(res.statusCode, 200);
      expect(res.body, {'patched': true});
    });

    test('does not retry non-idempotent PATCH on server error', () async {
      var attempts = 0;
      final client = buildClient(
        dispatcher: (method, url, {body, required headers}) async {
          attempts++;
          return _response(500, {'error': 'boom'});
        },
      );

      await expectLater(
        client.patch('/properties/1', body: {'f': 'v'}),
        throwsA(isA<ServerException>()),
      );
      expect(attempts, 1);
    });
  });

  group('ApiClient.upload', () {
    test('returns ApiResponse on 200 with parsed body', () async {
      // Create a temp file so upload() doesn't fail on missing file.
      final tempFile = '/tmp/test_upload_${DateTime.now().millisecondsSinceEpoch}.txt';
      await File(tempFile).writeAsString('test content');

      addTearDown(() => File(tempFile).delete());
      final transport = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.headers['content-type'], startsWith('multipart/form-data; boundary='));
        expect(request.headers['Authorization'], 'Bearer test-token');
        expect(request.body, contains('test content'));
        expect(request.body, contains('name="file"'));
        return http.Response(
          '{"uploaded":true}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final client = ApiClient(
        baseUrl: 'http://localhost:9999',
        authProvider: authProvider,
        etagCache: etagCache,
        enablePerformanceMetrics: false,
        client: transport,
      );
      addTearDown(client.close);
      final response = await client.upload('/upload', field: 'file', filePath: tempFile);
      expect(response.body, {'uploaded': true});
    });

    Future<String> tempFile() async {
      final path = '/tmp/test_upload_${DateTime.now().microsecondsSinceEpoch}.txt';
      await File(path).writeAsString('test content');
      addTearDown(() => File(path).delete());
      return path;
    }

    test('a 401 gets one forced refresh and one retry, like every other request', () async {
      final path = await tempFile();
      var requests = 0;
      final transport = MockClient((request) async {
        requests++;
        if (requests == 1) {
          return http.Response(
            '{"error":{"code":"TOKEN_EXPIRED","message":"expired"}}',
            401,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          '{"uploaded":true}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final client = ApiClient(
        baseUrl: 'http://localhost:9999',
        authProvider: authProvider,
        etagCache: etagCache,
        enablePerformanceMetrics: false,
        client: transport,
      )..onUnauthorized = onUnauthorized;
      addTearDown(client.close);

      final response = await client.upload('/upload', field: 'file', filePath: path);

      expect(response.body, {'uploaded': true});
      expect(requests, 2);
      // One header for the first send and one forced refresh for the retry.
      expect(authProvider.getAuthHeaderCalls, 2);
    });

    test('a 401 that survives the refresh ends the session once, with the backend code', () async {
      final path = await tempFile();
      final events = <UnauthorizedEvent>[];
      onUnauthorized = (event) async => events.add(event);
      var requests = 0;
      final transport = MockClient((request) async {
        requests++;
        return http.Response(
          '{"error":{"code":"TOKEN_INVALID","message":"bad"}}',
          401,
          headers: {'content-type': 'application/json'},
        );
      });
      final client = ApiClient(
        baseUrl: 'http://localhost:9999',
        authProvider: authProvider,
        etagCache: etagCache,
        enablePerformanceMetrics: false,
        client: transport,
      )..onUnauthorized = onUnauthorized;
      addTearDown(client.close);

      await expectLater(
        client.upload('/upload', field: 'file', filePath: path),
        throwsA(isA<AuthenticationException>().having((e) => e.code, 'code', 'TOKEN_INVALID')),
      );

      expect(requests, 2);
      expect(events, hasLength(1));
      expect(events.single.error.endsSession, isTrue);
    });
  });

  group('ApiClient.unauthorized notification', () {
    test('fires onUnauthorized for session-critical 401 after refresh fails', () async {
      // Force refresh to fail so the 401 path triggers the notification.
      authProvider.throwOnRefresh = true;
      var unauthorizedCalls = 0;
      onUnauthorized = (_) async {
        unauthorizedCalls++;
      };

      final client = buildClient(
        dispatcher: (method, url, {body, required headers}) async =>
            _response(401, {'detail': 'unauthorized'}),
      );

      await expectLater(
        client.get('/users/profile', useCache: false),
        throwsA(isA<AuthenticationException>()),
      );
      // Allow the microtask-based notification to run.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(unauthorizedCalls, 1);
    });

    test('fires onUnauthorized for a 401 on any authenticated endpoint', () async {
      // The forced-refresh retry already filters transient cases, so a 401 that
      // survives it means the session is dead no matter which endpoint saw it.
      authProvider.throwOnRefresh = true;
      var unauthorizedCalls = 0;
      onUnauthorized = (_) async {
        unauthorizedCalls++;
      };

      final client = buildClient(
        dispatcher: (method, url, {body, required headers}) async =>
            _response(401, {'detail': 'unauthorized'}),
      );

      await expectLater(
        client.get('/properties', useCache: false),
        throwsA(isA<AuthenticationException>()),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(unauthorizedCalls, 1);
    });

    test('fires onUnauthorized when no auth header can be built', () async {
      // Dead refresh token: the request never leaves the device, so the only
      // signal the app gets is MISSING_AUTH_HEADER.
      authProvider.header = null;
      UnauthorizedEvent? captured;
      onUnauthorized = (event) async {
        captured = event;
      };

      var dispatched = 0;
      final client = buildClient(
        dispatcher: (method, url, {body, required headers}) async {
          dispatched++;
          return _okResponse({'ok': true});
        },
      );

      await expectLater(
        client.get('/properties', useCache: false),
        throwsA(
          isA<AuthenticationException>().having((e) => e.code, 'code', 'MISSING_AUTH_HEADER'),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(dispatched, 0, reason: 'request must not leave the device');
      expect(captured?.error.code, 'MISSING_AUTH_HEADER');
    });

    test('does not fire onUnauthorized when the refresh is unreachable', () async {
      // Offline with an expired token. The session may be perfectly valid; we
      // simply could not reach the auth server, so signing out would strand the
      // user with no way back in.
      authProvider.headerError = NetworkException(
        'Could not reach the authentication service.',
        code: AuthHeaderProvider.refreshUnreachableCode,
      );
      var unauthorizedCalls = 0;
      onUnauthorized = (_) async {
        unauthorizedCalls++;
      };

      final client = buildClient(
        dispatcher: (method, url, {body, required headers}) async => _okResponse({'ok': true}),
      );

      await expectLater(
        client.get('/properties', useCache: false),
        throwsA(
          isA<NetworkException>().having(
            (e) => e.code,
            'code',
            AuthHeaderProvider.refreshUnreachableCode,
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(unauthorizedCalls, 0, reason: 'losing signal must never sign the user out');
    });

    test('does not fire onUnauthorized for a 401 on an optional-auth request', () async {
      var unauthorizedCalls = 0;
      onUnauthorized = (_) async {
        unauthorizedCalls++;
      };

      final client = buildClient(
        dispatcher: (method, url, {body, required headers}) async =>
            _response(401, {'detail': 'unauthorized'}),
      );

      await expectLater(
        client.get('/properties/42', useCache: false, requireAuth: false),
        throwsA(isA<AuthenticationException>()),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(unauthorizedCalls, 0);
    });

    test('does not fire onUnauthorized when notifyUnauthorized is false', () async {
      authProvider.throwOnRefresh = true;
      var unauthorizedCalls = 0;
      onUnauthorized = (_) async {
        unauthorizedCalls++;
      };

      final client = buildClient(
        dispatcher: (method, url, {body, required headers}) async =>
            _response(401, {'detail': 'unauthorized'}),
      );

      await expectLater(
        client.get('/users/profile', useCache: false, notifyUnauthorized: false),
        throwsA(isA<AuthenticationException>()),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(unauthorizedCalls, 0);
    });

    test('cooldown prevents rapid duplicate unauthorized notifications', () async {
      authProvider.throwOnRefresh = true;
      var unauthorizedCalls = 0;
      onUnauthorized = (_) async {
        unauthorizedCalls++;
      };

      final client = buildClient(
        dispatcher: (method, url, {body, required headers}) async =>
            _response(401, {'detail': 'unauthorized'}),
      );

      await expectLater(
        client.get('/users/profile', useCache: false),
        throwsA(isA<AuthenticationException>()),
      );
      await expectLater(
        client.get('/users/profile', useCache: false, dedupe: false),
        throwsA(isA<AuthenticationException>()),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Second call within the 6s cooldown should be suppressed.
      // Note: if a previous test already triggered the cooldown, both calls
      // may be suppressed (0). The key assertion is that we never get 2.
      expect(unauthorizedCalls, lessThanOrEqualTo(1));
    });
  });

  group('ApiClient optional auth (requireAuth: false)', () {
    test('guest sends no Authorization header and never refreshes', () async {
      authProvider.cachedHeader = null;
      Map<String, String>? capturedHeaders;
      final client = buildClient(
        dispatcher: (method, url, {body, required headers}) async {
          capturedHeaders = headers;
          return _okResponse({'id': 42});
        },
      );

      final res = await client.get('/properties/42', useCache: false, requireAuth: false);

      expect(res.statusCode, 200);
      expect(capturedHeaders!.containsKey('Authorization'), isFalse);
      expect(authProvider.getAuthHeaderCalls, 0, reason: 'must not await a doomed refresh');
    });

    test('signed-in user still sends the Authorization header', () async {
      authProvider.cachedHeader = {'Authorization': 'Bearer fresh-token'};
      Map<String, String>? capturedHeaders;
      final client = buildClient(
        dispatcher: (method, url, {body, required headers}) async {
          capturedHeaders = headers;
          return _okResponse({'id': 42});
        },
      );

      await client.get('/properties/42', useCache: false, requireAuth: false);

      expect(capturedHeaders!['Authorization'], 'Bearer fresh-token');
      expect(authProvider.getAuthHeaderCalls, 0);
    });
  });

  group('ApiClient.clearCache', () {
    test('delegates to ETagCache.clear', () async {
      final client = buildClient(
        dispatcher: (method, url, {body, required headers}) async => _okResponse({'ok': true}),
      );

      await client.clearCache();

      verify(() => etagCache.clear()).called(1);
    });
  });

  group('HTTP transport and lifecycle', () {
    ApiClient withTransport(http.Client transport, {int timeoutSeconds = 15, int retries = 0}) {
      final client = ApiClient(
        baseUrl: 'https://example.com',
        authProvider: authProvider,
        etagCache: etagCache,
        client: transport,
        timeoutSeconds: timeoutSeconds,
        maxGetRetries: retries,
        enablePerformanceMetrics: false,
      );
      addTearDown(client.close);
      return client;
    }

    test('sends JSON and decodes UTF-8 through injected http client', () async {
      final client = withTransport(
        MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.toString(), 'https://example.com/api/v1/properties');
          expect(jsonDecode(request.body), {'title': 'घर'});
          expect(request.headers['Authorization'], 'Bearer test-token');
          return http.Response.bytes(
            utf8.encode('{"title":"घर"}'),
            201,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final result = await client.post('/properties', body: {'title': 'घर'});
      expect(result.statusCode, 201);
      expect(result.body, {'title': 'घर'});
    });

    test('preserves HTML widget responses', () async {
      final client = withTransport(
        MockClient(
          (_) async =>
              http.Response('<main>Widget</main>', 200, headers: {'content-type': 'text/html'}),
        ),
      );
      expect((await client.get('/agent/widgets/map', useCache: false)).body, '<main>Widget</main>');
    });

    test('malformed JSON is a typed failure and is not retried', () async {
      var calls = 0;
      final client = withTransport(
        MockClient((_) async {
          calls++;
          return http.Response('{bad', 200, headers: {'content-type': 'application/json'});
        }),
        retries: 2,
      );
      await expectLater(
        client.get('/properties', useCache: false),
        throwsA(isA<ApiException>().having((error) => error.code, 'code', 'MALFORMED_RESPONSE')),
      );
      expect(calls, 1);
    });

    test('retries an actual http connection failure within the GET budget', () async {
      var calls = 0;
      final client = withTransport(
        MockClient((_) async {
          if (++calls == 1) throw http.ClientException('socket unavailable');
          return http.Response('{"ok":true}', 200, headers: {'content-type': 'application/json'});
        }),
        retries: 1,
      );
      expect((await client.get('/properties', useCache: false)).body, {'ok': true});
      expect(calls, 2);
    });

    test('timeout aborts the underlying request', () async {
      final transport = _PendingHttpClient();
      final client = withTransport(transport, timeoutSeconds: 0);
      await expectLater(
        client.get('/properties', useCache: false),
        throwsA(isA<NetworkException>().having((error) => error.code, 'code', 'TIMEOUT')),
      );
      await transport.aborted.future;
      expect(transport.calls, 1);
    });

    test('close aborts active requests and closes the owned client once', () async {
      final transport = _PendingHttpClient();
      final client = withTransport(transport, retries: 2);
      final pending = client.get('/properties', useCache: false);
      final result = expectLater(
        pending,
        throwsA(isA<NetworkException>().having((error) => error.code, 'code', 'CANCELLED')),
      );
      await transport.started.future;
      client.close();
      client.close();
      await result;
      expect(transport.closeCalls, 1);
      expect(transport.calls, 1);
    });

    for (final clearCache in [false, true]) {
      test(
        'rejects late responses after ${clearCache ? 'cache clear' : 'account change'}',
        () async {
          final response = Completer<ApiResponse>();
          final started = Completer<void>();
          final client = buildClient(
            dispatcher: (method, url, {body, required headers}) {
              started.complete();
              return response.future;
            },
            maxGetRetries: 2,
          );
          final pending = client.get('/properties');
          final result = expectLater(
            pending,
            throwsA(isA<NetworkException>().having((error) => error.code, 'code', 'CANCELLED')),
          );
          await started.future;
          if (clearCache) {
            await client.clearCache();
          } else {
            authProvider.scope = 'user:next';
          }
          response.complete(
            const ApiResponse(statusCode: 200, body: {'private': true}, headers: {'etag': 'old'}),
          );
          await result;
          verifyNever(() => etagCache.cacheResponse(any(), any(), scope: any(named: 'scope')));
        },
      );
    }

    test('304 without a usable cache retries once without If-None-Match', () async {
      when(
        () => etagCache.read(any(), scope: any(named: 'scope')),
      ).thenAnswer((_) async => _cachedEntry(null, 'old'));
      var calls = 0;
      final client = buildClient(
        dispatcher: (method, url, {body, required headers}) async {
          if (++calls == 1) {
            expect(headers['If-None-Match'], 'old');
            return const ApiResponse(statusCode: 304);
          }
          expect(headers.containsKey('If-None-Match'), isFalse);
          return const ApiResponse(statusCode: 200, body: {'fresh': true});
        },
      );
      expect((await client.get('/properties')).body, {'fresh': true});
      expect(calls, 2);
    });
  });

  group('ApiClient.baseUrl normalization', () {
    test('strips trailing slash from baseUrl', () {
      final client = ApiClient(
        baseUrl: 'https://api.example.com/',
        authProvider: authProvider,
        etagCache: etagCache,
        enablePerformanceMetrics: false,
      );
      expect(client.baseUrl, 'https://api.example.com');
    });

    test('strips /api/v1 suffix from baseUrl', () {
      final client = ApiClient(
        baseUrl: 'https://api.example.com/api/v1',
        authProvider: authProvider,
        etagCache: etagCache,
        enablePerformanceMetrics: false,
      );
      expect(client.baseUrl, 'https://api.example.com');
    });

    test('defaults to api.360ghar.com when baseUrl is empty', () {
      final client = ApiClient(
        baseUrl: '',
        authProvider: authProvider,
        etagCache: etagCache,
        enablePerformanceMetrics: false,
      );
      expect(client.baseUrl, 'https://api.360ghar.com');
    });

    test('preserves baseUrl without trailing slash or api prefix', () {
      final client = ApiClient(
        baseUrl: 'https://api.example.com',
        authProvider: authProvider,
        etagCache: etagCache,
        enablePerformanceMetrics: false,
      );
      expect(client.baseUrl, 'https://api.example.com');
    });
  });

  group('ApiClient.buildUrlForTesting', () {
    test('appends query params to the URL', () {
      final client = ApiClient(
        baseUrl: 'https://api.example.com',
        authProvider: authProvider,
        etagCache: etagCache,
        enablePerformanceMetrics: false,
      );

      final url = client.buildUrlForTesting('/properties', queryParams: {'limit': 10});

      expect(url, contains('limit=10'));
      expect(url, contains('/api/v1/properties'));
    });

    test('skips null query param values', () {
      final client = ApiClient(
        baseUrl: 'https://api.example.com',
        authProvider: authProvider,
        etagCache: etagCache,
        enablePerformanceMetrics: false,
      );

      final url = client.buildUrlForTesting('/properties', queryParams: {'limit': null});

      expect(url, isNot(contains('limit')));
    });

    test('handles iterable query params', () {
      final client = ApiClient(
        baseUrl: 'https://api.example.com',
        authProvider: authProvider,
        etagCache: etagCache,
        enablePerformanceMetrics: false,
      );

      final url = client.buildUrlForTesting(
        '/properties',
        queryParams: {
          'type': <String>['rent', 'sale'],
        },
      );

      expect(url, contains('type=rent'));
      expect(url, contains('type=sale'));
    });
  });

  group('ApiResponse', () {
    test('isSuccess is true for 2xx status codes', () {
      final res = const ApiResponse(statusCode: 200, body: {}, headers: {});
      expect(res.isSuccess, isTrue);
    });

    test('isSuccess is true for 201', () {
      final res = const ApiResponse(statusCode: 201, body: {}, headers: {});
      expect(res.isSuccess, isTrue);
    });

    test('isSuccess is false for 3xx status codes', () {
      final res = const ApiResponse(statusCode: 304, body: {}, headers: {});
      expect(res.isSuccess, isFalse);
    });

    test('isSuccess is false for 4xx status codes', () {
      final res = const ApiResponse(statusCode: 404, body: {}, headers: {});
      expect(res.isSuccess, isFalse);
    });

    test('isSuccess is false for 5xx status codes', () {
      final res = const ApiResponse(statusCode: 500, body: {}, headers: {});
      expect(res.isSuccess, isFalse);
    });
  });
}

ApiResponse _okResponse(Map<String, dynamic> body) {
  return ApiResponse(
    statusCode: 200,
    body: body,
    headers: const <String, String>{'content-type': 'application/json'},
  );
}

ApiResponse _response(int statusCode, Map<String, dynamic> body) {
  return ApiResponse(
    statusCode: statusCode,
    body: body,
    headers: const <String, String>{'content-type': 'application/json'},
  );
}

/// A fake auth header provider that returns a configurable header without
/// needing a real Supabase session. Extends [AuthHeaderProvider] so the rest
/// of the class surface stays intact while only [getAuthHeader] is overridden.
class _FakeAuthHeaderProvider extends AuthHeaderProvider {
  _FakeAuthHeaderProvider() : super();
  Map<String, String>? header = {'Authorization': 'Bearer test-token'};
  String scope = 'user:test';

  @override
  String get requestScope => scope;

  /// The non-refreshing header used by optional-auth requests. Null models a
  /// guest (or an expired session), which must not trigger a refresh.
  Map<String, String>? cachedHeader;
  bool throwOnRefresh = false;
  int getAuthHeaderCalls = 0;

  /// Thrown from every [getAuthHeader] call, modelling a transient refresh
  /// failure that must propagate rather than degrade to a null header.
  Object? headerError;

  @override
  Future<Map<String, String>?> getAuthHeader({bool forceRefresh = false}) async {
    getAuthHeaderCalls++;
    final error = headerError;
    if (error != null) throw error;
    if (forceRefresh && throwOnRefresh) {
      throw Exception('refresh failed');
    }
    return header;
  }

  @override
  Map<String, String>? get cachedAuthHeader => cachedHeader;
}

/// Mocktail mock for [ETagCache] (a concrete class).
class MockETagCache extends Mock implements ETagCache {}

class _PendingHttpClient extends http.BaseClient {
  final started = Completer<void>();
  final aborted = Completer<void>();
  int calls = 0;
  int closeCalls = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    calls++;
    started.complete();
    await (request as http.Abortable).abortTrigger;
    aborted.complete();
    throw http.RequestAbortedException(request.url);
  }

  @override
  void close() => closeCalls++;
}

class _MockStorageScope extends Mock implements StorageScope {}

CachedEntry _cachedEntry(Object? body, String etag) {
  final now = DateTime.now();
  return CachedEntry(
    value: body,
    etag: etag,
    createdAt: now,
    freshUntil: now.add(const Duration(minutes: 5)),
    expiresAt: now.add(const Duration(hours: 24)),
    schemaVersion: 1,
  );
}
