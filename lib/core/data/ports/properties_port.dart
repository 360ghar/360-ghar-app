import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/data/models/unified_property_response.dart';

/// Core-facing property data port. Feature repositories implement this so
/// core controllers (e.g. [PageDataLoader]) never import feature modules.
abstract class PropertiesPort {
  Future<UnifiedPropertyResponse> searchProperties({
    required UnifiedFilterModel filters,
    required String? cursor,
    required int limit,
    required double latitude,
    required double longitude,
    double? radiusKm,
    bool excludeSwiped = false,
    bool useCache = false,
  });

  Future<PropertyModel> getPropertyDetail(int propertyId);

  Future<List<PropertyModel>> getPropertiesByIds(List<int> propertyIds);

  void clearCache();
}
