import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late AppDatabase database;
  late ProviderContainer container;
  late StreamController<AuthState> events;
  late MockSupabaseClient supabase;
  late MockGoTrueClient auth;
  late Session? session;
  late HttpServer server;

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    database = await AppDatabase.open(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
      legacyReader: () async => {},
    );
    events = StreamController<AuthState>.broadcast(sync: true);
    session = _session('account-a');
    auth = MockGoTrueClient();
    supabase = MockSupabaseClient();
    when(() => supabase.auth).thenReturn(auth);
    when(() => auth.currentUser).thenAnswer((_) => session?.user);
    when(() => auth.currentSession).thenAnswer((_) => session);
    when(() => auth.onAuthStateChange).thenAnswer((_) => events.stream);
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        supabaseClientProvider.overrideWithValue(supabase),
        apiBaseUrlProvider.overrideWithValue('http://${server.address.host}:${server.port}'),
      ],
      retry: (_, _) => null,
    );
  });
  tearDown(() async {
    container.dispose();
    await events.close();
    await server.close(force: true);
    await database.close();
  });

  void transition(String? accountId, AuthChangeEvent event) {
    session = accountId == null ? null : _session(accountId);
    events.add(AuthState(event, session));
  }

  test('token refresh retains scope and both transport instances', () {
    final scope = container.read(storageScopeProvider);
    final api = container.read(apiClientProvider);
    final sse = container.read(sseClientProvider);
    transition('account-a', AuthChangeEvent.tokenRefreshed);
    expect(container.read(storageScopeProvider), same(scope));
    expect(container.read(apiClientProvider), same(api));
    expect(container.read(sseClientProvider), same(sse));
  });

  test('A to B to A changes reject the original account lease', () async {
    final original = container.read(storageScopeProvider);
    transition('account-b', AuthChangeEvent.signedIn);
    expect(container.read(storageScopeProvider).accountId, 'account-b');
    transition('account-a', AuthChangeEvent.signedIn);
    final current = container.read(storageScopeProvider);
    expect(current.key, original.key);
    expect(current, isNot(same(original)));
    await expectLater(
      database.readCache(scope: original, key: 'key'),
      throwsA(isA<StorageFailure>().having((error) => error.code, 'code', 'STORAGE_SCOPE_CHANGED')),
    );
  });

  test('account transition immediately aborts an active HTTP request', () async {
    final started = Completer<void>();
    server.listen((request) {
      started.complete();
    });
    final api = container.read(apiClientProvider);
    final response = api.get('/properties', useCache: false);
    final assertion = expectLater(
      response,
      throwsA(isA<NetworkException>().having((error) => error.code, 'code', 'CANCELLED')),
    );
    await started.future;
    transition(null, AuthChangeEvent.signedOut);
    expect(container.read(apiClientProvider), same(api));
    await assertion;
    expect(container.read(storageScopeProvider).accountId, isNull);
  });

  test('scope disposal closes transports and removes the auth subscription', () async {
    final api = container.read(apiClientProvider);
    final sse = container.read(sseClientProvider);
    expect(events.hasListener, isTrue);
    container.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(events.hasListener, isFalse);
    await expectLater(
      api.get('/properties', useCache: false),
      throwsA(isA<NetworkException>().having((error) => error.code, 'code', 'CANCELLED')),
    );
    expect(await sse.postStream('/chat', body: {}).toList(), isEmpty);
  });

  test('account transition closes SSE without delivering old conversation data', () async {
    final started = Completer<void>();
    server.listen((request) async {
      request.response.headers.contentType = ContentType('text', 'event-stream');
      request.response.write(': open\n\n');
      await request.response.flush();
      started.complete();
    });
    final sse = container.read(sseClientProvider);
    final result = sse.postStream('/chat', body: {'message': 'hello'}).toList();
    await started.future;
    transition('account-b', AuthChangeEvent.signedIn);
    expect(await result, isEmpty);
    expect(container.read(sseClientProvider), same(sse));
  });

  test('ETag provider persists only inside the current account scope', () async {
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      request.response.headers.set('etag', 'version-1');
      request.response.write('{"value":"account-a"}');
      await request.response.close();
    });
    final api = container.read(apiClientProvider);
    final result = await api.get('/properties');
    expect(result.body, {'value': 'account-a'});
    final cache = container.read(etagCacheProvider);
    final original = cache.scope;
    transition('account-b', AuthChangeEvent.signedIn);
    await expectLater(cache.read('any', scope: original), throwsA(isA<StorageFailure>()));
  });
}

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

Session _session(String accountId) {
  final payload = base64Url
      .encode(
        utf8.encode(jsonEncode({'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})),
      )
      .replaceAll('=', '');
  return Session(
    accessToken: 'header.$payload.signature',
    tokenType: 'bearer',
    user: User(
      id: accountId,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-01-01T00:00:00Z',
    ),
  );
}
