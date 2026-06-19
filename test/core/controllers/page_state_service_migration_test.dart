import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/controllers/page_state_service.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';

void main() {
  group('PageStateService.normalizeLegacyStateForRuntime', () {
    test('resets transient loading/pagination fields', () {
      final legacy = PageStateModel(
        pageType: PageType.discover,
        selectedLocation: const LocationData(
          name: 'Sector 10A, Gurugram',
          latitude: 28.44574,
          longitude: 77.008294,
        ),
        locationSource: 'gps',
        filters: UnifiedFilterModel.initial(),
        searchQuery: '2bhk',
        properties: const [],
        hasMore: false,
        isLoading: true,
        isLoadingMore: true,
        isRefreshing: true,
        error: NetworkException('stale loading'),
        additionalData: const {'searchVisible': true},
      );

      final normalized = PageStateService.normalizeLegacyStateForRuntime(legacy);

      expect(normalized.nextCursor, isNull);
      expect(normalized.hasMore, isTrue);
      expect(normalized.isLoading, isFalse);
      expect(normalized.isLoadingMore, isFalse);
      expect(normalized.isRefreshing, isFalse);
      expect(normalized.error, isNull);
      expect(normalized.properties, isEmpty);
    });

    test('preserves semantic state fields', () {
      final legacy = PageStateModel(
        pageType: PageType.likes,
        selectedLocation: const LocationData(name: 'Delhi', latitude: 28.6139, longitude: 77.2090),
        locationSource: 'manual',
        filters: UnifiedFilterModel.initial().copyWith(purpose: 'rent'),
        searchQuery: 'studio',
        properties: const [],
        additionalData: const {'currentSegment': 'passed'},
        lastFetched: DateTime(2026, 2, 10),
      );

      final normalized = PageStateService.normalizeLegacyStateForRuntime(legacy);

      expect(normalized.pageType, PageType.likes);
      expect(normalized.selectedLocation?.name, 'Delhi');
      expect(normalized.locationSource, 'manual');
      expect(normalized.filters.purpose, 'rent');
      expect(normalized.searchQuery, 'studio');
      expect(normalized.additionalData?['currentSegment'], 'passed');
      expect(normalized.lastFetched, DateTime(2026, 2, 10));
    });
  });
}
