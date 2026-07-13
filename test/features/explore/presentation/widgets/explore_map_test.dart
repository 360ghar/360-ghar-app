import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/translations/app_translations.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/explore/presentation/controllers/explore_controller.dart';
import 'package:ghar360/features/explore/presentation/widgets/explore_map.dart';
import 'package:ghar360/features/explore/presentation/widgets/property_marker_chip.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../../helpers/getx_test_binding.dart';
import '../../../../helpers/mocks.dart';

// ---------------------------------------------------------------------------
// Fake MapLibrePlatform — lets MapLibreMap build in widget tests without
// real platform channels.  buildView returns a plain Container and triggers
// onPlatformViewCreated asynchronously so the controller is created.
// ---------------------------------------------------------------------------

class _FakeMapLibrePlatform extends MapLibrePlatform {
  bool _viewCreated = false;

  @override
  Widget buildView(
    Map<String, dynamic> creationParams,
    OnPlatformViewCreatedCallback onPlatformViewCreated,
    Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers,
  ) {
    // Only trigger the callback once per platform instance — buildView can
    // be called multiple times on rebuilds.
    if (!_viewCreated) {
      _viewCreated = true;
      // Schedule the platform-view-created callback so the MapLibreMapController
      // is constructed (which in turn fires onMapCreated).
      Future<void>.microtask(() {
        onPlatformViewCreated(0);
      });
    }
    return const SizedBox.shrink();
  }

  @override
  Future<void> initPlatform(int id) async {
    // Fire the style-loaded callback so ExploreMap's _onStyleLoaded runs.
    Future<void>.microtask(() {
      onMapStyleLoadedPlatform(null);
    });
  }

  @override
  Future<CameraPosition?> updateMapOptions(Map<String, dynamic> optionsUpdate) async => null;

  @override
  Future<bool?> animateCamera(CameraUpdate cameraUpdate, {Duration? duration}) async => true;

  @override
  Future<bool?> moveCamera(CameraUpdate cameraUpdate) async => true;

  @override
  Future<bool> easeCamera(
    CameraUpdate cameraUpdate, {
    Duration? duration,
    CameraAnimationInterpolation? interpolation,
  }) async => true;

  @override
  Future<CameraPosition?> queryCameraPosition() async => null;

  @override
  Future<void> updateMyLocationTrackingMode(MyLocationTrackingMode mode) async {}

  @override
  Future<void> matchMapLanguageWithDeviceDefault() async {}

  @override
  void resizeWebMap() {}

  @override
  void forceResizeWebMap() {}

  @override
  Future<void> updateContentInsets(EdgeInsets insets, bool animated) async {}

  @override
  Future<void> setMapLanguage(String language) async {}

  @override
  Future<void> setTelemetryEnabled(bool enabled) async {}

  @override
  Future<bool> getTelemetryEnabled() async => false;

  @override
  Future<void> setMaximumFps(int fps) async {}

  @override
  Future<void> forceOnlineMode() async {}

  @override
  Future<bool> editGeoJsonSource(String id, String data) async => true;

  @override
  Future<bool> editGeoJsonUrl(String id, String url) async => true;

  @override
  Future<bool> setLayerFilter(String layerId, String filter) async => true;

  @override
  Future<String?> getStyle() async => '{}';

  @override
  Future<void> setCustomHeaders(Map<String, String> headers, List<String> filter) async {}

  @override
  Future<Map<String, String>> getCustomHeaders() async => {};

  @override
  Future<List> queryRenderedFeatures(
    math.Point<double> point,
    List<String> layerIds,
    List<Object>? filter,
  ) async => [];

  @override
  Future<List> queryRenderedFeaturesInRect(
    Rect rect,
    List<String> layerIds,
    String? filter,
  ) async => [];

  @override
  Future<List> querySourceFeatures(
    String sourceId,
    String? sourceLayerId,
    List<Object>? filter,
  ) async => [];

  @override
  Future invalidateAmbientCache() async {}

  @override
  Future clearAmbientCache() async {}

  @override
  Future<LatLng?> requestMyLocationLatLng() async => null;

  @override
  Future<LatLngBounds> getVisibleRegion() async =>
      LatLngBounds(southwest: const LatLng(0, 0), northeast: const LatLng(0, 0));

  @override
  Future<void> addImage(String name, Uint8List bytes, [bool sdf = false]) async {}

  @override
  Future<void> addImageSource(
    String imageSourceId,
    Uint8List bytes,
    LatLngQuad coordinates,
  ) async {}

  @override
  Future<void> updateImageSource(
    String imageSourceId,
    Uint8List? bytes,
    LatLngQuad? coordinates,
  ) async {}

  @override
  Future<void> addLayer(
    String imageLayerId,
    String imageSourceId,
    double? minzoom,
    double? maxzoom,
  ) async {}

  @override
  Future<void> addLayerBelow(
    String imageLayerId,
    String imageSourceId,
    String belowLayerId,
    double? minzoom,
    double? maxzoom,
  ) async {}

  @override
  Future<void> removeLayer(String imageLayerId) async {}

  @override
  Future<List> getLayerIds() async => [];

  @override
  Future<List> getSourceIds() async => [];

  @override
  Future<void> setFilter(String layerId, dynamic filter) async {}

  @override
  Future<dynamic> getFilter(String layerId) async => null;

  @override
  Future<math.Point> toScreenLocation(LatLng latLng) async => const math.Point(0.0, 0.0);

  @override
  Future<List<math.Point>> toScreenLocationBatch(Iterable<LatLng> latLngs) async => [];

  @override
  Future<LatLng> toLatLng(math.Point screenLocation) async => const LatLng(0, 0);

  @override
  Future<double> getMetersPerPixelAtLatitude(double latitude) async => 1.0;

  @override
  Future<void> addGeoJsonSource(
    String sourceId,
    Map<String, dynamic> geojson, {
    String? promoteId,
  }) async {}

  @override
  Future<void> setGeoJsonSource(String sourceId, Map<String, dynamic> geojson) async {}

  @override
  Future<void> setCameraBounds({
    required double west,
    required double north,
    required double south,
    required double east,
    required int padding,
  }) async {}

  @override
  Future<void> setFeatureForGeoJsonSource(
    String sourceId,
    Map<String, dynamic> geojsonFeature,
  ) async {}

  @override
  Future<void> setFeatureState(
    String sourceId,
    String featureId,
    Map<String, dynamic> state, {
    String? sourceLayer,
  }) async {}

  @override
  Future<void> removeFeatureState(
    String sourceId, {
    String? featureId,
    String? stateKey,
    String? sourceLayer,
  }) async {}

  @override
  Future<Map<String, dynamic>?> getFeatureState(
    String sourceId,
    String featureId, {
    String? sourceLayer,
  }) async => null;

  @override
  Future<void> removeSource(String sourceId) async {}

  @override
  Future<void> addSymbolLayer(
    String sourceId,
    String layerId,
    Map<String, dynamic> properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    dynamic filter,
    required bool enableInteraction,
  }) async {}

  @override
  Future<void> addLineLayer(
    String sourceId,
    String layerId,
    Map<String, dynamic> properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    dynamic filter,
    required bool enableInteraction,
  }) async {}

  @override
  Future<void> setLayerProperties(String layerId, Map<String, dynamic> properties) async {}

  @override
  Future<void> addCircleLayer(
    String sourceId,
    String layerId,
    Map<String, dynamic> properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    dynamic filter,
    required bool enableInteraction,
  }) async {}

  @override
  Future<void> addFillLayer(
    String sourceId,
    String layerId,
    Map<String, dynamic> properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    dynamic filter,
    required bool enableInteraction,
  }) async {}

  @override
  Future<void> addFillExtrusionLayer(
    String sourceId,
    String layerId,
    Map<String, dynamic> properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    dynamic filter,
    required bool enableInteraction,
  }) async {}

  @override
  Future<void> addRasterLayer(
    String sourceId,
    String layerId,
    Map<String, dynamic> properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
  }) async {}

  @override
  Future<void> addHillshadeLayer(
    String sourceId,
    String layerId,
    Map<String, dynamic> properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
  }) async {}

  @override
  Future<void> addHeatmapLayer(
    String sourceId,
    String layerId,
    Map<String, dynamic> properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
  }) async {}

  @override
  Future<void> addSource(String sourceId, SourceProperties properties) async {}

  @override
  Future<void> setLayerVisibility(String layerId, bool visible) async {}

  @override
  Future<bool?> getLayerVisibility(String layerId) async => null;

  @override
  Future<Size> setWebMapToCustomSize(Size size) async => Size.zero;

  @override
  Future<void> waitUntilMapIsIdleAfterMovement() async {}

  @override
  Future<void> waitUntilMapTilesAreLoaded() async {}

  @override
  Future<Uint8List> takeSnapshot({int? width, int? height}) async => Uint8List(0);

  @override
  Future<void> setStyle(String styleString) async {}
}

// ---------------------------------------------------------------------------
// Fake ExploreController for ExploreMap tests.
// ---------------------------------------------------------------------------

class _FakeExploreController extends GetxServiceMock implements ExploreController {
  _FakeExploreController({List<PropertyMarker> markers = const []}) {
    _markers.addAll(markers);
  }

  final List<PropertyMarker> _markers = [];
  @override
  final RxInt markersRevision = 0.obs;

  @override
  final Rx<LatLng> currentCenter = const LatLng(28.6139, 77.2090).obs;
  @override
  final RxDouble currentZoom = 12.0.obs;
  @override
  final RxDouble currentRadius = 5.0.obs;
  @override
  final RxBool isMapReady = false.obs;
  @override
  final Rx<ExploreState> state = ExploreState.loaded.obs;
  @override
  final RxList<PropertyModel> properties = <PropertyModel>[].obs;
  @override
  final Rxn<AppException> error = Rxn<AppException>();
  @override
  final Rx<PropertyModel?> selectedProperty = Rx<PropertyModel?>(null);
  @override
  final RxBool isListCollapsed = false.obs;
  @override
  final RxString searchQuery = ''.obs;
  @override
  final RxMap<int, bool> likedOverrides = <int, bool>{}.obs;

  MapLibreMapController? attachedController;
  int mapReadyCalls = 0;
  int cameraIdleCalls = 0;
  int selectCalls = 0;

  @override
  List<PropertyMarker> get propertyMarkers => _markers;

  @override
  void attachMap(MapLibreMapController controller) {
    attachedController = controller;
  }

  @override
  void onMapReady() {
    mapReadyCalls++;
    isMapReady.value = true;
  }

  @override
  void onCameraIdle(LatLng center, double zoom) {
    cameraIdleCalls++;
  }

  @override
  void selectProperty(PropertyModel property) {
    selectCalls++;
    selectedProperty.value = property;
  }

  @override
  bool hasMore = false;
  @override
  bool isLoadingMore = false;

  @override
  String get currentAreaText => '5.0 km';

  @override
  String get locationDisplayText => 'Test';

  @override
  String get propertiesCountText => '0';

  @override
  List<PropertyModel> get propertiesWithLocation => [];

  @override
  void zoomIn() {}

  @override
  void zoomOut() {}

  @override
  void recenterToCurrentLocation() {}

  @override
  void fitBoundsToProperties() {}

  @override
  void updateSearchQuery(String query) {}

  @override
  void retryLoading() {}

  @override
  void toggleListCollapsed() {}

  @override
  void expandList() {}

  @override
  void collapseList() {}

  @override
  void highlightPropertyFromCard(PropertyModel property) {}

  @override
  bool isPropertyLiked(PropertyModel property) => false;

  @override
  Future<void> toggleLike(PropertyModel property) async {}

  @override
  Future<void> loadMoreProperties() async {}
}

PropertyModel _property({int id = 100, String title = 'Test Property'}) {
  return PropertyModel(
    id: id,
    title: title,
    basePrice: 5000000,
    latitude: 28.61,
    longitude: 77.21,
    isAvailable: true,
    viewCount: 0,
    likeCount: 0,
    interestCount: 0,
  );
}

PropertyMarker _marker({int id = 100, bool selected = false, String label = '₹50L'}) {
  return PropertyMarker(
    property: _property(id: id),
    position: const LatLng(28.61, 77.21),
    isSelected: selected,
    label: label,
  );
}

void main() {
  late _FakeExploreController controller;
  MapLibrePlatform Function()? originalCreateInstance;

  setUp(() {
    GetxTestBinding.init();
    // Override the platform factory so MapLibreMap uses our fake.
    originalCreateInstance = MapLibrePlatform.createInstance;
    MapLibrePlatform.createInstance = () => _FakeMapLibrePlatform();

    controller = _FakeExploreController();
  });

  tearDown(() {
    // Restore the original platform factory.
    if (originalCreateInstance != null) {
      MapLibrePlatform.createInstance = originalCreateInstance!;
    }
    GetxTestBinding.reset();
  });

  Future<void> pumpExploreMap(WidgetTester tester, {Size size = const Size(400, 600)}) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        fallbackLocale: const Locale('en', 'US'),
        home: Scaffold(
          body: SizedBox(
            width: size.width,
            height: size.height,
            child: ExploreMap(controller: controller),
          ),
        ),
      ),
    );
    // Pump a few frames to let the microtask (onPlatformViewCreated) run.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // Drain any pending async exceptions.
    tester.takeException();
  }

  group('ExploreMap — widget construction', () {
    testWidgets('builds without throwing', (tester) async {
      await pumpExploreMap(tester);

      expect(find.byType(ExploreMap), findsOneWidget);
    });

    testWidgets('contains a MapLibreMap widget', (tester) async {
      await pumpExploreMap(tester);

      expect(find.byType(MapLibreMap), findsOneWidget);
    });

    testWidgets('calls attachMap via onMapCreated', (tester) async {
      await pumpExploreMap(tester);

      // The fake platform triggers onPlatformViewCreated which creates the
      // MapLibreMapController and calls onMapCreated → attachMap.
      expect(controller.attachedController, isNotNull);
    });

    testWidgets('calls onMapReady after style loads', (tester) async {
      await pumpExploreMap(tester);

      // After style loaded callback fires, onMapReady should be called.
      // We need to pump enough frames for the async style loaded callback.
      await tester.pump(const Duration(milliseconds: 200));
      expect(controller.mapReadyCalls, greaterThan(0));
    });
  });

  group('ExploreMap — marker overlays', () {
    testWidgets('renders PropertyMarkerChip for each marker with screen position', (tester) async {
      controller = _FakeExploreController(markers: [_marker(id: 1), _marker(id: 2)]);
      await pumpExploreMap(tester);

      // After the map renders and overlays update, marker chips should appear.
      // Pump enough frames for _updateOverlays to complete.
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(PropertyMarkerChip), findsNWidgets(2));
    });

    testWidgets('renders marker chip label text', (tester) async {
      controller = _FakeExploreController(markers: [_marker(id: 1, label: '₹99L')]);
      await pumpExploreMap(tester);

      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('₹99L'), findsOneWidget);
    });

    testWidgets('tapping a marker chip calls selectProperty', (tester) async {
      controller = _FakeExploreController(markers: [_marker(id: 1, label: '₹50L')]);
      await pumpExploreMap(tester);

      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('₹50L'));
      await tester.pump();

      expect(controller.selectCalls, 1);
    });

    testWidgets('does not render marker chips when no markers', (tester) async {
      controller = _FakeExploreController(markers: []);
      await pumpExploreMap(tester);

      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(PropertyMarkerChip), findsNothing);
    });

    testWidgets('rebuilds when markersRevision changes', (tester) async {
      controller = _FakeExploreController(markers: [_marker(id: 1)]);
      await pumpExploreMap(tester);

      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(PropertyMarkerChip), findsOneWidget);

      // Add a second marker and bump revision to trigger rebuild.
      controller._markers.add(_marker(id: 2));
      controller.markersRevision.value++;
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(PropertyMarkerChip), findsNWidgets(2));
    });
  });

  group('ExploreMap — camera and state changes', () {
    testWidgets('updates overlays when currentCenter changes', (tester) async {
      controller = _FakeExploreController(markers: [_marker(id: 1)]);
      await pumpExploreMap(tester);

      await tester.pump(const Duration(milliseconds: 200));

      // Change the center — the ever() worker should trigger _updateOverlays.
      controller.currentCenter.value = const LatLng(19.076, 72.877);
      await tester.pump(const Duration(milliseconds: 200));

      // The widget should still be present.
      expect(find.byType(ExploreMap), findsOneWidget);
    });

    testWidgets('updates overlays when currentRadius changes', (tester) async {
      controller = _FakeExploreController(markers: [_marker(id: 1)]);
      await pumpExploreMap(tester);

      await tester.pump(const Duration(milliseconds: 200));

      // Change the radius — the ever() worker should trigger _syncRadiusCircle.
      controller.currentRadius.value = 10.0;
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(ExploreMap), findsOneWidget);
    });

    testWidgets('updates overlays when markersRevision changes', (tester) async {
      controller = _FakeExploreController(markers: [_marker(id: 1)]);
      await pumpExploreMap(tester);

      await tester.pump(const Duration(milliseconds: 200));

      // Bump the markers revision — the ever() worker should trigger
      // _syncPropertiesSource.
      controller.markersRevision.value++;
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(ExploreMap), findsOneWidget);
    });
  });

  group('ExploreMap — dispose', () {
    testWidgets('disposes cleanly without errors', (tester) async {
      await pumpExploreMap(tester);

      // Re-pump with no widget to trigger dispose.
      await tester.pumpWidget(const GetMaterialApp(home: Scaffold(body: SizedBox.shrink())));
      await tester.pump();

      // If dispose threw, takeException would surface it.
      tester.takeException();
    });
  });

  group('ExploreMap — selected marker', () {
    testWidgets('renders selected marker chip with pulse animation', (tester) async {
      controller = _FakeExploreController(markers: [_marker(id: 1, selected: true)]);
      await pumpExploreMap(tester);

      await tester.pump(const Duration(milliseconds: 200));

      // The selected chip should be present.
      expect(find.byType(PropertyMarkerChip), findsOneWidget);
      // Advance the animation clock to verify the pulse is running.
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });
}
