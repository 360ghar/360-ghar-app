import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_cache_manager/file.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/utils/image_cache_service.dart';
import 'package:mocktail/mocktail.dart';

class _CacheManager extends Mock implements BaseCacheManager {}

class _File extends Mock implements File {}

void main() {
  late _CacheManager manager;
  late ImageCacheService service;
  late _File file;
  const url = 'https://example.com/photo.jpg';

  setUp(() {
    manager = _CacheManager();
    service = ImageCacheService(cacheManager: manager);
    file = _File();
    when(() => file.exists()).thenAnswer((_) async => true);
    when(() => file.length()).thenAnswer((_) async => 32);
    when(() => manager.getFileFromCache(any())).thenAnswer((_) async => null);
    when(() => manager.getSingleFile(any())).thenAnswer((_) async => file);
    when(() => manager.removeFile(any())).thenAnswer((_) async {});
    when(() => manager.emptyCache()).thenAnswer((_) async {});
    when(() => manager.dispose()).thenAnswer((_) async {});
  });

  test('repository disposal before open completes waits and closes exactly once', () async {
    final exists = Completer<bool>();
    when(() => file.exists()).thenAnswer((_) => exists.future);
    when(() => file.writeAsString(any())).thenAnswer((_) async => file);
    final repository = ImageCacheInfoRepository.withFile(file);
    final opening = repository.open();
    expect(repository.open(), same(opening));
    var closed = false;
    final closing = repository.close().then((_) => closed = true);
    await Future<void>.delayed(Duration.zero);
    expect(closed, isFalse);
    verifyNever(() => file.writeAsString(any()));
    exists.complete(false);
    await opening;
    await closing;
    await repository.close();
    verify(() => file.writeAsString('[]')).called(1);
  });

  test('unused repository close does not create or flush a file', () async {
    final repository = ImageCacheInfoRepository.withFile(file);
    expect(await repository.close(), isFalse);
    verifyZeroInteractions(file);
  });

  group('URL validation', () {
    for (final value in [
      url,
      'http://example.com/photo.png',
      'https://cdn.example.com/photo?w=80',
    ]) {
      test('accepts $value', () => expect(service.isValidImageUrl(value), isTrue));
    }
    for (final value in [
      '',
      ' ',
      'example.com/image.jpg',
      'ftp://example.com/photo',
      'file:///photo',
      'not a url',
      'https://[invalid',
      'https://',
      'https://user:password@example.com/photo',
      ' https://example.com/photo',
    ]) {
      test('rejects $value', () => expect(service.isValidImageUrl(value), isFalse));
    }
  });

  test('uses injected manager without creating platform dependencies', () {
    expect(service.cacheManager, same(manager));
  });

  test('invalid input does not start a cache or network request', () async {
    expect(await service.getImageFile('not-a-url'), isNull);
    expect(await service.getImageBytes(''), isNull);
    expect(await service.isImageCached(''), isFalse);
    await service.preloadImage('');
    verifyZeroInteractions(manager);
  });

  test('expired entry goes through manager freshness revalidation', () async {
    when(
      () => manager.getFileFromCache(url),
    ).thenAnswer((_) async => FileInfo(file, FileSource.Cache, DateTime(2000), url));
    expect(await service.getImageFile(url), same(file));
    verify(() => manager.getSingleFile(url)).called(1);
    verifyNever(() => manager.emptyCache());
    verifyNever(() => manager.removeFile(any()));
  });

  test('empty cache file is removed before a new request', () async {
    final corrupt = _File();
    when(() => corrupt.exists()).thenAnswer((_) async => true);
    when(() => corrupt.length()).thenAnswer((_) async => 0);
    when(
      () => manager.getFileFromCache(url),
    ).thenAnswer((_) async => FileInfo(corrupt, FileSource.Cache, DateTime(2100), url));
    expect(await service.getImageFile(url), same(file));
    verifyInOrder([
      () => manager.getFileFromCache(url),
      () => manager.removeFile(url),
      () => manager.getSingleFile(url),
    ]);
    verifyNever(() => manager.emptyCache());
  });

  test('missing file is not reported as cached', () async {
    when(() => file.exists()).thenAnswer((_) async => false);
    when(
      () => manager.getFileFromCache(url),
    ).thenAnswer((_) async => FileInfo(file, FileSource.Cache, DateTime(2100), url));
    expect(await service.isImageCached(url), isFalse);
  });

  test('nonempty file is reported as cached', () async {
    when(
      () => manager.getFileFromCache(url),
    ).thenAnswer((_) async => FileInfo(file, FileSource.Cache, DateTime(2100), url));
    expect(await service.isImageCached(url), isTrue);
  });

  test('empty downloads and failed downloads use the local fallback', () async {
    when(() => file.length()).thenAnswer((_) async => 0);
    expect(await service.getImageFile(url), isNull);
    when(() => manager.getSingleFile(url)).thenThrow(StateError('unavailable'));
    expect(await service.getImageFile(url), isNull);
  });

  test('bytes are read from the same cache', () async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    when(() => file.readAsBytes()).thenAnswer((_) async => bytes);
    expect(await service.getImageBytes(url), bytes);
    verify(() => manager.getSingleFile(url)).called(1);
  });

  test('failed byte reads return a local image failure', () async {
    when(() => file.readAsBytes()).thenThrow(StateError('disk failure'));
    expect(await service.getImageBytes(url), isNull);
  });

  test('prefetch deduplicates URLs and caps concurrent requests at two', () async {
    final pending = Completer<File>();
    when(() => manager.getSingleFile(any())).thenAnswer((_) => pending.future);
    final first = service.preloadImage(url);
    final duplicate = service.preloadImage(url);
    final second = service.preloadImage('https://example.com/2.jpg');
    await service.preloadImage('https://example.com/3.jpg');
    await Future<void>.delayed(Duration.zero);
    expect(duplicate, same(first));
    verify(() => manager.getSingleFile(url)).called(1);
    verify(() => manager.getSingleFile('https://example.com/2.jpg')).called(1);
    verifyNever(() => manager.getSingleFile('https://example.com/3.jpg'));
    pending.complete(file);
    await Future.wait([first, second]);
    await service.preloadImage('https://example.com/3.jpg');
    verify(() => manager.getSingleFile('https://example.com/3.jpg')).called(1);
  });

  test('gallery prefetch is limited to two distinct valid images', () async {
    await service.preloadImages([
      '',
      url,
      url,
      'https://example.com/2.jpg',
      'https://example.com/3.jpg',
    ]);
    verify(() => manager.getSingleFile(url)).called(1);
    verify(() => manager.getSingleFile('https://example.com/2.jpg')).called(1);
    verifyNever(() => manager.getSingleFile('https://example.com/3.jpg'));
  });

  test('paging away stops the next speculative request', () async {
    var current = true;
    when(() => manager.getSingleFile(url)).thenAnswer((_) async {
      current = false;
      return file;
    });
    await service.preloadImages([url, 'https://example.com/2.jpg'], isCurrent: () => current);
    verifyNever(() => manager.getSingleFile('https://example.com/2.jpg'));
  });

  test('explicit removal affects only the requested URL', () async {
    await service.removeFromCache(url);
    verify(() => manager.removeFile(url)).called(1);
    verifyNever(() => manager.emptyCache());
  });

  test('only explicit clearing empties the cache', () async {
    await service.clearCache();
    verify(() => manager.emptyCache()).called(1);
  });

  test('cache maintenance failures are not reported as success', () async {
    when(() => manager.removeFile(url)).thenThrow(StateError('disk failure'));
    when(() => manager.emptyCache()).thenThrow(StateError('disk failure'));
    await expectLater(service.removeFromCache(url), throwsStateError);
    await expectLater(service.clearCache(), throwsStateError);
  });

  test('disposal is idempotent and rejects new speculative requests', () async {
    await service.dispose();
    await service.dispose();
    await service.preloadImage(url);
    expect(await service.getImageFile(url), isNull);
    verify(() => manager.dispose()).called(1);
    verifyNever(() => manager.getSingleFile(any()));
  });

  test('disposal prevents an in-flight read from starting a new download', () async {
    final pending = Completer<FileInfo?>();
    when(() => manager.getFileFromCache(url)).thenAnswer((_) => pending.future);
    final prefetch = service.preloadImage(url);
    final closing = service.dispose();
    pending.complete(null);
    await Future.wait([prefetch, closing]);
    verifyNever(() => manager.getSingleFile(any()));
    verify(() => manager.dispose()).called(1);
  });
}
