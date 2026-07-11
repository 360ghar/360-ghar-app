import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:http/http.dart' as http;

/// Place suggestion from Google Places Autocomplete.
class PlaceSuggestion {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  PlaceSuggestion({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });
}

/// Service responsible for Google Places API interactions.
/// Extracted from LocationController to follow single-responsibility.
class GooglePlacesService extends GetxService {
  final RxList<PlaceSuggestion> placeSuggestions = <PlaceSuggestion>[].obs;
  final RxBool isSearchingPlaces = false.obs;

  /// User-facing error key or message for the last failed Places call.
  /// Empty string means no active error (success or real zero results).
  final RxString placesError = ''.obs;

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

  String _userMessageForStatus(String? status) {
    switch (status) {
      case 'REQUEST_DENIED':
        return 'places_api_request_denied'.tr;
      case 'OVER_QUERY_LIMIT':
        return 'places_api_quota_exceeded'.tr;
      case 'INVALID_REQUEST':
        return 'places_api_invalid_request'.tr;
      default:
        return 'failed_to_search_locations'.tr;
    }
  }

  /// Fetches place autocomplete suggestions for [query].
  /// Optionally biases results toward [currentPosition].
  Future<List<PlaceSuggestion>> getPlaceSuggestions(
    String query, {
    Position? currentPosition,
  }) async {
    if (query.trim().isEmpty || query.length < 2) {
      placeSuggestions.clear();
      _clearError();
      return [];
    }

    try {
      isSearchingPlaces.value = true;
      _clearError();

      final apiKey = dotenv.env['GOOGLE_PLACES_API_KEY'] ?? '';
      if (apiKey.isEmpty) {
        DebugLogger.warning(
          'Google Places API key not found '
          '(GOOGLE_PLACES_API_KEY missing from env)',
        );
        placeSuggestions.clear();
        _setError('places_api_key_missing'.tr);
        return [];
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
            (dotenv.env['PLACES_STRICT_BOUNDS'] ?? 'false').toLowerCase() == 'true';
        queryParams['location'] = '${currentPosition.latitude},${currentPosition.longitude}';
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
        DebugLogger.error('Google Places API request failed: ${response.statusCode}');
        if (kDebugMode) {
          DebugLogger.error('Response body: ${response.body}');
        }
        placeSuggestions.clear();
        _setError('failed_to_search_locations'.tr);
        return [];
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final status = data['status'] as String?;
      final errorMessage = data['error_message'] as String?;

      switch (status) {
        case 'OK':
          final predictions = data['predictions'] as List;
          final suggestions = predictions.map((prediction) {
            return PlaceSuggestion(
              placeId: prediction['place_id'],
              description: prediction['description'],
              mainText: prediction['structured_formatting']?['main_text'] ?? '',
              secondaryText: prediction['structured_formatting']?['secondary_text'] ?? '',
            );
          }).toList();

          placeSuggestions.value = suggestions;
          _clearError();
          return suggestions;

        case 'ZERO_RESULTS':
          DebugLogger.info('Google Places API returned no results for query: $query');
          placeSuggestions.clear();
          _clearError();
          return [];

        case 'OVER_QUERY_LIMIT':
        case 'REQUEST_DENIED':
        case 'INVALID_REQUEST':
          _logApiFailure('autocomplete', status, errorMessage);
          placeSuggestions.clear();
          _setError(_userMessageForStatus(status));
          return [];

        default:
          _logApiFailure('autocomplete', status, errorMessage);
          placeSuggestions.clear();
          _setError(_userMessageForStatus(status));
          return [];
      }
    } on TimeoutException catch (e) {
      DebugLogger.error('Google Places API request timed out for query: $query', e);
      placeSuggestions.clear();
      _setError('places_api_timeout'.tr);
      return [];
    } catch (e, stackTrace) {
      DebugLogger.error('Error getting place suggestions for query: $query', e, stackTrace);
      placeSuggestions.clear();
      _setError('failed_to_search_locations'.tr);
      return [];
    } finally {
      isSearchingPlaces.value = false;
    }
  }

  /// Fetches place details (coordinates, name) for [placeId].
  /// If [preferredName] is provided, it is used as the display name.
  Future<LocationData?> getPlaceDetails(String placeId, {String? preferredName}) async {
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
        DebugLogger.error('Google Places Details API request failed: ${response.statusCode}');
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
          _setError(_userMessageForStatus(status));
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
      DebugLogger.error('Error getting place details for placeId: $placeId', e, stackTrace);
      _setError('location_details_failed'.tr);
      return null;
    }
  }

  /// Performs an HTTP GET with retry on timeout.
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
    // Should not reach here, but satisfy analyzer
    throw TimeoutException('Request timed out after retries');
  }

  void clearPlaceSuggestions() {
    placeSuggestions.clear();
    _clearError();
  }
}
