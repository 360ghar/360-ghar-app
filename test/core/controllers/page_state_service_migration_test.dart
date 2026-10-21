import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/unified_property_response.dart';
import 'package:ghar360/features/properties/application/property_filters.dart';
import '../../helpers/property_query_test_support.dart';

void main() {
  test('legacy import preserves semantic preferences but not in-flight runtime fields', () async {
    final h = await PropertyQueryHarness.create(
      legacy: {
        'explore_state': {
          'selectedLocation': {'name': 'Delhi', 'latitude': 28.6, 'longitude': 77.2},
          'locationSource': 'gps',
          'filters': {
            'purpose': 'rent',
            'price_min': 10,
            'property_type': ['flat'],
          },
          'searchQuery': 'studio',
          'isLoading': true,
          'isLoadingMore': true,
          'isRefreshing': true,
          'error': 'private backend message',
          'nextCursor': 'old cursor',
          'hasMore': false,
          'properties': [
            {'id': 99},
          ],
          'lastFetched': '2026-01-01',
          'additionalData': {'searchVisible': true},
        },
        'likes_state': {
          'filters': {'purpose': 'rent'},
          'additionalData': {'currentSegment': 'passed'},
        },
        'discover_state': {
          'searchQuery': 'ignored',
          'filters': {'purpose': 'buy'},
        },
      },
    );
    addTearDown(h.close);
    final snapshot = h.database.readPreference<Map>('explore_state')!;
    expect(snapshot['selectedLocation']['name'], 'Delhi');
    expect(snapshot['locationSource'], 'manual');
    for (final transient in [
      'isLoading',
      'isLoadingMore',
      'isRefreshing',
      'error',
      'nextCursor',
      'hasMore',
      'properties',
      'lastFetched',
      'additionalData',
    ]) {
      expect(snapshot.containsKey(transient), false);
    }
    final filters = h.container.read(propertyFiltersProvider);
    expect(filters.forPage(PageType.explore).purpose, 'rent');
    expect(filters.forPage(PageType.explore).priceMin, 10);
    expect(filters.forPage(PageType.explore).propertyType, ['apartment']);
    expect(filters.forPage(PageType.explore).searchQuery, 'studio');
    expect(filters.forPage(PageType.discover).searchQuery, isNull);
    await h.container.read(propertyFiltersProvider.notifier).reset(PageType.explore);
    h.container.invalidate(propertyFiltersProvider);
    expect(h.container.read(propertyFiltersProvider).forPage(PageType.explore).searchQuery, isNull);
    expect(
      h.database.readPreference<Map>('likes_state')!['additionalData']['currentSegment'],
      'passed',
    );
    h.properties.response = (_) async => const UnifiedPropertyResponse(items: [], hasMore: false);
    await h.loaded();
    expect(h.state().busy, false);
    expect(h.state().items, isEmpty);
    expect(h.state().error, isNull);
  });
  test('one corrupt legacy page does not prevent another page filter migration', () async {
    final h = await PropertyQueryHarness.create(
      legacy: {
        'explore_state': {
          'filters': {'price_min': 'bad'},
        },
        'likes_state': {
          'filters': {'purpose': 'rent', 'price_min': 200},
        },
      },
    );
    addTearDown(h.close);
    final filters = h.container.read(propertyFiltersProvider);
    expect(filters.forPage(PageType.explore).purpose, 'buy');
    expect(filters.forPage(PageType.likes).purpose, 'rent');
    expect(filters.forPage(PageType.likes).priceMin, 200);
  });
}
