import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/map/map_controller.dart';
import 'package:ghar360/core/utils/best_effort.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/features/explore/presentation/controllers/explore_controller.dart';
import 'package:ghar360/features/explore/presentation/controllers/explore_map_session.dart';
import 'package:ghar360/features/explore/presentation/widgets/property_marker_chip.dart';
import 'package:ghar360/features/properties/application/property_filters.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

// Style ids for the search-radius circle (fill + outline) GeoJSON layers.
const String _radiusSourceId = 'explore-radius-source';
const String _radiusFillLayerId = 'explore-radius-fill';
const String _radiusLineLayerId = 'explore-radius-line';

// Style ids for the native property clustering source/layers.
const String _propertiesSourceId = 'explore-properties-source';
const String _clusterCircleLayerId = 'explore-clusters';
const String _clusterCountLayerId = 'explore-cluster-count';

/// The interactive explore map: an OpenFreeMap Liberty vector map with a
/// km-accurate search-radius ring (GeoJSON fill + line), native zoom-based
/// clustering for aggregated markers, and the rich [PropertyMarkerChip] price
/// bubbles rendered as Flutter widget overlays for individual (unclustered)
/// properties.
///
/// MARKER STRATEGY — HYBRID (native clusters + widget-overlay chips):
/// ghar360's clustering is zoom-based, so we use MapLibre's native GeoJSON
/// clustering (`cluster: true`) for the aggregated circles + counts (cheap,
/// GPU-rendered, scales to high counts) and tap-to-zoom-in. Individual property
/// markers keep their paper price slip + selected state + tap-to-select
/// by projecting each point to a screen pixel via `toScreenLocation` and
/// positioning the existing [PropertyMarkerChip] in a [Stack]. Chips whose
/// point falls inside a rendered cluster circle are hidden so the native
/// cluster owns that area — giving the native-cluster aggregation while
/// preserving the bespoke chip design for singletons.
class ExploreMap extends ConsumerStatefulWidget {
  const ExploreMap({super.key});

  @override
  ConsumerState<ExploreMap> createState() => _ExploreMapState();
}

class _ExploreMapState extends ConsumerState<ExploreMap> {
  ExploreController get _controller => ref.read(exploreProvider.notifier);
  final ExploreMapSession _session = ExploreMapSession();
  ExploreController? _owner;
  bool _active = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wasActive = _active;
    _active = TickerMode.valuesOf(context).enabled;
    _owner = ref.read(exploreProvider.notifier);
    _owner!.setVisible(_active);
    if (_active && !wasActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_active) return;
        _applyCamera();
        _syncRadiusCircle();
        _syncPropertiesSource();
        _updateOverlays();
      });
    }
  }

  MapLibreMapController? _mapController;
  bool _styleLoaded = false;
  bool _mapRendered = false;

  // Screen positions for each property marker, keyed by property id.
  final Map<int, Offset> _markerScreenPositions = {};
  // Property ids that are currently hidden because they sit under a cluster.
  final Set<int> _clusteredIds = {};
  String _markerSignature = '';

  // Last center/radius pushed to the radius GeoJSON source.
  LatLng? _radiusCenter;
  double? _radiusKm;
  bool _radiusSourceReady = false;

  // Last geojson signature pushed to the properties source.
  String _propertiesSignature = '';
  bool _propertiesSourceReady = false;

  // Serialise all style mutations so concurrent ever()/style-loaded/post-frame
  // callers cannot interleave remove+add (sourceAlreadyExists / sourceNotFound).
  Future<void> _styleMutationChain = Future<void>.value();

  @override
  void dispose() {
    _mapController?.removeListener(_onCameraChanged);
    _mapController?.onFeatureTapped.remove(_onFeatureTapped);
    _owner?.setVisible(false);
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final markers = ref.watch(exploreMarkersProvider);
    ref.listen(exploreProvider.select((state) => state.cameraRevision), (_, _) => _applyCamera());
    ref.listen(
      propertyFiltersProvider.select((state) => state.forPage(PageType.explore).radiusKm),
      (_, _) => _syncRadiusCircle(),
    );
    ref.listen(exploreProvider.select((state) => state.center), (_, _) {
      _syncRadiusCircle();
      _updateOverlays();
    });

    final signature = markers
        .map(
          (m) =>
              '${m.property.id}:${m.position.latitude}:${m.position.longitude}:${m.label}:${m.isSelected}',
        )
        .join('|');
    if (signature != _markerSignature) {
      _markerSignature = signature;
      if (_mapController != null && _styleLoaded) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _syncPropertiesSource();
          _updateOverlays();
        });
      }
    }

    return Stack(
      children: [
        MapLibreMap(
          key: const ValueKey('qa.explore.maplibre'),
          styleString: kLibertyStyle,
          initialCameraPosition: CameraPosition(
            target: _controller.currentCenter,
            zoom: _controller.currentZoom,
          ),
          minMaxZoomPreference: const MinMaxZoomPreference(kDefaultMinZoom, kDefaultMaxZoom),
          // Required so the wrapper can read cameraPosition for the camera-idle
          // re-fetch logic and for overlay projection.
          trackCameraPosition: true,
          rotateGesturesEnabled: false,
          tiltGesturesEnabled: false,
          // We manage GeoJSON layers ourselves; empty annotationOrder skips
          // package AnnotationManager init (avoids styleNotFound zone errors).
          annotationOrder: const [],
          annotationConsumeTapEvents: const [AnnotationType.symbol],
          // Keep attribution clear of the bottom property list sheet.
          attributionButtonPosition: AttributionButtonPosition.topLeft,
          onMapCreated: _onMapCreated,
          onStyleLoadedCallback: _onStyleLoaded,
          onCameraIdle: _onCameraIdle,
        ),
        ..._buildMarkerOverlays(markers),
      ],
    );
  }

  Future<void> _applyCamera() async {
    if (!mounted || !_active || !_styleLoaded) return;
    final state = ref.read(exploreProvider);
    if (state.fitBounds) {
      final points = _controller.propertiesWithLocation
          .map((property) => LatLng(property.latitude!, property.longitude!))
          .toList();
      _session.programmaticMove = true;
      try {
        await _session.mapController.fitBounds(points);
      } catch (_) {
        _session.programmaticMove = false;
      }
    } else {
      await _session.moveProgrammatic(state.center, state.zoom);
    }
  }

  List<Widget> _buildMarkerOverlays(List<PropertyMarker> markers) {
    final overlays = <Widget>[];
    for (final marker in markers) {
      final id = marker.property.id;
      if (_clusteredIds.contains(id)) continue;
      final pos = _markerScreenPositions[id];
      if (pos == null) continue;
      // Anchor the chip centre on the projected point.
      const double chipWidth = 120;
      const double chipHeight = 56;
      overlays.add(
        Positioned(
          left: pos.dx - chipWidth / 2,
          top: pos.dy - chipHeight / 2,
          width: chipWidth,
          height: chipHeight,
          child: Center(
            child: PropertyMarkerChip(
              property: marker.property,
              isSelected: marker.isSelected,
              label: marker.label,
              onTap: () {
                _controller.selectProperty(marker.property);
              },
            ),
          ),
        ),
      );
    }
    return overlays;
  }

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
    _session.attach(controller);
    controller.addListener(_onCameraChanged);
    // Cluster circle taps: zoom in to break the cluster apart.
    controller.onFeatureTapped.add(_onFeatureTapped);
  }

  void _onFeatureTapped(
    math.Point<double> point,
    LatLng coordinates,
    String id,
    String layerId,
    Annotation? annotation,
  ) {
    if (layerId != _clusterCircleLayerId) return;
    final controller = _mapController;
    if (controller == null) return;
    final currentZoom = controller.cameraPosition?.zoom ?? _controller.currentZoom;
    controller.animateCamera(
      CameraUpdate.newLatLngZoom(
        coordinates,
        (currentZoom + 2).clamp(kDefaultMinZoom, kDefaultMaxZoom),
      ),
    );
  }

  void _onCameraChanged() {
    if (!mounted) return;
    _updateOverlays();
  }

  Future<void> _onStyleLoaded() async {
    // Sources/layers must be (re)added here; this can fire again on a style
    // reload, so ready flags are reset and sync routines recreate sources.
    _styleLoaded = true;
    final mapAtStyleLoad = _mapController;
    if (!mounted || mapAtStyleLoad == null) return;
    _radiusCenter = null;
    _radiusKm = null;
    _radiusSourceReady = false;
    _propertiesSignature = '';
    _propertiesSourceReady = false;
    await _syncRadiusCircle();
    await _syncPropertiesSource();
    // Let the controller move the camera to the resolved location.
    _session.isMapReady = true;
    await _applyCamera();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapRendered = true;
      _updateOverlays();
    });
  }

  void _onCameraIdle() {
    final controller = _mapController;
    if (controller == null || !_active) return;
    final pos = controller.cameraPosition;
    if (pos != null) {
      _controller.onCameraIdle(pos.target, pos.zoom, programmatic: _session.programmaticMove);
      _session.programmaticMove = false;
    }
    _updateOverlays();
  }

  // Coalescing latch for overlay projection. MapLibre notifies on every camera
  // frame, and one pass costs a platform-channel round trip per marker, so
  // passes must not overlap (a stale pass can otherwise land last and strand
  // the chips off their pins). Events are remembered, never dropped:
  // INVARIANT — the last camera event always produces a final sync, because a
  // request arriving mid-pass sets _syncQueued, which forces one more pass
  // after the in-flight one drains.
  bool _syncing = false;
  bool _syncQueued = false;

  Future<void> _updateOverlays() async {
    if (_syncing) {
      _syncQueued = true;
      return;
    }
    _syncing = true;
    try {
      do {
        _syncQueued = false;
        try {
          await _computeAndSetOverlays();
        } catch (e) {
          // Every caller is fire-and-forget, so an escaping error would land in
          // the zone handler instead of anywhere useful.
          DebugLogger.warning('Explore overlay projection pass failed: ${e.runtimeType}');
          // Note: a queued event still drains, but a failed pass is not
          // re-armed — re-arming would retry unboundedly against a destroyed
          // surface. Recovery rides on the next camera/idle/style event.
        }
      } while (_syncQueued && mounted);
    } finally {
      _syncing = false;
    }
  }

  Future<void> _computeAndSetOverlays() async {
    final controller = _mapController;
    if (!mounted || !_active || controller == null || !_styleLoaded || !_mapRendered) return;

    final markers = ref.read(exploreMarkersProvider);
    final positions = <int, Offset>{};
    for (final marker in markers) {
      final p = await controller.toScreenLocation(marker.position);
      positions[marker.property.id] = Offset(p.x.toDouble(), p.y.toDouble());
    }

    // Determine which markers sit under a rendered cluster circle so we can
    // hide their overlay chips (the native cluster owns that area).
    final clustered = await _computeClusteredIds(positions);

    if (!mounted) return;
    if (_positionsEqual(positions, _markerScreenPositions) &&
        _setsEqual(clustered, _clusteredIds)) {
      return;
    }
    setState(() {
      _markerScreenPositions
        ..clear()
        ..addAll(positions);
      _clusteredIds
        ..clear()
        ..addAll(clustered);
    });
  }

  // Queries rendered cluster circles in the viewport and flags any property
  // whose screen position falls within a cluster circle's radius.
  Future<Set<int>> _computeClusteredIds(Map<int, Offset> positions) async {
    final controller = _mapController;
    final result = <int>{};
    if (controller == null || positions.isEmpty || !_mapRendered) return result;
    // Reached after the projection awaits: the tree may have gone away, and
    // context.size throws on a deactivated element.
    if (!mounted) return result;

    final size = context.size;
    if (size == null) return result;

    List<dynamic> features;
    try {
      features = await controller.queryRenderedFeaturesInRect(Offset.zero & size, [
        _clusterCircleLayerId,
      ], null);
    } catch (_) {
      return result;
    }

    // Build a list of cluster centres (screen px) + their visual radius.
    final clusters = <_ClusterScreen>[];
    for (final f in features) {
      final feature = (f is Map) ? f : null;
      if (feature == null) continue;
      final geometry = feature['geometry'];
      if (geometry is! Map) continue;
      final coords = geometry['coordinates'];
      if (coords is! List || coords.length < 2) continue;
      final lng = (coords[0] as num).toDouble();
      final lat = (coords[1] as num).toDouble();
      final props = feature['properties'];
      final count = (props is Map && props['point_count'] is num)
          ? (props['point_count'] as num).toInt()
          : 0;
      final screen = await controller.toScreenLocation(LatLng(lat, lng));
      clusters.add(
        _ClusterScreen(
          center: Offset(screen.x.toDouble(), screen.y.toDouble()),
          radius: _clusterRadiusForCount(count) + 4,
        ),
      );
    }

    if (clusters.isEmpty) return result;
    for (final entry in positions.entries) {
      for (final cluster in clusters) {
        if ((entry.value - cluster.center).distance <= cluster.radius) {
          result.add(entry.key);
          break;
        }
      }
    }
    return result;
  }

  // Mirrors the `circleRadius` step expression below.
  double _clusterRadiusForCount(int count) {
    if (count >= 50) return 28;
    if (count >= 10) return 22;
    return 18;
  }

  /// Enqueues [work] so style mutations never run concurrently.
  Future<void> _enqueueStyleMutation(Future<void> Function() work) {
    final run = _styleMutationChain.then((_) => work());
    // Keep the chain alive even if one mutation fails.
    _styleMutationChain = run.catchError((Object e, StackTrace st) {
      DebugLogger.warning('Explore map style mutation failed: ${e.runtimeType}');
    });
    return _styleMutationChain;
  }

  Future<void> _syncRadiusCircle() {
    return _enqueueStyleMutation(_syncRadiusCircleImpl);
  }

  Future<void> _syncRadiusCircleImpl() async {
    final controller = _mapController;
    if (!mounted || !_active || controller == null || !_styleLoaded) return;
    final center = _controller.currentCenter;
    final radiusKm = _controller.currentRadius;
    if (_radiusSourceReady &&
        _radiusCenter?.latitude == center.latitude &&
        _radiusCenter?.longitude == center.longitude &&
        _radiusKm == radiusKm) {
      return;
    }

    final geojson = circlePolygon(center, radiusKm);

    try {
      if (_radiusSourceReady) {
        await controller.setGeoJsonSource(_radiusSourceId, geojson);
      } else {
        await _ensureRadiusLayers(controller, geojson);
      }
      if (!mounted || !_active || !_styleLoaded) return;
      _radiusCenter = center;
      _radiusKm = radiusKm;
      _radiusSourceReady = true;
    } on PlatformException catch (e, st) {
      DebugLogger.warning('Explore radius sync failed: ${e.code}');
      DebugLogger.debug('$st');
      // Recover by forcing a full recreate on the next attempt.
      _radiusSourceReady = false;
      try {
        await _ensureRadiusLayers(controller, geojson);
        if (!mounted || !_active || !_styleLoaded) return;
        _radiusCenter = center;
        _radiusKm = radiusKm;
        _radiusSourceReady = true;
      } on PlatformException catch (e2) {
        DebugLogger.warning('Explore radius recreate failed: ${e2.code}');
      }
    }
  }

  Future<void> _ensureRadiusLayers(
    MapLibreMapController controller,
    Map<String, dynamic> geojson,
  ) async {
    // Removing a layer/source that does not exist yet throws; that is the
    // expected first-render path, so treat these as best-effort cleanup.
    await BestEffort.runAsync(
      () => controller.removeLayer(_radiusFillLayerId),
      label: 'explore-radius-remove-fill-layer',
    );
    await BestEffort.runAsync(
      () => controller.removeLayer(_radiusLineLayerId),
      label: 'explore-radius-remove-line-layer',
    );
    await BestEffort.runAsync(
      () => controller.removeSource(_radiusSourceId),
      label: 'explore-radius-remove-source',
    );

    await controller.addGeoJsonSource(_radiusSourceId, geojson);
    await controller.addFillLayer(
      _radiusSourceId,
      _radiusFillLayerId,
      // The chosen area in peacock teal (AppDesignTokens.teal700): a faint wash, a firm edge.
      const FillLayerProperties(fillColor: '#0C6A61', fillOpacity: 0.08),
    );
    await controller.addLineLayer(
      _radiusSourceId,
      _radiusLineLayerId,
      const LineLayerProperties(lineColor: '#0C6A61', lineOpacity: 0.55, lineWidth: 1.5),
    );
  }

  Future<void> _syncPropertiesSource() {
    return _enqueueStyleMutation(_syncPropertiesSourceImpl);
  }

  Future<void> _syncPropertiesSourceImpl() async {
    final controller = _mapController;
    if (!mounted || !_active || controller == null || !_styleLoaded) return;

    final markers = ref.read(exploreMarkersProvider);
    final features = <Map<String, dynamic>>[
      for (final m in markers)
        {
          'type': 'Feature',
          'properties': {'id': m.property.id},
          'geometry': {
            'type': 'Point',
            // GeoJSON is [lng, lat] — opposite of MapLibre LatLng.
            'coordinates': [m.position.longitude, m.position.latitude],
          },
        },
    ];
    final geojson = <String, dynamic>{'type': 'FeatureCollection', 'features': features};

    // Content-aware signature (sorted ids) so set vs recreate is correct.
    final points =
        markers
            .map((m) => '${m.property.id}:${m.position.latitude}:${m.position.longitude}')
            .toList()
          ..sort();
    final signature = points.join(',');
    if (_propertiesSourceReady && _propertiesSignature == signature) {
      return;
    }

    try {
      if (_propertiesSourceReady) {
        await controller.setGeoJsonSource(_propertiesSourceId, geojson);
      } else {
        await _ensurePropertiesLayers(controller, geojson);
      }
      if (!mounted || !_active || !_styleLoaded) return;
      _propertiesSignature = signature;
      _propertiesSourceReady = true;
      await _updateOverlays();
    } on PlatformException catch (e, st) {
      DebugLogger.warning('Explore properties sync failed: ${e.code}');
      DebugLogger.debug('$st');
      _propertiesSourceReady = false;
      try {
        await _ensurePropertiesLayers(controller, geojson);
        if (!mounted || !_active || !_styleLoaded) return;
        _propertiesSignature = signature;
        _propertiesSourceReady = true;
        await _updateOverlays();
      } on PlatformException catch (e2) {
        DebugLogger.warning('Explore properties recreate failed: ${e2.code}');
      }
    }
  }

  Future<void> _ensurePropertiesLayers(
    MapLibreMapController controller,
    Map<String, dynamic> geojson,
  ) async {
    await BestEffort.runAsync(
      () => controller.removeLayer(_clusterCountLayerId),
      label: 'explore-properties-remove-count-layer',
    );
    await BestEffort.runAsync(
      () => controller.removeLayer(_clusterCircleLayerId),
      label: 'explore-properties-remove-circle-layer',
    );
    await BestEffort.runAsync(
      () => controller.removeSource(_propertiesSourceId),
      label: 'explore-properties-remove-source',
    );

    await controller.addSource(
      _propertiesSourceId,
      GeojsonSourceProperties(data: geojson, cluster: true, clusterRadius: 60, clusterMaxZoom: 17),
    );
    await controller.addCircleLayer(
      _propertiesSourceId,
      _clusterCircleLayerId,
      const CircleLayerProperties(
        // Matches AppDesignTokens.gold500 (0xFFF5B400).
        circleColor: '#F5B400',
        circleRadius: [
          'step',
          ['get', 'point_count'],
          18,
          10,
          22,
          50,
          28,
        ],
        circleStrokeWidth: 1,
        circleStrokeColor: '#FFFFFF',
      ),
      filter: ['has', 'point_count'],
    );
    await controller.addSymbolLayer(
      _propertiesSourceId,
      _clusterCountLayerId,
      const SymbolLayerProperties(
        textField: ['get', 'point_count_abbreviated'],
        textSize: 12,
        textFont: ['Noto Sans Bold'],
        textColor: '#182320', // AppDesignTokens.ink900
        textAllowOverlap: true,
        textIgnorePlacement: true,
      ),
      filter: ['has', 'point_count'],
    );
  }

  static bool _positionsEqual(Map<int, Offset> a, Map<int, Offset> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      final other = b[entry.key];
      if (other == null || (other - entry.value).distanceSquared > 0.25) {
        return false;
      }
    }
    return true;
  }

  static bool _setsEqual(Set<int> a, Set<int> b) {
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }
}

class _ClusterScreen {
  const _ClusterScreen({required this.center, required this.radius});

  final Offset center;
  final double radius;
}
