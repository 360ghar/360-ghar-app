import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/design/paper/paper_chrome.dart';
import 'package:ghar360/core/design/paper/paper_cut.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';
import 'package:ghar360/features/assistant/data/assistant_repository.dart';

class ChatInputBar extends StatefulWidget {
  final void Function(String) onSend;
  final bool isStreaming;
  final VoidCallback? onCancel;
  final String? draft;
  final ValueChanged<String>? onDraftChanged;
  final bool enabled;

  const ChatInputBar({
    super.key,
    required this.onSend,
    this.isStreaming = false,
    this.onCancel,
    this.draft,
    this.onDraftChanged,
    this.enabled = true,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();

  bool get _hasText => _textController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _textController.text = widget.draft ?? '';
    _textController.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(covariant ChatInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.draft != null && widget.draft != _textController.text) {
      _textController.value = TextEditingValue(
        text: widget.draft!,
        selection: TextSelection.collapsed(offset: widget.draft!.length),
      );
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _send() {
    final text = _textController.text.trim();
    if (text.isEmpty || widget.isStreaming || !widget.enabled) return;
    widget.onSend(text);
    if (widget.draft == null) _textController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.design;

    // The composer is a paper strip with a hand-cut top edge, like the nav strip.
    return CustomPaint(
      painter: _ComposerEdgePainter(sheet: palette.surface, edge: palette.sheetLip),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, _cut + 6, 16, 8),
        child: SafeArea(
          top: false,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // The field is a cut paper slip, like the Saved search slip.
              Expanded(
                child: ListenableBuilder(
                  listenable: _focusNode,
                  builder: (context, field) {
                    final enabled = widget.enabled && !widget.isStreaming;
                    final focused = _focusNode.hasFocus && enabled;
                    return DecoratedBox(
                      decoration: ShapeDecoration(
                        color: palette.raised,
                        shape: CutBorder(
                          seed: 'assistant-input',
                          amp: 1.5,
                          side: BorderSide(
                            color: focused
                                ? palette.accent
                                : enabled
                                ? palette.fieldBorder
                                : palette.border,
                            width: focused ? 2 : 1,
                          ),
                        ),
                      ),
                      child: field,
                    );
                  },
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    maxLines: 4,
                    minLines: 1,
                    // The backend refuses a longer message with a 422.
                    maxLength: AssistantRepository.maxMessageLength,
                    buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                        null,
                    key: const ValueKey('qa.assistant.input'),
                    enabled: widget.enabled && !widget.isStreaming,
                    onChanged: widget.onDraftChanged,
                    textInputAction: TextInputAction.newline,
                    onSubmitted: (_) {
                      if (widget.isStreaming || !_hasText) return;
                      _send();
                    },
                    decoration: InputDecoration(
                      hintText: context.l10n.text('assistant_input_hint'),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      constraints: const BoxConstraints(minHeight: 48),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildActionButton(palette),
            ],
          ),
        ),
      ),
    );
  }

  /// Send is the one marigold action of the screen, a cut paper square the
  /// height of a one-line field. Stop is a bare brick mark.
  Widget _buildActionButton(AppPalette palette) {
    if (widget.isStreaming) {
      return IconButton(
        key: const ValueKey('qa.assistant.stop'),
        onPressed: widget.onCancel,
        tooltip: context.l10n.text('stop_generating'),
        icon: PaperIcon(KnifeIcon.stop, color: palette.error, size: 24),
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      );
    }

    final canSend = _hasText && widget.enabled;
    return Tooltip(
      message: context.l10n.text('send_message'),
      child: FilledButton(
        key: const ValueKey('qa.assistant.send'),
        onPressed: canSend ? _send : null,
        style: const ButtonStyle(
          minimumSize: WidgetStatePropertyAll(Size.square(48)),
          maximumSize: WidgetStatePropertyAll(Size.square(48)),
          padding: WidgetStatePropertyAll(EdgeInsets.zero),
          shape: WidgetStatePropertyAll(CutBorder(seed: 'assistant-send', amp: 1.5)),
        ),
        child: const PaperIcon(KnifeIcon.arrowUpRight, size: 24),
      ),
    );
  }
}

const _cut = 10.0;

/// The composer's hand-cut top edge, with a thin rim to show the card.
class _ComposerEdgePainter extends CustomPainter {
  const _ComposerEdgePainter({required this.sheet, required this.edge});

  final Color sheet;
  final Color edge;

  @override
  void paint(Canvas canvas, Size size) {
    final band = parsePaperPath(
      cutBandPath(
        'assistant-composer',
        width: size.width,
        height: _cut,
        segments: math.max(6, (size.width / 32).round()),
      ),
      fillType: PathFillType.nonZero,
    )..addRect(Rect.fromLTWH(0, _cut - 0.5, size.width, size.height - _cut + 0.5));
    canvas.drawPath(band.shift(const Offset(0, -1.5)), Paint()..color = edge);
    canvas.drawPath(band, Paint()..color = sheet);
  }

  @override
  bool shouldRepaint(_ComposerEdgePainter old) => old.sheet != sheet || old.edge != edge;
}
