import 'dart:async';

import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provides authentication headers for API requests.
class AuthHeaderProvider {
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

      // Log token details for debugging (only partial token for security)
      final tokenSuffix = token.length > 8 ? token.substring(token.length - 8) : token;

      DebugLogger.debug(
        '🔑 AuthHeaderProvider: Token retrieved '
        '(length: ${token.length}, suffix: ...$tokenSuffix, '
        'expiresIn: ${expiresIn ?? 'unknown'}s)',
      );

      return {'Authorization': 'Bearer $token'};
    } catch (e, stackTrace) {
      DebugLogger.error('🔑 Failed to get auth header: $e', e, stackTrace);
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
      DebugLogger.warning('🔑 AuthHeaderProvider: Session refresh failed', e, stackTrace);
      return _readCurrentSession();
    }
  }
}
