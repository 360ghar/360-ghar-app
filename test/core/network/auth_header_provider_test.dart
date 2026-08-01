import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/network/auth_header_provider.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
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

    // -----------------------------------------------------------------------
    // Refresh failure classification.
    //
    // Only a demonstrable server rejection may look like a dead session (null
    // header → MISSING_AUTH_HEADER → sign-out). Every other failure is
    // transient and must surface as a NetworkException, because signing a user
    // out for losing signal is unrecoverable without a network.
    // -----------------------------------------------------------------------
    AuthHeaderProvider providerFailingWith(Object error) {
      final user = _testUser();
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final staleSession = _sessionWithExpiry(
        token: _jwtWithExp(now - 10, subject: user.id),
        user: user,
      );
      return AuthHeaderProvider(
        currentSessionProvider: () => staleSession,
        refreshSession: () async => throw error,
      );
    }

    test('returns null when the server rejects the refresh token', () async {
      // Password changed on another device: the real session-fatal case.
      final provider = providerFailingWith(
        const AuthApiException('Invalid Refresh Token', statusCode: '400'),
      );

      expect(await provider.getAuthHeader(), isNull);
    });

    for (final entry in <String, Object>{
      'transport failure': AuthRetryableFetchException(message: 'Failed host lookup'),
      'server 5xx': AuthRetryableFetchException(message: 'boom', statusCode: '503'),
      'raw timeout': TimeoutException('no route to host'),
      'captive portal (unparseable body)': AuthUnknownException(
        message: 'Failed to decode error response',
        originalError: 'Received an empty response with status code 511',
      ),
      'unknown error': Exception('something we have never seen'),
    }.entries) {
      test('throws a transient NetworkException on ${entry.key}', () async {
        final provider = providerFailingWith(entry.value);

        await expectLater(
          provider.getAuthHeader(),
          throwsA(
            isA<NetworkException>().having(
              (e) => e.code,
              'code',
              AuthHeaderProvider.refreshUnreachableCode,
            ),
          ),
        );
      });
    }

    test('concurrent callers on one coalesced refresh all see the transient error', () async {
      var refreshCalls = 0;
      final user = _testUser();
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final staleSession = _sessionWithExpiry(
        token: _jwtWithExp(now - 10, subject: user.id),
        user: user,
      );
      final provider = AuthHeaderProvider(
        currentSessionProvider: () => staleSession,
        refreshSession: () async {
          refreshCalls++;
          await Future<void>.delayed(const Duration(milliseconds: 25));
          throw AuthRetryableFetchException(message: 'Failed host lookup');
        },
      );

      final results = await Future.wait(
        List.generate(
          4,
          (_) => provider.getAuthHeader().then<Object?>((h) => h).catchError((Object e) => e),
        ),
      );

      expect(refreshCalls, 1, reason: 'the refresh must still coalesce');
      for (final result in results) {
        expect(result, isA<NetworkException>());
        expect((result! as NetworkException).code, AuthHeaderProvider.refreshUnreachableCode);
      }
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

    test('cachedAuthHeader returns the bearer header for a fresh session', () {
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

      expect(provider.cachedAuthHeader, {'Authorization': 'Bearer ${freshSession.accessToken}'});
      expect(refreshCalls, 0, reason: 'cachedAuthHeader must never refresh');
    });

    test('cachedAuthHeader returns null for a guest and never refreshes', () {
      var refreshCalls = 0;
      final provider = AuthHeaderProvider(
        currentSessionProvider: () => null,
        refreshSession: () async {
          refreshCalls++;
          throw Exception('refresh must not be attempted for a guest');
        },
      );

      expect(provider.cachedAuthHeader, isNull);
      expect(refreshCalls, 0);
    });

    test('cachedAuthHeader returns null for an expired session', () {
      final user = _testUser();
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final expiredSession = _sessionWithExpiry(
        token: _jwtWithExp(now - 10, subject: user.id),
        user: user,
      );

      final provider = AuthHeaderProvider(currentSessionProvider: () => expiredSession);

      expect(provider.cachedAuthHeader, isNull);
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
