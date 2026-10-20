import 'dart:async';
import 'dart:convert';

import 'package:ghar360/core/config/app_config.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/network/api_paths.dart';
import 'package:ghar360/core/network/auth_header_provider.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:http/http.dart' as http;

/// Parsed Server-Sent Event.
class SseEvent {
  final String event;
  final Map<String, dynamic> data;

  const SseEvent({required this.event, required this.data});

  @override
  String toString() => 'SseEvent($event, $data)';
}

/// Dedicated client for Server-Sent Events (SSE) via POST requests.
///
/// Unlike [ApiClient] which handles JSON request/response, this client
/// streams the response body and parses SSE lines incrementally. It uses
/// `package:http`, which streams through `HttpClient` on devices and
/// `fetch` on web.
///
/// Authentication follows the same rule as [ApiClient]: a 401 gets one forced token refresh and
/// one retry, and a 401 that survives it (or a 403 `USER_INACTIVE`) goes to [onUnauthorized],
/// which ends the session. A failed request ends the stream with a typed [AppException] built
/// from the backend error envelope; the backend's own `error` frame stays an event.
class SseClient {
  final AuthHeaderProvider _authProvider;
  final String _baseUrl;
  final Set<http.Client> _activeClients = {};
  int _generation = 0;
  bool _closed = false;

  /// Told about a response that ends the session. Wired to the API client's handler.
  UnauthorizedHandler? onUnauthorized;

  SseClient({required this._authProvider, String? baseUrl, this.onUnauthorized})
    : _baseUrl = _normalizeBaseUrl(
        baseUrl ??
            (AppConfig.isInitialized ? AppConfig.instance.apiBaseUrl : 'https://api.360ghar.com'),
      );

  /// Strip trailing `/api/v1` so [ApiPaths.normalize] can re-add it.
  /// Mirrors [ApiClient._normalizeBaseUrl].
  static String _normalizeBaseUrl(String url) {
    var normalized = url.trim();
    if (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    if (normalized.endsWith(ApiPaths.apiVersionPrefix)) {
      normalized = normalized.substring(0, normalized.length - ApiPaths.apiVersionPrefix.length);
    }
    return normalized;
  }

  /// POST to [endpoint] and return a [Stream] of parsed [SseEvent]s.
  ///
  /// The stream completes when the connection closes. A failed request ends it with an
  /// [AppException]: [AuthenticationException] (401, 403), [NotFoundException] or [ApiException]
  /// (404 and other 4xx), [ValidationException] (422), [RateLimitException] (429),
  /// [ServerException] (5xx) or [NetworkException] (no connection, timeout, cancelled).
  /// Call [StreamSubscription.cancel] to abort early.
  Stream<SseEvent> postStream(String endpoint, {required Map<String, dynamic> body}) async* {
    if (_closed) return;
    final generation = _generation;
    final url = Uri.parse('$_baseUrl${ApiPaths.normalize(endpoint)}');
    DebugLogger.info('🌐 SSE POST ${url.path}');

    var forceRefresh = false;
    while (true) {
      final authHeader = await _authProvider.getAuthHeader(forceRefresh: forceRefresh);
      if (_closed || generation != _generation) return;
      if (authHeader == null) {
        // Raised on the device, not by the server: it never ends the session.
        throw AuthenticationException(
          'Authentication required but no auth header available',
          code: AppException.missingAuthHeaderCode,
        );
      }

      final client = http.Client();
      _activeClients.add(client);
      try {
        final request = http.Request('POST', url)
          ..headers.addAll({
            'Content-Type': 'application/json',
            'Accept': 'text/event-stream',
            ...authHeader,
          })
          ..body = jsonEncode(body);
        final response = await client
            .send(request)
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () => throw TimeoutException('SSE connection timed out'),
            );

        if (response.statusCode == 401 && !forceRefresh) {
          // The shared rule: one forced refresh, one retry.
          forceRefresh = true;
          await response.stream.drain<void>();
          continue;
        }

        if (response.statusCode != 200) {
          final error = await _failure(response);
          if (error is AuthenticationException && error.endsSession) {
            await _notifyUnauthorized(error, url, response.statusCode);
          }
          throw error;
        }

        yield* _events(response, generation);
        return;
      } on TimeoutException {
        if (_closed || generation != _generation) return;
        throw NetworkException('The assistant connection timed out.', code: 'TIMEOUT');
      } on http.ClientException {
        // Socket, TLS and fetch failures on every platform.
        if (_closed || generation != _generation) return;
        throw NetworkException('The service could not be reached.', code: 'NETWORK_ERROR');
      } finally {
        _activeClients.remove(client);
        client.close();
      }
    }
  }

  /// The typed failure of a non-200 response, from its error envelope.
  Future<AppException> _failure(http.StreamedResponse response) async {
    dynamic body;
    try {
      final bytes = await response.stream.toBytes().timeout(const Duration(seconds: 5));
      if (bytes.isNotEmpty) body = jsonDecode(utf8.decode(bytes));
    } catch (_) {
      // An upstream proxy can answer with HTML or nothing. The status still names the failure,
      // and that body is never shown.
    }
    return ApiClient.mapHttpError(
      ApiResponse(statusCode: response.statusCode, body: body, headers: response.headers),
    );
  }

  Future<void> _notifyUnauthorized(AuthenticationException error, Uri url, int statusCode) async {
    final handler = onUnauthorized;
    if (handler == null) return;
    try {
      await handler(
        UnauthorizedEvent(
          error: error,
          method: 'POST',
          endpoint: url.toString(),
          statusCode: statusCode,
        ),
      );
    } catch (error, stack) {
      DebugLogger.warning('Unauthorized handler failed.', error.runtimeType, stack);
    }
  }

  /// Parse the SSE stream line by line, carrying a partial line across chunk boundaries.
  Stream<SseEvent> _events(http.StreamedResponse response, int generation) async* {
    String currentEvent = 'message';
    StringBuffer dataBuffer = StringBuffer();
    String carryOver = '';

    await for (final chunk in response.stream.transform(utf8.decoder)) {
      if (_closed || generation != _generation) return;
      final combined = carryOver + chunk;
      final lines = combined.split('\n');

      // Last element may be a partial line if chunk didn't end with \n
      carryOver = combined.endsWith('\n') ? '' : lines.removeLast();

      for (final rawLine in lines) {
        final line = rawLine.endsWith('\r') ? rawLine.substring(0, rawLine.length - 1) : rawLine;
        if (line.startsWith('event: ')) {
          currentEvent = line.substring(7).trim();
        } else if (line.startsWith('data: ')) {
          if (dataBuffer.isNotEmpty) dataBuffer.write('\n');
          dataBuffer.write(line.substring(6));
        } else if (line.isEmpty && dataBuffer.isNotEmpty) {
          // Blank line = end of event
          try {
            final json = jsonDecode(dataBuffer.toString());
            yield SseEvent(
              event: currentEvent,
              data: json is Map<String, dynamic> ? json : <String, dynamic>{'value': json},
            );
          } catch (error, stack) {
            DebugLogger.warning('SSE event parse failed', error, stack);
          }
          currentEvent = 'message';
          dataBuffer = StringBuffer();
        }
      }
    }
  }

  void cancelPendingRequests() {
    _generation++;
    for (final client in _activeClients) {
      client.close();
    }
    _activeClients.clear();
  }

  void close() {
    if (_closed) return;
    _closed = true;
    cancelPendingRequests();
  }
}
