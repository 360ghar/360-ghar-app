import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/data/models/unified_property_response.dart';

void main() {
  group('UnifiedPropertyResponse.fromJson', () {
    test('parses full JSON correctly', () {
      final json = <String, dynamic>{
        'items': [
          {'id': 1, 'title': 'Cozy Apartment'},
          {'id': 2, 'title': 'Spacious Villa'},
        ],
        'limit': 10,
        'next_cursor': 'eyJwYWdlIjoyfQ==',
        'has_more': true,
        'filters_applied': {'city': 'Mumbai', 'purpose': 'rent'},
        'search_center': {'latitude': 19.0760, 'longitude': 72.8777},
        'total': 42,
      };

      final response = UnifiedPropertyResponse.fromJson(json);

      expect(response.items.length, 2);
      expect(response.items[0].id, 1);
      expect(response.items[0].title, 'Cozy Apartment');
      expect(response.items[1].id, 2);
      expect(response.limit, 10);
      expect(response.nextCursor, 'eyJwYWdlIjoyfQ==');
      expect(response.hasMore, true);
      expect(response.filtersApplied, {'city': 'Mumbai', 'purpose': 'rent'});
      expect(response.searchCenter, isNotNull);
      expect(response.searchCenter!.latitude, 19.0760);
      expect(response.searchCenter!.longitude, 72.8777);
      expect(response.total, 42);
    });

    test('applies defaults for missing fields', () {
      final response = UnifiedPropertyResponse.fromJson({});

      expect(response.items, [], reason: 'items defaults to empty list');
      expect(response.limit, 20, reason: 'limit defaults to 20');
      expect(response.nextCursor, isNull);
      expect(response.hasMore, false, reason: 'has_more defaults to false');
      expect(
        response.filtersApplied,
        <String, dynamic>{},
        reason: 'filters_applied defaults to empty map',
      );
      expect(response.searchCenter, isNull);
      expect(response.total, isNull);
    });

    test('parses empty items list explicitly', () {
      final response = UnifiedPropertyResponse.fromJson({'items': [], 'has_more': false});

      expect(response.items, []);
      expect(response.isEmpty, true);
      expect(response.currentItemCount, 0);
    });
  });

  group('UnifiedPropertyResponse convenience getters', () {
    test('hasMorePages is true when hasMore and nextCursor non-empty', () {
      final response = const UnifiedPropertyResponse(
        items: [],
        hasMore: true,
        nextCursor: 'abc123',
      );

      expect(response.hasMorePages, true);
    });

    test('hasMorePages is false when hasMore is false', () {
      const response = UnifiedPropertyResponse(hasMore: false, nextCursor: 'abc123');

      expect(response.hasMorePages, false);
    });

    test('hasMorePages is false when nextCursor is null', () {
      const response = UnifiedPropertyResponse(hasMore: true);

      expect(response.hasMorePages, false);
    });

    test('hasMorePages is false when nextCursor is empty', () {
      const response = UnifiedPropertyResponse(hasMore: true, nextCursor: '');

      expect(response.hasMorePages, false);
    });

    test('isEmpty reflects items list', () {
      expect(const UnifiedPropertyResponse().isEmpty, true);
      expect(const UnifiedPropertyResponse(items: []).isEmpty, true);
    });

    test('currentItemCount returns items length', () {
      final response = UnifiedPropertyResponse.fromJson({
        'items': [
          {'id': 1},
          {'id': 2},
          {'id': 3},
        ],
      });

      expect(response.currentItemCount, 3);
      expect(response.isEmpty, false);
    });
  });

  group('SearchCenter', () {
    test('fromJson parses latitude and longitude', () {
      final json = <String, dynamic>{'latitude': 28.6139, 'longitude': 77.2090};

      final center = SearchCenter.fromJson(json);

      expect(center.latitude, 28.6139);
      expect(center.longitude, 77.2090);
    });

    test('toJson roundtrip preserves fields', () {
      const original = SearchCenter(latitude: 19.0760, longitude: 72.8777);

      final json = original.toJson();
      final restored = SearchCenter.fromJson(json);

      expect(restored.latitude, original.latitude);
      expect(restored.longitude, original.longitude);
    });
  });

  group('UnifiedPropertyResponse.toJson roundtrip', () {
    test('roundtrip preserves all fields with explicitToJson', () {
      final original = const UnifiedPropertyResponse(
        items: [],
        limit: 15,
        nextCursor: 'cursor123',
        hasMore: true,
        filtersApplied: {'city': 'Delhi'},
        searchCenter: SearchCenter(latitude: 28.6, longitude: 77.2),
        total: 100,
      );

      final json = original.toJson();
      final restored = UnifiedPropertyResponse.fromJson(json);

      expect(restored.limit, original.limit);
      expect(restored.nextCursor, original.nextCursor);
      expect(restored.hasMore, original.hasMore);
      expect(restored.filtersApplied, original.filtersApplied);
      expect(restored.searchCenter?.latitude, original.searchCenter!.latitude);
      expect(restored.searchCenter?.longitude, original.searchCenter!.longitude);
      expect(restored.total, original.total);
    });

    test('toJson serializes search_center as nested map via explicitToJson', () {
      const response = UnifiedPropertyResponse(
        searchCenter: SearchCenter(latitude: 12.0, longitude: 34.0),
      );

      final json = response.toJson();

      expect(json['search_center'], isA<Map<String, dynamic>>());
      expect((json['search_center'] as Map<String, dynamic>)['latitude'], 12.0);
      expect((json['search_center'] as Map<String, dynamic>)['longitude'], 34.0);
    });
  });
}
