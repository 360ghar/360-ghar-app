import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/widgets/common/max_content_width.dart';
import 'package:ghar360/features/assistant/data/models/chat_message_model.dart';
import 'package:ghar360/features/assistant/presentation/controllers/assistant_controller.dart';
import 'package:ghar360/features/assistant/presentation/widgets/chat_input_bar.dart';
import 'package:ghar360/features/assistant/presentation/widgets/chat_message_bubble.dart';
import 'package:ghar360/features/assistant/presentation/widgets/chat_widget_bubble.dart';
import 'package:ghar360/features/assistant/presentation/widgets/suggested_prompts.dart';
import 'package:ghar360/features/assistant/presentation/widgets/tool_call_indicator.dart';

class AssistantView extends GetView<AssistantController> {
  const AssistantView({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.design;

    return Scaffold(
      key: const ValueKey('qa.assistant.screen'),
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text('assistant'.tr),
        actions: [
          IconButton(
            key: const ValueKey('qa.assistant.new_chat'),
            icon: const Icon(Icons.add_comment_outlined, size: 22),
            onPressed: controller.startNewConversation,
            tooltip: 'assistant_new_chat'.tr,
          ),
        ],
      ),
      body: MaxContentWidth(
        // Cap the chat column so messages and the input bar stay centered and
        // readable on tablet/desktop widths. No-op on compact (phone) widths.
        maxWidth: 720,
        child: Column(
          children: [
            Expanded(child: _buildMessageList(palette)),
            // Tool call indicator
            Obx(() {
              final tool = controller.activeToolCall.value;
              if (tool == null) return const SizedBox.shrink();
              return ToolCallIndicator(toolName: tool);
            }),
            // Input bar
            Obx(
              () => ChatInputBar(
                onSend: controller.sendMessage,
                isStreaming: controller.isStreaming.value,
                onCancel: controller.cancelStream,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(AppPalette palette) {
    return Obx(() {
      final messages = controller.messages;

      if (messages.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: SuggestedPrompts(onPromptTap: controller.sendMessage),
          ),
        );
      }

      return ListView.builder(
        key: const ValueKey('qa.assistant.message_list'),
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        reverse: true,
        itemCount: messages.length,
        itemBuilder: (context, index) {
          // Reverse index because list is reversed
          final msgIndex = messages.length - 1 - index;
          return _buildMessageItem(messages[msgIndex]);
        },
      );
    });
  }

  Widget _buildMessageItem(ChatMessageModel message) {
    switch (message.role) {
      case ChatRole.user:
        return ChatMessageBubble(message: message);
      case ChatRole.assistant:
        // Assistant text is always rendered whenever there is any. It used to
        // be suppressed when a widget followed, on the assumption the widget
        // showed the same information — but the text is the only render path
        // that cannot fail, so hiding it turned any widget failure into "did
        // not answer". Only a settled *empty* turn is skipped, so a
        // widget-only reply does not leave a blank stub bubble.
        if (message.content.trim().isEmpty && !message.isStreaming) {
          return const SizedBox.shrink();
        }
        return ChatMessageBubble(message: message);
      case ChatRole.widget:
        return ChatWidgetBubble(message: message);
      case ChatRole.toolCall:
      case ChatRole.toolResult:
      case ChatRole.error:
        return const SizedBox.shrink();
    }
  }
}
