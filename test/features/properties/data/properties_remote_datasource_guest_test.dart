import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/network/auth_header_provider.dart';
import 'package:ghar360/features/properties/data/datasources/properties_remote_datasource.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ({PropertiesRemoteDatasource datasource, ApiClient client, List<Map<String, String>> sent}) build(
    Session? session,
  ) {
    final sent = <Map<String, String>>[];
    final client = ApiClient(
      baseUrl: 'http://localhost:9999',
      authProvider: AuthHeaderProvider(currentSessionProvider: () => session),
      requestDispatcher:
          (
            String method,
            String url, {
            Map<String, dynamic>? body,
            required Map<String, String> headers,
          }) async {
            sent.add(headers);
            return const ApiResponse(
              statusCode: 200,
              body: <String, dynamic>{
                'items': <Object>[],
                'limit': 20,
                'next_cursor': null,
                'has_more': false,
                'total': 0,
              },
              headers: <String, String>{'content-type': 'application/json'},
            );
          },
      enablePerformanceMetrics: false,
      maxGetRetries: 0,
    );
    return (datasource: PropertiesRemoteDatasource(client), client: client, sent: sent);
  }

  test('a guest searches and fetches with no Authorization header and no error', () async {
    final h = build(null);
    expect(h.client.signedIn, false);
    await h.datasource.fetchProperties(
      latitude: 28.6,
      longitude: 77.2,
      radiusKm: 10,
      filters: const UnifiedFilterModel(),
      useCache: false,
    );
    await h.datasource.searchProperties(query: 'dlf', useCache: false);
    expect(h.sent, hasLength(2));
    expect(h.sent.every((headers) => !headers.containsKey('Authorization')), isTrue);
  });

  test('a signed-in user still sends the token', () async {
    final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
    String part(Object value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    final token = '${part({'alg': 'HS256'})}.${part({'sub': 'user-1', 'exp': exp})}.sig';
    final h = build(
      Session(
        accessToken: token,
        refreshToken: 'r',
        tokenType: 'bearer',
        user: const User(
          id: 'user-1',
          appMetadata: <String, dynamic>{},
          userMetadata: <String, dynamic>{},
          aud: 'authenticated',
          createdAt: '2025-01-01T00:00:00.000Z',
        ),
      ),
    );
    expect(h.client.signedIn, true);
    await h.datasource.searchProperties(query: 'dlf', useCache: false);
    expect(h.sent.single['Authorization'], 'Bearer $token');
  });
}
