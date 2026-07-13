import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/data/models/api_response_models.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';

void main() {
  group('UnifiedFilterModel.toApiQueryParams', () {
    test('normalizes purpose/property_type and remaps date keys', () {
      final filters = UnifiedFilterModel(
        purpose: 'shortStay',
        propertyType: ['Apartment', 'builderFloor', 'Loft', 'flatmate', 'All'],
        checkInDate: DateTime(2026, 2, 1),
        checkOutDate: DateTime(2026, 2, 3),
        propertyIds: [7, 9],
        genderPreference: 'Female',
        sharingType: 'shared room',
      );

      final params = filters.toApiQueryParams();

      expect(params['purpose'], 'short_stay');
      expect(params['property_type'], ['apartment', 'builder_floor', 'loft', 'flatmate']);
      expect(params['check_in'], '2026-02-01');
      expect(params['check_out'], '2026-02-03');
      expect(params['ids'], [7, 9]);
      expect(params['gender_preference'], 'female');
      expect(params['sharing_type'], 'shared_room');
      expect(params.containsKey('check_in_date'), isFalse);
      expect(params.containsKey('check_out_date'), isFalse);
    });

    test('normalizes legacy property type aliases', () {
      final filters = const UnifiedFilterModel(
        purpose: 'pg',
        propertyType: ['flat', 'independent-house', 'plots', 'office-space', 'roommate'],
      );

      final params = filters.toApiQueryParams();

      expect(params['purpose'], 'rent');
      expect(params['property_type'], ['apartment', 'house', 'plot', 'office', 'flatmate']);
    });

    test('maps search_query to q', () {
      const filters = UnifiedFilterModel(searchQuery: 'luxury flat');
      final params = filters.toApiQueryParams();
      expect(params['q'], 'luxury flat');
      expect(params.containsKey('search_query'), isFalse);
    });

    test('omits empty property_ids', () {
      const filters = UnifiedFilterModel(propertyIds: []);
      final params = filters.toApiQueryParams();
      expect(params.containsKey('ids'), isFalse);
    });

    test('omits invalid gender and sharing type', () {
      const filters = UnifiedFilterModel(genderPreference: 'unknown', sharingType: 'invalid');
      final params = filters.toApiQueryParams();
      expect(params.containsKey('gender_preference'), isFalse);
      expect(params.containsKey('sharing_type'), isFalse);
    });
  });

  group('UnifiedFilterModel JSON serialization', () {
    test('toJson serializes all fields correctly', () {
      final filters = UnifiedFilterModel(
        radiusKm: 15.0,
        purpose: 'rent',
        propertyType: ['apartment', 'villa'],
        priceMin: 50000,
        priceMax: 100000,
        bedroomsMin: 2,
        bedroomsMax: 4,
        bathroomsMin: 1,
        bathroomsMax: 3,
        areaMin: 500,
        areaMax: 2000,
        parkingSpacesMin: 1,
        floorNumberMin: 1,
        floorNumberMax: 10,
        ageMax: 5,
        amenities: ['pool', 'gym'],
        features: ['balcony'],
        genderPreference: 'male',
        sharingType: 'private_room',
        availableFrom: DateTime(2026, 1, 1),
        checkInDate: DateTime(2026, 2, 1),
        checkOutDate: DateTime(2026, 2, 5),
        guests: 3,
        sortBy: SortBy.priceLow,
        searchQuery: 'test',
        includeUnavailable: true,
        propertyIds: [1, 2, 3],
      );

      final json = filters.toJson();

      expect(json['radius_km'], 15.0);
      expect(json['purpose'], 'rent');
      expect(json['property_type'], ['apartment', 'villa']);
      expect(json['price_min'], 50000);
      expect(json['price_max'], 100000);
      expect(json['bedrooms_min'], 2);
      expect(json['bedrooms_max'], 4);
      expect(json['bathrooms_min'], 1);
      expect(json['bathrooms_max'], 3);
      expect(json['area_min'], 500);
      expect(json['area_max'], 2000);
      expect(json['parking_spaces_min'], 1);
      expect(json['floor_number_min'], 1);
      expect(json['floor_number_max'], 10);
      expect(json['age_max'], 5);
      expect(json['amenities'], ['pool', 'gym']);
      expect(json['features'], ['balcony']);
      expect(json['gender_preference'], 'male');
      expect(json['sharing_type'], 'private_room');
      expect(json['available_from'], '2026-01-01');
      expect(json['check_in_date'], '2026-02-01');
      expect(json['check_out_date'], '2026-02-05');
      expect(json['guests'], 3);
      expect(json['sort_by'], 'price_low');
      expect(json['search_query'], 'test');
      expect(json['include_unavailable'], true);
      expect(json['property_ids'], [1, 2, 3]);
    });

    test('toJson removes null and empty values', () {
      const filters = UnifiedFilterModel(purpose: 'buy');
      final json = filters.toJson();

      expect(json['purpose'], 'buy');
      expect(json.containsKey('radius_km'), isFalse);
      expect(json.containsKey('property_type'), isFalse);
      expect(json.containsKey('amenities'), isFalse);
    });

    test('toJson removes invalid numeric values', () {
      const filters = UnifiedFilterModel(
        radiusKm: -5,
        priceMin: -100,
        bedroomsMin: -1,
        bathroomsMax: -2,
        areaMin: -50,
        guests: 0,
      );
      final json = filters.toJson();

      expect(json.containsKey('radius_km'), isFalse);
      expect(json.containsKey('price_min'), isFalse);
      expect(json.containsKey('bedrooms_min'), isFalse);
      expect(json.containsKey('bathrooms_max'), isFalse);
      expect(json.containsKey('area_min'), isFalse);
      expect(json.containsKey('guests'), isFalse);
    });

    test('toJson removes radius over 1000', () {
      const filters = UnifiedFilterModel(radiusKm: 2000);
      final json = filters.toJson();
      expect(json.containsKey('radius_km'), isFalse);
    });

    test('fromJson parses all fields correctly', () {
      final json = {
        'radius_km': 20.0,
        'purpose': 'buy',
        'property_type': ['house'],
        'price_min': 1000000,
        'price_max': 5000000,
        'bedrooms_min': 3,
        'bedrooms_max': 5,
        'bathrooms_min': 2,
        'bathrooms_max': 4,
        'area_min': 1000,
        'area_max': 3000,
        'parking_spaces_min': 2,
        'floor_number_min': 0,
        'floor_number_max': 20,
        'age_max': 10,
        'amenities': ['gym'],
        'features': ['garden'],
        'gender_preference': 'female',
        'sharing_type': 'shared_room',
        'available_from': '2026-01-01T00:00:00.000',
        'check_in_date': '2026-02-01T00:00:00.000',
        'check_out_date': '2026-02-10T00:00:00.000',
        'guests': 4,
        'sort_by': 'newest',
        'search_query': 'villa',
        'include_unavailable': false,
        'property_ids': [10, 20],
      };

      final model = UnifiedFilterModel.fromJson(json);

      expect(model.radiusKm, 20.0);
      expect(model.purpose, 'buy');
      expect(model.propertyType, ['house']);
      expect(model.priceMin, 1000000);
      expect(model.priceMax, 5000000);
      expect(model.bedroomsMin, 3);
      expect(model.bedroomsMax, 5);
      expect(model.bathroomsMin, 2);
      expect(model.bathroomsMax, 4);
      expect(model.areaMin, 1000);
      expect(model.areaMax, 3000);
      expect(model.parkingSpacesMin, 2);
      expect(model.floorNumberMin, 0);
      expect(model.floorNumberMax, 20);
      expect(model.ageMax, 10);
      expect(model.amenities, ['gym']);
      expect(model.features, ['garden']);
      expect(model.genderPreference, 'female');
      expect(model.sharingType, 'shared_room');
      expect(model.availableFrom, DateTime(2026, 1, 1));
      expect(model.checkInDate, DateTime(2026, 2, 1));
      expect(model.checkOutDate, DateTime(2026, 2, 10));
      expect(model.guests, 4);
      expect(model.sortBy, SortBy.newest);
      expect(model.searchQuery, 'villa');
      expect(model.includeUnavailable, false);
      expect(model.propertyIds, [10, 20]);
    });

    test('fromJson handles null fields', () {
      final json = <String, dynamic>{};
      final model = UnifiedFilterModel.fromJson(json);

      expect(model.radiusKm, isNull);
      expect(model.purpose, isNull);
      expect(model.sortBy, isNull);
      expect(model.propertyIds, isNull);
    });

    test('fromJson decodes all SortBy enum values', () {
      const wireToEnum = {
        'distance': SortBy.distance,
        'price_low': SortBy.priceLow,
        'price_high': SortBy.priceHigh,
        'newest': SortBy.newest,
        'popular': SortBy.popular,
        'relevance': SortBy.relevance,
      };

      wireToEnum.forEach((wire, expected) {
        final model = UnifiedFilterModel.fromJson({'sort_by': wire});
        expect(model.sortBy, expected, reason: 'wire: $wire');
      });
    });
  });

  group('UnifiedFilterModel.initial', () {
    test('creates default filter values', () {
      final model = UnifiedFilterModel.initial();

      expect(model.radiusKm, 10.0);
      expect(model.purpose, 'buy');
      expect(model.sortBy, isNull);
      expect(model.includeUnavailable, false);
      expect(model.propertyType, isEmpty);
      expect(model.amenities, isEmpty);
      expect(model.features, isEmpty);
    });
  });

  group('UnifiedFilterModel.copyWith', () {
    test('overrides specified fields', () {
      const original = UnifiedFilterModel(purpose: 'buy', priceMin: 1000);
      final updated = original.copyWith(purpose: 'rent', priceMax: 5000);

      expect(updated.purpose, 'rent');
      expect(updated.priceMax, 5000);
      expect(updated.priceMin, 1000);
    });

    test('preserves fields when no overrides', () {
      const original = UnifiedFilterModel(purpose: 'buy', priceMin: 1000);
      final copy = original.copyWith();

      expect(copy.purpose, 'buy');
      expect(copy.priceMin, 1000);
    });
  });

  group('UnifiedFilterModel.activeFilterCount', () {
    test('returns 0 for initial model', () {
      expect(UnifiedFilterModel.initial().activeFilterCount, 0);
    });

    test('counts price filter as 1', () {
      const model = UnifiedFilterModel(priceMin: 1000);
      expect(model.activeFilterCount, 1);
    });

    test('counts multiple filter categories', () {
      const model = UnifiedFilterModel(
        priceMin: 1000,
        bedroomsMin: 2,
        bathroomsMin: 1,
        areaMin: 500,
        propertyType: ['apartment'],
        genderPreference: 'male',
        sharingType: 'private_room',
        amenities: ['gym'],
        features: ['balcony'],
        parkingSpacesMin: 1,
        floorNumberMin: 1,
        ageMax: 5,
      );
      expect(model.activeFilterCount, 12);
    });
  });

  group('UnifiedFilterModel normalization helpers', () {
    test('normalizePropertyTypeTokens handles null and empty', () {
      expect(UnifiedFilterModel.normalizePropertyTypeTokens(null), isEmpty);
      expect(UnifiedFilterModel.normalizePropertyTypeTokens(''), isEmpty);
      expect(UnifiedFilterModel.normalizePropertyTypeTokens('all'), isEmpty);
    });

    test('normalizePropertyTypeTokens maps aliases', () {
      expect(UnifiedFilterModel.normalizePropertyTypeTokens('flat'), ['apartment']);
      expect(UnifiedFilterModel.normalizePropertyTypeTokens('plots'), ['plot']);
      expect(UnifiedFilterModel.normalizePropertyTypeTokens('roommate'), ['flatmate']);
    });

    test('normalizePropertyTypeTokens filters non-canonical types', () {
      expect(UnifiedFilterModel.normalizePropertyTypeTokens('mansion'), isEmpty);
    });

    test('normalizePropertyTypeToken returns first or null', () {
      expect(UnifiedFilterModel.normalizePropertyTypeToken('flat'), 'apartment');
      expect(UnifiedFilterModel.normalizePropertyTypeToken(null), isNull);
      expect(UnifiedFilterModel.normalizePropertyTypeToken('all'), isNull);
    });

    test('normalizePropertyTypes deduplicates', () {
      final result = UnifiedFilterModel.normalizePropertyTypes(['flat', 'apartment', 'flats']);
      expect(result, ['apartment']);
    });

    test('normalizePurposeToken handles various inputs', () {
      expect(UnifiedFilterModel.normalizePurposeToken('buy'), 'buy');
      expect(UnifiedFilterModel.normalizePurposeToken('rent'), 'rent');
      expect(UnifiedFilterModel.normalizePurposeToken('short_stay'), 'short_stay');
      expect(UnifiedFilterModel.normalizePurposeToken('shortstay'), 'short_stay');
      expect(UnifiedFilterModel.normalizePurposeToken('pg'), 'rent');
      expect(UnifiedFilterModel.normalizePurposeToken('investment'), 'buy');
      expect(UnifiedFilterModel.normalizePurposeToken(null), isNull);
      expect(UnifiedFilterModel.normalizePurposeToken(''), isNull);
      expect(UnifiedFilterModel.normalizePurposeToken('invalid'), isNull);
    });

    test('normalizeGenderPreferenceToken handles valid values', () {
      expect(UnifiedFilterModel.normalizeGenderPreferenceToken('male'), 'male');
      expect(UnifiedFilterModel.normalizeGenderPreferenceToken('Female'), 'female');
      expect(UnifiedFilterModel.normalizeGenderPreferenceToken('any'), 'any');
      expect(UnifiedFilterModel.normalizeGenderPreferenceToken(null), isNull);
      expect(UnifiedFilterModel.normalizeGenderPreferenceToken(''), isNull);
      expect(UnifiedFilterModel.normalizeGenderPreferenceToken('other'), isNull);
    });

    test('normalizeSharingTypeToken handles valid values', () {
      expect(UnifiedFilterModel.normalizeSharingTypeToken('private_room'), 'private_room');
      expect(UnifiedFilterModel.normalizeSharingTypeToken('shared_room'), 'shared_room');
      expect(UnifiedFilterModel.normalizeSharingTypeToken('private-room'), 'private_room');
      expect(UnifiedFilterModel.normalizeSharingTypeToken('shared room'), 'shared_room');
      expect(UnifiedFilterModel.normalizeSharingTypeToken(null), isNull);
      expect(UnifiedFilterModel.normalizeSharingTypeToken(''), isNull);
      expect(UnifiedFilterModel.normalizeSharingTypeToken('invalid'), isNull);
    });
  });

  group('LocationData', () {
    test('fromJson throws on missing coordinates instead of defaulting to 0,0', () {
      expect(
        () => LocationData.fromJson({'name': 'Delhi', 'latitude': null, 'longitude': null}),
        throwsFormatException,
      );
    });

    test('tryFromJson returns null on missing coordinates and parses valid input', () {
      expect(LocationData.tryFromJson({'name': 'Delhi'}), isNull);
      expect(LocationData.tryFromJson(null), isNull);

      final location = LocationData.tryFromJson({
        'name': 'Delhi',
        'latitude': 28.6139,
        'longitude': 77.2090,
      });
      expect(location?.latitude, 28.6139);
      expect(location?.longitude, 77.2090);
    });

    test('fromJson parses valid data with name defaulting to empty', () {
      final location = LocationData.fromJson({'latitude': 10.0, 'longitude': 20.0});
      expect(location.name, '');
      expect(location.latitude, 10.0);
      expect(location.longitude, 20.0);
    });

    test('toJson serializes correctly', () {
      const location = LocationData(name: 'Mumbai', latitude: 19.076, longitude: 72.8777);
      final json = location.toJson();

      expect(json, {'name': 'Mumbai', 'latitude': 19.076, 'longitude': 72.8777});
    });

    test('round-trip fromJson then toJson preserves data', () {
      final json = {'name': 'Pune', 'latitude': 18.52, 'longitude': 73.85};
      final location = LocationData.fromJson(json);
      expect(location.toJson(), json);
    });
  });
}
