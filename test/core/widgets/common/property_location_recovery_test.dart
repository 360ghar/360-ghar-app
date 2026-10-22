import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/utils/image_cache_service.dart';
import 'package:ghar360/core/widgets/common/location_selector.dart';
import 'package:ghar360/core/widgets/common/property_location_recovery.dart';
import 'package:ghar360/features/discover/presentation/views/discover_view.dart';
import 'package:ghar360/features/discover/presentation/widgets/property_swipe_stack.dart';
import 'package:ghar360/features/explore/presentation/views/explore_view.dart';
import 'package:ghar360/features/explore/presentation/widgets/explore_map.dart';
import 'package:ghar360/features/likes/presentation/views/likes_view.dart';
import 'package:ghar360/features/location/application/location_backend_sync.dart';
import 'package:ghar360/features/location/application/location_search_controller.dart';
import 'package:ghar360/features/location/application/location_source.dart';
import 'package:ghar360/features/properties/application/property_location.dart';
import 'package:ghar360/features/properties/application/property_queries.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../helpers/explore_test_harness.dart';
import '../../../helpers/fake_explore_map_platform.dart';
import '../../../helpers/image_test_cache.dart';
import '../../../helpers/location_test_harness.dart';
import '../../../helpers/property_query_test_support.dart';
import '../../../helpers/provider_test_app.dart';

class _RecoveryDatabase extends ExploreDatabase {
  @override
  Future<CachedEntry?> readCache({
    required StorageScope scope,
    required String key,
    int expectedSchemaVersion = 1,
    DateTime? now,
  }) async => null;

  @override
  Future<void> writeCache({
    required StorageScope scope,
    required String key,
    required Object? value,
    required DateTime freshUntil,
    required DateTime expiresAt,
    String? etag,
    int schemaVersion = 1,
    DateTime? createdAt,
  }) async {}
}

void main() {
  late ProviderContainer container;
  late ExploreDevice device;
  late QueryProperties properties;
  late QuerySwipes swipes;
  late MapLibrePlatform Function() originalMapFactory;

  setUp(() {
    final database = _RecoveryDatabase();
    device = ExploreDevice()
      ..response = () async => throw LocationException('private GPS diagnostics');
    properties = QueryProperties();
    swipes = QuerySwipes();
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        storageScopeProvider.overrideWith(() => LocationScopeNotifier(database)),
        deviceLocationSourceProvider.overrideWithValue(device),
        locationBackendSyncProvider.overrideWithValue(LocationBackendSync(send: null)),
        googlePlacesServiceProvider.overrideWithValue(LocationTestPlaces()),
        propertiesRepositoryProvider.overrideWithValue(properties),
        swipesRepositoryProvider.overrideWithValue(swipes),
        imageCacheServiceProvider.overrideWithValue(ImageTestCache().service),
      ],
    );
    originalMapFactory = MapLibrePlatform.createInstance;
    MapLibrePlatform.createInstance = FakeExploreMapPlatform.new;
  });
  tearDown(() async {
    MapLibrePlatform.createInstance = originalMapFactory;
    container.dispose();
    await device.stream.close();
  });

  int requestCount(PropertyFeed feed) =>
      feed.isHistory ? swipes.requests.length : properties.requests.length;

  Future<void> pump(WidgetTester tester, PropertyFeed feed) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpProviderApp(
      UncontrolledProviderScope(
        container: container,
        child: switch (feed) {
          PropertyFeed.discover => const DiscoverView(),
          PropertyFeed.explore => const ExploreView(),
          _ => const LikesView(),
        },
      ),
    );
    await tester.pumpAndSettle();
  }

  void expectContent(PropertyFeed feed) {
    expect(container.read(propertyQueryProvider(feed)).items.single.id, 1);
    expect(container.read(propertyQueryProvider(feed)).error, isNull);
    if (feed == PropertyFeed.discover) {
      expect(find.byType(PropertySwipeStack), findsOneWidget);
    } else if (feed == PropertyFeed.explore) {
      expect(find.byType(ExploreMap), findsOneWidget);
    }
    expect(find.text('Property 1'), findsWidgets);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  for (final feed in [PropertyFeed.discover, PropertyFeed.explore, PropertyFeed.liked]) {
    testWidgets('${feed.name} missing location opens manual picker and loads selected area', (
      tester,
    ) async {
      await pump(tester, feed);
      expect(device.currentCalls, 1);
      expect(requestCount(feed), 0);
      expect(find.textContaining('private GPS'), findsNothing);
      expect(find.text('Unable to get current location'), findsOneWidget);
      await tester.tap(find.byKey(ValueKey('qa.${feed.page.name}.location.select')));
      await tester.pumpAndSettle();
      expect(find.byType(LocationPickerModal), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'Delhi');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      final result = find.text('Delhi').last;
      await tester.ensureVisible(result);
      await tester.tap(result);
      await tester.pumpAndSettle();
      expect(find.byType(LocationPickerModal), findsNothing);
      expect(container.read(propertyLocationProvider(feed.page)).source, LocationSource.manual);
      expect(device.currentCalls, 1);
      expect(requestCount(feed), 1);
      expectContent(feed);
      await unmount(tester);
    });

    testWidgets('${feed.name} skipped location prompt shows a neutral choose-an-area message', (
      tester,
    ) async {
      device.response = () async =>
          throw LocationException('not asked', code: 'LOCATION_NOT_ASKED');
      await pump(tester, feed);
      expect(find.text('Choose an area to see homes near you'), findsOneWidget);
      expect(find.text('Unable to get current location'), findsNothing);
      await unmount(tester);
    });

    testWidgets(
      '${feed.name} GPS retry waits for location before requesting and restores content',
      (tester) async {
        await pump(tester, feed);
        final pending = Completer<LocationResolution>();
        device.response = () => pending.future;
        final retry = find.byKey(ValueKey('qa.${feed.page.name}.location.gps_retry'));
        await tester.tap(retry);
        await tester.pump();
        expect(device.currentCalls, 2);
        expect(requestCount(feed), 0);
        expect(tester.widget<TextButton>(retry).onPressed, isNull);
        pending.complete(const LocationResolution(delhi, LocationSource.gps));
        await tester.pumpAndSettle();
        expect(container.read(propertyLocationProvider(feed.page)).source, LocationSource.gps);
        expect(requestCount(feed), 1);
        expect(find.byType(PropertyLocationRecovery), findsNothing);
        expectContent(feed);
        await unmount(tester);
      },
    );

    testWidgets('${feed.name} GPS failure retains loaded content with manual recovery', (
      tester,
    ) async {
      device.response = () async => const LocationResolution(delhi, LocationSource.gps);
      await pump(tester, feed);
      expectContent(feed);
      final requests = requestCount(feed);
      device.response = () async => throw LocationException('denied', code: 'LOCATION_DENIED');
      await container.read(propertyLocationProvider(feed.page).notifier).useCurrent();
      await tester.pumpAndSettle();
      expectContent(feed);
      expect(requestCount(feed), requests);
      expect(find.text('Location permission denied'), findsOneWidget);
      expect(
        tester.widget<PropertyLocationRecovery>(find.byType(PropertyLocationRecovery)).inline,
        isTrue,
      );
      await tester.tap(find.byKey(ValueKey('qa.${feed.page.name}.location.select')));
      await tester.pumpAndSettle();
      expect(find.byType(LocationPickerModal), findsOneWidget);
      await unmount(tester);
    });
  }

  for (final dark in [false, true]) {
    for (final hindi in [false, true]) {
      testWidgets('recovery actions fit narrow 2x text, dark=$dark, Hindi=$hindi', (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await container.read(propertyLocationProvider(PageType.discover).notifier).ensureLocation();
        await tester.pumpProviderApp(
          UncontrolledProviderScope(
            container: container,
            child: const Scaffold(body: PropertyLocationRecovery(pageType: PageType.discover)),
          ),
          theme: dark ? ThemeData.dark() : ThemeData.light(),
          locale: Locale(hindi ? 'hi' : 'en', 'IN'),
          textScale: 2,
        );
        await tester.pumpAndSettle();
        expect(find.text(hindi ? 'GPS फिर से आज़माएँ' : 'Retry GPS'), findsOneWidget);
        for (final action in ['select', 'gps_retry']) {
          final button = find.byKey(ValueKey('qa.discover.location.$action'));
          expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
        }
        expect(tester.takeException(), isNull);
        await unmount(tester);
      });
    }
  }
}
