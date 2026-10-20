import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/network/auth_header_provider.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ApiClient 401 retry after forced refresh', () {
    UnauthorizedHandler? onUnauthorized;
    tearDown(() {
      onUnauthorized = null;
    });

    test(
      'retries once with forced refresh and avoids unauthorized callback when retry succeeds',
      () async {
        final user = _testUser();
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final oldToken = _jwtWithExp(now + 3600, subject: user.id, marker: 'token-old');
        final newToken = _jwtWithExp(now + 7200, subject: user.id, marker: 'token-new');

        var session = _sessionWithToken(token: oldToken, user: user);
        final refreshedSession = _sessionWithToken(token: newToken, user: user);

        var refreshCalls = 0;
        final authProvider = AuthHeaderProvider(
          currentSessionProvider: () => session,
          refreshSession: () async {
            refreshCalls++;
            session = refreshedSession;
            return AuthResponse(session: refreshedSession);
          },
        );

        var requestCount = 0;

        var unauthorizedCallbacks = 0;
        onUnauthorized = (_) async {
          unauthorizedCallbacks++;
        };

        final client = ApiClient(
          baseUrl: 'http://localhost:9999',
          authProvider: authProvider,
          requestDispatcher:
              (
                String method,
                String url, {
                Map<String, dynamic>? body,
                required Map<String, String> headers,
              }) async {
                requestCount++;
                final authHeader = headers['Authorization'] ?? '';
                final isRetriedWithFreshToken = authHeader == 'Bearer $newToken';

                if (isRetriedWithFreshToken) {
                  return const ApiResponse(
                    statusCode: 200,
                    body: <String, dynamic>{'ok': true},
                    headers: <String, String>{'content-type': 'application/json'},
                  );
                }

                return const ApiResponse(
                  statusCode: 401,
                  body: <String, dynamic>{'detail': 'unauthorized'},
                  headers: <String, String>{'content-type': 'application/json'},
                );
              },
          enablePerformanceMetrics: false,
          maxGetRetries: 0,
        )..onUnauthorized = onUnauthorized;

        final response = await client.get('/users/profile', useCache: false, requireAuth: true);

        expect(response.statusCode, 200);
        expect(requestCount, 2);
        expect(refreshCalls, 1);
        expect(unauthorizedCallbacks, 0);
      },
    );

    test(
      'refresh-unreachable during a 401 retry fails fast without retrying or signing out',
      () async {
        final user = _testUser();
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        // Token is fresh, so the initial header build does not refresh; only
        // the 401-triggered forced refresh hits the (unreachable) auth server.
        final oldToken = _jwtWithExp(now + 3600, subject: user.id, marker: 'token-old');
        final session = _sessionWithToken(token: oldToken, user: user);

        final authProvider = AuthHeaderProvider(
          currentSessionProvider: () => session,
          refreshSession: () async {
            throw NetworkException('could not reach auth server');
          },
        );

        var requestCount = 0;
        var unauthorizedCallbacks = 0;
        onUnauthorized = (_) async {
          unauthorizedCallbacks++;
        };

        final client = ApiClient(
          baseUrl: 'http://localhost:9999',
          authProvider: authProvider,
          requestDispatcher:
              (
                String method,
                String url, {
                Map<String, dynamic>? body,
                required Map<String, String> headers,
              }) async {
                requestCount++;
                return const ApiResponse(
                  statusCode: 401,
                  body: <String, dynamic>{'detail': 'unauthorized'},
                  headers: <String, String>{'content-type': 'application/json'},
                );
              },
          enablePerformanceMetrics: false,
          // Generous budget on purpose: the point is that NOTHING is retried
          // with the stale token once the forced refresh could not reach the
          // auth server.
          maxGetRetries: 3,
        )..onUnauthorized = onUnauthorized;

        await expectLater(
          client.get('/users/profile', useCache: false, requireAuth: true),
          throwsA(
            isA<NetworkException>().having(
              (e) => e.code,
              'code',
              AuthHeaderProvider.refreshUnreachableCode,
            ),
          ),
        );

        expect(requestCount, 1, reason: 'must not retry with the stale token');
        expect(unauthorizedCallbacks, 0, reason: 'unreachable refresh must not sign out');
      },
    );
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

Session _sessionWithToken({required String token, required User user}) {
  return Session(
    accessToken: token,
    refreshToken: 'refresh-token',
    tokenType: 'bearer',
    user: user,
  );
}

String _jwtWithExp(int exp, {required String subject, required String marker}) {
  final header = base64Url.encode(utf8.encode('{"alg":"HS256","typ":"JWT"}')).replaceAll('=', '');
  final payloadMap = <String, dynamic>{'sub': subject, 'exp': exp, 'marker': marker};
  final payload = base64Url.encode(utf8.encode(jsonEncode(payloadMap))).replaceAll('=', '');
  return '$header.$payload.signature';
}
