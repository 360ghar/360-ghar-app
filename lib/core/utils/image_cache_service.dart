import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter_cache_manager/file.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/utils/debug_logger.dart';

/// One cache owner per application ProviderScope. Widgets only borrow it.
final imageCacheServiceProvider = Provider<ImageCacheService>((ref) {
  final service = ImageCacheService(
    cacheManager: CacheManager(
      Config(
        'robust_image_cache',
        stalePeriod: const Duration(hours: 24),
        maxNrOfCacheObjects: 200,
        // The JSON index opens a file through path_provider, which web lacks;
        // web keeps the package's in-memory default.
        repo: kIsWeb
            ? NonStoringObjectProvider()
            : ImageCacheInfoRepository(databaseName: 'robust_image_cache'),
      ),
    ),
  );
  ref.onDispose(
    () => unawaited(
      service.dispose().catchError((Object error) {
        DebugLogger.warning('Image cache close failed: ${error.runtimeType}');
      }),
    ),
  );
  return service;
}, retry: (_, _) => null);

/// JsonCacheInfoRepository.close writes its file before the package waits for
/// open. Scope disposal may occur while the platform directory call is pending.
/// Keep both operations on the same initialization future before closing.
class ImageCacheInfoRepository extends JsonCacheInfoRepository {
  ImageCacheInfoRepository({super.path, super.databaseName});
  ImageCacheInfoRepository.withFile(super.file) : super.withFile();
  Future<bool>? _opening;
  Future<bool>? _closing;
  @override
  Future<bool> open() => _opening ??= super.open();
  @override
  Future<bool> close() => _closing ??= _closeAfterOpen();
  Future<bool> _closeAfterOpen() async {
    final opening = _opening;
    if (opening == null) return false;
    try {
      await opening;
    } catch (_) {
      // An unsuccessful open owns no initialized file to flush.
      return false;
    }
    return super.close();
  }
}

/// Owns the disk cache shared by displayed images and speculative downloads.
///
/// The cache manager evicts the least recently used files above 200 entries and
/// files unused for 24 hours. HTTP cache headers control response freshness.
/// There is no claimed byte limit or estimated cache-size reporting.
class ImageCacheService {
  ImageCacheService({required this.cacheManager});

  /// The application owns this manager. Individual image widgets must not
  /// dispose it. Tests and scoped owners can supply an isolated manager.
  final BaseCacheManager cacheManager;
  final Map<String, Future<void>> _prefetches = {};
  bool _disposed = false;

  bool isValidImageUrl(String url) => isValidUrl(url);

  static bool isValidUrl(String url) {
    if (url.isEmpty || url.trim() != url) return false;
    final uri = Uri.tryParse(url);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty;
  }

  /// Fetches only fresh, nonempty files. CacheManager preserves HTTP expiry and
  /// request deduplication; an expired cache entry must not bypass revalidation.
  Future<File?> getImageFile(String url) async {
    if (_disposed || !isValidImageUrl(url)) return null;
    try {
      final cached = await cacheManager.getFileFromCache(url);
      if (cached != null && (!await cached.file.exists() || await cached.file.length() == 0)) {
        await cacheManager.removeFile(url);
      }
      if (_disposed) return null;
      final file = await cacheManager.getSingleFile(url);
      if (_disposed || !await file.exists() || await file.length() == 0) return null;
      return file;
    } catch (_) {
      // Images recover locally. Do not log signed URLs or response bodies.
      return null;
    }
  }

  Future<Uint8List?> getImageBytes(String url) async {
    try {
      return await (await getImageFile(url))?.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  Future<bool> isImageCached(String url) async {
    if (_disposed || !isValidImageUrl(url)) return false;
    try {
      final info = await cacheManager.getFileFromCache(url);
      return info != null && await info.file.exists() && await info.file.length() > 0;
    } catch (_) {
      return false;
    }
  }

  /// At most two speculative downloads run at once across all galleries.
  /// When both slots are occupied, drop the speculative request; a visible
  /// image can still request its file normally. Duplicate requests share work.
  Future<void> preloadImage(String url) {
    if (_disposed || !isValidImageUrl(url)) return Future<void>.value();
    final existing = _prefetches[url];
    if (existing != null) return existing;
    if (_prefetches.length >= 2) return Future<void>.value();
    final future = getImageFile(url).then<void>((_) {}).whenComplete(() {
      _prefetches.remove(url);
    });
    _prefetches[url] = future;
    return future;
  }

  /// Only the next two images are prefetched, to disk without decoded copies.
  /// The owner supplies [isCurrent] to stop work after paging or disposal.
  Future<void> preloadImages(Iterable<String> urls, {bool Function()? isCurrent}) async {
    for (final url in urls.where(isValidImageUrl).toSet().take(2)) {
      if (_disposed || isCurrent?.call() == false) return;
      await preloadImage(url);
    }
  }

  /// Explicit eviction. Errors reach the caller so it cannot claim success
  /// when local storage failed. Flutter's decoded image cache is widget-owned.
  Future<void> removeFromCache(String url) async {
    await cacheManager.removeFile(url);
  }

  Future<void> clearCache() async {
    await cacheManager.emptyCache();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await Future.wait(_prefetches.values.toList());
    await cacheManager.dispose();
  }
}
