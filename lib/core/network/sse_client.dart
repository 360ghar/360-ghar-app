import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ghar360/core/config/app_config.dart';
import 'package:ghar360/core/network/api_paths.dart';
import 'package:ghar360/core/network/auth_header_provider.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/utils/debug_logger.dart';

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
/// streams the response body and parses SSE lines incrementally.
class SseClient {
  final AuthHeaderProvider _authProvider;
  final String _baseUrl;

  SseClient({required this._authProvider, String? baseUrl})
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
  /// The stream completes when the server sends a `done` event or the
  /// connection closes.  Call [StreamSubscription.cancel] to abort early.
  Stream<SseEvent> postStream(String endpoint, {required Map<String, dynamic> body}) async* {
    final url = Uri.parse('$_baseUrl${ApiPaths.normalize(endpoint)}');
    DebugLogger.info('🌐 SSE POST $url');

    final authHeader = await _authProvider.getAuthHeader();
    if (authHeader == null) {
      yield const SseEvent(
        event: 'error',
        data: {'code': 'AUTH_MISSING', 'message': 'Not authenticated'},
      );
      return;
    }

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);

    HttpClientResponse? response;
    try {
      final request = await client.postUrl(url);
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Accept', 'text/event-stream');
      authHeader.forEach((key, value) {
        request.headers.set(key, value);
      });
      request.write(jsonEncode(body));
      response = await request.close().timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('SSE connection timed out'),
      );

      if (response.statusCode == 401) {
        yield const SseEvent(
          event: 'error',
          data: {'code': AppException.unauthorizedCode, 'message': 'Authentication failed'},
        );
        return;
      }

      if (response.statusCode != 200) {
        yield SseEvent(
          event: 'error',
          data: {
            'code': 'HTTP_${response.statusCode}',
            'message': 'Server returned ${response.statusCode}',
          },
        );
        return;
      }

      // Parse the SSE stream line by line.
      // Carry partial lines across chunk boundaries.
      String currentEvent = 'message';
      StringBuffer dataBuffer = StringBuffer();
      String carryOver = '';

      await for (final chunk in response.transform(utf8.decoder)) {
        final combined = carryOver + chunk;
        final lines = combined.split('\n');

        // Last element may be a partial line if chunk didn't end with \n
        carryOver = combined.endsWith('\n') ? '' : lines.removeLast();

        for (final line in lines) {
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
            } catch (e) {
              DebugLogger.warning('SSE parse error: $e');
            }
            currentEvent = 'message';
            dataBuffer = StringBuffer();
          }
        }
      }
    } on TimeoutException catch (e) {
      yield SseEvent(
        event: 'error',
        data: {'code': 'TIMEOUT', 'message': e.message ?? 'Request timed out'},
      );
    } on SocketException catch (e) {
      yield SseEvent(event: 'error', data: {'code': 'NETWORK_ERROR', 'message': e.message});
    } on HttpException catch (e) {
      yield SseEvent(event: 'error', data: {'code': 'HTTP_ERROR', 'message': e.message});
    } catch (e) {
      yield SseEvent(event: 'error', data: {'code': 'UNKNOWN_ERROR', 'message': e.toString()});
    } finally {
      client.close(force: true);
    }
  }
}
