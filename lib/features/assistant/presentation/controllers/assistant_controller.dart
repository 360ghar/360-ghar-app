import 'dart:async';
import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/bootstrap/provider_policy.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/features/assistant/data/assistant_repository.dart';
import 'package:ghar360/features/assistant/data/models/assistant_frame.dart';
import 'package:ghar360/features/assistant/data/models/chat_message_model.dart';

final assistantRepositoryProvider = Provider.autoDispose<AssistantRepository>((ref) {
  ref.watch(storageScopeProvider);
  final repository = AssistantRepository(
    apiClient: ref.watch(apiClientProvider),
    sseClient: ref.watch(sseClientProvider),
  );
  ref.onDispose(repository.clearWidgetCache);
  return repository;
}, retry: noProviderRetry);

final assistantControllerProvider = NotifierProvider.autoDispose
    .family<AssistantController, AssistantState, int?>(
      AssistantController.new,
      retry: noProviderRetry,
    );

enum ConversationLoadStatus { initial, loading, ready, failed }

/// True when the backend says the conversation does not exist for this user (404).
bool isConversationMissing(Object? error) =>
    error is NotFoundException || (error is ApiException && error.statusCode == 404);

enum AssistantStreamStatus { idle, streaming, interrupted, failed }

enum AssistantDraftStatus { ready, readFailed, writeFailed }

/// Loading of the pages before the newest one. It never blocks the composer.
enum OlderMessagesStatus { idle, loading, failed }

const _unchanged = Object();

class AssistantState {
  AssistantState({
    List<ChatMessageModel> messages = const [],
    this.conversationId,
    this.loadStatus = ConversationLoadStatus.initial,
    this.streamStatus = AssistantStreamStatus.idle,
    Map<String, String> activeToolCalls = const {},
    this.failedTool,
    this.draft = '',
    this.draftStatus = AssistantDraftStatus.ready,
    this.loadError,
    this.streamError,
    this.storageError,
    this.olderCursor,
    this.olderStatus = OlderMessagesStatus.idle,
    this.olderError,
    this.turnUsedTool = false,
  }) : messages = messages is UnmodifiableListView<ChatMessageModel>
           ? messages
           : UnmodifiableListView(List.of(messages)),
       activeToolCalls = Map.unmodifiable(activeToolCalls);

  final List<ChatMessageModel> messages;
  final int? conversationId;
  final ConversationLoadStatus loadStatus;
  final AssistantStreamStatus streamStatus;

  /// The tools that run now, by `call_id`, in start order. Two calls of one step run together,
  /// so an end frame clears only its own entry.
  final Map<String, String> activeToolCalls;

  /// The tool whose call ended with `success: false` during this reply, or null.
  final String? failedTool;
  final String draft;
  final AssistantDraftStatus draftStatus;
  final Object? loadError;
  final Object? streamError;
  final Object? storageError;

  /// Points to the page of messages before the first one shown; null at the start.
  final String? olderCursor;
  final OlderMessagesStatus olderStatus;
  final Object? olderError;

  /// A tool ran during the current or last reply, so a resend could repeat its action.
  final bool turnUsedTool;
  bool get isStreaming => streamStatus == AssistantStreamStatus.streaming;

  /// The tool shown in the indicator: the one that started last and has not ended.
  String? get activeToolCall => activeToolCalls.isEmpty ? null : activeToolCalls.values.last;
  bool get hasOlder => olderCursor != null;

  AssistantState copyWith({
    List<ChatMessageModel>? messages,
    Object? conversationId = _unchanged,
    ConversationLoadStatus? loadStatus,
    AssistantStreamStatus? streamStatus,
    Map<String, String>? activeToolCalls,
    Object? failedTool = _unchanged,
    String? draft,
    AssistantDraftStatus? draftStatus,
    Object? loadError = _unchanged,
    Object? streamError = _unchanged,
    Object? storageError = _unchanged,
    Object? olderCursor = _unchanged,
    OlderMessagesStatus? olderStatus,
    Object? olderError = _unchanged,
    bool? turnUsedTool,
  }) => AssistantState(
    messages: messages ?? this.messages,
    conversationId: identical(conversationId, _unchanged)
        ? this.conversationId
        : conversationId as int?,
    loadStatus: loadStatus ?? this.loadStatus,
    streamStatus: streamStatus ?? this.streamStatus,
    activeToolCalls: activeToolCalls ?? this.activeToolCalls,
    failedTool: identical(failedTool, _unchanged) ? this.failedTool : failedTool as String?,
    draft: draft ?? this.draft,
    draftStatus: draftStatus ?? this.draftStatus,
    loadError: identical(loadError, _unchanged) ? this.loadError : loadError,
    streamError: identical(streamError, _unchanged) ? this.streamError : streamError,
    storageError: identical(storageError, _unchanged) ? this.storageError : storageError,
    olderCursor: identical(olderCursor, _unchanged) ? this.olderCursor : olderCursor as String?,
    olderStatus: olderStatus ?? this.olderStatus,
    olderError: identical(olderError, _unchanged) ? this.olderError : olderError,
    turnUsedTool: turnUsedTool ?? this.turnUsedTool,
  );
}

/// Owns one conversation. Widgets own text, focus and scroll controllers.
/// SQLite stores unsent text and the last interrupted turn, never credentials.
class AssistantController extends Notifier<AssistantState> {
  AssistantController(this.initialConversationId);
  final int? initialConversationId;
  late AssistantRepository _repository;
  late AppDatabase _database;
  late StorageScope _scope;
  StreamSubscription<AssistantFrame>? _subscription;
  Timer? _saveTimer;
  Future<void> _writes = Future.value();
  int _generation = 0;

  /// Changes when the shown history is replaced, so a late older page is dropped.
  /// Separate from [_generation]: a send must not cancel an older-page load.
  int _historyEpoch = 0;
  int _writeVersion = 0;
  int _messageCounter = 0;
  String? _assistantId;
  String? _pendingPrompt;
  bool _initialized = false;
  String get _draftKey => 'assistant:${initialConversationId ?? 'new'}';

  @override
  AssistantState build() {
    _repository = ref.watch(assistantRepositoryProvider);
    _database = ref.watch(appDatabaseProvider);
    _scope = ref.watch(storageScopeProvider);
    ++_generation;
    ++_historyEpoch;
    _initialized = false;
    _pendingPrompt = null;
    _assistantId = null;
    ref.onDispose(() {
      ++_generation;
      _saveTimer?.cancel();
      unawaited(_subscription?.cancel());
    });
    return AssistantState(conversationId: initialConversationId);
  }

  bool _current(int generation) => ref.mounted && generation == _generation;
  String _nextId() => 'local_${DateTime.now().microsecondsSinceEpoch}_${++_messageCounter}';

  Future<void> initialize() async {
    if (_initialized || state.loadStatus != ConversationLoadStatus.initial) return;
    _initialized = true;
    final generation = _generation;
    state = state.copyWith(loadStatus: ConversationLoadStatus.loading);
    try {
      final saved = await _database.readDraft(scope: _scope, key: _draftKey);
      if (!_current(generation)) return;
      final draft = saved?['text'];
      final pending = saved?['pending_prompt'];
      final partial = saved?['partial_reply'];
      final savedId = saved?['conversation_id'];
      if (pending is String && pending.isNotEmpty) _pendingPrompt = pending;
      state = state.copyWith(
        draft: draft is String ? draft : '',
        draftStatus: AssistantDraftStatus.ready,
        storageError: null,
        conversationId: initialConversationId ?? (savedId is int ? savedId : null),
        turnUsedTool: _pendingPrompt != null && saved?['used_tool'] == true,
        streamStatus: _pendingPrompt == null
            ? AssistantStreamStatus.idle
            : AssistantStreamStatus.interrupted,
        messages: _pendingPrompt == null
            ? const []
            : [
                ChatMessageModel(
                  id: _nextId(),
                  role: ChatRole.user,
                  content: pending as String,
                  timestamp: DateTime.now(),
                ),
                if (partial is String && partial.isNotEmpty)
                  ChatMessageModel(
                    id: _nextId(),
                    role: ChatRole.assistant,
                    content: partial,
                    timestamp: DateTime.now(),
                  ),
              ],
      );
    } catch (error, stack) {
      if (!_current(generation)) return;
      DebugLogger.warning('Assistant draft read failed.', error.runtimeType, stack);
      state = state.copyWith(storageError: error, draftStatus: AssistantDraftStatus.readFailed);
    }
    if (!_current(generation)) return;
    if (state.conversationId != null) {
      await loadMessages();
    } else {
      state = state.copyWith(loadStatus: ConversationLoadStatus.ready);
    }
  }

  Future<void> loadMessages() async {
    final id = state.conversationId;
    if (id == null || state.isStreaming) return;
    final generation = ++_generation;
    ++_historyEpoch;
    state = state.copyWith(
      loadStatus: ConversationLoadStatus.loading,
      loadError: null,
      olderStatus: OlderMessagesStatus.idle,
      olderError: null,
    );
    try {
      final page = await _repository.getMessagesPage(id);
      if (!_current(generation)) return;
      final messages = page.items;
      // The local interrupted reply stays visible when the server has not saved it.
      final local = _pendingPrompt == null ? const <ChatMessageModel>[] : state.messages;
      final missing = local.where(
        (localMessage) => !messages.any(
          (serverMessage) =>
              serverMessage.role == localMessage.role &&
              serverMessage.content == localMessage.content,
        ),
      );
      state = state.copyWith(
        messages: [...messages, ...missing],
        loadStatus: ConversationLoadStatus.ready,
        olderCursor: page.hasMore ? page.nextCursor : null,
      );
    } catch (error, stack) {
      if (!_current(generation)) return;
      DebugLogger.warning('Assistant messages failed.', error.runtimeType, stack);
      state = state.copyWith(loadStatus: ConversationLoadStatus.failed, loadError: error);
    }
  }

  /// Prepends the page before the first message shown. The list is reversed, so
  /// rows added at the top do not move the rows the reader is looking at.
  Future<void> loadOlderMessages() async {
    final id = state.conversationId;
    final cursor = state.olderCursor;
    if (id == null || cursor == null || state.olderStatus == OlderMessagesStatus.loading) return;
    final older = state.olderError;
    if (older is ApiException && older.code == 'INVALID_CURSOR') return loadMessages();
    final epoch = _historyEpoch;
    bool current() => ref.mounted && epoch == _historyEpoch;
    state = state.copyWith(olderStatus: OlderMessagesStatus.loading, olderError: null);
    try {
      final page = await _repository.getMessagesPage(id, cursor: cursor);
      if (!current()) return;
      final shown = {for (final message in state.messages) message.id};
      state = state.copyWith(
        messages: [
          ...page.items.where((message) => !shown.contains(message.id)),
          ...state.messages,
        ],
        // A repeated cursor would loop forever; treat it as the start.
        olderCursor: page.hasMore && page.nextCursor != cursor ? page.nextCursor : null,
        olderStatus: OlderMessagesStatus.idle,
      );
    } catch (error, stack) {
      if (!current()) return;
      DebugLogger.warning('Assistant older messages failed.', error.runtimeType, stack);
      state = state.copyWith(olderStatus: OlderMessagesStatus.failed, olderError: error);
    }
  }

  void updateDraft(String text) {
    if (state.draftStatus == AssistantDraftStatus.readFailed) return;
    if (text == state.draft) return;
    state = state.copyWith(draft: text);
    _scheduleSave();
  }

  Map<String, Object?> _snapshot() {
    final partial = state.messages
        .where((message) => message.role == ChatRole.assistant)
        .lastOrNull;
    return {
      'text': state.isStreaming ? _pendingPrompt ?? state.draft : state.draft,
      'pending_prompt': _pendingPrompt,
      'partial_reply': _pendingPrompt == null ? null : partial?.content,
      'used_tool': _pendingPrompt != null && state.turnUsedTool,
      'conversation_id': state.conversationId,
    };
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 250), () => unawaited(saveDraft()));
  }

  /// Called before leaving the view as well as on edits and stream completion.
  /// The captured database lease prevents a delayed write crossing accounts.
  Future<void> saveDraft() {
    if (!ref.mounted || state.draftStatus == AssistantDraftStatus.readFailed) return Future.value();
    _saveTimer?.cancel();
    final payload = _snapshot();
    final database = _database;
    final scope = _scope;
    final key = _draftKey;
    final generation = _generation;
    final version = ++_writeVersion;
    final write = _writes.then((_) => database.writeDraft(scope: scope, key: key, value: payload));
    _writes = write.then<void>(
      (_) {
        if (_current(generation) && version == _writeVersion) {
          state = state.copyWith(storageError: null, draftStatus: AssistantDraftStatus.ready);
        }
      },
      onError: (Object error, StackTrace stack) {
        DebugLogger.warning('Assistant draft save failed.', error.runtimeType, stack);
        if (_current(generation) && version == _writeVersion) {
          state = state.copyWith(
            storageError: error,
            draftStatus: AssistantDraftStatus.writeFailed,
          );
        }
      },
    );
    return _writes;
  }

  Future<void> retryDraft() async {
    if (state.draftStatus == AssistantDraftStatus.readFailed) {
      _initialized = false;
      state = state.copyWith(loadStatus: ConversationLoadStatus.initial);
      await initialize();
    } else {
      await saveDraft();
    }
  }

  void sendMessage(String text) {
    final prompt = text.trim();
    // The backend refuses a longer message with a 422 before the stream starts.
    if (prompt.isEmpty ||
        prompt.length > AssistantRepository.maxMessageLength ||
        state.isStreaming ||
        state.draftStatus == AssistantDraftStatus.readFailed ||
        state.loadStatus == ConversationLoadStatus.loading ||
        state.loadStatus == ConversationLoadStatus.failed) {
      return;
    }
    _initialized = true;
    final generation = ++_generation;
    _pendingPrompt = prompt;
    final assistantId = _nextId();
    _assistantId = assistantId;
    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatMessageModel(
          id: _nextId(),
          role: ChatRole.user,
          content: prompt,
          timestamp: DateTime.now(),
        ),
        ChatMessageModel(
          id: assistantId,
          role: ChatRole.assistant,
          content: '',
          timestamp: DateTime.now(),
          isStreaming: true,
        ),
      ],
      loadStatus: ConversationLoadStatus.ready,
      streamStatus: AssistantStreamStatus.streaming,
      streamError: null,
      activeToolCalls: const {},
      failedTool: null,
      turnUsedTool: false,
      draft: '',
    );
    unawaited(saveDraft());
    unawaited(_subscription?.cancel());
    try {
      _subscription = _repository
          .streamChat(message: prompt, conversationId: state.conversationId)
          .listen(
            (frame) {
              if (_current(generation) && _assistantId == assistantId) _handleFrame(frame);
            },
            onError: (Object error, StackTrace stack) {
              if (!_current(generation) || _assistantId != assistantId) return;
              DebugLogger.warning('Assistant stream failed.', error.runtimeType, stack);
              _finish(AssistantStreamStatus.failed, error: error);
            },
            onDone: () {
              // EOF without the protocol's done event is an interrupted response.
              if (_current(generation) && _assistantId == assistantId) {
                _finish(AssistantStreamStatus.interrupted);
              }
            },
            cancelOnError: true,
          );
    } catch (error, stack) {
      DebugLogger.warning('Assistant stream failed to start.', error.runtimeType, stack);
      _finish(AssistantStreamStatus.failed, error: error);
    }
  }

  void _handleFrame(AssistantFrame frame) {
    switch (frame) {
      case ConversationInfoFrame(:final conversationId):
        if (conversationId > 0) state = state.copyWith(conversationId: conversationId);
      case TextChunkFrame(:final text):
        _replaceAssistant((message) => message.content + text);
      case ToolCallStartFrame(:final callId, :final tool):
        state = state.copyWith(
          activeToolCalls: {...state.activeToolCalls, callId: tool},
          turnUsedTool: true,
        );
      case ToolCallEndFrame(:final callId, :final tool, :final success):
        // Only this call leaves the indicator. A failed call is remembered for the reply.
        state = state.copyWith(
          activeToolCalls: {
            for (final entry in state.activeToolCalls.entries)
              if (entry.key != callId) entry.key: entry.value,
          },
          failedTool: success ? _unchanged : tool,
        );
      case WidgetFrame(:final widgetName, :final structuredContent):
        // A result with `error` set is not a widget: the reply text says what went wrong.
        if (AssistantRepository.isValidWidgetName(widgetName) &&
            structuredContent != null &&
            structuredContent['error'] != true) {
          state = state.copyWith(
            messages: [
              ...state.messages,
              ChatMessageModel(
                id: _nextId(),
                role: ChatRole.widget,
                content: '',
                widgetName: widgetName,
                widgetData: Map.unmodifiable(structuredContent),
                timestamp: DateTime.now(),
              ),
            ],
          );
        }
      case DoneFrame(:final responseText):
        if (responseText.isNotEmpty) _replaceAssistant((_) => responseText);
        _finish(AssistantStreamStatus.idle);
      case ErrorFrame(:final code):
        // The frame text is fixed server text. Presentation shows localized text instead.
        _finish(
          AssistantStreamStatus.failed,
          error: ServerException(
            'The assistant could not finish this reply.',
            code: code?.wire ?? AssistantErrorCode.agentError.wire,
          ),
        );
    }
    if (state.isStreaming) _scheduleSave();
  }

  void _replaceAssistant(String Function(ChatMessageModel) content) {
    state = state.copyWith(
      messages: [
        for (final message in state.messages)
          if (message.id == _assistantId) message.copyWith(content: content(message)) else message,
      ],
    );
  }

  void _finish(AssistantStreamStatus status, {Object? error}) {
    final assistantId = _assistantId;
    _assistantId = null;
    unawaited(_subscription?.cancel());
    _subscription = null;
    if (status == AssistantStreamStatus.idle) _pendingPrompt = null;
    state = state.copyWith(
      messages: [
        for (final message in state.messages)
          if (message.id == assistantId) message.copyWith(isStreaming: false) else message,
      ],
      streamStatus: status,
      streamError: error,
      // An unknown or foreign conversation answers 404. The next message starts a new one on
      // purpose, instead of the server quietly doing it.
      conversationId: isConversationMissing(error) ? null : state.conversationId,
      activeToolCalls: const {},
      draft: status == AssistantStreamStatus.idle ? state.draft : _pendingPrompt ?? state.draft,
    );
    unawaited(saveDraft());
  }

  /// Stop resources immediately when a route becomes inactive. Publish the
  /// settled state after the widget lifecycle callback has completed.
  void suspend() {
    if (!ref.mounted) return;
    final generation = _generation;
    unawaited(_subscription?.cancel());
    _subscription = null;
    unawaited(saveDraft());
    Future.microtask(() {
      if (_current(generation) && state.isStreaming) _finish(AssistantStreamStatus.interrupted);
    });
  }

  /// Sends the kept prompt again after a failed or interrupted reply. The
  /// composer text wins when the reader edited it.
  /// Never resends after a tool ran: it may already have acted (a booking, for
  /// example). The prompt stays in the composer for the reader to check.
  void retryLastPrompt() {
    if (state.turnUsedTool) return;
    final draft = state.draft.trim();
    sendMessage(draft.isNotEmpty ? draft : _pendingPrompt ?? '');
  }

  void cancelStream() {
    if (!ref.mounted) return;
    if (state.isStreaming) _finish(AssistantStreamStatus.interrupted);
  }

  Future<void> startNewConversation() async {
    cancelStream();
    ++_generation;
    ++_historyEpoch;
    _pendingPrompt = null;
    _initialized = true;
    state = AssistantState(loadStatus: ConversationLoadStatus.ready);
    await saveDraft();
  }
}
