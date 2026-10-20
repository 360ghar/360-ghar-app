import 'package:ghar360/core/network/api_response.dart';
import 'package:ghar360/core/storage/app_database.dart';

/// Conditional HTTP responses stored in the application database.
///
/// A request captures [scope] before its first await and passes the same lease
/// to every read/write. The database rejects leases from a previous account. The key a caller
/// passes already names the signed-in identity (`ApiClient` builds it from the request scope), so
/// one account never reads another's row. A row written under another [AppDatabase.cacheSchemaVersion]
/// reads as a miss, so a changed response model never replays an old-shape body on a 304.
///
/// The server marks authenticated responses `Cache-Control: no-store` and still sends an ETag.
/// The client must honour `no-store` itself: such a response is never stored, and a stored row
/// for the same key is deleted.
class ETagCache {
  ETagCache({required this._database, required this._scope});

  static const freshFor = Duration(minutes: 5);
  static const retainFor = Duration(hours: 24);
  final AppDatabase _database;
  final StorageScope Function() _scope;

  StorageScope get scope => _scope();

  /// True when a `Cache-Control` header lists the `no-store` directive.
  static bool isNoStore(Map<String, String> headers) {
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() != 'cache-control') continue;
      final directives = entry.value.toLowerCase().split(',').map((part) => part.trim());
      if (directives.contains('no-store')) return true;
    }
    return false;
  }

  Future<CachedEntry?> read(String key, {required StorageScope scope}) =>
      _database.readCache(scope: scope, key: key);

  Future<void> remove(String key, {required StorageScope scope}) =>
      _database.removeCache(scope: scope, key: key);

  Future<void> cacheResponse(
    String key,
    ApiResponse response, {
    required StorageScope scope,
  }) async {
    if (isNoStore(response.headers)) {
      await remove(key, scope: scope);
      return;
    }
    String? etag;
    for (final entry in response.headers.entries) {
      if (entry.key.toLowerCase() == 'etag') {
        etag = entry.value;
        break;
      }
    }
    if (etag == null || etag.isEmpty || response.body == null || response.body == '') return;
    final now = DateTime.now();
    await _database.writeCache(
      scope: scope,
      key: key,
      value: response.body,
      etag: etag,
      freshUntil: now.add(freshFor),
      expiresAt: now.add(retainFor),
      createdAt: now,
    );
  }

  Future<void> clear() => _database.clearCache();
}
