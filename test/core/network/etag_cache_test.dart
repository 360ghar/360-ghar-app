import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ghar360/core/network/api_response.dart';
import 'package:ghar360/core/network/etag_cache.dart';
import 'package:ghar360/core/storage/app_database.dart';

void main() {
  late Directory directory;
  late AppDatabase database;
  late StorageScope scope;
  late ETagCache cache;

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('ghar360-etag-test-');
    database = await AppDatabase.open(
      factory: databaseFactoryFfi,
      databasePath: '${directory.path}/cache.db',
      legacyReader: () async => {},
    );
    scope = database.activateScope(environment: 'https://api.example.com', accountId: 'account-a');
    cache = ETagCache(database: database, scope: () => scope);
  });
  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  const response = ApiResponse(statusCode: 200, body: {'ok': true}, headers: {'etag': 'W/"abc"'});

  test('missing entry is absent', () async {
    expect(await cache.read('missing', scope: scope), isNull);
  });

  test('stores ETag and decoded body with explicit freshness and expiry', () async {
    await cache.cacheResponse('key', response, scope: scope);
    final entry = (await cache.read('key', scope: scope))!;
    expect(entry.etag, 'W/"abc"');
    expect(entry.value, {'ok': true});
    expect(entry.schemaVersion, AppDatabase.cacheSchemaVersion);
    expect(entry.freshUntil.difference(entry.createdAt), ETagCache.freshFor);
    expect(entry.expiresAt.difference(entry.freshUntil), ETagCache.retainFor - ETagCache.freshFor);
  });

  test('stored response survives database reopen', () async {
    await cache.cacheResponse('key', response, scope: scope);
    await database.close();
    database = await AppDatabase.open(
      factory: databaseFactoryFfi,
      databasePath: '${directory.path}/cache.db',
      legacyReader: () async => {},
    );
    scope = database.activateScope(environment: 'https://api.example.com', accountId: 'account-a');
    cache = ETagCache(database: database, scope: () => scope);
    expect((await cache.read('key', scope: scope))?.value, {'ok': true});
  });

  test('expired entry is not returned', () async {
    final now = DateTime.now();
    await database.writeCache(
      scope: scope,
      key: 'key',
      value: {'ok': true},
      etag: 'old',
      freshUntil: now.subtract(const Duration(hours: 25)),
      expiresAt: now.subtract(const Duration(hours: 24)),
    );
    expect(await cache.read('key', scope: scope), isNull);
  });

  test('stale entry remains available for server revalidation until expiry', () async {
    final now = DateTime.now();
    await database.writeCache(
      scope: scope,
      key: 'key',
      value: {'ok': true},
      etag: 'old',
      freshUntil: now.subtract(const Duration(minutes: 1)),
      expiresAt: now.add(const Duration(hours: 1)),
    );
    final entry = (await cache.read('key', scope: scope))!;
    expect(entry.isStaleAt(now), isTrue);
    expect(entry.etag, 'old');
  });

  for (final headers in [
    <String, String>{},
    {'etag': ''},
  ]) {
    test('skips response without usable ETag: $headers', () async {
      await cache.cacheResponse(
        'key',
        ApiResponse(statusCode: 200, body: {'ok': true}, headers: headers),
        scope: scope,
      );
      expect(await cache.read('key', scope: scope), isNull);
    });
  }

  for (final body in [null, '']) {
    test('skips empty body: $body', () async {
      await cache.cacheResponse(
        'key',
        ApiResponse(statusCode: 200, body: body, headers: {'etag': 'valid'}),
        scope: scope,
      );
      expect(await cache.read('key', scope: scope), isNull);
    });
  }

  for (final name in ['etag', 'ETag', 'ETAG']) {
    test('ETag header matching is case insensitive: $name', () async {
      await cache.cacheResponse(
        'key',
        ApiResponse(statusCode: 200, body: {'ok': true}, headers: {name: 'valid'}),
        scope: scope,
      );
      expect((await cache.read('key', scope: scope))?.etag, 'valid');
    });
  }

  test('overwrites the old response for the same scoped key', () async {
    await cache.cacheResponse('key', response, scope: scope);
    await cache.cacheResponse(
      'key',
      const ApiResponse(statusCode: 200, body: {'version': 2}, headers: {'etag': 'new'}),
      scope: scope,
    );
    final entry = (await cache.read('key', scope: scope))!;
    expect(entry.etag, 'new');
    expect(entry.value, {'version': 2});
  });

  test('preserves text response type across persistence', () async {
    await cache.cacheResponse(
      'key',
      const ApiResponse(statusCode: 200, body: '<main>Widget</main>', headers: {'etag': 'html'}),
      scope: scope,
    );
    expect((await cache.read('key', scope: scope))?.value, '<main>Widget</main>');
  });

  test('accounts and environments cannot read each other\'s responses', () async {
    await cache.cacheResponse('key', response, scope: scope);
    scope = database.activateScope(environment: 'https://api.example.com', accountId: 'account-b');
    expect(await cache.read('key', scope: scope), isNull);
    scope = database.activateScope(
      environment: 'https://staging.example.com',
      accountId: 'account-a',
    );
    expect(await cache.read('key', scope: scope), isNull);
  });

  test('old account lease cannot write after an account transition', () async {
    final oldScope = scope;
    scope = database.activateScope(environment: 'https://api.example.com', accountId: 'account-b');
    await expectLater(
      cache.cacheResponse('key', response, scope: oldScope),
      throwsA(isA<StorageFailure>().having((error) => error.code, 'code', 'STORAGE_SCOPE_CHANGED')),
    );
    expect(await cache.read('key', scope: scope), isNull);
  });

  test('clear removes every response while retaining preferences', () async {
    await database.writePreference('language_code', 'hi');
    await cache.cacheResponse('one', response, scope: scope);
    await cache.cacheResponse('two', response, scope: scope);
    await cache.clear();
    expect(await cache.read('one', scope: scope), isNull);
    expect(await cache.read('two', scope: scope), isNull);
    expect(database.readPreference<String>('language_code'), 'hi');
  });

  test('clear succeeds when cache is empty', () async {
    await expectLater(cache.clear(), completes);
  });

  test('storage write failure is explicit and cannot report persisted data', () async {
    await database.close();
    await expectLater(
      cache.cacheResponse('key', response, scope: scope),
      throwsA(isA<StorageFailure>()),
    );
  });

  group('Cache-Control: no-store', () {
    for (final header in [
      'no-store',
      'private, no-store',
      'No-Store, max-age=0',
      'public,no-store',
    ]) {
      test('a response marked "$header" is never stored', () async {
        await cache.cacheResponse(
          'key',
          ApiResponse(
            statusCode: 200,
            body: {'ok': true},
            headers: {'etag': 'W/"abc"', 'cache-control': header},
          ),
          scope: scope,
        );
        expect(await cache.read('key', scope: scope), isNull);
      });
    }

    test('the header name is matched without case', () async {
      await cache.cacheResponse(
        'key',
        const ApiResponse(
          statusCode: 200,
          body: {'ok': true},
          headers: {'ETag': 'W/"abc"', 'Cache-Control': 'private, no-store'},
        ),
        scope: scope,
      );
      expect(await cache.read('key', scope: scope), isNull);
    });

    test('a no-store response deletes the row stored for the key before', () async {
      await cache.cacheResponse('key', response, scope: scope);
      expect(await cache.read('key', scope: scope), isNotNull);

      await cache.cacheResponse(
        'key',
        const ApiResponse(
          statusCode: 200,
          body: {'ok': false},
          headers: {'etag': 'W/"next"', 'cache-control': 'private, no-store'},
        ),
        scope: scope,
      );

      expect(await cache.read('key', scope: scope), isNull);
    });

    test('other Cache-Control directives still store the response', () async {
      await cache.cacheResponse(
        'key',
        const ApiResponse(
          statusCode: 200,
          body: {'ok': true},
          headers: {'etag': 'W/"abc"', 'cache-control': 'private, max-age=60'},
        ),
        scope: scope,
      );
      expect(await cache.read('key', scope: scope), isNotNull);
    });

    test('isNoStore reads the directive list', () {
      expect(ETagCache.isNoStore({'Cache-Control': 'private, no-store'}), isTrue);
      expect(ETagCache.isNoStore({'cache-control': 'no-cache'}), isFalse);
      expect(ETagCache.isNoStore({'cache-control': 'no-store-ish'}), isFalse);
      expect(ETagCache.isNoStore(const {}), isFalse);
    });
  });

  group('schema version', () {
    test('a row written under an older cache schema reads as a miss', () async {
      final now = DateTime.now();
      await database.writeCache(
        scope: scope,
        key: 'key',
        value: {'ok': true},
        etag: 'old-shape',
        freshUntil: now.add(const Duration(minutes: 5)),
        expiresAt: now.add(const Duration(hours: 1)),
        schemaVersion: AppDatabase.cacheSchemaVersion - 1,
      );
      expect(await cache.read('key', scope: scope), isNull);
    });

    test('the current schema version reads back', () async {
      await cache.cacheResponse('key', response, scope: scope);
      expect(
        (await cache.read('key', scope: scope))?.schemaVersion,
        AppDatabase.cacheSchemaVersion,
      );
    });
  });

  group('account scope', () {
    test('one account never reads the row of another for the same key', () async {
      await cache.cacheResponse('key', response, scope: scope);
      final other = database.activateScope(
        environment: 'https://api.example.com',
        accountId: 'account-b',
      );

      expect(await cache.read('key', scope: other), isNull);
    });
  });
}
