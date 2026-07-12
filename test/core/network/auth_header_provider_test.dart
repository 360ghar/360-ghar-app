import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/network/auth_header_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('AuthHeaderProvider', () {
    test('refreshes stale token and returns fresh bearer header', () async {
      final user = _testUser();
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      var currentSession = _sessionWithExpiry(
        token: _jwtWithExp(now - 60, subject: user.id),
        user: user,
      );
      final refreshedSession = _sessionWithExpiry(
        token: _jwtWithExp(now + 3600, subject: user.id),
        user: user,
      );

      var refreshCalls = 0;
      final provider = AuthHeaderProvider(
        currentSessionProvider: () => currentSession,
        refreshSession: () async {
          refreshCalls++;
          currentSession = refreshedSession;
          return AuthResponse(session: refreshedSession);
        },
      );

      final header = await provider.getAuthHeader();

      expect(refreshCalls, 1);
      expect(header, isNotNull);
      expect(header!['Authorization'], equals('Bearer ${refreshedSession.accessToken}'));
    });

    test('returns null when refresh fails and token remains stale', () async {
      final user = _testUser();
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final staleSession = _sessionWithExpiry(
        token: _jwtWithExp(now - 10, subject: user.id),
        user: user,
      );

      final provider = AuthHeaderProvider(
        currentSessionProvider: () => staleSession,
        refreshSession: () async => throw Exception('refresh failed'),
      );

      final header = await provider.getAuthHeader();

      expect(header, isNull);
    });

    test('coalesces concurrent refreshes into one request', () async {
      final user = _testUser();
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      var currentSession = _sessionWithExpiry(
        token: _jwtWithExp(now - 60, subject: user.id),
        user: user,
      );
      final refreshedSession = _sessionWithExpiry(
        token: _jwtWithExp(now + 3600, subject: user.id),
        user: user,
      );

      var refreshCalls = 0;
      final provider = AuthHeaderProvider(
        currentSessionProvider: () => currentSession,
        refreshSession: () async {
          refreshCalls++;
          await Future<void>.delayed(const Duration(milliseconds: 25));
          currentSession = refreshedSession;
          return AuthResponse(session: refreshedSession);
        },
      );

      final results = await Future.wait([provider.getAuthHeader(), provider.getAuthHeader()]);

      expect(refreshCalls, 1);
      expect(results[0]?['Authorization'], equals('Bearer ${refreshedSession.accessToken}'));
      expect(results[1]?['Authorization'], equals('Bearer ${refreshedSession.accessToken}'));
    });

    test('returns fresh header without refreshing when token is fresh', () async {
      final user = _testUser();
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final freshSession = _sessionWithExpiry(
        token: _jwtWithExp(now + 3600, subject: user.id),
        user: user,
      );

      var refreshCalls = 0;
      final provider = AuthHeaderProvider(
        currentSessionProvider: () => freshSession,
        refreshSession: () async {
          refreshCalls++;
          return AuthResponse(session: freshSession);
        },
      );

      final header = await provider.getAuthHeader();

      expect(refreshCalls, 0);
      expect(header, isNotNull);
      expect(header!['Authorization'], 'Bearer ${freshSession.accessToken}');
    });

    test('returns null when session is null and no refresh configured', () async {
      final provider = AuthHeaderProvider(currentSessionProvider: () => null);

      final header = await provider.getAuthHeader();

      expect(header, isNull);
    });

    test('returns null when access token is empty', () async {
      final user = _testUser();
      final session = _sessionWithExpiry(token: '', user: user);

      final provider = AuthHeaderProvider(
        currentSessionProvider: () => session,
        refreshSession: () async => AuthResponse(session: session),
      );

      final header = await provider.getAuthHeader();

      expect(header, isNull);
    });

    test('forceRefresh triggers refresh even when token is fresh', () async {
      final user = _testUser();
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final freshSession = _sessionWithExpiry(
        token: _jwtWithExp(now + 3600, subject: user.id),
        user: user,
      );
      final newerSession = _sessionWithExpiry(
        token: _jwtWithExp(now + 7200, subject: user.id),
        user: user,
      );

      var currentSession = freshSession;
      var refreshCalls = 0;
      final provider = AuthHeaderProvider(
        currentSessionProvider: () => currentSession,
        refreshSession: () async {
          refreshCalls++;
          currentSession = newerSession;
          return AuthResponse(session: newerSession);
        },
      );

      final header = await provider.getAuthHeader(forceRefresh: true);

      expect(refreshCalls, 1);
      expect(header!['Authorization'], 'Bearer ${newerSession.accessToken}');
    });

    test('returns null when refresh returns a still-stale session', () async {
      final user = _testUser();
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final staleSession = _sessionWithExpiry(
        token: _jwtWithExp(now - 60, subject: user.id),
        user: user,
      );

      final provider = AuthHeaderProvider(
        currentSessionProvider: () => staleSession,
        refreshSession: () async => AuthResponse(session: staleSession),
      );

      final header = await provider.getAuthHeader();

      expect(header, isNull);
    });

    test('treats session without expiry as fresh (no expiresAt)', () async {
      final user = _testUser();
      // Session with no expiresAt — _sessionExpiresInSeconds returns null and
      // _isTokenFresh treats null expiry as usable.
      final session = Session(
        accessToken: 'no-expiry-token',
        refreshToken: 'refresh',
        tokenType: 'bearer',
        user: user,
      );

      var refreshCalls = 0;
      final provider = AuthHeaderProvider(
        currentSessionProvider: () => session,
        refreshSession: () async {
          refreshCalls++;
          return AuthResponse(session: session);
        },
      );

      final header = await provider.getAuthHeader();

      expect(refreshCalls, 0);
      expect(header, isNotNull);
      expect(header!['Authorization'], 'Bearer no-expiry-token');
    });

    test('refresh failure falls back to current session which may be null', () async {
      final provider = AuthHeaderProvider(
        currentSessionProvider: () => null,
        refreshSession: () async => throw Exception('refresh failed'),
      );

      final header = await provider.getAuthHeader();

      expect(header, isNull);
    });

    test('returns null when getAuthHeader throws internally (caught)', () async {
      // A session provider that throws is caught by the try/catch in
      // getAuthHeader, returning null instead of propagating.
      final provider = AuthHeaderProvider(
        currentSessionProvider: () => throw StateError('boom'),
        refreshSession: () async => throw StateError('refresh boom'),
      );

      final header = await provider.getAuthHeader();

      expect(header, isNull);
    });

    test('clears in-flight refresh future after completion', () async {
      final user = _testUser();
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      var currentSession = _sessionWithExpiry(
        token: _jwtWithExp(now - 60, subject: user.id),
        user: user,
      );
      final refreshedSession = _sessionWithExpiry(
        token: _jwtWithExp(now + 3600, subject: user.id),
        user: user,
      );

      var refreshCalls = 0;
      final provider = AuthHeaderProvider(
        currentSessionProvider: () => currentSession,
        refreshSession: () async {
          refreshCalls++;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          currentSession = refreshedSession;
          return AuthResponse(session: refreshedSession);
        },
      );

      // First call triggers a refresh.
      await provider.getAuthHeader();
      // Second call (now fresh) should NOT trigger another refresh because the
      // in-flight future was cleared and the session is now fresh.
      await provider.getAuthHeader();

      expect(refreshCalls, 1);
    });
  });
}

User _testUser() {
  return const User(
    id: 'user-1',
    appMetadata: <String, dynamic>{},
    userMetadata: <String, dynamic>{},
    aud: 'authenticated',
    createdAt: '2025-01-01T00:00:00.000Z',
  );
}

Session _sessionWithExpiry({required String token, required User user}) {
  return Session(
    accessToken: token,
    refreshToken: 'refresh-token',
    tokenType: 'bearer',
    user: user,
  );
}

String _jwtWithExp(int exp, {required String subject}) {
  final header = base64Url.encode(utf8.encode('{"alg":"HS256","typ":"JWT"}')).replaceAll('=', '');
  final payloadMap = <String, dynamic>{'sub': subject, 'exp': exp};
  final payload = base64Url.encode(utf8.encode(jsonEncode(payloadMap))).replaceAll('=', '');
  return '$header.$payload.signature';
}
