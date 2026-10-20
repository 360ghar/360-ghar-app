import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/data/models/unified_property_response.dart';
import 'package:ghar360/core/data/ports/properties_port.dart';
import 'package:ghar360/core/data/ports/swipes_port.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/properties/application/property_filters.dart';
import 'package:ghar360/features/properties/application/property_location.dart';
import 'package:ghar360/features/properties/application/property_queries.dart';
import 'package:ghar360/features/properties/application/swipe_history.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class TestScope extends StorageScopeNotifier {
  @override
  StorageScope build() =>
      ref.read(appDatabaseProvider).activateScope(environment: 'test', accountId: 'a');
  void change(String account) {
    state = ref.read(appDatabaseProvider).activateScope(environment: 'test', accountId: account);
  }
}

class Properties extends Fake implements PropertiesPort {
  final requests = <({UnifiedFilterModel filters, String? cursor, double latitude})>[];
  Future<UnifiedPropertyResponse> Function(String?) response = (_) async => page([1]);
  @override
  Future<UnifiedPropertyResponse> searchProperties({
    required UnifiedFilterModel filters,
    required String? cursor,
    required int limit,
    required double latitude,
    required double longitude,
    double? radiusKm,
    bool excludeSwiped = false,
    bool useCache = false,
  }) {
    requests.add((filters: filters, cursor: cursor, latitude: latitude));
    return response(cursor);
  }
}

class Swipes extends Fake implements SwipesPort {
  final requests = <({int id, bool liked})>[];
  Future<SwipeOutcome> Function(int, bool) response = (_, _) async => const ConfirmedSwipe();
  @override
  Future<SwipeOutcome> recordSwipe({required int propertyId, required bool isLiked}) {
    requests.add((id: propertyId, liked: isLiked));
    return response(propertyId, isLiked);
  }

  @override
  Future<UnifiedPropertyResponse> getSwipeHistoryProperties({
    required UnifiedFilterModel filters,
    double? latitude,
    double? longitude,
    String? cursor,
    int limit = 50,
    bool? isLiked,
  }) async => page([1, 2]);
}

PropertyModel property(int id) => PropertyModel(
  id: id,
  ownerId: 7,
  createdAt: DateTime.utc(2026, 9, 30),
  updatedAt: DateTime.utc(2026, 9, 30),
  title: 'Property $id',
  basePrice: 1000000,
  isAvailable: true,
  viewCount: 0,
  likeCount: 0,
  interestCount: 0,
);
UnifiedPropertyResponse page(List<int> ids, [String? cursor]) => UnifiedPropertyResponse(
  items: ids.map(property).toList(),
  nextCursor: cursor,
  hasMore: cursor != null,
);
Future<void> until(bool Function() condition) async {
  for (var i = 0; i < 200; i++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('Provider did not reach expected state in 1 second');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase database;
  late ProviderContainer container;
  late Properties properties;
  late Swipes swipes;
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    database = await AppDatabase.open(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
      legacyReader: () async => {
        for (final type in PageType.values)
          '${type.name}_state': {
            'selectedLocation': {'name': 'Delhi', 'latitude': 28.6, 'longitude': 77.2},
            'filters': {'purpose': 'buy'},
          },
      },
    );
    properties = Properties();
    swipes = Swipes();
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        storageScopeProvider.overrideWith(TestScope.new),
        propertiesRepositoryProvider.overrideWithValue(properties),
        swipesRepositoryProvider.overrideWithValue(swipes),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await database.close();
  });
  PropertyPageState state([PropertyFeed feed = PropertyFeed.explore]) =>
      container.read(propertyQueryProvider(feed));
  PropertyQuery query([PropertyFeed feed = PropertyFeed.explore]) =>
      container.read(propertyQueryProvider(feed).notifier);
  Future<void> loaded([PropertyFeed feed = PropertyFeed.explore]) async {
    state(feed);
    await until(() => state(feed).updatedAt != null && !state(feed).busy);
  }

  test('initial content and immutable rows', () async {
    await loaded();
    expect(state().items.single.id, 1);
    expect(state().phase, PropertyLoadPhase.content);
    expect(() => state().items.clear(), throwsUnsupportedError);
    expect(properties.requests, hasLength(1));
  });
  test('empty response remains distinct from failure', () async {
    properties.response = (_) async => page([]);
    await loaded();
    expect(state().phase, PropertyLoadPhase.empty);
    properties.response = (_) async => throw NetworkException('offline');
    await query().load(refresh: true);
    expect(state().showFullError, isTrue);
    expect(state().phase, PropertyLoadPhase.failure);
  });
  test('refresh retains content then exposes a recoverable failure', () async {
    await loaded();
    final pending = Completer<UnifiedPropertyResponse>();
    properties.response = (_) => pending.future;
    final refresh = query().load(refresh: true);
    expect(state().isRefreshing, isTrue);
    expect(state().items.single.id, 1);
    pending.completeError(NetworkException('offline'));
    await refresh;
    expect(state().items.single.id, 1);
    expect(state().error, isA<NetworkException>());
    expect(state().stale, isTrue);
    expect(state().showFullError, isFalse);
    properties.response = (_) async => page([2]);
    await query().load(refresh: true);
    expect(state().items.single.id, 2);
    expect(state().error, isNull);
    expect(state().stale, isFalse);
  });
  test('short first page still follows server cursor', () async {
    properties.response = (cursor) async => cursor == null ? page([1], 'a') : page([2]);
    await loaded();
    expect(state().hasMore, isTrue);
    await query().loadMore();
    expect(state().items.map((p) => p.id), [1, 2]);
    expect(state().hasMore, isFalse);
  });
  test('pagination failure keeps cursor and suppresses automatic retry storm', () async {
    properties.response = (_) async => page([1], 'a');
    await loaded();
    properties.response = (_) async => throw NetworkException('offline');
    await query().loadMore();
    expect(state().items.single.id, 1);
    expect(state().nextCursor, 'a');
    expect(state().paginationError, isA<NetworkException>());
    await query().loadMore();
    await query().loadMore();
    expect(properties.requests, hasLength(2));
    properties.response = (_) async => page([1, 2]);
    await query().loadMore(retry: true);
    expect(properties.requests.last.cursor, 'a');
    expect(state().items.map((p) => p.id), [1, 2]);
    expect(state().paginationError, isNull);
  });
  test('repeated cursor cycle terminates without another request', () async {
    properties.response = (cursor) async => switch (cursor) {
      null => page([1], 'a'),
      'a' => page([2], 'b'),
      _ => page([3], 'a'),
    };
    await loaded();
    await query().loadMore();
    await query().loadMore();
    await query().loadMore();
    expect(state().items, hasLength(3));
    expect(state().hasMore, isFalse);
    expect(properties.requests, hasLength(3));
  });
  test('refresh supersedes stale pagination and its failure', () async {
    properties.response = (_) async => page([1], 'a');
    await loaded();
    final old = Completer<UnifiedPropertyResponse>();
    properties.response = (_) => old.future;
    final more = query().loadMore();
    properties.response = (_) async => page([3]);
    await query().load(refresh: true);
    old.completeError(NetworkException('old'));
    await more;
    expect(state().items.single.id, 3);
    expect(state().paginationError, isNull);
  });
  test('filter input invalidates old completion immediately', () async {
    final old = Completer<UnifiedPropertyResponse>();
    properties.response = (_) => old.future;
    state();
    await until(() => properties.requests.isNotEmpty);
    await container.read(propertyFiltersProvider.notifier).search(PageType.explore, 'park');
    old.complete(page([8]));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(state().items, isEmpty);
    properties.response = (_) async => page([9]);
    await until(() => state().items.isNotEmpty);
    expect(state().items.single.id, 9);
    expect(properties.requests.last.filters.searchQuery, 'park');
  });
  test('scope change rejects pending old-account content', () async {
    final old = Completer<UnifiedPropertyResponse>();
    properties.response = (_) => old.future;
    state();
    await until(() => properties.requests.isNotEmpty);
    properties.response = (_) async => page([2]);
    (container.read(storageScopeProvider.notifier) as TestScope).change('b');
    await loaded();
    old.complete(page([1]));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(state().items.single.id, 2);
  });
  test('SQLite content is visible while revalidation is unresolved', () async {
    await loaded();
    container.invalidate(propertyQueryProvider(PropertyFeed.explore));
    final fresh = Completer<UnifiedPropertyResponse>();
    properties.response = (_) => fresh.future;
    state();
    await until(() => state().items.isNotEmpty);
    expect(state().isRefreshing, isTrue);
    expect(state().items.single.id, 1);
    fresh.completeError(NetworkException('offline'));
    await until(() => !state().busy);
    expect(state().items.single.id, 1);
    expect(state().stale, isTrue);
  });
  test('Discover does not persist or hydrate a deck cache', () async {
    await loaded(PropertyFeed.discover);
    container.invalidate(propertyQueryProvider(PropertyFeed.discover));
    final fresh = Completer<UnifiedPropertyResponse>();
    properties.response = (_) => fresh.future;
    state(PropertyFeed.discover);
    await until(() => properties.requests.length == 2);
    expect(state(PropertyFeed.discover).items, isEmpty);
    fresh.complete(page([2]));
    await loaded(PropertyFeed.discover);
    expect(state(PropertyFeed.discover).items.single.id, 2);
  });
  test('global purpose and types propagate; price and search stay page-specific', () async {
    final filters = container.read(propertyFiltersProvider.notifier);
    await filters.update(
      PageType.explore,
      const UnifiedFilterModel(
        purpose: 'rent',
        propertyType: ['flat'],
        priceMin: 200,
        searchQuery: 'park',
      ),
    );
    final result = container.read(propertyFiltersProvider);
    expect(result.forPage(PageType.discover).purpose, 'rent');
    expect(result.forPage(PageType.likes).propertyType, ['apartment']);
    expect(result.forPage(PageType.likes).priceMin, isNull);
    expect(result.forPage(PageType.likes).searchQuery, isNull);
    container.invalidate(propertyFiltersProvider);
    expect(container.read(propertyFiltersProvider).forPage(PageType.explore).priceMin, 200);
  });
  test('manual location survives provider replacement in scoped storage', () async {
    final location = container.read(propertyLocationProvider(PageType.explore).notifier);
    await location.select(const LocationData(name: 'Mumbai', latitude: 19.07, longitude: 72.87));
    container.invalidate(propertyLocationProvider(PageType.explore));
    await container.read(propertyLocationProvider(PageType.explore).notifier).ensureLocation();
    expect(container.read(propertyLocationProvider(PageType.explore)).location?.name, 'Mumbai');
  });
  test('concurrent swipes on separate properties retain both outcomes', () async {
    final history = container.read(swipeHistoryProvider.notifier);
    await until(() => container.read(swipeHistoryProvider).hydrated);
    final first = Completer<SwipeOutcome>();
    final second = Completer<SwipeOutcome>();
    swipes.response = (id, _) => id == 1 ? first.future : second.future;
    final one = history.record(property(1), true);
    final two = history.record(property(2), false);
    await until(() => swipes.requests.length == 2);
    second.complete(const ConfirmedSwipe());
    first.complete(const ConfirmedSwipe());
    expect(await one, isTrue);
    expect(await two, isTrue);
    expect(container.read(swipeHistoryProvider).excluded, {1, 2});
    expect(container.read(swipeHistoryProvider).likes, 1);
    expect(container.read(swipeHistoryProvider).passes, 1);
  });
  test('same property requests stay ordered and old failure cannot roll back new intent', () async {
    final history = container.read(swipeHistoryProvider.notifier);
    await until(() => container.read(swipeHistoryProvider).hydrated);
    final old = Completer<SwipeOutcome>();
    swipes.response = (_, liked) => liked ? old.future : Future.value(const ConfirmedSwipe());
    final first = history.record(property(1), true);
    final last = history.record(property(1), false);
    await until(() => swipes.requests.isNotEmpty);
    expect(swipes.requests, hasLength(1));
    old.completeError(NetworkException('failed old action'));
    expect(await first, isFalse);
    expect(await last, isTrue);
    expect(container.read(swipeHistoryProvider).entries[1]!.isLiked, isFalse);
    expect(container.read(swipeHistoryProvider).failures, isEmpty);
  });
  test('failed swipe rolls back only its own property and exposes mutation failure', () async {
    final history = container.read(swipeHistoryProvider.notifier);
    await until(() => container.read(swipeHistoryProvider).hydrated);
    swipes.response = (id, _) async {
      if (id == 1) throw NetworkException('offline');
      return const ConfirmedSwipe();
    };
    await Future.wait([history.record(property(1), true), history.record(property(2), true)]);
    expect(container.read(swipeHistoryProvider).excluded, {2});
    expect(container.read(swipeHistoryProvider).failures.keys, [1]);
  });
  test('swiped cards stay excluded during refresh and undo restores them', () async {
    properties.response = (_) async => page([1, 2]);
    container.read(visiblePropertiesProvider(PropertyFeed.discover));
    await loaded(PropertyFeed.discover);
    await until(() => container.read(swipeHistoryProvider).hydrated);
    final history = container.read(swipeHistoryProvider.notifier);
    await history.record(property(1), true);
    await query(PropertyFeed.discover).load(refresh: true);
    expect(container.read(visiblePropertiesProvider(PropertyFeed.discover)).map((p) => p.id), [2]);
    await history.undo(1);
    expect(container.read(visiblePropertiesProvider(PropertyFeed.discover)).map((p) => p.id), [
      1,
      2,
    ]);
  });
  test('disposed provider rejects an in-flight network completion', () async {
    final old = Completer<UnifiedPropertyResponse>();
    properties.response = (_) => old.future;
    state();
    await until(() => properties.requests.isNotEmpty);
    container.dispose();
    old.complete(page([1]));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    // Disposal itself is the assertion: no unhandled update-after-dispose error.
    container = ProviderContainer();
  });
}
