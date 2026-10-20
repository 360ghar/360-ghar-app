import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/core/storage/legacy_storage.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory directory;
  late String databasePath;
  late AppDatabase database;
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('ghar360-storage-test-');
    databasePath = path.join(directory.path, 'test.db');
    database = await AppDatabase.open(
      factory: databaseFactoryFfi,
      databasePath: databasePath,
      legacyReader: () async => {},
    );
  });
  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  Future<AppDatabase> reopen({LegacyStorageReader? reader}) async {
    await database.close();
    database = await AppDatabase.open(
      factory: databaseFactoryFfi,
      databasePath: databasePath,
      legacyReader: reader ?? () async => {},
    );
    return database;
  }

  test('preferences survive restart and callers cannot change them without a write', () async {
    await database.writePreferences({
      'themeMode': 'dark',
      'document_checklist': {'title_deed': true},
    });
    database.readPreference<Map<String, dynamic>>('document_checklist')!['title_deed'] = false;
    expect(
      database.readPreference<Map<String, dynamic>>('document_checklist')!['title_deed'],
      true,
    );
    await reopen();
    expect(database.readPreference<String>('themeMode'), 'dark');
    expect(database.readPreference<int>('themeMode'), isNull);
    await database.removePreference('themeMode');
    await reopen();
    expect(database.readPreference<String>('themeMode'), isNull);
  });

  test('a failed transaction does not update preferences in memory or on disk', () async {
    await database.writePreferences({'language_code': 'en', 'country_code': 'US'});
    final raw = await databaseFactoryFfi.openDatabase(databasePath);
    await raw.execute("""CREATE TRIGGER reject_country BEFORE INSERT ON preferences
      WHEN NEW.key = 'country_code' BEGIN SELECT RAISE(ABORT, 'disk failure'); END""");
    await expectLater(
      database.writePreferences({'language_code': 'hi', 'country_code': 'IN'}),
      throwsA(isA<StorageFailure>()),
    );
    expect(database.readPreference<String>('language_code'), 'en');
    expect(
      (await raw.query(
        'preferences',
        where: 'key = ?',
        whereArgs: ['language_code'],
      )).single['value'],
      '"en"',
    );
  });

  test('SQLite disk-full failure is typed and does not claim the preference was saved', () async {
    final raw = await databaseFactoryFfi.openDatabase(databasePath);
    final pageCount = (await raw.rawQuery('PRAGMA page_count')).single.values.single! as int;
    await raw.execute('PRAGMA max_page_count = $pageCount');
    await expectLater(
      database.writePreference('large', 'x' * (1024 * 1024)),
      throwsA(isA<StorageFailure>()),
    );
    expect(database.readPreference<String>('large'), isNull);
  });

  test('legacy migration commits preferences and marker once, without server data', () async {
    await database.close();
    await databaseFactoryFfi.deleteDatabase(databasePath);
    database = await AppDatabase.open(
      factory: databaseFactoryFfi,
      databasePath: databasePath,
      legacyReader: () async => {
        'themeMode': 1,
        'language_code': 'hi',
        'country_code': 'wrong',
        'has_seen_onboarding': true,
        'global_purpose': 'rent',
        'global_property_types': ['apartment', 42],
        'document_checklist': {'title_deed': true, 'sale_deed': 'yes', 'unknown': true},
        'discover_state': {
          'filters': {'purpose': 'buy'},
          'properties': [
            {'id': 9},
          ],
          'isLoading': true,
          'nextCursor': 'private',
          'searchQuery': 'discard',
        },
        'access_token': 'do-not-import',
        'etag_cache_old-account': 'do-not-import',
        'offline_action_queue': [
          {'type': 'visit', 'propertyId': 9},
          'malformed record',
        ],
      },
    );
    expect(database.readPreference<String>('themeMode'), 'dark');
    expect(database.readPreference<String>('country_code'), 'IN');
    expect(database.readPreference<bool>('has_seen_onboarding'), true);
    expect(database.readPreference<List<dynamic>>('global_property_types'), ['apartment']);
    expect(database.readPreference<Map<String, dynamic>>('document_checklist'), {
      'title_deed': true,
    });
    final snapshot = database.readPreference<Map<String, dynamic>>('discover_state')!;
    expect(snapshot['filters']['purpose'], 'buy');
    for (final key in ['properties', 'isLoading', 'nextCursor', 'searchQuery']) {
      expect(snapshot.containsKey(key), false);
    }
    expect(database.readPreference<Object>('access_token'), isNull);
    expect(database.readPreference<Object>('etag_cache_old-account'), isNull);
    final actions = await database.readUnownedLegacyActions();
    expect(actions, hasLength(2));
    expect(
      actions.every(
        (a) => a.status == PendingActionStatus.needsReconciliation && a.scopeKey == null,
      ),
      true,
    );
    final scope = database.activateScope(environment: 'test', accountId: 'new-account');
    expect(await database.listActions(scope: scope), isEmpty);
    await database.writePreference('themeMode', 'light');
    await reopen(reader: () async => throw StateError('must not read legacy twice'));
    expect(database.readPreference<String>('themeMode'), 'light');
    expect(await database.readUnownedLegacyActions(), hasLength(2));
  });

  test('interrupted migration rolls back the marker and can be retried', () async {
    final raw = await databaseFactoryFfi.openDatabase(databasePath);
    await raw.delete('metadata');
    await raw.execute("""CREATE TRIGGER interrupt_import BEFORE INSERT ON preferences
      WHEN NEW.key = 'themeMode' BEGIN SELECT RAISE(ABORT, 'interrupted'); END""");
    await database.close();
    Future<Map<String, Object?>> legacy() async => {
      'has_seen_onboarding': true,
      'themeMode': 'dark',
    };
    await expectLater(
      AppDatabase.open(
        factory: databaseFactoryFfi,
        databasePath: databasePath,
        legacyReader: legacy,
      ),
      throwsA(isA<StorageFailure>()),
    );
    final verify = await databaseFactoryFfi.openDatabase(databasePath);
    expect(await verify.query('metadata'), isEmpty);
    expect(await verify.query('preferences'), isEmpty);
    await verify.execute('DROP TRIGGER interrupt_import');
    await verify.close();
    database = await AppDatabase.open(
      factory: databaseFactoryFfi,
      databasePath: databasePath,
      legacyReader: legacy,
    );
    expect(database.readPreference<String>('themeMode'), 'dark');
    expect(database.readPreference<bool>('has_seen_onboarding'), true);
  });

  test('legacy reader falls back to backup and leaves source files unchanged', () async {
    final primary = File(path.join(directory.path, 'GetStorage.gs'));
    final backup = File(path.join(directory.path, 'GetStorage.bak'));
    await primary.writeAsString('{broken');
    await backup.writeAsString('{"themeMode":"dark"}');
    expect(await readLegacyStorage(directory: directory.path), {'themeMode': 'dark'});
    expect(await primary.readAsString(), '{broken');
    expect(await backup.readAsString(), '{"themeMode":"dark"}');
    await backup.writeAsString('broken too');
    await expectLater(
      readLegacyStorage(directory: directory.path),
      throwsA(isA<StorageFailure>().having((e) => e.code, 'code', 'LEGACY_STORAGE_CORRUPT')),
    );
  });

  test(
    'a malformed preference row reads as unset, stays on disk and never blocks startup',
    () async {
      await database.writePreference('language_code', 'hi');
      final raw = await databaseFactoryFfi.openDatabase(databasePath);
      await raw.insert('preferences', {'key': 'themeMode', 'value': '{invalid'});
      await raw.close();

      await reopen();

      expect(database.readPreference<String>('themeMode'), isNull);
      expect(database.readPreference<String>('language_code'), 'hi', reason: 'other rows load');
      final verify = await databaseFactoryFfi.openDatabase(databasePath);
      final rows = await verify.query('preferences', where: "key = 'themeMode'");
      expect(rows.single['value'], '{invalid', reason: 'the source row is not deleted');
      await verify.close();

      await reopen(); // `verify` shared and closed the one connection of this path.
      await database.writePreference('themeMode', 'dark');
      await reopen();
      expect(database.readPreference<String>('themeMode'), 'dark', reason: 'a write replaces it');
    },
  );

  group('legacy storage recovery', () {
    late String freshPath;
    setUp(() async {
      await database.close();
      freshPath = path.join(directory.path, 'fresh.db');
    });

    Future<AppDatabase> openFresh(LegacyStorageReader reader) => AppDatabase.open(
      factory: databaseFactoryFfi,
      databasePath: freshPath,
      legacyReader: reader,
    );

    Future<Object?> marker() async {
      final verify = await databaseFactoryFfi.openDatabase(freshPath);
      final rows = await verify.query('metadata');
      await verify.close();
      return rows.isEmpty ? null : rows.single['value'];
    }

    test('two unparsable legacy files open with defaults and keep both files untouched', () async {
      final primary = File(path.join(directory.path, 'GetStorage.gs'));
      final backup = File(path.join(directory.path, 'GetStorage.bak'));
      await primary.writeAsString('{broken');
      await backup.writeAsString('broken too');

      database = await openFresh(() => readLegacyStorage(directory: directory.path));

      expect(database.readPreference<String>('themeMode'), isNull);
      expect(await marker(), 'quarantined', reason: 'the skip is recorded, not a success');
      expect(await primary.readAsString(), '{broken');
      expect(await backup.readAsString(), 'broken too');

      // The marker stops a second read, so the next launch does not look at the files again.
      var reads = 0;
      await database.close();
      database = await openFresh(() async {
        reads++;
        return {};
      });
      expect(reads, 0);
    });

    test('a file that cannot be read stays a typed failure that a retry can pass', () async {
      await expectLater(
        openFresh(
          () async => throw StorageFailure(
            'read legacy storage',
            cause: const FileSystemException('denied'),
            code: legacyStorageUnreadable,
          ),
        ),
        throwsA(isA<StorageFailure>().having((e) => e.code, 'code', legacyStorageUnreadable)),
      );
      final verify = await databaseFactoryFfi.openDatabase(freshPath);
      expect(await verify.query('metadata'), isEmpty, reason: 'no marker, so a retry imports');
      await verify.close();

      database = await openFresh(() async => {'themeMode': 'dark'});
      expect(database.readPreference<String>('themeMode'), 'dark');
      expect(await marker(), 'complete');
    });

    test('the reader tells a corrupt file from an unreadable one', () async {
      final primary = File(path.join(directory.path, 'GetStorage.gs'));
      await primary.writeAsString('{"themeMode":"dark"}');
      await Process.run('chmod', ['000', primary.path]);
      addTearDown(() => Process.run('chmod', ['600', primary.path]));
      var readable = true;
      try {
        await primary.readAsString();
      } on FileSystemException {
        readable = false;
      }
      if (readable) return; // Running as a user that ignores file modes.

      await expectLater(
        readLegacyStorage(directory: directory.path),
        throwsA(isA<StorageFailure>().having((e) => e.code, 'code', legacyStorageUnreadable)),
      );
    });
  });

  test(
    'cache separates accounts, rejects old leases, and exposes stale content before expiry',
    () async {
      final now = DateTime.now().toUtc();
      final a = database.activateScope(environment: 'staging', accountId: 'A');
      await database.writeCache(
        scope: a,
        key: 'properties?sort=price',
        value: {'id': 1},
        freshUntil: now.subtract(const Duration(seconds: 1)),
        expiresAt: now.add(const Duration(days: 1)),
        etag: 'v1',
      );
      final cached = await database.readCache(scope: a, key: 'properties?sort=price');
      expect(cached!.isStaleAt(now), true);
      expect(cached.etag, 'v1');
      expect(await database.readCache(scope: a, key: 'properties?sort=date'), isNull);
      expect(
        await database.readCache(
          scope: a,
          key: 'properties?sort=price',
          expectedSchemaVersion: AppDatabase.cacheSchemaVersion + 1,
        ),
        isNull,
      );
      expect(
        await database.readCache(
          scope: a,
          key: 'properties?sort=price',
          now: now.add(const Duration(days: 2)),
        ),
        isNull,
      );
      final b = database.activateScope(environment: 'staging', accountId: 'B');
      expect(await database.readCache(scope: b, key: 'properties?sort=price'), isNull);
      await expectLater(
        database.writeCache(
          scope: a,
          key: 'late',
          value: 'old account',
          freshUntil: now,
          expiresAt: now.add(const Duration(days: 1)),
        ),
        throwsA(isA<StorageFailure>().having((e) => e.code, 'code', 'STORAGE_SCOPE_CHANGED')),
      );
      final production = database.activateScope(environment: 'production', accountId: 'A');
      expect(await database.readCache(scope: production, key: 'properties?sort=price'), isNull);
    },
  );

  test('cache eviction enforces the size limit and clear removes actual rows', () async {
    final scope = database.activateScope(environment: 'test');
    final now = DateTime.now();
    final large = 'x' * (11 * 1024 * 1024);
    await database.writeCache(
      scope: scope,
      key: 'old',
      value: large,
      createdAt: now,
      freshUntil: now.add(const Duration(minutes: 5)),
      expiresAt: now.add(const Duration(days: 1)),
    );
    await database.writeCache(
      scope: scope,
      key: 'new',
      value: large,
      createdAt: now.add(const Duration(seconds: 1)),
      freshUntil: now.add(const Duration(minutes: 5)),
      expiresAt: now.add(const Duration(days: 1)),
    );
    expect(await database.readCache(scope: scope, key: 'old'), isNull);
    expect(await database.readCache(scope: scope, key: 'new'), isNotNull);
    await database.clearCache(scopeKey: scope.key);
    expect(await database.readCache(scope: scope, key: 'new'), isNull);
  });

  test('draft and pending action remain owned after restart and failure', () async {
    final a = database.activateScope(environment: 'test', accountId: 'A');
    await database.writeDraft(scope: a, key: 'assistant:42', value: {'message': 'unfinished'});
    final id = await database.createAction(
      scope: a,
      kind: 'visit',
      payload: {'propertyId': 1},
      status: PendingActionStatus.needsReconciliation,
    );
    await database.updateAction(
      scope: a,
      operationId: id,
      status: PendingActionStatus.failed,
      attempts: 5,
      failureCode: 'RETRY_EXHAUSTED',
    );
    await reopen();
    final b = database.activateScope(environment: 'test', accountId: 'B');
    expect(await database.listActions(scope: b), isEmpty);
    expect(await database.readDraft(scope: b, key: 'assistant:42'), isNull);
    final aAgain = database.activateScope(environment: 'test', accountId: 'A');
    final action = (await database.listActions(scope: aAgain)).single;
    expect(action.operationId, id);
    expect(action.status, PendingActionStatus.failed);
    expect(action.attempts, 5);
    expect(await database.readDraft(scope: aAgain, key: 'assistant:42'), {'message': 'unfinished'});
    await database.discardAction(scope: aAgain, operationId: id);
    expect(await database.listActions(scope: aAgain), isEmpty);
  });

  test('action queue capacity rejects the new write and retains existing requests', () async {
    final scope = database.activateScope(environment: 'test', accountId: 'A');
    for (var i = 0; i < AppDatabase.maxPendingActions; i++) {
      await database.createAction(scope: scope, kind: 'swipe', payload: {'propertyId': i});
    }
    await expectLater(
      database.createAction(scope: scope, kind: 'swipe', payload: {'propertyId': 999}),
      throwsA(isA<StorageFailure>().having((e) => e.code, 'code', 'ACTION_QUEUE_FULL')),
    );
    expect(await database.listActions(scope: scope), hasLength(AppDatabase.maxPendingActions));
    expect((await database.listActions(scope: scope)).first.payload['propertyId'], 0);
  });

  test('guest actions are rejected and duplicate operation IDs do not create duplicates', () async {
    final guest = database.activateScope(environment: 'test');
    await expectLater(
      database.createAction(scope: guest, kind: 'visit', payload: {}),
      throwsA(isA<StorageFailure>()),
    );
    final scope = database.activateScope(environment: 'test', accountId: 'A');
    await database.createAction(scope: scope, kind: 'visit', payload: {}, operationId: 'one');
    await expectLater(
      database.createAction(scope: scope, kind: 'visit', payload: {}, operationId: 'one'),
      throwsA(isA<StorageFailure>()),
    );
    expect(await database.listActions(scope: scope), hasLength(1));
  });
  test('pending payload recursively rejects mutation', () async {
    final scope = database.activateScope(environment: 'test', accountId: 'a');
    await database.createAction(
      scope: scope,
      kind: 'visit',
      payload: {
        'nested': {
          'items': [1, 2],
        },
      },
    );
    final action = (await database.listActions(scope: scope)).single;
    expect(() => action.payload['nested']['new'] = true, throwsUnsupportedError);
    expect(() => action.payload['nested']['items'].add(3), throwsUnsupportedError);
  });

  test('explicit legacy discard cannot delete an owned operation', () async {
    final raw = await databaseFactoryFfi.openDatabase(databasePath);
    await raw.insert('actions', {
      'operation_id': 'unowned-review',
      'scope': null,
      'kind': 'legacy',
      'payload': '{}',
      'created_at': 0,
      'status': 'needsReconciliation',
    });
    final scope = database.activateScope(environment: 'test', accountId: 'a');
    final owned = await database.createAction(scope: scope, kind: 'visit', payload: {});
    await database.discardUnownedAction(owned);
    expect((await database.listActions(scope: scope)).single.operationId, owned);
    await database.discardUnownedAction('unowned-review');
    expect(await database.readUnownedLegacyActions(), isEmpty);
  });
  test('one cache eviction preserves other keys and rejects an old account lease', () async {
    final old = database.activateScope(environment: 'test', accountId: 'a');
    final now = DateTime.now();
    for (final key in ['one', 'two']) {
      await database.writeCache(
        scope: old,
        key: key,
        value: key,
        freshUntil: now.add(const Duration(minutes: 1)),
        expiresAt: now.add(const Duration(days: 1)),
      );
    }
    await database.removeCache(scope: old, key: 'one');
    expect(await database.readCache(scope: old, key: 'one'), isNull);
    expect((await database.readCache(scope: old, key: 'two'))!.value, 'two');
    database.activateScope(environment: 'test', accountId: 'b');
    final current = database.activateScope(environment: 'test', accountId: 'a');
    await expectLater(database.removeCache(scope: old, key: 'two'), throwsA(isA<StorageFailure>()));
    expect((await database.readCache(scope: current, key: 'two'))!.value, 'two');
  });

  group('schema version and account data', () {
    test('opening a version 1 database empties the cache and keeps the rest', () async {
      await database.close();
      final old = await databaseFactoryFfi.openDatabase(
        path.join(directory.path, 'old.db'),
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            await db.execute(
              'CREATE TABLE preferences (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
            );
            await db.execute('CREATE TABLE metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
            await db.execute(
              '''CREATE TABLE cache (
              scope TEXT NOT NULL, key TEXT NOT NULL, value TEXT NOT NULL, etag TEXT,
              created_at INTEGER NOT NULL, fresh_until INTEGER NOT NULL, expires_at INTEGER NOT NULL,
              schema_version INTEGER NOT NULL, size_bytes INTEGER NOT NULL, PRIMARY KEY(scope,key))''',
            );
            await db.execute('''CREATE TABLE drafts (
              scope TEXT NOT NULL, key TEXT NOT NULL, value TEXT NOT NULL,
              updated_at INTEGER NOT NULL, PRIMARY KEY(scope,key))''');
            await db.execute('''CREATE TABLE actions (
              operation_id TEXT PRIMARY KEY, scope TEXT, kind TEXT NOT NULL, payload TEXT NOT NULL,
              created_at INTEGER NOT NULL, status TEXT NOT NULL, attempts INTEGER NOT NULL DEFAULT 0,
              next_attempt_at INTEGER, failure_code TEXT)''');
            await db.execute("INSERT INTO preferences VALUES ('themeMode', '\"dark\"')");
            await db.execute("INSERT INTO metadata VALUES ('get_storage_import_v1', 'complete')");
            await db.execute(
              "INSERT INTO cache VALUES ('s', 'k', '{}', 'e', 1, 2, 9999999999999, 1, 2)",
            );
            await db.execute("INSERT INTO drafts VALUES ('s', 'k', '{}', 1)");
          },
        ),
      );
      await old.close();

      database = await AppDatabase.open(
        factory: databaseFactoryFfi,
        databasePath: path.join(directory.path, 'old.db'),
        legacyReader: () async => {},
      );

      // The factory returns the open connection for a path: no second close.
      final raw = await databaseFactoryFfi.openDatabase(path.join(directory.path, 'old.db'));
      expect(await raw.query('cache'), isEmpty);
      expect(await raw.query('drafts'), hasLength(1));
      expect(database.readPreference<String>('themeMode'), 'dark');
      expect(AppDatabase.schemaVersion, greaterThanOrEqualTo(2));
    });

    test('purgeScope deletes the cache rows and drafts of that account only', () async {
      final now = DateTime.now().toUtc();
      final a = database.activateScope(environment: 'staging', accountId: 'A');
      Future<void> fill(StorageScope scope) async {
        await database.writeCache(
          scope: scope,
          key: 'properties',
          value: {'id': 1},
          freshUntil: now.add(const Duration(minutes: 5)),
          expiresAt: now.add(const Duration(days: 1)),
        );
        await database.writeDraft(scope: scope, key: 'swipe_history_v1', value: {'n': 1});
      }

      await fill(a);
      await database.createAction(scope: a, kind: 'swipe', payload: {'property_id': 1});
      final b = database.activateScope(environment: 'staging', accountId: 'B');
      await fill(b);

      await database.purgeScope(a.key);

      final a2 = database.activateScope(environment: 'staging', accountId: 'A');
      expect(await database.readCache(scope: a2, key: 'properties'), isNull);
      expect(await database.readDraft(scope: a2, key: 'swipe_history_v1'), isNull);
      expect(
        await database.listActions(scope: a2),
        hasLength(1),
        reason: 'pending actions stay with their account until it signs in again',
      );
      final b2 = database.activateScope(environment: 'staging', accountId: 'B');
      expect(await database.readCache(scope: b2, key: 'properties'), isNotNull);
      expect(await database.readDraft(scope: b2, key: 'swipe_history_v1'), isNotNull);
    });

    test('a draft not saved for 30 days is deleted when read', () async {
      final scope = database.activateScope(environment: 'staging', accountId: 'A');
      await database.writeDraft(scope: scope, key: 'old', value: {'n': 1});
      final raw = await databaseFactoryFfi.openDatabase(databasePath);
      await raw.update('drafts', {
        'updated_at': DateTime.now()
            .subtract(AppDatabase.draftRetention + const Duration(days: 1))
            .millisecondsSinceEpoch,
      });

      expect(await database.readDraft(scope: scope, key: 'old'), isNull);
    });
  });
}
