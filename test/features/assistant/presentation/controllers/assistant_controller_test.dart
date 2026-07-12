import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/network/sse_client.dart';
import 'package:ghar360/features/assistant/data/assistant_repository.dart';
import 'package:ghar360/features/assistant/data/models/chat_message_model.dart';
import 'package:ghar360/features/assistant/data/models/conversation_model.dart';
import 'package:ghar360/features/assistant/presentation/controllers/assistant_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/getx_test_binding.dart';
import '../../../../helpers/mocks.dart';

void main() {
  late MockAssistantRepository mockRepository;
  late MockSseClient mockSseClient;

  setUp(() {
    GetxTestBinding.init();
    mockRepository = MockAssistantRepository();
    mockSseClient = MockSseClient();
    GetxTestBinding.bind()
      ..register<AssistantRepository>(mockRepository)
      ..register<SseClient>(mockSseClient);
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  AssistantController createController() {
    final c = AssistantController();
    c.onInit();
    return c;
  }

  /// Creates a [ConversationModel] with sensible defaults for tests.
  ConversationModel testConversation({required int id, String? title, int messageCount = 0}) {
    return ConversationModel(
      id: id,
      title: title ?? 'Conversation $id',
      createdAt: DateTime(2024, 1, id),
      updatedAt: DateTime(2024, 1, id),
      messageCount: messageCount,
    );
  }

  group('AssistantController', () {
    // ── sendMessage ─────────────────────────────────────────────────────

    test('sendMessage adds user message and assistant placeholder, sets streaming', () {
      final streamController = StreamController<SseEvent>();
      when(
        () => mockRepository.streamChat(message: 'hello', conversationId: null),
      ).thenAnswer((_) => streamController.stream);

      final controller = createController();
      controller.sendMessage('hello');

      expect(controller.messages.length, 2);
      expect(controller.messages[0].role, ChatRole.user);
      expect(controller.messages[0].content, 'hello');
      expect(controller.messages[1].role, ChatRole.assistant);
      expect(controller.messages[1].isStreaming, isTrue);
      expect(controller.isStreaming.value, isTrue);

      streamController.close();
    });

    // ── selectConversation (success) ─────────────────────────────────────

    test('selectConversation loads messages on success', () async {
      final msgs = [
        ChatMessageModel(
          id: '1',
          role: ChatRole.user,
          content: 'Hi',
          timestamp: DateTime(2024, 1, 1),
        ),
        ChatMessageModel(
          id: '2',
          role: ChatRole.assistant,
          content: 'Hello!',
          timestamp: DateTime(2024, 1, 2),
        ),
      ];
      when(() => mockRepository.getConversationMessages(5)).thenAnswer((_) async => msgs);

      final controller = createController();
      await controller.selectConversation(5);

      expect(controller.conversationId.value, 5);
      expect(controller.messages.length, 2);
      expect(controller.messages[0].content, 'Hi');
      expect(controller.messages[1].content, 'Hello!');
    });

    // ── selectConversation (error) ───────────────────────────────────────

    test('selectConversation handles error gracefully', () async {
      when(() => mockRepository.getConversationMessages(99)).thenThrow(Exception('Network error'));

      final controller = createController();
      await controller.selectConversation(99);

      // conversationId is set even on error.
      expect(controller.conversationId.value, 99);
      // Messages are cleared then error returns [] from repository.
      expect(controller.messages, isEmpty);
    });

    // ── loadConversations (success) ──────────────────────────────────────

    test('loadConversations populates list on success', () async {
      final page = ConversationsPage(
        items: [
          testConversation(id: 1, title: 'First'),
          testConversation(id: 2, title: 'Second'),
        ],
        hasMore: true,
        nextCursor: 'cursor_abc',
      );
      when(() => mockRepository.getConversations()).thenAnswer((_) async => page);

      final controller = createController();
      await controller.loadConversations();

      expect(controller.conversations.length, 2);
      expect(controller.conversations[0].title, 'First');
      expect(controller.conversations[1].title, 'Second');
      expect(controller.conversationsNextCursor.value, 'cursor_abc');
      expect(controller.conversationsHasMore.value, isTrue);
      expect(controller.isLoadingConversations.value, isFalse);
      expect(controller.conversationsError.value, isFalse);
    });

    // ── loadConversations (error) ────────────────────────────────────────

    test('loadConversations sets error flag on failure', () async {
      when(() => mockRepository.getConversations()).thenThrow(Exception('Server down'));

      final controller = createController();
      await controller.loadConversations();

      expect(controller.conversations, isEmpty);
      expect(controller.conversationsError.value, isTrue);
      expect(controller.isLoadingConversations.value, isFalse);
    });

    // ── deleteConversation (success) ─────────────────────────────────────

    test('deleteConversation removes item from list on success', () async {
      when(() => mockRepository.deleteConversation(3)).thenAnswer((_) async => true);

      final controller = createController();
      controller.conversations.assignAll([
        testConversation(id: 1),
        testConversation(id: 3),
        testConversation(id: 5),
      ]);

      await controller.deleteConversation(3);

      expect(controller.conversations.length, 2);
      expect(controller.conversations.any((c) => c.id == 3), isFalse);
      expect(controller.isDeleting.value, isFalse);
    });

    // ── deleteConversation (failure) ─────────────────────────────────────

    test('deleteConversation keeps list intact on failure', () async {
      when(() => mockRepository.deleteConversation(3)).thenAnswer((_) async => false);

      final controller = createController();
      controller.conversations.assignAll([testConversation(id: 1), testConversation(id: 3)]);

      await controller.deleteConversation(3);

      // List should remain unchanged when delete returns false.
      expect(controller.conversations.length, 2);
      expect(controller.isDeleting.value, isFalse);
    });

    // ── deleteConversation sets isDeleting correctly ─────────────────────

    test('deleteConversation toggles isDeleting during operation', () async {
      final completer = Completer<bool>();
      when(() => mockRepository.deleteConversation(7)).thenAnswer((_) => completer.future);

      final controller = createController();
      controller.conversations.assignAll([testConversation(id: 7)]);

      // Fire and forget — don't await yet.
      final future = controller.deleteConversation(7);

      // isDeleting should be true while the future is pending.
      expect(controller.isDeleting.value, isTrue);

      completer.complete(true);
      await future;

      // isDeleting should be false after completion.
      expect(controller.isDeleting.value, isFalse);
    });

    // ── conversation_id parsed as int from SSE event ─────────────────────

    test('conversation_info event with int conversation_id sets value', () async {
      final streamController = StreamController<SseEvent>();
      when(
        () => mockRepository.streamChat(message: 'test', conversationId: null),
      ).thenAnswer((_) => streamController.stream);

      final controller = createController();
      controller.sendMessage('test');

      streamController.add(
        const SseEvent(event: 'conversation_info', data: {'conversation_id': 42}),
      );
      // Allow microtask to flush so the stream listener processes the event.
      await Future<void>.value();
      expect(controller.conversationId.value, 42);

      await streamController.close();
    });

    // ── conversation_id parsed as string from SSE event ──────────────────

    test('conversation_info event with string conversation_id parses to int', () async {
      final streamController = StreamController<SseEvent>();
      when(
        () => mockRepository.streamChat(message: 'test', conversationId: null),
      ).thenAnswer((_) => streamController.stream);

      final controller = createController();
      controller.sendMessage('test');

      streamController.add(
        const SseEvent(event: 'conversation_info', data: {'conversation_id': '99'}),
      );
      await Future<void>.value();
      expect(controller.conversationId.value, 99);

      await streamController.close();
    });

    // ── cancelStream ─────────────────────────────────────────────────────

    test('cancelStream stops streaming and clears state', () {
      final streamController = StreamController<SseEvent>();
      when(
        () => mockRepository.streamChat(message: 'hi', conversationId: null),
      ).thenAnswer((_) => streamController.stream);

      final controller = createController();
      controller.sendMessage('hi');
      expect(controller.isStreaming.value, isTrue);

      controller.cancelStream();

      expect(controller.isStreaming.value, isFalse);
      expect(controller.activeToolCall.value, isNull);
    });

    // ── deleteConversation success resets active conversation ─────────────

    test('deleteConversation resets active conversation when deleting current one', () async {
      when(() => mockRepository.deleteConversation(10)).thenAnswer((_) async => true);

      final controller = createController();
      controller.conversations.assignAll([testConversation(id: 10), testConversation(id: 20)]);
      // Simulate that conversation 10 is currently active.
      controller.conversationId.value = 10;
      controller.messages.add(
        ChatMessageModel(
          id: 'msg1',
          role: ChatRole.user,
          content: 'hello',
          timestamp: DateTime.now(),
        ),
      );

      await controller.deleteConversation(10);

      expect(controller.conversations.length, 1);
      expect(controller.conversationId.value, isNull);
      expect(controller.messages, isEmpty);
    });

    // ── sendMessage edge cases ────────────────────────────────────────────

    test('sendMessage ignores empty/whitespace text', () {
      final streamController = StreamController<SseEvent>();
      when(
        () => mockRepository.streamChat(message: any(named: 'message'), conversationId: any(named: 'conversationId')),
      ).thenAnswer((_) => streamController.stream);

      final controller = createController();

      controller.sendMessage('   ');
      expect(controller.messages, isEmpty);
      expect(controller.isStreaming.value, isFalse);
      verifyNever(
        () => mockRepository.streamChat(message: any(named: 'message'), conversationId: any(named: 'conversationId')),
      );

      streamController.close();
    });

    test('sendMessage ignores when already streaming', () {
      final streamController = StreamController<SseEvent>();
      when(
        () => mockRepository.streamChat(message: 'first', conversationId: null),
      ).thenAnswer((_) => streamController.stream);

      final controller = createController();
      controller.sendMessage('first');
      expect(controller.messages.length, 2);

      // Now streaming — second call should be ignored.
      controller.sendMessage('second');
      expect(controller.messages.length, 2);
      expect(controller.messages[0].content, 'first');

      streamController.close();
    });

    test('sendMessage trims whitespace from text', () {
      final streamController = StreamController<SseEvent>();
      when(
        () => mockRepository.streamChat(message: 'hello', conversationId: null),
      ).thenAnswer((_) => streamController.stream);

      final controller = createController();
      controller.sendMessage('  hello  ');

      expect(controller.messages[0].content, 'hello');
      verify(() => mockRepository.streamChat(message: 'hello', conversationId: null)).called(1);

      streamController.close();
    });

    test('sendMessage passes existing conversationId to repository', () {
      final streamController = StreamController<SseEvent>();
      when(
        () => mockRepository.streamChat(message: 'hi', conversationId: 5),
      ).thenAnswer((_) => streamController.stream);

      final controller = createController();
      controller.conversationId.value = 5;
      controller.sendMessage('hi');

      verify(() => mockRepository.streamChat(message: 'hi', conversationId: 5)).called(1);

      streamController.close();
    });

    test('sendMessage does not start new stream while already streaming', () async {
      final firstController = StreamController<SseEvent>();
      final secondController = StreamController<SseEvent>();
      when(() => mockRepository.streamChat(message: 'first', conversationId: null))
          .thenAnswer((_) => firstController.stream);
      when(() => mockRepository.streamChat(message: 'second', conversationId: null))
          .thenAnswer((_) => secondController.stream);

      final controller = createController();
      controller.sendMessage('first');
      await Future<void>.value();
      expect(controller.isStreaming.value, isTrue);

      // Second message is ignored because streaming is in progress.
      controller.sendMessage('second');
      await Future<void>.value();

      expect(controller.messages.length, 2);
      expect(controller.messages[0].content, 'first');
      verifyNever(() => mockRepository.streamChat(message: 'second', conversationId: null));

      firstController.close();
      secondController.close();
    });

    // ── SSE event handling ────────────────────────────────────────────────

    test('text_chunk event appends text to assistant message', () async {
      final streamController = StreamController<SseEvent>();
      when(() => mockRepository.streamChat(message: 'hi', conversationId: null))
          .thenAnswer((_) => streamController.stream);

      final controller = createController();
      controller.sendMessage('hi');

      streamController.add(const SseEvent(event: 'text_chunk', data: {'text': 'Hello'}));
      await Future<void>.value();
      expect(controller.messages[1].content, 'Hello');

      streamController.add(const SseEvent(event: 'text_chunk', data: {'text': ' world'}));
      await Future<void>.value();
      expect(controller.messages[1].content, 'Hello world');

      await streamController.close();
    });

    test('text_chunk event with missing text field does not crash', () async {
      final streamController = StreamController<SseEvent>();
      when(() => mockRepository.streamChat(message: 'hi', conversationId: null))
          .thenAnswer((_) => streamController.stream);

      final controller = createController();
      controller.sendMessage('hi');

      streamController.add(const SseEvent(event: 'text_chunk', data: {}));
      await Future<void>.value();
      expect(controller.messages[1].content, '');

      await streamController.close();
    });

    test('tool_call_start event sets activeToolCall', () async {
      final streamController = StreamController<SseEvent>();
      when(() => mockRepository.streamChat(message: 'hi', conversationId: null))
          .thenAnswer((_) => streamController.stream);

      final controller = createController();
      controller.sendMessage('hi');

      streamController.add(const SseEvent(event: 'tool_call_start', data: {'tool': 'search_properties'}));
      await Future<void>.value();
      expect(controller.activeToolCall.value, 'search_properties');

      await streamController.close();
    });

    test('tool_call_end event clears activeToolCall', () async {
      final streamController = StreamController<SseEvent>();
      when(() => mockRepository.streamChat(message: 'hi', conversationId: null))
          .thenAnswer((_) => streamController.stream);

      final controller = createController();
      controller.sendMessage('hi');

      streamController.add(const SseEvent(event: 'tool_call_start', data: {'tool': 'search'}));
      await Future<void>.value();
      expect(controller.activeToolCall.value, 'search');

      streamController.add(const SseEvent(event: 'tool_call_end', data: {}));
      await Future<void>.value();
      expect(controller.activeToolCall.value, isNull);

      await streamController.close();
    });

    test('widget event adds a widget message', () async {
      final streamController = StreamController<SseEvent>();
      when(() => mockRepository.streamChat(message: 'hi', conversationId: null))
          .thenAnswer((_) => streamController.stream);

      final controller = createController();
      controller.sendMessage('hi');
      final initialCount = controller.messages.length;

      streamController.add(const SseEvent(
        event: 'widget',
        data: {'widget_name': 'property_card', 'structured_content': {'id': 1}},
      ));
      await Future<void>.value();

      expect(controller.messages.length, initialCount + 1);
      final widgetMsg = controller.messages.last;
      expect(widgetMsg.role, ChatRole.widget);
      expect(widgetMsg.widgetName, 'property_card');
      expect(widgetMsg.widgetData, {'id': 1});

      await streamController.close();
    });

    test('widget event with missing fields does not add a message', () async {
      final streamController = StreamController<SseEvent>();
      when(() => mockRepository.streamChat(message: 'hi', conversationId: null))
          .thenAnswer((_) => streamController.stream);

      final controller = createController();
      controller.sendMessage('hi');
      final initialCount = controller.messages.length;

      streamController.add(const SseEvent(event: 'widget', data: {'widget_name': 'property_card'}));
      await Future<void>.value();
      expect(controller.messages.length, initialCount);

      streamController.add(const SseEvent(event: 'widget', data: {'structured_content': {'id': 1}}));
      await Future<void>.value();
      expect(controller.messages.length, initialCount);

      await streamController.close();
    });

    test('done event replaces assistant content with authoritative text', () async {
      final streamController = StreamController<SseEvent>();
      when(() => mockRepository.streamChat(message: 'hi', conversationId: null))
          .thenAnswer((_) => streamController.stream);

      final controller = createController();
      controller.sendMessage('hi');

      streamController.add(const SseEvent(event: 'text_chunk', data: {'text': 'partial'}));
      await Future<void>.value();
      expect(controller.messages[1].content, 'partial');

      streamController.add(const SseEvent(event: 'done', data: {'response_text': 'Final answer'}));
      await Future<void>.value();
      expect(controller.messages[1].content, 'Final answer');
      expect(controller.messages[1].isStreaming, isFalse);
      expect(controller.isStreaming.value, isFalse);

      await streamController.close();
    });

    test('done event with empty response_text keeps streamed content', () async {
      final streamController = StreamController<SseEvent>();
      when(() => mockRepository.streamChat(message: 'hi', conversationId: null))
          .thenAnswer((_) => streamController.stream);

      final controller = createController();
      controller.sendMessage('hi');

      streamController.add(const SseEvent(event: 'text_chunk', data: {'text': 'streamed text'}));
      await Future<void>.value();

      streamController.add(const SseEvent(event: 'done', data: {'response_text': ''}));
      await Future<void>.value();
      expect(controller.messages[1].content, 'streamed text');
      expect(controller.isStreaming.value, isFalse);

      await streamController.close();
    });

    test('error event appends error message and finishes streaming', () async {
      final streamController = StreamController<SseEvent>();
      when(() => mockRepository.streamChat(message: 'hi', conversationId: null))
          .thenAnswer((_) => streamController.stream);

      final controller = createController();
      controller.sendMessage('hi');

      streamController.add(const SseEvent(event: 'error', data: {'message': 'Something went wrong'}));
      await Future<void>.value();
      expect(controller.messages[1].content, 'Something went wrong');
      expect(controller.isStreaming.value, isFalse);
      expect(controller.activeToolCall.value, isNull);

      await streamController.close();
    });

    test('stream onError finishes streaming', () async {
      final streamController = StreamController<SseEvent>();
      when(() => mockRepository.streamChat(message: 'hi', conversationId: null))
          .thenAnswer((_) => streamController.stream);

      final controller = createController();
      controller.sendMessage('hi');

      streamController.addError(Exception('network error'));
      await Future<void>.value();
      expect(controller.isStreaming.value, isFalse);
      expect(controller.activeToolCall.value, isNull);

      await streamController.close();
    });

    test('stream onDone finishes streaming', () async {
      final streamController = StreamController<SseEvent>();
      when(() => mockRepository.streamChat(message: 'hi', conversationId: null))
          .thenAnswer((_) => streamController.stream);

      final controller = createController();
      controller.sendMessage('hi');

      await streamController.close();
      await Future<void>.value();
      expect(controller.isStreaming.value, isFalse);
      expect(controller.messages[1].isStreaming, isFalse);
    });

    // ── loadMoreConversations ─────────────────────────────────────────────

    test('loadMoreConversations appends items and updates cursor', () async {
      final firstPage = ConversationsPage(
        items: [testConversation(id: 1), testConversation(id: 2)],
        hasMore: true,
        nextCursor: 'cursor_1',
      );
      final secondPage = ConversationsPage(
        items: [testConversation(id: 3), testConversation(id: 4)],
        hasMore: false,
        nextCursor: null,
      );
      when(() => mockRepository.getConversations()).thenAnswer((_) async => firstPage);
      when(() => mockRepository.getConversations(cursor: 'cursor_1'))
          .thenAnswer((_) async => secondPage);

      final controller = createController();
      await controller.loadConversations();
      expect(controller.conversations.length, 2);

      await controller.loadMoreConversations();
      expect(controller.conversations.length, 4);
      expect(controller.conversations[2].id, 3);
      expect(controller.conversations[3].id, 4);
      expect(controller.conversationsHasMore.value, isFalse);
      expect(controller.conversationsNextCursor.value, isNull);
      expect(controller.isLoadingMoreConversations.value, isFalse);
    });

    test('loadMoreConversations is no-op when hasMore is false', () async {
      final firstPage = ConversationsPage(
        items: [testConversation(id: 1)],
        hasMore: false,
        nextCursor: null,
      );
      when(() => mockRepository.getConversations()).thenAnswer((_) async => firstPage);

      final controller = createController();
      await controller.loadConversations();
      expect(controller.conversations.length, 1);

      await controller.loadMoreConversations();
      // List unchanged — no additional fetch was made.
      expect(controller.conversations.length, 1);
    });

    test('loadMoreConversations is no-op when cursor is null', () async {
      final controller = createController();
      controller.conversations.assignAll([testConversation(id: 1)]);
      controller.conversationsHasMore.value = true;
      controller.conversationsNextCursor.value = null;

      await controller.loadMoreConversations();
      expect(controller.conversationsHasMore.value, isFalse);
    });

    test('loadMoreConversations is no-op when cursor is empty', () async {
      final controller = createController();
      controller.conversations.assignAll([testConversation(id: 1)]);
      controller.conversationsHasMore.value = true;
      controller.conversationsNextCursor.value = '';

      await controller.loadMoreConversations();
      expect(controller.conversationsHasMore.value, isFalse);
    });

    test('loadMoreConversations is no-op when already loading more', () async {
      final controller = createController();
      controller.conversations.assignAll([testConversation(id: 1)]);
      controller.conversationsHasMore.value = true;
      controller.conversationsNextCursor.value = 'cursor';
      controller.isLoadingMoreConversations.value = true;

      await controller.loadMoreConversations();
      verifyNever(() => mockRepository.getConversations(cursor: any(named: 'cursor')));
    });

    test('loadMoreConversations is no-op when isLoadingConversations is true', () async {
      final controller = createController();
      controller.conversations.assignAll([testConversation(id: 1)]);
      controller.conversationsHasMore.value = true;
      controller.conversationsNextCursor.value = 'cursor';
      controller.isLoadingConversations.value = true;

      await controller.loadMoreConversations();
      verifyNever(() => mockRepository.getConversations(cursor: any(named: 'cursor')));
    });

    test('loadMoreConversations dedupes items by id', () async {
      final firstPage = ConversationsPage(
        items: [testConversation(id: 1), testConversation(id: 2)],
        hasMore: true,
        nextCursor: 'cursor_1',
      );
      // Second page returns id 2 again (overlap) plus id 3.
      final secondPage = ConversationsPage(
        items: [testConversation(id: 2), testConversation(id: 3)],
        hasMore: false,
        nextCursor: null,
      );
      when(() => mockRepository.getConversations()).thenAnswer((_) async => firstPage);
      when(() => mockRepository.getConversations(cursor: 'cursor_1'))
          .thenAnswer((_) async => secondPage);

      final controller = createController();
      await controller.loadConversations();
      await controller.loadMoreConversations();

      expect(controller.conversations.length, 3);
      expect(controller.conversations.map((c) => c.id).toList(), [1, 2, 3]);
    });

    test('loadMoreConversations sets error flag on failure', () async {
      final firstPage = ConversationsPage(
        items: [testConversation(id: 1)],
        hasMore: true,
        nextCursor: 'cursor_1',
      );
      when(() => mockRepository.getConversations()).thenAnswer((_) async => firstPage);
      when(() => mockRepository.getConversations(cursor: 'cursor_1'))
          .thenThrow(Exception('Network error'));

      final controller = createController();
      await controller.loadConversations();
      await controller.loadMoreConversations();

      expect(controller.conversationsError.value, isTrue);
      expect(controller.isLoadingMoreConversations.value, isFalse);
    });

    // ── loadConversations guards ──────────────────────────────────────────

    test('loadConversations is no-op when already loading', () async {
      when(() => mockRepository.getConversations()).thenAnswer((_) async => ConversationsPage(items: [], hasMore: false));

      final controller = createController();
      controller.isLoadingConversations.value = true;

      await controller.loadConversations();
      verifyNever(() => mockRepository.getConversations());
    });

    test('loadConversations is no-op when loading more', () async {
      when(() => mockRepository.getConversations()).thenAnswer((_) async => ConversationsPage(items: [], hasMore: false));

      final controller = createController();
      controller.isLoadingMoreConversations.value = true;

      await controller.loadConversations();
      verifyNever(() => mockRepository.getConversations());
    });

    // ── startNewConversation ──────────────────────────────────────────────

    test('startNewConversation clears messages and conversationId', () {
      final streamController = StreamController<SseEvent>();
      when(() => mockRepository.streamChat(message: 'hi', conversationId: null))
          .thenAnswer((_) => streamController.stream);

      final controller = createController();
      controller.sendMessage('hi');
      controller.conversationId.value = 7;
      expect(controller.messages, isNotEmpty);
      expect(controller.isStreaming.value, isTrue);

      controller.startNewConversation();

      expect(controller.conversationId.value, isNull);
      expect(controller.messages, isEmpty);
      expect(controller.isStreaming.value, isFalse);

      streamController.close();
    });

    // ── deleteConversation error ──────────────────────────────────────────

    test('deleteConversation handles exception gracefully', () async {
      when(() => mockRepository.deleteConversation(3)).thenThrow(Exception('Server error'));

      final controller = createController();
      controller.conversations.assignAll([testConversation(id: 1), testConversation(id: 3)]);

      await controller.deleteConversation(3);

      expect(controller.conversations.length, 2);
      expect(controller.isDeleting.value, isFalse);
    });

    // ── onClose ───────────────────────────────────────────────────────────

    test('onClose cancels stream subscription', () {
      final streamController = StreamController<SseEvent>();
      when(() => mockRepository.streamChat(message: 'hi', conversationId: null))
          .thenAnswer((_) => streamController.stream);

      final controller = createController();
      controller.sendMessage('hi');
      expect(streamController.hasListener, isTrue);

      controller.onClose();
      expect(streamController.hasListener, isFalse);

      streamController.close();
    });

    // ── conversation_info with invalid id ─────────────────────────────────

    test('conversation_info event with non-int/non-string id does not set value', () async {
      final streamController = StreamController<SseEvent>();
      when(() => mockRepository.streamChat(message: 'hi', conversationId: 5))
          .thenAnswer((_) => streamController.stream);

      final controller = createController();
      controller.conversationId.value = 5;
      controller.sendMessage('hi');

      // A bool value is neither int nor String, so conversationId stays unchanged.
      streamController.add(const SseEvent(event: 'conversation_info', data: {'conversation_id': true}));
      await Future<void>.value();
      expect(controller.conversationId.value, 5);

      await streamController.close();
    });

    test('conversation_info event with non-numeric string sets conversationId to null', () async {
      final streamController = StreamController<SseEvent>();
      when(() => mockRepository.streamChat(message: 'hi', conversationId: 5))
          .thenAnswer((_) => streamController.stream);

      final controller = createController();
      controller.conversationId.value = 5;
      controller.sendMessage('hi');

      streamController.add(const SseEvent(event: 'conversation_info', data: {'conversation_id': 'not_a_number'}));
      await Future<void>.value();
      expect(controller.conversationId.value, isNull);

      await streamController.close();
    });
  });
}
