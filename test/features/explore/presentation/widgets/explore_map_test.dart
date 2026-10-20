import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:ghar360/core/controllers/localization_controller.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/features/explore/presentation/widgets/explore_map.dart';
import 'package:ghar360/features/explore/presentation/widgets/property_marker_chip.dart';
import 'package:ghar360/features/properties/application/property_filters.dart';
import 'package:ghar360/features/properties/application/property_queries.dart';
import '../../../../helpers/explore_test_harness.dart';
import '../../../../helpers/fake_explore_map_platform.dart';
import '../../../../helpers/provider_test_app.dart';

void main() {
  late ExploreTestHarness harness;
  late MapLibrePlatform Function() original;
  FakeExploreMapPlatform? platform;
  setUp(() {
    harness = ExploreTestHarness();
    original = MapLibrePlatform.createInstance;
    MapLibrePlatform.createInstance = () => platform = FakeExploreMapPlatform();
  });
  tearDown(() async {
    MapLibrePlatform.createInstance = original;
    await harness.dispose();
  });
  void seed(List<int> ids) => harness.query.seed(
    PropertyPageState(phase: PropertyLoadPhase.content, items: ids.map(exploreProperty).toList()),
  );
  Future<void> pump(WidgetTester tester, {bool active = true}) async {
    await tester.pumpProviderApp(
      UncontrolledProviderScope(
        container: harness.container,
        child: Scaffold(
          body: TickerMode(
            enabled: active,
            child: const SizedBox(width: 400, height: 600, child: ExploreMap()),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  }

  Positioned chipPosition(WidgetTester tester) => tester.widget<Positioned>(
    find
        .ancestor(of: find.byType(PropertyMarkerChip).first, matching: find.byType(Positioned))
        .first,
  );
  testWidgets('constructs MapLibre and attaches style sources before moving camera', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byType(ExploreMap), findsOneWidget);
    expect(find.byType(MapLibreMap), findsOneWidget);
    expect(platform!.viewCreated, isTrue);
    expect(platform!.sourceIds, contains('explore-radius-source'));
    expect(platform!.sourceIds, contains('explore-properties-source'));
    expect(platform!.cameraMoves, isNotEmpty);
    await dispose(tester);
  });
  testWidgets('renders one projected price marker per property and selects on tap', (tester) async {
    seed([1, 2]);
    await pump(tester);
    expect(find.byType(PropertyMarkerChip), findsNWidgets(2));
    expect(find.text('₹50 L'), findsNWidgets(2));
    platform!.screenOffset = 120;
    platform!.onCameraMovePlatform(const CameraPosition(target: LatLng(28.6, 77.2), zoom: 12));
    await tester.pump();
    await tester.tap(find.text('₹50 L').last);
    await tester.pump();
    expect(harness.state.selectedId, 2);
    await dispose(tester);
  });
  testWidgets('no located properties renders no marker chips', (tester) async {
    await pump(tester);
    expect(find.byType(PropertyMarkerChip), findsNothing);
    await dispose(tester);
  });
  testWidgets('immutable items update adds markers without an explicit revision bridge', (
    tester,
  ) async {
    seed([1]);
    await pump(tester);
    expect(find.byType(PropertyMarkerChip), findsOneWidget);
    seed([1, 2]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(PropertyMarkerChip), findsNWidgets(2));
    await dispose(tester);
  });
  testWidgets('manual location, filter radius, and language changes refresh map data', (
    tester,
  ) async {
    seed([1]);
    await pump(tester);
    await harness.location.select(mumbai);
    await tester.pump(const Duration(milliseconds: 200));
    expect(harness.state.center, const LatLng(19.07, 72.87));
    await harness.container
        .read(propertyFiltersProvider.notifier)
        .update(PageType.explore, const UnifiedFilterModel(radiusKm: 25));
    await tester.pump(const Duration(milliseconds: 200));
    expect(harness.controller.currentRadius, 25);
    await harness.container.read(localizationProvider.notifier).changeLanguage('hi', 'IN');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('लाख'), findsOneWidget);
    expect(find.byType(ExploreMap), findsOneWidget);
    await dispose(tester);
  });
  Future<void> burst(WidgetTester tester, {int count = 8}) async {
    final fake = platform!..simulateProjectionLatency = true;
    fake.maxConcurrentToScreen = 0;
    const position = CameraPosition(target: LatLng(28.6, 77.2), zoom: 12);
    for (var index = 1; index <= count; index++) {
      fake.screenOffset = index * 10;
      fake.onCameraMovePlatform(position);
    }
    fake.screenOffset = 190;
    fake.onCameraMovePlatform(position);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('camera burst settles chips on the last position', (tester) async {
    seed([1]);
    await pump(tester);
    await burst(tester);
    expect(chipPosition(tester).left, 190 - 60);
    expect(chipPosition(tester).top, 190 - 28);
    await dispose(tester);
  });
  testWidgets('overlay projection does not run concurrent passes', (tester) async {
    seed([1, 2]);
    await pump(tester);
    await burst(tester, count: 12);
    expect(platform!.maxConcurrentToScreen, 1);
    await dispose(tester);
  });
  testWidgets('projection failure is contained and next event recovers', (tester) async {
    seed([1]);
    await pump(tester);
    platform!
      ..failProjection = true
      ..screenOffset = 100;
    const position = CameraPosition(target: LatLng(28.6, 77.2), zoom: 12);
    platform!.onCameraMovePlatform(position);
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
    platform!
      ..failProjection = false
      ..screenOffset = 150;
    platform!.onCameraMovePlatform(position);
    await tester.pump(const Duration(milliseconds: 200));
    expect(chipPosition(tester).left, 150 - 60);
    await dispose(tester);
  });
  testWidgets('selected marker keeps visual selection across rebuilds', (tester) async {
    seed([1]);
    harness.controller.selectProperty(exploreProperty(1));
    await pump(tester);
    expect(tester.widget<PropertyMarkerChip>(find.byType(PropertyMarkerChip)).isSelected, isTrue);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CustomPaint), findsWidgets);
    await dispose(tester);
  });
  testWidgets('inactive map ignores camera-driven search and disposes cleanly', (tester) async {
    seed([1]);
    await pump(tester, active: false);
    harness.controller.onCameraIdle(const LatLng(20, 72), 14);
    await tester.pump(const Duration(seconds: 1));
    expect(harness.device.addressCalls, 0);
    await dispose(tester);
  });
  testWidgets('same property ID with new coordinates refreshes native source', (tester) async {
    seed([1]);
    await pump(tester);
    harness.query.seed(
      PropertyPageState(
        phase: PropertyLoadPhase.content,
        items: [exploreProperty(1, latitude: 20)],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final data = platform!.geojson['explore-properties-source']!;
    expect((data['features'] as List).single['geometry']['coordinates'], [
      closeTo(77.2, 0.000001),
      20.0,
    ]);
    await dispose(tester);
  });
  testWidgets('reactivating a retained map resumes projection without another map instance', (
    tester,
  ) async {
    seed([1]);
    await pump(tester);
    final originalPlatform = platform;
    await pump(tester, active: false);
    platform!.screenOffset = 150;
    platform!.onCameraMovePlatform(const CameraPosition(target: LatLng(28.6, 77.2), zoom: 12));
    await tester.pump();
    await pump(tester, active: true);
    expect(platform, same(originalPlatform));
    expect(chipPosition(tester).left, 150 - 60);
    await dispose(tester);
  });
}
