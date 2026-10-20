import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/bootstrap/provider_policy.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/features/assistant/data/assistant_repository.dart';
import 'package:ghar360/features/assistant/data/models/conversation_model.dart';
import 'package:ghar360/features/assistant/presentation/controllers/assistant_controller.dart';

final assistantHistoryProvider =
    NotifierProvider.autoDispose<AssistantHistoryController, AssistantHistoryState>(
      AssistantHistoryController.new,
      retry: noProviderRetry,
    );

enum HistoryLoadStatus {
  initial,
  loading,
  ready,
  refreshing,
  loadingMore,
  failed,
  refreshFailed,
  pageFailed,
}

const _unchanged = Object();

class AssistantHistoryState {
  AssistantHistoryState({
    List<ConversationModel> conversations = const [],
    this.status = HistoryLoadStatus.initial,
    this.nextCursor,
    this.hasMore = false,
    this.error,
    this.deletingId,
    this.deleteError,
    this.cleanupId,
  }) : conversations = List.unmodifiable(conversations);
  final List<ConversationModel> conversations;
  final HistoryLoadStatus status;
  final String? nextCursor;
  final bool hasMore;
  final Object? error;
  final int? deletingId;
  final Object? deleteError;
  final int? cleanupId;
  bool get isLoading => const [
    HistoryLoadStatus.loading,
    HistoryLoadStatus.refreshing,
    HistoryLoadStatus.loadingMore,
  ].contains(status);
  AssistantHistoryState copyWith({
    List<ConversationModel>? conversations,
    HistoryLoadStatus? status,
    Object? nextCursor = _unchanged,
    bool? hasMore,
    Object? error = _unchanged,
    Object? deletingId = _unchanged,
    Object? deleteError = _unchanged,
    Object? cleanupId = _unchanged,
  }) => AssistantHistoryState(
    conversations: conversations ?? this.conversations,
    status: status ?? this.status,
    nextCursor: identical(nextCursor, _unchanged) ? this.nextCursor : nextCursor as String?,
    hasMore: hasMore ?? this.hasMore,
    error: identical(error, _unchanged) ? this.error : error,
    deletingId: identical(deletingId, _unchanged) ? this.deletingId : deletingId as int?,
    deleteError: identical(deleteError, _unchanged) ? this.deleteError : deleteError,
    cleanupId: identical(cleanupId, _unchanged) ? this.cleanupId : cleanupId as int?,
  );
}

class AssistantHistoryController extends Notifier<AssistantHistoryState> {
  late AssistantRepository _repository;
  late AppDatabase _database;
  late StorageScope _scope;
  int _generation = 0;
  static const _pageSize = 50;
  final _seenCursors = <String>{};
  @override
  AssistantHistoryState build() {
    _repository = ref.watch(assistantRepositoryProvider);
    _scope = ref.watch(storageScopeProvider);
    _database = ref.watch(appDatabaseProvider);
    ++_generation;
    _seenCursors.clear();
    ref.onDispose(() => ++_generation);
    return AssistantHistoryState();
  }

  bool _current(int generation) => ref.mounted && generation == _generation;

  Future<void> loadConversations() => _load(more: false);
  Future<void> loadMoreConversations() => _load(more: true);

  /// SQLite key of the first page, shown at once on a repeat visit.
  static const cacheKey = 'assistant:conversations:first';

  Future<void> _load({required bool more}) async {
    if (state.isLoading) return;
    final failed = state.error;
    if (more &&
        state.status == HistoryLoadStatus.pageFailed &&
        failed is ApiException &&
        failed.code == 'INVALID_CURSOR') {
      // The cursor can never succeed again; start over from the first page.
      return _load(more: false);
    }
    final cursor = more ? state.nextCursor : null;
    if (more && (!state.hasMore || cursor == null || cursor.isEmpty)) {
      if (state.hasMore) state = state.copyWith(hasMore: false, nextCursor: null);
      return;
    }
    final generation = _generation;
    final firstVisit = !more && state.status == HistoryLoadStatus.initial;
    state = state.copyWith(
      status: more
          ? HistoryLoadStatus.loadingMore
          : state.conversations.isEmpty
          ? HistoryLoadStatus.loading
          : HistoryLoadStatus.refreshing,
      error: null,
    );
    if (firstVisit) {
      await _restoreCache(generation);
      if (!_current(generation)) return;
      if (state.conversations.isNotEmpty) {
        state = state.copyWith(status: HistoryLoadStatus.refreshing);
      }
    }
    try {
      final page = await _repository.getConversations(cursor: cursor, limit: _pageSize);
      if (!_current(generation)) return;
      if (!more) _seenCursors.clear();
      if (cursor != null) _seenCursors.add(cursor);
      final ids = <int>{};
      final items = [
        for (final item in [...(more ? state.conversations : <ConversationModel>[]), ...page.items])
          if (ids.add(item.id)) item,
      ];
      final nextCursor = page.nextCursor;
      final hasMore =
          page.hasMore &&
          nextCursor != null &&
          nextCursor.isNotEmpty &&
          !_seenCursors.contains(nextCursor);
      state = state.copyWith(
        conversations: items,
        status: HistoryLoadStatus.ready,
        nextCursor: hasMore ? nextCursor : null,
        hasMore: hasMore,
      );
      if (!more) await _persist();
    } catch (error, stack) {
      if (!_current(generation)) return;
      DebugLogger.warning('Assistant history failed.', error.runtimeType, stack);
      state = state.copyWith(
        status: more
            ? HistoryLoadStatus.pageFailed
            : state.conversations.isEmpty
            ? HistoryLoadStatus.failed
            : HistoryLoadStatus.refreshFailed,
        error: error,
      );
    }
  }

  Future<void> _restoreCache(int generation) async {
    try {
      final cached = (await _database.readCache(scope: _scope, key: cacheKey))?.value;
      if (!_current(generation) || cached is! Map || cached['items'] is! List) return;
      final items = [
        for (final item in cached['items'] as List)
          if (item is Map) ConversationModel.fromJson(Map<String, dynamic>.from(item)),
      ];
      final next = cached['next_cursor'];
      state = state.copyWith(
        conversations: items,
        nextCursor: next is String && next.isNotEmpty ? next : null,
        hasMore: cached['has_more'] == true && next is String && next.isNotEmpty,
      );
    } catch (error, stack) {
      // A missing or unreadable cache only means the network load shows a skeleton.
      DebugLogger.warning('Assistant history cache read failed.', error.runtimeType, stack);
    }
  }

  /// Stores the first page (not later pages) so the next visit opens without a skeleton.
  Future<void> _persist() async {
    final snapshot = state;
    final first = snapshot.conversations.take(_pageSize).toList();
    final complete = first.length == snapshot.conversations.length;
    final now = DateTime.now();
    try {
      await _database.writeCache(
        scope: _scope,
        key: cacheKey,
        value: {
          'items': [for (final item in first) item.toJson()],
          'next_cursor': complete ? snapshot.nextCursor : null,
          'has_more': complete && snapshot.hasMore,
        },
        freshUntil: now.add(const Duration(minutes: 5)),
        expiresAt: now.add(const Duration(days: 7)),
      );
    } catch (error, stack) {
      DebugLogger.warning('Assistant history cache write failed.', error.runtimeType, stack);
    }
  }

  Future<void> retryDraftCleanup() async {
    final id = state.cleanupId;
    if (id != null) await _clearDrafts(id);
  }

  Future<void> _clearDrafts(int id) async {
    final generation = _generation;
    final scope = _scope;
    final database = _database;
    try {
      await database.removeDraft(scope: scope, key: 'assistant:$id');
      final newDraft = await database.readDraft(scope: scope, key: 'assistant:new');
      if (newDraft?['conversation_id'] == id) {
        await database.removeDraft(scope: scope, key: 'assistant:new');
      }
      if (_current(generation)) state = state.copyWith(deleteError: null, cleanupId: null);
    } catch (error, stack) {
      DebugLogger.warning('Deleted conversation draft cleanup failed.', error.runtimeType, stack);
      if (_current(generation)) state = state.copyWith(deleteError: error, cleanupId: id);
    }
  }

  Future<bool> deleteConversation(int id) async {
    if (state.deletingId != null || state.cleanupId != null) return false;
    final generation = _generation;
    state = state.copyWith(deletingId: id, deleteError: null);
    try {
      if (!await _repository.deleteConversation(id)) throw StateError('Conversation delete failed');
      if (!_current(generation)) return false;
      await _clearDrafts(id);
      if (!_current(generation)) return false;
      // Invalidate an open conversation only after the server confirms deletion.
      ref.invalidate(assistantControllerProvider(id));
      state = state.copyWith(
        conversations: state.conversations.where((item) => item.id != id).toList(),
        deletingId: null,
      );
      // A repeat visit must not show the deleted row, even for a moment.
      await _persist();
      return true;
    } catch (error, stack) {
      if (!_current(generation)) return false;
      DebugLogger.warning('Assistant delete failed.', error.runtimeType, stack);
      state = state.copyWith(deletingId: null, deleteError: error);
      return false;
    }
  }
}
