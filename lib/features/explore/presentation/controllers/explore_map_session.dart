import 'package:ghar360/core/map/map_controller.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// Owns MapLibre attachment and programmatic camera moves for Explore.
class ExploreMapSession {
  final GharMapController mapController = GharMapController();
  bool isMapReady = false;
  bool programmaticMove = false;

  void attach(MapLibreMapController controller) {
    mapController.attach(controller);
  }

  void dispose() {
    mapController.dispose();
  }

  Future<void> moveProgrammatic(LatLng center, double zoom) async {
    if (!mapController.isAttached) return;
    programmaticMove = true;
    try {
      await mapController.move(center, zoom);
    } catch (e) {
      DebugLogger.warning('⚠️ Could not move map: $e');
      programmaticMove = false;
    }
  }

  Future<void> zoomBy(double delta, LatLng center, double currentZoom) async {
    final next = (currentZoom + delta).clamp(3.0, 20.0);
    await moveProgrammatic(center, next);
  }
}
