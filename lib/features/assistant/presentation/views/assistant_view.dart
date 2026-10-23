import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/design/paper/paper_scene_data.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/api_date_time.dart';
import 'package:ghar360/core/widgets/common/error_states.dart';
import 'package:ghar360/core/widgets/common/inline_retry_banner.dart';
import 'package:ghar360/core/widgets/common/loading_states.dart';
import 'package:ghar360/core/widgets/common/max_content_width.dart';
import 'package:ghar360/core/widgets/common/symmetric_safe_area.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';
import 'package:ghar360/core/widgets/paper/scene_header_sliver.dart';
import 'package:ghar360/features/assistant/data/models/chat_message_model.dart';
import 'package:ghar360/features/assistant/data/models/conversation_model.dart';
import 'package:ghar360/features/assistant/presentation/controllers/assistant_controller.dart';
import 'package:ghar360/features/assistant/presentation/controllers/assistant_history_controller.dart';
import 'package:ghar360/features/assistant/presentation/widgets/chat_input_bar.dart';
import 'package:ghar360/features/assistant/presentation/widgets/chat_message_bubble.dart';
import 'package:ghar360/features/assistant/presentation/widgets/chat_widget_bubble.dart';
import 'package:ghar360/features/assistant/presentation/widgets/suggested_prompts.dart';
import 'package:ghar360/features/assistant/presentation/widgets/tool_call_indicator.dart';

typedef _Conversation = NotifierProvider<AssistantController, AssistantState>;

/// Load the next page when fewer than this many pixels remain to scroll.
const _pageTrigger = 400.0;

class AssistantView extends ConsumerStatefulWidget {
  const AssistantView({super.key, this.conversationId});
  final int? conversationId;
  @override
  ConsumerState<AssistantView> createState() => _AssistantViewState();
}

class _AssistantViewState extends ConsumerState<AssistantView> with WidgetsBindingObserver {
  int? _conversationId;
  AssistantController? _controller;
  bool _active = true;

  @override
  void initState() {
    super.initState();
    _conversationId = widget.conversationId;
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void didUpdateWidget(covariant AssistantView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationId != widget.conversationId) {
      _leave();
      _conversationId = widget.conversationId;
      _initialize();
    }
  }

  void _initialize() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) {
      unawaited(ref.read(assistantControllerProvider(_conversationId).notifier).initialize());
    }
  });

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = TickerMode.valuesOf(context).enabled;
    if (_active && !active) _leave();
    _active = active;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) _leave();
  }

  void _leave() => _controller?.suspend();

  @override
  void dispose() {
    _leave();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _select(int id) {
    _leave();
    setState(() => _conversationId = id);
    _initialize();
  }

  void _newConversation() {
    _leave();
    setState(() => _conversationId = null);
    unawaited(ref.read(assistantControllerProvider(null).notifier).startNewConversation());
  }

  Future<void> _openHistory(_Conversation provider) async {
    final id = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      constraints: sheetConstraints(context),
      builder: (_) => UncontrolledProviderScope(
        container: ProviderScope.containerOf(context),
        child: SafeArea(
          top: false,
          bottom: false,
          child: _HistorySheet(
            onDeleted: (id) {
              if (ref.read(provider).conversationId == id && mounted) _newConversation();
            },
          ),
        ),
      ),
    );
    if (id != null && mounted) _select(id);
  }

  @override
  Widget build(BuildContext context) {
    final provider = assistantControllerProvider(_conversationId);
    _controller = ref.read(provider.notifier);
    ref.listen(provider.select((state) => state.loadStatus), (previous, next) {
      if (next == ConversationLoadStatus.initial) _initialize();
    });
    final l10n = context.l10n;
    return Scaffold(
      key: const ValueKey('qa.assistant.screen'),
      backgroundColor: context.design.background,
      body: _KiteSkyPage(
        header: SceneHeaderSliver(
          title: l10n.text('assistant'),
          qaId: 'qa.assistant.title',
          scene: _scene,
          actions: [
            IconButton(
              key: const ValueKey('qa.assistant.history'),
              icon: const PaperIcon(KnifeIcon.clock),
              tooltip: l10n.text('assistant_history'),
              onPressed: () => _openHistory(provider),
            ),
            IconButton(
              key: const ValueKey('qa.assistant.new_chat'),
              icon: const PaperIcon(KnifeIcon.chat, size: 22),
              onPressed: _newConversation,
              tooltip: l10n.text('assistant_new_chat'),
            ),
          ],
        ),
        child: MaxContentWidth(
          maxWidth: 720,
          child: LayoutBuilder(
            builder: (context, constraints) => Column(
              children: [
                // Keyed: each conversation opens at its newest message.
                Expanded(
                  child: _MessagePane(key: ValueKey(_conversationId), provider: provider),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: constraints.maxHeight * 0.35),
                  child: _RecoveryStack(provider: provider),
                ),
                _Composer(key: ValueKey(_conversationId), provider: provider),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The kite over the towers, in a short band: the chat needs the room.
final _scene = PaperSceneSpec(
  art: paperHeaders['assistant']!,
  ground: 214,
  focusX: 0.64,
  band: 104,
);

/// The kite scene pinned at the top and the chat on the white sheet under
/// its lip. While the keyboard is up, or on a short window, the scene folds
/// into the compact bar so the conversation keeps its room; it opens again
/// when there is room.
class _KiteSkyPage extends StatefulWidget {
  const _KiteSkyPage({required this.header, required this.child});
  final SceneHeaderSliver header;
  final Widget child;
  @override
  State<_KiteSkyPage> createState() => _KiteSkyPageState();
}

/// Below this height the open scene would take the chat's room.
const _shortWindow = 640.0;

class _KiteSkyPageState extends State<_KiteSkyPage> {
  ScrollController? _scroll;
  ({bool folded, double band})? _shown;

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  void _settle() {
    final (shown, scroll) = (_shown, _scroll);
    if (!mounted || shown == null || scroll == null || !scroll.hasClients) return;
    final target = shown.folded ? shown.band : 0.0;
    if (scroll.offset == target) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      scroll.jumpTo(target);
    } else {
      unawaited(
        scroll.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final header = widget.header;
        final band = SceneHeaderSliver.extentsFor(
          context,
          width: constraints.maxWidth,
          scene: header.scene,
          title: header.title,
        ).band;
        final shown = (folded: keyboard || constraints.maxHeight < _shortWindow, band: band);
        // The first frame already sits folded or open; later changes move.
        final scroll = _scroll ??= ScrollController(
          initialScrollOffset: shown.folded ? shown.band : 0,
        );
        if (shown != _shown) {
          final first = _shown == null;
          _shown = shown;
          if (!first) WidgetsBinding.instance.addPostFrameCallback((_) => _settle());
        }
        // The chat scrolls inside; this view only folds the header.
        return CustomScrollView(
          controller: scroll,
          physics: const NeverScrollableScrollPhysics(),
          slivers: [
            header,
            SliverFillRemaining(
              child: ColoredBox(color: context.design.surface, child: widget.child),
            ),
          ],
        );
      },
    );
  }
}

/// The conversation, newest at the bottom. Older pages load near the top.
class _MessagePane extends ConsumerStatefulWidget {
  const _MessagePane({super.key, required this.provider});
  final _Conversation provider;
  @override
  ConsumerState<_MessagePane> createState() => _MessagePaneState();
}

class _MessagePaneState extends ConsumerState<_MessagePane> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadOlder);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// The list is reversed, so the extent after the viewport is the older side.
  /// A short conversation that does not fill the screen also loads its past.
  void _maybeLoadOlder() {
    if (!mounted || !_scroll.hasClients) return;
    final state = ref.read(widget.provider);
    if (!state.hasOlder ||
        state.olderStatus != OlderMessagesStatus.idle ||
        state.loadStatus != ConversationLoadStatus.ready ||
        _scroll.position.extentAfter > _pageTrigger) {
      return;
    }
    unawaited(ref.read(widget.provider.notifier).loadOlderMessages());
  }

  @override
  Widget build(BuildContext context) {
    final (messages, loadStatus, loadError) = ref.watch(
      widget.provider.select((state) => (state.messages, state.loadStatus, state.loadError)),
    );
    final (olderStatus, hasOlder, olderError) = ref.watch(
      widget.provider.select((state) => (state.olderStatus, state.hasOlder, state.olderError)),
    );
    final controller = ref.read(widget.provider.notifier);
    final l10n = context.l10n;

    if (messages.isEmpty) {
      if (loadStatus == ConversationLoadStatus.loading ||
          loadStatus == ConversationLoadStatus.initial) {
        return const _ConversationSkeleton();
      }
      if (loadStatus == ConversationLoadStatus.failed) {
        return KeyedSubtree(
          key: const ValueKey('failed_to_load_messages'),
          child: ErrorStates.genericError(
            error: loadError,
            onRetry: controller.loadMessages,
            customMessage: l10n.text('failed_to_load_messages'),
            seed: 'assistant',
          ),
        );
      }
      // A new chat starts where the conversation will grow: at the composer.
      return ListView(
        reverse: true,
        padding: const EdgeInsets.only(top: 12, bottom: 12),
        children: [SuggestedPrompts(onPromptTap: controller.sendMessage)],
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoadOlder());
    final Widget? top = switch ((loadStatus, olderStatus)) {
      (ConversationLoadStatus.loading, _) ||
      (_, OlderMessagesStatus.loading) => const _OlderSkeleton(),
      (_, OlderMessagesStatus.failed) => InlineRetryBanner(
        key: const ValueKey('assistant_older_failed'),
        message: l10n.text('assistant_older_failed'),
        onRetry: controller.loadOlderMessages,
        error: olderError,
        identifier: 'qa.assistant.older_retry',
      ),
      _ when hasOlder => Center(
        child: TextButton(
          key: const ValueKey('qa.assistant.load_earlier'),
          onPressed: controller.loadOlderMessages,
          child: Text(l10n.text('assistant_load_earlier'), textAlign: TextAlign.center),
        ),
      ),
      _ => null,
    };
    return ListView.builder(
      key: const ValueKey('qa.assistant.message_list'),
      controller: _scroll,
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      reverse: true,
      itemCount: messages.length + (top == null ? 0 : 1),
      itemBuilder: (context, index) {
        if (index == messages.length) return top;
        final message = messages[messages.length - 1 - index];
        switch (message.role) {
          case ChatRole.user:
          case ChatRole.assistant:
            if (message.content.trim().isEmpty && !message.isStreaming) {
              return const SizedBox.shrink();
            }
            return ChatMessageBubble(key: ValueKey(message.id), message: message);
          case ChatRole.widget:
            return ChatWidgetBubble(
              key: ValueKey(message.id),
              message: message,
              onAction: controller.sendMessage,
            );
          case ChatRole.error:
            return Padding(
              key: const ValueKey('assistant_stream_failed'),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: ErrorStates.inlineError(message: l10n.text('assistant_stream_failed')),
            );
          case ChatRole.toolCall:
          case ChatRole.toolResult:
            return const SizedBox.shrink();
        }
      },
    );
  }
}

/// Failures that keep the conversation on screen, plus the running tool.
class _RecoveryStack extends ConsumerWidget {
  const _RecoveryStack({required this.provider});
  final _Conversation provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(
      provider.select(
        (state) => (
          storageError: state.storageError,
          draftStatus: state.draftStatus,
          loadFailed:
              state.loadStatus == ConversationLoadStatus.failed && state.messages.isNotEmpty,
          loadError: state.loadError,
          stream: state.streamStatus,
          streamError: state.streamError,
          tool: state.activeToolCall,
          failedTool: state.failedTool,
          usedTool: state.turnUsedTool,
        ),
      ),
    );
    final controller = ref.read(provider.notifier);
    final l10n = context.l10n;
    final draftKey = s.draftStatus == AssistantDraftStatus.readFailed
        ? 'assistant_draft_load_failed'
        : 'assistant_draft_save_failed';
    final streamKey = isConversationMissing(s.streamError)
        ? 'assistant_conversation_missing'
        : s.stream == AssistantStreamStatus.failed
        ? 'assistant_stream_failed'
        : 'assistant_stream_interrupted';
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (s.storageError != null)
            InlineRetryBanner(
              key: ValueKey(draftKey),
              message: l10n.text(draftKey),
              onRetry: controller.retryDraft,
              error: s.storageError,
              identifier: 'qa.assistant.draft_retry',
            ),
          if (s.loadFailed)
            InlineRetryBanner(
              key: const ValueKey('failed_to_load_messages'),
              message: l10n.text('failed_to_load_messages'),
              onRetry: controller.loadMessages,
              error: s.loadError,
              identifier: 'qa.assistant.messages_retry',
            ),
          // The partial reply stays in the list above; retry sends the kept prompt.
          if ((s.stream == AssistantStreamStatus.failed ||
                  s.stream == AssistantStreamStatus.interrupted) &&
              s.usedTool)
            Padding(
              key: const ValueKey('assistant_stream_failed_after_tool'),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ErrorStates.inlineError(
                message: l10n.text('assistant_stream_failed_after_tool'),
              ),
            )
          else if (s.stream == AssistantStreamStatus.failed ||
              s.stream == AssistantStreamStatus.interrupted)
            InlineRetryBanner(
              key: ValueKey(streamKey),
              message: l10n.text(streamKey),
              onRetry: controller.retryLastPrompt,
              error: s.streamError,
              identifier: 'qa.assistant.stream_retry',
            ),
          if (s.failedTool != null)
            Padding(
              key: const ValueKey('assistant_tool_failed'),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ErrorStates.inlineError(message: l10n.text('assistant_tool_failed')),
            ),
          if (s.tool != null) ToolCallIndicator(toolName: s.tool!),
        ],
      ),
    );
  }
}

class _Composer extends ConsumerWidget {
  const _Composer({super.key, required this.provider});
  final _Conversation provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (draft, streaming, enabled) = ref.watch(
      provider.select(
        (state) => (
          state.draft,
          state.isStreaming,
          state.loadStatus == ConversationLoadStatus.ready &&
              state.draftStatus != AssistantDraftStatus.readFailed,
        ),
      ),
    );
    final controller = ref.read(provider.notifier);
    return ChatInputBar(
      onSend: controller.sendMessage,
      isStreaming: streaming,
      onCancel: controller.cancelStream,
      draft: draft,
      onDraftChanged: controller.updateDraft,
      enabled: enabled,
    );
  }
}

/// Two turns in the shape of the conversation that is loading.
class _ConversationSkeleton extends StatelessWidget {
  const _ConversationSkeleton();
  @override
  Widget build(BuildContext context) => Skeleton(
    child: ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        for (var index = 0; index < 4; index++)
          Align(
            alignment: index.isEven ? Alignment.centerRight : Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: SkeletonBox(width: index.isEven ? 180 : 250, height: index.isEven ? 44 : 64),
            ),
          ),
      ],
    ),
  );
}

/// The page before the first shown message, while it loads.
class _OlderSkeleton extends StatelessWidget {
  const _OlderSkeleton();
  @override
  Widget build(BuildContext context) => const Skeleton(
    child: Padding(
      padding: EdgeInsets.fromLTRB(16, 4, 48, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(height: 14, width: 240),
          SizedBox(height: 8),
          SkeletonBox(height: 14, width: 160),
        ],
      ),
    ),
  );
}

class _HistorySheet extends ConsumerStatefulWidget {
  const _HistorySheet({required this.onDeleted});
  final ValueChanged<int> onDeleted;
  @override
  ConsumerState<_HistorySheet> createState() => _HistorySheetState();
}

class _HistorySheetState extends ConsumerState<_HistorySheet> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
    Future.microtask(() {
      if (mounted) unawaited(ref.read(assistantHistoryProvider.notifier).loadConversations());
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (!mounted || !_scroll.hasClients) return;
    final state = ref.read(assistantHistoryProvider);
    if (!state.hasMore ||
        state.status != HistoryLoadStatus.ready ||
        _scroll.position.extentAfter > _pageTrigger) {
      return;
    }
    unawaited(ref.read(assistantHistoryProvider.notifier).loadMoreConversations());
  }

  Future<void> _delete(ConversationModel conversation) async {
    final controller = ref.read(assistantHistoryProvider.notifier);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.text('assistant_delete_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.text('cancel')),
          ),
          TextButton(
            key: const ValueKey('qa.assistant.delete_confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: context.design.error),
            child: Text(context.l10n.text('delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (await controller.deleteConversation(conversation.id) && mounted) {
      widget.onDeleted(conversation.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(assistantHistoryProvider);
    final controller = ref.read(assistantHistoryProvider.notifier);
    final l10n = context.l10n;
    ref.listen(assistantHistoryProvider.select((state) => state.status), (previous, next) {
      if (next == HistoryLoadStatus.initial) {
        Future.microtask(() {
          if (mounted) unawaited(controller.loadConversations());
        });
      }
    });
    final deleteKey = state.cleanupId == null
        ? 'failed_to_delete_conversation'
        : 'assistant_draft_remove_failed';
    return FractionallySizedBox(
      heightFactor: 0.8,
      // The sheet has a hand-cut edge (amp 3); every side clears it.
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        l10n.text('assistant_history'),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('qa.assistant.history.refresh'),
                    onPressed: state.isLoading ? null : controller.loadConversations,
                    tooltip: l10n.text('refresh'),
                    icon: state.status == HistoryLoadStatus.refreshing
                        ? LoadingStates.buttonSpinner(size: 20)
                        : const PaperIcon(KnifeIcon.retry),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: l10n.text('close'),
                    icon: const PaperIcon(KnifeIcon.close),
                  ),
                ],
              ),
            ),
            if (state.deleteError != null)
              Padding(
                key: ValueKey(deleteKey),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ErrorStates.inlineError(
                  message: l10n.text(deleteKey),
                  onRetry: state.cleanupId == null ? null : controller.retryDraftCleanup,
                ),
              ),
            if (state.status == HistoryLoadStatus.refreshFailed)
              InlineRetryBanner(
                key: const ValueKey('assistant_history_failed'),
                message: l10n.text('assistant_history_failed'),
                onRetry: controller.loadConversations,
                error: state.error,
                identifier: 'qa.assistant.history.retry',
              ),
            Expanded(child: _body(context, state, controller)),
          ],
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    AssistantHistoryState state,
    AssistantHistoryController controller,
  ) {
    final l10n = context.l10n;
    if (state.conversations.isEmpty) {
      return switch (state.status) {
        HistoryLoadStatus.initial ||
        HistoryLoadStatus.loading ||
        HistoryLoadStatus.refreshing => LoadingStates.conversationListSkeleton(),
        HistoryLoadStatus.failed => KeyedSubtree(
          key: const ValueKey('assistant_history_failed'),
          child: ErrorStates.genericError(
            error: state.error,
            onRetry: controller.loadConversations,
            customMessage: l10n.text('assistant_history_failed'),
            seed: 'assistant',
          ),
        ),
        _ => ErrorStates.emptyState(
          title: l10n.text('assistant_no_conversations'),
          message: l10n.text('assistant_history_empty_message'),
          onAction: () => Navigator.of(context).pop(),
          actionText: l10n.text('assistant_new_chat'),
          seed: 'assistant',
        ),
      };
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoadMore());
    final Widget? footer = switch (state.status) {
      HistoryLoadStatus.loadingMore => const _HistoryRowSkeleton(),
      HistoryLoadStatus.pageFailed => InlineRetryBanner(
        key: const ValueKey('assistant_history_page_failed'),
        message: l10n.text('assistant_history_failed'),
        onRetry: controller.loadMoreConversations,
        error: state.error,
        identifier: 'qa.assistant.history.page_retry',
      ),
      _ when state.hasMore => Center(
        child: TextButton(
          key: const ValueKey('qa.assistant.history.load_more'),
          onPressed: state.isLoading ? null : controller.loadMoreConversations,
          child: Text(l10n.text('load_more')),
        ),
      ),
      _ => null,
    };
    final busy = state.deletingId != null || state.cleanupId != null;
    return ListView.builder(
      key: const ValueKey('qa.assistant.history.list'),
      controller: _scroll,
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      itemCount: state.conversations.length + (footer == null ? 0 : 1),
      itemBuilder: (context, index) {
        if (index == state.conversations.length) return footer;
        final conversation = state.conversations[index];
        return _ConversationRow(
          key: ValueKey('qa.assistant.conversation.${conversation.id}'),
          conversation: conversation,
          deleting: state.deletingId == conversation.id,
          onOpen: () => Navigator.of(context).pop(conversation.id),
          onDelete: busy ? null : () => _delete(conversation),
        );
      },
    );
  }
}

/// A title, then the date and size in quiet type. No card, no divider.
class _ConversationRow extends StatelessWidget {
  const _ConversationRow({
    super.key,
    required this.conversation,
    required this.deleting,
    required this.onOpen,
    required this.onDelete,
  });

  final ConversationModel conversation;
  final bool deleting;
  final VoidCallback onOpen;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final date = conversation.updatedAt;
    final count = conversation.messageCount;
    final meta = [
      formatDisplayDate(date.toLocal()),
      if (count > 0)
        count == 1
            ? l10n.text('assistant_messages_one')
            : l10n.text('assistant_messages_count', params: {'count': '$count'}),
    ].join(' · ');
    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 0, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conversation.title ?? l10n.text('assistant_new_chat'),
                    style: text.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      meta,
                      style: text.bodySmall?.copyWith(color: context.design.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: l10n.text('delete'),
              onPressed: onDelete,
              icon: deleting
                  ? LoadingStates.buttonSpinner(size: 20)
                  : PaperIcon(KnifeIcon.trash, color: context.design.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryRowSkeleton extends StatelessWidget {
  const _HistoryRowSkeleton();
  @override
  Widget build(BuildContext context) => const Skeleton(
    child: Padding(
      padding: EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(height: 16, width: 200),
          SizedBox(height: 6),
          SkeletonBox(height: 12, width: 90),
        ],
      ),
    ),
  );
}
