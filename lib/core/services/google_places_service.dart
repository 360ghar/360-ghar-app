import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:ghar360/core/data/models/popular_city.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:http/http.dart' as http;

class PlaceSuggestion {
  const PlaceSuggestion({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
    this.latitude,
    this.longitude,
  });
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;
  final double? latitude;
  final double? longitude;
  bool get hasCoordinates => _validCoordinates(latitude, longitude);
}

bool _validCoordinates(double? latitude, double? longitude) =>
    latitude != null &&
    longitude != null &&
    latitude.isFinite &&
    longitude.isFinite &&
    latitude.abs() <= 90 &&
    longitude.abs() <= 180;

/// HTTP boundary only. The search provider owns visible results and generations.
/// Public Nominatim fallback is for explicit searches, never autocomplete:
/// https://operations.osmfoundation.org/policies/nominatim/
class GooglePlacesService {
  GooglePlacesService({
    required this._client,
    required this._apiKey,
    String country = 'in',
    int radiusMeters = 25000,
    this._strictBounds = false,
    Uri? nominatimEndpoint,
    DateTime Function()? now,
    Future<void> Function(Duration)? wait,
  }) : _country = country.toLowerCase(),
       _radiusMeters = radiusMeters.clamp(1, 200000),
       _nominatimEndpoint =
           nominatimEndpoint ?? Uri.https('nominatim.openstreetmap.org', '/search'),
       _now = now ?? DateTime.now,
       _wait = wait ?? Future<void>.delayed;
  final http.Client _client;
  final String _apiKey;
  final String _country;
  final int _radiusMeters;
  final bool _strictBounds;
  final Uri _nominatimEndpoint;
  final DateTime Function() _now;
  final Future<void> Function(Duration) _wait;
  DateTime? _googleDisabledUntil;
  DateTime? _lastNominatimRequestAt;
  Future<void> _nominatimQueue = Future.value();
  final _cache = <String, List<PlaceSuggestion>>{};
  bool _disposed = false;
  static const _minimumInterval = Duration(milliseconds: 1100);

  bool get _googleAvailable =>
      _apiKey.isNotEmpty &&
      (_googleDisabledUntil == null || !_now().isBefore(_googleDisabledUntil!));
  void _checkActive() {
    if (_disposed) throw NetworkException('Cancelled', code: 'CANCELLED');
  }

  Future<List<PlaceSuggestion>> getPlaceSuggestions(
    String query, {
    Position? currentPosition,
    bool allowFallback = true,
    bool Function()? isCurrent,
  }) async {
    final text = query.trim();
    if (text.length < 2) return const [];
    _checkActive();
    bool current() => !_disposed && (isCurrent?.call() ?? true);
    if (_googleAvailable) {
      try {
        final results = await _googleSearch(text, currentPosition);
        if (!current()) return const [];
        if (results.isNotEmpty || !allowFallback) return results;
      } on AppException {
        if (!current()) return const [];
        if (!allowFallback) rethrow;
      }
    } else if (!allowFallback) {
      // The UI keeps an explicit Search action for the alternate provider.
      return const [];
    }
    if (!current()) return const [];
    return _nominatimSearch(text, current);
  }

  Future<Map<String, dynamic>> _googleGet(String path, Map<String, String> parameters) async {
    if (_apiKey.isEmpty) {
      throw LocationException('Place provider unavailable', code: 'PLACES_UNAVAILABLE');
    }
    final uri = Uri.https('maps.googleapis.com', path, {...parameters, 'key': _apiKey});
    final response = await _getWithRetry(uri);
    if (response.statusCode != 200) {
      throw LocationException('Place request failed', code: 'PLACES_UNAVAILABLE');
    }
    try {
      final raw = jsonDecode(response.body);
      if (raw is! Map<String, dynamic>) throw const FormatException();
      final status = raw['status'];
      if (status == 'REQUEST_DENIED' || status == 'OVER_QUERY_LIMIT') {
        _googleDisabledUntil = _now().add(const Duration(minutes: 10));
      }
      if (status == 'ZERO_RESULTS' || status == 'NOT_FOUND') return {'status': status};
      if (status != 'OK') {
        throw LocationException('Place request failed', code: 'PLACES_UNAVAILABLE');
      }
      return raw;
    } on FormatException {
      throw LocationException('Invalid place response', code: 'PLACES_MALFORMED');
    }
  }

  Future<List<PlaceSuggestion>> _googleSearch(String text, Position? position) async {
    final data = await _googleGet('/maps/api/place/autocomplete/json', {
      'input': text,
      'components': 'country:$_country',
      if (position != null) ...{
        'location': '${position.latitude},${position.longitude}',
        'radius': '$_radiusMeters',
        if (_strictBounds) 'strictbounds': 'true',
      },
    });
    if (data['status'] == 'ZERO_RESULTS') return const [];
    final raw = data['predictions'];
    if (raw is! List) throw LocationException('Invalid place response', code: 'PLACES_MALFORMED');
    final items = <PlaceSuggestion>[];
    for (final item in raw.whereType<Map>()) {
      final id = item['place_id'];
      if (id is! String || id.isEmpty) continue;
      final formatting = item['structured_formatting'];
      items.add(
        PlaceSuggestion(
          placeId: id,
          description: item['description'] is String ? item['description'] as String : '',
          mainText: formatting is Map && formatting['main_text'] is String
              ? formatting['main_text'] as String
              : '',
          secondaryText: formatting is Map && formatting['secondary_text'] is String
              ? formatting['secondary_text'] as String
              : '',
        ),
      );
    }
    return List.unmodifiable(items);
  }

  Future<List<PlaceSuggestion>> _nominatimSearch(String query, bool Function() isCurrent) {
    final request = _nominatimQueue.then((_) => _readNominatim(query, isCurrent));
    _nominatimQueue = request.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return request;
  }

  Future<List<PlaceSuggestion>> _readNominatim(String query, bool Function() isCurrent) async {
    if (!isCurrent()) return const [];
    final key = '${query.toLowerCase()}|$_country';
    final cached = _cache[key];
    if (cached != null) return cached;
    final last = _lastNominatimRequestAt;
    if (last != null) {
      final elapsed = _now().difference(last);
      if (elapsed < _minimumInterval) await _wait(_minimumInterval - elapsed);
    }
    if (!isCurrent()) return const [];
    _lastNominatimRequestAt = _now();
    try {
      final uri = _nominatimEndpoint.replace(
        queryParameters: {
          'q': query,
          'format': 'json',
          'addressdetails': '1',
          'limit': '8',
          'countrycodes': _country,
        },
      );
      final response = await _client
          .get(
            uri,
            headers: {
              'User-Agent': '360Ghar/1.0 (https://360ghar.com; location-search)',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 12));
      if (!isCurrent()) return const [];
      if (response.statusCode != 200) {
        throw LocationException('Place search failed', code: 'PLACES_UNAVAILABLE');
      }
      final raw = jsonDecode(response.body);
      if (raw is! List) throw const FormatException();
      final items = <PlaceSuggestion>[];
      for (final item in raw.whereType<Map>()) {
        final latitude = double.tryParse('${item['lat']}');
        final longitude = double.tryParse('${item['lon']}');
        final name = item['display_name'];
        if (!_validCoordinates(latitude, longitude) || name is! String || name.trim().isEmpty) {
          continue;
        }
        final parts = name.split(',').map((part) => part.trim()).toList();
        items.add(
          PlaceSuggestion(
            placeId:
                'osm:${item['osm_type'] ?? 'n'}${item['osm_id'] ?? '$latitude,$longitude'}|$latitude|$longitude',
            description: name.trim(),
            mainText: parts.first,
            secondaryText: parts.skip(1).take(3).join(', '),
            latitude: latitude,
            longitude: longitude,
          ),
        );
      }
      if (_cache.length >= 32) _cache.remove(_cache.keys.first);
      return _cache[key] = List.unmodifiable(items);
    } on TimeoutException {
      throw LocationException('Place search timed out', code: 'PLACES_TIMEOUT');
    } on AppException {
      rethrow;
    } on FormatException {
      throw LocationException('Invalid place response', code: 'PLACES_MALFORMED');
    } on Object {
      throw LocationException('Place search unavailable', code: 'PLACES_UNAVAILABLE');
    }
  }

  Future<LocationData> getPlaceDetails(String placeId, {String? preferredName}) async {
    _checkActive();
    if (PopularCity.isPopularPlaceId(placeId) || placeId.startsWith('osm:')) {
      final parts = placeId.substring(placeId.indexOf(':') + 1).split('|');
      if (parts.length == 3) {
        final latitude = double.tryParse(parts[1]);
        final longitude = double.tryParse(parts[2]);
        if (_validCoordinates(latitude, longitude)) {
          return LocationData(
            name: preferredName?.trim().isNotEmpty == true ? preferredName! : parts[0],
            latitude: latitude!,
            longitude: longitude!,
          );
        }
      }
      throw LocationException('Invalid place coordinates', code: 'PLACES_MALFORMED');
    }
    final data = await _googleGet('/maps/api/place/details/json', {
      'place_id': placeId,
      'fields': 'name,geometry,address_components',
    });
    _checkActive();
    final result = data['result'];
    if (result is! Map) throw LocationException('Place not found', code: 'PLACES_NOT_FOUND');
    final geometry = result['geometry'];
    final coordinates = geometry is Map ? geometry['location'] : null;
    final latitude = coordinates is Map ? double.tryParse('${coordinates['lat']}') : null;
    final longitude = coordinates is Map ? double.tryParse('${coordinates['lng']}') : null;
    if (!_validCoordinates(latitude, longitude)) {
      throw LocationException('Invalid place coordinates', code: 'PLACES_MALFORMED');
    }
    String? city;
    String? locality;
    final components = result['address_components'];
    if (components is List) {
      for (final item in components.whereType<Map>()) {
        final types = item['types'];
        final name = item['long_name'];
        if (types is! List || name is! String) continue;
        if (types.contains('locality')) locality = name;
        if (types.contains('administrative_area_level_2')) city = name;
      }
    }
    return LocationData(
      name: preferredName?.trim().isNotEmpty == true
          ? preferredName!
          : [locality, city].whereType<String>().join(', ').isNotEmpty
          ? [locality, city].whereType<String>().join(', ')
          : result['name'] is String
          ? result['name'] as String
          : '',
      latitude: latitude!,
      longitude: longitude!,
    );
  }

  Future<http.Response> _getWithRetry(Uri uri) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      _checkActive();
      try {
        return await _client.get(uri).timeout(const Duration(seconds: 10));
      } on TimeoutException {
        if (attempt == 1) {
          throw LocationException('Place request timed out', code: 'PLACES_TIMEOUT');
        }
        await _wait(const Duration(seconds: 2));
      } on Object {
        throw LocationException('Place request failed', code: 'PLACES_UNAVAILABLE');
      }
    }
    throw StateError('Unreachable');
  }

  void dispose() {
    _disposed = true;
    _cache.clear();
    _client.close();
  }
}
