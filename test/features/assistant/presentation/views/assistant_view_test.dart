import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/network/sse_client.dart';
import 'package:ghar360/core/translations/app_translations.dart';
import 'package:ghar360/features/assistant/data/assistant_repository.dart';
import 'package:ghar360/features/assistant/data/models/chat_message_model.dart';
import 'package:ghar360/features/assistant/presentation/controllers/assistant_controller.dart';
import 'package:ghar360/features/assistant/presentation/views/assistant_view.dart';
import 'package:ghar360/features/assistant/presentation/widgets/chat_input_bar.dart';
import 'package:ghar360/features/assistant/presentation/widgets/chat_message_bubble.dart';
import 'package:ghar360/features/assistant/presentation/widgets/chat_widget_bubble.dart';
import 'package:ghar360/features/assistant/presentation/widgets/suggested_prompts.dart';
import 'package:ghar360/features/assistant/presentation/widgets/tool_call_indicator.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fake_webview_platform.dart';
import '../../../../helpers/getx_test_binding.dart';
import '../../../../helpers/mocks.dart';

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
  late MockAssistantRepository mockRepository;
  late MockSseClient mockSseClient;
  late AssistantController controller;

  setUp(() {
    GetxTestBinding.init();
    installFakeWebViewPlatform();
    FlutterError.onError = (details) {
      if (!details.summary.toString().contains('overflowed')) {
        FlutterError.presentError(details);
      }
    };
    mockRepository = MockAssistantRepository();
    mockSseClient = MockSseClient();
    GetxTestBinding.bind()
      ..register<AssistantRepository>(mockRepository)
      ..register<SseClient>(mockSseClient);

    // Stub streamChat so sendMessage doesn't crash if called.
    when(
      () => mockRepository.streamChat(
        message: any(named: 'message'),
        conversationId: any(named: 'conversationId'),
      ),
    ).thenAnswer((_) => const Stream<SseEvent>.empty());

    controller = AssistantController();
    controller.onInit();
    // Re-register the controller instance so GetView finds it.
    Get.put<AssistantController>(controller, permanent: true);
  });

  tearDown(() {
    FlutterError.onError = FlutterError.presentError;
    uninstallFakeWebViewPlatform();
    GetxTestBinding.reset();
  });

  Future<void> pumpView(WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        fallbackLocale: const Locale('en', 'US'),
        home: const AssistantView(),
      ),
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

    testWidgets('renders AppBar with assistant title', (tester) async {
      await pumpView(tester);

      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('renders new chat IconButton with correct key', (tester) async {
      await pumpView(tester);

      expect(find.byKey(const ValueKey('qa.assistant.new_chat')), findsOneWidget);
    });

    testWidgets('renders new chat icon (add_comment_outlined)', (tester) async {
      await pumpView(tester);

      expect(find.byIcon(Icons.add_comment_outlined), findsOneWidget);
    });

    testWidgets('calls startNewConversation when new chat button tapped', (tester) async {
      await pumpView(tester);

      await tester.tap(find.byKey(const ValueKey('qa.assistant.new_chat')));
      await tester.pump();

      // startNewConversation clears messages and cancels stream.
      expect(controller.messages, isEmpty);
      expect(controller.conversationId.value, isNull);
    });

    // ── Empty state (suggested prompts) ──────────────────────────────────

    testWidgets('shows SuggestedPrompts when messages is empty', (tester) async {
      await pumpView(tester);

      expect(find.byType(SuggestedPrompts), findsOneWidget);
      expect(find.byIcon(Icons.smart_toy_outlined), findsOneWidget);
    });

    testWidgets('does not show ListView when messages is empty', (tester) async {
      await pumpView(tester);

      expect(find.byKey(const ValueKey('qa.assistant.message_list')), findsNothing);
    });

    // ── Message list rendering ───────────────────────────────────────────

    testWidgets('shows ListView when messages are present', (tester) async {
      controller.messages.addAll([_userMessage(), _assistantMessage()]);
      await pumpView(tester);

      expect(find.byKey(const ValueKey('qa.assistant.message_list')), findsOneWidget);
    });

    testWidgets('renders user message as ChatMessageBubble', (tester) async {
      controller.messages.add(_userMessage(content: 'Test user message'));
      await pumpView(tester);

      expect(find.byType(ChatMessageBubble), findsOneWidget);
      expect(find.text('Test user message'), findsOneWidget);
    });

    testWidgets('renders assistant message as ChatMessageBubble', (tester) async {
      controller.messages.add(_assistantMessage(content: 'Test assistant reply'));
      await pumpView(tester);

      expect(find.byType(ChatMessageBubble), findsOneWidget);
    });

    testWidgets('renders widget message as ChatWidgetBubble', (tester) async {
      controller.messages.add(_widgetMessage());
      await pumpView(tester);

      expect(find.byType(ChatWidgetBubble), findsOneWidget);
    });

    testWidgets('hides toolCall messages (returns SizedBox.shrink)', (tester) async {
      controller.messages.add(_toolCallMessage());
      await pumpView(tester);

      // ToolCall messages should not render any visible content.
      expect(find.byType(ChatMessageBubble), findsNothing);
      expect(find.byType(ChatWidgetBubble), findsNothing);
    });

    testWidgets('hides toolResult messages (returns SizedBox.shrink)', (tester) async {
      controller.messages.add(_toolResultMessage());
      await pumpView(tester);

      expect(find.byType(ChatMessageBubble), findsNothing);
      expect(find.byType(ChatWidgetBubble), findsNothing);
    });

    testWidgets('hides error messages (returns SizedBox.shrink)', (tester) async {
      controller.messages.add(_errorMessage());
      await pumpView(tester);

      expect(find.byType(ChatMessageBubble), findsNothing);
      expect(find.byType(ChatWidgetBubble), findsNothing);
    });

    // ── _isFollowedByWidget logic ────────────────────────────────────────
    // When an assistant message is immediately followed by a widget message
    // (with no user message in between), the assistant text is suppressed
    // because the widget already displays the same information.

    testWidgets('suppresses assistant message when followed by widget', (tester) async {
      controller.messages.addAll([
        _assistantMessage(id: 'a1', content: 'Here are the results'),
        _widgetMessage(id: 'w1'),
      ]);
      await pumpView(tester);

      // The ChatWidgetBubble should be rendered.
      expect(find.byType(ChatWidgetBubble), findsOneWidget);
      // The assistant ChatMessageBubble should be suppressed (SizedBox.shrink).
      expect(find.text('Here are the results'), findsNothing);
    });

    testWidgets('shows assistant message when followed by user message', (tester) async {
      controller.messages.addAll([
        _assistantMessage(id: 'a1', content: 'Here are the results'),
        _userMessage(id: 'u1', content: 'Thanks'),
      ]);
      await pumpView(tester);

      // Both should render as ChatMessageBubble.
      expect(find.byType(ChatMessageBubble), findsNWidgets(2));
    });

    testWidgets('shows assistant message when not followed by widget', (tester) async {
      controller.messages.addAll([
        _userMessage(id: 'u1', content: 'Hello'),
        _assistantMessage(id: 'a1', content: 'Hi!'),
      ]);
      await pumpView(tester);

      expect(find.byType(ChatMessageBubble), findsNWidgets(2));
      expect(find.text('Hello'), findsOneWidget);
      expect(find.text('Hi!'), findsOneWidget);
    });

    testWidgets('suppresses assistant when tool result is between assistant and widget', (
      tester,
    ) async {
      controller.messages.addAll([
        _assistantMessage(id: 'a1', content: 'Searching...'),
        _toolResultMessage(id: 'tr1'),
        _widgetMessage(id: 'w1'),
      ]);
      await pumpView(tester);

      // Widget should render.
      expect(find.byType(ChatWidgetBubble), findsOneWidget);
      // Assistant text should be suppressed.
      expect(find.text('Searching...'), findsNothing);
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

      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pump();

      // The controller should have added a user message.
      expect(controller.messages.length, greaterThan(0));
      expect(controller.messages[0].content, 'Test message');
    });

    testWidgets('shows stop button when streaming', (tester) async {
      controller.isStreaming.value = true;
      await pumpView(tester);

      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsNothing);
    });

    testWidgets('stop button calls controller.cancelStream', (tester) async {
      controller.isStreaming.value = true;
      await pumpView(tester);

      await tester.tap(find.byIcon(Icons.stop_rounded));
      await tester.pump();

      expect(controller.isStreaming.value, isFalse);
    });

    // ── Tool call indicator ──────────────────────────────────────────────

    testWidgets('shows ToolCallIndicator when activeToolCall is set', (tester) async {
      controller.activeToolCall.value = 'search_properties';
      await pumpView(tester);

      expect(find.byType(ToolCallIndicator), findsOneWidget);
    });

    testWidgets('hides ToolCallIndicator when activeToolCall is null', (tester) async {
      controller.activeToolCall.value = null;
      await pumpView(tester);

      expect(find.byType(ToolCallIndicator), findsNothing);
    });

    testWidgets('hides ToolCallIndicator when activeToolCall is null and messages exist', (
      tester,
    ) async {
      controller.messages.add(_userMessage());
      controller.activeToolCall.value = null;
      await pumpView(tester);

      expect(find.byType(ToolCallIndicator), findsNothing);
    });

    // ── Mixed message list ───────────────────────────────────────────────

    testWidgets('renders multiple messages correctly', (tester) async {
      controller.messages.addAll([
        _userMessage(id: 'u1', content: 'First message'),
        _assistantMessage(id: 'a1', content: 'First reply'),
        _userMessage(id: 'u2', content: 'Second message'),
        _assistantMessage(id: 'a2', content: 'Second reply'),
      ]);
      await pumpView(tester);

      // All 4 messages should render as ChatMessageBubble.
      expect(find.byType(ChatMessageBubble), findsNWidgets(4));
    });

    testWidgets('clearing messages shows SuggestedPrompts again', (tester) async {
      controller.messages.add(_userMessage());
      await pumpView(tester);
      expect(find.byType(SuggestedPrompts), findsNothing);

      controller.messages.clear();
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
      expect(controller.messages.length, greaterThan(0));
      expect(controller.messages[0].role, ChatRole.user);
    });
  });
}
