import 'package:flutter/material.dart';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/features/property_details/presentation/widgets/fullscreen_photo_gallery.dart';
import '../../../../helpers/image_test_cache.dart';
import '../../../../helpers/knife_finders.dart';

void main() {
  late ImageTestCache cache;
  setUp(() {
    cache = ImageTestCache();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });

  Future<void> pumpGallery(WidgetTester tester, List<String> images, {int initialIndex = 0}) =>
      tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: FullscreenPhotoGallery(
              images: images,
              initialIndex: initialIndex,
              heroTagPrefix: 'test',
              cacheService: cache.service,
            ),
          ),
        ),
      );

  testWidgets('empty gallery has a local fallback and can close', (tester) async {
    await pumpGallery(tester, []);
    expect(findKnife(KnifeIcon.camera), findsOneWidget);
    expect(findKnife(KnifeIcon.close), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('out-of-range starting page is bounded to available images', (tester) async {
    await pumpGallery(tester, [
      'https://example.com/1.jpg',
      'https://example.com/2.jpg',
    ], initialIndex: 10);
    await tester.pump();
    expect(find.text('2/2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed fullscreen image retries through the shared cache', (tester) async {
    const url = 'https://example.com/retry-fullscreen.jpg';
    cache.response = (_) => Stream<FileResponse>.error(StateError('offline'));
    await pumpGallery(tester, [url]);
    await tester.pump();
    expect(findKnife(KnifeIcon.retry), findsOneWidget);
    cache.response = (_) => const Stream<FileResponse>.empty();
    await tester.tap(findKnife(KnifeIcon.retry));
    await tester.pump();
    await tester.pump();
    expect(cache.removed, [url]);
    expect(cache.displayed, [url, url]);
    expect(findKnife(KnifeIcon.close), findsOneWidget);
  });
}
