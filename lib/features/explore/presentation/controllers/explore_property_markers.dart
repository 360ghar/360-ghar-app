import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// Map pin model for the explore surface.
class PropertyMarker {
  final PropertyModel property;
  final LatLng position;
  final bool isSelected;
  final String label;

  PropertyMarker({
    required this.property,
    required this.position,
    required this.isSelected,
    required this.label,
  });
}

/// Builds and caches property map markers. Owned by [ExploreController] but
/// kept in a dedicated type so marker math does not bloat the controller.
class ExplorePropertyMarkers {
  List<PropertyMarker>? _cached;
  bool _dirty = true;
  bool _invalidationScheduled = false;
  int revision = 0;

  void invalidate(String reason, {void Function(int revision)? onRevision}) {
    _dirty = true;
    DebugLogger.debug('🧠 propertyMarkers cache invalidated: $reason');
    if (_invalidationScheduled) return;
    _invalidationScheduled = true;
    Future.microtask(() {
      _invalidationScheduled = false;
      revision++;
      onRevision?.call(revision);
    });
  }

  String deriveMarkerLabel(PropertyModel property) {
    try {
      final price = property.getEffectivePrice();
      if (price <= 0) return '₹--';

      String withPrecision(double v) {
        final str = (v < 10 ? v.toStringAsFixed(1) : v.toStringAsFixed(0));
        return str.endsWith('.0') ? str.substring(0, str.length - 2) : str;
      }

      if (price >= 10000000) {
        return '₹${withPrecision(price / 10000000.0)}Cr';
      }
      if (price >= 100000) {
        return '₹${withPrecision(price / 100000.0)}L';
      }
      if (price >= 1000) {
        return '₹${withPrecision(price / 1000.0)}k';
      }
      return '₹${price.toStringAsFixed(0)}';
    } catch (_) {
      return property.formattedPrice;
    }
  }

  List<PropertyMarker> build({
    required List<PropertyModel> properties,
    required int? selectedPropertyId,
  }) {
    try {
      if (!_dirty && _cached != null) {
        DebugLogger.debug('⚡ Returning cached property markers: ${_cached!.length}');
        return _cached!;
      }

      final propsWithLocation = properties
          .where((p) => p.hasLocation && p.latitude != null && p.longitude != null)
          .toList();
      DebugLogger.info('🗺️ Generating markers for ${propsWithLocation.length} properties');

      if (propsWithLocation.isEmpty) {
        _cached = const <PropertyMarker>[];
        _dirty = false;
        return _cached!;
      }

      final markers = <PropertyMarker>[];
      for (final property in propsWithLocation) {
        try {
          final lat = property.latitude;
          final lng = property.longitude;
          if (lat == null || lng == null) continue;
          markers.add(
            PropertyMarker(
              property: property,
              position: LatLng(lat, lng),
              isSelected: selectedPropertyId == property.id,
              label: deriveMarkerLabel(property),
            ),
          );
        } catch (e) {
          DebugLogger.error('❌ Error creating marker for property ${property.id}: $e');
        }
      }

      DebugLogger.info('🗺️ Generated ${markers.length} property markers.');
      _cached = markers;
      _dirty = false;
      return _cached!;
    } catch (e) {
      DebugLogger.error('❌ Error generating property markers: $e');
      _cached = const <PropertyMarker>[];
      _dirty = false;
      return _cached!;
    }
  }
}
