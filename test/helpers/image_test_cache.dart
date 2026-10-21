import 'package:flutter_cache_manager/file.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:ghar360/core/utils/image_cache_service.dart';
import 'package:mocktail/mocktail.dart';

/// Images remain in the loading state unless a test supplies a response. This
/// avoids network requests, platform channels, disk files, and cleanup timers.
class ImageTestCache extends Fake implements BaseCacheManager {
  final List<String> displayed = [];
  final List<String> prefetched = [];
  final List<String> removed = [];
  Stream<FileResponse> Function(String)? response;
  late final ImageCacheService service = ImageCacheService(cacheManager: this);

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) {
    displayed.add(url);
    return response?.call(url) ?? const Stream<FileResponse>.empty();
  }

  @override
  Future<FileInfo?> getFileFromCache(String key, {bool ignoreMemCache = false}) async => null;

  @override
  Future<File> getSingleFile(String url, {String? key, Map<String, String>? headers}) async {
    prefetched.add(url);
    throw StateError('No test image configured');
  }

  @override
  Future<void> removeFile(String key) async => removed.add(key);

  @override
  Future<void> dispose() async {}
}
