// Regression behavior from PageDataLoader now exercised through the public
// query provider and repository ports, without controller lifecycle emulation.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/data/models/unified_property_response.dart';
import 'package:ghar360/core/network/cache_policy.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/properties/application/property_filters.dart';
import 'package:ghar360/features/properties/application/property_queries.dart';
import '../../helpers/property_query_test_support.dart';

void main() {
  late PropertyQueryHarness h;
  setUp(() async {
    h = await PropertyQueryHarness.create();
  });
  tearDown(() async {
    await h.close();
  });
  for (final feed in PropertyFeed.values) {
    test('$feed calls its correct endpoint, page size and location', () async {
      await h.loaded(feed);
      if (feed.isHistory) {
        expect(h.properties.requests, isEmpty);
        final request = h.swipes.requests.single;
        expect(request.liked, feed == PropertyFeed.liked);
        expect(request.limit, 50);
        expect(request.cursor, isNull);
        expect(request.latitude, 28.6);
        expect(request.longitude, 77.2);
      } else {
        expect(h.swipes.requests, isEmpty);
        final request = h.properties.requests.single;
        expect(request.limit, feed == PropertyFeed.discover ? 20 : 50);
        expect(request.excludeSwiped, feed == PropertyFeed.discover);
        expect(request.useCache, feed != PropertyFeed.discover);
        expect(request.cursor, isNull);
        expect(request.latitude, 28.6);
        expect(request.longitude, 77.2);
      }
    });
  }
  test('foreground load has an explicit phase and immutable deduplicated rows', () async {
    final pending = Completer<UnifiedPropertyResponse>();
    h.properties.response = (_) => pending.future;
    h.state();
    await waitForQuery(() => h.properties.requests.isNotEmpty);
    expect(h.state().isLoading, true);
    expect(h.state().items, isEmpty);
    pending.complete(queryPage([1, 1, 2]));
    await h.loaded();
    expect(h.state().items.map((p) => p.id), [1, 2]);
    expect(() => h.state().items.clear(), throwsUnsupportedError);
  });
  test('one in-flight request suppresses repeated normal loads and pagination', () async {
    final pending = Completer<UnifiedPropertyResponse>();
    h.properties.response = (_) => pending.future;
    h.state();
    await waitForQuery(() => h.properties.requests.isNotEmpty);
    await h.query().load();
    await h.query().loadMore();
    expect(h.properties.requests.length, 1);
    pending.complete(queryPage([1], 'a'));
    await h.loaded();
  });
  for (final oldFails in [false, true]) {
    test(
      'forced refresh replaces in-flight request; old failure=$oldFails cannot commit',
      () async {
        final old = Completer<UnifiedPropertyResponse>();
        h.properties.response = (_) => old.future;
        h.state();
        await waitForQuery(() => h.properties.requests.isNotEmpty);
        h.properties.response = (_) async => queryPage([2]);
        await h.query().load(refresh: true);
        if (oldFails) {
          old.completeError(NetworkException('old'));
        } else {
          old.complete(queryPage([1]));
        }
        await h.container.pump();
        expect(h.state().items.single.id, 2);
        expect(h.state().error, isNull);
      },
    );
  }
  test('refresh Future completes after fetch and preserves visible rows until then', () async {
    await h.loaded();
    final pending = Completer<UnifiedPropertyResponse>();
    h.properties.response = (_) => pending.future;
    var finished = false;
    final work = h.query().load(refresh: true).then((_) {
      finished = true;
    });
    expect(h.state().isRefreshing, true);
    expect(h.state().items.single.id, 1);
    expect(finished, false);
    pending.complete(queryPage([2]));
    await work;
    expect(finished, true);
    expect(h.state().items.single.id, 2);
  });
  test('failed refresh retains content and exposes explicit retry', () async {
    await h.loaded();
    h.properties.response = (_) async => throw NetworkException('offline');
    await h.query().load(refresh: true);
    expect(h.state().items.single.id, 1);
    expect(h.state().stale, true);
    expect(h.state().error, isA<NetworkException>());
    h.properties.response = (_) async => queryPage([2]);
    await h.query().load(refresh: true);
    expect(h.state().error, isNull);
    expect(h.state().stale, false);
  });
  test('untyped initial failure is safe and distinct from a successful empty page', () async {
    h.properties.response = (_) async => throw StateError('private backend body');
    h.state();
    await waitForQuery(() => h.state().error != null);
    expect(h.state().showFullError, true);
    expect(h.state().error!.message, isNot(contains('private')));
    h.properties.response = (_) async => queryPage([]);
    await h.query().load(refresh: true);
    expect(h.state().phase, PropertyLoadPhase.empty);
    expect(h.state().error, isNull);
  });
  for (final feed in [PropertyFeed.explore, PropertyFeed.liked, PropertyFeed.passed]) {
    test('$feed appends pages in server order and deduplicates overlapping IDs', () async {
      h.properties.response = (cursor) async =>
          cursor == null ? queryPage([2, 1], 'a') : queryPage([1, 3, 3]);
      h.swipes.response = (cursor, _) async =>
          cursor == null ? queryPage([2, 1], 'a') : queryPage([1, 3, 3]);
      await h.loaded(feed);
      await h.query(feed).loadMore();
      expect(h.state(feed).items.map((p) => p.id), [2, 1, 3]);
      expect(h.state(feed).hasMore, false);
    });
  }
  test('short or empty first page still follows a valid server cursor', () async {
    h.properties.response = (cursor) async => cursor == null ? queryPage([], 'a') : queryPage([2]);
    await h.loaded();
    expect(h.state().hasMore, true);
    await h.query().loadMore();
    expect(h.state().items.single.id, 2);
  });
  test('pagination failure preserves cursor and only explicit retry repeats it', () async {
    h.properties.response = (_) async => queryPage([1], 'a');
    await h.loaded();
    h.properties.response = (_) async => throw NetworkException('offline');
    await h.query().loadMore();
    expect(h.state().nextCursor, 'a');
    expect(h.state().items.single.id, 1);
    expect(h.state().paginationError, isA<NetworkException>());
    final calls = h.properties.requests.length;
    await h.query().loadMore();
    expect(h.properties.requests.length, calls);
    h.properties.response = (_) async => queryPage([2]);
    await h.query().loadMore(retry: true);
    expect(h.properties.requests.last.cursor, 'a');
    expect(h.state().paginationError, isNull);
    expect(h.state().items.length, 2);
  });
  test('cursor cycles stop before a repeated network request', () async {
    h.properties.response = (cursor) async => switch (cursor) {
      null => queryPage([1], 'a'),
      'a' => queryPage([2], 'b'),
      _ => queryPage([3], 'a'),
    };
    await h.loaded();
    await h.query().loadMore();
    await h.query().loadMore();
    await h.query().loadMore();
    expect(h.properties.requests.map((r) => r.cursor), [null, 'a', 'b']);
    expect(h.state().hasMore, false);
    expect(h.state().items.length, 3);
  });
  test('empty next cursor is terminal even if backend hasMore is true', () async {
    h.properties.response = (_) async =>
        UnifiedPropertyResponse(items: [queryProperty(1)], nextCursor: '', hasMore: true);
    await h.loaded();
    await h.query().loadMore();
    expect(h.properties.requests.length, 1);
    expect(h.state().hasMore, false);
  });
  test('pagination cannot run twice or during a refresh', () async {
    h.properties.response = (_) async => queryPage([1], 'a');
    await h.loaded();
    final page = Completer<UnifiedPropertyResponse>();
    h.properties.response = (_) => page.future;
    final more = h.query().loadMore();
    await h.query().loadMore();
    expect(h.properties.requests.length, 2);
    h.properties.response = (_) async => queryPage([9]);
    await h.query().load(refresh: true);
    page.complete(queryPage([2], 'b'));
    await more;
    expect(h.state().items.single.id, 9);
    expect(h.state().hasMore, false);
  });
  test('filter change clears old content and rejects old pagination failure', () async {
    h.properties.response = (_) async => queryPage([1], 'a');
    await h.loaded();
    final pending = Completer<UnifiedPropertyResponse>();
    h.properties.response = (_) => pending.future;
    final more = h.query().loadMore();
    await h.container.read(propertyFiltersProvider.notifier).search(PageType.explore, 'park');
    expect(h.state().items, isEmpty);
    h.properties.response = (_) async => queryPage([3]);
    pending.completeError(NetworkException('old'));
    await more;
    await h.loaded();
    expect(h.state().items.single.id, 3);
    expect(h.state().paginationError, isNull);
  });
  test('rapid query edits debounce into the latest search only', () async {
    await h.loaded();
    final filters = h.container.read(propertyFiltersProvider.notifier);
    await filters.search(PageType.explore, 'p');
    await filters.search(PageType.explore, 'pa');
    await filters.search(PageType.explore, 'park');
    await waitForQuery(() => h.properties.requests.length == 2);
    expect(h.properties.requests.last.filters.searchQuery, 'park');
    await h.loaded();
  });
  test('equivalent filter update does not reload', () async {
    await h.loaded();
    await h.container
        .read(propertyFiltersProvider.notifier)
        .update(
          PageType.explore,
          h.container.read(propertyFiltersProvider).forPage(PageType.explore),
        );
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(h.properties.requests.length, 1);
  });
  test('location update invalidates old response and uses both new coordinates', () async {
    final old = Completer<UnifiedPropertyResponse>();
    h.properties.response = (_) => old.future;
    h.state();
    await waitForQuery(() => h.properties.requests.isNotEmpty);
    h.properties.response = (_) async => queryPage([2]);
    h.location().replace(const LocationData(name: 'Mumbai', latitude: 19.07, longitude: 72.87));
    await h.loaded();
    old.complete(queryPage([1]));
    await h.container.pump();
    expect(h.state().items.single.id, 2);
    expect(h.properties.requests.last.latitude, 19.07);
    expect(h.properties.requests.last.longitude, 72.87);
  });
  test('no selected location prevents a repository request', () async {
    h.location().replace(null);
    h.state();
    await h.container.pump();
    expect(h.properties.requests, isEmpty);
    expect(h.state().busy, false);
  });
  for (final radius in [1.0, 5.0, 100.0]) {
    test('radius $radius is passed on: the backend accepts 1 to 100 km', () async {
      await h.container
          .read(propertyFiltersProvider.notifier)
          .update(PageType.explore, UnifiedFilterModel(radiusKm: radius));
      await h.loaded();
      expect(h.properties.requests.single.radiusKm, radius);
    });
  }
  test('scope transition removes content immediately and rejects the previous result', () async {
    await h.loaded();
    final old = Completer<UnifiedPropertyResponse>();
    h.properties.response = (_) => old.future;
    final refresh = h.query().load(refresh: true);
    h.properties.response = (_) async => queryPage([2]);
    h.scope.change('b');
    expect(h.state().items, isEmpty);
    await h.loaded();
    old.complete(queryPage([1]));
    await refresh;
    expect(h.state().items.single.id, 2);
  });
  test('A to B to A rejects the first A network response', () async {
    final old = Completer<UnifiedPropertyResponse>();
    h.properties.response = (_) => old.future;
    h.state();
    await waitForQuery(() => h.properties.requests.isNotEmpty);
    h.scope.change('b');
    h.state();
    h.properties.response = (_) async => queryPage([3]);
    h.scope.change('a');
    await h.loaded();
    old.complete(queryPage([1]));
    await h.container.pump();
    expect(h.state().items.single.id, 3);
  });
  test('disposing pending debounce prevents another network request', () async {
    await h.loaded();
    await h.container.read(propertyFiltersProvider.notifier).search(PageType.explore, 'park');
    h.disposeProviders();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(h.properties.requests.length, 1);
  });
  group('SQLite cache behavior', () {
    Future<void> replaceProvider() async {
      h.container.invalidate(propertyQueryProvider(PropertyFeed.explore));
      await h.container.pump();
    }

    test('fresh cache appears while the server is revalidated', () async {
      await h.loaded();
      await replaceProvider();
      final pending = Completer<UnifiedPropertyResponse>();
      h.properties.response = (_) => pending.future;
      h.state();
      await waitForQuery(() => h.state().items.isNotEmpty);
      expect(h.state().isRefreshing, true);
      expect(h.state().stale, false);
      expect(h.state().items.single.id, 1);
      pending.complete(queryPage([2]));
      await h.loaded();
      expect(h.state().items.single.id, 2);
    });
    test('stale retained cache survives failed revalidation with visible failure', () async {
      await h.loaded();
      await h.raw.update('cache', {
        'fresh_until': DateTime.now().subtract(const Duration(minutes: 1)).millisecondsSinceEpoch,
      });
      await replaceProvider();
      h.properties.response = (_) async => throw NetworkException('offline');
      h.state();
      await waitForQuery(() => h.state().error != null);
      expect(h.state().items.single.id, 1);
      expect(h.state().stale, true);
      expect(h.state().showFullError, false);
    });
    test('a page marked no-store is shown, never stored, and the stored copy is deleted', () async {
      await h.loaded();
      expect(await h.raw.query('cache'), hasLength(1));
      h.properties.response = (_) async =>
          markCachePolicy(queryPage([2]), {'cache-control': 'private, no-store'});
      await h.query().load(refresh: true);
      expect(h.state().items.single.id, 2);
      expect(await h.raw.query('cache'), isEmpty);
    });
    test('a stored page holds no phone number', () async {
      h.properties.response = (_) async => UnifiedPropertyResponse(
        items: [
          PropertyModel.fromJson({...queryProperty(1).toJson(), 'owner_contact': '+911800000360'}),
        ],
        hasMore: false,
      );
      await h.loaded();
      final rows = await h.raw.query('cache');
      expect(rows, hasLength(1));
      expect(rows.single['value'] as String, isNot(contains('+911800000360')));
      expect(rows.single['value'] as String, isNot(contains('owner_contact')));
    });
    test('expired cache does not appear during a new request', () async {
      await h.loaded();
      await h.raw.update('cache', {'fresh_until': 0, 'expires_at': 1});
      await replaceProvider();
      final pending = Completer<UnifiedPropertyResponse>();
      h.properties.response = (_) => pending.future;
      h.state();
      await waitForQuery(() => h.properties.requests.length == 2);
      expect(h.state().items, isEmpty);
      pending.complete(queryPage([2]));
      await h.loaded();
    });
    test('corrupt JSON cache does not prevent a successful network response', () async {
      await h.loaded();
      await h.raw.update('cache', {'value': 'invalid json'});
      await replaceProvider();
      h.properties.response = (_) async => queryPage([3]);
      await h.loaded();
      expect(h.state().items.single.id, 3);
      expect(h.state().error, isNull);
    });
    test('a cache write failure preserves fresh rows and reports storage recovery', () async {
      await h.raw.execute(
        "CREATE TRIGGER reject_cache BEFORE INSERT ON cache BEGIN SELECT RAISE(ABORT, 'disk failure'); END",
      );
      await h.loaded();
      await waitForQuery(() => h.state().storageError != null);
      expect(h.state().items.single.id, 1);
      expect(h.state().error, isNull);
      await h.raw.execute('DROP TRIGGER reject_cache');
      await h.query().load(refresh: true);
      expect(h.state().storageError, isNull);
    });
    test('a missing cache table does not mask the network result', () async {
      await h.raw.execute('DROP TABLE cache');
      h.state();
      await waitForQuery(() => h.state().items.isNotEmpty && !h.state().busy);
      expect(h.state().items.single.id, 1);
      expect(h.state().error, isNull);
      expect(h.state().storageError, isNotNull);
    });
    test('Discover does not save or restore a stale deck', () async {
      await h.loaded(PropertyFeed.discover);
      expect(await h.raw.query('cache'), isEmpty);
      h.container.invalidate(propertyQueryProvider(PropertyFeed.discover));
      final pending = Completer<UnifiedPropertyResponse>();
      h.properties.response = (_) => pending.future;
      h.state(PropertyFeed.discover);
      await waitForQuery(() => h.properties.requests.length == 2);
      expect(h.state(PropertyFeed.discover).items, isEmpty);
      pending.complete(queryPage([2]));
      await h.loaded(PropertyFeed.discover);
    });
    test('cached snapshots are bounded without losing current visible rows', () async {
      h.properties.response = (_) async => queryPage(List.generate(250, (i) => i + 1), 'more');
      await h.loaded();
      expect(h.state().items.length, 250);
      expect(h.state().hasMore, true);
      final records = await h.raw.query('cache');
      final body = jsonDecode(records.single['value']! as String) as Map;
      expect((body['items'] as List).length, 200);
      expect(body['has_more'], false);
      expect(body['next_cursor'], isNull);
    });
    test('one account cannot hydrate another account feed cache', () async {
      await h.loaded();
      final pending = Completer<UnifiedPropertyResponse>();
      h.properties.response = (_) => pending.future;
      h.scope.change('b');
      expect(h.state().items, isEmpty);
      await waitForQuery(() => h.properties.requests.length == 2);
      expect(h.state().items, isEmpty);
      pending.complete(queryPage([2]));
      await h.loaded();
      expect((await h.raw.query('cache')).length, 2);
    });
    test('disposal prevents a pending response writing a feed snapshot', () async {
      final pending = Completer<UnifiedPropertyResponse>();
      h.properties.response = (_) => pending.future;
      h.state();
      await waitForQuery(() => h.properties.requests.isNotEmpty);
      h.disposeProviders();
      pending.complete(queryPage([99]));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(await h.raw.query('cache'), isEmpty);
    });
  });
}
