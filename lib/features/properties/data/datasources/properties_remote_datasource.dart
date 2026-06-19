import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/data/models/unified_property_response.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/network/api_paths.dart';
import 'package:ghar360/core/network/response_parser.dart';
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
    DebugLogger.debug(
      '🔍 Fetching properties: lat=$latitude, lng=$longitude, radius=${radiusKm}km',
    );

    final queryParams = _buildQueryParams(
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm,
      filters: filters,
      cursor: cursor,
      limit: limit,
      excludeSwiped: excludeSwiped,
    );

    DebugLogger.debug('🔍 Query params: $queryParams');

    final response = await _apiClient.get(
      ApiPaths.properties,
      queryParams: queryParams,
      useCache: useCache,
    );

    return _parsePropertiesResponse(response.body);
  }

  /// Fetches a single property by ID.
  Future<PropertyModel> fetchPropertyById(String propertyId) async {
    final response = await _apiClient.get(ApiPaths.propertyById(propertyId), useCache: true);
    final payload = ResponseParser.unwrapObject(response.body);
    if (payload.isEmpty) {
      throw const FormatException('Unexpected property response format');
    }
    return PropertyModel.fromJson(Map<String, dynamic>.from(payload));
  }

  /// Fetches multiple properties by IDs in a single request.
  ///
  /// Uses repeated `ids` query params (e.g. `?ids=1&ids=2`) to batch-fetch.
  /// Falls back to
  /// individual fetches if the batch endpoint fails.
  Future<List<PropertyModel>> fetchPropertiesByIds(List<int> ids) async {
    DebugLogger.debug('📦 Batch-fetching ${ids.length} properties by IDs');
    final response = await _apiClient.get(
      ApiPaths.properties,
      queryParams: {'ids': ids},
      useCache: true,
    );
    return _parsePropertiesResponse(response.body).items;
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
    return _parsePropertiesResponse(response.body);
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
    final queryParams = <String, dynamic>{'limit': limit.toString()};
    // Omit `cursor` on the first page; backend treats absence/null as page 1.
    if (cursor != null && cursor.isNotEmpty) {
      queryParams['cursor'] = cursor;
    }

    if (latitude != null && longitude != null) {
      queryParams['lat'] = latitude.toStringAsFixed(6);
      queryParams['lng'] = longitude.toStringAsFixed(6);
      final effectiveRadius = radiusKm ?? filters?.radiusKm ?? 10.0;
      queryParams['radius'] = effectiveRadius.toInt().toString();
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

  UnifiedPropertyResponse _parsePropertiesResponse(dynamic body) {
    try {
      DebugLogger.debug('📊 Response type: ${body?.runtimeType}');

      if (body is Map) {
        // Normalize to a typed map and unwrap common nested envelopes (`data`
        // as a list or as a `{items,...}` map) so the cursor envelope parser
        // always sees the final shape. Without this, a wrapped response
        // silently drops results or throws at runtime when `items` is absent.
        final mapBody = Map<String, dynamic>.from(body);
        if (!mapBody.containsKey('items')) {
          final nestedData = mapBody['data'];
          if (nestedData is List) {
            mapBody['items'] = nestedData;
          } else if (nestedData is Map) {
            final nestedMap = Map<String, dynamic>.from(nestedData);
            final nestedItems = nestedMap['items'];
            if (nestedItems is List) mapBody['items'] = nestedItems;
            mapBody.putIfAbsent('has_more', () => nestedMap['has_more']);
            mapBody.putIfAbsent('next_cursor', () => nestedMap['next_cursor']);
            mapBody.putIfAbsent('limit', () => nestedMap['limit']);
          }
        }
        // Guarantee `items` is a List so fromJson never throws on scalar payloads.
        mapBody['items'] = (mapBody['items'] is List) ? mapBody['items'] : const <Object>[];
        final unifiedResponse = UnifiedPropertyResponse.fromJson(mapBody);
        DebugLogger.debug(
          '📦 Parsed ${unifiedResponse.items.length} properties '
          '(hasMore=${unifiedResponse.hasMore}, nextCursor=${unifiedResponse.nextCursor != null})',
        );
        return unifiedResponse;
      } else if (body is List) {
        // Tolerate bare-array responses by wrapping them in the uniform envelope.
        final normalizedData = {'items': body};
        return UnifiedPropertyResponse.fromJson(normalizedData);
      } else {
        // Unknown/scalar payload: return an empty terminal page instead of a
        // runtime type error.
        return const UnifiedPropertyResponse();
      }
    } catch (e, stackTrace) {
      DebugLogger.error('Failed to parse properties response: $e', e, stackTrace);
      rethrow;
    }
  }
}
