import 'dart:async';

import 'package:get/get.dart';

import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/network/sse_client.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/features/assistant/data/models/chat_message_model.dart';
import 'package:ghar360/features/assistant/data/models/conversation_model.dart';

/// A single page of conversations returned by [AssistantRepository.getConversations].
///
/// Mirrors the uniform cursor envelope (`{items, next_cursor, has_more}`)
/// documented on the endpoint so callers can drive [loadMoreConversations]
/// without re-parsing the response.
class ConversationsPage {
  final List<ConversationModel> items;
  final String? nextCursor;
  final bool hasMore;

  const ConversationsPage({required this.items, required this.hasMore, this.nextCursor});
}

class AssistantRepository {
  final SseClient _sseClient = Get.find<SseClient>();
  final ApiClient _apiClient = Get.find<ApiClient>();
  final Map<String, String?> _widgetHtmlCache = {};

  /// Stream chat response from the agent via SSE.
  Stream<SseEvent> streamChat({required String message, int? conversationId}) {
    return _sseClient.postStream(
      '/agent/chat',
      body: {'message': message, 'conversation_id': ?conversationId},
    );
  }

  /// List the user's conversations.
  ///
  /// Uses the uniform cursor envelope `{items, next_cursor, has_more, limit}`.
  /// Pass [cursor] (from a previous response's `next_cursor`) to fetch the
  /// next page; omit/null on the first page. Returns a [ConversationsPage]
  /// so callers can drive pagination from [nextCursor] and [hasMore].
  Future<ConversationsPage> getConversations({String? cursor, int limit = 50}) async {
    try {
      final response = await _apiClient.get(
        '/agent/conversations',
        queryParams: <String, dynamic>{
          'limit': limit.toString(),
          if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        },
      );
      final body = response.body;

      // Tolerate bare-list responses too (older deployments that pre-date the
      // cursor envelope): treat a bare list as a single terminal page.
      if (body is List) {
        final items = body
            .map((e) => ConversationModel.fromJson(e as Map<String, dynamic>))
            .toList();
        return ConversationsPage(items: items, hasMore: false, nextCursor: null);
      }

      if (body is Map<String, dynamic>) {
        final dynamic rawItems = body['items'] ?? body['data'];
        final items = rawItems is List
            ? rawItems.whereType<Map<String, dynamic>>().map(ConversationModel.fromJson).toList()
            : const <ConversationModel>[];

        // Envelope-driven pagination: honour has_more / next_cursor when the
        // server provides them. Default to a terminal page otherwise so the
        // caller short-circuits on subsequent [loadMoreConversations] calls.
        final dynamic rawHasMore = body['has_more'];
        final dynamic rawNextCursor = body['next_cursor'];
        final bool hasMore = rawHasMore is bool ? rawHasMore : false;
        final String? nextCursor = rawNextCursor is String && rawNextCursor.isNotEmpty
            ? rawNextCursor
            : null;

        return ConversationsPage(items: items, hasMore: hasMore, nextCursor: nextCursor);
      }

      return const ConversationsPage(items: <ConversationModel>[], hasMore: false);
    } catch (e) {
      DebugLogger.error('Failed to load conversations', e);
      return const ConversationsPage(items: <ConversationModel>[], hasMore: false);
    }
  }

  /// Get messages for a conversation.
  Future<List<ChatMessageModel>> getConversationMessages(
    int conversationId, {
    int limit = 100,
  }) async {
    try {
      final response = await _apiClient.get(
        '/agent/conversations/$conversationId/messages?limit=$limit',
      );
      if (response.body is List) {
        return (response.body as List)
            .map((e) => ChatMessageModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      DebugLogger.error('Failed to load messages', e);
      return [];
    }
  }

  /// Fetch widget HTML bundle by name (cached in memory).
  ///
  /// Caches both successful and failed results to avoid repeated
  /// network requests during streaming list rebuilds.
  Future<String?> getWidgetHtml(String widgetName) async {
    if (_widgetHtmlCache.containsKey(widgetName)) {
      return _widgetHtmlCache[widgetName];
    }
    try {
      final response = await _apiClient.get('/agent/widgets/$widgetName');
      if (response.body is String) {
        final html = response.body as String;
        _widgetHtmlCache[widgetName] = html;
        return html;
      }
    } catch (e) {
      DebugLogger.error('Failed to fetch widget HTML', e);
    }
    _widgetHtmlCache[widgetName] = null;
    return null;
  }

  /// Delete a conversation.
  Future<bool> deleteConversation(int conversationId) async {
    try {
      await _apiClient.delete('/agent/conversations/$conversationId');
      return true;
    } catch (e) {
      DebugLogger.error('Failed to delete conversation', e);
      return false;
    }
  }
}
