import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/data/models/likes_segment.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/widgets/common/property_list_card.dart';
import 'package:ghar360/core/widgets/paper/paper_vignette.dart';
import 'package:ghar360/core/widgets/paper/scene_header_sliver.dart';
import 'package:ghar360/features/likes/presentation/controllers/likes_controller.dart';
import 'package:ghar360/features/likes/presentation/views/likes_view.dart';
import 'package:ghar360/features/properties/application/property_queries.dart';
import 'package:ghar360/features/properties/application/swipe_history.dart';
import '../../../../helpers/property_query_test_support.dart';
import '../../../../helpers/property_screen_harness.dart';

void main() {
  Future<PropertyScreenHarness> setup(
    WidgetTester tester, {
    PropertyPageState? liked,
    PropertyPageState? passed,
    Size size = const Size(390, 844),
    double scale = 1,
    bool dark = false,
    Locale locale = const Locale('en', 'US'),
  }) async {
    final data = (await tester.runAsync(PropertyQueryHarness.create))!;
    final h = PropertyScreenHarness(
      data,
      pages: {PropertyFeed.liked: ?liked, PropertyFeed.passed: ?passed},
    );
    await h.pump(tester, const LikesView(), size: size, scale: scale, dark: dark, locale: locale);
    return h;
  }

  PropertyPageState content([List<int> ids = const [1, 2]]) =>
      PropertyPageState(phase: PropertyLoadPhase.content, items: ids.map(queryProperty).toList());
  testWidgets('Saved exposes Liked Passed and always-visible search', (tester) async {
    final h = await setup(tester);
    expect(find.text('Liked'), findsWidgets);
    expect(find.text('Passed'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('No Liked Properties'), findsOneWidget);
    await tester.tap(find.text('Passed'));
    await tester.pump();
    expect(h.container.read(likesProvider), LikesSegment.passed);
    expect(find.text('No Passed Properties'), findsOneWidget);
    await h.close(tester);
  });
  for (final phase in [PropertyLoadPhase.idle, PropertyLoadPhase.loading]) {
    testWidgets('$phase shows skeleton before an empty result', (tester) async {
      final h = await setup(tester, liked: PropertyPageState(phase: phase));
      expect(find.text('No Liked Properties'), findsNothing);
      expect(find.byType(PropertyListCard), findsNothing);
      expect(tester.takeException(), isNull);
      await h.close(tester);
    });
  }
  testWidgets('initial failure shows safe retry and never an empty success', (tester) async {
    final h = await setup(
      tester,
      liked: PropertyPageState(
        phase: PropertyLoadPhase.failure,
        error: NetworkException('secret-diagnostic'),
      ),
    );
    expect(find.text('No Liked Properties'), findsNothing);
    expect(find.textContaining('secret-diagnostic'), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(h.query(PropertyFeed.liked).loads, 1);
    await h.close(tester);
  });
  testWidgets('content renders both properties and switches segments without losing rows', (
    tester,
  ) async {
    final h = await setup(tester, liked: content(), passed: content([3]));
    expect(find.byType(PropertyListCard), findsNWidgets(2));
    // The open tab counts its rows; a tab not opened yet has no number.
    expect(find.text('Liked 2'), findsOneWidget);
    expect(find.text('Passed'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('qa.likes.tab.passed')));
    await tester.pump();
    expect(find.text('Property 3'), findsOneWidget);
    expect(find.text('Passed 1'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('qa.likes.tab.liked')));
    await tester.pump();
    expect(find.text('Property 1'), findsOneWidget);
    expect(find.text('Property 2'), findsOneWidget);
    expect(find.text('Liked 2'), findsOneWidget);
    await h.close(tester);
  });
  testWidgets('the facade lights one window per liked home', (tester) async {
    final h = await setup(tester, liked: content([1, 2, 3]));
    final header = tester.widget<SceneHeaderSliver>(find.byType(SceneHeaderSliver));
    expect(header.scene.litCount, 3);
    expect(find.bySemanticsIdentifier('qa.likes.title'), findsOneWidget);
    await h.close(tester);
  });
  testWidgets('favorite toggle sends the current property and keeps tap state safe', (
    tester,
  ) async {
    final h = await setup(tester, liked: content([1]));
    final card = tester.widget<PropertyListCard>(find.byType(PropertyListCard));
    card.onFavouriteToggle();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
    expect(h.data.swipes.mutations, [(id: 1, liked: true)]);
    await h.close(tester);
  });
  testWidgets('property card routes to the numeric details URL', (tester) async {
    final h = await setup(tester, liked: content([1]));
    await tester.tap(find.text('Property 1'));
    await tester.pumpAndSettle();
    expect(find.text('Details 1'), findsOneWidget);
    await h.close(tester);
  });
  for (final pagination in [true, false]) {
    testWidgets(
      '${pagination ? 'pagination' : 'refresh'} error retains rows and retries in place',
      (tester) async {
        final h = await setup(
          tester,
          liked: content().copyWith(
            error: pagination ? null : NetworkException('offline'),
            paginationError: pagination ? NetworkException('offline') : null,
          ),
        );
        expect(find.byType(PropertyListCard), findsNWidgets(2));
        final before = h.query(PropertyFeed.liked).more;
        await tester.tap(find.byKey(const ValueKey('qa.likes.content.retry')));
        await tester.pump();
        expect(
          pagination ? h.query(PropertyFeed.liked).retried : h.query(PropertyFeed.liked).refreshed,
          isTrue,
        );
        expect(
          pagination
              ? h.query(PropertyFeed.liked).more - before
              : h.query(PropertyFeed.liked).loads,
          1,
        );
        await h.close(tester);
      },
    );
  }
  testWidgets('cached stale content is labeled while it refreshes', (tester) async {
    final h = await setup(
      tester,
      liked: content().copyWith(stale: true, phase: PropertyLoadPhase.refreshing),
    );
    expect(find.textContaining('Showing saved properties'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byType(PropertyListCard), findsNWidgets(2));
    await h.close(tester);
  });
  testWidgets('mutation failure uses the shared notification and retains content', (tester) async {
    final h = await setup(tester, liked: content());
    h.history.emit(
      SwipeHistoryState(hydrated: true, failures: {1: ServerException('raw-response')}),
    );
    await tester.pump();
    expect(find.textContaining('raw-response'), findsNothing);
    expect(find.byType(PropertyListCard), findsNWidgets(2));
    expect(find.text('Action Failed'), findsOneWidget);
    await h.close(tester);
  });
  testWidgets('empty search offers clear and preserves the active segment', (tester) async {
    final h = await setup(tester);
    await tester.enterText(find.byType(TextField), 'villa');
    await tester.pump();
    expect(find.textContaining('villa'), findsWidgets);
    expect(h.container.read(likesProvider), LikesSegment.liked);
    await h.close(tester);
  });
  for (final dark in [false, true]) {
    for (final size in [const Size(320, 740), const Size(1024, 768)]) {
      testWidgets('Saved ${size.width}px Hindi2x dark=$dark has no overflow', (tester) async {
        final h = await setup(
          tester,
          liked: content(),
          size: size,
          scale: 2,
          dark: dark,
          locale: const Locale('hi', 'IN'),
        );
        expect(find.byType(PropertyListCard), findsWidgets);
        expect(tester.takeException(), isNull);
        await h.close(tester);
      });
    }
  }
  for (final liked in [true, false]) {
    final name = liked ? 'liked' : 'passed';
    testWidgets('empty $name shows its own scene and one action to Discover', (tester) async {
      final h = await setup(tester);
      if (!liked) {
        await tester.tap(find.text('Passed'));
        await tester.pump();
      }
      expect(tester.widget<PaperVignette>(find.byType(PaperVignette)).seed, name);
      expect(find.byKey(const ValueKey('qa.state.empty.action')), findsOneWidget);
      expect(find.byKey(const ValueKey('qa.state.empty.secondary')), findsNothing);
      expect(find.text('Go to Discover'), findsOneWidget);
      await tester.tap(find.text('Go to Discover'));
      await tester.pumpAndSettle();
      expect(find.text('Discover destination'), findsOneWidget);
      await h.close(tester);
    });
  }
  testWidgets('a failed first load uses the saved error scene', (tester) async {
    final h = await setup(
      tester,
      liked: PropertyPageState(phase: PropertyLoadPhase.failure, error: ServerException('x')),
    );
    expect(tester.widget<PaperVignette>(find.byType(PaperVignette)).seed, 'saved');
    await h.close(tester);
  });
  testWidgets('rows are flat photo-beside-words rows', (tester) async {
    final h = await setup(tester, liked: content());
    final cards = tester.widgetList<PropertyListCard>(find.byType(PropertyListCard));
    expect(cards.every((card) => card.row), isTrue);
    await h.close(tester);
  });
  testWidgets('the next page loads under the kept rows', (tester) async {
    final h = await setup(tester, liked: content().copyWith(phase: PropertyLoadPhase.paginating));
    expect(find.byType(PropertyListCard), findsNWidgets(2));
    expect(find.text('Loading more properties...'), findsOneWidget);
    expect(find.byKey(const ValueKey('qa.likes.content.retry')), findsNothing);
    await h.close(tester);
  });
}
