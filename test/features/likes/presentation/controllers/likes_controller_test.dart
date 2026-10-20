import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/data/models/likes_segment.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/data/ports/swipes_port.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/likes/presentation/controllers/likes_controller.dart';
import 'package:ghar360/features/properties/application/property_filters.dart';
import 'package:ghar360/features/properties/application/property_queries.dart';
import 'package:ghar360/features/properties/application/swipe_history.dart';
import '../../../../helpers/property_query_test_support.dart';

void main() {
  late PropertyQueryHarness h;
  LikesController c() => h.container.read(likesProvider.notifier);
  List<int> rows(PropertyFeed feed) =>
      h.container.read(visiblePropertiesProvider(feed)).map((p) => p.id).toList();
  Future<void> hydrate() async {
    h.container.read(swipeHistoryProvider);
    await waitForQuery(() => h.container.read(swipeHistoryProvider).hydrated);
  }

  setUp(() async {
    h = await PropertyQueryHarness.create();
    await hydrate();
  });
  tearDown(() async => h.close());
  test('default liked segment composes without fetching a hidden page', () {
    expect(h.container.read(likesProvider), LikesSegment.liked);
    expect(c().feed, PropertyFeed.liked);
    expect(h.swipes.requests, isEmpty);
  });
  for (final segment in LikesSegment.values) {
    test('switching to ${segment.name} selects exactly its query and retains same selection', () {
      c().switchToSegment(segment);
      c().switchToSegment(segment);
      expect(h.container.read(likesProvider), segment);
      expect(c().feed, segment == LikesSegment.liked ? PropertyFeed.liked : PropertyFeed.passed);
    });
    test('${segment.name} refresh and retry address the selected endpoint', () async {
      c().switchToSegment(segment);
      await h.loaded(c().feed);
      await c().refreshCurrentSegment();
      await c().retryCurrentSegment();
      expect(h.swipes.requests.length, 3);
      expect(h.swipes.requests.every((r) => r.liked == (segment == LikesSegment.liked)), isTrue);
      expect(h.swipes.requests.every((r) => r.cursor == null), isTrue);
    });
    test('${segment.name} pagination preserves rows and sends the next cursor', () async {
      c().switchToSegment(segment);
      h.swipes.response = (cursor, _) async =>
          cursor == null ? queryPage([1], 'more') : queryPage([1, 2]);
      await h.loaded(c().feed);
      await c().loadMoreCurrentSegment();
      expect(h.swipes.requests.last.cursor, 'more');
      expect(rows(c().feed), [1, 2]);
    });
    test('${segment.name} refresh failure retains rows and retry clears only load error', () async {
      c().switchToSegment(segment);
      await h.loaded(c().feed);
      h.swipes.response = (_, _) async => throw NetworkException('offline');
      await c().refreshCurrentSegment();
      expect(rows(c().feed), [1]);
      expect(h.state(c().feed).error, isA<NetworkException>());
      expect(h.state(c().feed).stale, isTrue);
      h.swipes.response = (_, _) async => queryPage([2]);
      await c().retryCurrentSegment();
      expect(rows(c().feed), [2]);
      expect(h.state(c().feed).error, isNull);
    });
  }
  test('search and clear use shared page state and preserve another page search', () async {
    await h.container.read(propertyFiltersProvider.notifier).search(PageType.explore, 'Delhi');
    await c().updateSearchQuery('villa');
    expect(h.container.read(propertyFiltersProvider).forPage(PageType.likes).searchQuery, 'villa');
    await c().clearSearch();
    expect(h.container.read(propertyFiltersProvider).forPage(PageType.likes).searchQuery, '');
    expect(
      h.container.read(propertyFiltersProvider).forPage(PageType.explore).searchQuery,
      'Delhi',
    );
  });
  test('search write failure keeps the query and exposes a retryable persistence failure', () async {
    await h.raw.execute(
      "CREATE TRIGGER fail_pref BEFORE INSERT ON preferences BEGIN SELECT RAISE(FAIL,'full'); END",
    );
    expect(await c().updateSearchQuery('home'), isFalse);
    expect(h.container.read(propertyFiltersProvider).forPage(PageType.likes).searchQuery, 'home');
    expect(h.container.read(propertyFiltersProvider).save.hasError, isTrue);
  });
  test('favourite reads the model before any tab is loaded', () {
    final liked = PropertyModel.fromJson({...queryProperty(1).toJson(), 'liked': true});
    expect(c().isFavourite(liked), isTrue);
    expect(c().isFavourite(queryProperty(2)), isFalse);
  });
  for (final liked in [true, false]) {
    for (final fails in [true, false]) {
      test(
        '${liked ? 'add' : 'remove'} ${fails ? 'failure rolls back' : 'success keeps'} latest favourite state',
        () async {
          final p = PropertyModel.fromJson({...queryProperty(1).toJson(), 'liked': !liked});
          final request = Completer<SwipeOutcome>();
          h.swipes.mutation = (_, _) => request.future;
          final task = liked ? c().addToFavourites(p) : c().removeFromFavourites(p);
          expect(c().isFavourite(p), liked);
          expect(c().isFavouriteUpdating(p), isTrue);
          await waitForQuery(() => h.swipes.mutations.isNotEmpty);
          if (fails) {
            request.completeError(ServerException('private'));
          } else {
            request.complete(const ConfirmedSwipe());
          }
          expect(await task, !fails);
          expect(c().isFavouriteUpdating(p), isFalse);
          expect(c().isFavourite(p), fails ? !liked : liked);
          expect(h.container.read(swipeHistoryProvider).failures.containsKey(1), fails);
          expect(h.swipes.mutations, [(id: 1, liked: liked)]);
        },
      );
    }
  }
  test('a second tap while the same property is submitting sends no duplicate request', () async {
    final request = Completer<SwipeOutcome>();
    h.swipes.mutation = (_, _) => request.future;
    final first = c().addToFavourites(queryProperty(1));
    expect(await c().removeFromFavourites(queryProperty(1)), isFalse);
    await waitForQuery(() => h.swipes.mutations.isNotEmpty);
    expect(h.swipes.mutations.length, 1);
    request.complete(const ConfirmedSwipe());
    await first;
  });
  test('moveToLikes and removeFromLikes share the same authoritative mutation state', () async {
    final p = queryProperty(1);
    await c().moveToLikes(p);
    expect(c().isFavourite(p), isTrue);
    await c().removeFromLikes(p);
    expect(c().isFavourite(p), isFalse);
    expect(h.swipes.mutations, [(id: 1, liked: true), (id: 1, liked: false)]);
  });
  test('failed remove keeps original liked row and failed move keeps passed row', () async {
    await h.loaded(PropertyFeed.liked);
    await h.loaded(PropertyFeed.passed);
    h.swipes.mutation = (_, _) async => throw ServerException('no');
    expect(await c().removeFromLikes(queryProperty(1)), isFalse);
    expect(rows(PropertyFeed.liked), [1]);
    expect(await c().moveToLikes(queryProperty(1)), isFalse);
    expect(rows(PropertyFeed.passed), [1]);
  });
  test('server lists cannot override a newer local favourite intent', () async {
    await h.loaded(PropertyFeed.liked);
    await c().removeFromLikes(queryProperty(1));
    await h.query(PropertyFeed.liked).load(refresh: true);
    expect(rows(PropertyFeed.liked), isEmpty);
    expect(c().isFavourite(queryProperty(1)), isFalse);
  });
  test('account changes clear segment and optimistic state before old work completes', () async {
    c().switchToSegment(LikesSegment.passed);
    final request = Completer<SwipeOutcome>();
    h.swipes.mutation = (_, _) => request.future;
    final old = c().moveToLikes(queryProperty(1));
    await waitForQuery(() => h.swipes.mutations.isNotEmpty);
    h.scope.change('b');
    expect(h.container.read(likesProvider), LikesSegment.liked);
    expect(c().isFavourite(queryProperty(1)), isFalse);
    request.complete(const ConfirmedSwipe());
    expect(await old, isFalse);
    expect(c().isFavourite(queryProperty(1)), isFalse);
  });
  test('imports valid legacy passed segment without a global registration', () async {
    await h.close();
    h = await PropertyQueryHarness.create(
      legacy: {
        'likes_state': {
          'additionalData': {'currentSegment': 'passed'},
        },
      },
    );
    expect(h.container.read(likesProvider), LikesSegment.passed);
  });
}
