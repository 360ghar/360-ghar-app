import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/network/api_paths.dart';
import 'package:ghar360/core/utils/debug_logger.dart';

/// Remote datasource for swipe operations.
class SwipesRemoteDatasource {
  final ApiClient _apiClient;

  SwipesRemoteDatasource(this._apiClient);

  /// Logs a swipe action.
  /// [propertyId] is the property ID (int for consistency with PropertyModel)
  Future<void> logSwipe({required int propertyId, required String action}) async {
    DebugLogger.debug('👆 Logging swipe: $action on property $propertyId');
    await _apiClient.post(
      ApiPaths.swipes,
      body: {'property_id': propertyId, 'action': action},
      idempotent: true,
    );
  }

  /// Records a swipe with explicit liked/passed state.
  Future<void> swipeProperty({required int propertyId, required bool isLiked}) async {
    await _apiClient.post(
      ApiPaths.swipes,
      body: {'property_id': propertyId, 'is_liked': isLiked},
      idempotent: true,
    );
  }
}
