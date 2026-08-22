import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/network/api_paths.dart';

/// Remote datasource for swipe operations.
class SwipesRemoteDatasource {
  final ApiClient _apiClient;

  SwipesRemoteDatasource(this._apiClient);

  /// Records a swipe with explicit liked/passed state.
  Future<void> swipeProperty({required int propertyId, required bool isLiked}) async {
    await _apiClient.post(
      ApiPaths.swipes,
      body: {'property_id': propertyId, 'is_liked': isLiked},
      idempotent: true,
    );
  }
}
