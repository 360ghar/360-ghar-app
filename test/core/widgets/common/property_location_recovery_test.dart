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
    testWidgets(
      '${feed.name} unresolved automatic location starts in Gurugram and can be changed',
      (tester) async {
        await pump(tester, feed);
        expect(device.currentCalls, 1);
        expect(find.textContaining('private GPS'), findsNothing);
        expect(find.text('Unable to get current location'), findsNothing);
        final state = container.read(propertyLocationProvider(feed.page));
        expect(state.source, LocationSource.fallback);
        expect(state.location?.name, 'Gurugram');
        expect(requestCount(feed), 1);
        expectContent(feed);
        expect(
          find.text('Homes are in Gurugram for now'),
          feed == PropertyFeed.discover ? findsOneWidget : findsNothing,
        );
        await tester.tap(find.byKey(ValueKey('qa.location.selector.trigger.${feed.page.name}')));
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
        expect(requestCount(feed), 2);
        expect(find.text('Homes are in Gurugram for now'), findsNothing);
        await unmount(tester);
      },
    );

    testWidgets('${feed.name} skipped location prompt starts in Gurugram without an error', (
      tester,
    ) async {
      device.response = () async =>
          throw LocationException('not asked', code: 'LOCATION_NOT_ASKED');
      await pump(tester, feed);
      expect(container.read(propertyLocationProvider(feed.page)).source, LocationSource.fallback);
      expect(find.text('Choose an area to see homes near you'), findsNothing);
      expect(find.text('Unable to get current location'), findsNothing);
      expectContent(feed);
      await unmount(tester);
    });

    testWidgets('${feed.name} an explicit read that fails keeps the Gurugram fallback', (
      tester,
    ) async {
      device.response = () async =>
          throw LocationException('not asked', code: 'LOCATION_NOT_ASKED');
      await pump(tester, feed);
      await container.read(propertyLocationProvider(feed.page).notifier).useCurrent();
      await tester.pumpAndSettle();
      final state = container.read(propertyLocationProvider(feed.page));
      expect(state.source, LocationSource.fallback);
      expect(state.load.hasError, isTrue);
      if (feed == PropertyFeed.discover) {
        // Discover: an unasked permission is a choice. Gurugram homes, the
        // quiet line and its Change action, no recovery box.
        expect(find.byType(PropertyLocationRecovery), findsNothing);
        expect(find.text('Homes are in Gurugram for now'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('qa.discover.out_of_area.change')));
        await tester.pumpAndSettle();
        expect(
          tester.widget<LocationPickerModal>(find.byType(LocationPickerModal)).pageType,
          PageType.discover,
        );
      } else {
        expect(find.text('Choose an area to see homes near you'), findsOneWidget);
      }
      await unmount(tester);
    });

    testWidgets('${feed.name} GPS read waits for location and restores content', (tester) async {
      await pump(tester, feed);
      final pending = Completer<LocationResolution>();
      device.response = () => pending.future;
      final read = container.read(propertyLocationProvider(feed.page).notifier).useCurrent();
      await tester.pump();
      expect(device.currentCalls, 2);
      pending.complete(const LocationResolution(delhi, LocationSource.gps));
      await read;
      await tester.pumpAndSettle();
      expect(container.read(propertyLocationProvider(feed.page)).source, LocationSource.gps);
      expect(find.byType(PropertyLocationRecovery), findsNothing);
      expectContent(feed);
      await unmount(tester);
    });

    testWidgets('${feed.name} Retry GPS waits for location and restores content', (tester) async {
      // A page that is not visible has not started its own read yet.
      final location = container.read(propertyLocationProvider(feed.page).notifier);
      await location.useCurrent();
      location.setVisible(false);
      await pump(tester, feed);
      final retry = find.byKey(ValueKey('qa.${feed.page.name}.location.gps_retry'));
      expect(find.text('Unable to get current location'), findsOneWidget);
      final pending = Completer<LocationResolution>();
      device.response = () => pending.future;
      await tester.tap(retry);
      await tester.pump();
      expect(tester.widget<TextButton>(retry).onPressed, isNull);
      pending.complete(const LocationResolution(delhi, LocationSource.gps));
      await tester.pumpAndSettle();
      expect(container.read(propertyLocationProvider(feed.page)).source, LocationSource.gps);
      expect(find.byType(PropertyLocationRecovery), findsNothing);
      expectContent(feed);
      await unmount(tester);
    });

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
      if (feed == PropertyFeed.discover) {
        // Discover keeps its homes with no warning; the location picker
        // explains a denial when the user asks for the current location there.
        expect(find.byType(PropertyLocationRecovery), findsNothing);
        expect(find.text('Location permission denied'), findsNothing);
        await unmount(tester);
        return;
      }
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

  testWidgets('a guest who declines the OS prompt sees Gurugram homes and the line', (
    tester,
  ) async {
    device
      ..undetermined = true
      // iOS reports a declined prompt as denied forever.
      ..response = () async => throw LocationException('blocked', code: 'LOCATION_DENIED_FOREVER');
    await pump(tester, PropertyFeed.discover);
    await tester.tap(find.byKey(const ValueKey('qa.location.explainer.allow')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('qa.location.explainer.allow')), findsNothing);
    // Continue reached the OS prompt; the earlier silent read did not.
    expect(device.prompts.last, isTrue);
    expect(find.byType(PropertyLocationRecovery), findsNothing);
    expect(find.text('Location permission permanently denied'), findsNothing);
    expect(find.byKey(const ValueKey('qa.discover.out_of_area.change')), findsOneWidget);
    expect(find.text('Choose an area to see homes near you'), findsNothing);
    expect(find.text('Unable to get current location'), findsNothing);
    expect(find.text('Homes are in Gurugram for now'), findsOneWidget);
    expectContent(PropertyFeed.discover);
    await unmount(tester);
  });

  for (final dark in [false, true]) {
    for (final hindi in [false, true]) {
      testWidgets('recovery actions fit narrow 2x text, dark=$dark, Hindi=$hindi', (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await container.read(propertyLocationProvider(PageType.discover).notifier).useCurrent();
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
