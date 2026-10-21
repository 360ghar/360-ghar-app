import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/controllers/offline_queue_service.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/data/ports/swipes_port.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/properties/application/property_filters.dart';
import 'package:ghar360/features/properties/application/property_queries.dart';
import 'package:ghar360/features/properties/application/swipe_history.dart';
import '../../../helpers/property_query_test_support.dart';

void main() {
  late PropertyQueryHarness h;
  late OfflineQueueService queue;
  SwipeHistory history() => h.container.read(swipeHistoryProvider.notifier);
  SwipeHistoryState state() => h.container.read(swipeHistoryProvider);
  List<int> visible(PropertyFeed feed) =>
      h.container.read(visiblePropertiesProvider(feed)).map((property) => property.id).toList();
  Future<void> hydrate() async {
    state();
    await waitForQuery(() => state().hydrated);
  }

  Future<PendingAction> pending({int id = 1, bool liked = true}) async {
    h.swipes.mutation = (id, liked) async => PendingSwipe(
      await queue.enqueueSwipe(
        propertyId: id,
        isLiked: liked,
        scope: h.container.read(storageScopeProvider),
      ),
    );
    expect(await history().record(queryProperty(id), liked), true);
    return (await queue.list()).last;
  }

  Future<void> confirm(PendingAction action) => queue.update(
    action,
    scope: h.container.read(storageScopeProvider),
    status: PendingActionStatus.confirmed,
  );

  setUp(() async {
    h = await PropertyQueryHarness.create();
    queue = h.container.read(offlineQueueServiceProvider);
    await hydrate();
  });
  tearDown(() async => h.close());

  for (final change in ['purpose', 'location']) {
    test('restored Discover card does not cross $change inputs', () async {
      await h.loaded(PropertyFeed.discover);
      await history().record(queryProperty(1), true);
      h.properties.response = (_) async => queryPage([]);
      await h.query(PropertyFeed.discover).load(refresh: true);
      expect(await history().undo(1), true);
      expect(visible(PropertyFeed.discover), [1]);
      if (change == 'purpose') {
        final filters = h.container.read(propertyFiltersProvider).forPage(PageType.discover);
        await h.container
            .read(propertyFiltersProvider.notifier)
            .update(PageType.discover, filters.copyWith(purpose: 'rent'));
      } else {
        h
            .location(PageType.discover)
            .replace(const LocationData(name: 'Mumbai', latitude: 19, longitude: 72));
      }
      expect(visible(PropertyFeed.discover), isEmpty);
      expect(state().entries[1]!.restored, true);
      await h.loaded(PropertyFeed.discover);
      expect(visible(PropertyFeed.discover), isEmpty);
    });
  }

  for (final change in ['search', 'price', 'type', 'location']) {
    test('Saved optimistic membership requires unchanged $change inputs', () async {
      await h.loaded(PropertyFeed.explore);
      h.swipes.response = (_, _) async => queryPage([]);
      await h.loaded(PropertyFeed.liked);
      await pending();
      expect(visible(PropertyFeed.liked), [1]);
      final filters = h.container.read(propertyFiltersProvider).forPage(PageType.likes);
      switch (change) {
        case 'search':
          await h.container.read(propertyFiltersProvider.notifier).search(PageType.likes, 'other');
        case 'price':
          await h.container
              .read(propertyFiltersProvider.notifier)
              .update(PageType.likes, filters.copyWith(priceMin: 99999999));
        case 'type':
          await h.container
              .read(propertyFiltersProvider.notifier)
              .update(PageType.likes, filters.copyWith(propertyType: ['villa']));
        case 'location':
          h
              .location(PageType.likes)
              .replace(const LocationData(name: 'Mumbai', latitude: 19, longitude: 72));
      }
      expect(visible(PropertyFeed.liked), isEmpty);
      expect(state().excluded, contains(1));
      expect(state().entries[1]!.phase, SwipePhase.pending);
      await h.loaded(PropertyFeed.liked);
      expect(visible(PropertyFeed.liked), isEmpty);
    });
  }

  test('unknown membership waits for authoritative history and does not fabricate a row', () async {
    h.swipes.response = (_, _) async => queryPage([]);
    await h.loaded(PropertyFeed.liked);
    await pending(id: 99);
    expect(visible(PropertyFeed.liked), isEmpty);
    h.swipes.response = (_, _) async => queryPage([99]);
    await h.query(PropertyFeed.liked).load(refresh: true);
    expect(visible(PropertyFeed.liked), [99]);
  });

  test('latest local intent removes stale server membership after query changes', () async {
    await h.loaded(PropertyFeed.liked);
    await pending(liked: false);
    await h.container.read(propertyFiltersProvider.notifier).search(PageType.likes, 'new');
    await h.loaded(PropertyFeed.liked);
    expect(h.state(PropertyFeed.liked).items.map((p) => p.id), [1]);
    expect(visible(PropertyFeed.liked), isEmpty);
  });

  test('confirmed record revalidates only existing history feeds', () async {
    await history().record(queryProperty(1), true);
    expect(h.swipes.requests, isEmpty);
    expect(h.container.exists(propertyQueryProvider(PropertyFeed.liked)), false);
    await h.loaded(PropertyFeed.liked);
    final count = h.swipes.requests.length;
    await history().record(queryProperty(1), false);
    await waitForQuery(() => h.swipes.requests.length > count);
    expect(h.swipes.requests.last.liked, true);
    expect(h.container.exists(propertyQueryProvider(PropertyFeed.passed)), false);
  });

  test('query identities survive hydration without entering new Saved search', () async {
    await h.loaded(PropertyFeed.explore);
    await pending();
    h.container.invalidate(swipeHistoryProvider);
    await hydrate();
    h.swipes.response = (_, _) async => queryPage([]);
    await h.loaded(PropertyFeed.liked);
    expect(visible(PropertyFeed.liked), [1]);
    await h.container.read(propertyFiltersProvider.notifier).search(PageType.likes, 'different');
    expect(visible(PropertyFeed.liked), isEmpty);
  });

  test('retry coalesces duplicate taps and confirms the existing operation', () async {
    final action = await pending();
    final completion = Completer<SwipeOutcome>();
    h.swipes.retryResponse = (_) => completion.future;
    final first = history().retryPending(action);
    final second = history().retryPending(action);
    expect(identical(first, second), true);
    expect(state().pendingOperations[action.operationId]!.isLoading, true);
    await waitForQuery(() => h.swipes.retryRequests.length == 1);
    expect(await history().discardPending(action), false);
    await confirm(action);
    completion.complete(ConfirmedSwipe(operationId: action.operationId));
    expect(await first, true);
    expect(state().pendingOperations[action.operationId]!.requireValue, true);
    expect(state().entries[1]!.phase, SwipePhase.confirmed);
    expect(state().entries[1]!.operationId, action.operationId);
    expect(state().excluded, contains(1));
  });

  test('retry of a pending undo preserves its restored Discover card', () async {
    await h.loaded(PropertyFeed.discover);
    await pending();
    expect(await history().undo(1), true);
    final action = (await queue.list()).last;
    h.swipes.retryResponse = (action) async {
      await confirm(action);
      return ConfirmedSwipe(operationId: action.operationId);
    };
    expect(await history().retryPending(action), true);
    expect(state().entries[1]!.restored, true);
    expect(state().excluded, isNot(contains(1)));
    expect(visible(PropertyFeed.discover), [1]);
  });

  test('failed latest intent can retry after the UI rolled back to an older summary', () async {
    await pending(liked: false);
    h.swipes.mutation = (id, liked) async {
      final action = await queue.enqueueSwipe(
        propertyId: id,
        isLiked: liked,
        scope: h.container.read(storageScopeProvider),
      );
      await queue.update(
        action,
        scope: h.container.read(storageScopeProvider),
        status: PendingActionStatus.failed,
        failureCode: 'REJECTED',
      );
      throw ServerException('Failed', code: 'REJECTED');
    };
    expect(await history().record(queryProperty(1), true), false);
    expect(state().entries[1]!.isLiked, false);
    final latest = (await queue.list()).last;
    h.swipes.retryResponse = (action) async {
      await confirm(action);
      return ConfirmedSwipe(operationId: action.operationId);
    };
    expect(await history().retryPending(latest), true);
    expect(state().entries[1]!.isLiked, true);
    expect(state().entries[1]!.operationId, latest.operationId);
    expect(state().failures, isEmpty);
  });

  test('unresolved retry retains intent with an explicit operation error', () async {
    final action = await pending();
    h.swipes.retryResponse = (_) async => PendingSwipe(action);
    expect(await history().retryPending(action), false);
    expect(
      state().pendingOperations[action.operationId]!.error,
      isA<NetworkException>().having((error) => error.code, 'code', 'SWIPE_UNRESOLVED'),
    );
    expect(state().entries[1]!.phase, SwipePhase.pending);
    expect((await queue.list()).single.operationId, action.operationId);
  });

  test('retry rejects superseded action without replaying its POST', () async {
    final old = await pending();
    final latest = await pending(liked: false);
    expect(await history().retryPending(old), false);
    expect(h.swipes.retryRequests, isEmpty);
    expect(state().entries[1]!.operationId, latest.operationId);
    expect(state().entries[1]!.isLiked, false);
  });

  test('new intent waits for an active retry and cannot be overwritten by its result', () async {
    final action = await pending();
    final completion = Completer<SwipeOutcome>();
    h.swipes.retryResponse = (_) => completion.future;
    final retry = history().retryPending(action);
    await waitForQuery(() => h.swipes.retryRequests.isNotEmpty);
    final newer = history().record(queryProperty(1), false);
    expect(h.swipes.mutations.length, 1);
    expect(state().entries[1]!.isLiked, false);
    await confirm(action);
    completion.complete(ConfirmedSwipe(operationId: action.operationId));
    expect(await retry, true);
    expect(await newer, true);
    expect(state().entries[1]!.isLiked, false);
    expect(state().entries[1]!.phase, SwipePhase.pending);
    expect(state().entries[1]!.operationId, isNot(action.operationId));
  });

  test('action can recover after crash before its property summary was saved', () async {
    final action = await queue.enqueueSwipe(
      propertyId: 42,
      isLiked: true,
      scope: h.container.read(storageScopeProvider),
    );
    h.swipes.retryResponse = (action) async {
      await confirm(action);
      return ConfirmedSwipe(operationId: action.operationId);
    };
    expect(await history().retryPending(action), true);
    expect(state().excluded, contains(42));
    expect(state().entries, isEmpty);
  });

  test('discard keeps unresolved exclusion and survives provider reconstruction', () async {
    final action = await pending();
    expect(await history().discardPending(action), true);
    expect(await queue.list(), isEmpty);
    expect(h.swipes.retryRequests, isEmpty);
    expect(state().entries[1]!.phase, SwipePhase.unresolved);
    h.container.invalidate(swipeHistoryProvider);
    await hydrate();
    expect(state().entries[1]!.phase, SwipePhase.unresolved);
    expect(state().excluded, contains(1));
    await h.loaded(PropertyFeed.discover);
    expect(visible(PropertyFeed.discover), isEmpty);
  });

  test('discarded unresolved exclusion survives recent-history bounds', () async {
    final action = await pending();
    expect(await history().discardPending(action), true);
    final scope = h.container.read(storageScopeProvider);
    final snapshot = (await h.database.readDraft(scope: scope, key: 'swipe_history_v1'))!;
    // Simulate enough later cards to evict the first ID from recent history.
    await h.database.writeDraft(
      scope: scope,
      key: 'swipe_history_v1',
      value: {
        ...snapshot,
        'excluded': [1, ...List.generate(2100, (i) => i + 2)],
        'entries': <Object?>[],
      },
    );
    h.container.invalidate(swipeHistoryProvider);
    await hydrate();
    await history().retrySave();
    h.container.invalidate(swipeHistoryProvider);
    await hydrate();
    expect(state().entries, isEmpty);
    expect(state().excluded, contains(1));
    expect(
      (await h.database.readDraft(scope: scope, key: 'swipe_history_v1'))!['excluded'],
      hasLength(2000),
    );
  });

  test('duplicate discard is rejected while the first local write runs', () async {
    final action = await pending();
    final first = history().discardPending(action);
    expect(await history().discardPending(action), false);
    expect(await first, true);
    expect(await queue.list(), isEmpty);
  });

  for (final failAt in ['draft', 'delete']) {
    test('$failAt storage failure keeps the action available to retry', () async {
      final action = await pending();
      await h.raw.execute(
        failAt == 'draft'
            ? "CREATE TRIGGER fail_discard BEFORE INSERT ON drafts BEGIN SELECT RAISE(ABORT,'disk full'); END"
            : "CREATE TRIGGER fail_discard BEFORE DELETE ON actions BEGIN SELECT RAISE(ABORT,'disk full'); END",
      );
      expect(await history().discardPending(action), false);
      expect(state().pendingOperations[action.operationId]!.hasError, true);
      expect(state().entries[1]!.phase, SwipePhase.pending);
      expect(state().entries[1]!.operationId, action.operationId);
      expect((await queue.list()).single.operationId, action.operationId);
      await h.raw.execute('DROP TRIGGER fail_discard');
      h.swipes.retryResponse = (action) async {
        await confirm(action);
        return ConfirmedSwipe(operationId: action.operationId);
      };
      expect(await history().retryPending(action), true);
    });
  }

  test('discarding superseded action preserves a newer restored card', () async {
    await h.loaded(PropertyFeed.discover);
    final old = await pending();
    expect(await history().undo(1), true);
    expect(state().entries[1]!.restored, true);
    expect(visible(PropertyFeed.discover), [1]);
    expect(await history().discardPending(old), true);
    expect(state().excluded, isNot(contains(1)));
    expect(visible(PropertyFeed.discover), [1]);
  });

  for (final operation in ['retry', 'discard']) {
    test('$operation rejects a request from a different account', () async {
      final action = await pending();
      h.scope.change('b');
      await hydrate();
      final success = operation == 'retry'
          ? await history().retryPending(action)
          : await history().discardPending(action);
      expect(success, false);
      expect(state().entries, isEmpty);
      expect(state().excluded, isEmpty);
      expect(h.swipes.retryRequests, isEmpty);
      expect(await queue.list(), isEmpty);
    });
  }

  test('A to B to A discards an earlier account generation retry result', () async {
    final action = await pending();
    final completion = Completer<SwipeOutcome>();
    h.swipes.retryResponse = (_) => completion.future;
    final result = history().retryPending(action);
    await waitForQuery(() => h.swipes.retryRequests.isNotEmpty);
    h.scope.change('b');
    await hydrate();
    expect(state().entries, isEmpty);
    h.scope.change('a');
    await hydrate();
    expect(state().entries[1]!.phase, SwipePhase.pending);
    completion.complete(ConfirmedSwipe(operationId: action.operationId));
    expect(await result, false);
    expect(state().entries[1]!.phase, SwipePhase.pending);
    expect(state().pendingOperations, isEmpty);
  });

  test('durable confirmed receipt repairs stale pending summary on hydration', () async {
    final action = await pending();
    await confirm(action);
    h.container.invalidate(swipeHistoryProvider);
    await hydrate();
    expect(state().entries[1]!.phase, SwipePhase.confirmed);
    expect(await history().retryPending(action), false);
    expect(h.swipes.retryRequests, isEmpty);
  });
}
