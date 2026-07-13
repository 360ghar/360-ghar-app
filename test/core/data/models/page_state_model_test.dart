import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';

void main() {
  group('PageStateModel.copyWith', () {
    test('clears nullable fields when null is explicitly passed', () {
      final original = PageStateModel(
        pageType: PageType.explore,
        selectedLocation: const LocationData(name: 'Delhi', latitude: 28.6139, longitude: 77.2090),
        locationSource: 'gps',
        filters: UnifiedFilterModel.initial(),
        searchQuery: 'rent',
        properties: const [],
        error: NetworkException('boom'),
        lastFetched: DateTime(2026, 1, 1),
        additionalData: const {'segment': 'liked'},
      );

      final updated = original.copyWith(
        selectedLocation: null,
        locationSource: null,
        searchQuery: null,
        error: null,
        lastFetched: null,
        additionalData: null,
      );

      expect(updated.selectedLocation, isNull);
      expect(updated.locationSource, isNull);
      expect(updated.searchQuery, isNull);
      expect(updated.error, isNull);
      expect(updated.lastFetched, isNull);
      expect(updated.additionalData, isNull);
    });

    test('retains existing nullable fields when omitted', () {
      final original = PageStateModel(
        pageType: PageType.explore,
        selectedLocation: const LocationData(name: 'Delhi', latitude: 28.6139, longitude: 77.2090),
        locationSource: 'gps',
        filters: UnifiedFilterModel.initial(),
        searchQuery: 'rent',
        properties: const [],
        error: NetworkException('boom'),
        lastFetched: DateTime(2026, 1, 1),
        additionalData: const {'segment': 'liked'},
      );

      final updated = original.copyWith(isLoading: true);

      expect(updated.selectedLocation, original.selectedLocation);
      expect(updated.locationSource, original.locationSource);
      expect(updated.searchQuery, original.searchQuery);
      expect(updated.error, original.error);
      expect(updated.lastFetched, original.lastFetched);
      expect(updated.additionalData, original.additionalData);
      expect(updated.isLoading, isTrue);
    });
  });

  group('PageStateModel.initial', () {
    test('creates initial state for explore page', () {
      final model = PageStateModel.initial(PageType.explore);

      expect(model.pageType, PageType.explore);
      expect(model.properties, isEmpty);
      expect(model.isLoading, isFalse);
      expect(model.hasMore, isTrue);
      expect(model.additionalData, isNull);
    });

    test('creates initial state for likes page with currentSegment', () {
      final model = PageStateModel.initial(PageType.likes);

      expect(model.pageType, PageType.likes);
      expect(model.additionalData, {'currentSegment': 'liked'});
    });

    test('creates initial state for discover page without additionalData', () {
      final model = PageStateModel.initial(PageType.discover);

      expect(model.pageType, PageType.discover);
      expect(model.additionalData, isNull);
    });
  });

  group('PageStateModel JSON serialization', () {
    test('toJson and fromJson round-trip correctly', () {
      final model = PageStateModel(
        pageType: PageType.discover,
        selectedLocation: const LocationData(name: 'Mumbai', latitude: 19.076, longitude: 72.8777),
        locationSource: 'manual',
        filters: UnifiedFilterModel.initial(),
        searchQuery: 'flat',
        properties: const [],
        nextCursor: 'cursor123',
        hasMore: false,
        isLoading: true,
        isLoadingMore: false,
        isRefreshing: true,
        lastFetched: DateTime(2026, 1, 15, 10, 30),
        additionalData: const {'key': 'value'},
      );

      final json = model.toJson();

      expect(json['pageType'], 'discover');
      expect(json['locationSource'], 'manual');
      expect(json['searchQuery'], 'flat');
      expect(json['nextCursor'], 'cursor123');
      expect(json['hasMore'], false);
      expect(json['isLoading'], true);
      expect(json['isRefreshing'], true);
      expect(json['lastFetched'], '2026-01-15T10:30:00.000');
      expect(json['additionalData'], {'key': 'value'});
      expect(json['selectedLocation'], {
        'name': 'Mumbai',
        'latitude': 19.076,
        'longitude': 72.8777,
      });

      final restored = PageStateModel.fromJson(json);
      expect(restored.pageType, PageType.discover);
      expect(restored.locationSource, 'manual');
      expect(restored.searchQuery, 'flat');
      expect(restored.nextCursor, 'cursor123');
      expect(restored.hasMore, false);
      expect(restored.isLoading, true);
      expect(restored.isRefreshing, true);
      expect(restored.lastFetched, DateTime(2026, 1, 15, 10, 30));
      expect(restored.additionalData, {'key': 'value'});
      expect(restored.selectedLocation?.name, 'Mumbai');
    });

    test('toJson handles null fields', () {
      final model = PageStateModel(
        pageType: PageType.explore,
        filters: UnifiedFilterModel.initial(),
        properties: const [],
      );

      final json = model.toJson();

      expect(json['selectedLocation'], isNull);
      expect(json['locationSource'], isNull);
      expect(json['searchQuery'], isNull);
      expect(json['nextCursor'], isNull);
      expect(json['lastFetched'], isNull);
      expect(json['additionalData'], isNull);
    });

    test('fromJson applies defaults for optional bool fields', () {
      final json = {
        'pageType': 'explore',
        'filters': UnifiedFilterModel.initial().toJson(),
        'properties': <Map<String, dynamic>>[],
      };

      final model = PageStateModel.fromJson(json);

      expect(model.hasMore, isTrue);
      expect(model.isLoading, isFalse);
      expect(model.isLoadingMore, isFalse);
      expect(model.isRefreshing, isFalse);
    });

    test('fromJson handles null lastFetched', () {
      final json = {
        'pageType': 'discover',
        'filters': UnifiedFilterModel.initial().toJson(),
        'properties': <Map<String, dynamic>>[],
        'lastFetched': null,
      };

      final model = PageStateModel.fromJson(json);

      expect(model.lastFetched, isNull);
    });

    test('fromJson decodes all enum values', () {
      for (final pageType in PageType.values) {
        final json = {
          'pageType': pageType.name,
          'filters': UnifiedFilterModel.initial().toJson(),
          'properties': <Map<String, dynamic>>[],
        };

        final model = PageStateModel.fromJson(json);
        expect(model.pageType, pageType);
      }
    });
  });

  group('PageStateSnapshot JSON serialization', () {
    test('toJson and fromJson round-trip correctly', () {
      final snapshot = PageStateSnapshot(
        pageType: 'explore',
        selectedLocation: const LocationData(name: 'Pune', latitude: 18.52, longitude: 73.85),
        locationSource: 'gps',
        filters: UnifiedFilterModel.initial(),
        searchQuery: 'villa',
        additionalData: const {'seg': 'passed'},
        lastFetched: DateTime(2026, 3, 1),
      );

      final json = snapshot.toJson();

      expect(json['pageType'], 'explore');
      expect(json['locationSource'], 'gps');
      expect(json['searchQuery'], 'villa');
      expect(json['additionalData'], {'seg': 'passed'});
      expect(json['lastFetched'], '2026-03-01T00:00:00.000');

      final restored = PageStateSnapshot.fromJson(json);
      expect(restored.pageType, 'explore');
      expect(restored.locationSource, 'gps');
      expect(restored.searchQuery, 'villa');
      expect(restored.additionalData, {'seg': 'passed'});
      expect(restored.selectedLocation?.name, 'Pune');
    });

    test('toJson handles null fields', () {
      final snapshot = PageStateSnapshot(
        pageType: 'discover',
        filters: UnifiedFilterModel.initial(),
      );

      final json = snapshot.toJson();

      expect(json['selectedLocation'], isNull);
      expect(json['locationSource'], isNull);
      expect(json['searchQuery'], isNull);
      expect(json['additionalData'], isNull);
      expect(json['lastFetched'], isNull);
    });

    test('fromJson handles null lastFetched', () {
      final json = {'pageType': 'likes', 'filters': UnifiedFilterModel.initial().toJson()};

      final snapshot = PageStateSnapshot.fromJson(json);

      expect(snapshot.lastFetched, isNull);
      expect(snapshot.selectedLocation, isNull);
    });
  });

  group('PageStateModel snapshot conversion', () {
    test('toSnapshot and fromSnapshot round-trip correctly', () {
      final model = PageStateModel(
        pageType: PageType.likes,
        selectedLocation: const LocationData(name: 'Goa', latitude: 15.29, longitude: 74.12),
        locationSource: 'ip',
        filters: UnifiedFilterModel.initial(),
        searchQuery: 'beach',
        properties: const [],
        additionalData: const {'currentSegment': 'liked'},
        lastFetched: DateTime(2026, 6, 15),
      );

      final snapshot = model.toSnapshot();

      expect(snapshot.pageType, 'likes');
      expect(snapshot.locationSource, 'ip');
      expect(snapshot.searchQuery, 'beach');
      expect(snapshot.selectedLocation?.name, 'Goa');
      expect(snapshot.additionalData, {'currentSegment': 'liked'});

      final restored = PageStateModel.fromSnapshot(snapshot);
      expect(restored.pageType, PageType.likes);
      expect(restored.locationSource, 'ip');
      expect(restored.searchQuery, 'beach');
      expect(restored.selectedLocation?.name, 'Goa');
      expect(restored.properties, isEmpty);
      expect(restored.additionalData, {'currentSegment': 'liked'});
    });

    test('fromSnapshot defaults to discover for unknown pageType', () {
      final snapshot = PageStateSnapshot(
        pageType: 'unknown',
        filters: UnifiedFilterModel.initial(),
      );

      final restored = PageStateModel.fromSnapshot(snapshot);
      expect(restored.pageType, PageType.discover);
    });
  });

  group('PageStateModel getters', () {
    test('hasLocation returns true when location is set', () {
      final model = PageStateModel(
        pageType: PageType.explore,
        selectedLocation: const LocationData(name: 'Delhi', latitude: 1, longitude: 2),
        filters: UnifiedFilterModel.initial(),
        properties: const [],
      );
      expect(model.hasLocation, isTrue);
    });

    test('hasLocation returns false when location is null', () {
      final model = PageStateModel(
        pageType: PageType.explore,
        filters: UnifiedFilterModel.initial(),
        properties: const [],
      );
      expect(model.hasLocation, isFalse);
    });

    test('locationDisplayText returns location name when set', () {
      final model = PageStateModel(
        pageType: PageType.explore,
        selectedLocation: const LocationData(name: 'Bangalore', latitude: 1, longitude: 2),
        filters: UnifiedFilterModel.initial(),
        properties: const [],
      );
      expect(model.locationDisplayText, 'Bangalore');
    });

    test('locationDisplayText returns Current Location for empty name', () {
      final model = PageStateModel(
        pageType: PageType.explore,
        selectedLocation: const LocationData(name: '', latitude: 1, longitude: 2),
        filters: UnifiedFilterModel.initial(),
        properties: const [],
      );
      expect(model.locationDisplayText, 'Current Location');
    });

    test('locationDisplayText returns Select Location when no location', () {
      final model = PageStateModel(
        pageType: PageType.explore,
        filters: UnifiedFilterModel.initial(),
        properties: const [],
      );
      expect(model.locationDisplayText, 'Select Location');
    });

    test('hasActiveFilters is true when searchQuery is non-empty', () {
      final model = PageStateModel(
        pageType: PageType.explore,
        filters: UnifiedFilterModel.initial(),
        searchQuery: 'test',
        properties: const [],
      );
      expect(model.hasActiveFilters, isTrue);
    });

    test('hasActiveFilters is false when no filters and empty search', () {
      final model = PageStateModel(
        pageType: PageType.explore,
        filters: UnifiedFilterModel.initial(),
        searchQuery: '',
        properties: const [],
      );
      expect(model.hasActiveFilters, isFalse);
    });

    test('isDataStale is true when lastFetched is null', () {
      final model = PageStateModel(
        pageType: PageType.explore,
        filters: UnifiedFilterModel.initial(),
        properties: const [],
      );
      expect(model.isDataStale, isTrue);
    });

    test('isDataStale is true when lastFetched is older than 5 minutes', () {
      final model = PageStateModel(
        pageType: PageType.explore,
        filters: UnifiedFilterModel.initial(),
        properties: const [],
        lastFetched: DateTime.now().subtract(const Duration(minutes: 10)),
      );
      expect(model.isDataStale, isTrue);
    });

    test('isDataStale is false when lastFetched is recent', () {
      final model = PageStateModel(
        pageType: PageType.explore,
        filters: UnifiedFilterModel.initial(),
        properties: const [],
        lastFetched: DateTime.now(),
      );
      expect(model.isDataStale, isFalse);
    });
  });

  group('PageStateModel helper methods', () {
    test('getAdditionalData returns value for existing key', () {
      final model = PageStateModel(
        pageType: PageType.likes,
        filters: UnifiedFilterModel.initial(),
        properties: const [],
        additionalData: const {'count': 42},
      );
      expect(model.getAdditionalData<int>('count'), 42);
    });

    test('getAdditionalData returns null for missing key', () {
      final model = PageStateModel(
        pageType: PageType.likes,
        filters: UnifiedFilterModel.initial(),
        properties: const [],
      );
      expect(model.getAdditionalData<String>('missing'), isNull);
    });

    test('updateAdditionalData adds new key', () {
      final model = PageStateModel(
        pageType: PageType.likes,
        filters: UnifiedFilterModel.initial(),
        properties: const [],
      );
      final updated = model.updateAdditionalData('newKey', 'newValue');
      expect(updated.additionalData, {'newKey': 'newValue'});
    });

    test('updateAdditionalData preserves existing keys', () {
      final model = PageStateModel(
        pageType: PageType.likes,
        filters: UnifiedFilterModel.initial(),
        properties: const [],
        additionalData: const {'a': 1},
      );
      final updated = model.updateAdditionalData('b', 2);
      expect(updated.additionalData, {'a': 1, 'b': 2});
    });

    test('resetData clears data-related fields', () {
      final model = PageStateModel(
        pageType: PageType.explore,
        filters: UnifiedFilterModel.initial(),
        properties: const [],
        nextCursor: 'abc',
        hasMore: false,
        isLoading: true,
        isRefreshing: true,
        lastFetched: DateTime(2026, 1, 1),
      );
      final reset = model.resetData();

      expect(reset.properties, isEmpty);
      expect(reset.nextCursor, isNull);
      expect(reset.hasMore, isTrue);
      expect(reset.isLoading, isFalse);
      expect(reset.isLoadingMore, isFalse);
      expect(reset.isRefreshing, isFalse);
      expect(reset.lastFetched, isNull);
    });

    test('resetFilters resets filters and searchQuery', () {
      final model = PageStateModel(
        pageType: PageType.explore,
        filters: UnifiedFilterModel.initial().copyWith(searchQuery: 'test'),
        searchQuery: 'old query',
        properties: const [],
        nextCursor: 'abc',
      );
      final reset = model.resetFilters();

      expect(reset.filters, UnifiedFilterModel.initial());
      expect(reset.searchQuery, '');
      expect(reset.properties, isEmpty);
      expect(reset.nextCursor, isNull);
    });

    test('resetFilters sets searchQuery to null for discover page', () {
      final model = PageStateModel(
        pageType: PageType.discover,
        filters: UnifiedFilterModel.initial(),
        searchQuery: null,
        properties: const [],
      );
      final reset = model.resetFilters();

      expect(reset.searchQuery, isNull);
    });
  });
}
