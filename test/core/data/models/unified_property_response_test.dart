import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/data/models/unified_property_response.dart';

Map<String, dynamic> _item(int id, String title) => {
  'id': id,
  'owner_id': 7,
  'title': title,
  'property_type': 'apartment',
  'purpose': 'buy',
  'status': 'available',
  'base_price': 8500000,
  'country': 'India',
  'is_available': true,
  'view_count': 0,
  'like_count': 0,
  'interest_count': 0,
  'created_at': '2026-09-30T10:15:02Z',
  'updated_at': '2026-09-30T10:15:02Z',
};

void main() {
  group('UnifiedPropertyResponse.fromJson', () {
    test('parses a CursorPage of properties', () {
      final json = <String, dynamic>{
        'items': [_item(1, 'Cozy Apartment'), _item(2, 'Spacious Villa')],
        'limit': 10,
        'next_cursor': 'eyJwYWdlIjoyfQ==',
        'has_more': true,
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
      expect(response.total, 42);
    });

    test('total is null unless the request set include_total', () {
      final response = UnifiedPropertyResponse.fromJson({
        'items': <Object?>[],
        'limit': 20,
        'next_cursor': null,
        'has_more': false,
        'total': null,
      });

      expect(response.total, isNull);
      expect(response.nextCursor, isNull);
    });

    test('a page without one of its five keys is a contract break', () {
      final full = <String, dynamic>{
        'items': <Object?>[],
        'limit': 20,
        'next_cursor': null,
        'has_more': false,
        'total': null,
      };
      for (final key in full.keys) {
        final body = {...full}..remove(key);
        expect(
          () => UnifiedPropertyResponse.fromJson(body),
          throwsA(anything),
          reason: 'missing $key',
        );
      }
    });

    test('parses an empty items list', () {
      final response = UnifiedPropertyResponse.fromJson({
        'items': <Object?>[],
        'limit': 20,
        'next_cursor': null,
        'has_more': false,
        'total': null,
      });

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
        'items': [_item(1, 'A'), _item(2, 'B'), _item(3, 'C')],
        'limit': 20,
        'next_cursor': null,
        'has_more': false,
        'total': null,
      });

      expect(response.currentItemCount, 3);
      expect(response.isEmpty, false);
    });
  });

  group('UnifiedPropertyResponse.toJson roundtrip', () {
    test('roundtrip preserves all fields', () {
      final original = const UnifiedPropertyResponse(
        items: [],
        limit: 15,
        nextCursor: 'cursor123',
        hasMore: true,
        total: 100,
      );

      final json = original.toJson();
      final restored = UnifiedPropertyResponse.fromJson(json);

      expect(restored.limit, original.limit);
      expect(restored.nextCursor, original.nextCursor);
      expect(restored.hasMore, original.hasMore);
      expect(restored.total, original.total);
    });
  });
}
