// Filter behavior previously delegated through PageFilterManager now belongs to
// one immutable provider. Widget tests own text controllers and debounce timing.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/features/properties/application/property_filters.dart';
import '../../helpers/property_query_test_support.dart';
import '../../helpers/settings_test_database.dart';

void main() {
  late SettingsTestDatabase database;
  late ProviderContainer container;
  PropertyFilters getController() => container.read(propertyFiltersProvider.notifier);
  UnifiedFilterModel filters(PageType page) =>
      container.read(propertyFiltersProvider).forPage(page);

  setUp(() {
    database = SettingsTestDatabase();
    container = ProviderContainer(overrides: [appDatabaseProvider.overrideWithValue(database)]);
  });
  tearDown(() => container.dispose());

  test('fresh feeds have independent default filters', () {
    for (final page in PageType.values) {
      expect(filters(page).purpose, 'buy');
      expect(filters(page).propertyType, isEmpty);
      expect(filters(page).radiusKm, 10);
    }
  });

  test('page-only price, amenity, and search changes leave other pages unchanged', () async {
    await getController().update(
      PageType.explore,
      filters(
        PageType.explore,
      ).copyWith(priceMin: 100, priceMax: 500, amenities: ['parking'], searchQuery: 'Delhi'),
    );
    expect(filters(PageType.explore).priceMax, 500);
    for (final page in [PageType.discover, PageType.likes]) {
      expect(filters(page).priceMax, isNull);
      expect(filters(page).searchQuery, isNull);
      expect(filters(page).amenities, isEmpty);
    }
  });

  test('purpose and property type propagate together and persist canonical values', () async {
    await getController().update(
      PageType.explore,
      filters(
        PageType.explore,
      ).copyWith(purpose: ' rent ', propertyType: ['flat', 'house', 'flat']),
    );
    for (final page in PageType.values) {
      expect(filters(page).purpose, 'rent');
      expect(filters(page).propertyType, ['apartment', 'house']);
    }
    expect(database.values['global_purpose'], 'rent');
    expect(database.values['global_property_types'], ['apartment', 'house']);
    expect(database.writeCount, 1);
    expect(
      (database.values['property_filters_v1'] as Map).keys,
      containsAll(['discover', 'explore', 'likes']),
    );
  });

  test('shared changes retain other pages local filters', () async {
    await getController().update(
      PageType.likes,
      filters(PageType.likes).copyWith(priceMin: 700, searchQuery: 'Saved'),
    );
    await getController().update(
      PageType.explore,
      filters(PageType.explore).copyWith(purpose: 'rent'),
    );
    expect(filters(PageType.likes).purpose, 'rent');
    expect(filters(PageType.likes).priceMin, 700);
    expect(filters(PageType.likes).searchQuery, 'Saved');
  });

  test('empty purpose normalizes to buy rather than persisting an invalid token', () async {
    await getController().update(
      PageType.explore,
      filters(PageType.explore).copyWith(purpose: 'rent'),
    );
    await getController().update(
      PageType.explore,
      filters(PageType.explore).copyWith(purpose: '  '),
    );
    expect(database.values['global_purpose'], 'buy');
    expect(filters(PageType.likes).purpose, 'buy');
  });

  test('clearing property types propagates to every feed', () async {
    await getController().update(
      PageType.explore,
      filters(PageType.explore).copyWith(propertyType: ['house']),
    );
    await getController().update(
      PageType.explore,
      filters(PageType.explore).copyWith(propertyType: []),
    );
    for (final page in PageType.values) {
      expect(filters(page).propertyType, isEmpty);
    }
  });

  test('search updates and clears only the requested searchable feed', () async {
    await getController().search(PageType.explore, 'Delhi');
    await getController().search(PageType.likes, 'Mumbai');
    await getController().search(PageType.explore, '');
    expect(filters(PageType.explore).searchQuery, '');
    expect(filters(PageType.likes).searchQuery, 'Mumbai');
  });

  test('Discover search does not mutate preferences or write storage', () async {
    final before = container.read(propertyFiltersProvider);
    expect(await getController().search(PageType.discover, 'ignored'), isTrue);
    expect(container.read(propertyFiltersProvider), same(before));
    expect(database.writeCount, 0);
  });

  test(
    'reset page restores defaults and shared values without clearing another page search',
    () async {
      await getController().update(
        PageType.explore,
        filters(PageType.explore).copyWith(purpose: 'rent', priceMin: 500),
      );
      await getController().search(PageType.likes, 'retained');
      await getController().reset(PageType.explore);
      expect(filters(PageType.explore).toJson(), UnifiedFilterModel.initial().toJson());
      expect(filters(PageType.likes).purpose, 'buy');
      expect(filters(PageType.likes).searchQuery, 'retained');
    },
  );

  test('reset all persists complete defaults for every feed', () async {
    await getController().search(PageType.likes, 'Saved');
    await getController().update(
      PageType.explore,
      filters(PageType.explore).copyWith(purpose: 'rent', propertyType: ['house']),
    );
    expect(await getController().resetAll(), isTrue);
    for (final page in PageType.values) {
      expect(filters(page).toJson(), UnifiedFilterModel.initial().toJson());
    }
  });

  test('restores global values over page values and filters invalid stored types', () {
    database.values.addAll({
      'global_purpose': 'rent',
      'global_property_types': ['flat', 42, 'house', true],
      'explore_state': {
        'filters': {'purpose': 'buy', 'price_min': 700.0},
        'searchQuery': 'Legacy',
      },
    });
    expect(filters(PageType.explore).priceMin, 700);
    expect(filters(PageType.explore).searchQuery, 'Legacy');
    for (final page in PageType.values) {
      expect(filters(page).purpose, 'rent');
      expect(filters(page).propertyType, ['apartment', 'house']);
    }
  });

  test('new snapshot wins over legacy page snapshot', () {
    database.values.addAll({
      'property_filters_v1': {
        'explore': {'price_min': 900.0, 'search_query': 'New'},
      },
      'explore_state': {
        'filters': {'price_min': 700.0},
        'searchQuery': 'Legacy',
      },
      'discover_state': {'searchQuery': 'Never apply to deck'},
    });
    expect(filters(PageType.explore).priceMin, 900);
    expect(filters(PageType.explore).searchQuery, 'New');
    expect(filters(PageType.discover).searchQuery, isNull);
  });

  test('malformed page cannot prevent valid page hydration', () {
    database.values['property_filters_v1'] = {
      'explore': {'price_min': 'not a number'},
      'likes': {'search_query': 'Valid'},
    };
    expect(filters(PageType.explore).priceMin, isNull);
    expect(filters(PageType.likes).searchQuery, 'Valid');
  });

  test('input collections cannot mutate published or persisted filters', () async {
    final amenities = ['parking'];
    final ids = [1];
    final done = getController().update(
      PageType.explore,
      filters(PageType.explore).copyWith(amenities: amenities, propertyIds: ids),
    );
    amenities.add('pool');
    ids.add(2);
    await done;
    expect(filters(PageType.explore).amenities, ['parking']);
    expect(filters(PageType.explore).propertyIds, [1]);
    expect(() => filters(PageType.explore).amenities!.add('pool'), throwsUnsupportedError);
    expect(() => container.read(propertyFiltersProvider).pages.clear(), throwsUnsupportedError);
  });

  test('storage failure retains draft and exposes explicit retry', () async {
    database.writeFailure = StorageFailure('disk full', code: 'SQLITE_FULL');
    expect(await getController().search(PageType.explore, 'Unsaved'), isFalse);
    expect(filters(PageType.explore).searchQuery, 'Unsaved');
    expect(container.read(propertyFiltersProvider).save.error, isA<StorageFailure>());
    expect(database.values, isEmpty);
    database.writeFailure = null;
    expect(await getController().retrySave(), isTrue);
    expect(container.read(propertyFiltersProvider).save.hasError, isFalse);
    expect((database.values['property_filters_v1'] as Map)['explore']['search_query'], 'Unsaved');
  });

  test('serialized writes cannot replace newest filters with old completion', () async {
    final release = Completer<void>();
    database.beforeWrite = () => release.future;
    final first = getController().search(PageType.explore, 'First');
    final second = getController().search(PageType.explore, 'Second');
    expect(filters(PageType.explore).searchQuery, 'Second');
    expect(container.read(propertyFiltersProvider).save.isLoading, isTrue);
    release.complete();
    await Future.wait([first, second]);
    expect(filters(PageType.explore).searchQuery, 'Second');
    expect((database.values['property_filters_v1'] as Map)['explore']['search_query'], 'Second');
  });

  test('pending durable write does not publish into a disposed provider', () async {
    final release = Completer<void>();
    database.beforeWrite = () => release.future;
    final save = getController().search(PageType.explore, 'Persist me');
    container.dispose();
    release.complete();
    expect(await save, isTrue);
    expect(
      (database.values['property_filters_v1'] as Map)['explore']['search_query'],
      'Persist me',
    );
  });

  test('real SQLite restores filter snapshot after provider disposal', () async {
    final harness = await PropertyQueryHarness.create();
    addTearDown(harness.close);
    final owner = harness.container.read(propertyFiltersProvider.notifier);
    await owner.update(
      PageType.explore,
      UnifiedFilterModel.initial().copyWith(
        purpose: 'rent',
        priceMax: 2000,
        searchQuery: 'Restored',
      ),
    );
    harness.disposeProviders();
    final restored = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(harness.database)],
    );
    addTearDown(restored.dispose);
    expect(
      restored.read(propertyFiltersProvider).forPage(PageType.explore).searchQuery,
      'Restored',
    );
    expect(restored.read(propertyFiltersProvider).forPage(PageType.explore).priceMax, 2000);
    expect(restored.read(propertyFiltersProvider).forPage(PageType.discover).purpose, 'rent');
  });
}
