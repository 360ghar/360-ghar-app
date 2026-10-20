import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/data/models/unified_property_response.dart';
import 'package:ghar360/core/data/ports/properties_port.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/features/properties/data/datasources/properties_remote_datasource.dart';

class PropertiesRepository implements PropertiesPort {
  PropertiesRepository({required this._remoteDatasource, required this._apiClient});

  final PropertiesRemoteDatasource _remoteDatasource;
  final ApiClient _apiClient;

  Future<UnifiedPropertyResponse> getProperties({
    required UnifiedFilterModel filters,
    required String? cursor,
    required int limit,
    required double latitude,
    required double longitude,
    double? radiusKm,
    bool excludeSwiped = false,
    bool useCache = true,
  }) async {
    try {
      DebugLogger.api(
        'Fetching properties cursor=${cursor == null ? "first" : "next"} '
        'limit=$limit filters=${filters.activeFilterCount}',
      );

      final response = await _remoteDatasource.fetchProperties(
        filters: filters,
        latitude: latitude,
        longitude: longitude,
        radiusKm: (filters.radiusKm ?? radiusKm ?? 10.0),
        cursor: cursor,
        limit: limit,
        excludeSwiped: excludeSwiped,
        useCache: useCache,
      );

      DebugLogger.success(
        'Fetched ${response.items.length} properties '
        '(hasMore=${response.hasMore}, nextCursor=${response.nextCursor != null})',
      );
      return response;
    } on AppException catch (e) {
      DebugLogger.error('Failed to fetch properties: ${e.runtimeType}');
      rethrow;
    } catch (e, stackTrace) {
      DebugLogger.error('Unexpected error fetching properties', e.runtimeType, stackTrace);
      rethrow;
    }
  }

  @override
  Future<PropertyModel> getPropertyDetail(int propertyId) async {
    try {
      DebugLogger.api('Fetching property details: $propertyId');
      final property = await _remoteDatasource.fetchPropertyById(propertyId.toString());
      DebugLogger.success('Property detail fetched');
      return property;
    } on AppException catch (e) {
      DebugLogger.error('Property detail failed: ${e.runtimeType}');
      rethrow;
    }
  }

  @override
  Future<UnifiedPropertyResponse> searchProperties({
    required UnifiedFilterModel filters,
    required String? cursor,
    required int limit,
    required double latitude,
    required double longitude,
    double? radiusKm,
    bool excludeSwiped = false,
    bool useCache = false,
  }) async {
    return getProperties(
      filters: filters,
      cursor: cursor,
      limit: limit,
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm,
      excludeSwiped: excludeSwiped,
      useCache: useCache,
    );
  }

  @override
  Future<void> clearCache() => _apiClient.clearCache();
}
