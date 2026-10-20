import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/assistant/data/assistant_repository.dart';
import 'package:ghar360/features/assistant/data/models/assistant_frame.dart';
import 'package:ghar360/features/assistant/data/models/chat_message_model.dart';
import 'package:ghar360/features/assistant/data/models/conversation_model.dart';
import 'package:ghar360/features/assistant/presentation/controllers/assistant_controller.dart';
import 'package:ghar360/features/assistant/presentation/controllers/assistant_history_controller.dart';
import '../../../../helpers/assistant_test_harness.dart';

void main() {
  late AssistantTestHarness harness;
  late MockAssistantRepository mockRepository;
  setUp(() {
    harness = AssistantTestHarness();
    mockRepository = harness.repository;
  });
  tearDown(() => harness.dispose());
  TestAssistantController createController([int? id]) => harness.conversation(id);
  TestAssistantHistoryController createHistoryController() => harness.history();

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
      final streamController = StreamController<AssistantFrame>();
      when(
        () => mockRepository.streamChat(message: 'hello', conversationId: null),
      ).thenAnswer((_) => streamController.stream);

      final controller = createController();
      controller.sendMessage('hello');

      expect(controller.snapshot.messages.length, 2);
      expect(controller.snapshot.messages[0].role, ChatRole.user);
      expect(controller.snapshot.messages[0].content, 'hello');
      expect(controller.snapshot.messages[1].role, ChatRole.assistant);
      expect(controller.snapshot.messages[1].isStreaming, isTrue);
      expect(controller.snapshot.isStreaming, isTrue);

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
      when(
        () => mockRepository.getMessagesPage(5),
      ).thenAnswer((_) async => MessagesPage(items: msgs, hasMore: false));

      final controller = createController(5);
      await controller.loadMessages();

      expect(controller.snapshot.conversationId, 5);
      expect(controller.snapshot.messages.length, 2);
      expect(controller.snapshot.messages[0].content, 'Hi');
      expect(controller.snapshot.messages[1].content, 'Hello!');
    });

    // ── selectConversation (error) ───────────────────────────────────────

    test('selectConversation handles error gracefully', () async {
      when(() => mockRepository.getMessagesPage(99)).thenThrow(Exception('Network error'));

      final controller = createController(99);
      await controller.loadMessages();
      expect(controller.snapshot.loadStatus, ConversationLoadStatus.failed);
      expect(controller.snapshot.loadError, isA<Exception>());

      // conversationId is set even on error.
      expect(controller.snapshot.conversationId, 99);
      // Messages are cleared then error returns [] from repository.
      expect(controller.snapshot.messages, isEmpty);
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

      final controller = createHistoryController();
      await controller.loadConversations();

      expect(controller.snapshot.conversations.length, 2);
      expect(controller.snapshot.conversations[0].title, 'First');
      expect(controller.snapshot.conversations[1].title, 'Second');
      expect(controller.snapshot.nextCursor, 'cursor_abc');
      expect(controller.snapshot.hasMore, isTrue);
      expect(controller.snapshot.isLoading, isFalse);
      expect(controller.snapshot.error != null, isFalse);
    });

    // ── loadConversations (error) ────────────────────────────────────────

    test('loadConversations sets error flag on failure', () async {
      when(() => mockRepository.getConversations()).thenThrow(Exception('Server down'));

      final controller = createHistoryController();
      await controller.loadConversations();

      expect(controller.snapshot.conversations, isEmpty);
      expect(controller.snapshot.error != null, isTrue);
      expect(controller.snapshot.isLoading, isFalse);
    });

    // ── deleteConversation (success) ─────────────────────────────────────

    test('deleteConversation removes item from list on success', () async {
      when(() => mockRepository.deleteConversation(3)).thenAnswer((_) async => true);

      final controller = createHistoryController();
      controller.seed(
        controller.snapshot.copyWith(
          conversations: [
            testConversation(id: 1),
            testConversation(id: 3),
            testConversation(id: 5),
          ],
        ),
      );

      await controller.deleteConversation(3);

      expect(controller.snapshot.conversations.length, 2);
      expect(controller.snapshot.conversations.any((c) => c.id == 3), isFalse);
      expect(controller.snapshot.deletingId != null, isFalse);
    });

    // ── deleteConversation (failure) ─────────────────────────────────────

    test('deleteConversation keeps list intact on failure', () async {
      when(() => mockRepository.deleteConversation(3)).thenAnswer((_) async => false);

      final controller = createHistoryController();
      controller.seed(
        controller.snapshot.copyWith(
          conversations: [testConversation(id: 1), testConversation(id: 3)],
        ),
      );

      await controller.deleteConversation(3);

      // List should remain unchanged when delete returns false.
      expect(controller.snapshot.conversations.length, 2);
      expect(controller.snapshot.deletingId != null, isFalse);
    });

    // ── deleteConversation sets isDeleting correctly ─────────────────────

    test('deleteConversation toggles isDeleting during operation', () async {
      final completer = Completer<bool>();
      when(() => mockRepository.deleteConversation(7)).thenAnswer((_) => completer.future);

      final controller = createHistoryController();
      controller.seed(controller.snapshot.copyWith(conversations: [testConversation(id: 7)]));

      // Fire and forget — don't await yet.
      final future = controller.deleteConversation(7);

      // isDeleting should be true while the future is pending.
      expect(controller.snapshot.deletingId != null, isTrue);

      completer.complete(true);
      await future;

      // isDeleting should be false after completion.
      expect(controller.snapshot.deletingId != null, isFalse);
    });

    // ── conversation_id parsed as int from SSE event ─────────────────────

    test('conversation_info event with int conversation_id sets value', () async {
      final streamController = StreamController<AssistantFrame>();
      when(
        () => mockRepository.streamChat(message: 'test', conversationId: null),
      ).thenAnswer((_) => streamController.stream);

      final controller = createController();
      controller.sendMessage('test');

      streamController.add(const ConversationInfoFrame(42));
      // Allow microtask to flush so the stream listener processes the event.
      await Future<void>.value();
      expect(controller.snapshot.conversationId, 42);

      await streamController.close();
    });

    // ── a frame with no usable id ────────────────────────────────────────

    test('conversation_info with a non-positive id does not set the conversation', () async {
      final streamController = StreamController<AssistantFrame>();
      when(
        () => mockRepository.streamChat(message: 'test', conversationId: null),
      ).thenAnswer((_) => streamController.stream);

      final controller = createController();
      controller.sendMessage('test');

      streamController.add(const ConversationInfoFrame(0));
      await Future<void>.value();
      expect(controller.snapshot.conversationId, isNull);

      await streamController.close();
    });

    // ── cancelStream ─────────────────────────────────────────────────────

    test('cancelStream stops streaming and clears state', () {
      final streamController = StreamController<AssistantFrame>();
      when(
        () => mockRepository.streamChat(message: 'hi', conversationId: null),
      ).thenAnswer((_) => streamController.stream);

      final controller = createController();
      controller.sendMessage('hi');
      expect(controller.snapshot.isStreaming, isTrue);

      controller.cancelStream();

      expect(controller.snapshot.isStreaming, isFalse);
      expect(controller.snapshot.activeToolCall, isNull);
      // The in-flight assistant message is settled too, so the typing
      // indicator does not animate forever after a manual cancel.
      expect(controller.snapshot.messages[1].isStreaming, isFalse);
    });

    // ── SSE 'error' event ────────────────────────────────────────────────

    test('an error frame exposes failed status, a typed error and preserves the draft', () async {
      final streamController = StreamController<AssistantFrame>();
      when(
        () => mockRepository.streamChat(message: 'hi', conversationId: null),
      ).thenAnswer((_) => streamController.stream);

      final controller = createController();
      controller.sendMessage('hi');
      // No usable message: finishing as a normal empty turn would be hidden by
      // the view's shrink rule — the user gets no error and no retry affordance.
      streamController.add(
        const ErrorFrame(code: AssistantErrorCode.streamError, message: 'Try again.'),
      );
      await Future<void>.value();

      expect(controller.snapshot.streamStatus, AssistantStreamStatus.failed);
      expect(
        controller.snapshot.streamError,
        isA<ServerException>().having((e) => e.code, 'code', 'STREAM_ERROR'),
      );
      expect(controller.snapshot.draft, 'hi');
      expect(controller.snapshot.messages[1].content, isEmpty);
      expect(controller.snapshot.messages[1].isStreaming, isFalse);
      expect(controller.snapshot.isStreaming, isFalse);
      await streamController.close();
    });

    // ── deleteConversation success resets active conversation ─────────────

    test('deleteConversation resets active conversation when deleting current one', () async {
      when(() => mockRepository.deleteConversation(10)).thenAnswer((_) async => true);

      final controller = createHistoryController();
      controller.seed(
        controller.snapshot.copyWith(
          conversations: [testConversation(id: 10), testConversation(id: 20)],
        ),
      );
      final active = createController(10);
      active.seed(
        AssistantState(
          conversationId: 10,
          messages: [
            ChatMessageModel(
              id: 'm1',
              role: ChatRole.user,
              content: 'hello',
              timestamp: DateTime.now(),
            ),
          ],
        ),
      );
      await controller.deleteConversation(10);

      expect(controller.snapshot.conversations.length, 1);
      expect(harness.container.read(assistantControllerProvider(10)).messages, isEmpty);
    });

    // ── sendMessage edge cases ────────────────────────────────────────────

    test('sendMessage ignores empty/whitespace text', () {
      final streamController = StreamController<AssistantFrame>();
      when(
        () => mockRepository.streamChat(
          message: any(named: 'message'),
          conversationId: any(named: 'conversationId'),
        ),
      ).thenAnswer((_) => streamController.stream);

      final controller = createController();

      controller.sendMessage('   ');
      expect(controller.snapshot.messages, isEmpty);
      expect(controller.snapshot.isStreaming, isFalse);
      verifyNever(
        () => mockRepository.streamChat(
          message: any(named: 'message'),
          conversationId: any(named: 'conversationId'),
        ),
      );

      streamController.close();
    });

    test('sendMessage ignores when already streaming', () {
      final streamController = StreamController<AssistantFrame>();
      when(
        () => mockRepository.streamChat(message: 'first', conversationId: null),
      ).thenAnswer((_) => streamController.stream);

      final controller = createController();
      controller.sendMessage('first');
      expect(controller.snapshot.messages.length, 2);

      // Now streaming — second call should be ignored.
      controller.sendMessage('second');
      expect(controller.snapshot.messages.length, 2);
      expect(controller.snapshot.messages[0].content, 'first');

      streamController.close();
    });

    test('sendMessage trims whitespace from text', () {
      final streamController = StreamController<AssistantFrame>();
      when(
        () => mockRepository.streamChat(message: 'hello', conversationId: null),
      ).thenAnswer((_) => streamController.stream);

      final controller = createController();
      controller.sendMessage('  hello  ');

      expect(controller.snapshot.messages[0].content, 'hello');
      verify(() => mockRepository.streamChat(message: 'hello', conversationId: null)).called(1);

      streamController.close();
    });

    test('sendMessage passes existing conversationId to repository', () {
      final streamController = StreamController<AssistantFrame>();
      when(
        () => mockRepository.streamChat(message: 'hi', conversationId: 5),
      ).thenAnswer((_) => streamController.stream);

      final controller = createController();
      controller.seed(controller.snapshot.copyWith(conversationId: 5));
      controller.sendMessage('hi');

      verify(() => mockRepository.streamChat(message: 'hi', conversationId: 5)).called(1);

      streamController.close();
    });

    test('sendMessage does not start new stream while already streaming', () async {
      final firstController = StreamController<AssistantFrame>();
      final secondController = StreamController<AssistantFrame>();
      when(
        () => mockRepository.streamChat(message: 'first', conversationId: null),
      ).thenAnswer((_) => firstController.stream);
      when(
        () => mockRepository.streamChat(message: 'second', conversationId: null),
      ).thenAnswer((_) => secondController.stream);

      final controller = createController();
      controller.sendMessage('first');
      await Future<void>.value();
      expect(controller.snapshot.isStreaming, isTrue);

      // Second message is ignored because streaming is in progress.
      controller.sendMessage('second');
      await Future<void>.value();

      expect(controller.snapshot.messages.length, 2);
      expect(controller.snapshot.messages[0].content, 'first');
      verifyNever(() => mockRepository.streamChat(message: 'second', conversationId: null));

      firstController.close();
      secondController.close();
    });

    // ── SSE event handling ────────────────────────────────────────────────

    test('text_chunk event appends text to assistant message', () async {
      final streamController = StreamController<AssistantFrame>();
      when(
        () => mockRepository.streamChat(message: 'hi', conversationId: null),
      ).thenAnswer((_) => streamController.stream);

      final controller = createController();
      controller.sendMessage('hi');

      streamController.add(const TextChunkFrame('Hello'));
      await Future<void>.value();
      expect(controller.snapshot.messages[1].content, 'Hello');

      streamController.add(const TextChunkFrame(' world'));
      await Future<void>.value();
      expect(controller.snapshot.messages[1].content, 'Hello world');

      await streamController.close();
    });

    test('tool_call_start event sets activeToolCall', () async {
      final streamController = StreamController<AssistantFrame>();
      when(
        () => mockRepository.streamChat(message: 'hi', conversationId: null),
      ).thenAnswer((_) => streamController.stream);

      final controller = createController();
      controller.sendMessage('hi');

      streamController.add(const ToolCallStartFrame(callId: 'call_1', tool: 'search_properties'));
      await Future<void>.value();
      expect(controller.snapshot.activeToolCall, 'search_properties');

      await streamController.close();
    });

    test('tool_call_end clears the call it names', () async {
      final streamController = StreamController<AssistantFrame>();
      when(
        () => mockRepository.streamChat(message: 'hi', conversationId: null),
      ).thenAnswer((_) => streamController.stream);

      final controller = createController();
      controller.sendMessage('hi');

      streamController.add(const ToolCallStartFrame(callId: 'call_1', tool: 'search'));
      await Future<void>.value();
      expect(controller.snapshot.activeToolCall, 'search');

      streamController.add(const ToolCallEndFrame(callId: 'call_1', tool: 'search', success: true));
      await Future<void>.value();
      expect(controller.snapshot.activeToolCall, isNull);
      expect(controller.snapshot.failedTool, isNull);

      await streamController.close();
    });

    test('two parallel calls: one end frame does not clear the other call', () async {
      final streamController = StreamController<AssistantFrame>();
      when(
        () => mockRepository.streamChat(message: 'hi', conversationId: null),
      ).thenAnswer((_) => streamController.stream);

      final controller = createController();
      controller.sendMessage('hi');

      streamController
        ..add(const ToolCallStartFrame(callId: 'call_a', tool: 'discovery_search'))
        ..add(const ToolCallStartFrame(callId: 'call_b', tool: 'discovery_property_get'));
      await Future<void>.delayed(Duration.zero);
      expect(controller.snapshot.activeToolCalls, {
        'call_a': 'discovery_search',
        'call_b': 'discovery_property_get',
      });
      expect(controller.snapshot.activeToolCall, 'discovery_property_get');

      streamController.add(
        const ToolCallEndFrame(callId: 'call_b', tool: 'discovery_property_get', success: true),
      );
      await Future<void>.value();
      expect(controller.snapshot.activeToolCalls, {'call_a': 'discovery_search'});
      expect(controller.snapshot.activeToolCall, 'discovery_search');

      streamController.add(
        const ToolCallEndFrame(callId: 'call_a', tool: 'discovery_search', success: true),
      );
      await Future<void>.value();
      expect(controller.snapshot.activeToolCalls, isEmpty);

      await streamController.close();
    });

    test('an end frame with success false is remembered for the reply', () async {
      final streamController = StreamController<AssistantFrame>();
      when(
        () => mockRepository.streamChat(message: 'hi', conversationId: null),
      ).thenAnswer((_) => streamController.stream);

      final controller = createController();
      controller.sendMessage('hi');

      streamController
        ..add(const ToolCallStartFrame(callId: 'call_a', tool: 'bookings_create'))
        ..add(const ToolCallEndFrame(callId: 'call_a', tool: 'bookings_create', success: false));
      await Future<void>.delayed(Duration.zero);

      expect(controller.snapshot.activeToolCalls, isEmpty);
      expect(controller.snapshot.failedTool, 'bookings_create');
      expect(controller.snapshot.turnUsedTool, isTrue);

      // The next message starts clean.
      controller.cancelStream();
      when(
        () => mockRepository.streamChat(message: 'again', conversationId: null),
      ).thenAnswer((_) => const Stream<AssistantFrame>.empty());
      controller.sendMessage('again');
      expect(controller.snapshot.failedTool, isNull);

      await streamController.close();
    });

    test('an end frame for a call that never started changes nothing', () async {
      final streamController = StreamController<AssistantFrame>();
      when(
        () => mockRepository.streamChat(message: 'hi', conversationId: null),
      ).thenAnswer((_) => streamController.stream);

      final controller = createController();
      controller.sendMessage('hi');
      streamController.add(const ToolCallStartFrame(callId: 'call_a', tool: 'search'));
      streamController.add(const ToolCallEndFrame(callId: 'call_x', tool: 'other', success: true));
      await Future<void>.delayed(Duration.zero);

      expect(controller.snapshot.activeToolCalls, {'call_a': 'search'});

      await streamController.close();
    });

    test('widget event adds a widget message', () async {
      final streamController = StreamController<AssistantFrame>();
      when(
        () => mockRepository.streamChat(message: 'hi', conversationId: null),
      ).thenAnswer((_) => streamController.stream);

      final controller = createController();
      controller.sendMessage('hi');
      final initialCount = controller.snapshot.messages.length;

      streamController.add(
        const WidgetFrame(widgetName: 'property_card', structuredContent: {'id': 1}),
      );
      await Future<void>.value();

      expect(controller.snapshot.messages.length, initialCount + 1);
      final widgetMsg = controller.snapshot.messages.last;
      expect(widgetMsg.role, ChatRole.widget);
      expect(widgetMsg.widgetName, 'property_card');
      expect(widgetMsg.widgetData, {'id': 1});

      await streamController.close();
    });

    test(
      'a widget frame with no content, an error payload or an unsafe name adds no message',
      () async {
        final streamController = StreamController<AssistantFrame>();
        when(
          () => mockRepository.streamChat(message: 'hi', conversationId: null),
        ).thenAnswer((_) => streamController.stream);

        final controller = createController();
        controller.sendMessage('hi');
        final initialCount = controller.snapshot.messages.length;

        streamController.add(const WidgetFrame(widgetName: 'property_card'));
        await Future<void>.value();
        expect(controller.snapshot.messages.length, initialCount);

        streamController.add(
          const WidgetFrame(
            widgetName: 'property_card',
            structuredContent: {'error': true, 'message': 'Not found'},
          ),
        );
        await Future<void>.value();
        expect(controller.snapshot.messages.length, initialCount);

        streamController.add(
          const WidgetFrame(widgetName: '../secret', structuredContent: {'id': 1}),
        );
        await Future<void>.value();
        expect(controller.snapshot.messages.length, initialCount);

        await streamController.close();
      },
    );

    test('done event replaces assistant content with authoritative text', () async {
      final streamController = StreamController<AssistantFrame>();
      when(
        () => mockRepository.streamChat(message: 'hi', conversationId: null),
      ).thenAnswer((_) => streamController.stream);

      final controller = createController();
      controller.sendMessage('hi');

      streamController.add(const TextChunkFrame('partial'));
      await Future<void>.value();
      expect(controller.snapshot.messages[1].content, 'partial');

      streamController.add(const DoneFrame('Final answer'));
      await Future<void>.value();
      expect(controller.snapshot.messages[1].content, 'Final answer');
      expect(controller.snapshot.messages[1].isStreaming, isFalse);
      expect(controller.snapshot.isStreaming, isFalse);

      await streamController.close();
    });

    test('done event with empty response_text keeps streamed content', () async {
      final streamController = StreamController<AssistantFrame>();
      when(
        () => mockRepository.streamChat(message: 'hi', conversationId: null),
      ).thenAnswer((_) => streamController.stream);

      final controller = createController();
      controller.sendMessage('hi');

      streamController.add(const TextChunkFrame('streamed text'));
      await Future<void>.value();

      streamController.add(const DoneFrame(''));
      await Future<void>.value();
      expect(controller.snapshot.messages[1].content, 'streamed text');
      expect(controller.snapshot.isStreaming, isFalse);

      await streamController.close();
    });

    test('error event hides raw error text and finishes streaming', () async {
      final streamController = StreamController<AssistantFrame>();
      when(
        () => mockRepository.streamChat(message: 'hi', conversationId: null),
      ).thenAnswer((_) => streamController.stream);

      final controller = createController();
      controller.sendMessage('hi');

      streamController.add(
        const ErrorFrame(code: AssistantErrorCode.agentError, message: 'Something went wrong'),
      );
      await Future<void>.value();
      expect(controller.snapshot.streamStatus, AssistantStreamStatus.failed);
      expect(controller.snapshot.messages[1].content, isEmpty);
      expect(controller.snapshot.isStreaming, isFalse);
      expect(controller.snapshot.activeToolCall, isNull);

      await streamController.close();
    });

    test('stream onError finishes streaming', () async {
      final streamController = StreamController<AssistantFrame>();
      when(
        () => mockRepository.streamChat(message: 'hi', conversationId: null),
      ).thenAnswer((_) => streamController.stream);

      final controller = createController();
      controller.sendMessage('hi');

      streamController.addError(Exception('network error'));
      await Future<void>.value();
      expect(controller.snapshot.isStreaming, isFalse);
      expect(controller.snapshot.activeToolCall, isNull);

      await streamController.close();
    });

    test('stream onDone finishes streaming', () async {
      final streamController = StreamController<AssistantFrame>();
      when(
        () => mockRepository.streamChat(message: 'hi', conversationId: null),
      ).thenAnswer((_) => streamController.stream);

      final controller = createController();
      controller.sendMessage('hi');

      await streamController.close();
      await Future<void>.value();
      expect(controller.snapshot.isStreaming, isFalse);
      expect(controller.snapshot.messages[1].isStreaming, isFalse);
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
      when(
        () => mockRepository.getConversations(cursor: 'cursor_1'),
      ).thenAnswer((_) async => secondPage);

      final controller = createHistoryController();
      await controller.loadConversations();
      expect(controller.snapshot.conversations.length, 2);

      await controller.loadMoreConversations();
      expect(controller.snapshot.conversations.length, 4);
      expect(controller.snapshot.conversations[2].id, 3);
      expect(controller.snapshot.conversations[3].id, 4);
      expect(controller.snapshot.hasMore, isFalse);
      expect(controller.snapshot.nextCursor, isNull);
      expect(controller.snapshot.isLoading, isFalse);
    });

    test('loadMoreConversations is no-op when hasMore is false', () async {
      final firstPage = ConversationsPage(
        items: [testConversation(id: 1)],
        hasMore: false,
        nextCursor: null,
      );
      when(() => mockRepository.getConversations()).thenAnswer((_) async => firstPage);

      final controller = createHistoryController();
      await controller.loadConversations();
      expect(controller.snapshot.conversations.length, 1);

      await controller.loadMoreConversations();
      // List unchanged — no additional fetch was made.
      expect(controller.snapshot.conversations.length, 1);
    });

    test('loadMoreConversations is no-op when cursor is null', () async {
      final controller = createHistoryController();
      controller.seed(controller.snapshot.copyWith(conversations: [testConversation(id: 1)]));
      controller.seed(controller.snapshot.copyWith(hasMore: true));
      controller.seed(controller.snapshot.copyWith(nextCursor: null));

      await controller.loadMoreConversations();
      expect(controller.snapshot.hasMore, isFalse);
    });

    test('loadMoreConversations is no-op when cursor is empty', () async {
      final controller = createHistoryController();
      controller.seed(controller.snapshot.copyWith(conversations: [testConversation(id: 1)]));
      controller.seed(controller.snapshot.copyWith(hasMore: true));
      controller.seed(controller.snapshot.copyWith(nextCursor: ''));

      await controller.loadMoreConversations();
      expect(controller.snapshot.hasMore, isFalse);
    });

    test('loadMoreConversations is no-op when already loading more', () async {
      final controller = createHistoryController();
      controller.seed(controller.snapshot.copyWith(conversations: [testConversation(id: 1)]));
      controller.seed(controller.snapshot.copyWith(hasMore: true));
      controller.seed(controller.snapshot.copyWith(nextCursor: 'cursor'));
      controller.seed(controller.snapshot.copyWith(status: HistoryLoadStatus.loadingMore));

      await controller.loadMoreConversations();
      verifyNever(() => mockRepository.getConversations(cursor: any(named: 'cursor')));
    });

    test('loadMoreConversations is no-op when isLoadingConversations is true', () async {
      final controller = createHistoryController();
      controller.seed(controller.snapshot.copyWith(conversations: [testConversation(id: 1)]));
      controller.seed(controller.snapshot.copyWith(hasMore: true));
      controller.seed(controller.snapshot.copyWith(nextCursor: 'cursor'));
      controller.seed(controller.snapshot.copyWith(status: HistoryLoadStatus.loading));

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
      when(
        () => mockRepository.getConversations(cursor: 'cursor_1'),
      ).thenAnswer((_) async => secondPage);

      final controller = createHistoryController();
      await controller.loadConversations();
      await controller.loadMoreConversations();

      expect(controller.snapshot.conversations.length, 3);
      expect(controller.snapshot.conversations.map((c) => c.id).toList(), [1, 2, 3]);
    });

    test('loadMoreConversations sets error flag on failure', () async {
      final firstPage = ConversationsPage(
        items: [testConversation(id: 1)],
        hasMore: true,
        nextCursor: 'cursor_1',
      );
      when(() => mockRepository.getConversations()).thenAnswer((_) async => firstPage);
      when(
        () => mockRepository.getConversations(cursor: 'cursor_1'),
      ).thenThrow(Exception('Network error'));

      final controller = createHistoryController();
      await controller.loadConversations();
      await controller.loadMoreConversations();

      expect(controller.snapshot.error != null, isTrue);
      expect(controller.snapshot.isLoading, isFalse);
    });

    // ── loadConversations guards ──────────────────────────────────────────

    test('loadConversations is no-op when already loading', () async {
      when(
        () => mockRepository.getConversations(),
      ).thenAnswer((_) async => const ConversationsPage(items: [], hasMore: false));

      final controller = createHistoryController();
      controller.seed(controller.snapshot.copyWith(status: HistoryLoadStatus.loading));

      await controller.loadConversations();
      verifyNever(() => mockRepository.getConversations());
    });

    test('loadConversations is no-op when loading more', () async {
      when(
        () => mockRepository.getConversations(),
      ).thenAnswer((_) async => const ConversationsPage(items: [], hasMore: false));

      final controller = createHistoryController();
      controller.seed(controller.snapshot.copyWith(status: HistoryLoadStatus.loadingMore));

      await controller.loadConversations();
      verifyNever(() => mockRepository.getConversations());
    });

    // ── startNewConversation ──────────────────────────────────────────────

    test('startNewConversation clears messages and conversationId', () {
      final streamController = StreamController<AssistantFrame>();
      when(
        () => mockRepository.streamChat(message: 'hi', conversationId: null),
      ).thenAnswer((_) => streamController.stream);

      final controller = createController();
      controller.sendMessage('hi');
      controller.seed(controller.snapshot.copyWith(conversationId: 7));
      expect(controller.snapshot.messages, isNotEmpty);
      expect(controller.snapshot.isStreaming, isTrue);

      controller.startNewConversation();

      expect(controller.snapshot.conversationId, isNull);
      expect(controller.snapshot.messages, isEmpty);
      expect(controller.snapshot.isStreaming, isFalse);

      streamController.close();
    });

    // ── deleteConversation error ──────────────────────────────────────────

    test('deleteConversation handles exception gracefully', () async {
      when(() => mockRepository.deleteConversation(3)).thenThrow(Exception('Server error'));

      final controller = createHistoryController();
      controller.seed(
        controller.snapshot.copyWith(
          conversations: [testConversation(id: 1), testConversation(id: 3)],
        ),
      );

      await controller.deleteConversation(3);

      expect(controller.snapshot.conversations.length, 2);
      expect(controller.snapshot.deletingId != null, isFalse);
    });

    // ── onClose ───────────────────────────────────────────────────────────

    test('provider disposal cancels stream subscription', () {
      final streamController = StreamController<AssistantFrame>();
      when(
        () => mockRepository.streamChat(message: 'hi', conversationId: null),
      ).thenAnswer((_) => streamController.stream);

      final controller = createController();
      controller.sendMessage('hi');
      expect(streamController.hasListener, isTrue);

      harness.container.dispose();
      expect(streamController.hasListener, isFalse);

      streamController.close();
    });

    // ── the backend limit and a missing conversation ──────────────────────

    test('a message over 4000 characters is not sent', () {
      final controller = createController();

      controller.sendMessage('x' * 4001);

      expect(controller.snapshot.messages, isEmpty);
      verifyNever(
        () => mockRepository.streamChat(
          message: any(named: 'message'),
          conversationId: any(named: 'conversationId'),
        ),
      );
    });

    test('a message of exactly 4000 characters is sent', () {
      final text = 'x' * 4000;
      when(
        () => mockRepository.streamChat(message: text, conversationId: null),
      ).thenAnswer((_) => const Stream<AssistantFrame>.empty());
      final controller = createController();

      controller.sendMessage(text);

      expect(controller.snapshot.messages, hasLength(2));
    });

    test('a 404 for the conversation clears its id so the next message starts a new one', () async {
      final streamController = StreamController<AssistantFrame>();
      when(
        () => mockRepository.streamChat(message: 'hi', conversationId: 5),
      ).thenAnswer((_) => streamController.stream);

      final controller = createController();
      controller.seed(controller.snapshot.copyWith(conversationId: 5));
      controller.sendMessage('hi');

      streamController.addError(
        ApiException('The request could not be completed.', code: 'NOT_FOUND', statusCode: 404),
      );
      await Future<void>.value();

      expect(controller.snapshot.streamStatus, AssistantStreamStatus.failed);
      expect(isConversationMissing(controller.snapshot.streamError), isTrue);
      expect(controller.snapshot.conversationId, isNull);

      await streamController.close();
    });

    test('other failures keep the conversation id', () async {
      final streamController = StreamController<AssistantFrame>();
      when(
        () => mockRepository.streamChat(message: 'hi', conversationId: 5),
      ).thenAnswer((_) => streamController.stream);

      final controller = createController();
      controller.seed(controller.snapshot.copyWith(conversationId: 5));
      controller.sendMessage('hi');

      streamController.addError(NetworkException('offline'));
      await Future<void>.value();

      expect(controller.snapshot.conversationId, 5);
      expect(isConversationMissing(controller.snapshot.streamError), isFalse);

      await streamController.close();
    });
  });
}
