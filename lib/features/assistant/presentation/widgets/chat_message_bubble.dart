import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:flutter_markdown/flutter_markdown.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/app_spacing.dart';
import 'package:ghar360/features/assistant/data/models/chat_message_model.dart';
import 'package:ghar360/features/assistant/presentation/widgets/paper_note.dart';

/// One chat turn on the white sheet. The reader's own words sit on a mint
/// slip at the right; the assistant's reply is a white hand-cut note at the
/// left, signed with the kite.
class ChatMessageBubble extends StatelessWidget {
  final ChatMessageModel message;

  const ChatMessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    final palette = context.design;
    final content = _buildContent(context, isUser, palette);

    return Padding(
      padding: EdgeInsets.only(
        left: isUser ? 48 : 16,
        right: isUser ? 16 : 48,
        bottom: isUser ? 12 : 20,
      ),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: isUser
            ? PaperNote(seed: 'slip-${message.id}', slip: true, child: content)
            : Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The kite rocks while the reply is still being written.
                  Padding(
                    padding: const EdgeInsets.only(top: 13),
                    child: AssistantKite(sway: message.isStreaming),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: PaperNote(seed: 'note-${message.id}', child: content),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isUser, AppPalette palette) {
    final text = Theme.of(context).textTheme;
    final body = text.bodyLarge?.copyWith(color: palette.textPrimary);
    if (message.isStreaming && message.content.isEmpty) {
      return Semantics(
        label: context.l10n.text('assistant_tool_executing'),
        liveRegion: true,
        child: _TypingIndicator(color: palette.textSecondary),
      );
    }

    // User text, and a reply while it streams, stay plain: MarkdownBody would
    // re-parse partial content on every chunk and drop characters.
    if (isUser || message.isStreaming) return SelectableText(message.content, style: body);

    return MarkdownBody(
      data: message.content,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: body,
        strong: body?.copyWith(fontWeight: FontWeight.w700),
        h1: text.headlineMedium,
        h2: text.headlineSmall,
        h3: text.titleMedium,
        listBullet: body?.copyWith(color: palette.textSecondary),
        code: text.bodyMedium?.copyWith(color: palette.textPrimary, backgroundColor: palette.slip),
        codeblockDecoration: BoxDecoration(
          color: palette.slip,
          borderRadius: BorderRadius.circular(AppBorderRadius.sm),
        ),
        codeblockPadding: const EdgeInsets.all(12),
        a: body?.copyWith(color: palette.accent, decoration: TextDecoration.underline),
        blockSpacing: 10,
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  final Color color;

  const _TypingIndicator({required this.color});

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) || !TickerMode.valuesOf(context).enabled) {
      _controller.stop();
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.2;
            final t = (_controller.value - delay).clamp(0.0, 1.0);
            final opacity = 0.3 + 0.7 * (0.5 + 0.5 * math.sin(t * 2 * math.pi));
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
