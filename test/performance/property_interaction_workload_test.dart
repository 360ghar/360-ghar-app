import 'dart:convert';
import 'dart:io';

import 'package:file/local.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/features/discover/presentation/views/discover_view.dart';
import 'package:ghar360/features/discover/presentation/widgets/property_swipe_stack.dart';
import 'package:ghar360/features/likes/presentation/views/likes_view.dart';
import 'package:ghar360/features/properties/application/property_queries.dart';

import '../helpers/load_app_fonts.dart';
import '../helpers/property_query_test_support.dart';
import '../helpers/property_screen_harness.dart';

const _measuredWidgets = {
  'PropertySwipeStack',
  'PropertySwipeCard',
  'SwipeCardHeroSection',
  'SwipeCardDetailsSection',
  'PropertyListCard',
  'RobustNetworkImage',
};

PropertyModel _property(int id, {bool liked = false}) => PropertyModel(
  id: id,
  title: 'Garden Court Residence $id',
  description: 'A bright family apartment with generous living space and a private balcony.',
  basePrice: 8500000,
  propertyType: PropertyType.apartment,
  purpose: PropertyPurpose.buy,
  bedrooms: 3,
  bathrooms: 2,
  areaSqft: 1450,
  city: 'Gurugram',
  state: 'Haryana',
  fullAddress: 'Sector 57, Gurugram, Haryana',
  // One local photo identity makes decode cost deterministic as list items enter.
  mainImageUrl: 'https://performance-fixture.invalid/property.jpg',
  isAvailable: true,
  viewCount: 24,
  likeCount: 8,
  liked: liked,
  interestCount: 3,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);
  final samples = <Map<String, Object?>>[];

  for (final workload in [
    'discover_horizontal_drag',
    'discover_card_scroll',
    'saved_list_scroll',
  ]) {
    testWidgets('$workload records 30 pointer moves with decoded photos', (tester) async {
      final isSaved = workload == 'saved_list_scroll';
      final horizontal = workload == 'discover_horizontal_drag';
      final compact = workload == 'discover_card_scroll';
      final feed = isSaved ? PropertyFeed.liked : PropertyFeed.discover;
      final data = (await tester.runAsync(
        () => PropertyQueryHarness.create(
          legacy: {'language_code': compact ? 'hi' : 'en', 'country_code': compact ? 'IN' : 'US'},
        ),
      ))!;
      final harness = PropertyScreenHarness(
        data,
        pages: {
          feed: PropertyPageState(
            phase: PropertyLoadPhase.content,
            items: List.generate(isSaved ? 24 : 3, (index) => _property(index + 1, liked: isSaved)),
          ),
        },
      );
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      harness.images.response = (url) => Stream.value(
        FileInfo(
          const LocalFileSystem().file(
            '${Directory.current.path}/test/fixtures/images/property_photo.jpg',
          ),
          FileSource.Cache,
          DateTime(2030),
          url,
        ),
      );
      await harness.pump(
        tester,
        isSaved ? const LikesView() : const DiscoverView(),
        size: Size(compact ? 320 : 390, 844),
        scale: compact ? 2 : 1,
        locale: compact ? const Locale('hi', 'IN') : const Locale('en', 'US'),
      );
      await settleFixturePhotos(tester);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      final cache = PaintingBinding.instance.imageCache;
      expect(cache.currentSizeBytes, greaterThan(0));

      final target = isSaved ? find.byType(LikesView) : find.byType(PropertySwipeStack);
      final scrollable = tester.state<ScrollableState>(
        find.descendant(of: target, matching: find.byType(Scrollable)).first,
      );
      final initialOffset = scrollable.position.pixels;
      final cacheBytesBefore = cache.currentSizeBytes;
      final rebuilds = {for (final name in _measuredWidgets) name: 0};
      final firstBuilds = {for (final name in _measuredWidgets) name: 0};
      var totalDirtyBuilds = 0;
      final priorCallback = debugOnRebuildDirtyWidget;
      final watch = Stopwatch();
      final gesture = await tester.startGesture(tester.getCenter(target));
      try {
        debugOnRebuildDirtyWidget = (element, builtOnce) {
          totalDirtyBuilds++;
          final name = element.widget.runtimeType.toString();
          if (_measuredWidgets.contains(name)) {
            final counts = builtOnce ? rebuilds : firstBuilds;
            counts[name] = counts[name]! + 1;
          }
          priorCallback?.call(element, builtOnce);
        };
        watch.start();
        for (var move = 0; move < 30; move++) {
          await gesture.moveBy(horizontal ? const Offset(3, 0) : const Offset(0, -8));
          await tester.pump(const Duration(milliseconds: 16));
        }
        watch.stop();
      } finally {
        debugOnRebuildDirtyWidget = priorCallback;
      }
      final finalOffset = scrollable.position.pixels;
      final sample = <String, Object?>{
        'workload': workload,
        'logicalSize': [compact ? 320 : 390, 844],
        'textScale': compact ? 2 : 1,
        'locale': compact ? 'hi-IN' : 'en-US',
        'pointerMoves': 30,
        'pumpCount': 30,
        'pumpDurationMs': 480,
        'wallTimeMicroseconds': watch.elapsedMicroseconds,
        'imageCacheBytesBefore': cacheBytesBefore,
        'imageCacheBytesAfter': cache.currentSizeBytes,
        'totalDirtyBuilds': totalDirtyBuilds,
        'selectedWidgetRebuilds': rebuilds,
        'selectedWidgetFirstBuilds': firstBuilds,
        'scrollOffsetBefore': initialOffset,
        'scrollOffsetAfter': finalOffset,
      };
      samples.add(sample);
      // The measurement window ends before release/snap-back or further scrolling.
      await gesture.cancel();
      await tester.pump(const Duration(milliseconds: 500));
      if (horizontal) {
        expect(finalOffset, initialOffset);
        expect(totalDirtyBuilds, greaterThan(0));
        expect(rebuilds['PropertySwipeCard'], 0);
        expect(rebuilds['SwipeCardHeroSection'], 0);
        expect(rebuilds['SwipeCardDetailsSection'], 0);
        expect(find.text('Garden Court Residence 1'), findsWidgets);
      } else {
        expect(finalOffset, greaterThan(initialOffset + 100));
      }
      if (compact) {
        // The 2x Hindi card continues below the first viewport; the primary
        // details action remains reachable by scrolling the actual card.
        final detailsAction = find.text('विवरण देखें');
        await tester.scrollUntilVisible(
          detailsAction,
          200,
          scrollable: find.descendant(of: target, matching: find.byType(Scrollable)).first,
        );
        expect(detailsAction.hitTestable(), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await harness.close(tester);
    });
  }

  tearDownAll(() async {
    if (!const bool.fromEnvironment('WRITE_INTERACTION_METRICS')) return;
    final file = File('build/verification/property-interaction-workload.json');
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'kind': 'Flutter debug widget-test workload; not device frame timings',
        'recordedAtUtc': DateTime.now().toUtc().toIso8601String(),
        'platform': Platform.operatingSystem,
        'dartVersion': Platform.version,
        'fixture': 'test/fixtures/images/property_photo.jpg',
        'fonts': ['Manrope', 'Erode', 'Noto Sans Devanagari', 'Noto Serif Devanagari'],
        'warmPhotoDecode': true,
        'reducedMotion': true,
        'measurementWindow':
            '30 pointer moves and 30 pumps; excludes mount, decode and pointer release',
        'samples': samples,
      }),
    );
  });
}
