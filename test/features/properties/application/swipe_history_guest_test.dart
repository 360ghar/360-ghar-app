import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/controllers/offline_queue_service.dart';
import 'package:ghar360/features/properties/application/property_queries.dart';
import 'package:ghar360/features/properties/application/swipe_history.dart';
import '../../../helpers/property_query_test_support.dart';

void main() {
  late PropertyQueryHarness h;
  SwipeHistory history() => h.container.read(swipeHistoryProvider.notifier);
  SwipeHistoryState state() => h.container.read(swipeHistoryProvider);
  List<int> visible() =>
      h.container.read(visiblePropertiesProvider(PropertyFeed.discover)).map((p) => p.id).toList();
  Future<void> hydrate() async {
    state();
    await waitForQuery(() => state().hydrated);
  }

  setUp(() async {
    h = await PropertyQueryHarness.create();
    h.scope.change(null);
    await hydrate();
  });
  tearDown(() async => h.close());

  test('a guest like returns false and changes nothing', () async {
    await h.loaded(PropertyFeed.discover);
    expect(await history().record(queryProperty(1), true), false);
    expect(state().entries, isEmpty);
    expect(state().excluded, isEmpty);
    expect(visible(), [1]);
    expect(h.swipes.mutations, isEmpty);
  });

  test('a guest pass hides the card in memory and never reaches the network or queue', () async {
    await h.loaded(PropertyFeed.discover);
    expect(await history().record(queryProperty(1), false), true);
    expect(state().excluded, {1});
    expect(state().entries[1]!.phase, SwipePhase.confirmed);
    expect(visible(), isEmpty);
    expect(h.swipes.mutations, isEmpty);
    expect(h.swipes.requests, isEmpty);
    expect(await h.container.read(offlineQueueServiceProvider).list(), isEmpty);
  });

  test('undo of a guest pass brings the card back, still offline', () async {
    await h.loaded(PropertyFeed.discover);
    await history().record(queryProperty(1), false);
    expect(await history().undo(1), true);
    expect(visible(), [1]);
    expect(h.swipes.mutations, isEmpty);
  });

  test('a signed-in like still reaches the repository', () async {
    h.scope.change('a');
    await hydrate();
    expect(await history().record(queryProperty(1), true), true);
    expect(h.swipes.mutations, [(id: 1, liked: true)]);
  });
}
