import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/data/models/unified_property_response.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/network/api_paths.dart';
import 'package:ghar360/core/network/cache_policy.dart';
import 'package:ghar360/core/network/response_parser.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/utils/debug_logger.dart';

/// Remote datasource for property data.
/// Handles API communication and response parsing.
class PropertiesRemoteDatasource {
  final ApiClient _apiClient;

  PropertiesRemoteDatasource(this._apiClient);

  /// Fetches properties from the API.
  Future<UnifiedPropertyResponse> fetchProperties({
    required double latitude,
    required double longitude,
    required double radiusKm,
    required UnifiedFilterModel filters,
    String? cursor,
    int limit = 20,
    bool excludeSwiped = false,
    bool useCache = true,
  }) async {
    DebugLogger.debug('Fetching properties with location and radius');

    final queryParams = _buildQueryParams(
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm,
      filters: filters,
      cursor: cursor,
      limit: limit,
      excludeSwiped: excludeSwiped,
    );

    DebugLogger.debug('Property query fields: ${queryParams.keys.join(',')}');

    final response = await _apiClient.get(
      ApiPaths.properties,
      queryParams: queryParams,
      useCache: useCache,
    );

    return _parsePropertiesResponse(response);
  }

  /// Fetches a single property by ID.
  ///
  /// Optional auth: the endpoint is public (shared `/p/:id` deep links must
  /// work signed out) but still enriches liked-status for signed-in users.
  /// The ETag cache is off here: the detail has its own scoped cache, and the server marks a
  /// signed-in response `private, no-store` (see [markCachePolicy]).
  Future<PropertyModel> fetchPropertyById(String propertyId) async {
    final response = await _apiClient.get(
      ApiPaths.propertyById(propertyId),
      useCache: false,
      requireAuth: false,
    );
    final PropertyModel property;
    try {
      property = _parseProperty(ResponseParser.object(response.body));
    } catch (error, stack) {
      throw _malformed(error, stack);
    }
    return markCachePolicy(property, response.headers);
  }

  /// Searches properties by query.
  Future<UnifiedPropertyResponse> searchProperties({
    required String query,
    double? latitude,
    double? longitude,
    double? radiusKm,
    UnifiedFilterModel? filters,
    String? cursor,
    int limit = 20,
    bool excludeSwiped = false,
    bool useCache = true,
  }) async {
    final queryParams = _buildQueryParams(
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm,
      filters: filters,
      cursor: cursor,
      limit: limit,
      searchQuery: query,
      excludeSwiped: excludeSwiped,
    );

    final response = await _apiClient.get(
      ApiPaths.properties,
      queryParams: queryParams,
      useCache: useCache,
    );
    return _parsePropertiesResponse(response);
  }

  Map<String, dynamic> _buildQueryParams({
    required String? cursor,
    required int limit,
    UnifiedFilterModel? filters,
    double? latitude,
    double? longitude,
    double? radiusKm,
    String? searchQuery,
    bool excludeSwiped = false,
  }) {
    final queryParams = <String, dynamic>{'limit': limit.clamp(1, 100).toString()};
    // Omit `cursor` on the first page; backend treats absence/null as page 1.
    if (cursor != null && cursor.isNotEmpty) {
      queryParams['cursor'] = cursor;
    }

    if (latitude != null && longitude != null) {
      queryParams['lat'] = latitude.toStringAsFixed(6);
      queryParams['lng'] = longitude.toStringAsFixed(6);
      final effectiveRadius = radiusKm ?? filters?.radiusKm ?? 10.0;
      queryParams['radius'] = UnifiedFilterModel.apiRadiusKm(effectiveRadius).toString();
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      queryParams['q'] = searchQuery.trim();
    }

    if (excludeSwiped) {
      queryParams['exclude_swiped'] = 'true';
    }

    if (filters != null) {
      final filterMap = filters.toApiQueryParams();
      filterMap.forEach((key, value) {
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

        final stringValue = value.toString().trim();
        if (stringValue.isNotEmpty) {
          queryParams[key] = stringValue;
        }
      });
    }

    return queryParams;
  }

  PropertyModel _parseProperty(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! int || id <= 0) {
      throw const FormatException('Property response has no valid identity.');
    }
    return PropertyModel.fromJson(json);
  }

  ServerException _malformed(Object error, StackTrace stack) {
    DebugLogger.error('Property response rejected', error.runtimeType, stack);
    return ServerException(
      'The service returned an invalid property response.',
      code: 'MALFORMED_RESPONSE',
    );
  }

  /// A `CursorPage[Property]`. A row that cannot be read fails the page: dropping it would make a
  /// partial page look complete and advance its cursor past a missing property.
  UnifiedPropertyResponse _parsePropertiesResponse(ApiResponse response) {
    try {
      final body = ResponseParser.object(response.body);
      final items = body['items'];
      if (items is! List) {
        throw const FormatException('Property response has no list of items.');
      }
      for (final item in items) {
        final id = (item as Map)['id'];
        if (id is! int || id <= 0) {
          throw const FormatException('Property response has no valid identity.');
        }
      }
      return markCachePolicy(UnifiedPropertyResponse.fromJson(body), response.headers);
    } catch (error, stack) {
      throw _malformed(error, stack);
    }
  }
}
