import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/utils/indian_currency.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class PropertyMarker {
  const PropertyMarker({
    required this.property,
    required this.position,
    required this.isSelected,
    required this.label,
  });
  final PropertyModel property;
  final LatLng position;
  final bool isSelected;
  final String label;
}

/// Riverpod owns the cache; every response-shaping input is explicit here.
class ExplorePropertyMarkers {
  const ExplorePropertyMarkers();
  String deriveMarkerLabel(PropertyModel property, {String languageCode = 'en'}) {
    final price = property.effectivePrice;
    if (price == null || !price.isFinite || price <= 0) return '₹--';
    return IndianCurrency.compact(price, fractionDigits: 1, languageCode: languageCode);
  }

  List<PropertyMarker> build({
    required List<PropertyModel> properties,
    required int? selectedPropertyId,
    String languageCode = 'en',
  }) => List.unmodifiable([
    for (final property in properties)
      if (property.hasLocation &&
          property.latitude!.isFinite &&
          property.longitude!.isFinite &&
          property.latitude!.abs() <= 90 &&
          property.longitude!.abs() <= 180)
        PropertyMarker(
          property: property,
          position: LatLng(property.latitude!, property.longitude!),
          isSelected: selectedPropertyId == property.id,
          label: deriveMarkerLabel(property, languageCode: languageCode),
        ),
  ]);
}
