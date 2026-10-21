import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:maplibre_gl/maplibre_gl.dart';

class FakeExploreMapPlatform extends MapLibrePlatform {
  bool _viewCreated = false;
  bool get viewCreated => _viewCreated;
  final cameraMoves = <CameraUpdate>[];
  final sourceIds = <String>[];
  final geojson = <String, Map<String, dynamic>>{};

  /// Simulated camera state: every projected point lands at
  /// (screenOffset, screenOffset). Changing it stands in for a camera move.
  double screenOffset = 0;

  /// When true, [toScreenLocation] resolves after a delay that DECREASES as
  /// [screenOffset] grows, so an older camera state resolves *after* a newer
  /// one. This mirrors real platform-channel jitter and is what lets a stale
  /// overlay pass win whenever two passes are allowed to run concurrently.
  bool simulateProjectionLatency = false;

  /// Highest number of [toScreenLocation] futures in flight at once. An
  /// overlay pass projects its markers sequentially, so anything above 1 means
  /// two passes overlapped.
  int maxConcurrentToScreen = 0;
  int _inFlightToScreen = 0;

  /// While true, [toScreenLocation] throws, standing in for a projection that
  /// fails because the surface is being recreated or the style swapped.
  bool failProjection = false;

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
  Future<bool?> animateCamera(CameraUpdate cameraUpdate, {Duration? duration}) async {
    cameraMoves.add(cameraUpdate);
    return true;
  }

  @override
  Future<bool?> moveCamera(CameraUpdate cameraUpdate) async {
    cameraMoves.add(cameraUpdate);
    return true;
  }

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
  Future<math.Point> toScreenLocation(LatLng latLng) async {
    // Thrown before the in-flight counter moves so it stays balanced.
    if (failProjection) {
      throw PlatformException(code: 'surfaceDestroyed', message: 'no surface');
    }
    // Capture the camera state at call time so a pass that started earlier
    // keeps projecting against the camera it saw.
    final captured = screenOffset;
    _inFlightToScreen++;
    if (_inFlightToScreen > maxConcurrentToScreen) {
      maxConcurrentToScreen = _inFlightToScreen;
    }
    if (simulateProjectionLatency) {
      await Future<void>.delayed(Duration(milliseconds: math.max(1, 200 - captured.round())));
    }
    _inFlightToScreen--;
    return math.Point(captured, captured);
  }

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
  }) async {
    sourceIds.add(sourceId);
    this.geojson[sourceId] = geojson;
  }

  @override
  Future<void> setGeoJsonSource(String sourceId, Map<String, dynamic> geojson) async {
    this.geojson[sourceId] = geojson;
  }

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
  Future<void> addSource(String sourceId, SourceProperties properties) async {
    sourceIds.add(sourceId);
  }

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
