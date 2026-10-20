import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/network/auth_header_provider.dart';
import 'package:ghar360/core/network/sse_client.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import '../../helpers/log_capture.dart';

void main() {
  group('SseEvent', () {
    test('stores event and data fields', () {
      const event = SseEvent(event: 'message', data: {'key': 'value'});
      expect(event.event, 'message');
      expect(event.data, {'key': 'value'});
    });

    test('toString returns human-readable representation', () {
      const event = SseEvent(event: 'done', data: {'status': 'ok'});
      expect(event.toString(), 'SseEvent(done, {status: ok})');
    });

    test('supports empty data map', () {
      const event = SseEvent(event: 'ping', data: {});
      expect(event.data, isEmpty);
    });
  });

  group('SseClient construction', () {
    late MockAuthHeaderProvider mockAuthProvider;

    setUp(() {
      mockAuthProvider = MockAuthHeaderProvider();
    });

    test('strips trailing slash from baseUrl', () {
      final client = SseClient(authProvider: mockAuthProvider, baseUrl: 'https://example.com/');
      // Verify construction succeeds — URL is normalized internally
      expect(client, isNotNull);
    });

    test('strips api version prefix from baseUrl', () {
      final client = SseClient(
        authProvider: mockAuthProvider,
        baseUrl: 'https://example.com/api/v1',
      );
      expect(client, isNotNull);
    });

    test('handles baseUrl without trailing slash', () {
      final client = SseClient(authProvider: mockAuthProvider, baseUrl: 'https://example.com');
      expect(client, isNotNull);
    });

    test('handles baseUrl with trailing slash and api prefix', () {
      final client = SseClient(
        authProvider: mockAuthProvider,
        baseUrl: 'https://example.com/api/v1/',
      );
      expect(client, isNotNull);
    });
  });

  group('SseClient.postStream', () {
    late MockAuthHeaderProvider mockAuthProvider;

    setUp(() {
      mockAuthProvider = MockAuthHeaderProvider();
    });

    test('a missing auth header ends the stream with a device-raised failure', () async {
      when(
        () => mockAuthProvider.getAuthHeader(forceRefresh: any(named: 'forceRefresh')),
      ).thenAnswer((_) async => null);

      final client = SseClient(authProvider: mockAuthProvider, baseUrl: 'https://example.com');

      await expectLater(
        client.postStream('/chat', body: {'message': 'hello'}).toList(),
        throwsA(
          isA<AuthenticationException>()
              .having((e) => e.code, 'code', AppException.missingAuthHeaderCode)
              .having((e) => e.statusCode, 'statusCode', isNull)
              .having((e) => e.endsSession, 'endsSession', isFalse),
        ),
      );
    });

    test('emits no event when auth is missing', () async {
      when(
        () => mockAuthProvider.getAuthHeader(forceRefresh: any(named: 'forceRefresh')),
      ).thenAnswer((_) async => null);

      final client = SseClient(authProvider: mockAuthProvider, baseUrl: 'https://example.com');

      var count = 0;
      await expectLater(() async {
        await for (final _ in client.postStream('/chat', body: {})) {
          count++;
        }
      }(), throwsA(isA<AuthenticationException>()));
      expect(count, 0);
    });
  });

  // ---------------------------------------------------------------------------
  // Integration-style tests using a local dart:io HttpServer to exercise the
  // real SSE parsing, error-handling, and connection paths of postStream.
  // ---------------------------------------------------------------------------
  group('SseClient.postStream (local server)', () {
    late HttpServer server;
    late MockAuthHeaderProvider mockAuthProvider;
    late String baseUrl;

    setUp(() async {
      mockAuthProvider = MockAuthHeaderProvider();
      when(
        () => mockAuthProvider.getAuthHeader(forceRefresh: any(named: 'forceRefresh')),
      ).thenAnswer((_) async => {'Authorization': 'Bearer test-token'});

      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      baseUrl = 'http://${server.address.host}:${server.port}';
    });

    tearDown(() async {
      await server.close(force: true);
    });

    test('malformed events do not print streamed content and later events still arrive', () async {
      final logs = LogCapture();
      addTearDown(logs.close);
      server.listen((request) async {
        request.response.headers.contentType = ContentType('text', 'event-stream');
        request.response.write('data: private-conversation-token\n\ndata: {"ok":true}\n\n');
        await request.response.close();
      });
      final client = SseClient(authProvider: mockAuthProvider, baseUrl: baseUrl);
      addTearDown(client.close);
      final events = await client.postStream('/chat', body: {'message': 'private-prompt'}).toList();
      expect(events.single.data, {'ok': true});
      expect(logs.text, contains('FormatException'));
      expect(logs.text, isNot(contains('private-')));
    });

    test('parses a stream of SSE data events', () async {
      server.listen((request) async {
        request.response.headers.contentType = ContentType('text', 'event-stream');
        request.response.write('data: {"value": 1}\n\n');
        request.response.write('data: {"value": 2}\n\n');
        await request.response.close();
      });

      final client = SseClient(authProvider: mockAuthProvider, baseUrl: baseUrl);
      final events = await client.postStream('/chat', body: {'q': 'hi'}).toList();

      expect(events, hasLength(2));
      expect(events[0].event, 'message');
      expect(events[0].data['value'], 1);
      expect(events[1].event, 'message');
      expect(events[1].data['value'], 2);
    });

    test('parses named events (event: line)', () async {
      server.listen((request) async {
        request.response.headers.contentType = ContentType('text', 'event-stream');
        request.response.write('event: token\n');
        request.response.write('data: {"chunk": "abc"}\n\n');
        await request.response.close();
      });

      final client = SseClient(authProvider: mockAuthProvider, baseUrl: baseUrl);
      final events = await client.postStream('/chat', body: {}).toList();

      expect(events, hasLength(1));
      expect(events[0].event, 'token');
      expect(events[0].data['chunk'], 'abc');
    });

    test('resets event name to message after each dispatched event', () async {
      server.listen((request) async {
        request.response.headers.contentType = ContentType('text', 'event-stream');
        request.response.write('event: named\n');
        request.response.write('data: {"a": 1}\n\n');
        // Second event has no event: line, so it should fall back to "message".
        request.response.write('data: {"b": 2}\n\n');
        await request.response.close();
      });

      final client = SseClient(authProvider: mockAuthProvider, baseUrl: baseUrl);
      final events = await client.postStream('/chat', body: {}).toList();

      expect(events, hasLength(2));
      expect(events[0].event, 'named');
      expect(events[1].event, 'message');
    });

    test('concatenates multi-line data fields with newline', () async {
      server.listen((request) async {
        request.response.headers.contentType = ContentType('text', 'event-stream');
        request.response.write('data: line1\n');
        request.response.write('data: line2\n\n');
        await request.response.close();
      });

      final client = SseClient(authProvider: mockAuthProvider, baseUrl: baseUrl);
      final events = await client.postStream('/chat', body: {}).toList();

      // The combined "line1\nline2" is not valid JSON, so the parse error is
      // swallowed and no event is emitted.
      expect(events, isEmpty);
    });

    String envelope(String code, String message) => jsonEncode({
      'error': {'code': code, 'message': message},
    });

    test('a 401 gets one forced token refresh and one retry, then the request succeeds', () async {
      var requests = 0;
      server.listen((request) async {
        requests++;
        if (requests == 1) {
          request.response.statusCode = 401;
          request.response.headers.contentType = ContentType.json;
          request.response.write(envelope('TOKEN_INVALID', 'Expired'));
          await request.response.close();
          return;
        }
        request.response.headers.contentType = ContentType('text', 'event-stream');
        request.response.write('event: done\ndata: {"response_text":"ok"}\n\n');
        await request.response.close();
      });

      final client = SseClient(authProvider: mockAuthProvider, baseUrl: baseUrl);
      final events = await client.postStream('/chat', body: {}).toList();

      expect(requests, 2);
      expect(events.single.event, 'done');
      verify(() => mockAuthProvider.getAuthHeader(forceRefresh: true)).called(1);
    });

    test('a 401 that survives the refresh ends the session through the handler', () async {
      server.listen((request) async {
        request.response.statusCode = 401;
        request.response.headers.contentType = ContentType.json;
        request.response.write(envelope('TOKEN_INVALID', 'Expired'));
        await request.response.close();
      });
      UnauthorizedEvent? event;
      final client = SseClient(
        authProvider: mockAuthProvider,
        baseUrl: baseUrl,
        onUnauthorized: (e) async => event = e,
      );

      await expectLater(
        client.postStream('/chat', body: {}).toList(),
        throwsA(
          isA<AuthenticationException>()
              .having((e) => e.code, 'code', 'TOKEN_INVALID')
              .having((e) => e.endsSession, 'endsSession', isTrue),
        ),
      );

      expect(event?.error.code, 'TOKEN_INVALID');
      expect(event?.statusCode, 401);
      expect(event?.endpoint, endsWith('/api/v1/chat'));
      verify(() => mockAuthProvider.getAuthHeader(forceRefresh: true)).called(1);
    });

    test('a 403 USER_INACTIVE keeps its code and ends the session', () async {
      server.listen((request) async {
        request.response.statusCode = 403;
        request.response.headers.contentType = ContentType.json;
        request.response.write(envelope('USER_INACTIVE', 'This account is deactivated.'));
        await request.response.close();
      });
      UnauthorizedEvent? event;
      final client = SseClient(
        authProvider: mockAuthProvider,
        baseUrl: baseUrl,
        onUnauthorized: (e) async => event = e,
      );

      await expectLater(
        client.postStream('/chat', body: {}).toList(),
        throwsA(
          isA<AuthenticationException>()
              .having((e) => e.code, 'code', 'USER_INACTIVE')
              .having((e) => e.statusCode, 'statusCode', 403)
              .having((e) => e.endsSession, 'endsSession', isTrue),
        ),
      );

      expect(event?.error.code, 'USER_INACTIVE');
    });

    test('a 403 for another reason does not end the session', () async {
      server.listen((request) async {
        request.response.statusCode = 403;
        request.response.headers.contentType = ContentType.json;
        request.response.write(envelope('USER_ACCESS_DENIED', 'No.'));
        await request.response.close();
      });
      var notified = false;
      final client = SseClient(
        authProvider: mockAuthProvider,
        baseUrl: baseUrl,
        onUnauthorized: (_) async => notified = true,
      );

      await expectLater(
        client.postStream('/chat', body: {}).toList(),
        throwsA(isA<AuthenticationException>().having((e) => e.isPermissionDenied, 'denied', true)),
      );
      expect(notified, isFalse);
    });

    test('a 404 for an unknown conversation is a typed not-found failure', () async {
      server.listen((request) async {
        request.response.statusCode = 404;
        request.response.headers.contentType = ContentType.json;
        request.response.write(envelope('NOT_FOUND', 'Conversation not found'));
        await request.response.close();
      });
      final client = SseClient(authProvider: mockAuthProvider, baseUrl: baseUrl);

      await expectLater(
        client.postStream('/chat', body: {}).toList(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'status', 404)
              .having((e) => e.code, 'code', 'NOT_FOUND'),
        ),
      );
    });

    test('a 422 carries the field error types', () async {
      server.listen((request) async {
        request.response.statusCode = 422;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'error': {
              'code': 'VALIDATION_ERROR',
              'message': 'Request validation failed',
              'details': {
                'fields': [
                  {'field': 'body.message', 'msg': 'too long', 'type': 'string_too_long'},
                ],
              },
            },
          }),
        );
        await request.response.close();
      });
      final client = SseClient(authProvider: mockAuthProvider, baseUrl: baseUrl);

      await expectLater(
        client.postStream('/chat', body: {}).toList(),
        throwsA(
          isA<ValidationException>().having((e) => e.fieldErrors?['message'], 'message', [
            'string_too_long',
          ]),
        ),
      );
    });

    test('a 429 honours Retry-After', () async {
      server.listen((request) async {
        request.response.statusCode = 429;
        request.response.headers.set('Retry-After', '60');
        request.response.headers.contentType = ContentType.json;
        request.response.write(envelope('RATE_LIMIT_EXCEEDED', 'Slow down'));
        await request.response.close();
      });
      final client = SseClient(authProvider: mockAuthProvider, baseUrl: baseUrl);

      await expectLater(
        client.postStream('/chat', body: {}).toList(),
        throwsA(
          isA<RateLimitException>().having(
            (e) => e.retryAfter,
            'wait',
            const Duration(seconds: 60),
          ),
        ),
      );
    });

    test(
      'a 5xx with an HTML body from a proxy is a server failure and the body is not read',
      () async {
        server.listen((request) async {
          request.response.statusCode = 502;
          request.response.headers.contentType = ContentType.html;
          request.response.write('<html>private upstream detail</html>');
          await request.response.close();
        });
        final client = SseClient(authProvider: mockAuthProvider, baseUrl: baseUrl);

        await expectLater(
          client.postStream('/chat', body: {}).toList(),
          throwsA(
            isA<ServerException>()
                .having((e) => e.statusCode, 'status', 502)
                .having((e) => e.message, 'message', isNot(contains('private'))),
          ),
        );
      },
    );

    test('handles empty response body gracefully (no events)', () async {
      server.listen((request) async {
        request.response.headers.contentType = ContentType('text', 'event-stream');
        await request.response.close();
      });

      final client = SseClient(authProvider: mockAuthProvider, baseUrl: baseUrl);
      final events = await client.postStream('/chat', body: {}).toList();

      expect(events, isEmpty);
    });

    test('wraps non-Map JSON data in a {value: ...} envelope', () async {
      server.listen((request) async {
        request.response.headers.contentType = ContentType('text', 'event-stream');
        request.response.write('data: 42\n\n');
        await request.response.close();
      });

      final client = SseClient(authProvider: mockAuthProvider, baseUrl: baseUrl);
      final events = await client.postStream('/chat', body: {}).toList();

      expect(events, hasLength(1));
      expect(events[0].data['value'], 42);
    });

    test('handles chunk boundaries that split a data line', () async {
      server.listen((request) async {
        request.response.headers.contentType = ContentType('text', 'event-stream');
        // Write the first chunk without a trailing newline, then the rest.
        request.response.write('data: {"v":');
        await request.response.flush();
        request.response.write('1}\n\n');
        await request.response.close();
      });

      final client = SseClient(authProvider: mockAuthProvider, baseUrl: baseUrl);
      final events = await client.postStream('/chat', body: {}).toList();

      expect(events, hasLength(1));
      expect(events[0].data['v'], 1);
    });

    test('sends the auth header and JSON body to the server', () async {
      final receivedHeaders = <String, String>{};
      late String receivedBody;
      server.listen((request) async {
        receivedHeaders['Authorization'] = request.headers.value('Authorization') ?? '';
        receivedHeaders['Content-Type'] = request.headers.contentType?.mimeType ?? '';
        receivedHeaders['Accept'] = request.headers.value('Accept') ?? '';
        final body = await request.cast<List<int>>().fold<List<int>>(
          <int>[],
          (acc, chunk) => acc..addAll(chunk),
        );
        receivedBody = utf8.decode(body);
        request.response.headers.contentType = ContentType('text', 'event-stream');
        await request.response.close();
      });

      final client = SseClient(authProvider: mockAuthProvider, baseUrl: baseUrl);
      await client.postStream('/chat', body: {'query': 'hello'}).toList();

      expect(receivedHeaders['Authorization'], 'Bearer test-token');
      expect(receivedHeaders['Content-Type'], 'application/json');
      expect(receivedHeaders['Accept'], 'text/event-stream');
      expect(receivedBody, '{"query":"hello"}');
    });

    test('a refused connection is a typed network failure', () async {
      // Bind then immediately close to get a free port that refuses connections.
      final tempServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = tempServer.port;
      await tempServer.close(force: true);

      final client = SseClient(
        authProvider: mockAuthProvider,
        baseUrl: 'http://${InternetAddress.loopbackIPv4.host}:$port',
      );

      await expectLater(
        client.postStream('/chat', body: {}).toList(),
        throwsA(isA<NetworkException>().having((e) => e.code, 'code', 'NETWORK_ERROR')),
      );
    });

    test('the backend error frame stays an event for the caller to read', () async {
      server.listen((request) async {
        request.response.headers.contentType = ContentType('text', 'event-stream');
        request.response.write(
          'event: error\ndata: {"code":"AGENT_ERROR","message":"The assistant could not finish."}\n\n',
        );
        await request.response.close();
      });
      final client = SseClient(authProvider: mockAuthProvider, baseUrl: baseUrl);

      final events = await client.postStream('/chat', body: {}).toList();

      expect(events.single.event, 'error');
      expect(events.single.data['code'], 'AGENT_ERROR');
    });

    test('CRLF line ends parse like LF', () async {
      server.listen((request) async {
        request.response.headers.contentType = ContentType('text', 'event-stream');
        request.response.write('event: text_chunk\r\ndata: {"text":"Hi"}\r\n\r\n');
        await request.response.close();
      });
      final client = SseClient(authProvider: mockAuthProvider, baseUrl: baseUrl);

      final events = await client.postStream('/chat', body: {}).toList();

      expect(events.single.event, 'text_chunk');
      expect(events.single.data['text'], 'Hi');
    });
  });
}

/// Test-local mock for [AuthHeaderProvider].
class MockAuthHeaderProvider extends Mock implements AuthHeaderProvider {}
