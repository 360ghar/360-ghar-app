import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/network/sse_client.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/assistant/data/assistant_repository.dart';
import 'package:ghar360/features/assistant/data/models/assistant_frame.dart';
import 'package:ghar360/features/assistant/data/models/chat_message_model.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/api_fixtures.dart';
import '../../../helpers/mocks.dart';

void main() {
  late MockApiClient mockApiClient;
  late MockSseClient mockSseClient;
  late AssistantRepository repository;

  setUp(() {
    mockApiClient = MockApiClient();
    mockSseClient = MockSseClient();
    repository = AssistantRepository(sseClient: mockSseClient, apiClient: mockApiClient);
  });

  /// Convenience helper: builds an [ApiResponse] with the given body.
  ApiResponse mockResponse(dynamic body) {
    return ApiResponse(statusCode: 200, body: body, headers: {});
  }

  Map<String, dynamic> cursorPage(
    List<Object?> items, {
    String? nextCursor,
    int limit = 30,
    Map<String, dynamic> overrides = const {},
  }) => {
    'items': items,
    'next_cursor': nextCursor,
    'has_more': nextCursor != null,
    'limit': limit,
    'total': null,
    ...overrides,
  };

  Map<String, dynamic> message(int id) => {
    'id': id,
    'role': id.isEven ? 'assistant' : 'user',
    'content': 'm$id',
    'created_at': '2024-01-01T00:00:${id.toString().padLeft(2, '0')}Z',
  };

  Map<String, dynamic> conversation(int id) => {
    'id': id,
    'title': 'Conversation $id',
    'created_at': '2024-01-01T00:00:00Z',
    'updated_at': '2024-01-01T00:00:00Z',
    'message_count': 1,
  };

  group('AssistantRepository conversations', () {
    test('reads a CursorPage of conversations', () async {
      when(
        () => mockApiClient.get('/agent/conversations', queryParams: any(named: 'queryParams')),
      ).thenAnswer(
        (_) async => mockResponse(cursorPage([conversation(1), conversation(2)], nextCursor: 'n')),
      );

      final page = await repository.getConversations(limit: 2);

      expect(page.items.map((c) => c.id), [1, 2]);
      expect(page.nextCursor, 'n');
      expect(page.hasMore, isTrue);
      verify(
        () => mockApiClient.get('/agent/conversations', queryParams: {'limit': '2'}),
      ).called(1);
    });

    test('limit stays between 1 and 100', () async {
      when(
        () => mockApiClient.get('/agent/conversations', queryParams: any(named: 'queryParams')),
      ).thenAnswer((_) async => mockResponse(cursorPage([])));

      await repository.getConversations(limit: 500);

      verify(
        () => mockApiClient.get('/agent/conversations', queryParams: {'limit': '100'}),
      ).called(1);
    });

    test('the fixture page from the backend model parses', () async {
      final page = apiFixture('assistant')['conversations_page'];
      when(
        () => mockApiClient.get('/agent/conversations', queryParams: any(named: 'queryParams')),
      ).thenAnswer((_) async => mockResponse(page));

      final result = await repository.getConversations();

      expect(result.items.single.id, 42);
      expect(result.items.single.messageCount, 6);
      expect(result.nextCursor, isNotEmpty);
    });

    for (final payload in [
      null,
      {'message': 'invalid'},
      ['a bare list is not a CursorPage'],
      {'data': <Object?>[]},
    ]) {
      test('malformed conversations $payload fail instead of returning empty history', () async {
        when(
          () => mockApiClient.get('/agent/conversations', queryParams: any(named: 'queryParams')),
        ).thenAnswer((_) async => mockResponse(payload));
        await expectLater(
          repository.getConversations(),
          throwsA(isA<ApiException>().having((error) => error.code, 'code', 'MALFORMED_RESPONSE')),
        );
      });
    }

    test('a conversation row without an id or a date fails the page', () async {
      for (final key in ['id', 'created_at', 'updated_at']) {
        final row = conversation(1)..remove(key);
        when(
          () => mockApiClient.get('/agent/conversations', queryParams: any(named: 'queryParams')),
        ).thenAnswer((_) async => mockResponse(cursorPage([row])));
        await expectLater(
          repository.getConversations(),
          throwsA(isA<ApiException>().having((e) => e.code, 'code', 'MALFORMED_RESPONSE')),
          reason: 'missing $key',
        );
      }
    });

    test('getConversations propagates exceptions from ApiClient', () async {
      when(
        () => mockApiClient.get('/agent/conversations', queryParams: any(named: 'queryParams')),
      ).thenThrow(NetworkException('offline'));

      await expectLater(repository.getConversations(), throwsA(isA<NetworkException>()));
    });
  });

  group('AssistantRepository messages (the page route only)', () {
    test('reads the newest page and its older cursor', () async {
      when(
        () => mockApiClient.get(
          '/agent/conversations/7/messages/page',
          queryParams: any(named: 'queryParams'),
        ),
      ).thenAnswer(
        (_) async => mockResponse(cursorPage([message(3), message(4)], nextCursor: 'older')),
      );

      final page = await repository.getMessagesPage(7);

      expect(page.items.map((m) => m.content), ['m3', 'm4']);
      expect(page.nextCursor, 'older');
      expect(page.hasMore, isTrue);
      verify(
        () =>
            mockApiClient.get('/agent/conversations/7/messages/page', queryParams: {'limit': '30'}),
      ).called(1);
    });

    test('sends the cursor for an older page', () async {
      when(
        () => mockApiClient.get(any(), queryParams: any(named: 'queryParams')),
      ).thenAnswer((_) async => mockResponse(cursorPage([message(1)])));

      final page = await repository.getMessagesPage(7, cursor: 'older', limit: 10);

      expect(page.hasMore, isFalse);
      verify(
        () => mockApiClient.get(
          '/agent/conversations/7/messages/page',
          queryParams: {'limit': '10', 'cursor': 'older'},
        ),
      ).called(1);
    });

    test('never calls the removed bare messages route, even after a 404', () async {
      when(
        () => mockApiClient.get(any(), queryParams: any(named: 'queryParams')),
      ).thenThrow(ApiException('Not Found', statusCode: 404, code: 'NOT_FOUND'));

      await expectLater(
        repository.getMessagesPage(7),
        throwsA(isA<ApiException>().having((error) => error.statusCode, 'status', 404)),
      );

      verify(
        () => mockApiClient.get(
          '/agent/conversations/7/messages/page',
          queryParams: any(named: 'queryParams'),
        ),
      ).called(1);
      verifyNever(() => mockApiClient.get(any()));
    });

    test('limit stays between 1 and 100', () async {
      when(
        () => mockApiClient.get(any(), queryParams: any(named: 'queryParams')),
      ).thenAnswer((_) async => mockResponse(cursorPage([])));

      await repository.getMessagesPage(7, limit: 0);
      await repository.getMessagesPage(7, limit: 1000);

      verify(
        () =>
            mockApiClient.get('/agent/conversations/7/messages/page', queryParams: {'limit': '1'}),
      ).called(1);
      verify(
        () => mockApiClient.get(
          '/agent/conversations/7/messages/page',
          queryParams: {'limit': '100'},
        ),
      ).called(1);
    });

    test('an older page failure surfaces as the typed failure', () async {
      when(
        () => mockApiClient.get(any(), queryParams: any(named: 'queryParams')),
      ).thenThrow(ApiException('Invalid cursor', statusCode: 400, code: 'INVALID_CURSOR'));

      await expectLater(
        repository.getMessagesPage(7, cursor: 'stale'),
        throwsA(isA<ApiException>().having((error) => error.code, 'code', 'INVALID_CURSOR')),
      );
    });

    for (final payload in [
      null,
      <Object?>[],
      {'error': 'bad'},
      {'items': 'x', 'next_cursor': null, 'has_more': false, 'limit': 30, 'total': null},
    ]) {
      test('malformed messages $payload fail instead of returning empty history', () async {
        when(
          () => mockApiClient.get(any(), queryParams: any(named: 'queryParams')),
        ).thenAnswer((_) async => mockResponse(payload));
        await expectLater(
          repository.getMessagesPage(7),
          throwsA(isA<ApiException>().having((error) => error.code, 'code', 'MALFORMED_RESPONSE')),
        );
      });
    }

    test('a message row with an unknown role fails the page', () async {
      when(() => mockApiClient.get(any(), queryParams: any(named: 'queryParams'))).thenAnswer(
        (_) async => mockResponse(
          cursorPage([
            {...message(1), 'role': 'tool_result'},
          ]),
        ),
      );

      await expectLater(
        repository.getMessagesPage(7),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'MALFORMED_RESPONSE')),
      );
    });

    test('the fixture page from the backend model parses, widget rows included', () async {
      when(
        () => mockApiClient.get(any(), queryParams: any(named: 'queryParams')),
      ).thenAnswer((_) async => mockResponse(apiFixture('assistant')['messages_page']));

      final page = await repository.getMessagesPage(42);

      expect(page.items.map((m) => m.id), ['311', '312', '313']);
      expect(page.items.map((m) => m.role), [ChatRole.user, ChatRole.widget, ChatRole.assistant]);
      expect(page.items[1].widgetName, 'PropertySearchWidget');
      expect(page.items[1].widgetData, isNotNull);
      expect(page.nextCursor, isNotEmpty);
      expect(page.limit, 30);
    });
  });

  group('AssistantRepository.streamChat', () {
    test('turns SSE events into typed frames and skips an unknown frame name', () async {
      when(() => mockSseClient.postStream('/agent/chat', body: any(named: 'body'))).thenAnswer(
        (_) => Stream.fromIterable(const [
          SseEvent(event: 'conversation_info', data: {'conversation_id': 9}),
          SseEvent(event: 'fallback', data: {'provider': 'x'}),
          SseEvent(event: 'text_chunk', data: {'text': 'Hi'}),
          SseEvent(event: 'done', data: {'response_text': 'Hi'}),
        ]),
      );

      final frames = await repository.streamChat(message: 'hello', conversationId: 9).toList();

      expect(frames.map((f) => f.runtimeType), [ConversationInfoFrame, TextChunkFrame, DoneFrame]);
      verify(
        () => mockSseClient.postStream(
          '/agent/chat',
          body: {'message': 'hello', 'conversation_id': 9},
        ),
      ).called(1);
    });

    test('omits conversation_id for a new conversation: the body has only declared keys', () async {
      when(
        () => mockSseClient.postStream('/agent/chat', body: any(named: 'body')),
      ).thenAnswer((_) => const Stream<SseEvent>.empty());

      await repository.streamChat(message: 'hello').toList();

      verify(() => mockSseClient.postStream('/agent/chat', body: {'message': 'hello'})).called(1);
    });

    test('refuses an empty message or one over 4000 characters before any request', () async {
      await expectLater(
        repository.streamChat(message: '').toList(),
        throwsA(isA<ValidationException>()),
      );
      await expectLater(
        repository.streamChat(message: 'x' * 4001).toList(),
        throwsA(isA<ValidationException>()),
      );
      verifyNever(() => mockSseClient.postStream(any(), body: any(named: 'body')));
    });

    test(
      'a frame that does not match the contract ends the stream with a FormatException',
      () async {
        when(() => mockSseClient.postStream('/agent/chat', body: any(named: 'body'))).thenAnswer(
          (_) => Stream.fromIterable(const [
            SseEvent(event: 'tool_call_end', data: {'call_id': 'a', 'tool': 'x'}),
          ]),
        );

        await expectLater(repository.streamChat(message: 'hello').toList(), throwsFormatException);
      },
    );

    test('request failures pass through as typed exceptions', () async {
      when(
        () => mockSseClient.postStream('/agent/chat', body: any(named: 'body')),
      ).thenAnswer((_) => Stream<SseEvent>.error(RateLimitException('slow down')));

      await expectLater(
        repository.streamChat(message: 'hello').toList(),
        throwsA(isA<RateLimitException>()),
      );
    });
  });

  group('AssistantRepository widgets and deletes', () {
    test('getWidgetHtml caches successful response', () async {
      when(
        () => mockApiClient.get('/agent/widgets/map_widget'),
      ).thenAnswer((_) async => mockResponse('<div>Map</div>'));

      final result1 = await repository.getWidgetHtml('map_widget');
      expect(result1, '<div>Map</div>');

      final result2 = await repository.getWidgetHtml('map_widget');
      expect(result2, '<div>Map</div>');

      verify(() => mockApiClient.get('/agent/widgets/map_widget')).called(1);
    });

    test('getWidgetHtml does not cache failures, allows retry', () async {
      when(
        () => mockApiClient.get('/agent/widgets/failing_widget'),
      ).thenThrow(Exception('Server error'));

      final result1 = await repository.getWidgetHtml('failing_widget');
      expect(result1, isNull);

      when(
        () => mockApiClient.get('/agent/widgets/failing_widget'),
      ).thenAnswer((_) async => mockResponse('<div>Recovered</div>'));

      final result2 = await repository.getWidgetHtml('failing_widget');
      expect(result2, '<div>Recovered</div>');

      verify(() => mockApiClient.get('/agent/widgets/failing_widget')).called(2);
    });

    test('deleteConversation returns true on success (204, no body)', () async {
      when(
        () => mockApiClient.delete('/agent/conversations/15'),
      ).thenAnswer((_) async => const ApiResponse(statusCode: 204));

      final result = await repository.deleteConversation(15);

      expect(result, isTrue);
      verify(() => mockApiClient.delete('/agent/conversations/15')).called(1);
    });

    test('deleteConversation returns false on error', () async {
      when(
        () => mockApiClient.delete('/agent/conversations/15'),
      ).thenThrow(Exception('Delete failed'));

      final result = await repository.deleteConversation(15);

      expect(result, isFalse);
    });
  });
}
