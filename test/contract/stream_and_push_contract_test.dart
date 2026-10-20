// The assistant stream and the push payload, read from frames and payloads the backend itself
// produced (`tool/api_fixtures.py` writes `assistant.json` and `notifications.json` from the
// backend serializers). The stream goes through a real `SseClient` against a local server, then
// through `AssistantRepository.streamChat`.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/network/sse_client.dart';
import 'package:ghar360/core/routes/route_policy.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/assistant/data/assistant_repository.dart';
import 'package:ghar360/features/assistant/data/models/assistant_frame.dart';
import 'package:ghar360/features/assistant/presentation/widgets/tool_call_indicator.dart';
import 'contract_support.dart';

void main() {
  final assistant = asObject(apiFixture('assistant'));

  group('assistant stream', () {
    late HttpServer server;
    late SseClient sse;
    late AssistantRepository repository;
    late String body;
    var status = 200;

    setUp(() async {
      status = 200;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        await request.drain<void>();
        request.response.statusCode = status;
        request.response.headers.contentType = ContentType('text', 'event-stream');
        request.response.write(body);
        await request.response.close();
      });
      sse = SseClient(
        authProvider: ContractAuth(),
        baseUrl: 'http://${server.address.host}:${server.port}',
      );
      repository = AssistantRepository(
        sseClient: sse,
        apiClient: RecordingApi((_) => jsonResponse(null, status: 204)).client,
      );
    });

    tearDown(() async {
      sse.close();
      await server.close(force: true);
    });

    test('the recorded stream reads as typed frames, in order', () async {
      body = assistant['stream']! as String;

      final frames = await repository.streamChat(message: 'flats in Gurugram').toList();

      expect(frames.map((f) => f.runtimeType), [
        ConversationInfoFrame,
        TextChunkFrame,
        ToolCallStartFrame,
        ToolCallStartFrame,
        ToolCallEndFrame,
        ToolCallEndFrame,
        WidgetFrame,
        TextChunkFrame,
        DoneFrame,
      ]);
      expect((frames[0] as ConversationInfoFrame).conversationId, 42);
      expect((frames[1] as TextChunkFrame).text, 'Here are ');
      final ends = frames.whereType<ToolCallEndFrame>().toList();
      expect(ends.map((f) => (f.callId, f.success)), [('call_a', true), ('call_b', false)]);
      expect((frames.last as DoneFrame).responseText, 'Here are three options.');
      final widget = frames.whereType<WidgetFrame>().single;
      expect(widget.widgetName, 'PropertySearchWidget');
      expect(widget.structuredContent?['items'], isA<List>());
    });

    test('the recorded error stream is an error frame with a typed code, not raw text', () async {
      body = assistant['error_stream']! as String;

      final frames = await repository.streamChat(message: 'hello').toList();

      final error = frames.single as ErrorFrame;
      expect(error.code, AssistantErrorCode.agentError);
    });

    test('a 403 USER_INACTIVE answer ends the stream with its own code', () async {
      status = 403;
      body = '{"error":{"code":"USER_INACTIVE","message":"Account is inactive"}}';

      await expectLater(
        repository.streamChat(message: 'hello').toList(),
        throwsA(
          isA<AuthenticationException>()
              .having((e) => e.code, 'code', 'USER_INACTIVE')
              .having((e) => e.endsSession, 'endsSession', isTrue),
        ),
      );
    });

    test('a message over 4000 characters is not sent', () async {
      body = assistant['stream']! as String;

      await expectLater(
        repository.streamChat(message: 'x' * 4001).toList(),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('AssistantFrame.fromEvent', () {
    test('every recorded frame reads', () {
      for (final raw in assistant['frames']! as List) {
        final frame = asObject(raw);
        final event = SseEvent(event: frame['event']! as String, data: asObject(frame['data']));
        expect(AssistantFrame.fromEvent(event), isNotNull, reason: '${frame['event']}');
      }
    });

    SseEvent event(String name, Map<String, dynamic> data) => SseEvent(event: name, data: data);

    test('the recorded error frame reads with its typed code and fixed message', () {
      final recorded = asObject(assistant['error_frame']);
      final frame =
          AssistantFrame.fromEvent(
                SseEvent(event: recorded['event']! as String, data: asObject(recorded['data'])),
              )
              as ErrorFrame;

      expect(frame.code, AssistantErrorCode.agentError);
      expect(frame.message, 'The assistant could not finish this reply. Try again.');
    });

    test('a key the backend always sends is required with its type', () {
      for (final bad in [
        event('conversation_info', {'conversation_id': '42'}),
        event('conversation_info', {}),
        event('text_chunk', {'text': 1}),
        event('tool_call_start', {'tool': 'x'}),
        event('tool_call_end', {'call_id': 'a', 'tool': 'x'}),
        event('tool_call_end', {'call_id': 'a', 'tool': 'x', 'success': 'yes'}),
        event('widget', {'structured_content': {}}),
        event('widget', {'widget_name': 'W', 'structured_content': 'text'}),
        event('done', {}),
        event('error', {'code': 'AGENT_ERROR'}),
      ]) {
        expect(
          () => AssistantFrame.fromEvent(bad),
          throwsFormatException,
          reason: '${bad.event} ${bad.data}',
        );
      }
    });

    test('a frame name this app does not know is skipped, not an error of the reply', () {
      expect(AssistantFrame.fromEvent(event('fallback', {'reason': 'x'})), isNull);
    });

    test('a widget with no structured content reads with none', () {
      final frame =
          AssistantFrame.fromEvent(
                event('widget', {'widget_name': 'W', 'structured_content': null}),
              )
              as WidgetFrame;
      expect(frame.structuredContent, isNull);
    });

    test('an error code this app does not know reads as null, and the frame still reads', () {
      final frame =
          AssistantFrame.fromEvent(event('error', {'code': 'NEW_CODE', 'message': 'x'}))
              as ErrorFrame;
      expect(frame.code, isNull);
    });
  });

  group('push payload', () {
    final push = asObject(apiFixture('notifications'));

    test('a property push opens the property from route and property_id', () {
      final data = asObject(push['push_property']);

      final payload = PushPayload.fromData(data);

      expect(payload.route, '/property/12');
      expect(payload.typeKey, 'property_recommendation');
      expect(payload.propertyId, 12);
      expect(notificationDestination(data), '/property/12');
    });

    test('_meta is JSON text and reads as a map', () {
      final payload = PushPayload.fromData(asObject(push['push_property']));

      expect(payload.meta['type_key'], 'property_recommendation');
      expect(payload.meta['channel'], 'push');
    });

    test('a visits push opens the visits tab', () {
      expect(notificationDestination(asObject(push['push_visits'])), '/visits');
    });

    test('a push with a type and no route opens the place of the type', () {
      expect(notificationDestination(asObject(push['push_type_only'])), '/visits');
    });

    test('a route this app has no screen for opens nothing', () {
      expect(notificationDestination(asObject(push['push_unknown_route'])), isNull);
    });

    test('a broken _meta never blocks the route', () {
      final data = {...asObject(push['push_visits']), '_meta': '{broken'};

      expect(PushPayload.fromData(data).meta, isEmpty);
      expect(notificationDestination(data), '/visits');
    });

    test('the camelCase and deep_link keys of the old payload are not read', () {
      expect(notificationDestination({'propertyId': '12'}), isNull);
      expect(notificationDestination({'deep_link': 'ghar360://property/12'}), isNull);
    });
  });
  group('tool progress lines', () {
    final registered = (assistant['tool_names'] as List).cast<String>();

    test('every tool the backend registers has a line, and the table names no other tool', () {
      expect(registered, hasLength(52));
      expect(registered.toSet().difference(toolLabelKeys.keys.toSet()), isEmpty);
      expect(toolLabelKeys.keys.toSet().difference(registered.toSet()), isEmpty);
    });

    test('a tool that fetches a thing is not labelled as a different thing', () {
      expect(toolLabelKeys['bookings_cancel'], 'assistant_tool_executing');
      expect(toolLabelKeys['tenant_maintenance_list'], 'assistant_tool_executing');
      expect(toolLabelKeys['owner_properties_update'], 'assistant_tool_executing');
    });
  });
}
