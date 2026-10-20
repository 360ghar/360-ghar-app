import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/unified_property_response.dart';
import 'package:ghar360/core/data/ports/swipes_port.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/discover/presentation/controllers/discover_controller.dart';
import 'package:ghar360/features/properties/application/property_filters.dart';
import 'package:ghar360/features/properties/application/property_queries.dart';
import 'package:ghar360/features/properties/application/swipe_history.dart';
import '../../../../helpers/property_query_test_support.dart';

void main() {
  late PropertyQueryHarness h;
  DiscoverController controller() => h.container.read(discoverProvider.notifier);
  DiscoverSession session() => h.container.read(discoverProvider);
  Future<void> deck(List<int> ids, [String? cursor]) async {
    h.properties.response = (_) async => queryPage(ids, cursor);
    await h.loaded(PropertyFeed.discover);
    h.container.read(swipeHistoryProvider);
    await waitForQuery(() => h.container.read(swipeHistoryProvider).hydrated);
  }

  setUp(() async {
    h = await PropertyQueryHarness.create();
  });
  tearDown(() async => h.close());

  test('session begins with zero likes passes and total', () {
    expect(session().likes, 0);
    expect(session().passes, 0);
    expect(session().total, 0);
    expect(h.properties.requests, isEmpty);
  });
  for (final liked in [true, false]) {
    test(
      '${liked ? 'Like' : 'Pass'} updates the shared ledger and removes only its card',
      () async {
        await deck([1, 2, 3, 4, 5]);
        if (liked) {
          await controller().swipeRight(queryProperty(1));
        } else {
          await controller().swipeLeft(queryProperty(1));
        }
        expect(controller().deck.map((p) => p.id), [2, 3, 4, 5]);
        expect(h.swipes.mutations, [(id: 1, liked: liked)]);
        expect(session().likes, liked ? 1 : 0);
        expect(session().passes, liked ? 0 : 1);
        expect(session().total, 1);
        expect(h.container.read(swipeHistoryProvider).entries[1]!.isLiked, liked);
      },
    );
    test('${liked ? 'Like' : 'Pass'} rejects an absent card and repeated gesture', () async {
      await deck([1, 2]);
      final c = controller();
      Future<void> act(int id) =>
          liked ? c.swipeRight(queryProperty(id)) : c.swipeLeft(queryProperty(id));
      await act(99);
      expect(h.swipes.mutations, isEmpty);
      await act(1);
      await act(1);
      expect(h.swipes.mutations.length, 1);
      expect(session().total, 1);
    });
    test(
      '${liked ? 'Like' : 'Pass'} failure restores the card and rolls back session count',
      () async {
        await deck([1, 2, 3]);
        final pending = Completer<SwipeOutcome>();
        h.swipes.mutation = (_, _) => pending.future;
        final task = liked
            ? controller().swipeRight(queryProperty(1))
            : controller().swipeLeft(queryProperty(1));
        expect(controller().deck.map((p) => p.id), [2, 3]);
        expect(session().total, 1);
        pending.completeError(ServerException('private failure'));
        await task;
        expect(controller().deck.map((p) => p.id), [1, 2, 3]);
        expect(session().total, 0);
        expect(h.container.read(swipeHistoryProvider).failures[1], isA<ServerException>());
      },
    );
  }
  test('different cards can finish out of order without losing counts or failure', () async {
    await deck([1, 2, 3]);
    final first = Completer<SwipeOutcome>();
    h.swipes.mutation = (id, _) => id == 1 ? first.future : Future.value(const ConfirmedSwipe());
    final slow = controller().swipeRight(queryProperty(1));
    await controller().swipeLeft(queryProperty(2));
    first.completeError(ServerException('not saved'));
    await slow;
    expect(session().likes, 0);
    expect(session().passes, 1);
    expect(controller().deck.map((p) => p.id), [1, 3]);
    expect(h.container.read(swipeHistoryProvider).failures.keys, [1]);
  });
  test('last swipe empties the deck when pagination is exhausted', () async {
    await deck([1]);
    await controller().swipeRight(queryProperty(1));
    expect(controller().deck, isEmpty);
    expect(h.properties.requests.length, 1);
  });
  for (final count in [1, 4]) {
    test('$count remaining cards prefetch exactly one next page', () async {
      await deck(List.generate(count, (i) => i + 1), 'next');
      final more = Completer<UnifiedPropertyResponse>();
      h.properties.response = (_) => more.future;
      await controller().swipeRight(queryProperty(1));
      await waitForQuery(() => h.properties.requests.length == 2);
      expect(h.properties.requests.last.cursor, 'next');
      expect(h.state(PropertyFeed.discover).isLoadingMore, isTrue);
      more.complete(queryPage([99]));
      await waitForQuery(() => !h.state(PropertyFeed.discover).busy);
      expect(controller().deck.map((p) => p.id), [...List.generate(count - 1, (i) => i + 2), 99]);
    });
  }
  test('prefetch failure retains the next cursor and exposes a retryable error', () async {
    await deck([1, 2], 'next');
    h.properties.response = (_) async => throw NetworkException('offline');
    await controller().swipeRight(queryProperty(1));
    await waitForQuery(() => h.state(PropertyFeed.discover).paginationError != null);
    final page = h.state(PropertyFeed.discover);
    expect(page.nextCursor, 'next');
    expect(page.busy, isFalse);
    expect(controller().deck.map((p) => p.id), [2]);
    h.properties.response = (_) async => queryPage([3]);
    await h.query(PropertyFeed.discover).loadMore(retry: true);
    expect(controller().deck.map((p) => p.id), [2, 3]);
  });
  test('refresh resets session stats but does not restore already swiped cards', () async {
    await deck([1, 2]);
    await controller().swipeRight(queryProperty(1));
    await controller().refreshDeck();
    expect(session().total, 0);
    expect(controller().deck.map((p) => p.id), [2]);
    expect(h.properties.requests.last.excludeSwiped, isTrue);
    expect(h.properties.requests.last.useCache, isFalse);
  });
  test('refresh failure retains visible cards and retry recovers', () async {
    await deck([1, 2]);
    h.properties.response = (_) async => throw NetworkException('offline');
    await controller().refreshDeck();
    expect(controller().deck.length, 2);
    expect(h.state(PropertyFeed.discover).stale, isTrue);
    h.properties.response = (_) async => queryPage([3]);
    await controller().retryLoading();
    expect(controller().deck.map((p) => p.id), [3]);
    expect(h.state(PropertyFeed.discover).error, isNull);
  });
  test('initial request failure is explicit and retry loads content', () async {
    h.properties.response = (_) async => throw ServerException('failed');
    controller().deck;
    await waitForQuery(() => h.state(PropertyFeed.discover).error != null);
    expect(h.state(PropertyFeed.discover).phase, PropertyLoadPhase.failure);
    h.properties.response = (_) async => queryPage([1]);
    await controller().retryLoading();
    expect(controller().deck.length, 1);
  });
  for (final purpose in ['buy', 'rent', 'short_stay']) {
    test('purpose shortcut $purpose updates all shared page filters', () async {
      await controller().filterByPurpose(purpose);
      for (final page in PageType.values) {
        expect(h.container.read(propertyFiltersProvider).forPage(page).purpose, purpose);
      }
    });
  }
  for (final type in ['apartment', 'villa', 'plot', 'pg']) {
    test('property type shortcut $type uses canonical shared filters', () async {
      await controller().filterByPropertyType(type);
      expect(h.container.read(propertyFiltersProvider).forPage(PageType.discover).propertyType, [
        type,
      ]);
    });
  }
  test('account transition clears counts and rejects old mutation result', () async {
    await deck([1, 2]);
    final request = Completer<SwipeOutcome>();
    h.swipes.mutation = (_, _) => request.future;
    final old = controller().swipeRight(queryProperty(1));
    await waitForQuery(() => h.swipes.mutations.isNotEmpty);
    h.scope.change('b');
    expect(session().total, 0);
    request.completeError(NetworkException('old'));
    await old;
    expect(session().total, 0);
    expect(h.container.read(swipeHistoryProvider).failures, isEmpty);
  });
  test('provider disposal rejects a pending mutation completion', () async {
    await deck([1]);
    final request = Completer<SwipeOutcome>();
    h.swipes.mutation = (_, _) => request.future;
    final old = controller().swipeRight(queryProperty(1));
    await waitForQuery(() => h.swipes.mutations.isNotEmpty);
    h.disposeProviders();
    request.complete(const ConfirmedSwipe());
    await old;
  });
}
