import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/data/models/api_response_models.dart';

void main() {
  group('SortBy enum', () {
    test('has every wire value', () {
      expect(SortBy.values.length, 6);
      expect(SortBy.values, contains(SortBy.distance));
      expect(SortBy.values, contains(SortBy.priceLow));
      expect(SortBy.values, contains(SortBy.priceHigh));
      expect(SortBy.values, contains(SortBy.newest));
      expect(SortBy.values, contains(SortBy.popular));
      expect(SortBy.values, contains(SortBy.relevance));
    });

    test('wire values are the backend values', () {
      expect(SortBy.priceLow.wire, 'price_low');
      expect(SortBy.priceHigh.wire, 'price_high');
      expect(SortBy.fromJson('newest'), SortBy.newest);
    });

    test('an unknown sort reads as null, not as distance', () {
      expect(SortBy.fromJson('cheapest'), isNull);
      expect(SortBy.fromJson(null), isNull);
    });
  });
}
