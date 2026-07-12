import 'package:flutter/material.dart';
import 'package:ghar360/core/design/app_design_tokens.dart';
import 'package:ghar360/core/map/map_controller.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// A compact single-pin MapLibre map (OpenFreeMap Liberty vector tiles) for
/// property-detail screens.
///
/// The map allows pinch-zoom + drag, so the pin cannot simply be centred: it is
/// drawn as a Flutter [Icon] overlay whose screen position is reprojected from
/// the geo point on every camera change (and on style load). This keeps the
/// bespoke `Icons.location_on` look without depending on the style's
/// sprite/glyph sheet for a custom marker image.
class MiniMapView extends StatefulWidget {
  const MiniMapView({required this.latitude, required this.longitude, super.key, this.zoom = 15});

  final double latitude;
  final double longitude;
  final double zoom;

  @override
  State<MiniMapView> createState() => _MiniMapViewState();
}

class _MiniMapViewState extends State<MiniMapView> {
  MapLibreMapController? _controller;
  Offset? _pinPosition;

  LatLng get _point => LatLng(widget.latitude, widget.longitude);

  @override
  void dispose() {
    _controller?.removeListener(_onCameraChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: MapLibreMap(
            styleString: kLibertyStyle,
            initialCameraPosition: CameraPosition(target: _point, zoom: widget.zoom),
            // Match the previous flutter_map config: pinch-zoom + drag only.
            trackCameraPosition: true,
            rotateGesturesEnabled: false,
            tiltGesturesEnabled: false,
            // Pin is a Flutter overlay; skip package AnnotationManager init.
            annotationOrder: const [],
            annotationConsumeTapEvents: const [AnnotationType.symbol],
            // Keep attribution visible per the OSM/OpenFreeMap license.
            attributionButtonPosition: AttributionButtonPosition.bottomRight,
            onMapCreated: _onMapCreated,
            onStyleLoadedCallback: _onStyleLoaded,
          ),
        ),
        if (_pinPosition != null)
          Positioned(
            // Anchor the tip of the pin (icon bottom) on the projected point.
            left: _pinPosition!.dx - 18,
            top: _pinPosition!.dy - 36,
            child: const IgnorePointer(
              child: Icon(Icons.location_on, size: 36, color: AppDesignTokens.brandGold),
            ),
          ),
      ],
    );
  }

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
    controller.addListener(_onCameraChanged);
  }

  void _onStyleLoaded() {
    _updatePinPosition();
  }

  void _onCameraChanged() {
    if (!mounted) return;
    _updatePinPosition();
  }

  Future<void> _updatePinPosition() async {
    final controller = _controller;
    if (controller == null || !mounted) return;
    final screen = await controller.toScreenLocation(_point);
    if (!mounted) return;
    final next = Offset(screen.x.toDouble(), screen.y.toDouble());
    if (_pinPosition != null && (_pinPosition! - next).distanceSquared < 0.25) {
      return;
    }
    setState(() => _pinPosition = next);
  }
}
