import 'package:ghar360/core/data/models/swipe_models.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/data/models/unified_property_response.dart';
import 'package:ghar360/core/storage/app_database.dart';

sealed class SwipeOutcome {
  const SwipeOutcome();
}

class ConfirmedSwipe extends SwipeOutcome {
  const ConfirmedSwipe({this.operationId, this.swipe});
  final String? operationId;

  /// The server's receipt (`SwipeOut`). Null when the swipe was already confirmed earlier, or
  /// when a 2xx response carried a receipt the app could not read.
  final SwipeOut? swipe;
}

class PendingSwipe extends SwipeOutcome {
  const PendingSwipe(this.action);
  final PendingAction action;
}

/// Core-facing swipe data port. Feature repositories implement this so
/// core controllers never import feature modules.
abstract class SwipesPort {
  Future<SwipeOutcome> recordSwipe({required int propertyId, required bool isLiked});

  /// User-requested retry of the same durable operation; never automatic.
  Future<SwipeOutcome> retryPendingSwipe(PendingAction action);

  Future<UnifiedPropertyResponse> getSwipeHistoryProperties({
    required UnifiedFilterModel filters,
    double? latitude,
    double? longitude,
    String? cursor,
    int limit = 50,
    bool? isLiked,
  });
}
