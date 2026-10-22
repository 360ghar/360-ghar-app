@TestOn('mac-os')
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:file/local.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/discover/presentation/views/discover_view.dart';
import 'package:ghar360/features/explore/presentation/views/explore_view.dart';
import 'package:ghar360/features/likes/presentation/views/likes_view.dart';
import 'package:ghar360/features/properties/application/property_location.dart';
import 'package:ghar360/features/properties/application/property_queries.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../helpers/fake_explore_map_platform.dart';
import '../helpers/layout_variants.dart';
import '../helpers/load_app_fonts.dart';
import '../helpers/property_query_test_support.dart';
import '../helpers/property_screen_harness.dart';

/// Only the native surface is replaced. Flutter markers, camera controls, list,
/// recovery banners and search are the application widgets. This fixture does
/// not establish native map rendering, GPS accuracy or permission behavior.
class _VisualMapPlatform extends FakeExploreMapPlatform {
  @override
  Widget buildView(
    Map<String, dynamic> creationParams,
    OnPlatformViewCreatedCallback onPlatformViewCreated,
    Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers,
  ) {
    super.buildView(creationParams, onPlatformViewCreated, gestureRecognizers);
    return Builder(
      builder: (context) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: const Center(
          child: Text(
            'Native map surface\nnot rendered in widget tests',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11),
          ),
        ),
      ),
    );
  }

  @override
  Future<math.Point> toScreenLocation(LatLng location) async => math.Point(
    location.latitude > 28.61 ? 235.0 : 100.0,
    location.latitude > 28.61 ? 190.0 : 115.0,
  );
}

PropertyModel _property(int id, {bool liked = false}) => PropertyModel(
  id: id,
  title: id == 1 ? 'Garden Court Residence' : 'Parkside Family Apartment',
  basePrice: id == 1 ? 8500000 : 6400000,
  propertyType: PropertyType.apartment,
  purpose: PropertyPurpose.buy,
  bedrooms: 3,
  bathrooms: 2,
  areaSqft: 1450,
  city: 'Gurugram',
  state: 'Haryana',
  fullAddress: 'Sector 57, Gurugram, Haryana',
  mainImageUrl: 'https://visual-fixture.invalid/property-$id.jpg',
  latitude: id == 1 ? 28.60 : 28.63,
  longitude: 77.20,
  isAvailable: true,
  viewCount: 24,
  likeCount: 8,
  liked: liked,
  interestCount: 3,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);
  final originalMap = MapLibrePlatform.createInstance;
  setUp(() => MapLibrePlatform.createInstance = _VisualMapPlatform.new);
  tearDown(() => MapLibrePlatform.createInstance = originalMap);

  for (final screen in ['discover', 'saved', 'explore']) {
    for (final state in ['content', 'loading', 'partial_failure', 'empty', 'error']) {
      for (final dark in [false, true]) {
        for (final size in [
          '390_en_1x',
          '320_hi_2x',
          if (state == 'content') '834_en_1x',
          // Wide and Duo windows: content, light only.
          if (state == 'content' && !dark) ...[for (final v in layoutVariants) v.name],
        ]) {
          final compact = size == '320_hi_2x';
          final layout = layoutVariants.where((v) => v.name == size).firstOrNull;
          final name = '${screen}_${state}_${dark ? 'dark' : 'light'}_$size';
          testWidgets(name, (tester) async {
            final locale = compact ? const Locale('hi', 'IN') : const Locale('en', 'US');
            final data = (await tester.runAsync(
              () => PropertyQueryHarness.create(
                legacy: {'language_code': locale.languageCode, 'country_code': locale.countryCode},
              ),
            ))!;
            final feed = switch (screen) {
              'discover' => PropertyFeed.discover,
              'saved' => PropertyFeed.liked,
              _ => PropertyFeed.explore,
            };
            final page = PropertyPageState(
              phase: switch (state) {
                'loading' => PropertyLoadPhase.loading,
                'empty' => PropertyLoadPhase.empty,
                'error' => PropertyLoadPhase.failure,
                _ => PropertyLoadPhase.content,
              },
              items: ['loading', 'empty', 'error'].contains(state)
                  ? []
                  : [
                      _property(1, liked: screen == 'saved'),
                      _property(2, liked: screen == 'saved'),
                    ],
              error: switch (state) {
                'partial_failure' => NetworkException('offline'),
                'error' => ServerException('private'),
                _ => null,
              },
            );
            final harness = PropertyScreenHarness(data, pages: {feed: page});
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
            if (screen == 'explore' && state == 'loading') {
              (harness.container.read(propertyLocationProvider(PageType.explore).notifier)
                      as QueryLocation)
                  .replace(null);
            }
            final view = switch (screen) {
              'discover' => const DiscoverView(),
              'saved' => const LikesView(),
              _ => const ExploreView(),
            };
            const boundary = ValueKey('visual.screen');
            await harness.pump(
              tester,
              RepaintBoundary(key: boundary, child: view),
              size: switch (size) {
                '834_en_1x' => const Size(834, 1112),
                '320_hi_2x' => const Size(320, 844),
                '390_en_1x' => const Size(390, 844),
                _ => layout!.size,
              },
              padding: layout?.padding ?? EdgeInsets.zero,
              scale: compact ? 2 : 1,
              dark: dark,
              locale: locale,
            );
            if (state == 'content' || state == 'partial_failure') {
              await settleFixturePhotos(tester);
              expect(
                find.byType(CircularProgressIndicator),
                findsNothing,
                reason: 'Content snapshots must include decoded fixture photos.',
              );
            }
            expect(find.textContaining('private'), findsNothing);
            await expectLater(find.byKey(boundary), matchesGoldenFile('goldens/$name.png'));
            if (screen == 'discover' && state == 'partial_failure' && compact) {
              final scrollable = find.descendant(
                of: find.byKey(const ValueKey('discover.scroll.1')),
                matching: find.byType(Scrollable),
              );
              final detailsAction = find.text('विवरण देखें');
              await tester.scrollUntilVisible(detailsAction, 200, scrollable: scrollable);
              expect(detailsAction.hitTestable(), findsOneWidget);
              await tester.pump(const Duration(milliseconds: 200));
              await expectLater(
                find.byKey(boundary),
                matchesGoldenFile('goldens/${name}_after_scroll.png'),
              );
            }
            await harness.close(tester);
          });
        }
      }
    }
  }
}
