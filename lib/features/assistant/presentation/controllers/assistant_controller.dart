import 'dart:async';

import 'package:get/get.dart';

import 'package:ghar360/core/network/sse_client.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/features/assistant/data/assistant_repository.dart';
import 'package:ghar360/features/assistant/data/models/chat_message_model.dart';
import 'package:ghar360/features/assistant/data/models/conversation_model.dart';

class AssistantController extends GetxController {
  late final AssistantRepository _repository;

  final messages = <ChatMessageModel>[].obs;
  final isStreaming = false.obs;
  final activeToolCall = Rxn<String>();
  final conversationId = Rxn<int>();
  final conversations = <ConversationModel>[].obs;

  // Pagination state for [loadConversations] / [loadMoreConversations].
  // The repository returns a uniform cursor envelope; we mirror its fields
  // here so the UI (or a follow-up) can drive an infinite-scroll list.
  final RxBool isLoadingConversations = false.obs;
  final RxBool isLoadingMoreConversations = false.obs;
  final RxBool conversationsHasMore = true.obs;
  final Rxn<String> conversationsNextCursor = Rxn<String>();

  StreamSubscription<SseEvent>? _streamSubscription;
  int _messageIdCounter = 0;

  @override
  void onInit() {
    super.onInit();
    _repository = Get.find<AssistantRepository>();
  }

  String _nextId() => 'local_${++_messageIdCounter}';

  // ── Sending Messages ───────────────────────────────────────────

  void sendMessage(String text) {
    if (text.trim().isEmpty || isStreaming.value) return;

    // Add user message optimistically
    messages.add(
      ChatMessageModel(
        id: _nextId(),
        role: ChatRole.user,
        content: text.trim(),
        timestamp: DateTime.now(),
      ),
    );

    // Add placeholder for assistant response
    final assistantId = _nextId();
    messages.add(
      ChatMessageModel(
        id: assistantId,
        role: ChatRole.assistant,
        content: '',
        timestamp: DateTime.now(),
        isStreaming: true,
      ),
    );

    isStreaming.value = true;

    _streamSubscription = _repository
        .streamChat(message: text.trim(), conversationId: conversationId.value)
        .listen(
          (event) => _handleSseEvent(event, assistantId),
          onError: (error) {
            DebugLogger.error('SSE stream error', error);
            _finishStreaming(assistantId);
          },
          onDone: () => _finishStreaming(assistantId),
        );
  }

  void _handleSseEvent(SseEvent event, String assistantId) {
    switch (event.event) {
      case 'conversation_info':
        final id = event.data['conversation_id'];
        if (id is int) conversationId.value = id;
        break;

      case 'text_chunk':
        final text = event.data['text'] as String? ?? '';
        _appendToAssistant(assistantId, text);
        break;

      case 'tool_call_start':
        activeToolCall.value = event.data['tool'] as String?;
        break;

      case 'tool_call_end':
        activeToolCall.value = null;
        break;

      case 'widget':
        final widgetName = event.data['widget_name'] as String?;
        final widgetData = event.data['structured_content'] as Map<String, dynamic>?;
        if (widgetName != null && widgetData != null) {
          messages.add(
            ChatMessageModel(
              id: _nextId(),
              role: ChatRole.widget,
              content: '',
              widgetName: widgetName,
              widgetData: widgetData,
              timestamp: DateTime.now(),
            ),
          );
        }
        break;

      case 'done':
        // Use the authoritative response text from the backend
        final responseText = event.data['response_text'] as String?;
        if (responseText != null && responseText.isNotEmpty) {
          final idx = messages.indexWhere((m) => m.id == assistantId);
          if (idx >= 0) {
            messages[idx] = messages[idx].copyWith(content: responseText);
          }
        }
        _finishStreaming(assistantId);
        break;

      case 'error':
        final msg = event.data['message'] as String? ?? 'assistant_error'.tr;
        _appendToAssistant(assistantId, msg);
        _finishStreaming(assistantId);
        break;
    }
  }

  void _appendToAssistant(String assistantId, String text) {
    final idx = messages.indexWhere((m) => m.id == assistantId);
    if (idx < 0) return;
    messages[idx] = messages[idx].copyWith(content: messages[idx].content + text);
  }

  void _finishStreaming(String assistantId) {
    isStreaming.value = false;
    activeToolCall.value = null;
    final idx = messages.indexWhere((m) => m.id == assistantId);
    if (idx >= 0) {
      messages[idx] = messages[idx].copyWith(isStreaming: false);
    }
  }

  void cancelStream() {
    _streamSubscription?.cancel();
    _streamSubscription = null;
    isStreaming.value = false;
    activeToolCall.value = null;
  }

  // ── Conversation History ───────────────────────────────────────

  /// Loads the first page of conversations and resets the pagination cursor.
  ///
  /// Replaces [conversations] in place. After this call, [loadMoreConversations]
  /// can fetch additional pages by passing [conversationsNextCursor] back to
  /// the repository.
  Future<void> loadConversations() async {
    if (isLoadingConversations.value || isLoadingMoreConversations.value) return;

    isLoadingConversations.value = true;
    try {
      final page = await _repository.getConversations();
      conversations.assignAll(page.items);
      conversationsNextCursor.value = page.nextCursor;
      conversationsHasMore.value = page.hasMore;
    } catch (e) {
      DebugLogger.error('Failed to load conversations page', e);
    } finally {
      isLoadingConversations.value = false;
    }
  }

  /// Loads the next page of conversations using [conversationsNextCursor].
  ///
  /// No-op when already loading, when [conversationsHasMore] is false, or
  /// when the cursor is null/empty (backend signalled terminal page).
  /// Appends the freshly fetched items to [conversations] and updates the
  /// cursor so a follow-up call can fetch the page after this one.
  Future<void> loadMoreConversations() async {
    if (isLoadingConversations.value || isLoadingMoreConversations.value) return;
    if (!conversationsHasMore.value) return;

    final cursor = conversationsNextCursor.value;
    if (cursor == null || cursor.isEmpty) {
      conversationsHasMore.value = false;
      return;
    }

    isLoadingMoreConversations.value = true;
    try {
      final page = await _repository.getConversations(cursor: cursor);
      // Dedupe by id so cursor rewinds or backend overlaps never produce
      // duplicate rows in the reactive list.
      final existingIds = conversations.map((c) => c.id).toSet();
      final fresh = page.items.where((c) => !existingIds.contains(c.id)).toList();
      conversations.addAll(fresh);
      conversationsNextCursor.value = page.nextCursor;
      conversationsHasMore.value = page.hasMore;
    } catch (e) {
      DebugLogger.error('Failed to load more conversations', e);
    } finally {
      isLoadingMoreConversations.value = false;
    }
  }

  Future<void> selectConversation(int id) async {
    conversationId.value = id;
    messages.clear();
    final msgs = await _repository.getConversationMessages(id);
    messages.addAll(msgs);
  }

  void startNewConversation() {
    cancelStream();
    conversationId.value = null;
    messages.clear();
  }

  Future<void> deleteConversation(int id) async {
    final success = await _repository.deleteConversation(id);
    if (success) {
      conversations.removeWhere((c) => c.id == id);
      if (conversationId.value == id) {
        startNewConversation();
      }
    }
  }

  @override
  void onClose() {
    _streamSubscription?.cancel();
    super.onClose();
  }
}
