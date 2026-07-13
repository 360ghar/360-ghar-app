import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ghar360/core/config/app_config.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/services/google_places_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Standard AppConfig with a non-empty API key so the service proceeds
  /// past the guard branch and makes an HTTP request (which we intercept).
  void initConfigWithKey() {
    AppConfig.initialize(
      overrides: const <String, String>{
        'API_BASE_URL': 'https://api.360ghar.com',
        'SUPABASE_URL': 'https://example.supabase.co',
        'SUPABASE_PUBLISHABLE_KEY': 'key',
        'GOOGLE_PLACES_API_KEY': 'test-api-key',
        'DEFAULT_COUNTRY': 'in',
      },
    );
  }

  void initConfigWithoutKey() {
    AppConfig.initialize(
      overrides: const <String, String>{
        'API_BASE_URL': 'https://api.360ghar.com',
        'SUPABASE_URL': 'https://example.supabase.co',
        'SUPABASE_PUBLISHABLE_KEY': 'key',
        'GOOGLE_PLACES_API_KEY': '',
        'DEFAULT_COUNTRY': 'in',
      },
    );
  }

  /// Builds a [MockClient] that returns canned responses for Google Places
  /// autocomplete and details endpoints based on the request URL path.
  http.Client buildMockClient({
    Map<String, String> autocompleteResponses = const {},
    Map<String, String> detailsResponses = const {},
    int autocompleteStatusCode = 200,
    int detailsStatusCode = 200,
  }) {
    return MockClient((request) async {
      final path = request.url.path;
      final query = request.url.queryParameters;

      String body;
      int statusCode;

      if (path.contains('autocomplete')) {
        final input = query['input'] ?? '';
        body =
            autocompleteResponses[input] ??
            jsonEncode(<String, dynamic>{'status': 'INVALID_REQUEST'});
        statusCode = autocompleteStatusCode;
      } else if (path.contains('details')) {
        final placeId = query['place_id'] ?? '';
        body = detailsResponses[placeId] ?? jsonEncode(<String, dynamic>{'status': 'NOT_FOUND'});
        statusCode = detailsStatusCode;
      } else {
        body = jsonEncode(<String, dynamic>{'status': 'INVALID_REQUEST'});
        statusCode = 400;
      }

      return http.Response(body, statusCode);
    });
  }

  group('GooglePlacesService.getPlaceSuggestions (no network)', () {
    late GooglePlacesService service;

    setUp(() {
      initConfigWithoutKey();
      service = GooglePlacesService();
      service.clearPlaceSuggestions();
    });

    tearDown(() {
      AppConfig.resetForTest();
    });

    test('returns empty list and clears suggestions for empty query', () async {
      final result = await service.getPlaceSuggestions('');

      expect(result, isEmpty);
      expect(service.placeSuggestions, isEmpty);
    });

    test('returns empty list for whitespace-only query', () async {
      final result = await service.getPlaceSuggestions('   ');

      expect(result, isEmpty);
      expect(service.placeSuggestions, isEmpty);
    });

    test('returns empty list for single-character query (length < 2)', () async {
      final result = await service.getPlaceSuggestions('a');

      expect(result, isEmpty);
      expect(service.placeSuggestions, isEmpty);
    });

    test('resets isSearchingPlaces to false after empty-query early return', () async {
      await service.getPlaceSuggestions('');
      expect(service.isSearchingPlaces.value, isFalse);
    });

    test('resets isSearchingPlaces to false after short-query early return', () async {
      await service.getPlaceSuggestions('x');
      expect(service.isSearchingPlaces.value, isFalse);
    });

    test('returns empty list when API key is empty (guard branch)', () async {
      final result = await service.getPlaceSuggestions('kathmandu');

      expect(result, isEmpty);
      expect(service.placeSuggestions, isEmpty);
    });

    test('resets isSearchingPlaces to false after API-key-missing return', () async {
      await service.getPlaceSuggestions('kathmandu');
      expect(service.isSearchingPlaces.value, isFalse);
    });
  });

  group('GooglePlacesService.getPlaceDetails (no network)', () {
    late GooglePlacesService service;

    setUp(() {
      initConfigWithoutKey();
      service = GooglePlacesService();
    });

    tearDown(() {
      AppConfig.resetForTest();
    });

    test('returns null when API key is empty', () async {
      final result = await service.getPlaceDetails('place-id-1');

      expect(result, isNull);
    });

    test('returns null when API key is empty even with preferredName', () async {
      final result = await service.getPlaceDetails('place-id-1', preferredName: 'My Place');

      expect(result, isNull);
    });
  });

  group('GooglePlacesService reactive state', () {
    setUp(() {
      initConfigWithoutKey();
    });

    tearDown(() {
      AppConfig.resetForTest();
    });

    test('placeSuggestions starts empty', () {
      final service = GooglePlacesService();
      expect(service.placeSuggestions, isEmpty);
    });

    test('isSearchingPlaces starts false', () {
      final service = GooglePlacesService();
      expect(service.isSearchingPlaces.value, isFalse);
    });

    test('clearPlaceSuggestions empties the list', () {
      final service = GooglePlacesService();
      service.clearPlaceSuggestions();
      expect(service.placeSuggestions, isEmpty);
    });

    test('clearPlaceSuggestions is callable multiple times', () {
      final service = GooglePlacesService();
      expect(() {
        service.clearPlaceSuggestions();
        service.clearPlaceSuggestions();
      }, returnsNormally);
    });
  });

  group('PlaceSuggestion value object', () {
    test('stores all fields correctly', () {
      final suggestion = PlaceSuggestion(
        placeId: 'abc',
        description: 'Kathmandu, Nepal',
        mainText: 'Kathmandu',
        secondaryText: 'Nepal',
      );

      expect(suggestion.placeId, 'abc');
      expect(suggestion.description, 'Kathmandu, Nepal');
      expect(suggestion.mainText, 'Kathmandu');
      expect(suggestion.secondaryText, 'Nepal');
    });

    test('supports empty text fields', () {
      final suggestion = PlaceSuggestion(
        placeId: 'xyz',
        description: '',
        mainText: '',
        secondaryText: '',
      );

      expect(suggestion.placeId, 'xyz');
      expect(suggestion.description, '');
      expect(suggestion.mainText, '');
      expect(suggestion.secondaryText, '');
    });
  });

  group('LocationData value object', () {
    test('stores name and coordinates', () {
      const data = LocationData(name: 'Lalitpur', latitude: 27.67, longitude: 85.32);

      expect(data.name, 'Lalitpur');
      expect(data.latitude, 27.67);
      expect(data.longitude, 85.32);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // HTTP-mocked tests: exercise the actual JSON parsing and status-code
  // branches by intercepting HTTP requests via [http.runWithClient].
  // ─────────────────────────────────────────────────────────────────────

  group('GooglePlacesService.getPlaceSuggestions (HTTP mocked)', () {
    late GooglePlacesService service;

    setUp(() {
      initConfigWithKey();
      service = GooglePlacesService();
      service.clearPlaceSuggestions();
    });

    tearDown(() {
      AppConfig.resetForTest();
    });

    test('parses OK response with predictions', () async {
      final client = buildMockClient(
        autocompleteResponses: {
          'kathmandu': jsonEncode(<String, dynamic>{
            'status': 'OK',
            'predictions': [
              {
                'place_id': 'place-1',
                'description': 'Kathmandu, Nepal',
                'structured_formatting': {'main_text': 'Kathmandu', 'secondary_text': 'Nepal'},
              },
              {
                'place_id': 'place-2',
                'description': 'Kathmandu Valley, Nepal',
                'structured_formatting': {
                  'main_text': 'Kathmandu Valley',
                  'secondary_text': 'Nepal',
                },
              },
            ],
          }),
        },
      );

      final result = await http.runWithClient(
        () => service.getPlaceSuggestions('kathmandu'),
        () => client,
      );

      expect(result, hasLength(2));
      expect(result[0].placeId, 'place-1');
      expect(result[0].description, 'Kathmandu, Nepal');
      expect(result[0].mainText, 'Kathmandu');
      expect(result[0].secondaryText, 'Nepal');
      expect(result[1].placeId, 'place-2');
      expect(service.placeSuggestions, hasLength(2));
      expect(service.isSearchingPlaces.value, isFalse);
    });

    test('parses OK response with missing structured_formatting', () async {
      final client = buildMockClient(
        autocompleteResponses: {
          'test': jsonEncode(<String, dynamic>{
            'status': 'OK',
            'predictions': [
              {'place_id': 'place-x', 'description': 'Test Place'},
            ],
          }),
        },
      );

      final result = await http.runWithClient(
        () => service.getPlaceSuggestions('test'),
        () => client,
      );

      expect(result, hasLength(1));
      expect(result[0].placeId, 'place-x');
      expect(result[0].mainText, '');
      expect(result[0].secondaryText, '');
    });

    test('handles ZERO_RESULTS status', () async {
      final client = buildMockClient(
        autocompleteResponses: {
          'nowhere': jsonEncode(<String, dynamic>{
            'status': 'ZERO_RESULTS',
            'predictions': <dynamic>[],
          }),
        },
      );

      final result = await http.runWithClient(
        () => service.getPlaceSuggestions('nowhere'),
        () => client,
      );

      expect(result, isEmpty);
      expect(service.placeSuggestions, isEmpty);
      expect(service.isSearchingPlaces.value, isFalse);
    });

    test('handles OVER_QUERY_LIMIT status', () async {
      final client = buildMockClient(
        autocompleteResponses: {
          'query': jsonEncode(<String, dynamic>{'status': 'OVER_QUERY_LIMIT'}),
        },
      );

      final result = await http.runWithClient(
        () => service.getPlaceSuggestions('query'),
        () => client,
      );

      expect(result, isEmpty);
      expect(service.placeSuggestions, isEmpty);
    });

    test('handles REQUEST_DENIED status', () async {
      final client = buildMockClient(
        autocompleteResponses: {
          'denied': jsonEncode(<String, dynamic>{'status': 'REQUEST_DENIED'}),
        },
      );

      final result = await http.runWithClient(
        () => service.getPlaceSuggestions('denied'),
        () => client,
      );

      expect(result, isEmpty);
      expect(service.placeSuggestions, isEmpty);
    });

    test('handles INVALID_REQUEST status', () async {
      final client = buildMockClient(
        autocompleteResponses: {
          'invalid': jsonEncode(<String, dynamic>{'status': 'INVALID_REQUEST'}),
        },
      );

      final result = await http.runWithClient(
        () => service.getPlaceSuggestions('invalid'),
        () => client,
      );

      expect(result, isEmpty);
      expect(service.placeSuggestions, isEmpty);
    });

    test('handles unknown status', () async {
      final client = buildMockClient(
        autocompleteResponses: {
          'unknown': jsonEncode(<String, dynamic>{'status': 'SOME_NEW_STATUS'}),
        },
      );

      final result = await http.runWithClient(
        () => service.getPlaceSuggestions('unknown'),
        () => client,
      );

      expect(result, isEmpty);
      expect(service.placeSuggestions, isEmpty);
    });

    test('handles non-200 HTTP status code', () async {
      final client = buildMockClient(autocompleteStatusCode: 500);

      final result = await http.runWithClient(
        () => service.getPlaceSuggestions('error'),
        () => client,
      );

      expect(result, isEmpty);
      expect(service.placeSuggestions, isEmpty);
      expect(service.isSearchingPlaces.value, isFalse);
    });

    test('includes location and radius when currentPosition is provided', () async {
      final client = buildMockClient(
        autocompleteResponses: {
          'nearby': jsonEncode(<String, dynamic>{
            'status': 'OK',
            'predictions': [
              {
                'place_id': 'nearby-1',
                'description': 'Nearby Place',
                'structured_formatting': {'main_text': 'Nearby', 'secondary_text': 'Place'},
              },
            ],
          }),
        },
      );

      final position = Position(
        latitude: 27.7172,
        longitude: 85.3240,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );

      final result = await http.runWithClient(
        () => service.getPlaceSuggestions('nearby', currentPosition: position),
        () => client,
      );

      expect(result, hasLength(1));
      expect(result[0].placeId, 'nearby-1');
    });

    test('handles JSON decode error gracefully', () async {
      final client = MockClient((request) async {
        return http.Response('not valid json {{{', 200);
      });

      final result = await http.runWithClient(
        () => service.getPlaceSuggestions('badjson'),
        () => client,
      );

      expect(result, isEmpty);
      expect(service.placeSuggestions, isEmpty);
      expect(service.isSearchingPlaces.value, isFalse);
    });
  });

  group('GooglePlacesService.getPlaceDetails (HTTP mocked)', () {
    late GooglePlacesService service;

    setUp(() {
      initConfigWithKey();
      service = GooglePlacesService();
    });

    tearDown(() {
      AppConfig.resetForTest();
    });

    test('parses OK response with locality and city', () async {
      final client = buildMockClient(
        detailsResponses: {
          'place-1': jsonEncode(<String, dynamic>{
            'status': 'OK',
            'result': {
              'name': 'Connaught Place',
              'geometry': {
                'location': {'lat': 28.6315, 'lng': 77.2167},
              },
              'address_components': [
                {
                  'long_name': 'Connaught Place',
                  'types': ['locality'],
                },
                {
                  'long_name': 'New Delhi',
                  'types': ['administrative_area_level_2'],
                },
              ],
            },
          }),
        },
      );

      final result = await http.runWithClient(
        () => service.getPlaceDetails('place-1'),
        () => client,
      );

      expect(result, isNotNull);
      expect(result!.name, 'Connaught Place, New Delhi');
      expect(result.latitude, 28.6315);
      expect(result.longitude, 77.2167);
    });

    test('uses preferredName when provided', () async {
      final client = buildMockClient(
        detailsResponses: {
          'place-2': jsonEncode(<String, dynamic>{
            'status': 'OK',
            'result': {
              'name': 'Some Random Name',
              'geometry': {
                'location': {'lat': 27.0, 'lng': 85.0},
              },
              'address_components': <dynamic>[],
            },
          }),
        },
      );

      final result = await http.runWithClient(
        () => service.getPlaceDetails('place-2', preferredName: 'My Custom Name'),
        () => client,
      );

      expect(result, isNotNull);
      expect(result!.name, 'My Custom Name');
    });

    test('falls back to name when no locality or city found', () async {
      final client = buildMockClient(
        detailsResponses: {
          'place-3': jsonEncode(<String, dynamic>{
            'status': 'OK',
            'result': {
              'name': 'Just A Name',
              'geometry': {
                'location': {'lat': 27.0, 'lng': 85.0},
              },
              'address_components': <dynamic>[],
            },
          }),
        },
      );

      final result = await http.runWithClient(
        () => service.getPlaceDetails('place-3'),
        () => client,
      );

      expect(result, isNotNull);
      expect(result!.name, 'Just A Name');
    });

    test('uses city only when locality is missing', () async {
      final client = buildMockClient(
        detailsResponses: {
          'place-4': jsonEncode(<String, dynamic>{
            'status': 'OK',
            'result': {
              'name': 'Some Area',
              'geometry': {
                'location': {'lat': 27.0, 'lng': 85.0},
              },
              'address_components': [
                {
                  'long_name': 'Kathmandu',
                  'types': ['administrative_area_level_2'],
                },
              ],
            },
          }),
        },
      );

      final result = await http.runWithClient(
        () => service.getPlaceDetails('place-4'),
        () => client,
      );

      expect(result, isNotNull);
      expect(result!.name, 'Kathmandu');
    });

    test('uses locality only when city is missing', () async {
      final client = buildMockClient(
        detailsResponses: {
          'place-5': jsonEncode(<String, dynamic>{
            'status': 'OK',
            'result': {
              'name': 'Some Area',
              'geometry': {
                'location': {'lat': 27.0, 'lng': 85.0},
              },
              'address_components': [
                {
                  'long_name': 'Patan',
                  'types': ['locality'],
                },
              ],
            },
          }),
        },
      );

      final result = await http.runWithClient(
        () => service.getPlaceDetails('place-5'),
        () => client,
      );

      expect(result, isNotNull);
      expect(result!.name, 'Patan');
    });

    test('returns null when result is null in OK response', () async {
      final client = buildMockClient(
        detailsResponses: {
          'place-null': jsonEncode(<String, dynamic>{'status': 'OK', 'result': null}),
        },
      );

      final result = await http.runWithClient(
        () => service.getPlaceDetails('place-null'),
        () => client,
      );

      expect(result, isNull);
    });

    test('handles ZERO_RESULTS status', () async {
      final client = buildMockClient(
        detailsResponses: {
          'place-zr': jsonEncode(<String, dynamic>{'status': 'ZERO_RESULTS'}),
        },
      );

      final result = await http.runWithClient(
        () => service.getPlaceDetails('place-zr'),
        () => client,
      );

      expect(result, isNull);
    });

    test('handles OVER_QUERY_LIMIT status', () async {
      final client = buildMockClient(
        detailsResponses: {
          'place-ql': jsonEncode(<String, dynamic>{'status': 'OVER_QUERY_LIMIT'}),
        },
      );

      final result = await http.runWithClient(
        () => service.getPlaceDetails('place-ql'),
        () => client,
      );

      expect(result, isNull);
    });

    test('handles REQUEST_DENIED status', () async {
      final client = buildMockClient(
        detailsResponses: {
          'place-rd': jsonEncode(<String, dynamic>{'status': 'REQUEST_DENIED'}),
        },
      );

      final result = await http.runWithClient(
        () => service.getPlaceDetails('place-rd'),
        () => client,
      );

      expect(result, isNull);
    });

    test('handles INVALID_REQUEST status', () async {
      final client = buildMockClient(
        detailsResponses: {
          'place-ir': jsonEncode(<String, dynamic>{'status': 'INVALID_REQUEST'}),
        },
      );

      final result = await http.runWithClient(
        () => service.getPlaceDetails('place-ir'),
        () => client,
      );

      expect(result, isNull);
    });

    test('handles NOT_FOUND status', () async {
      final client = buildMockClient(
        detailsResponses: {
          'place-nf': jsonEncode(<String, dynamic>{'status': 'NOT_FOUND'}),
        },
      );

      final result = await http.runWithClient(
        () => service.getPlaceDetails('place-nf'),
        () => client,
      );

      expect(result, isNull);
    });

    test('handles unknown status', () async {
      final client = buildMockClient(
        detailsResponses: {
          'place-unknown': jsonEncode(<String, dynamic>{'status': 'WEIRD_STATUS'}),
        },
      );

      final result = await http.runWithClient(
        () => service.getPlaceDetails('place-unknown'),
        () => client,
      );

      expect(result, isNull);
    });

    test('handles non-200 HTTP status code', () async {
      final client = buildMockClient(detailsStatusCode: 403);

      final result = await http.runWithClient(
        () => service.getPlaceDetails('place-err'),
        () => client,
      );

      expect(result, isNull);
    });

    test('handles JSON decode error gracefully', () async {
      final client = MockClient((request) async {
        return http.Response('not valid json {{{', 200);
      });

      final result = await http.runWithClient(
        () => service.getPlaceDetails('place-badjson'),
        () => client,
      );

      expect(result, isNull);
    });
  });
}
