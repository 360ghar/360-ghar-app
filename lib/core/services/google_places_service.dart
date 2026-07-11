import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:http/http.dart' as http;

/// Place suggestion from autocomplete (Google Places or OSM fallback).
class PlaceSuggestion {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  /// When set (e.g. OSM Nominatim), details do not need a second network call.
  final double? latitude;
  final double? longitude;

  PlaceSuggestion({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
    this.latitude,
    this.longitude,
  });

  bool get hasCoordinates => latitude != null && longitude != null;
}

/// Service for place autocomplete + details.
/// Prefers Google Places; falls back to OpenStreetMap Nominatim when Google
/// is denied (billing), missing key, or otherwise unavailable.
class GooglePlacesService extends GetxService {
  static const String _osmPlaceIdPrefix = 'osm:';

  final RxList<PlaceSuggestion> placeSuggestions = <PlaceSuggestion>[].obs;
  final RxBool isSearchingPlaces = false.obs;

  /// User-facing error for the last failed search. Empty when OK / zero results.
  final RxString placesError = ''.obs;

  /// After a denied Google call, skip Google for a while to avoid log spam.
  DateTime? _googleDisabledUntil;
  static const Duration _googleCooldown = Duration(minutes: 10);

  void _setError(String message) {
    placesError.value = message;
  }

  void _clearError() {
    placesError.value = '';
  }

  void _logApiFailure(String action, String? status, String? errorMessage) {
    final detail = errorMessage != null && errorMessage.isNotEmpty
        ? ' — $errorMessage'
        : '';
    DebugLogger.error('Google Places $action status=$status$detail');
  }

  bool get _shouldTryGoogle {
    final until = _googleDisabledUntil;
    if (until == null) return true;
    if (DateTime.now().isAfter(until)) {
      _googleDisabledUntil = null;
      return true;
    }
    return false;
  }

  void _disableGoogleTemporarily() {
    _googleDisabledUntil = DateTime.now().add(_googleCooldown);
    DebugLogger.warning(
      'Google Places unavailable — using OpenStreetMap fallback '
      'for ${_googleCooldown.inMinutes} minutes',
    );
  }

  /// Fetches place autocomplete suggestions for [query].
  Future<List<PlaceSuggestion>> getPlaceSuggestions(
    String query, {
    Position? currentPosition,
  }) async {
    if (query.trim().isEmpty || query.length < 2) {
      placeSuggestions.clear();
      _clearError();
      return [];
    }

    isSearchingPlaces.value = true;
    _clearError();

    try {
      if (_shouldTryGoogle) {
        final googleResults = await _searchGooglePlaces(
          query,
          currentPosition: currentPosition,
        );
        if (googleResults != null) {
          placeSuggestions.value = googleResults;
          _clearError();
          return googleResults;
        }
        // null => Google failed (denied/missing/error) — try fallback
      }

      final fallback = await _searchNominatim(query);
      if (fallback.isNotEmpty) {
        placeSuggestions.value = fallback;
        _clearError();
        DebugLogger.success(
          'Location search via OpenStreetMap: ${fallback.length} results',
        );
        return fallback;
      }

      placeSuggestions.clear();
      // Only show error if both providers failed to return anything useful
      // and we did not already clear for zero results from Google.
      if (placesError.value.isEmpty) {
        _clearError(); // real empty results
      }
      return [];
    } finally {
      isSearchingPlaces.value = false;
    }
  }

  /// Returns suggestions on success / ZERO_RESULTS (empty list).
  /// Returns null when Google cannot be used (caller should fall back).
  Future<List<PlaceSuggestion>?> _searchGooglePlaces(
    String query, {
    Position? currentPosition,
  }) async {
    try {
      final apiKey = dotenv.env['GOOGLE_PLACES_API_KEY'] ?? '';
      if (apiKey.isEmpty) {
        DebugLogger.warning(
          'Google Places API key not found — will use OSM fallback',
        );
        _disableGoogleTemporarily();
        return null;
      }

      if (kDebugMode) {
        DebugLogger.info(
          'Google Places autocomplete key present (length=${apiKey.length})',
        );
      }

      final countryCode = dotenv.env['DEFAULT_COUNTRY'] ?? 'in';
      final queryParams = <String, String>{
        'input': query,
        'components': 'country:$countryCode',
        'key': apiKey,
      };

      if (currentPosition != null) {
        final configuredRadius = dotenv.env['PLACES_RADIUS_METERS'] ?? '25000';
        final strictBoundsEnabled =
            (dotenv.env['PLACES_STRICT_BOUNDS'] ?? 'false').toLowerCase() ==
            'true';
        queryParams['location'] =
            '${currentPosition.latitude},${currentPosition.longitude}';
        queryParams['radius'] = configuredRadius;
        if (strictBoundsEnabled) {
          queryParams['strictbounds'] = 'true';
        }
      }

      final url = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/autocomplete/json',
        queryParams,
      );

      final response = await _getWithRetry(url);

      if (response.statusCode != 200) {
        DebugLogger.error(
          'Google Places API request failed: ${response.statusCode}',
        );
        if (kDebugMode) {
          DebugLogger.error('Response body: ${response.body}');
        }
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final status = data['status'] as String?;
      final errorMessage = data['error_message'] as String?;

      switch (status) {
        case 'OK':
          final predictions = data['predictions'] as List;
          return predictions.map((prediction) {
            return PlaceSuggestion(
              placeId: prediction['place_id'] as String,
              description: prediction['description'] as String? ?? '',
              mainText:
                  prediction['structured_formatting']?['main_text'] as String? ??
                  '',
              secondaryText:
                  prediction['structured_formatting']?['secondary_text']
                      as String? ??
                  '',
            );
          }).toList();

        case 'ZERO_RESULTS':
          DebugLogger.info(
            'Google Places API returned no results for query: $query',
          );
          return [];

        case 'OVER_QUERY_LIMIT':
        case 'REQUEST_DENIED':
        case 'INVALID_REQUEST':
          _logApiFailure('autocomplete', status, errorMessage);
          _disableGoogleTemporarily();
          return null;

        default:
          _logApiFailure('autocomplete', status, errorMessage);
          return null;
      }
    } on TimeoutException catch (e) {
      DebugLogger.error(
        'Google Places API request timed out for query: $query',
        e,
      );
      return null;
    } catch (e, stackTrace) {
      DebugLogger.error(
        'Error getting place suggestions for query: $query',
        e,
        stackTrace,
      );
      return null;
    }
  }

  /// OpenStreetMap Nominatim search (no API key / billing required).
  Future<List<PlaceSuggestion>> _searchNominatim(String query) async {
    try {
      final countryCode = (dotenv.env['DEFAULT_COUNTRY'] ?? 'in').toLowerCase();
      final url = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query,
        'format': 'json',
        'addressdetails': '1',
        'limit': '8',
        'countrycodes': countryCode,
      });

      final response = await http
          .get(
            url,
            headers: {
              // Nominatim usage policy requires a valid User-Agent.
              'User-Agent': 'ghar360-flutter/1.0 (location-search)',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        DebugLogger.error(
          'Nominatim search failed: HTTP ${response.statusCode}',
        );
        _setError('failed_to_search_locations'.tr);
        return [];
      }

      final decoded = json.decode(response.body);
      if (decoded is! List) {
        DebugLogger.warning('Nominatim returned unexpected payload');
        return [];
      }

      final suggestions = <PlaceSuggestion>[];
      for (final item in decoded) {
        if (item is! Map<String, dynamic>) continue;
        final lat = double.tryParse(item['lat']?.toString() ?? '');
        final lon = double.tryParse(item['lon']?.toString() ?? '');
        if (lat == null || lon == null) continue;

        final displayName = (item['display_name'] as String?)?.trim() ?? '';
        if (displayName.isEmpty) continue;

        final parts = displayName.split(',').map((p) => p.trim()).toList();
        final mainText = parts.isNotEmpty ? parts.first : displayName;
        final secondaryText = parts.length > 1
            ? parts.skip(1).take(3).join(', ')
            : '';

        final osmType = item['osm_type']?.toString() ?? 'n';
        final osmId = item['osm_id']?.toString() ?? '${lat}_$lon';
        final placeId = '$_osmPlaceIdPrefix$osmType$osmId|$lat|$lon';

        suggestions.add(
          PlaceSuggestion(
            placeId: placeId,
            description: displayName,
            mainText: mainText,
            secondaryText: secondaryText,
            latitude: lat,
            longitude: lon,
          ),
        );
      }

      if (suggestions.isEmpty) {
        DebugLogger.info('Nominatim returned no results for query: $query');
      }
      return suggestions;
    } on TimeoutException catch (e) {
      DebugLogger.error('Nominatim search timed out for query: $query', e);
      _setError('places_api_timeout'.tr);
      return [];
    } catch (e, stackTrace) {
      DebugLogger.error(
        'Nominatim search error for query: $query',
        e,
        stackTrace,
      );
      _setError('failed_to_search_locations'.tr);
      return [];
    }
  }

  /// Fetches place details (coordinates, name) for [placeId].
  Future<LocationData?> getPlaceDetails(
    String placeId, {
    String? preferredName,
  }) async {
    // Resolve from in-memory suggestions first (covers OSM + any pre-resolved).
    for (final suggestion in placeSuggestions) {
      if (suggestion.placeId == placeId && suggestion.hasCoordinates) {
        _clearError();
        return LocationData(
          name: (preferredName != null && preferredName.isNotEmpty)
              ? preferredName
              : (suggestion.mainText.isNotEmpty
                    ? suggestion.mainText
                    : suggestion.description),
          latitude: suggestion.latitude!,
          longitude: suggestion.longitude!,
        );
      }
    }

    // OSM place ids encode lat/lng: osm:node123|28.6|77.2
    if (placeId.startsWith(_osmPlaceIdPrefix)) {
      final parsed = _parseOsmPlaceId(placeId);
      if (parsed != null) {
        _clearError();
        return LocationData(
          name: (preferredName != null && preferredName.isNotEmpty)
              ? preferredName
              : parsed.$3,
          latitude: parsed.$1,
          longitude: parsed.$2,
        );
      }
      _setError('location_details_failed'.tr);
      return null;
    }

    return _getGooglePlaceDetails(placeId, preferredName: preferredName);
  }

  /// Returns (lat, lng, fallbackName).
  (double, double, String)? _parseOsmPlaceId(String placeId) {
    try {
      final body = placeId.substring(_osmPlaceIdPrefix.length);
      final parts = body.split('|');
      if (parts.length < 3) return null;
      final lat = double.tryParse(parts[1]);
      final lng = double.tryParse(parts[2]);
      if (lat == null || lng == null) return null;
      return (lat, lng, parts[0]);
    } catch (_) {
      return null;
    }
  }

  Future<LocationData?> _getGooglePlaceDetails(
    String placeId, {
    String? preferredName,
  }) async {
    try {
      final apiKey = dotenv.env['GOOGLE_PLACES_API_KEY'] ?? '';
      if (apiKey.isEmpty) {
        DebugLogger.warning(
          'Google Places API key not found '
          '(GOOGLE_PLACES_API_KEY missing from env)',
        );
        _setError('places_api_key_missing'.tr);
        return null;
      }

      final url = Uri.https('maps.googleapis.com', '/maps/api/place/details/json', {
        'place_id': placeId,
        'fields': 'name,geometry,address_components',
        'key': apiKey,
      });

      final response = await _getWithRetry(url);

      if (response.statusCode != 200) {
        DebugLogger.error(
          'Google Places Details API request failed: ${response.statusCode}',
        );
        if (kDebugMode) {
          DebugLogger.error('Response body: ${response.body}');
        }
        _setError('location_details_failed'.tr);
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final status = data['status'] as String?;
      final errorMessage = data['error_message'] as String?;

      switch (status) {
        case 'OK':
          final result = data['result'];
          if (result != null) {
            final location = result['geometry']['location'];
            final addressComponents = result['address_components'] as List;

            String displayName;
            if (preferredName != null && preferredName.isNotEmpty) {
              displayName = preferredName;
            } else {
              String? city;
              String? locality;

              for (final component in addressComponents) {
                final types = component['types'] as List;
                if (types.contains('locality')) {
                  locality = component['long_name'];
                }
                if (types.contains('administrative_area_level_2')) {
                  city = component['long_name'];
                }
              }

              displayName = result['name'] ?? '';
              if (locality != null && city != null) {
                displayName = '$locality, $city';
              } else if (city != null) {
                displayName = city;
              } else if (locality != null) {
                displayName = locality;
              }
            }

            _clearError();
            return LocationData(
              name: displayName,
              latitude: location['lat'].toDouble(),
              longitude: location['lng'].toDouble(),
            );
          }
          DebugLogger.warning(
            'Google Places Details API returned null result '
            'for placeId: $placeId',
          );
          _setError('location_details_failed'.tr);
          return null;

        case 'ZERO_RESULTS':
        case 'NOT_FOUND':
          _logApiFailure('details', status, errorMessage);
          _setError('location_details_failed'.tr);
          return null;

        case 'OVER_QUERY_LIMIT':
        case 'REQUEST_DENIED':
        case 'INVALID_REQUEST':
          _logApiFailure('details', status, errorMessage);
          _disableGoogleTemporarily();
          _setError('location_details_failed'.tr);
          return null;

        default:
          _logApiFailure('details', status, errorMessage);
          _setError('location_details_failed'.tr);
          return null;
      }
    } on TimeoutException catch (e) {
      DebugLogger.error(
        'Google Places Details API request timed out '
        'for placeId: $placeId',
        e,
      );
      _setError('places_api_timeout'.tr);
      return null;
    } catch (e, stackTrace) {
      DebugLogger.error(
        'Error getting place details for placeId: $placeId',
        e,
        stackTrace,
      );
      _setError('location_details_failed'.tr);
      return null;
    }
  }

  Future<http.Response> _getWithRetry(
    Uri url, {
    int maxRetries = 1,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        return await http.get(url).timeout(timeout);
      } on TimeoutException {
        if (attempt == maxRetries) rethrow;
        DebugLogger.warning(
          '🌍 Places API timeout (attempt ${attempt + 1}), '
          'retrying...',
        );
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    throw TimeoutException('Request timed out after retries');
  }

  void clearPlaceSuggestions() {
    placeSuggestions.clear();
    _clearError();
  }
}
