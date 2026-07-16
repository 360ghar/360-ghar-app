import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/data/models/popular_city.dart';
import 'package:ghar360/core/services/google_places_service.dart';

void main() {
  group('PopularCity', () {
    test('defaults include Gurgaon, Noida, and Delhi', () {
      final names = PopularCity.defaults.map((c) => c.name).toSet();
      expect(names, containsAll(['Gurgaon', 'Noida', 'Delhi']));
    });

    test('matchesQuery finds Gurgaon via Gurugram alias', () {
      final city = PopularCity.defaults.firstWhere((c) => c.name == 'Gurgaon');
      expect(city.matchesQuery('gurgaon'), isTrue);
      expect(city.matchesQuery('Gurugram'), isTrue);
      expect(city.matchesQuery('xyz'), isFalse);
    });

    test('suggestionsForQuery returns all when query empty', () {
      expect(PopularCity.suggestionsForQuery(''), hasLength(PopularCity.defaults.length));
    });

    test('suggestionsForQuery filters by name', () {
      final results = PopularCity.suggestionsForQuery('noi');
      expect(results, hasLength(1));
      expect(results.first.mainText, 'Noida');
      expect(PopularCity.isPopularPlaceId(results.first.placeId), isTrue);
    });

    test('mergeWithRemote puts popular cities first and de-dupes', () {
      final remote = [
        PlaceSuggestion(
          placeId: 'google-1',
          description: 'Noida, Uttar Pradesh, India',
          mainText: 'Noida',
          secondaryText: 'Uttar Pradesh, India',
        ),
        PlaceSuggestion(
          placeId: 'google-2',
          description: 'Sector 18, Noida',
          mainText: 'Sector 18',
          secondaryText: 'Noida, Uttar Pradesh',
        ),
        PlaceSuggestion(
          placeId: 'google-3',
          description: 'Greater Noida, Uttar Pradesh, India',
          mainText: 'Greater Noida',
          secondaryText: 'Uttar Pradesh, India',
        ),
      ];

      final merged = PopularCity.mergeWithRemote('noi', remote);
      expect(merged.first.mainText, 'Noida');
      expect(PopularCity.isPopularPlaceId(merged.first.placeId), isTrue);
      // Exact mainText de-dupe only — not substring matches.
      expect(merged.where((s) => s.mainText == 'Noida'), hasLength(1));
      expect(merged.any((s) => s.mainText == 'Sector 18'), isTrue);
      expect(merged.any((s) => s.mainText == 'Greater Noida'), isTrue);
    });

    test('toLocationData exposes coordinates', () {
      final city = PopularCity.defaults.first;
      final loc = city.toLocationData();
      expect(loc.name, city.name);
      expect(loc.latitude, city.latitude);
      expect(loc.longitude, city.longitude);
    });

    test('buildSuggestionsList exposes header when remote empty', () {
      final list = PopularCity.buildSuggestionsList('', const []);
      expect(list.showPopularHeader, isTrue);
      expect(list.suggestionAt(0), isNull);
      expect(list.suggestionAt(1)?.mainText, isNotEmpty);
      expect(list.listItemCount, PopularCity.defaults.length + 1);
    });
  });
}
