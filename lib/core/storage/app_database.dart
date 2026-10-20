import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'package:ghar360/core/storage/legacy_storage.dart';
import 'package:ghar360/core/storage/storage_failure.dart';
import 'package:ghar360/core/utils/debug_logger.dart';

export 'package:ghar360/core/storage/legacy_storage.dart' show LegacyStorageReader;
export 'package:ghar360/core/storage/storage_failure.dart';

/// Capture before starting account work. A transition invalidates all old leases.
class StorageScope {
  const StorageScope._(this.key, this.accountId, this._generation);
  final String key;
  final String? accountId;
  final int _generation;
}

class CachedEntry {
  const CachedEntry({
    required this.value,
    required this.createdAt,
    required this.freshUntil,
    required this.expiresAt,
    required this.schemaVersion,
    this.etag,
  });
  final Object? value;
  final String? etag;
  final DateTime createdAt;
  final DateTime freshUntil;
  final DateTime expiresAt;
  final int schemaVersion;
  bool isStaleAt(DateTime time) => !time.isBefore(freshUntil);
}

enum PendingActionStatus { pending, needsReconciliation, failed, confirmed }

class PendingAction {
  PendingAction({
    required this.operationId,
    required this.scopeKey,
    required this.kind,
    required Map<String, dynamic> payload,
    required this.createdAt,
    required this.status,
    this.attempts = 0,
    this.nextAttemptAt,
    this.failureCode,
  }) : payload = _freezeJson(payload) as Map<String, dynamic>;
  final String operationId;

  /// Null means the legacy action has no trustworthy account owner.
  final String? scopeKey;
  final String kind;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final PendingActionStatus status;
  final int attempts;
  final DateTime? nextAttemptAt;
  final String? failureCode;
}

Object? _freezeJson(Object? value) => switch (value) {
  Map() => Map<String, dynamic>.unmodifiable(
    value.map((key, item) => MapEntry(key.toString(), _freezeJson(item))),
  ),
  List() => List<Object?>.unmodifiable(value.map(_freezeJson)),
  _ => value,
};

/// One application database. Supabase owns credentials and session persistence.
class AppDatabase {
  AppDatabase._(this._database, this._preferences);

  /// SQLite schema version. Version 2 empties the cache table, because every stored row has the
  /// shape of the previous contract.
  static const schemaVersion = 2;

  /// Version of the JSON shapes stored in the cache table. A row written under another version
  /// reads as a miss. Bump it with any change to a model that is cached.
  static const cacheSchemaVersion = 2;

  /// A draft not saved for this long is deleted when it is read.
  static const draftRetention = Duration(days: 30);
  static const maxCacheEntries = 500;
  static const maxCacheBytes = 20 * 1024 * 1024;
  static const maxPendingActions = 100;
  static const _migrationKey = 'get_storage_import_v1';
  final Database _database;
  final Map<String, Object?> _preferences;
  int _generation = 0;
  StorageScope? _scope;

  static Future<AppDatabase> open({
    DatabaseFactory? factory,
    String? databasePath,
    LegacyStorageReader? legacyReader,
  }) async {
    Database? database;
    try {
      // Web has no sqflite plugin: SQLite runs as wasm in a shared worker
      // (web/sqlite3.wasm and web/sqflite_sw.js, from `dart run sqflite_common_ffi_web:setup`).
      final selectedFactory = factory ?? (kIsWeb ? databaseFactoryFfiWeb : databaseFactory);
      final location =
          databasePath ?? path.join(await selectedFactory.getDatabasesPath(), 'ghar360.db');
      database = await selectedFactory.openDatabase(
        location,
        options: OpenDatabaseOptions(
          version: schemaVersion,
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
            await db.execute('CREATE INDEX actions_scope_status ON actions(scope,status)');
          },
          onUpgrade: (db, oldVersion, newVersion) async {
            // Cached responses of the previous contract are not readable by the current models.
            if (oldVersion < 2) await db.delete('cache');
          },
          onDowngrade: (db, oldVersion, newVersion) async {
            throw StorageFailure('open newer schema', code: 'STORAGE_SCHEMA_UNSUPPORTED');
          },
        ),
      );
      final marker = await database.query('metadata', where: 'key = ?', whereArgs: [_migrationKey]);
      if (marker.isEmpty) {
        var legacy = const <String, Object?>{};
        var quarantined = false;
        try {
          legacy = await (legacyReader ?? readLegacyStorage)();
        } on StorageFailure catch (error, stack) {
          if (error.code != legacyStorageCorrupt) rethrow;
          // Neither legacy file parses, so nothing can be imported. Both files stay on disk
          // untouched. The marker records the skip, so startup does not fail on every launch.
          quarantined = true;
          DebugLogger.warning(
            'Legacy storage is corrupt; opening with defaults',
            error.code,
            stack,
          );
        }
        await database.transaction((txn) async {
          for (final entry in legacyPreferences(legacy).entries) {
            await txn.insert('preferences', {
              'key': entry.key,
              'value': jsonEncode(entry.value),
            }, conflictAlgorithm: ConflictAlgorithm.ignore);
          }
          final actions = legacy['offline_action_queue'];
          if (actions is List) {
            for (var i = 0; i < actions.length; i++) {
              // Retain even malformed entries for review; never execute them.
              await txn.insert('actions', {
                'operation_id': 'legacy-$i',
                'scope': null,
                'kind': 'legacy',
                'payload': jsonEncode({'legacy': actions[i]}),
                'created_at': DateTime.now().toUtc().millisecondsSinceEpoch,
                'status': PendingActionStatus.needsReconciliation.name,
                'failure_code': 'LEGACY_OWNER_UNKNOWN',
              }, conflictAlgorithm: ConflictAlgorithm.ignore);
            }
          }
          await txn.insert('metadata', {
            'key': _migrationKey,
            'value': quarantined ? 'quarantined' : 'complete',
          });
        });
      }
      final preferences = <String, Object?>{};
      for (final row in await database.query('preferences')) {
        final key = row['key']! as String;
        try {
          preferences[key] = jsonDecode(row['value']! as String);
        } on FormatException catch (error, stack) {
          // The row stays on disk. The key reads as unset (its documented default) until a write
          // replaces it, so one bad row never blocks startup.
          DebugLogger.warning('Preference row is not JSON; reading it as unset', key, stack);
        }
      }
      return AppDatabase._(database, preferences);
    } catch (error, stack) {
      await database?.close();
      Error.throwWithStackTrace(
        error is StorageFailure ? error : StorageFailure('open database', cause: error),
        stack,
      );
    }
  }

  /// Synchronous startup reads from a snapshot hydrated before runApp.
  T? readPreference<T>(String key) {
    final value = _preferences[key];
    // A JSON copy prevents mutation of nested cached values without a commit.
    final copy = value == null ? null : jsonDecode(jsonEncode(value));
    return copy is T ? copy : null;
  }

  Future<void> writePreference(String key, Object? value) => writePreferences({key: value});

  /// Commit related values (for example language and country) together.
  Future<void> writePreferences(Map<String, Object?> values) =>
      _guard('write preferences', () async {
        final encoded = values.map((key, value) => MapEntry(key, jsonEncode(value)));
        await _database.transaction((txn) async {
          for (final entry in encoded.entries) {
            await txn.insert('preferences', {
              'key': entry.key,
              'value': entry.value,
            }, conflictAlgorithm: ConflictAlgorithm.replace);
          }
        });
        for (final entry in encoded.entries) {
          _preferences[entry.key] = jsonDecode(entry.value);
        }
      });

  Future<void> removePreference(String key) => _guard('remove preference', () async {
    await _database.delete('preferences', where: 'key = ?', whereArgs: [key]);
    _preferences.remove(key);
  });

  /// Call synchronously on logout/account change, before waiting on cleanup.
  StorageScope activateScope({required String environment, String? accountId}) {
    final key = jsonEncode([environment, accountId ?? 'guest']);
    if (_scope?.key == key) return _scope!;
    _scope = StorageScope._(key, accountId, ++_generation);
    return _scope!;
  }

  void _checkScope(StorageScope scope) {
    if (!identical(scope, _scope) || scope._generation != _generation) {
      throw StorageFailure('account changed', code: 'STORAGE_SCOPE_CHANGED');
    }
  }

  Future<CachedEntry?> readCache({
    required StorageScope scope,
    required String key,
    int expectedSchemaVersion = cacheSchemaVersion,
    DateTime? now,
  }) => _guard('read cache', () async {
    _checkScope(scope);
    final rows = await _database.query(
      'cache',
      where: 'scope = ? AND key = ?',
      whereArgs: [scope.key, key],
    );
    _checkScope(scope);
    if (rows.isEmpty) return null;
    final row = rows.single;
    if (row['schema_version'] != expectedSchemaVersion ||
        (row['expires_at']! as int) <= (now ?? DateTime.now()).millisecondsSinceEpoch) {
      return null;
    }
    try {
      return CachedEntry(
        value: jsonDecode(row['value']! as String),
        etag: row['etag'] as String?,
        createdAt: _date(row['created_at']),
        freshUntil: _date(row['fresh_until']),
        expiresAt: _date(row['expires_at']),
        schemaVersion: row['schema_version']! as int,
      );
    } on FormatException {
      await _database.delete('cache', where: 'scope = ? AND key = ?', whereArgs: [scope.key, key]);
      throw StorageFailure('decode cache', code: 'CACHE_CORRUPT');
    }
  });

  Future<void> writeCache({
    required StorageScope scope,
    required String key,
    required Object? value,
    required DateTime freshUntil,
    required DateTime expiresAt,
    String? etag,
    int schemaVersion = cacheSchemaVersion,
    DateTime? createdAt,
  }) => _guard('write cache', () async {
    _checkScope(scope);
    final encoded = jsonEncode(value);
    final bytes = utf8.encode(encoded).length;
    if (bytes > maxCacheBytes || expiresAt.isBefore(freshUntil)) {
      throw StorageFailure('invalid cache entry', code: 'CACHE_LIMIT');
    }
    await _database.transaction((txn) async {
      _checkScope(scope);
      await txn.insert('cache', {
        'scope': scope.key,
        'key': key,
        'value': encoded,
        'etag': etag,
        'created_at': (createdAt ?? DateTime.now()).millisecondsSinceEpoch,
        'fresh_until': freshUntil.millisecondsSinceEpoch,
        'expires_at': expiresAt.millisecondsSinceEpoch,
        'schema_version': schemaVersion,
        'size_bytes': bytes,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.delete(
        'cache',
        where: 'expires_at <= ?',
        whereArgs: [DateTime.now().millisecondsSinceEpoch],
      );
      final rows = await txn.query(
        'cache',
        columns: ['scope', 'key', 'size_bytes'],
        orderBy: 'created_at DESC, rowid DESC',
      );
      var total = 0;
      for (var index = 0; index < rows.length; index++) {
        final row = rows[index];
        total += row['size_bytes']! as int;
        if (index >= maxCacheEntries || total > maxCacheBytes) {
          await txn.delete(
            'cache',
            where: 'scope = ? AND key = ?',
            whereArgs: [row['scope'], row['key']],
          );
        }
      }
      _checkScope(scope);
    });
  });

  Future<void> removeCache({required StorageScope scope, required String key}) =>
      _guard('remove cache entry', () async {
        await _database.transaction((txn) async {
          _checkScope(scope);
          await txn.delete('cache', where: 'scope = ? AND key = ?', whereArgs: [scope.key, key]);
          _checkScope(scope);
        });
      });

  Future<void> clearCache({String? scopeKey}) => _guard('clear cache', () async {
    await _database.delete(
      'cache',
      where: scopeKey == null ? null : 'scope = ?',
      whereArgs: scopeKey == null ? null : [scopeKey],
    );
  });

  /// Deletes every cache row and every draft of one account scope. Call it when that account
  /// signs out, so its listings, profile and unsent text do not stay on the device. Pending
  /// actions stay: they still belong to the account and wait for it to sign in again.
  Future<void> purgeScope(String scopeKey) => _guard('purge account data', () async {
    await _database.transaction((txn) async {
      await txn.delete('cache', where: 'scope = ?', whereArgs: [scopeKey]);
      await txn.delete('drafts', where: 'scope = ?', whereArgs: [scopeKey]);
    });
  });

  Future<void> writeDraft({
    required StorageScope scope,
    required String key,
    required Map<String, Object?> value,
  }) => _guard('write draft', () async {
    await _database.transaction((txn) async {
      _checkScope(scope);
      await txn.insert('drafts', {
        'scope': scope.key,
        'key': key,
        'value': jsonEncode(value),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      _checkScope(scope);
    });
  });

  Future<Map<String, dynamic>?> readDraft({required StorageScope scope, required String key}) =>
      _guard('read draft', () async {
        _checkScope(scope);
        final rows = await _database.query(
          'drafts',
          where: 'scope = ? AND key = ?',
          whereArgs: [scope.key, key],
        );
        _checkScope(scope);
        if (rows.isEmpty) return null;
        final savedAt = _date(rows.single['updated_at']);
        if (DateTime.now().toUtc().difference(savedAt) > draftRetention) {
          await _database.delete(
            'drafts',
            where: 'scope = ? AND key = ?',
            whereArgs: [scope.key, key],
          );
          return null;
        }
        return jsonDecode(rows.single['value']! as String) as Map<String, dynamic>;
      });

  Future<void> removeDraft({required StorageScope scope, required String key}) => _guard(
    'remove draft',
    () async {
      _checkScope(scope);
      await _database.delete('drafts', where: 'scope = ? AND key = ?', whereArgs: [scope.key, key]);
    },
  );

  static String newOperationId() {
    final random = Random.secure();
    return List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  /// Await this before claiming an action was saved. Never evicts another action.
  Future<String> createAction({
    required StorageScope scope,
    required String kind,
    required Map<String, Object?> payload,
    String? operationId,
    PendingActionStatus status = PendingActionStatus.pending,
  }) => _guard('create action', () async {
    if (scope.accountId == null) {
      throw StorageFailure('action requires account', code: 'ACTION_OWNER_REQUIRED');
    }
    final id = operationId ?? newOperationId();
    await _database.transaction((txn) async {
      _checkScope(scope);
      final count =
          Sqflite.firstIntValue(
            await txn.rawQuery(
              "SELECT count(*) FROM actions WHERE scope = ? AND status != 'confirmed'",
              [scope.key],
            ),
          ) ??
          0;
      if (count >= maxPendingActions) {
        throw StorageFailure('action queue full', code: 'ACTION_QUEUE_FULL');
      }
      await txn.insert('actions', {
        'operation_id': id,
        'scope': scope.key,
        'kind': kind,
        'payload': jsonEncode(payload),
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'status': status.name,
      });
      _checkScope(scope);
    });
    return id;
  });

  Future<List<PendingAction>> listActions({required StorageScope scope}) =>
      _guard('read actions', () async {
        _checkScope(scope);
        final rows = await _database.query(
          'actions',
          where: 'scope = ?',
          whereArgs: [scope.key],
          orderBy: 'created_at, rowid',
        );
        _checkScope(scope);
        return rows.map(_action).toList(growable: false);
      });

  /// A separate review path. These records must never enter automatic replay.
  Future<List<PendingAction>> readUnownedLegacyActions() => _guard('read legacy actions', () async {
    return (await _database.query(
      'actions',
      where: 'scope IS NULL',
      orderBy: 'created_at, rowid',
    )).map(_action).toList(growable: false);
  });

  /// Explicit review may remove only an imported record with no verified owner.
  Future<void> discardUnownedAction(String operationId) =>
      _guard('discard legacy action', () async {
        await _database.delete(
          'actions',
          where: 'scope IS NULL AND operation_id = ?',
          whereArgs: [operationId],
        );
      });

  Future<void> updateAction({
    required StorageScope scope,
    required String operationId,
    required PendingActionStatus status,
    int attempts = 0,
    DateTime? nextAttemptAt,
    String? failureCode,
  }) => _guard('update action', () async {
    await _database.transaction((txn) async {
      _checkScope(scope);
      final changed = await txn.update(
        'actions',
        {
          'status': status.name,
          'attempts': attempts,
          'next_attempt_at': nextAttemptAt?.millisecondsSinceEpoch,
          'failure_code': failureCode,
        },
        where: 'scope = ? AND operation_id = ?',
        whereArgs: [scope.key, operationId],
      );
      if (changed != 1) throw StorageFailure('action not found', code: 'ACTION_NOT_FOUND');
      _checkScope(scope);
    });
  });

  Future<void> discardAction({required StorageScope scope, required String operationId}) =>
      _guard('discard action', () async {
        _checkScope(scope);
        await _database.delete(
          'actions',
          where: 'scope = ? AND operation_id = ?',
          whereArgs: [scope.key, operationId],
        );
      });

  static DateTime _date(Object? value) =>
      DateTime.fromMillisecondsSinceEpoch(value! as int, isUtc: true);
  static PendingAction _action(Map<String, Object?> row) => PendingAction(
    operationId: row['operation_id']! as String,
    scopeKey: row['scope'] as String?,
    kind: row['kind']! as String,
    payload: jsonDecode(row['payload']! as String) as Map<String, dynamic>,
    createdAt: _date(row['created_at']),
    status: PendingActionStatus.values.byName(row['status']! as String),
    attempts: row['attempts']! as int,
    nextAttemptAt: row['next_attempt_at'] == null ? null : _date(row['next_attempt_at']),
    failureCode: row['failure_code'] as String?,
  );

  Future<T> _guard<T>(String operation, Future<T> Function() action) async {
    try {
      return await action();
    } catch (error, stack) {
      Error.throwWithStackTrace(
        error is StorageFailure ? error : StorageFailure(operation, cause: error),
        stack,
      );
    }
  }

  Future<void> close() async {
    _generation++;
    _scope = null;
    await _guard('close database', _database.close);
  }
}
