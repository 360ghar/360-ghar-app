import 'package:get/get.dart';

import 'package:ghar360/core/controllers/offline_queue_service.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/data/models/unified_property_response.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/network/api_paths.dart';
import 'package:ghar360/core/network/response_parser.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/utils/debug_logger.dart';

class SwipesRepository extends GetxService {
  final ApiClient _apiClient = Get.find<ApiClient>();

  // Record a swipe action
  Future<void> recordSwipe({required int propertyId, required bool isLiked}) async {
    try {
      DebugLogger.api('👆 RECORDING SWIPE: ${isLiked ? 'LIKE' : 'DISLIKE'} property $propertyId');
      DebugLogger.api('🔄 Swipe will update liked status to: $isLiked');

      await _apiClient.post(
        ApiPaths.swipes,
        body: {'property_id': propertyId, 'is_liked': isLiked},
      );

      DebugLogger.success('✅ Swipe recorded successfully');
    } on AppException catch (e) {
      // If it's a network error, enqueue for retry instead of failing hard
      if (e is NetworkException) {
        DebugLogger.warning('🌐 Network error, queuing swipe for retry: ${e.message}');
        try {
          final queue = Get.find<OfflineQueueService>();
          await queue.enqueueSwipe(propertyId: propertyId, isLiked: isLiked);
        } catch (qErr) {
          DebugLogger.error('💥 Failed to enqueue swipe: $qErr');
        }
        return; // swallow network errors after enqueueing
      }
      DebugLogger.error('❌ Failed to record swipe: ${e.message}');
      rethrow;
    }
  }

  // Get swipe history properties with comprehensive filtering
  Future<UnifiedPropertyResponse> getSwipeHistoryProperties({
    required UnifiedFilterModel filters,
    double? latitude,
    double? longitude,
    String? cursor,
    int limit = 50,
    bool? isLiked,
  }) async {
    try {
      DebugLogger.api(
        '📜 Fetching swipe history properties: cursor=${cursor == null ? "first" : "next"}, '
        'limit=$limit, liked=$isLiked, filters=${filters.activeFilterCount} active',
      );

      final queryParams = <String, dynamic>{'limit': limit.toString()};
      // Omit `cursor` on the first page; backend treats absence/null as page 1.
      if (cursor != null && cursor.isNotEmpty) {
        queryParams['cursor'] = cursor;
      }

      if (latitude != null) queryParams['lat'] = latitude.toString();
      if (longitude != null) queryParams['lng'] = longitude.toString();
      if (filters.radiusKm != null) queryParams['radius'] = filters.radiusKm!.toInt().toString();
      final canonicalFilterParams = filters.toApiQueryParams();
      canonicalFilterParams.forEach((key, value) {
        if (value == null) return;
        if (value is List) {
          final cleanList = value
              .where((item) => item != null && item.toString().trim().isNotEmpty)
              .map((item) => item.toString().trim())
              .toList();
          if (cleanList.isNotEmpty) {
            queryParams[key] = cleanList;
          }
          return;
        }
        final scalar = value.toString().trim();
        if (scalar.isNotEmpty) {
          queryParams[key] = scalar;
        }
      });
      if (isLiked != null) queryParams['is_liked'] = isLiked.toString();

      DebugLogger.api('🔍 Fetching swipes with ApiClient');
      final apiResponse = await _apiClient.get(
        ApiPaths.swipes,
        queryParams: queryParams,
        useCache: false,
      );
      final rawBody = apiResponse.body;
      final responseJson = rawBody is Map<String, dynamic>
          ? rawBody
          : <String, dynamic>{'items': const <dynamic>[]};
      final payload = ResponseParser.unwrapObject(responseJson);

      // Log raw API response for debugging
      DebugLogger.api('📊 [SWIPES_REPO] RAW API RESPONSE: $responseJson');

      // Parse properties from the uniform cursor envelope (`items`).
      final List<dynamic> propertiesJson = payload['items'] as List<dynamic>? ?? const <dynamic>[];
      DebugLogger.api(
        '📦 [SWIPES_REPO] Cursor envelope: Found ${propertiesJson.length} properties in response',
      );

      final properties = <PropertyModel>[];
      for (int i = 0; i < propertiesJson.length; i++) {
        try {
          final item = propertiesJson[i];
          if (item is Map<String, dynamic>) {
            final property = PropertyModel.fromJson(item);
            properties.add(property);
          } else if (item is Map) {
            final property = PropertyModel.fromJson(Map<String, dynamic>.from(item));
            properties.add(property);
          }
        } catch (e) {
          DebugLogger.error('❌ [SWIPES_REPO] Error parsing property ${i + 1}: $e');
          DebugLogger.error('❌ [SWIPES_REPO] Property data: ${propertiesJson[i]}');
          // Continue with other properties instead of failing entirely
        }
      }

      // Build the uniform cursor-paginated response from backend signals.
      final hasMore = ResponseParser.extractHasMore(payload);
      final nextCursor = ResponseParser.extractNextCursor(payload);
      final searchCenter = () {
        try {
          final searchCenterData = payload['search_center'];
          if (searchCenterData != null) {
            final lat = searchCenterData['latitude'] ?? searchCenterData['lat'];
            final lng = searchCenterData['longitude'] ?? searchCenterData['lng'];
            num? toNum(dynamic v) => v is num ? v : (v is String ? num.tryParse(v) : null);
            final nLat = toNum(lat), nLng = toNum(lng);
            if (nLat != null && nLng != null) {
              return SearchCenter(latitude: nLat.toDouble(), longitude: nLng.toDouble());
            }
          }
          return null;
        } catch (e) {
          DebugLogger.error('❌ [SWIPES_REPO] Error creating SearchCenter: $e');
          return null;
        }
      }();

      final unifiedResponse = UnifiedPropertyResponse(
        items: properties,
        limit: (payload['limit'] is num ? (payload['limit'] as num).toInt() : limit),
        nextCursor: nextCursor,
        hasMore: hasMore,
        filtersApplied: payload['filters_applied'] is Map
            ? Map<String, dynamic>.from(payload['filters_applied'] as Map)
            : filters.toJson(),
        searchCenter: searchCenter,
      );

      DebugLogger.success(
        '✅ Loaded ${unifiedResponse.items.length} properties from swipe history '
        '(hasMore=${unifiedResponse.hasMore}, nextCursor=${unifiedResponse.nextCursor != null})',
      );
      return unifiedResponse;
    } on AppException catch (e) {
      DebugLogger.error('❌ Failed to fetch swipe history properties: ${e.message}');
      rethrow;
    }
  }

  // Get liked properties via server-side history endpoint
  Future<List<PropertyModel>> getLikedProperties({
    required UnifiedFilterModel filters,
    double? latitude,
    double? longitude,
    String? cursor,
    int limit = 50,
  }) async {
    try {
      DebugLogger.api('❤️ Fetching liked properties (server-side): cursor=$cursor, limit=$limit');
      final response = await getSwipeHistoryProperties(
        filters: filters,
        latitude: latitude,
        longitude: longitude,
        cursor: cursor,
        limit: limit,
        isLiked: true,
      );
      return response.items;
    } on AppException catch (e) {
      DebugLogger.error('❌ Failed to fetch liked properties: ${e.message}');
      rethrow;
    }
  }

  // Get passed properties via server-side history endpoint
  Future<List<PropertyModel>> getPassedProperties({
    required UnifiedFilterModel filters,
    double? latitude,
    double? longitude,
    String? cursor,
    int limit = 50,
  }) async {
    try {
      DebugLogger.api('👎 Fetching passed properties (server-side): cursor=$cursor, limit=$limit');
      final response = await getSwipeHistoryProperties(
        filters: filters,
        latitude: latitude,
        longitude: longitude,
        cursor: cursor,
        limit: limit,
        isLiked: false,
      );
      return response.items;
    } on AppException catch (e) {
      DebugLogger.error('❌ Failed to fetch passed properties: ${e.message}');
      rethrow;
    }
  }

  // Get liked properties (new format - no swipe IDs needed)
  Future<List<PropertyModel>> getLikedPropertiesWithSwipeIds({
    required UnifiedFilterModel filters,
    double? latitude,
    double? longitude,
    String? cursor,
    int limit = 50,
  }) async {
    try {
      DebugLogger.api('❤️ Fetching liked properties: cursor=$cursor, limit=$limit');

      final response = await getSwipeHistoryProperties(
        filters: filters,
        latitude: latitude,
        longitude: longitude,
        cursor: cursor,
        limit: limit,
        isLiked: true,
      );

      DebugLogger.success('✅ Loaded ${response.items.length} liked properties');
      return response.items;
    } on AppException catch (e) {
      DebugLogger.error('❌ Failed to fetch liked properties: ${e.message}');
      rethrow;
    }
  }

  // Get all swiped properties (both liked and disliked) with comprehensive filtering
  Future<UnifiedPropertyResponse> getAllSwipedProperties({
    required UnifiedFilterModel filters,
    String? cursor,
    int limit = 50,
  }) async {
    return await getSwipeHistoryProperties(
      filters: filters,
      cursor: cursor,
      limit: limit,
      isLiked: null, // Get both liked and disliked
    );
  }
}
