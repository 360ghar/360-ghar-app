import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';

class ChatInputBar extends StatefulWidget {
  final void Function(String) onSend;
  final bool isStreaming;
  final VoidCallback? onCancel;

  const ChatInputBar({super.key, required this.onSend, this.isStreaming = false, this.onCancel});

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
    _textController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _send() {
    final text = _textController.text.trim();
    if (text.isEmpty || widget.isStreaming) return;
    widget.onSend(text);
    _textController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.design;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.border.withValues(alpha: 0.3))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: palette.inputBackground,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: palette.border.withValues(alpha: 0.4)),
                ),
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  maxLines: 4,
                  minLines: 1,
                  enabled: !widget.isStreaming,
                  textInputAction: TextInputAction.newline,
                  onSubmitted: (_) {
                    if (widget.isStreaming || !_hasText) return;
                    _send();
                  },
                  style: TextStyle(fontSize: 14, color: palette.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'assistant_input_hint'.tr,
                    hintStyle: TextStyle(color: palette.textTertiary, fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _buildActionButton(palette),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(AppPalette palette) {
    if (widget.isStreaming) {
      return Semantics(
        button: true,
        label: 'stop_generating'.tr,
        child: IconButton(
          onPressed: widget.onCancel,
          tooltip: 'stop_generating'.tr,
          icon: Icon(Icons.stop_rounded, color: palette.error, size: 22),
          style: IconButton.styleFrom(
            backgroundColor: palette.error.withValues(alpha: 0.1),
            minimumSize: const Size(44, 44),
            fixedSize: const Size(44, 44),
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      enabled: _hasText,
      label: 'send_message'.tr,
      child: IconButton(
        onPressed: _hasText ? _send : null,
        tooltip: 'send_message'.tr,
        icon: Icon(
          Icons.arrow_upward_rounded,
          color: _hasText ? AppDesign.textDark : palette.textTertiary,
          size: 22,
        ),
        style: IconButton.styleFrom(
          backgroundColor: _hasText
              ? AppDesign.primaryYellow
              : AppDesign.primaryYellow.withValues(alpha: 0.3),
          disabledBackgroundColor: AppDesign.primaryYellow.withValues(alpha: 0.3),
          minimumSize: const Size(44, 44),
          fixedSize: const Size(44, 44),
        ),
      ),
    );
  }
}
