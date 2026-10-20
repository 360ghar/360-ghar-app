// Device filter preferences replace PageStateService's filter delegates.
// Shared deck/swipe behavior is covered in property_providers_test.dart.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/data/ports/swipes_port.dart';
import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/properties/application/property_filters.dart';
import 'package:ghar360/features/properties/application/property_queries.dart';
import 'package:ghar360/features/properties/application/swipe_history.dart';
import '../../helpers/property_query_test_support.dart';

void main() {
  late PropertyQueryHarness h;
  setUp(() async {
    h = await PropertyQueryHarness.create();
  });
  tearDown(() async {
    await h.close();
  });
  PropertyFilters filters() => h.container.read(propertyFiltersProvider.notifier);
  UnifiedFilterModel page(PageType page) => h.container.read(propertyFiltersProvider).forPage(page);
  test('every page starts with validated defaults and immutable page map', () {
    for (final type in PageType.values) {
      expect(page(type).purpose, 'buy');
      expect(page(type).radiusKm, 10);
    }
    expect(() => h.container.read(propertyFiltersProvider).pages.clear(), throwsUnsupportedError);
  });
  test('global purpose and normalized types propagate but local filters do not', () async {
    await filters().update(
      PageType.explore,
      const UnifiedFilterModel(
        purpose: 'shortstay',
        propertyType: ['flat', 'apartments', 'unknown', 'Builder Floor'],
        priceMin: 20,
        searchQuery: 'park',
        amenities: ['pool'],
      ),
    );
    for (final type in PageType.values) {
      expect(page(type).purpose, 'short_stay');
      expect(page(type).propertyType, ['apartment', 'builder_floor']);
    }
    expect(page(PageType.explore).priceMin, 20);
    expect(page(PageType.explore).searchQuery, 'park');
    expect(page(PageType.discover).priceMin, isNull);
    expect(page(PageType.likes).searchQuery, isNull);
    expect(page(PageType.likes).amenities, isEmpty);
  });
  test('local changes preserve another page price, radius and search', () async {
    await filters().update(
      PageType.likes,
      const UnifiedFilterModel(purpose: 'buy', priceMin: 30, searchQuery: 'studio', radiusKm: 20),
    );
    await filters().update(
      PageType.explore,
      const UnifiedFilterModel(purpose: 'rent', priceMax: 50, searchQuery: 'park', radiusKm: 5),
    );
    expect(page(PageType.likes).purpose, 'rent');
    expect(page(PageType.likes).priceMin, 30);
    expect(page(PageType.likes).searchQuery, 'studio');
    expect(page(PageType.likes).radiusKm, 20);
  });
  test('filter inputs cannot mutate published state or queued persistence', () async {
    final types = ['flat'];
    final amenities = ['pool'];
    final features = ['balcony'];
    final ids = [1];
    final work = filters().update(
      PageType.explore,
      UnifiedFilterModel(
        propertyType: types,
        amenities: amenities,
        features: features,
        propertyIds: ids,
      ),
    );
    types.add('house');
    amenities.add('gym');
    features.clear();
    ids.add(2);
    await work;
    final value = page(PageType.explore);
    expect(value.propertyType, ['apartment']);
    expect(value.amenities, ['pool']);
    expect(value.features, ['balcony']);
    expect(value.propertyIds, [1]);
    for (final values in [
      value.propertyType!,
      value.amenities!,
      value.features!,
      value.propertyIds!,
    ]) {
      expect(() => values.clear(), throwsUnsupportedError);
    }
    h.container.invalidate(propertyFiltersProvider);
    expect(page(PageType.explore).amenities, ['pool']);
  });
  test('rehydrated filter lists remain immutable', () async {
    await filters().update(
      PageType.explore,
      const UnifiedFilterModel(
        propertyType: ['flat'],
        amenities: ['pool'],
        features: ['balcony'],
        propertyIds: [1],
      ),
    );
    h.container.invalidate(propertyFiltersProvider);
    final value = page(PageType.explore);
    for (final values in [
      value.propertyType!,
      value.amenities!,
      value.features!,
      value.propertyIds!,
    ]) {
      expect(() => values.clear(), throwsUnsupportedError);
    }
  });
  test('search is page-specific, clearable, and excluded from Discover', () async {
    await filters().search(PageType.explore, 'park');
    await filters().search(PageType.likes, 'studio');
    await filters().search(PageType.discover, 'ignored');
    expect(page(PageType.explore).searchQuery, 'park');
    expect(page(PageType.likes).searchQuery, 'studio');
    expect(page(PageType.discover).searchQuery, isNull);
    await filters().search(PageType.explore, '');
    expect(page(PageType.explore).searchQuery, '');
    h.container.invalidate(propertyFiltersProvider);
    expect(page(PageType.explore).searchQuery, isNull);
    expect(page(PageType.likes).searchQuery, 'studio');
  });
  test('reset one page restores shared defaults and keeps other local filters', () async {
    await filters().update(
      PageType.likes,
      const UnifiedFilterModel(
        purpose: 'rent',
        propertyType: ['house'],
        priceMin: 30,
        searchQuery: 'studio',
      ),
    );
    await filters().update(
      PageType.explore,
      const UnifiedFilterModel(
        purpose: 'rent',
        propertyType: ['house'],
        priceMax: 50,
        searchQuery: 'park',
      ),
    );
    await filters().reset(PageType.explore);
    expect(page(PageType.explore).priceMax, isNull);
    expect(page(PageType.explore).searchQuery, isNull);
    expect(page(PageType.likes).priceMin, 30);
    expect(page(PageType.likes).searchQuery, 'studio');
    for (final type in PageType.values) {
      expect(page(type).purpose, 'buy');
      expect(page(type).propertyType, isEmpty);
    }
  });
  test('reset all filters clears every persisted local query', () async {
    await filters().update(
      PageType.likes,
      const UnifiedFilterModel(purpose: 'rent', priceMin: 20, searchQuery: 'studio'),
    );
    await filters().resetAll();
    h.container.invalidate(propertyFiltersProvider);
    for (final type in PageType.values) {
      expect(page(type).purpose, 'buy');
      expect(page(type).priceMin, isNull);
      expect(page(type).searchQuery, isNull);
    }
  });
  test('a disk failure retains draft filter values and retries the same snapshot', () async {
    await h.raw.execute(
      "CREATE TRIGGER reject_filter BEFORE INSERT ON preferences WHEN NEW.key = 'property_filters_v1' BEGIN SELECT RAISE(ABORT, 'disk unavailable'); END",
    );
    expect(await filters().search(PageType.explore, 'park'), false);
    expect(page(PageType.explore).searchQuery, 'park');
    expect(h.container.read(propertyFiltersProvider).save.error, isA<StorageFailure>());
    await h.raw.execute('DROP TRIGGER reject_filter');
    expect(await filters().retrySave(), true);
    expect(h.container.read(propertyFiltersProvider).save.error, isNull);
    h.container.invalidate(propertyFiltersProvider);
    expect(page(PageType.explore).searchQuery, 'park');
  });
  test('rapid saves are serialized and older completion cannot replace new input', () async {
    final first = filters().search(PageType.explore, 'old');
    final second = filters().search(PageType.explore, 'new');
    expect(page(PageType.explore).searchQuery, 'new');
    await Future.wait([first, second]);
    expect(page(PageType.explore).searchQuery, 'new');
    h.container.invalidate(propertyFiltersProvider);
    expect(page(PageType.explore).searchQuery, 'new');
  });
  test(
    'preferences remain available after account change while server data resets elsewhere',
    () async {
      await filters().search(PageType.explore, 'park');
      h.scope.change('b');
      expect(page(PageType.explore).searchQuery, 'park');
    },
  );
  group('shared swipe and deck projection', () {
    Future<SwipeHistory> history() async {
      final value = h.container.read(swipeHistoryProvider.notifier);
      await waitForQuery(() => h.container.read(swipeHistoryProvider).hydrated);
      return value;
    }

    List<int> visible(PropertyFeed feed) =>
        h.container.read(visiblePropertiesProvider(feed)).map((p) => p.id).toList();
    test('local like is visible in liked feed while passed feed remains independent', () async {
      h.swipes.response = (_, liked) async => queryPage(liked == true ? [2] : [3]);
      h.properties.response = (_) async => queryPage([7]);
      await h.loaded(PropertyFeed.explore);
      await h.loaded(PropertyFeed.liked);
      await h.loaded(PropertyFeed.passed);
      final swipes = await history();
      await swipes.record(queryProperty(7), true);
      expect(visible(PropertyFeed.liked), [7, 2]);
      expect(visible(PropertyFeed.passed), [3]);
    });
    test('opposite local intent overrides stale server liked rows without duplicates', () async {
      h.swipes.response = (_, _) async => queryPage([1, 2]);
      await h.loaded(PropertyFeed.liked);
      await h.loaded(PropertyFeed.passed);
      final swipes = await history();
      await swipes.record(queryProperty(1), false);
      expect(visible(PropertyFeed.liked), [2]);
      expect(visible(PropertyFeed.passed), [1, 2]);
      await h.query(PropertyFeed.liked).load(refresh: true);
      expect(visible(PropertyFeed.liked), [2]);
    });
    test('server catches up to a local like without adding a duplicate', () async {
      h.swipes.response = (_, _) async => queryPage([2]);
      await h.loaded(PropertyFeed.liked);
      final swipes = await history();
      await swipes.record(queryProperty(1), true);
      h.swipes.response = (_, _) async => queryPage([1, 2]);
      await h.query(PropertyFeed.liked).load(refresh: true);
      expect(visible(PropertyFeed.liked), [1, 2]);
    });
    test('restored card survives a later refresh that omits it and undo is single-use', () async {
      h.properties.response = (_) async => queryPage([1, 2]);
      await h.loaded(PropertyFeed.discover);
      final swipes = await history();
      await swipes.record(queryProperty(1), true);
      expect(visible(PropertyFeed.discover), [2]);
      expect(await swipes.undo(1), true);
      expect(await swipes.undo(1), false);
      h.properties.response = (_) async => queryPage([2, 3]);
      await h.query(PropertyFeed.discover).load(refresh: true);
      expect(visible(PropertyFeed.discover), [1, 2, 3]);
      expect(h.swipes.mutations.length, 2);
    });
    test('failed undo retains previous exclusion and exposes one mutation error', () async {
      h.properties.response = (_) async => queryPage([1, 2]);
      await h.loaded(PropertyFeed.discover);
      final swipes = await history();
      await swipes.record(queryProperty(1), true);
      h.swipes.mutation = (_, _) async => throw NetworkException('offline');
      expect(await swipes.undo(1), false);
      expect(visible(PropertyFeed.discover), [2]);
      expect(h.container.read(swipeHistoryProvider).failures.keys, [1]);
    });
    test('scoped swipe snapshot restores exclusions but does not fetch a deck cache', () async {
      h.properties.response = (_) async => queryPage([1, 2]);
      await h.loaded(PropertyFeed.discover);
      final swipes = await history();
      await swipes.record(queryProperty(1), false);
      await swipes.retrySave();
      h.container.invalidate(swipeHistoryProvider);
      await history();
      expect(visible(PropertyFeed.discover), [2]);
      expect(h.container.read(swipeHistoryProvider).passes, 1);
      expect(await h.raw.query('cache'), isEmpty);
    });
    test(
      'account change rejects a previous mutation without exposing its optimistic state',
      () async {
        final swipes = await history();
        final pending = Completer<SwipeOutcome>();
        h.swipes.mutation = (_, _) => pending.future;
        final action = swipes.record(queryProperty(1), true);
        await waitForQuery(() => h.swipes.mutations.isNotEmpty);
        h.scope.change('b');
        expect(h.container.read(swipeHistoryProvider).entries, isEmpty);
        pending.complete(const ConfirmedSwipe());
        await action;
        await history();
        expect(h.container.read(swipeHistoryProvider).entries, isEmpty);
        expect(h.container.read(swipeHistoryProvider).excluded, isEmpty);
      },
    );
    test('record uses the supplied model even when it is absent from every server list', () async {
      final swipes = await history();
      await swipes.record(queryProperty(99), true);
      expect(h.container.read(swipeHistoryProvider).entries[99]!.property.title, 'Property 99');
      expect(h.swipes.mutations.single.id, 99);
    });
  });
}
