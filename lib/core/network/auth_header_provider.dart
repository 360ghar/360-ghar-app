import 'dart:async';

import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provides authentication headers for API requests.
class AuthHeaderProvider {
  /// Error code on the [NetworkException] thrown when a session refresh could
  /// not reach the auth server. Transient: callers must not sign the user out.
  static const String refreshUnreachableCode = 'AUTH_REFRESH_UNREACHABLE';

  static const Duration _minTokenTtl = Duration(seconds: 45);

  final SupabaseClient? _supabaseClient;
  final Session? Function()? _currentSessionProvider;
  final Future<AuthResponse> Function()? _refreshSession;
  Future<Session?>? _refreshInFlight;

  AuthHeaderProvider({this._supabaseClient, this._currentSessionProvider, this._refreshSession});

  SupabaseClient get _supabase => _supabaseClient ?? Supabase.instance.client;

  /// Gets the current auth header if user is authenticated.
  ///
  /// Token lifecycle is managed by Supabase SDK. This provider reads and
  /// refreshes sessions when the token is stale or when [forceRefresh] is true.
  Future<Map<String, String>?> getAuthHeader({bool forceRefresh = false}) async {
    try {
      var session = _readCurrentSession();
      final isFresh = _isTokenFresh(session);

      if (forceRefresh || !isFresh) {
        final refreshed = await _refreshSessionCoalesced();
        if (refreshed != null) {
          session = refreshed;
        }
      }

      final token = session?.accessToken;
      final expiresIn = _sessionExpiresInSeconds(session);

      if (token == null || token.isEmpty) {
        DebugLogger.debug(
          '🔑 AuthHeaderProvider: No access token available '
          '(forceRefresh requested: $forceRefresh, expiresIn: ${expiresIn ?? 'unknown'}s)',
        );
        return null;
      }

      if (!_isTokenFresh(session)) {
        DebugLogger.warning(
          '🔑 AuthHeaderProvider: Token is stale after refresh attempt '
          '(expiresIn: ${expiresIn ?? 'unknown'}s).',
        );
        return null;
      }

      DebugLogger.debug(
        '🔑 AuthHeaderProvider: Token retrieved '
        '(expiresIn: ${expiresIn ?? 'unknown'}s)',
      );

      return {'Authorization': 'Bearer $token'};
    } on NetworkException {
      // The refresh could not reach the server. Never downgrade this to "no
      // header available" — that reads as a dead session and signs the user out
      // for losing signal.
      rethrow;
    } catch (e, stackTrace) {
      DebugLogger.error('🔑 Failed to get auth header: $e', e, stackTrace);
      return null;
    }
  }

  /// Stable scope for request deduplication. Anonymous and authenticated
  /// sessions must never share an in-flight response, and different users
  /// must not receive each other's response.
  String get requestScope {
    try {
      final session = _readCurrentSession();
      final userId = session?.user.id;
      if (userId == null || userId.isEmpty) return 'anonymous';
      return 'user:$userId';
    } catch (_) {
      return 'unknown';
    }
  }

  /// The auth header for the session already in memory, or null when there is
  /// no usable one. Never refreshes and never awaits, so optional-auth requests
  /// can enrich themselves for signed-in users without dragging anonymous
  /// callers through a doomed `refreshSession()`.
  Map<String, String>? get cachedAuthHeader {
    try {
      final session = _readCurrentSession();
      if (!_isTokenFresh(session)) return null;
      return {'Authorization': 'Bearer ${session!.accessToken}'};
    } catch (e, stackTrace) {
      DebugLogger.warning('🔑 Failed to read cached auth header', e, stackTrace);
      return null;
    }
  }

  Session? _readCurrentSession() {
    final sessionProvider = _currentSessionProvider;
    if (sessionProvider != null) {
      return sessionProvider();
    }
    return _supabase.auth.currentSession;
  }

  bool _isTokenFresh(Session? session) {
    final token = session?.accessToken;
    if (token == null || token.isEmpty) return false;

    final expiresIn = _sessionExpiresInSeconds(session);
    if (expiresIn == null) {
      // Some SDK/session variants may not expose expiry; treat as usable.
      return true;
    }
    return expiresIn > _minTokenTtl.inSeconds;
  }

  int? _sessionExpiresInSeconds(Session? session) {
    final expiresAt = session?.expiresAt;
    if (expiresAt == null) return null;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return expiresAt - now;
  }

  Future<Session?> _refreshSessionCoalesced() {
    final inFlight = _refreshInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    Future<Session?>? future;
    future = _performRefreshSession().whenComplete(() {
      if (identical(_refreshInFlight, future)) {
        _refreshInFlight = null;
      }
    });

    _refreshInFlight = future;
    return future;
  }

  Future<Session?> _performRefreshSession() async {
    // Nothing to refresh. A signed-out user must get "no header available",
    // not a pointless round trip that could be misread as a transient failure.
    if (_readCurrentSession() == null) return null;

    try {
      DebugLogger.debug('🔑 AuthHeaderProvider: Refreshing Supabase session');
      final refreshSession = _refreshSession;
      final response = refreshSession != null
          ? await refreshSession()
          : await _supabase.auth.refreshSession();
      final refreshed = response.session ?? _readCurrentSession();
      final expiresIn = _sessionExpiresInSeconds(refreshed);
      DebugLogger.debug(
        '🔑 AuthHeaderProvider: Session refresh completed '
        '(expiresIn: ${expiresIn ?? 'unknown'}s)',
      );
      return refreshed;
    } catch (e, stackTrace) {
      if (!_isRefreshRejection(e)) {
        DebugLogger.warning(
          '🔑 AuthHeaderProvider: Session refresh could not reach the server',
          e,
          stackTrace,
        );
        throw NetworkException(
          'Could not reach the authentication service.',
          code: refreshUnreachableCode,
          details: e.toString(),
        );
      }
      DebugLogger.warning('🔑 AuthHeaderProvider: Refresh token rejected', e, stackTrace);
      return _readCurrentSession();
    }
  }

  /// True only when the auth server demonstrably rejected the refresh token
  /// (revoked, expired, password changed elsewhere) — the session is dead.
  ///
  /// Everything else is treated as transient, deliberately erring toward
  /// keeping the user signed in: signed-in-but-degraded recovers with a pull to
  /// refresh, signed-out with no network cannot re-authenticate at all.
  ///   - [AuthRetryableFetchException] — gotrue wraps transport failures and
  ///     5xx responses in this (see gotrue `fetch.dart`), so it covers
  ///     SocketException / TimeoutException / ClientException.
  ///   - [AuthUnknownException] — a non-2xx whose body would not parse, which
  ///     is exactly what a captive portal's HTML error page produces.
  ///   - Any non-[AuthException] (a raw socket or timeout error thrown before
  ///     gotrue's fetch layer) is unclassifiable, so transient.
  static bool _isRefreshRejection(Object error) =>
      error is AuthException &&
      error is! AuthRetryableFetchException &&
      error is! AuthUnknownException;
}
