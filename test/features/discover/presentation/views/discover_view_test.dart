import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/discover/presentation/views/discover_view.dart';
import 'package:ghar360/features/discover/presentation/widgets/property_swipe_stack.dart';
import 'package:ghar360/features/location/application/location_source.dart';
import 'package:ghar360/features/properties/application/property_location.dart';
import 'package:ghar360/features/properties/application/property_queries.dart';
import 'package:ghar360/features/properties/application/swipe_history.dart';
import '../../../../helpers/property_query_test_support.dart';
import '../../../../helpers/property_screen_harness.dart';

void main() {
  Future<PropertyScreenHarness> setup(
    WidgetTester tester,
    PropertyPageState page, {
    Size size = const Size(390, 844),
    double scale = 1,
    bool dark = false,
    Locale locale = const Locale('en', 'US'),
    bool guest = false,
  }) async {
    final data = (await tester.runAsync(PropertyQueryHarness.create))!;
    final h = PropertyScreenHarness(
      data,
      pages: {PropertyFeed.discover: page},
      // A guest runs the real ledger: its backstop is what the test proves.
      historyFactory: guest ? SwipeHistory.new : null,
    );
    if (guest) (h.container.read(storageScopeProvider.notifier) as QueryScope).change(null);
    await h.pump(
      tester,
      const DiscoverView(),
      size: size,
      scale: scale,
      dark: dark,
      locale: locale,
    );
    if (guest) {
      // The real ledger hydrates from the database before the deck shows.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    return h;
  }

  PropertyPageState content() => PropertyPageState(
    phase: PropertyLoadPhase.content,
    items: [queryProperty(1), queryProperty(2)],
  );
  testWidgets('the out-of-area line shows only while the Gurugram fallback applies', (
    tester,
  ) async {
    final h = await setup(tester, content());
    final location =
        h.container.read(propertyLocationProvider(PageType.discover).notifier) as QueryLocation;
    const line = 'Homes are in Gurugram for now';
    expect(find.text(line), findsNothing);
    location.replace(ServiceArea.center, source: LocationSource.fallback);
    await tester.pump();
    expect(find.text(line), findsOneWidget);
    // A place the user picks replaces the fallback and the line goes.
    location.replace(
      const LocationData(name: 'Noida', latitude: 28.5355, longitude: 77.391),
      source: LocationSource.manual,
    );
    await tester.pump();
    expect(find.text(line), findsNothing);
    await h.close(tester);
  });
  for (final phase in [
    PropertyLoadPhase.idle,
    PropertyLoadPhase.loading,
    PropertyLoadPhase.paginating,
  ]) {
    testWidgets('empty $phase shows loading instead of an exhausted deck', (tester) async {
      final h = await setup(tester, PropertyPageState(phase: phase));
      expect(find.byKey(const ValueKey('qa.discover.screen')), findsOneWidget);
      expect(find.text('You have seen every home here'), findsNothing);
      expect(find.byType(PropertySwipeStack), findsNothing);
      expect(tester.takeException(), isNull);
      await h.close(tester);
    });
  }
  testWidgets('initial network failure is localized and retry invokes the current query', (
    tester,
  ) async {
    final h = await setup(
      tester,
      PropertyPageState(
        phase: PropertyLoadPhase.failure,
        error: NetworkException('private-response'),
      ),
    );
    expect(find.textContaining('private-response'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(h.query(PropertyFeed.discover).loads, 1);
    expect(h.query(PropertyFeed.discover).refreshed, isTrue);
    await h.close(tester);
  });
  testWidgets('empty deck offers refresh and filter recovery', (tester) async {
    final h = await setup(tester, PropertyPageState(phase: PropertyLoadPhase.empty));
    expect(find.text('You have seen every home here'), findsOneWidget);
    expect(find.text('Adjust Filters'), findsOneWidget);
    await tester.tap(find.text('Refresh'));
    await tester.pump();
    expect(h.query(PropertyFeed.discover).loads, 1);
    await h.close(tester);
  });
  testWidgets('content includes explicit Like Pass and a labeled Assistant entry', (tester) async {
    final h = await setup(tester, content());
    expect(find.byType(PropertySwipeStack), findsOneWidget);
    for (final action in ['like', 'pass']) {
      final button = find.byKey(ValueKey('qa.discover.action.$action'));
      expect(button, findsOneWidget);
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
    }
    expect(find.text('Like'), findsOneWidget);
    expect(find.text('Pass'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('qa.discover.assistant')));
    await tester.pumpAndSettle();
    expect(find.text('Assistant destination'), findsOneWidget);
    await h.close(tester);
  });
  group('guest', () {
    testWidgets('sees Sign in instead of the Assistant, and it opens sign-in', (tester) async {
      final h = await setup(tester, content(), guest: true);
      expect(find.byKey(const ValueKey('qa.discover.assistant')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('qa.discover.sign_in')));
      await tester.pumpAndSettle();
      expect(find.text('Sign-in destination /discover'), findsOneWidget);
      await h.close(tester);
    });
    testWidgets('signed-in user keeps the Assistant and has no Sign in', (tester) async {
      final h = await setup(tester, content());
      expect(find.byKey(const ValueKey('qa.discover.sign_in')), findsNothing);
      expect(find.byKey(const ValueKey('qa.discover.assistant')), findsOneWidget);
      await h.close(tester);
    });
    testWidgets('Like shows the sign-in sheet and the card stays', (tester) async {
      final h = await setup(tester, content(), guest: true);
      await tester.tap(find.byKey(const ValueKey('qa.discover.action.like')));
      await tester.pumpAndSettle();
      expect(find.text('Sign in to continue'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('qa.sign_in_gate.not_now')));
      await tester.pumpAndSettle();
      expect(find.text('Sign in to continue'), findsNothing);
      expect(h.container.read(swipeHistoryProvider).excluded, isEmpty);
      expect(h.data.swipes.mutations, isEmpty);
      await h.close(tester);
    });
    testWidgets('Pass removes the card and calls no repository', (tester) async {
      final h = await setup(tester, content(), guest: true);
      await tester.tap(find.byKey(const ValueKey('qa.discover.action.pass')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
      expect(h.container.read(swipeHistoryProvider).excluded, {1});
      expect(h.data.swipes.mutations, isEmpty);
      expect(find.text('You have seen every home here'), findsNothing);
      await h.close(tester);
    });
  });
  for (final liked in [true, false]) {
    testWidgets('explicit ${liked ? 'Like' : 'Pass'} calls the same ledger as a swipe', (
      tester,
    ) async {
      final h = await setup(tester, content());
      await tester.tap(find.byKey(ValueKey('qa.discover.action.${liked ? 'like' : 'pass'}')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
      expect(h.data.swipes.mutations, [(id: 1, liked: liked)]);
      expect(h.container.read(swipeHistoryProvider).excluded, contains(1));
      await h.close(tester);
    });
  }
  for (final pagination in [true, false]) {
    testWidgets(
      '${pagination ? 'pagination' : 'refresh'} failure retains content and retries the failed stage',
      (tester) async {
        final p = content().copyWith(
          error: pagination ? null : NetworkException('offline'),
          paginationError: pagination ? NetworkException('offline') : null,
          stale: true,
        );
        final h = await setup(tester, p);
        expect(find.byType(PropertySwipeStack), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('qa.discover.content.retry')));
        await tester.pump();
        expect(
          pagination ? h.query(PropertyFeed.discover).more : h.query(PropertyFeed.discover).loads,
          1,
        );
        expect(
          pagination
              ? h.query(PropertyFeed.discover).retried
              : h.query(PropertyFeed.discover).refreshed,
          isTrue,
        );
        await h.close(tester);
      },
    );
  }
  testWidgets('refresh and pagination show progress while the card stays usable', (tester) async {
    final h = await setup(tester, content().copyWith(phase: PropertyLoadPhase.refreshing));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byType(PropertySwipeStack), findsOneWidget);
    h.query(PropertyFeed.discover).emit(content().copyWith(phase: PropertyLoadPhase.paginating));
    await tester.pump();
    expect(find.byType(PropertySwipeStack), findsOneWidget);
    expect(tester.takeException(), isNull);
    await h.close(tester);
  });
  testWidgets('swipe failure is announced without exposing diagnostics', (tester) async {
    final h = await setup(tester, content());
    h.history.emit(
      SwipeHistoryState(hydrated: true, failures: {1: ServerException('private-diagnostic')}),
    );
    await tester.pump();
    expect(find.textContaining('could not be saved'), findsOneWidget);
    expect(find.textContaining('private-diagnostic'), findsNothing);
    await h.close(tester);
  });
  testWidgets('property tap retains the numeric details destination', (tester) async {
    final h = await setup(tester, content());
    final card = tester.widget<PropertySwipeStack>(find.byType(PropertySwipeStack));
    card.onSwipeUp(queryProperty(1));
    await tester.pumpAndSettle();
    expect(find.text('Details 1'), findsOneWidget);
    await h.close(tester);
  });
  for (final dark in [false, true]) {
    for (final size in [const Size(320, 740), const Size(1024, 768)]) {
      testWidgets('content ${size.width}px Hindi2x dark=$dark has no layout errors', (
        tester,
      ) async {
        final p = PropertyModel.fromJson({
          ...queryProperty(1).toJson(),
          'title': 'A long readable property title with complete information',
          'bedrooms': 3,
          'bathrooms': 2,
          'area_sqft': 1400,
          'city': 'New Delhi',
        });
        final h = await setup(
          tester,
          PropertyPageState(phase: PropertyLoadPhase.content, items: [p]),
          size: size,
          scale: 2,
          dark: dark,
          locale: const Locale('hi', 'IN'),
        );
        expect(find.byType(PropertySwipeStack), findsOneWidget);
        expect(tester.takeException(), isNull);
        await h.close(tester);
      });
    }
  }
}
