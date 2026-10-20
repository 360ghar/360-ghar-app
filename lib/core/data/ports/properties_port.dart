import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/data/models/unified_property_response.dart';

/// Property data contract shared by query and detail providers.
/// Callers depend on this port instead of a concrete feature repository.
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

  Future<void> clearCache();
}
