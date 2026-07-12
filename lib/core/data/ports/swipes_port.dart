import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/data/models/unified_property_response.dart';

/// Core-facing swipe data port. Feature repositories implement this so
/// core controllers never import feature modules.
abstract class SwipesPort {
  Future<void> recordSwipe({required int propertyId, required bool isLiked});

  Future<UnifiedPropertyResponse> getSwipeHistoryProperties({
    required UnifiedFilterModel filters,
    double? latitude,
    double? longitude,
    String? cursor,
    int limit = 50,
    bool? isLiked,
  });
}
