import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/controllers/localization_controller.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/data/ports/swipes_port.dart';
import 'package:ghar360/core/map/map_controller.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/explore/presentation/controllers/explore_controller.dart';
import 'package:ghar360/features/explore/presentation/controllers/explore_property_markers.dart';
import 'package:ghar360/features/location/application/location_source.dart';
import 'package:ghar360/features/properties/application/property_filters.dart';
import 'package:ghar360/features/properties/application/property_location.dart';
import 'package:ghar360/features/properties/application/property_queries.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../../helpers/explore_test_harness.dart';

Future<void> flush() => Future<void>.delayed(Duration.zero);
void main() {
  late ExploreTestHarness harness;
  setUp(() => harness = ExploreTestHarness());
  tearDown(() => harness.dispose());
  test('provider replaces binding registration and starts with saved location', () {
    expect(harness.controller, isA<ExploreController>());
    expect(harness.state.center, const LatLng(28.6, 77.2));
    expect(harness.state.zoom, 12);
    expect(harness.state.selectedId, isNull);
    expect(harness.state.collapsed, isFalse);
  });
  test('no saved location uses default center without pretending a GPS fix', () async {
    final empty = ExploreTestHarness(located: false);
    addTearDown(empty.dispose);
    expect(empty.state.center, const LatLng(28.6139, 77.2090));
    expect(empty.container.read(propertyLocationProvider(PageType.explore)).location, isNull);
  });
  for (final entry in [
    (PropertyLoadPhase.idle, ExploreState.initial),
    (PropertyLoadPhase.loading, ExploreState.loading),
    (PropertyLoadPhase.content, ExploreState.loaded),
    (PropertyLoadPhase.empty, ExploreState.empty),
    (PropertyLoadPhase.paginating, ExploreState.loadingMore),
    (PropertyLoadPhase.failure, ExploreState.error),
  ]) {
    test('page phase ${entry.$1} maps to view state without duplicate data', () {
      final properties = entry.$1 == PropertyLoadPhase.content
          ? [exploreProperty(1)]
          : <PropertyModel>[];
      harness.query.seed(
        PropertyPageState(
          phase: entry.$1,
          items: properties,
          error: entry.$1 == PropertyLoadPhase.failure ? NetworkException('offline') : null,
        ),
      );
      expect(harness.controller.viewState, entry.$2);
      expect(harness.controller.properties, properties);
      expect(harness.controller.hasProperties, properties.isNotEmpty);
      expect(harness.controller.isLoading, entry.$1 == PropertyLoadPhase.loading);
      expect(harness.controller.isLoadingMore, entry.$1 == PropertyLoadPhase.paginating);
    });
  }
  test('refresh and failure retain existing property content', () {
    final rows = [exploreProperty(1)];
    for (final phase in [PropertyLoadPhase.refreshing, PropertyLoadPhase.content]) {
      harness.query.seed(
        PropertyPageState(
          phase: phase,
          items: rows,
          error: NetworkException('offline'),
          stale: true,
        ),
      );
      expect(harness.controller.properties.single.id, 1);
      expect(harness.controller.viewState, ExploreState.loaded);
      expect(harness.controller.error, isA<NetworkException>());
    }
  });
  test('selection expands list, highlighting preserves collapse, and clear removes selection', () {
    final first = exploreProperty(1);
    final second = exploreProperty(2);
    harness.query.seed(PropertyPageState(phase: PropertyLoadPhase.content, items: [first, second]));
    final controller = harness.controller;
    controller.collapseList();
    controller.selectProperty(first);
    expect(controller.isListCollapsed, isFalse);
    expect(controller.selectedProperty, same(first));
    controller.collapseList();
    controller.highlightPropertyFromCard(second);
    expect(controller.selectedProperty, same(second));
    expect(controller.isListCollapsed, isTrue);
    controller.highlightPropertyFromCard(second);
    expect(controller.selectedProperty, same(second));
    controller.expandList();
    controller.toggleListCollapsed();
    expect(controller.isListCollapsed, isTrue);
    controller.clearSelection();
    expect(controller.selectedProperty, isNull);
  });
  test('refresh retains selected ID while loading and clears missing selection after content', () {
    final property = exploreProperty(1);
    harness.query.seed(PropertyPageState(phase: PropertyLoadPhase.content, items: [property]));
    harness.controller.selectProperty(property);
    harness.query.seed(PropertyPageState(phase: PropertyLoadPhase.refreshing));
    expect(harness.state.selectedId, 1);
    harness.query.seed(
      PropertyPageState(phase: PropertyLoadPhase.content, items: [exploreProperty(2)]),
    );
    expect(harness.state.selectedId, isNull);
  });
  test(
    'search input and clear are stored immediately while query debounce is owned centrally',
    () async {
      await harness.controller.updateSearchQuery('park');
      expect(
        harness.container.read(propertyFiltersProvider).forPage(PageType.explore).searchQuery,
        'park',
      );
      await harness.controller.updateSearchQuery('lake');
      expect(
        harness.container.read(propertyFiltersProvider).forPage(PageType.explore).searchQuery,
        'lake',
      );
      await harness.controller.clearSearch();
      expect(
        harness.container.read(propertyFiltersProvider).forPage(PageType.explore).searchQuery,
        '',
      );
    },
  );
  test('quick filters preserve wire values and radius follows page filter state', () async {
    await harness.controller.quickFilterByType(PropertyType.house);
    await harness.controller.quickFilterByPurpose(PropertyPurpose.rent);
    final filter = harness.container.read(propertyFiltersProvider).forPage(PageType.explore);
    expect(filter.propertyType, ['house']);
    expect(filter.purpose, 'rent');
    await harness.container
        .read(propertyFiltersProvider.notifier)
        .update(PageType.explore, filter.copyWith(radiusKm: 25));
    expect(harness.controller.currentRadius, 25);
    await harness.container
        .read(propertyFiltersProvider.notifier)
        .update(PageType.explore, filter.copyWith(radiusKm: 100));
    expect(harness.controller.currentRadius, 50);
  });
  test('zoom controls clamp and signal programmatic camera revisions', () {
    final controller = harness.controller;
    controller.zoomIn();
    expect(controller.currentZoom, 13);
    expect(harness.state.cameraRevision, 1);
    controller.zoomOut();
    expect(controller.currentZoom, 12);
    for (var i = 0; i < 30; i++) {
      controller.zoomIn();
    }
    expect(controller.currentZoom, kDefaultMaxZoom);
    for (var i = 0; i < 30; i++) {
      controller.zoomOut();
    }
    expect(controller.currentZoom, kDefaultMinZoom);
  });
  test('fit bounds skips missing coordinates and preserves located properties', () {
    final controller = harness.controller;
    controller.fitBoundsToProperties();
    expect(harness.state.fitBounds, isFalse);
    harness.query.seed(
      PropertyPageState(
        phase: PropertyLoadPhase.content,
        items: [
          exploreProperty(1, latitude: null, longitude: null),
          exploreProperty(2),
          exploreProperty(3, latitude: 95),
          exploreProperty(4, longitude: double.nan),
        ],
      ),
    );
    expect(controller.propertiesWithLocation.map((p) => p.id), [2]);
    controller.fitBoundsToProperties();
    expect(harness.state.fitBounds, isTrue);
    expect(harness.state.cameraRevision, 1);
  });
  test(
    'marker provider caches immutable lists and rebuilds selection, prices, and locale',
    () async {
      harness.query.seed(
        PropertyPageState(
          phase: PropertyLoadPhase.content,
          items: [exploreProperty(1), exploreProperty(2, latitude: null, longitude: null)],
        ),
      );
      final first = harness.container.read(exploreMarkersProvider);
      expect(first.map((m) => m.property.id), [1]);
      expect(first.single.label, '₹50 L');
      expect(harness.container.read(exploreMarkersProvider), same(first));
      expect(() => first.clear(), throwsUnsupportedError);
      harness.controller.selectProperty(exploreProperty(1));
      expect(harness.container.read(exploreMarkersProvider).single.isSelected, isTrue);
      await harness.container.read(localizationProvider.notifier).changeLanguage('hi', 'IN');
      expect(harness.container.read(exploreMarkersProvider).single.label, contains('लाख'));
      harness.query.seed(
        PropertyPageState(
          phase: PropertyLoadPhase.content,
          items: [exploreProperty(1, price: 20000000)],
        ),
      );
      expect(harness.container.read(exploreMarkersProvider).single.label, contains('करोड़'));
    },
  );
  test('marker builder rejects invalid coordinates and uses effective prices', () {
    const builder = ExplorePropertyMarkers();
    final markers = builder.build(
      properties: [
        exploreProperty(1, latitude: double.nan),
        exploreProperty(2, latitude: 91),
        exploreProperty(3, longitude: 181),
        exploreProperty(4, price: 0),
        exploreProperty(5, price: 999),
      ],
      selectedPropertyId: null,
    );
    expect(markers.map((m) => m.property.id), [4, 5]);
    expect(markers.first.label, '₹--');
    expect(markers.last.label, '₹999');
  });
  test('likes use backend intent overlay and failure restores prior state', () async {
    final property = exploreProperty(1);
    expect(harness.controller.isPropertyLiked(property), isFalse);
    expect(await harness.controller.toggleLike(property), isTrue);
    expect(harness.controller.isPropertyLiked(property), isTrue);
    harness.swipes.response = (_, _) async => throw NetworkException('offline');
    expect(await harness.controller.toggleLike(property), isFalse);
    expect(harness.controller.isPropertyLiked(property), isTrue);
    expect(harness.history.failures[1], isA<NetworkException>());
    expect(harness.controller.isPropertyLiked(exploreProperty(2, liked: true)), isTrue);
  });
  test('rapid reverse like ignores stale failure from previous intent', () async {
    final pending = Completer<SwipeOutcome>();
    harness.swipes.response = (_, liked) =>
        liked ? pending.future : Future.value(const ConfirmedSwipe());
    final property = exploreProperty(1);
    final first = harness.controller.toggleLike(property);
    final last = harness.controller.toggleLike(property);
    expect(harness.controller.isPropertyLiked(property), isFalse);
    pending.completeError(NetworkException('first failed'));
    expect(await first, isFalse);
    expect(await last, isTrue);
    expect(harness.controller.isPropertyLiked(property), isFalse);
    expect(harness.history.failures, isEmpty);
  });
  test('refresh retry and pagination delegate to authoritative query state', () async {
    await harness.controller.refreshProperties();
    await harness.controller.retryLoading();
    expect(harness.query.refreshCalls, 2);
    await harness.controller.loadMoreProperties();
    expect(harness.query.loadMoreCalls, 0);
    harness.query.seed(PropertyPageState(phase: PropertyLoadPhase.content, nextCursor: 'next'));
    expect(harness.controller.hasMore, isTrue);
    await harness.controller.loadMoreProperties();
    expect(harness.query.loadMoreCalls, 1);
    for (final phase in [PropertyLoadPhase.loading, PropertyLoadPhase.paginating]) {
      harness.query.seed(PropertyPageState(phase: phase, nextCursor: 'next'));
      await harness.controller.loadMoreProperties();
    }
    expect(harness.query.loadMoreCalls, 1);
  });
  test('saved location changes update camera and small jitter does not move camera', () async {
    final controller = harness.controller;
    await harness.location.select(mumbai);
    expect(controller.currentCenter, const LatLng(19.07, 72.87));
    final revision = harness.state.cameraRevision;
    await harness.location.select(
      const LocationData(name: 'nearby', latitude: 19.070001, longitude: 72.87),
    );
    expect(harness.state.cameraRevision, revision);
  });
  test(
    'recenter uses explicit GPS/IP source and retains manual location when unavailable',
    () async {
      await harness.location.select(mumbai);
      harness.device.response = () async => const LocationResolution(delhi, LocationSource.ip);
      await harness.controller.recenterToCurrentLocation();
      expect(
        harness.container.read(propertyLocationProvider(PageType.explore)).source,
        LocationSource.ip,
      );
      expect(harness.state.center, const LatLng(28.6, 77.2));
      harness.device.response = () async => throw LocationException('offline');
      await harness.controller.recenterToCurrentLocation();
      expect(harness.state.center, const LatLng(28.6, 77.2));
      expect(
        harness.container.read(propertyLocationProvider(PageType.explore)).load.hasError,
        isTrue,
      );
    },
  );
  testWidgets('small or programmatic camera moves do not query; gesture movement is debounced', (
    tester,
  ) async {
    final controller = harness.controller;
    await tester.pump();
    controller.onCameraIdle(const LatLng(28.60001, 77.2), 12);
    await tester.pump(const Duration(seconds: 1));
    expect(harness.device.addressCalls, 0);
    controller.onCameraIdle(const LatLng(20, 72), 14, programmatic: true);
    await tester.pump(const Duration(seconds: 1));
    expect(controller.currentCenter, const LatLng(20, 72));
    expect(harness.device.addressCalls, 0);
    controller.onCameraIdle(const LatLng(21, 72), 14);
    controller.onCameraIdle(const LatLng(22, 72), 15);
    await tester.pump(const Duration(milliseconds: 599));
    expect(harness.device.addressCalls, 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(harness.device.addressCalls, 1);
    expect(
      harness.container.read(propertyLocationProvider(PageType.explore)).location?.latitude,
      22,
    );
  });
  testWidgets('manual selection and inactive tab reject pending camera geocode', (tester) async {
    final controller = harness.controller;
    await tester.pump();
    final pending = Completer<String>();
    harness.device.addressResponse = (_, _) => pending.future;
    controller.onCameraIdle(const LatLng(20, 72), 14);
    await tester.pump(const Duration(milliseconds: 600));
    await harness.location.select(mumbai);
    pending.complete('Old map');
    await tester.pump();
    expect(harness.state.center, const LatLng(19.07, 72.87));
    final inactive = Completer<String>();
    harness.device.addressResponse = (_, _) => inactive.future;
    controller.onCameraIdle(const LatLng(23, 73), 14);
    await tester.pump(const Duration(milliseconds: 600));
    controller.setVisible(false);
    inactive.complete('Inactive map');
    await tester.pump();
    expect(
      harness.container.read(propertyLocationProvider(PageType.explore)).location?.name,
      'Mumbai',
    );
    expect(harness.state.cameraUpdate.isLoading, isFalse);
  });
  testWidgets('camera failure exposes retry while preserving selected location', (tester) async {
    final controller = harness.controller;
    await tester.pump();
    harness.device.addressResponse = (_, _) async => throw NetworkException('lookup failed');
    controller.onCameraIdle(const LatLng(21, 72), 14);
    await tester.pump(const Duration(milliseconds: 600));
    expect(harness.state.cameraUpdate.hasError, isTrue);
    expect(
      harness.container.read(propertyLocationProvider(PageType.explore)).location?.name,
      'Delhi',
    );
    harness.device.addressResponse = (_, _) async => 'New area';
    await controller.retryCameraSearch();
    expect(harness.state.cameraUpdate.hasError, isFalse);
    expect(
      harness.container.read(propertyLocationProvider(PageType.explore)).location?.name,
      'New area',
    );
  });
  testWidgets('account switch and disposal cancel camera timers and old results', (tester) async {
    final controller = harness.controller;
    await tester.pump();
    controller.onCameraIdle(const LatLng(20, 72), 14);
    harness.changeAccount('b');
    harness.state;
    await tester.pump(const Duration(seconds: 1));
    expect(harness.device.addressCalls, 0);
    controller.onCameraIdle(const LatLng(21, 72), 14);
    harness.container.dispose();
    await tester.pump(const Duration(seconds: 1));
    expect(harness.device.addressCalls, 0);
  });
}
