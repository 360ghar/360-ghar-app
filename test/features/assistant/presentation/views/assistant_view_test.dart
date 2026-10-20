import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/design/paper/paper_scene_data.dart';
import 'package:ghar360/core/widgets/paper/scene_header_sliver.dart';
import 'package:ghar360/features/assistant/data/assistant_repository.dart';
import 'package:ghar360/features/assistant/data/models/assistant_frame.dart';
import 'package:ghar360/features/assistant/data/models/chat_message_model.dart';
import 'package:ghar360/features/assistant/data/models/conversation_model.dart';
import 'package:ghar360/features/assistant/presentation/controllers/assistant_controller.dart';
import 'package:ghar360/features/assistant/presentation/views/assistant_view.dart';
import 'package:ghar360/features/assistant/presentation/widgets/chat_input_bar.dart';
import 'package:ghar360/features/assistant/presentation/widgets/chat_message_bubble.dart';
import 'package:ghar360/features/assistant/presentation/widgets/chat_widget_bubble.dart';
import 'package:ghar360/features/assistant/presentation/widgets/suggested_prompts.dart';
import 'package:ghar360/features/assistant/presentation/widgets/tool_call_indicator.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/assistant_test_harness.dart';
import '../../../../helpers/fake_webview_platform.dart';
import '../../../../helpers/knife_finders.dart';
import '../../../../helpers/provider_test_app.dart';

ChatMessageModel _userMessage({String content = 'Hello', String id = 'u1'}) {
  return ChatMessageModel(id: id, role: ChatRole.user, content: content, timestamp: DateTime.now());
}

ChatMessageModel _assistantMessage({String content = 'Hi there!', String id = 'a1'}) {
  return ChatMessageModel(
    id: id,
    role: ChatRole.assistant,
    content: content,
    timestamp: DateTime.now(),
  );
}

ChatMessageModel _widgetMessage({String id = 'w1'}) {
  return ChatMessageModel(
    id: id,
    role: ChatRole.widget,
    content: '',
    widgetName: 'property_card',
    widgetData: {'id': 1},
    timestamp: DateTime.now(),
  );
}

ChatMessageModel _toolCallMessage({String id = 'tc1'}) {
  return ChatMessageModel(
    id: id,
    role: ChatRole.toolCall,
    content: '',
    toolName: 'search',
    timestamp: DateTime.now(),
  );
}

ChatMessageModel _toolResultMessage({String id = 'tr1'}) {
  return ChatMessageModel(
    id: id,
    role: ChatRole.toolResult,
    content: '',
    timestamp: DateTime.now(),
  );
}

ChatMessageModel _errorMessage({String id = 'e1'}) {
  return ChatMessageModel(
    id: id,
    role: ChatRole.error,
    content: 'Something went wrong',
    timestamp: DateTime.now(),
  );
}

void main() {
  late AssistantTestHarness harness;
  late MockAssistantRepository mockRepository;
  late TestAssistantController controller;
  setUp(() {
    installFakeWebViewPlatform();
    harness = AssistantTestHarness();
    mockRepository = harness.repository;
    when(
      () => mockRepository.streamChat(
        message: any(named: 'message'),
        conversationId: any(named: 'conversationId'),
      ),
    ).thenAnswer((_) => const Stream<AssistantFrame>.empty());
    controller = harness.conversation();
    controller.seed(AssistantState(loadStatus: ConversationLoadStatus.ready));
  });
  tearDown(() {
    uninstallFakeWebViewPlatform();
    harness.dispose();
  });
  Future<void> pumpView(WidgetTester tester) async {
    await tester.pumpProviderApp(
      UncontrolledProviderScope(container: harness.container, child: const AssistantView()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('AssistantView', () {
    // ── Basic rendering ──────────────────────────────────────────────────

    testWidgets('renders Scaffold with correct key', (tester) async {
      await pumpView(tester);

      expect(find.byKey(const ValueKey('qa.assistant.screen')), findsOneWidget);
    });

    testWidgets('renders the kite scene header with the assistant title', (tester) async {
      await pumpView(tester);

      final header = tester.widget<SceneHeaderSliver>(find.byType(SceneHeaderSliver));
      expect(header.title, 'Assistant');
      expect(header.qaId, 'qa.assistant.title');
      expect(header.scene.art, same(paperHeaders['assistant']));
      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('renders new chat IconButton with correct key', (tester) async {
      await pumpView(tester);

      expect(find.byKey(const ValueKey('qa.assistant.new_chat')), findsOneWidget);
    });

    testWidgets('renders new chat icon (add_comment_outlined)', (tester) async {
      await pumpView(tester);

      expect(findKnife(KnifeIcon.chat), findsOneWidget);
    });

    testWidgets('calls startNewConversation when new chat button tapped', (tester) async {
      await pumpView(tester);

      await tester.tap(find.byKey(const ValueKey('qa.assistant.new_chat')));
      await tester.pump();

      // startNewConversation clears messages and cancels stream.
      expect(controller.snapshot.messages, isEmpty);
      expect(controller.snapshot.conversationId, isNull);
    });

    // ── Empty state (suggested prompts) ──────────────────────────────────

    testWidgets('shows SuggestedPrompts when messages is empty', (tester) async {
      await pumpView(tester);

      expect(find.byType(SuggestedPrompts), findsOneWidget);
      // Four prompts, each a bare arrow; the send arrow is the fifth.
      expect(findKnife(KnifeIcon.arrowUpRight), findsNWidgets(5));
    });

    testWidgets('does not show ListView when messages is empty', (tester) async {
      await pumpView(tester);

      expect(find.byKey(const ValueKey('qa.assistant.message_list')), findsNothing);
    });

    // ── Message list rendering ───────────────────────────────────────────

    testWidgets('shows ListView when messages are present', (tester) async {
      controller.seed(
        controller.snapshot.copyWith(messages: [_userMessage(), _assistantMessage()]),
      );
      await pumpView(tester);

      expect(find.byKey(const ValueKey('qa.assistant.message_list')), findsOneWidget);
    });

    testWidgets('renders user message as ChatMessageBubble', (tester) async {
      controller.seed(
        controller.snapshot.copyWith(messages: [_userMessage(content: 'Test user message')]),
      );
      await pumpView(tester);

      expect(find.byType(ChatMessageBubble), findsOneWidget);
      expect(find.text('Test user message'), findsOneWidget);
    });

    testWidgets('renders assistant message as ChatMessageBubble', (tester) async {
      controller.seed(
        controller.snapshot.copyWith(
          messages: [_assistantMessage(content: 'Test assistant reply')],
        ),
      );
      await pumpView(tester);

      expect(find.byType(ChatMessageBubble), findsOneWidget);
    });

    testWidgets('renders widget message as ChatWidgetBubble', (tester) async {
      controller.seed(controller.snapshot.copyWith(messages: [_widgetMessage()]));
      await pumpView(tester);

      expect(find.byType(ChatWidgetBubble), findsOneWidget);
    });

    testWidgets('hides toolCall messages (returns SizedBox.shrink)', (tester) async {
      controller.seed(controller.snapshot.copyWith(messages: [_toolCallMessage()]));
      await pumpView(tester);

      // ToolCall messages should not render any visible content.
      expect(find.byType(ChatMessageBubble), findsNothing);
      expect(find.byType(ChatWidgetBubble), findsNothing);
    });

    testWidgets('hides toolResult messages (returns SizedBox.shrink)', (tester) async {
      controller.seed(controller.snapshot.copyWith(messages: [_toolResultMessage()]));
      await pumpView(tester);

      expect(find.byType(ChatMessageBubble), findsNothing);
      expect(find.byType(ChatWidgetBubble), findsNothing);
    });

    testWidgets('shows localized recovery for error messages', (tester) async {
      controller.seed(controller.snapshot.copyWith(messages: [_errorMessage()]));
      await pumpView(tester);

      expect(find.byType(ChatMessageBubble), findsNothing);
      expect(find.byType(ChatWidgetBubble), findsNothing);
      expect(find.byKey(const ValueKey('assistant_stream_failed')), findsOneWidget);
    });

    // ── _isFollowedByWidget logic ────────────────────────────────────────
    // When an assistant message is immediately followed by a widget message
    // (with no user message in between), the assistant text is suppressed
    // because the widget already displays the same information.

    testWidgets('keeps assistant message when followed by widget', (tester) async {
      controller.seed(
        controller.snapshot.copyWith(
          messages: [
            _assistantMessage(id: 'a1', content: 'Here are the results'),
            _widgetMessage(id: 'w1'),
          ],
        ),
      );
      await pumpView(tester);

      // Both render: the text is the only path that cannot fail, so it must
      // never be hidden behind a widget that might not load.
      expect(find.byType(ChatWidgetBubble), findsOneWidget);
      expect(find.text('Here are the results'), findsOneWidget);
    });

    testWidgets('shows assistant message when followed by user message', (tester) async {
      controller.seed(
        controller.snapshot.copyWith(
          messages: [
            _assistantMessage(id: 'a1', content: 'Here are the results'),
            _userMessage(id: 'u1', content: 'Thanks'),
          ],
        ),
      );
      await pumpView(tester);

      // Both should render as ChatMessageBubble.
      expect(find.byType(ChatMessageBubble), findsNWidgets(2));
    });

    testWidgets('shows assistant message when not followed by widget', (tester) async {
      controller.seed(
        controller.snapshot.copyWith(
          messages: [
            _userMessage(id: 'u1', content: 'Hello'),
            _assistantMessage(id: 'a1', content: 'Hi!'),
          ],
        ),
      );
      await pumpView(tester);

      expect(find.byType(ChatMessageBubble), findsNWidgets(2));
      expect(find.text('Hello'), findsOneWidget);
      expect(find.text('Hi!'), findsOneWidget);
    });

    testWidgets('keeps assistant when tool result is between assistant and widget', (tester) async {
      controller.seed(
        controller.snapshot.copyWith(
          messages: [
            _assistantMessage(id: 'a1', content: 'Searching...'),
            _toolResultMessage(id: 'tr1'),
            _widgetMessage(id: 'w1'),
          ],
        ),
      );
      await pumpView(tester);

      expect(find.byType(ChatWidgetBubble), findsOneWidget);
      expect(find.text('Searching...'), findsOneWidget);
      // The tool-result row itself stays hidden.
      expect(find.byType(ChatMessageBubble), findsOneWidget);
    });

    // ── Input bar ────────────────────────────────────────────────────────

    testWidgets('renders ChatInputBar', (tester) async {
      await pumpView(tester);

      expect(find.byType(ChatInputBar), findsOneWidget);
    });

    testWidgets('input bar send button calls controller.sendMessage', (tester) async {
      await pumpView(tester);

      await tester.enterText(find.byType(TextField), 'Test message');
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('qa.assistant.send')));
      await tester.pump();

      // The controller should have added a user message.
      expect(controller.snapshot.messages.length, greaterThan(0));
      expect(controller.snapshot.messages[0].content, 'Test message');
    });

    testWidgets('shows stop button when streaming', (tester) async {
      controller.seed(controller.snapshot.copyWith(streamStatus: AssistantStreamStatus.streaming));
      await pumpView(tester);

      expect(findKnife(KnifeIcon.stop), findsOneWidget);
      expect(find.byKey(const ValueKey('qa.assistant.send')), findsNothing);
    });

    testWidgets('stop button calls controller.cancelStream', (tester) async {
      controller.seed(controller.snapshot.copyWith(streamStatus: AssistantStreamStatus.streaming));
      await pumpView(tester);

      await tester.tap(findKnife(KnifeIcon.stop));
      await tester.pump();

      expect(controller.snapshot.isStreaming, isFalse);
    });

    // ── Tool call indicator ──────────────────────────────────────────────

    testWidgets('shows ToolCallIndicator when activeToolCall is set', (tester) async {
      controller.seed(
        controller.snapshot.copyWith(activeToolCalls: {'call_1': 'search_properties'}),
      );
      await pumpView(tester);

      expect(find.byType(ToolCallIndicator), findsOneWidget);
    });

    testWidgets('hides ToolCallIndicator when activeToolCall is null', (tester) async {
      controller.seed(controller.snapshot.copyWith(activeToolCalls: const {}));
      await pumpView(tester);

      expect(find.byType(ToolCallIndicator), findsNothing);
    });

    testWidgets('hides ToolCallIndicator when activeToolCall is null and messages exist', (
      tester,
    ) async {
      controller.seed(controller.snapshot.copyWith(messages: [_userMessage()]));
      controller.seed(controller.snapshot.copyWith(activeToolCalls: const {}));
      await pumpView(tester);

      expect(find.byType(ToolCallIndicator), findsNothing);
    });

    // ── Mixed message list ───────────────────────────────────────────────

    testWidgets('renders multiple messages correctly', (tester) async {
      controller.seed(
        controller.snapshot.copyWith(
          messages: [
            _userMessage(id: 'u1', content: 'First message'),
            _assistantMessage(id: 'a1', content: 'First reply'),
            _userMessage(id: 'u2', content: 'Second message'),
            _assistantMessage(id: 'a2', content: 'Second reply'),
          ],
        ),
      );
      await pumpView(tester);

      // All 4 messages should render as ChatMessageBubble.
      expect(find.byType(ChatMessageBubble), findsNWidgets(4));
    });

    testWidgets('clearing messages shows SuggestedPrompts again', (tester) async {
      controller.seed(controller.snapshot.copyWith(messages: [_userMessage()]));
      await pumpView(tester);
      expect(find.byType(SuggestedPrompts), findsNothing);

      controller.seed(controller.snapshot.copyWith(messages: []));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SuggestedPrompts), findsOneWidget);
    });

    // ── SuggestedPrompts interaction ─────────────────────────────────────

    testWidgets('tapping a suggested prompt sends a message', (tester) async {
      await pumpView(tester);

      // Find prompt chips by their GestureDetector wrappers inside
      // SuggestedPrompts. Each chip is a GestureDetector → Container → Text.
      final promptTexts = find.descendant(
        of: find.byType(SuggestedPrompts),
        matching: find.byType(Text),
      );
      // Should have greeting + subtitle + 4 prompt chips = 6 Text widgets.
      expect(promptTexts, findsWidgets);

      // Tap the first prompt chip text (after greeting/subtitle).
      // The chips start at index 2 (after greeting and subtitle).
      await tester.tap(promptTexts.at(2));
      await tester.pump();

      // The controller should have added a user message.
      expect(controller.snapshot.messages.length, greaterThan(0));
      expect(controller.snapshot.messages[0].role, ChatRole.user);
    });
    testWidgets('initial conversation failure differs from empty and retries', (tester) async {
      final result = Completer<MessagesPage>();
      when(() => mockRepository.getMessagesPage(7)).thenAnswer((_) => result.future);
      await tester.pumpProviderApp(
        UncontrolledProviderScope(
          container: harness.container,
          child: const AssistantView(conversationId: 7),
        ),
      );
      await tester.pump();
      expect(find.byType(SuggestedPrompts), findsNothing);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      result.completeError(Exception('private backend detail'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Failed to load messages'), findsOneWidget);
      expect(find.textContaining('private backend detail'), findsNothing);
      expect(find.byType(SuggestedPrompts), findsNothing);
      when(() => mockRepository.getMessagesPage(7)).thenAnswer(
        (_) async => MessagesPage(items: [_assistantMessage(content: 'Recovered')], hasMore: false),
      );
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(find.text('Recovered'), findsOneWidget);
    });

    testWidgets('stream failure keeps partial reply and restores editable prompt', (tester) async {
      final stream = StreamController<AssistantFrame>();
      when(
        () => mockRepository.streamChat(message: 'Keep me', conversationId: null),
      ).thenAnswer((_) => stream.stream);
      await pumpView(tester);
      controller.sendMessage('Keep me');
      stream.add(const TextChunkFrame('Partial reply'));
      stream.add(
        const ErrorFrame(code: AssistantErrorCode.agentError, message: 'private diagnostics'),
      );
      await tester.pump();
      expect(find.text('Partial reply'), findsOneWidget);
      expect(find.byKey(const ValueKey('assistant_stream_failed')), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Keep me');
      expect(find.textContaining('private diagnostics'), findsNothing);
      unawaited(stream.close());
      await tester.pump();
    });

    testWidgets('history is visible, can fail, and can retry to empty', (tester) async {
      when(() => mockRepository.getConversations()).thenThrow(Exception('offline'));
      await pumpView(tester);
      await tester.tap(find.byKey(const ValueKey('qa.assistant.history')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('assistant_history_failed')), findsOneWidget);
      expect(find.text('No conversations yet'), findsNothing);
      when(
        () => mockRepository.getConversations(),
      ).thenAnswer((_) async => const ConversationsPage(items: [], hasMore: false));
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('No conversations yet'), findsOneWidget);
    });

    testWidgets('selecting history opens the chosen conversation family', (tester) async {
      when(() => mockRepository.getConversations()).thenAnswer(
        (_) async => ConversationsPage(
          items: [
            ConversationModel(
              id: 7,
              title: 'Saved chat',
              createdAt: DateTime.utc(2024),
              updatedAt: DateTime.utc(2024),
            ),
          ],
          hasMore: false,
        ),
      );
      when(() => mockRepository.getMessagesPage(7)).thenAnswer(
        (_) async =>
            MessagesPage(items: [_assistantMessage(content: 'Loaded saved chat')], hasMore: false),
      );
      await pumpView(tester);
      await tester.tap(find.byKey(const ValueKey('qa.assistant.history')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Saved chat'));
      await tester.pumpAndSettle();
      expect(find.text('Loaded saved chat'), findsOneWidget);
      verify(() => mockRepository.getMessagesPage(7)).called(1);
    });

    testWidgets('conversation constructor changes switch provider identity', (tester) async {
      when(() => mockRepository.getMessagesPage(7)).thenAnswer(
        (_) async =>
            MessagesPage(items: [_assistantMessage(content: 'Conversation seven')], hasMore: false),
      );
      when(() => mockRepository.getMessagesPage(8)).thenAnswer(
        (_) async =>
            MessagesPage(items: [_assistantMessage(content: 'Conversation eight')], hasMore: false),
      );
      await tester.pumpProviderApp(
        UncontrolledProviderScope(
          container: harness.container,
          child: const AssistantView(conversationId: 7),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Conversation seven'), findsOneWidget);
      await tester.pumpProviderApp(
        UncontrolledProviderScope(
          container: harness.container,
          child: const AssistantView(conversationId: 8),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Conversation seven'), findsNothing);
      expect(find.text('Conversation eight'), findsOneWidget);
    });

    testWidgets('inactive view cancels its stream and keeps draft', (tester) async {
      final active = ValueNotifier(true);
      addTearDown(active.dispose);
      final stream = StreamController<AssistantFrame>();
      when(
        () => mockRepository.streamChat(message: 'Keep on pause', conversationId: null),
      ).thenAnswer((_) => stream.stream);
      await tester.pumpProviderApp(
        UncontrolledProviderScope(
          container: harness.container,
          child: ValueListenableBuilder<bool>(
            valueListenable: active,
            builder: (_, enabled, child) => TickerMode(enabled: enabled, child: child!),
            child: const AssistantView(),
          ),
        ),
      );
      await tester.pump();
      controller.sendMessage('Keep on pause');
      await tester.pump();
      active.value = false;
      await tester.pump();
      expect(stream.hasListener, isFalse);
      expect(controller.snapshot.draft, 'Keep on pause');
      expect(controller.snapshot.streamStatus, AssistantStreamStatus.interrupted);
      expect(tester.takeException(), isNull);
      unawaited(stream.close());
      await tester.pump();
    });

    for (final brightness in Brightness.values) {
      testWidgets('narrow large text and keyboard retain recovery in $brightness', (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = const FakeViewPadding(bottom: 240);
        addTearDown(tester.view.reset);
        controller.seed(
          AssistantState(
            loadStatus: ConversationLoadStatus.ready,
            messages: [_userMessage(), _assistantMessage()],
            draft: 'Retained input',
            streamStatus: AssistantStreamStatus.failed,
            storageError: Exception('disk'),
          ),
        );
        await tester.pumpProviderApp(
          UncontrolledProviderScope(container: harness.container, child: const AssistantView()),
          theme: ThemeData(brightness: brightness),
          textScale: 2,
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Retained input');
        expect(find.byKey(const ValueKey('assistant_draft_save_failed')), findsOneWidget);
      });
    }
  });
}
