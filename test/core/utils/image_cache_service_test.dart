import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/utils/image_cache_service.dart';

void main() {
  // ImageCacheService's constructor creates a CacheManager which uses
  // path_provider/platform channels and an HttpClient. The binding must be
  // initialized and the path_provider channel must be mocked so the cache
  // manager's async initialization does not throw MissingPluginException.
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('image_cache_test_');
    // Mock path_provider method channel to return a real temp directory so
    // flutter_cache_manager can initialize its file system and database.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall call) async {
        return tempDir.path;
      },
    );
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  late ImageCacheService service;

  setUp(() {
    service = ImageCacheService.instance;
  });

  group('ImageCacheService.instance (singleton)', () {
    test('returns the same instance on repeated calls', () {
      final a = ImageCacheService.instance;
      final b = ImageCacheService.instance;

      expect(identical(a, b), isTrue);
    });
  });

  group('ImageCacheService.isValidImageUrl', () {
    test('returns true for valid https URLs', () {
      expect(service.isValidImageUrl('https://example.com/image.jpg'), isTrue);
    });

    test('returns true for valid http URLs', () {
      expect(service.isValidImageUrl('http://example.com/image.png'), isTrue);
    });

    test('returns true for URLs with paths and query parameters', () {
      expect(
        service.isValidImageUrl('https://cdn.example.com/images/123?w=800&h=600'),
        isTrue,
      );
    });

    test('returns true for URLs with subdomains', () {
      expect(service.isValidImageUrl('https://res.cloudinary.com/360ghar/image.jpg'), isTrue);
    });

    test('returns false for empty string', () {
      expect(service.isValidImageUrl(''), isFalse);
    });

    test('returns false for whitespace-only input', () {
      expect(service.isValidImageUrl('   '), isFalse);
    });

    test('returns false for URL without a scheme', () {
      expect(service.isValidImageUrl('example.com/image.jpg'), isFalse);
    });

    test('returns false for ftp scheme', () {
      expect(service.isValidImageUrl('ftp://example.com/image.jpg'), isFalse);
    });

    test('returns false for file scheme', () {
      expect(service.isValidImageUrl('file:///path/to/image.jpg'), isFalse);
    });

    test('returns false for a plain string that is not a URL', () {
      expect(service.isValidImageUrl('not a url'), isFalse);
    });

    test('returns false for a malformed string', () {
      expect(service.isValidImageUrl('https://[invalid'), isFalse);
    });
  });

  group('ImageCacheService.getCacheSize', () {
    test('returns 0 (flutter_cache_manager does not expose size)', () async {
      final size = await service.getCacheSize();

      expect(size, 0);
    });
  });

  group('ImageCacheService.getCacheFileCount', () {
    test('returns 0 (flutter_cache_manager does not expose count)', () async {
      final count = await service.getCacheFileCount();

      expect(count, 0);
    });
  });

  group('ImageCacheService.getCacheStats', () {
    test('returns a map with expected configuration keys', () async {
      final stats = await service.getCacheStats();

      expect(stats, isA<Map<String, dynamic>>());
      expect(stats.containsKey('maxAge'), isTrue);
      expect(stats.containsKey('maxSize'), isTrue);
      expect(stats.containsKey('maxFiles'), isTrue);
      expect(stats.containsKey('note'), isTrue);
    });

    test('returns maxSize as an integer', () async {
      final stats = await service.getCacheStats();

      expect(stats['maxSize'], isA<int>());
    });

    test('returns maxFiles as an integer', () async {
      final stats = await service.getCacheStats();

      expect(stats['maxFiles'], isA<int>());
    });

    test('returns maxAge as a string', () async {
      final stats = await service.getCacheStats();

      expect(stats['maxAge'], isA<String>());
    });

    test('returns a descriptive note string', () async {
      final stats = await service.getCacheStats();

      expect(stats['note'], isA<String>());
      expect(stats['note'].toString(), isNotEmpty);
    });
  });

  group('ImageCacheService error paths', () {
    test('getImageFile returns null for an invalid URL', () async {
      final file = await service.getImageFile('not-a-url');

      expect(file, isNull);
    });

    test('getImageFile returns null for an empty URL', () async {
      final file = await service.getImageFile('');

      expect(file, isNull);
    });

    test('getImageBytes returns null for an invalid URL', () async {
      final bytes = await service.getImageBytes('not-a-url');

      expect(bytes, isNull);
    });

    test('getImageBytes returns null for an empty URL', () async {
      final bytes = await service.getImageBytes('');

      expect(bytes, isNull);
    });

    test('updateCacheConfig does not throw', () async {
      await expectLater(
        service.updateCacheConfig(
          maxAge: const Duration(hours: 12),
          maxSize: 100 * 1024 * 1024,
          maxFiles: 100,
        ),
        completes,
      );
    });
  });

  group('ImageCacheServiceExtension', () {
    test('preloadImage is a no-op for an invalid URL', () async {
      await expectLater(service.preloadImage('not-a-url'), completes);
    });

    test('isImageCached returns false for an invalid URL', () async {
      final cached = await service.isImageCached('not-a-url');

      expect(cached, isFalse);
    });
  });

  group('ImageCacheService cache maintenance', () {
    test('removeFromCache completes for any key', () async {
      await expectLater(
        service.removeFromCache('https://example.com/missing.jpg'),
        completes,
      );
    });

    test('clearCache completes without throwing', () async {
      await expectLater(service.clearCache(), completes);
    });

    test('cleanExpiredCache completes without throwing', () async {
      await expectLater(service.cleanExpiredCache(), completes);
    });

    test('smartCleanup completes without throwing', () async {
      await expectLater(service.smartCleanup(), completes);
    });

    test('dispose releases singleton and allows re-instantiation', () async {
      await service.dispose();
      final next = ImageCacheService.instance;
      expect(next, isA<ImageCacheService>());
    });
  });
}
