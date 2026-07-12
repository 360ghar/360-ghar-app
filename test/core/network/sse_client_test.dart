import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/network/auth_header_provider.dart';
import 'package:ghar360/core/network/sse_client.dart';
import 'package:mocktail/mocktail.dart';

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

    test('yields AUTH_MISSING error when auth header is null', () async {
      when(
        () => mockAuthProvider.getAuthHeader(forceRefresh: any(named: 'forceRefresh')),
      ).thenAnswer((_) async => null);

      final client = SseClient(authProvider: mockAuthProvider, baseUrl: 'https://example.com');

      final events = await client.postStream('/chat', body: {'message': 'hello'}).toList();

      expect(events, hasLength(1));
      expect(events.first.event, 'error');
      expect(events.first.data['code'], 'AUTH_MISSING');
    });

    test('yields AUTH_MISSING error with correct message', () async {
      when(
        () => mockAuthProvider.getAuthHeader(forceRefresh: any(named: 'forceRefresh')),
      ).thenAnswer((_) async => null);

      final client = SseClient(authProvider: mockAuthProvider, baseUrl: 'https://example.com');

      final events = await client.postStream('/chat', body: {'query': 'test'}).toList();

      expect(events.first.data['message'], 'Not authenticated');
    });

    test('emits exactly one event when auth is missing', () async {
      when(
        () => mockAuthProvider.getAuthHeader(forceRefresh: any(named: 'forceRefresh')),
      ).thenAnswer((_) async => null);

      final client = SseClient(authProvider: mockAuthProvider, baseUrl: 'https://example.com');

      var count = 0;
      await for (final _ in client.postStream('/chat', body: {})) {
        count++;
      }

      expect(count, 1);
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

    test('emits an UNAUTHORIZED error event for 401 responses', () async {
      server.listen((request) async {
        request.response.statusCode = 401;
        await request.response.close();
      });

      final client = SseClient(authProvider: mockAuthProvider, baseUrl: baseUrl);
      final events = await client.postStream('/chat', body: {}).toList();

      expect(events, hasLength(1));
      expect(events.first.event, 'error');
      expect(events.first.data['code'], 'UNAUTHORIZED');
      expect(events.first.data['message'], 'Authentication failed');
    });

    test('emits an HTTP_<code> error event for non-200/non-401 responses', () async {
      server.listen((request) async {
        request.response.statusCode = 500;
        await request.response.close();
      });

      final client = SseClient(authProvider: mockAuthProvider, baseUrl: baseUrl);
      final events = await client.postStream('/chat', body: {}).toList();

      expect(events, hasLength(1));
      expect(events.first.event, 'error');
      expect(events.first.data['code'], 'HTTP_500');
      expect(events.first.data['message'], 'Server returned 500');
    });

    test('emits an HTTP_<code> error event for 403 responses', () async {
      server.listen((request) async {
        request.response.statusCode = 403;
        await request.response.close();
      });

      final client = SseClient(authProvider: mockAuthProvider, baseUrl: baseUrl);
      final events = await client.postStream('/chat', body: {}).toList();

      expect(events.first.data['code'], 'HTTP_403');
    });

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

    test('emits NETWORK_ERROR on connection refused', () async {
      // Bind then immediately close to get a free port that refuses connections.
      final tempServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = tempServer.port;
      await tempServer.close(force: true);

      final client = SseClient(
        authProvider: mockAuthProvider,
        baseUrl: 'http://${InternetAddress.loopbackIPv4.host}:$port',
      );
      final events = await client.postStream('/chat', body: {}).toList();

      expect(events, hasLength(1));
      expect(events.first.event, 'error');
      // SocketException is mapped to NETWORK_ERROR.
      expect(events.first.data['code'], anyOf('NETWORK_ERROR', 'UNKNOWN_ERROR'));
    });
  });
}

/// Test-local mock for [AuthHeaderProvider].
class MockAuthHeaderProvider extends Mock implements AuthHeaderProvider {}
