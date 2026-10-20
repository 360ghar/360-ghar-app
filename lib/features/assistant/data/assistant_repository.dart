import 'dart:async';

import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/network/api_paths.dart';
import 'package:ghar360/core/network/response_parser.dart';
import 'package:ghar360/core/network/sse_client.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/features/assistant/data/models/assistant_frame.dart';
import 'package:ghar360/features/assistant/data/models/chat_message_model.dart';
import 'package:ghar360/features/assistant/data/models/conversation_model.dart';

/// A page of conversations, newest first.
typedef ConversationsPage = CursorPageData<ConversationModel>;

/// A page of messages, oldest first within the page. [CursorPageData.nextCursor] points to
/// older messages.
typedef MessagesPage = CursorPageData<ChatMessageModel>;

class AssistantRepository {
  AssistantRepository({required this._sseClient, required this._apiClient});

  final SseClient _sseClient;
  final ApiClient _apiClient;
  final Map<String, String?> _widgetHtmlCache = {};

  /// The longest message the backend takes (`AgentChatRequest.message`): a longer one is a 422.
  static const maxMessageLength = 4000;

  /// Stream the reply of the agent as typed frames. The stream ends with an [AppException] when
  /// the request fails (see [SseClient.postStream]) and with a [FormatException] when a frame
  /// does not match the contract. A frame name this app does not know is skipped.
  Stream<AssistantFrame> streamChat({required String message, int? conversationId}) async* {
    if (message.isEmpty || message.length > maxMessageLength) {
      throw ValidationException(
        'The message is empty or longer than $maxMessageLength characters.',
        code: 'INVALID_MESSAGE',
      );
    }
    await for (final event in _sseClient.postStream(
      ApiPaths.agentChat,
      body: {'message': message, 'conversation_id': ?conversationId},
    )) {
      final frame = AssistantFrame.fromEvent(event);
      if (frame != null) yield frame;
    }
  }

  /// List the user's conversations. Pass [cursor] from a previous page's
  /// `next_cursor`; omit it for the first page.
  Future<ConversationsPage> getConversations({String? cursor, int limit = 50}) async {
    final response = await _apiClient.get(
      ApiPaths.agentConversations,
      queryParams: <String, dynamic>{
        'limit': limit.clamp(1, 100).toString(),
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      },
    );
    return _page(response.body, ConversationModel.fromJson);
  }

  /// The newest [limit] messages, or the page before [cursor]
  /// (`GET /agent/conversations/{id}/messages/page`, a `CursorPage`, 1 to 100 rows).
  Future<MessagesPage> getMessagesPage(int conversationId, {String? cursor, int limit = 30}) async {
    final response = await _apiClient.get(
      ApiPaths.agentMessagesPage(conversationId),
      queryParams: <String, dynamic>{'limit': '${limit.clamp(1, 100)}', 'cursor': ?cursor},
    );
    return _page(response.body, ChatMessageModel.fromJson);
  }

  /// A `CursorPage`. A row that cannot be read fails the page, so a partial page never looks
  /// complete.
  CursorPageData<T> _page<T>(Object? body, T Function(Map<String, dynamic>) fromJson) {
    try {
      return ResponseParser.cursorPage(body, fromJson);
    } on FormatException {
      throw _malformedResponse();
    } on TypeError {
      throw _malformedResponse();
    }
  }

  ApiException _malformedResponse() =>
      ApiException('Conversation data could not be read.', code: 'MALFORMED_RESPONSE');

  /// Safe widget name: alphanumeric, underscore, hyphen only (blocks path traversal).
  static final RegExp widgetNamePattern = RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9_-]{0,63}$');

  /// Returns true when [widgetName] is safe to interpolate into a URL path.
  static bool isValidWidgetName(String widgetName) => widgetNamePattern.hasMatch(widgetName);

  /// Fetch widget HTML bundle by name (cached in memory).
  ///
  /// Caches both successful and failed results to avoid repeated
  /// network requests during streaming list rebuilds.
  Future<String?> getWidgetHtml(String widgetName) async {
    if (!isValidWidgetName(widgetName)) {
      DebugLogger.warning('Rejected unsafe assistant widget name');
      return null;
    }
    if (_widgetHtmlCache.containsKey(widgetName)) {
      return _widgetHtmlCache[widgetName];
    }
    try {
      final response = await _apiClient.get(ApiPaths.agentWidget(widgetName));
      if (response.body is String) {
        final html = response.body as String;
        _widgetHtmlCache[widgetName] = html;
        return html;
      }
    } catch (error, stack) {
      DebugLogger.error('Failed to fetch widget HTML: ${error.runtimeType}', null, stack);
    }
    // Do not cache failures — allow retry on next call.
    return null;
  }

  /// Clears in-memory widget HTML (call on logout).
  void clearWidgetCache() => _widgetHtmlCache.clear();

  /// Delete a conversation (`DELETE`, 204 with no body).
  Future<bool> deleteConversation(int conversationId) async {
    try {
      await _apiClient.delete(ApiPaths.agentConversation(conversationId));
      return true;
    } catch (error, stack) {
      DebugLogger.error('Failed to delete conversation: ${error.runtimeType}', null, stack);
      return false;
    }
  }
}
