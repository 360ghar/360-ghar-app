import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/config/app_config.dart';
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

  /// Fetches place autocomplete suggestions for [query].
  /// Optionally biases results toward [currentPosition].
  Future<List<PlaceSuggestion>> getPlaceSuggestions(
    String query, {
    Position? currentPosition,
  }) async {
    if (query.trim().isEmpty || query.length < 2) {
      placeSuggestions.clear();
      return [];
    }

    try {
      isSearchingPlaces.value = true;

      final config = AppConfig.instance;
      final apiKey = config.googlePlacesApiKey;
      if (apiKey.isEmpty) {
        DebugLogger.warning('Google Places API key not found');
        placeSuggestions.clear();
        return [];
      }

      final countryCode = config.defaultCountry;
      final queryParams = <String, String>{
        'input': query,
        'components': 'country:$countryCode',
        'key': apiKey,
      };

      if (currentPosition != null) {
        queryParams['location'] = '${currentPosition.latitude},${currentPosition.longitude}';
        queryParams['radius'] = config.placesRadiusMeters;
        if (config.placesStrictBounds) {
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
        return [];
      }

      final data = json.decode(response.body);
      final status = data['status'];

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
          return suggestions;

        case 'ZERO_RESULTS':
          DebugLogger.info('Google Places API returned no results for query: $query');
          placeSuggestions.clear();
          return [];

        case 'OVER_QUERY_LIMIT':
          DebugLogger.error('Google Places API quota exceeded for query: $query');
          placeSuggestions.clear();
          return [];

        case 'REQUEST_DENIED':
          DebugLogger.error('Google Places API request denied for query: $query');
          placeSuggestions.clear();
          return [];

        case 'INVALID_REQUEST':
          DebugLogger.error('Invalid Google Places API request for query: $query');
          placeSuggestions.clear();
          return [];

        default:
          DebugLogger.warning('Unknown Google Places API status: $status for query: $query');
          placeSuggestions.clear();
          return [];
      }
    } on TimeoutException catch (e) {
      DebugLogger.error('Google Places API request timed out for query: $query', e);
      placeSuggestions.clear();
      return [];
    } catch (e, stackTrace) {
      DebugLogger.error('Error getting place suggestions for query: $query', e, stackTrace);
      placeSuggestions.clear();
      return [];
    } finally {
      isSearchingPlaces.value = false;
    }
  }

  /// Fetches place details (coordinates, name) for [placeId].
  /// If [preferredName] is provided, it is used as the display name.
  Future<LocationData?> getPlaceDetails(String placeId, {String? preferredName}) async {
    try {
      final apiKey = AppConfig.instance.googlePlacesApiKey;
      if (apiKey.isEmpty) {
        DebugLogger.warning('Google Places API key not found');
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
        return null;
      }

      final data = json.decode(response.body);
      final status = data['status'];

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
          return null;

        case 'ZERO_RESULTS':
          DebugLogger.info(
            'Google Places Details API returned no results '
            'for placeId: $placeId',
          );
          return null;

        case 'OVER_QUERY_LIMIT':
          DebugLogger.error(
            'Google Places Details API quota exceeded '
            'for placeId: $placeId',
          );
          return null;

        case 'REQUEST_DENIED':
          DebugLogger.error(
            'Google Places Details API request denied '
            'for placeId: $placeId',
          );
          return null;

        case 'INVALID_REQUEST':
          DebugLogger.error(
            'Invalid Google Places Details API request '
            'for placeId: $placeId',
          );
          return null;

        case 'NOT_FOUND':
          DebugLogger.warning('Place not found for placeId: $placeId');
          return null;

        default:
          DebugLogger.warning(
            'Unknown Google Places Details API status: $status '
            'for placeId: $placeId',
          );
          return null;
      }
    } on TimeoutException catch (e) {
      DebugLogger.error(
        'Google Places Details API request timed out '
        'for placeId: $placeId',
        e,
      );
      return null;
    } catch (e, stackTrace) {
      DebugLogger.error('Error getting place details for placeId: $placeId', e, stackTrace);
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
  }
}
