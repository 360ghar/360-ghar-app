import 'dart:async';
import 'dart:convert';

import 'package:firebase_performance/firebase_performance.dart' as fp;
import 'package:flutter/foundation.dart';
import 'package:ghar360/core/config/app_config.dart';
import 'package:ghar360/core/network/api_error.dart';
import 'package:ghar360/core/network/api_paths.dart';
import 'package:ghar360/core/network/api_response.dart';
import 'package:ghar360/core/network/auth_header_provider.dart';
import 'package:ghar360/core/network/etag_cache.dart';
import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/core/utils/retry_policy.dart';
import 'package:http/http.dart' as http;
import 'package:universal_io/io.dart' show HttpDate, HttpException;

export 'package:ghar360/core/network/api_response.dart';

class UnauthorizedEvent {
  final AuthenticationException error;
  final String method;
  final String endpoint;
  final int statusCode;

  const UnauthorizedEvent({
    required this.error,
    required this.method,
    required this.endpoint,
    required this.statusCode,
  });
}

typedef UnauthorizedHandler = Future<void> Function(UnauthorizedEvent event);
typedef RequestDispatcher =
    Future<ApiResponse> Function(
      String method,
      String url, {
      Map<String, dynamic>? body,
      required Map<String, String> headers,
    });

/// Focused HTTP client for API communication.
/// Handles: auth headers, retries, instrumentation, caching (ETag).
class ApiClient {
  UnauthorizedHandler? onUnauthorized;
  DateTime? _lastUnauthorizedNotificationAt;
  static const Duration _unauthorizedNotificationCooldown = Duration(seconds: 6);

  final String _baseUrl;
  final AuthHeaderProvider _authProvider;
  final ETagCache? _etagCache;
  final int _timeoutSeconds;

  /// Optional override of GET retry count (tests). When null, [RetryPolicy.apiGet]
  /// is the sole budget for GET retries.
  final int? _maxGetRetriesOverride;
  final bool _enablePerformanceMetrics;
  final RequestDispatcher? _requestDispatcher;
  http.Client? _client;
  final Set<Completer<void>> _activeRequests = {};
  int _requestGeneration = 0;
  bool _closed = false;

  /// In-flight GET requests keyed by request URL and auth/request semantics.
  /// Prevents duplicate calls without sharing one user's response with another.
  final Map<String, Future<ApiResponse>> _inflightGets = {};

  ApiClient({
    String? baseUrl,
    AuthHeaderProvider? authProvider,
    this._etagCache,
    this._timeoutSeconds = 15,
    int? maxGetRetries,
    this._enablePerformanceMetrics = !kDebugMode,
    this._requestDispatcher,
    this._client,
  }) : _maxGetRetriesOverride = maxGetRetries,
       _baseUrl = _normalizeBaseUrl(
         baseUrl ??
             (AppConfig.isInitialized ? AppConfig.instance.apiBaseUrl : 'https://api.360ghar.com'),
       ),
       _authProvider = authProvider ?? AuthHeaderProvider();

  String get baseUrl => _baseUrl;

  /// False for a guest. Public reads pass it as `requireAuth` so a guest sends no token
  /// and a signed-in user keeps the forced refresh.
  bool get signedIn => _authProvider.signedIn;

  http.Client get _resolvedClient => _client ??= http.Client();

  /// Makes a GET request.
  /// Set [dedupe] to false to bypass in-flight request deduplication.
  Future<ApiResponse> get(
    String endpoint, {
    Map<String, dynamic>? queryParams,
    bool useCache = true,
    bool dedupe = true,
    bool requireAuth = true,
    bool notifyUnauthorized = true,
  }) async {
    if (!dedupe) {
      return _makeRequest(
        'GET',
        endpoint,
        queryParams: queryParams,
        useCache: useCache,
        requireAuth: requireAuth,
        notifyUnauthorized: notifyUnauthorized,
      );
    }

    final requestUrl = _buildUrl(endpoint, queryParams);
    final dedupeKey =
        '$requestUrl|generation=$_requestGeneration|scope=${_authProvider.requestScope}|auth=$requireAuth|'
        'cache=$useCache|unauthorized=$notifyUnauthorized';
    final inflight = _inflightGets[dedupeKey];
    if (inflight != null) {
      DebugLogger.debug('Deduplicating GET ${_diagnosticPath(requestUrl)}');
      return inflight;
    }

    final future =
        _makeRequest(
          'GET',
          endpoint,
          queryParams: queryParams,
          useCache: useCache,
          requireAuth: requireAuth,
          notifyUnauthorized: notifyUnauthorized,
        ).whenComplete(() {
          _inflightGets.remove(dedupeKey);
        });

    _inflightGets[dedupeKey] = future;
    return future;
  }

  /// Makes a POST request.
  /// Set [idempotent] to true to allow one retry on transient errors.
  Future<ApiResponse> post(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParams,
    bool idempotent = false,
    bool requireAuth = true,
    bool notifyUnauthorized = true,
  }) async {
    return _makeRequest(
      'POST',
      endpoint,
      body: body,
      queryParams: queryParams,
      idempotent: idempotent,
      requireAuth: requireAuth,
      notifyUnauthorized: notifyUnauthorized,
    );
  }

  /// Makes a PUT request.
  /// Set [idempotent] to true to allow one retry on transient errors.
  Future<ApiResponse> put(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParams,
    bool idempotent = false,
    bool requireAuth = true,
    bool notifyUnauthorized = true,
  }) async {
    return _makeRequest(
      'PUT',
      endpoint,
      body: body,
      queryParams: queryParams,
      idempotent: idempotent,
      requireAuth: requireAuth,
      notifyUnauthorized: notifyUnauthorized,
    );
  }

  /// Makes a DELETE request. A delete answers 204 with no body. A route that names its target in
  /// a JSON [body] (for example the device token) takes it here, never in the URL.
  Future<ApiResponse> delete(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParams,
    bool requireAuth = true,
    bool notifyUnauthorized = true,
  }) async {
    return _makeRequest(
      'DELETE',
      endpoint,
      body: body,
      queryParams: queryParams,
      requireAuth: requireAuth,
      notifyUnauthorized: notifyUnauthorized,
    );
  }

  /// Makes a PATCH request.
  Future<ApiResponse> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParams,
    bool requireAuth = true,
    bool notifyUnauthorized = true,
  }) async {
    return _makeRequest(
      'PATCH',
      endpoint,
      body: body,
      queryParams: queryParams,
      requireAuth: requireAuth,
      notifyUnauthorized: notifyUnauthorized,
    );
  }

  /// Upload a file via multipart/form-data POST. A 401 gets one forced token refresh and one
  /// retry, like every other request; a 401 that survives it ends the session.
  Future<ApiResponse> upload(
    String endpoint, {
    required String field,
    required String filePath,
    Map<String, String>? fields,
    bool requireAuth = true,
    bool notifyUnauthorized = true,
  }) async {
    final scope = _authProvider.requestScope;
    final generation = _requestGeneration;
    _ensureCurrentRequest(scope, generation);
    final url = _buildUrl(endpoint, null);
    var forceRefresh = false;
    while (true) {
      final headers = await _buildHeaders(requireAuth: requireAuth, forceRefresh: forceRefresh);
      _ensureCurrentRequest(scope, generation);
      headers.remove('Content-Type');
      final abort = Completer<void>();
      final request =
          http.AbortableMultipartRequest('POST', Uri.parse(url), abortTrigger: abort.future)
            ..headers.addAll(headers)
            ..fields.addAll(fields ?? const {});
      request.files.add(await http.MultipartFile.fromPath(field, filePath));
      _ensureCurrentRequest(scope, generation);

      try {
        final response = await _sendRequest(request, abort);
        _ensureCurrentRequest(scope, generation);
        if (response.statusCode == 401 && requireAuth && !forceRefresh) {
          forceRefresh = true;
          continue;
        }
        if (!response.isSuccess) {
          final error = mapHttpError(response);
          if (error is AuthenticationException &&
              error.endsSession &&
              requireAuth &&
              notifyUnauthorized) {
            await _notifyUnauthorized(
              UnauthorizedEvent(
                error: error,
                method: 'POST',
                endpoint: url,
                statusCode: response.statusCode,
              ),
            );
          }
          throw error;
        }
        return response;
      } on TimeoutException {
        throw NetworkException('The upload timed out.', code: 'TIMEOUT');
      }
    }
  }

  Future<ApiResponse> _makeRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParams,
    bool useCache = false,
    bool idempotent = false,
    bool requireAuth = true,
    bool notifyUnauthorized = true,
  }) async {
    final scope = _authProvider.requestScope;
    final generation = _requestGeneration;
    _ensureCurrentRequest(scope, generation);
    final fullEndpoint = _buildUrl(endpoint, queryParams);
    final requestPath = _diagnosticPath(fullEndpoint);
    Map<String, String> headers;
    try {
      headers = await _buildHeaders(requireAuth: requireAuth, forceRefresh: false);
    } on AuthenticationException catch (e) {
      _ensureCurrentRequest(scope, generation);
      // A dead refresh token surfaces here (MISSING_AUTH_HEADER) instead of as a 401. The
      // handler sees it, but it carries no status, so only a server 401 ends the session.
      if (notifyUnauthorized) {
        await _notifyUnauthorized(
          UnauthorizedEvent(
            error: e,
            method: method.toUpperCase(),
            endpoint: fullEndpoint,
            statusCode: 401,
          ),
        );
      }
      rethrow;
    }
    _ensureCurrentRequest(scope, generation);
    final cacheScope = useCache ? _etagCache?.scope : null;
    final cacheKey = useCache && cacheScope != null
        ? _buildCacheKey(method, fullEndpoint, requireAuth: requireAuth, scope: scope)
        : null;
    var authRefreshRetryPerformed = false;
    var cacheRecoveryPerformed = false;
    // Set when a 401's forced refresh failed because the auth server was
    // unreachable. Such a NetworkException must escape the retry loop without
    // being replayed: _shouldRetry treats NetworkException as transient, so it
    // would retry with the OLD expired token — whose second 401 then forces a
    // sign-out for what was only a connectivity blip (see the comment on the
    // forced-refresh catch below).
    var forcedRefreshUnreachable = false;

    CachedEntry? cached;
    if (cacheKey != null && cacheScope != null) {
      try {
        cached = await _etagCache?.read(cacheKey, scope: cacheScope);
      } on StorageFailure catch (error, stack) {
        if (error.code == 'STORAGE_SCOPE_CHANGED') {
          throw NetworkException('The request was cancelled.', code: 'CANCELLED');
        }
        DebugLogger.warning('HTTP cache read failed; fetching current data.', error, stack);
      }
      _ensureCurrentRequest(scope, generation);
      if (cached?.etag case final etag? when etag.isNotEmpty) {
        headers['If-None-Match'] = etag;
      }
    }

    // Performance instrumentation
    fp.HttpMetric? httpMetric;
    int? responseCodeForMetric;
    int? responseSizeForMetric;
    if (_enablePerformanceMetrics) {
      try {
        final uri = Uri.parse(fullEndpoint);
        final metricUrl = Uri(
          scheme: uri.scheme,
          host: uri.host,
          port: uri.hasPort ? uri.port : null,
          path: requestPath,
        ).toString();
        httpMetric = fp.FirebasePerformance.instance.newHttpMetric(
          metricUrl,
          _methodToHttpMethod(method),
        );
        await httpMetric.start();
      } catch (error, stack) {
        DebugLogger.debug('HTTP metric start failed (ignored)', error, stack);
      }
    }

    DebugLogger.api('🚀 API $method $requestPath');

    try {
      var attempt = 0;
      while (true) {
        try {
          _ensureCurrentRequest(scope, generation);
          final response = await _dispatchRequest(
            method,
            fullEndpoint,
            body: body,
            headers: headers,
          );
          _ensureCurrentRequest(scope, generation);
          responseCodeForMetric = response.statusCode;
          if (httpMetric != null) {
            try {
              responseSizeForMetric = utf8.encode(jsonEncode(response.body)).length;
            } catch (error, stack) {
              DebugLogger.debug('HTTP metric size unavailable (ignored)', error, stack);
            }
          }
          DebugLogger.api('📨 API $method $requestPath → ${response.statusCode}');

          // A missing or corrupt cache entry requires one unconditional GET.
          if (response.statusCode == 304 && cacheKey != null) {
            if (cached?.value != null) {
              // A response that is now `no-store` must not stay on the device.
              if (ETagCache.isNoStore(response.headers)) {
                unawaited(_etagCache?.remove(cacheKey, scope: cacheScope!) ?? Future<void>.value());
              }
              return ApiResponse(statusCode: 200, body: cached!.value, headers: response.headers);
            }
            if (!cacheRecoveryPerformed) {
              cacheRecoveryPerformed = true;
              headers.remove('If-None-Match');
              continue;
            }
            throw ApiException('The server returned no usable data.', code: 'MALFORMED_RESPONSE');
          }

          // Handle errors
          if (!response.isSuccess) {
            if (response.statusCode == 401 && requireAuth && !authRefreshRetryPerformed) {
              authRefreshRetryPerformed = true;
              try {
                headers = await _buildHeaders(requireAuth: true, forceRefresh: true);
                DebugLogger.warning(
                  '🔐 401 received for $requestPath. '
                  'Forced token refresh succeeded; retrying once.',
                );
                continue;
              } catch (refreshError, refreshStackTrace) {
                DebugLogger.warning(
                  '🔐 401 received for $requestPath but forced refresh failed.',
                  refreshError,
                  refreshStackTrace,
                );
                // The refresh never reached the server, so the 401 proves
                // nothing about the session. Surface it as a network failure
                // rather than falling through to a sign-out.
                if (refreshError is NetworkException) {
                  forcedRefreshUnreachable = true;
                  rethrow;
                }
              }
            }

            final mappedError = mapHttpError(response);
            // Any 401 that survives the forced-refresh retry above means the
            // session is unusable, whatever endpoint produced it. A 403 for a deactivated
            // account (`USER_INACTIVE`) ends it too.
            if (mappedError is AuthenticationException &&
                mappedError.endsSession &&
                requireAuth &&
                notifyUnauthorized) {
              await _notifyUnauthorized(
                UnauthorizedEvent(
                  error: mappedError,
                  method: method.toUpperCase(),
                  endpoint: fullEndpoint,
                  statusCode: response.statusCode,
                ),
              );
            }
            if (_shouldRetry(
              method: method,
              error: mappedError,
              attempt: attempt,
              idempotent: idempotent,
            )) {
              attempt++;
              await _retryBackoffDelay(attempt, method: method);
              continue;
            }
            throw mappedError;
          }

          // Cache successful GET responses
          if (cacheKey != null && cacheScope != null) {
            try {
              await _etagCache?.cacheResponse(cacheKey, response, scope: cacheScope);
            } on StorageFailure catch (error, stack) {
              if (error.code == 'STORAGE_SCOPE_CHANGED') {
                throw NetworkException('The request was cancelled.', code: 'CANCELLED');
              }
              DebugLogger.warning('HTTP cache write failed.', error, stack);
            }
            _ensureCurrentRequest(scope, generation);
          }

          return ApiResponse(
            statusCode: response.statusCode,
            body: response.body,
            headers: response.headers,
          );
        } on TimeoutException catch (_) {
          if (_shouldRetry(
            method: method,
            error: NetworkException('timeout'),
            attempt: attempt,
            idempotent: idempotent,
          )) {
            attempt++;
            await _retryBackoffDelay(attempt, method: method);
            continue;
          }
          throw NetworkException('The request timed out.', code: 'TIMEOUT');
        } catch (e) {
          // A forced refresh that could not reach the auth server must not be
          // retried with the stale token: _shouldRetry would classify it as
          // transient and replay the request, whose second 401 (already past
          // the refresh branch) notifies unauthorized and signs the user out.
          if (forcedRefreshUnreachable &&
              e is NetworkException &&
              e.code == AuthHeaderProvider.refreshUnreachableCode) {
            rethrow;
          }
          if (_shouldRetry(method: method, error: e, attempt: attempt, idempotent: idempotent)) {
            attempt++;
            await _retryBackoffDelay(attempt, method: method);
            continue;
          }

          if (e is AppException) rethrow;
          throw NetworkException('The service could not be reached.', code: 'NETWORK_ERROR');
        }
      }
    } on AppException {
      rethrow;
    } catch (e) {
      if (e is AppException) rethrow;
      throw NetworkException('The service could not be reached.', code: 'NETWORK_ERROR');
    } finally {
      if (httpMetric != null) {
        try {
          httpMetric.httpResponseCode = responseCodeForMetric ?? 0;
          if (responseSizeForMetric != null) {
            final payloadSize = responseSizeForMetric;
            httpMetric.responsePayloadSize = payloadSize;
          }
        } catch (error, stack) {
          DebugLogger.debug('HTTP metric attributes failed (ignored)', error, stack);
        }
        try {
          await httpMetric.stop();
        } catch (error, stack) {
          DebugLogger.debug('HTTP metric stop failed (ignored)', error, stack);
        }
      }
    }
  }

  /// Static path labels only. Resource identifiers, query values, fragments,
  /// and credentials must never enter logs or monitoring URLs.
  static String _diagnosticPath(String url) {
    const labels = {
      'api',
      'v1',
      'properties',
      'visits',
      'upcoming',
      'past',
      'cancel',
      'reschedule',
      'agents',
      'assigned',
      'users',
      'profile',
      'location',
      'preferences',
      'me',
      'avatar',
      'upload',
      'swipes',
      'notifications',
      'devices',
      'register',
      'unregister',
      'bugs',
      'pages',
      'public',
      'agent',
      'conversations',
      'messages',
      'widgets',
      'health',
      'versions',
      'check',
      'amenities',
    };
    return '/${Uri.parse(url).pathSegments.map((part) => labels.contains(part) ? part : ':value').join('/')}';
  }

  String _buildUrl(String endpoint, Map<String, dynamic>? queryParams) {
    final normalizedEndpoint = ApiPaths.normalize(endpoint);
    final rawUrl = normalizedEndpoint.startsWith('http')
        ? normalizedEndpoint
        : '$_baseUrl$normalizedEndpoint';
    final uri = Uri.parse(rawUrl);
    if (queryParams == null || queryParams.isEmpty) {
      return uri.toString();
    }

    final merged = <String, List<String>>{};
    uri.queryParametersAll.forEach((key, value) {
      merged[key] = List<String>.from(value);
    });

    for (final entry in queryParams.entries) {
      if (entry.value == null) continue;

      final value = entry.value;
      if (value is Iterable && value is! String) {
        final values = value
            .where((item) => item != null)
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList();
        if (values.isNotEmpty) {
          merged[entry.key] = values;
        }
        continue;
      }

      final scalar = value.toString().trim();
      if (scalar.isNotEmpty) {
        merged[entry.key] = [scalar];
      }
    }

    final queryString = merged.entries
        .expand((entry) {
          final encodedKey = Uri.encodeQueryComponent(entry.key);
          final values = entry.value.isEmpty ? const <String>[''] : entry.value;
          return values.map((value) => '$encodedKey=${Uri.encodeQueryComponent(value)}');
        })
        .join('&');

    return uri.replace(query: queryString).toString();
  }

  @visibleForTesting
  String buildUrlForTesting(String endpoint, {Map<String, dynamic>? queryParams}) {
    return _buildUrl(endpoint, queryParams);
  }

  Future<Map<String, String>> _buildHeaders({
    required bool requireAuth,
    bool forceRefresh = false,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (!requireAuth) {
      // Optional auth: attach an already-valid token so the backend can still
      // enrich the response for signed-in users, but never block or refresh.
      final cached = _authProvider.cachedAuthHeader;
      if (cached != null) headers.addAll(cached);
      return headers;
    }

    // Add auth header if available
    final authHeader = await _authProvider.getAuthHeader(forceRefresh: forceRefresh);
    if (authHeader != null) {
      headers.addAll(authHeader);
      DebugLogger.debug('🔐 Auth header added for authenticated request');
    } else {
      // CRITICAL: Block request if auth is required but header is not available
      DebugLogger.error('🔐 CRITICAL: No auth header available for authenticated request');
      throw AuthenticationException(
        'Authentication required but no auth header available',
        code: AppException.missingAuthHeaderCode,
      );
    }

    return headers;
  }

  /// Cache keys are scoped like the in-flight dedupe keys: GET responses
  /// carry per-user data (e.g. liked-status), so one account's cached entry
  /// must never be served to another user — or to a guest — for the same URL.
  String? _buildCacheKey(
    String method,
    String url, {
    required bool requireAuth,
    required String scope,
  }) {
    if (method.toUpperCase() != 'GET') return null;
    return '$url|scope=$scope|auth=$requireAuth';
  }

  Future<ApiResponse> _dispatchRequest(
    String method,
    String url, {
    Map<String, dynamic>? body,
    required Map<String, String> headers,
  }) async {
    final requestDispatcher = _requestDispatcher;
    if (requestDispatcher != null) {
      return requestDispatcher(
        method.toUpperCase(),
        url,
        body: body,
        headers: headers,
      ).timeout(Duration(seconds: _timeoutSeconds));
    }
    final abort = Completer<void>();
    final request = http.AbortableRequest(
      method.toUpperCase(),
      Uri.parse(url),
      abortTrigger: abort.future,
    )..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);
    return _sendRequest(request, abort);
  }

  Future<ApiResponse> _sendRequest(http.BaseRequest request, Completer<void> abort) async {
    _activeRequests.add(abort);
    try {
      final response = await _resolvedClient
          .send(request)
          .then(http.Response.fromStream)
          .timeout(
            Duration(seconds: _timeoutSeconds),
            onTimeout: () {
              if (!abort.isCompleted) abort.complete();
              throw TimeoutException('Request timed out');
            },
          );
      dynamic body;
      if (response.bodyBytes.isNotEmpty) {
        final contentType = response.headers['content-type']?.toLowerCase() ?? '';
        final isJson = contentType.contains('application/json') || contentType.contains('+json');
        try {
          body = isJson || contentType.isEmpty
              ? jsonDecode(utf8.decode(response.bodyBytes))
              : response.body;
        } on FormatException {
          if (response.statusCode >= 200 && response.statusCode < 300) {
            throw ApiException('The server returned invalid data.', code: 'MALFORMED_RESPONSE');
          }
          // Status errors still need their typed failure even when an upstream
          // proxy supplies HTML or invalid JSON. Never expose that body.
        }
      }
      return ApiResponse(statusCode: response.statusCode, body: body, headers: response.headers);
    } on http.RequestAbortedException {
      throw NetworkException('The request was cancelled.', code: 'CANCELLED');
    } on http.ClientException {
      throw NetworkException('The service could not be reached.', code: 'NETWORK_ERROR');
    } finally {
      _activeRequests.remove(abort);
    }
  }

  void _ensureCurrentRequest(String scope, int generation) {
    if (_closed || generation != _requestGeneration || scope != _authProvider.requestScope) {
      throw NetworkException('The request was cancelled.', code: 'CANCELLED');
    }
  }

  bool _shouldRetry({
    required String method,
    required Object error,
    required int attempt,
    bool idempotent = false,
  }) {
    final isGet = method.toUpperCase() == 'GET';
    // A server that asks for a longer wait than the backoff gets its wait:
    // surface the failure instead of retrying early.
    if (error is ServerException && (error.retryAfter ?? Duration.zero) > _maxRetryAfterWait) {
      return false;
    }
    // Non-idempotent mutations never retry. GETs and idempotent mutations use
    // RetryPolicy as the single source of truth for attempt budgets.
    if (!isGet && !idempotent) return false;
    final policy = isGet ? RetryPolicy.apiGet() : RetryPolicy.idempotentMutation();
    // Test seam: hard-cap GET retries when maxGetRetries was injected.
    final override = _maxGetRetriesOverride;
    if (isGet && override != null && attempt >= override) {
      return false;
    }
    // [attempt] is 0-based count of failures so far; RetryPolicy uses 1-based
    // "attempts already performed".
    return policy.shouldRetry(attempt + 1, error);
  }

  Future<void> _retryBackoffDelay(int attempt, {required String method}) async {
    // [attempt] is 1-based after increment in the request loop.
    final policy = method.toUpperCase() == 'GET'
        ? RetryPolicy.apiGet()
        : RetryPolicy.idempotentMutation();
    await Future.delayed(policy.delayForAttempt(attempt));
  }

  static String _normalizeBaseUrl(String baseUrl) {
    var normalized = baseUrl.trim();
    if (normalized.isEmpty) {
      return 'https://api.360ghar.com';
    }

    if (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }

    if (normalized.endsWith(ApiPaths.apiVersionPrefix)) {
      normalized = normalized.substring(0, normalized.length - ApiPaths.apiVersionPrefix.length);
    }

    return normalized;
  }

  fp.HttpMethod _methodToHttpMethod(String method) {
    switch (method.toUpperCase()) {
      case 'GET':
        return fp.HttpMethod.Get;
      case 'POST':
        return fp.HttpMethod.Post;
      case 'PUT':
        return fp.HttpMethod.Put;
      case 'DELETE':
        return fp.HttpMethod.Delete;
      case 'PATCH':
        return fp.HttpMethod.Patch;
      default:
        return fp.HttpMethod.Get;
    }
  }

  /// Retries wait at most this long; a longer `Retry-After` stops retrying.
  static const _maxRetryAfterWait = Duration(seconds: 1);

  /// The typed failure for a non-2xx [response]: the backend code and `details.fields` come from
  /// the error envelope, `Retry-After` from the headers. The assistant stream uses it too.
  static AppException mapHttpError(ApiResponse response) {
    final statusCode = response.statusCode;
    final error = ApiErrorBody.parse(response.body);
    final code = error?.code;
    final retryAfter = retryAfterOf(response.headers);

    if (statusCode == 401) {
      DebugLogger.error('🔐 Authentication failed: $statusCode');
      return AuthenticationException(
        'Your session has expired. Please sign in again.',
        code: code ?? AppException.unauthorizedCode,
        details: error?.details,
        statusCode: 401,
      );
    }

    if (statusCode == 403) {
      DebugLogger.error('🔐 Authorization denied: $statusCode');
      return AuthenticationException(
        'You do not have permission to access this resource.',
        code: code ?? 'FORBIDDEN',
        details: error?.details,
        statusCode: 403,
      );
    }

    if (statusCode == 429) {
      return RateLimitException(
        'Too many requests.',
        code: code,
        retryAfter: retryAfter ?? RateLimitException.defaultWait,
      );
    }

    if (statusCode == 422) {
      return ValidationException(
        'The request was not valid.',
        code: code ?? 'VALIDATION_ERROR',
        fieldErrors: error?.fieldErrors,
      );
    }

    if (statusCode >= 500) {
      return ServerException(
        'The service is temporarily unavailable.',
        code: code,
        statusCode: statusCode,
        retryAfter: retryAfter,
      );
    }

    if (statusCode >= 400) {
      return ApiException(
        'The request could not be completed.',
        code: code,
        statusCode: statusCode,
      );
    }

    return ApiException('The server returned an unexpected response.', statusCode: statusCode);
  }

  Future<void> _notifyUnauthorized(UnauthorizedEvent event) async {
    final callback = onUnauthorized;
    if (callback == null) return;

    final now = DateTime.now();
    final lastNotificationAt = _lastUnauthorizedNotificationAt;
    if (lastNotificationAt != null &&
        now.difference(lastNotificationAt) < _unauthorizedNotificationCooldown) {
      return;
    }

    _lastUnauthorizedNotificationAt = now;
    try {
      await callback(event);
    } catch (e, st) {
      DebugLogger.warning('🔐 Unauthorized handler failed', e, st);
    }
  }

  /// Reports a 401 that survived the token refresh, or a 403 `USER_INACTIVE`, that another
  /// transport saw (the assistant stream), so one handler ends the session for all of them.
  Future<void> reportUnauthorized(UnauthorizedEvent event) => _notifyUnauthorized(event);

  @visibleForTesting
  void resetUnauthorizedCooldown() => _lastUnauthorizedNotificationAt = null;

  /// Invalidates pending work before deleting cached responses. A late response
  /// can neither repopulate the cache nor update a subsequent account session.
  Future<void> clearCache() {
    cancelPendingRequests();
    return _etagCache?.clear() ?? Future<void>.value();
  }

  /// Called synchronously on an account transition before any new request.
  void cancelPendingRequests() {
    _requestGeneration++;
    _inflightGets.clear();
    for (final abort in _activeRequests) {
      if (!abort.isCompleted) abort.complete();
    }
    _activeRequests.clear();
  }

  /// The owning provider must call this when it is disposed. Injected HTTP
  /// clients transfer ownership to this instance and are closed exactly once.
  void close() {
    if (_closed) return;
    _closed = true;
    cancelPendingRequests();
    _client?.close();
  }
}

/// The backend error code from `{"error": {"code": ...}}`, if present.
@visibleForTesting
String? errorCodeOf(Object? body) => ApiErrorBody.parse(body)?.code;

/// 422 field errors from `{"error": {"details": {"fields": [{field, msg, type}]}}}`: the error
/// types by field name, without the `body.` or `query.` prefix. Messages stay in diagnostics;
/// forms show localized text for the type.
@visibleForTesting
Map<String, List<String>>? fieldErrorsOf(Object? body) => ApiErrorBody.parse(body)?.fieldErrors;

/// `Retry-After` as seconds or an HTTP date, clamped to 1 s to 10 min.
@visibleForTesting
Duration? retryAfterOf(Map<String, String> headers, {DateTime? now}) {
  final value = headers['retry-after'] ?? headers['Retry-After'];
  if (value == null || value.trim().isEmpty) return null;
  final Duration wait;
  final seconds = int.tryParse(value.trim());
  if (seconds != null) {
    wait = Duration(seconds: seconds);
  } else {
    try {
      wait = HttpDate.parse(value.trim()).difference(now ?? DateTime.now());
    } on HttpException {
      return null;
    } on FormatException {
      return null;
    }
  }
  if (wait < const Duration(seconds: 1)) return const Duration(seconds: 1);
  if (wait > const Duration(minutes: 10)) return const Duration(minutes: 10);
  return wait;
}
