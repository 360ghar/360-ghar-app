import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/services/google_places_service.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import '../../helpers/fake_location_platform.dart';

void main() {
  http.Response response(Object body, [int status = 200]) =>
      http.Response(jsonEncode(body), status);
  const osm = [
    {'lat': '28.6', 'lon': '77.2', 'display_name': 'Delhi, India', 'osm_id': 1, 'osm_type': 'node'},
  ];
  GooglePlacesService service(
    Future<http.Response> Function(http.Request) send, {
    String key = 'test-key',
    int radius = 25000,
    bool strict = false,
  }) {
    final value = GooglePlacesService(
      client: MockClient(send),
      apiKey: key,
      radiusMeters: radius,
      strictBounds: strict,
      wait: (_) async {},
    );
    addTearDown(value.dispose);
    return value;
  }

  for (final query in ['', '   ', 'x']) {
    test('short query "$query" returns empty without network', () async {
      final places = service((_) => throw StateError('No network expected'));
      expect(await places.getPlaceSuggestions(query), isEmpty);
    });
  }
  test('missing key uses OSM only on explicit search', () async {
    final calls = <Uri>[];
    final places = service((request) async {
      calls.add(request.url);
      return response(osm);
    }, key: '');
    expect(await places.getPlaceSuggestions('Delhi', allowFallback: false), isEmpty);
    expect(calls, isEmpty);
    final result = await places.getPlaceSuggestions('Delhi');
    expect(result.single.mainText, 'Delhi');
    expect(result.single.secondaryText, 'India');
    expect(result.single.description, 'Delhi, India');
    expect(result.single.hasCoordinates, isTrue);
    expect(calls.single.host, 'nominatim.openstreetmap.org');
  });
  test('value objects retain fields and reject invalid coordinates', () {
    const suggestion = PlaceSuggestion(
      placeId: 'a',
      description: 'City, Region',
      mainText: 'City',
      secondaryText: 'Region',
      latitude: 28,
      longitude: 77,
    );
    expect(suggestion.placeId, 'a');
    expect(suggestion.description, 'City, Region');
    expect(suggestion.mainText, 'City');
    expect(suggestion.secondaryText, 'Region');
    expect(suggestion.hasCoordinates, isTrue);
    expect(
      const PlaceSuggestion(
        placeId: '',
        description: '',
        mainText: '',
        secondaryText: '',
        latitude: 95,
        longitude: 77,
      ).hasCoordinates,
      isFalse,
    );
    const location = LocationData(name: 'Delhi', latitude: 28, longitude: 77);
    expect(location.name, 'Delhi');
    expect(location.latitude, 28);
    expect(location.longitude, 77);
  });
  test('Google predictions preserve names and tolerate missing formatting', () async {
    final places = service(
      (_) async => response({
        'status': 'OK',
        'predictions': [
          {
            'place_id': 'one',
            'description': 'Delhi, India',
            'structured_formatting': {'main_text': 'Delhi', 'secondary_text': 'India'},
          },
          {'place_id': 'two', 'description': 'Gurgaon'},
          {'description': 'missing id'},
          42,
        ],
      }),
    );
    final result = await places.getPlaceSuggestions('Delhi');
    expect(result, hasLength(2));
    expect(result.first.placeId, 'one');
    expect(result.first.mainText, 'Delhi');
    expect(result.first.secondaryText, 'India');
    expect(result.first.description, 'Delhi, India');
    expect(result.last.mainText, '');
    expect(result.last.secondaryText, '');
    expect(() => result.clear(), throwsUnsupportedError);
  });
  for (final status in [
    'ZERO_RESULTS',
    'OVER_QUERY_LIMIT',
    'REQUEST_DENIED',
    'INVALID_REQUEST',
    'UNKNOWN_ERROR',
  ]) {
    test('$status falls back and keeps real empty results distinct from failure', () async {
      final places = service(
        (request) async =>
            request.url.host.contains('google') ? response({'status': status}) : response(osm),
      );
      expect((await places.getPlaceSuggestions('Delhi')).single.mainText, 'Delhi');
    });
  }
  for (final malformed in [false, true]) {
    test('Google ${malformed ? 'malformed JSON' : 'HTTP error'} falls back', () async {
      final places = service(
        (request) async => request.url.host.contains('google')
            ? http.Response(malformed ? '{bad' : '', malformed ? 200 : 503)
            : response(osm),
      );
      expect((await places.getPlaceSuggestions('Delhi')).single.latitude, 28.6);
    });
  }
  test('zero results from both providers are a successful empty search', () async {
    final places = service(
      (request) async =>
          request.url.host.contains('google') ? response({'status': 'ZERO_RESULTS'}) : response([]),
    );
    expect(await places.getPlaceSuggestions('Nowhere'), isEmpty);
  });
  test('fallback HTTP failure and malformed response throw typed errors', () async {
    for (final reply in [http.Response('', 503), response({}), http.Response('{bad', 200)]) {
      final places = service((_) async => reply, key: '');
      await expectLater(places.getPlaceSuggestions('Delhi'), throwsA(isA<LocationException>()));
    }
  });
  test('Google cooldown lasts ten minutes and does not leak raw errors', () async {
    var now = DateTime(2026);
    var googleCalls = 0;
    final places = GooglePlacesService(
      client: MockClient((request) async {
        if (request.url.host.contains('google')) {
          googleCalls++;
          return response({'status': 'REQUEST_DENIED', 'error_message': 'private raw body'});
        }
        return response([]);
      }),
      apiKey: 'key',
      now: () => now,
      wait: (duration) async {
        now = now.add(duration);
      },
    );
    addTearDown(places.dispose);
    await places.getPlaceSuggestions('one');
    await places.getPlaceSuggestions('two');
    expect(googleCalls, 1);
    now = now.add(const Duration(minutes: 10));
    await places.getPlaceSuggestions('three');
    expect(googleCalls, 2);
  });
  test('location bias preserves configured radius and optional strict bounds', () async {
    for (final radius in [25, 25000, 999999]) {
      Uri? uri;
      final places = service(
        (request) async {
          uri = request.url;
          return response({'status': 'ZERO_RESULTS'});
        },
        radius: radius,
        strict: true,
      );
      await places.getPlaceSuggestions(
        'Delhi',
        currentPosition: testPosition(),
        allowFallback: false,
      );
      expect(uri!.queryParameters['radius'], '${radius.clamp(1, 200000)}');
      expect(uri!.queryParameters['strictbounds'], 'true');
      expect(uri!.queryParameters['location'], '28.6139,77.209');
      expect(uri!.queryParameters['components'], 'country:in');
      expect(uri!.queryParameters, isNot(contains('types')));
    }
  });
  test('OSM requests are serialized, cached, identified, and validate coordinates', () async {
    var now = DateTime(2026);
    final starts = <DateTime>[];
    final places = GooglePlacesService(
      client: MockClient((request) async {
        starts.add(now);
        expect(request.headers['User-Agent'], contains('360Ghar'));
        return response([
          ...osm,
          {'lat': 'NaN', 'lon': '77', 'display_name': 'Invalid'},
        ]);
      }),
      apiKey: '',
      now: () => now,
      wait: (duration) async {
        now = now.add(duration);
      },
    );
    addTearDown(places.dispose);
    final results = await Future.wait([
      places.getPlaceSuggestions('one'),
      places.getPlaceSuggestions('two'),
      places.getPlaceSuggestions('three'),
    ]);
    expect(results.every((result) => result.length == 1), isTrue);
    expect(
      starts[1].difference(starts[0]),
      greaterThanOrEqualTo(const Duration(milliseconds: 1100)),
    );
    expect(
      starts[2].difference(starts[1]),
      greaterThanOrEqualTo(const Duration(milliseconds: 1100)),
    );
    await places.getPlaceSuggestions('ONE');
    expect(starts, hasLength(3));
  });
  test('superseded request does not start fallback or publish a result', () async {
    final gate = Completer<http.Response>();
    var current = true;
    var calls = 0;
    final places = service((_) {
      calls++;
      return gate.future;
    });
    final request = places.getPlaceSuggestions('Delhi', isCurrent: () => current);
    current = false;
    gate.complete(response({'status': 'ZERO_RESULTS'}));
    expect(await request, isEmpty);
    expect(calls, 1);
  });
  for (final status in [
    'ZERO_RESULTS',
    'NOT_FOUND',
    'OVER_QUERY_LIMIT',
    'REQUEST_DENIED',
    'INVALID_REQUEST',
    'UNKNOWN_ERROR',
  ]) {
    test('details $status returns a typed failure', () async {
      final places = service((_) async => response({'status': status}));
      await expectLater(places.getPlaceDetails('one'), throwsA(isA<LocationException>()));
    });
  }
  for (final components in <List<Map<String, Object>>>[
    [
      {
        'types': ['locality'],
        'long_name': 'Locality',
      },
      {
        'types': ['administrative_area_level_2'],
        'long_name': 'City',
      },
    ],
    [
      {
        'types': ['locality'],
        'long_name': 'Locality',
      },
    ],
    [
      {
        'types': ['administrative_area_level_2'],
        'long_name': 'City',
      },
    ],
    [],
  ]) {
    test('details preserve address-name fallback $components', () async {
      final places = service(
        (_) async => response({
          'status': 'OK',
          'result': {
            'name': 'Fallback',
            'geometry': {
              'location': {'lat': 28, 'lng': 77},
            },
            'address_components': components,
          },
        }),
      );
      final expected = components.isEmpty
          ? 'Fallback'
          : components.map((item) => item['long_name']).join(', ');
      final details = await places.getPlaceDetails('one');
      expect(details.name, expected);
      expect(details.latitude, 28);
      expect(details.longitude, 77);
      expect((await places.getPlaceDetails('one', preferredName: 'Chosen')).name, 'Chosen');
    });
  }
  test('malformed details never silently become coordinates 0,0', () async {
    for (final reply in [
      response({'status': 'OK', 'result': null}),
      response({
        'status': 'OK',
        'result': {'geometry': {}},
      }),
      http.Response('{bad', 200),
      http.Response('', 503),
    ]) {
      final places = service((_) async => reply);
      await expectLater(places.getPlaceDetails('one'), throwsA(isA<LocationException>()));
    }
  });
  test('popular/OSM details resolve offline and reject malformed coordinates', () async {
    final places = service((_) => throw StateError('No HTTP'), key: '');
    expect((await places.getPlaceDetails('popular:Delhi|28.6|77.2')).name, 'Delhi');
    expect(
      (await places.getPlaceDetails('osm:node1|28.6|77.2', preferredName: 'Local name')).name,
      'Local name',
    );
    for (final id in ['popular:bad', 'osm:x|99|77', 'osm:x|NaN|77']) {
      await expectLater(places.getPlaceDetails(id), throwsA(isA<LocationException>()));
    }
    await expectLater(places.getPlaceDetails('google-id'), throwsA(isA<LocationException>()));
  });
  test('timeout retry is bounded to two Google calls', () async {
    var calls = 0;
    final places = service((_) async {
      calls++;
      throw TimeoutException('test');
    });
    await expectLater(
      places.getPlaceSuggestions('Delhi', allowFallback: false),
      throwsA(isA<LocationException>().having((error) => error.code, 'code', 'PLACES_TIMEOUT')),
    );
    expect(calls, 2);
  });
}
