import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/image_cache_service.dart';
import 'package:ghar360/core/widgets/common/robust_network_image.dart';

import '../../../helpers/image_test_cache.dart';
import '../../../helpers/knife_finders.dart';

void main() {
  late ImageTestCache cache;
  setUp(() {
    cache = ImageTestCache();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });

  Future<void> pumpWidget(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: const [AppLocalizations.delegate],
          locale: const Locale('en', 'US'),
          home: Scaffold(body: Center(child: child)),
        ),
      ),
    );
  }

  testWidgets('all mounted images borrow the same scoped cache without a global fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [imageCacheServiceProvider.overrideWithValue(cache.service)],
        child: const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                RobustNetworkImage(
                  imageUrl: 'https://example.com/scoped-one.jpg',
                  width: 100,
                  height: 100,
                ),
                RobustNetworkImage(
                  imageUrl: 'https://example.com/scoped-two.jpg',
                  width: 100,
                  height: 100,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final widgets = tester.widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage));
    expect(widgets, hasLength(2));
    expect(widgets.every((widget) => identical(widget.cacheManager, cache)), isTrue);
    expect(
      cache.displayed,
      containsAll(['https://example.com/scoped-one.jpg', 'https://example.com/scoped-two.jpg']),
    );
    await tester.pumpWidget(const SizedBox());
    await cache.service.preloadImage('https://example.com/after-unmount.jpg');
    expect(cache.prefetched, contains('https://example.com/after-unmount.jpg'));
  });

  testWidgets('renders error widget for an empty URL', (tester) async {
    await pumpWidget(
      tester,
      RobustNetworkImage(cacheService: cache.service, imageUrl: '', width: 200, height: 200),
    );

    // No valid URL → default error widget with home icon.
    expect(findKnife(KnifeIcon.home), findsOneWidget);
    // The "Property Image" label is shown when width > 100.
    expect(find.text('Property Image'), findsOneWidget);
    // CachedNetworkImage is NOT rendered for invalid URLs.
    expect(find.byType(CachedNetworkImage), findsNothing);
  });

  testWidgets('renders error widget for a null-equivalent invalid URL', (tester) async {
    await pumpWidget(
      tester,
      RobustNetworkImage(cacheService: cache.service, imageUrl: 'not-a-url', width: 80, height: 80),
    );

    // Invalid URL → error widget (home icon).
    expect(findKnife(KnifeIcon.home), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsNothing);
  });

  testWidgets('renders CachedNetworkImage for a valid http URL', (tester) async {
    await pumpWidget(
      tester,
      RobustNetworkImage(
        cacheService: cache.service,
        imageUrl: 'https://example.com/image.jpg',
        width: 200,
        height: 200,
      ),
    );

    // A valid URL produces a CachedNetworkImage widget.
    expect(find.byType(CachedNetworkImage), findsOneWidget);
  });

  testWidgets('renders CachedNetworkImage for a valid https URL', (tester) async {
    await pumpWidget(
      tester,
      RobustNetworkImage(
        cacheService: cache.service,
        imageUrl: 'https://cdn.example.com/photo.png',
        width: 100,
        height: 100,
      ),
    );

    expect(find.byType(CachedNetworkImage), findsOneWidget);
  });

  testWidgets('shows loading placeholder while image loads', (tester) async {
    await pumpWidget(
      tester,
      RobustNetworkImage(
        cacheService: cache.service,
        imageUrl: 'https://example.com/image.jpg',
        width: 200,
        height: 200,
      ),
    );

    // The default placeholder is a quiet tonal slot: no spinner, no retry.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(findKnife(KnifeIcon.retry), findsNothing);
    expect(find.byType(Container), findsWidgets);
  });

  testWidgets('uses custom placeholder when provided', (tester) async {
    await pumpWidget(
      tester,
      RobustNetworkImage(
        cacheService: cache.service,
        imageUrl: 'https://example.com/image.jpg',
        width: 200,
        height: 200,
        placeholder: const Text('Custom Placeholder'),
      ),
    );

    expect(find.text('Custom Placeholder'), findsOneWidget);
  });

  testWidgets('uses custom error widget when provided for invalid URL', (tester) async {
    await pumpWidget(
      tester,
      RobustNetworkImage(
        cacheService: cache.service,
        imageUrl: '',
        width: 200,
        height: 200,
        errorWidget: const Text('Custom Error'),
      ),
    );

    expect(find.text('Custom Error'), findsOneWidget);
    expect(findKnife(KnifeIcon.home), findsNothing);
  });

  testWidgets('applies ClipRRect when borderRadius is provided', (tester) async {
    await pumpWidget(
      tester,
      RobustNetworkImage(
        cacheService: cache.service,
        imageUrl: 'https://example.com/image.jpg',
        width: 200,
        height: 200,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
    );

    expect(find.byType(ClipRRect), findsOneWidget);
  });

  testWidgets('applies ClipRRect for invalid URL with borderRadius', (tester) async {
    await pumpWidget(
      tester,
      RobustNetworkImage(
        cacheService: cache.service,
        imageUrl: '',
        width: 200,
        height: 200,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
    );

    expect(find.byType(ClipRRect), findsOneWidget);
  });

  testWidgets('uses one injected cache and sizes decoding to physical pixels', (tester) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpWidget(
      tester,
      RobustNetworkImage(
        cacheService: cache.service,
        imageUrl: 'https://example.com/decode.jpg',
        width: 120,
        height: 80,
      ),
    );
    final image = tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
    expect(image.cacheManager, same(cache));
    expect(image.memCacheWidth, 240);
    expect(image.memCacheHeight, 160);
  });

  testWidgets('reduced motion disables both photo fades', (tester) async {
    await pumpWidget(
      tester,
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: RobustNetworkImage(
          cacheService: cache.service,
          imageUrl: 'https://example.com/reduced-motion.jpg',
          width: 120,
          height: 80,
        ),
      ),
    );
    final image = tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
    expect(image.fadeInDuration, Duration.zero);
    expect(image.fadeOutDuration, Duration.zero);
  });

  testWidgets('bounds explicit decode dimensions', (tester) async {
    await pumpWidget(
      tester,
      RobustNetworkImage(
        cacheService: cache.service,
        imageUrl: 'https://example.com/large.jpg',
        memCacheWidth: 8000,
        memCacheHeight: 8000,
      ),
    );
    final image = tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
    expect(image.memCacheWidth, 2048);
    expect(image.memCacheHeight, 2048);
  });

  testWidgets('image failure has an explicit retry using the same cache', (tester) async {
    cache.response = (_) => Stream<FileResponse>.error(StateError('offline'));
    const url = 'https://example.com/retry.jpg';
    await pumpWidget(
      tester,
      RobustNetworkImage(cacheService: cache.service, imageUrl: url, width: 200, height: 200),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(findKnife(KnifeIcon.retry), findsOneWidget);
    cache.response = (_) => const Stream<FileResponse>.empty();
    await tester.tap(findKnife(KnifeIcon.retry));
    await tester.pump();
    await tester.pump();
    expect(cache.removed, [url]);
    expect(cache.displayed, [url, url]);
    // Back to the loading slot while the retry runs.
    expect(findKnife(KnifeIcon.retry), findsNothing);
  });

  testWidgets('SVG failures use the same cache and have a local retry', (tester) async {
    const url = 'https://example.com/image.svg';
    await pumpWidget(
      tester,
      RobustNetworkImage(cacheService: cache.service, imageUrl: url, width: 200, height: 200),
    );
    await tester.pump();
    expect(cache.prefetched, [url]);
    expect(findKnife(KnifeIcon.retry), findsOneWidget);
    await tester.tap(findKnife(KnifeIcon.retry));
    await tester.pump();
    await tester.pump();
    expect(cache.removed, [url]);
    expect(cache.prefetched, [url, url]);
  });

  group('ImageLoadingService', () {
    test('isValidUrl returns true for valid http(s) URLs', () {
      expect(ImageLoadingService.isValidUrl('https://example.com/img.jpg'), isTrue);
      expect(ImageLoadingService.isValidUrl('http://example.com/img.jpg'), isTrue);
    });

    test('isValidUrl returns false for invalid URLs', () {
      expect(ImageLoadingService.isValidUrl(''), isFalse);
      expect(ImageLoadingService.isValidUrl('not-a-url'), isFalse);
      expect(ImageLoadingService.isValidUrl('ftp://example.com/img.jpg'), isFalse);
    });

    test('getValidImageUrl returns null for null or empty input', () {
      expect(ImageLoadingService.getValidImageUrl(null), isNull);
      expect(ImageLoadingService.getValidImageUrl(''), isNull);
    });

    test('getValidImageUrl returns the URL when valid', () {
      expect(
        ImageLoadingService.getValidImageUrl('https://example.com/img.jpg'),
        'https://example.com/img.jpg',
      );
    });
  });
}
