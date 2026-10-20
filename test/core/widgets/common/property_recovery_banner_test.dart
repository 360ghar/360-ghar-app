import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/widgets/common/property_recovery_banner.dart';
import 'package:ghar360/features/properties/application/property_filters.dart';
import 'package:ghar360/features/properties/application/property_queries.dart';
import 'package:ghar360/features/properties/application/swipe_history.dart';
import '../../../helpers/property_query_test_support.dart';
import '../../../helpers/property_screen_harness.dart';

class RecoveryHistory extends ScreenHistory {
  int saves = 0;
  Completer<void>? completion;
  bool succeeds = true;
  @override
  Future<void> retrySave() async {
    saves++;
    await completion?.future;
    if (succeeds) emit(SwipeHistoryState(hydrated: true));
  }
}

void main() {
  Future<PropertyScreenHarness> setup(WidgetTester tester, {PropertyPageState? page}) async {
    final data = (await tester.runAsync(PropertyQueryHarness.create))!;
    return PropertyScreenHarness(
      data,
      historyFactory: RecoveryHistory.new,
      pages: {
        PropertyFeed.liked:
            page ?? PropertyPageState(phase: PropertyLoadPhase.content, items: [queryProperty(1)]),
      },
    );
  }

  Future<void> pump(
    WidgetTester tester,
    PropertyScreenHarness h, {
    bool dark = false,
    bool narrow = false,
  }) => h.pump(
    tester,
    const Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            PropertyRecoveryBanner(feed: PropertyFeed.liked),
            Text('Retained property'),
          ],
        ),
      ),
    ),
    size: narrow ? const Size(320, 700) : const Size(390, 844),
    scale: narrow ? 2 : 1,
    locale: narrow ? const Locale('hi', 'IN') : const Locale('en', 'US'),
    dark: dark,
  );
  RecoveryHistory history(PropertyScreenHarness h) => h.history as RecoveryHistory;
  Future<void> failFilters(PropertyScreenHarness h) async {
    await h.data.raw.execute(
      "CREATE TRIGGER fail_preferences BEFORE INSERT ON preferences BEGIN SELECT RAISE(ABORT,'private-preferences'); END",
    );
    await h.container
        .read(propertyFiltersProvider.notifier)
        .search(PageType.likes, 'Retained query');
  }

  final filtersRetry = find.byKey(const ValueKey('qa.filters.save.retry'));
  final localRetry = find.byKey(const ValueKey('qa.properties.save.retry'));

  test('filter retry exposes loading before either storage result', () async {
    final h = await PropertyQueryHarness.create();
    addTearDown(h.close);
    final filters = h.container.read(propertyFiltersProvider.notifier);
    await h.raw.execute(
      "CREATE TRIGGER fail_preferences BEFORE INSERT ON preferences BEGIN SELECT RAISE(ABORT,'full'); END",
    );
    await filters.search(PageType.likes, 'Retained query');
    final failed = filters.retrySave();
    expect(h.container.read(propertyFiltersProvider).save.isLoading, true);
    expect(await failed, false);
    await h.raw.execute('DROP TRIGGER fail_preferences');
    final saved = filters.retrySave();
    expect(h.container.read(propertyFiltersProvider).save.isLoading, true);
    expect(await saved, true);
    expect(
      h.container.read(propertyFiltersProvider).forPage(PageType.likes).searchQuery,
      'Retained query',
    );
  });

  testWidgets('healthy content has no recovery control', (tester) async {
    final h = await setup(tester);
    await pump(tester, h);
    expect(filtersRetry, findsNothing);
    expect(localRetry, findsNothing);
    expect(find.text('Retained property'), findsOneWidget);
    await h.close(tester);
  });

  testWidgets('stale cache announces retained content without hiding it', (tester) async {
    final h = await setup(tester, page: PropertyPageState(stale: true, items: [queryProperty(1)]));
    await pump(tester, h);
    expect(find.text('Showing saved properties. Refresh to check for changes.'), findsOneWidget);
    expect(find.text('Retained property'), findsOneWidget);
    final notice = find.ancestor(
      of: find.text('Showing saved properties. Refresh to check for changes.'),
      matching: find.byType(Semantics),
    );
    expect(
      tester.widgetList<Semantics>(notice).any((widget) => widget.properties.liveRegion == true),
      true,
    );
    h
        .query(PropertyFeed.liked)
        .emit(PropertyPageState(stale: true, error: NetworkException('private-network')));
    await tester.pump();
    expect(find.text('Showing saved properties. Refresh to check for changes.'), findsNothing);
    expect(find.textContaining('private-network'), findsNothing);
    await h.close(tester);
  });

  testWidgets('filter failure has priority and retry preserves active query until saved', (
    tester,
  ) async {
    final h = await setup(tester, page: PropertyPageState(storageError: Exception('private-page')));
    history(h).emit(SwipeHistoryState(storageError: Exception('private-ledger'), hydrated: true));
    await tester.runAsync(() => failFilters(h));
    await pump(tester, h);
    expect(filtersRetry, findsOneWidget);
    expect(localRetry, findsNothing);
    expect(find.textContaining('private-'), findsNothing);
    final previousFailure = h.container.read(propertyFiltersProvider).save.error;
    await tester.runAsync(() async {
      await tester.tap(filtersRetry);
      await waitForQuery(() {
        final save = h.container.read(propertyFiltersProvider).save;
        return save.hasError && !identical(save.error, previousFailure);
      });
    });
    await tester.pump();
    await tester.pump();
    expect(tester.widget<TextButton>(filtersRetry).onPressed, isNotNull);
    expect(
      h.container.read(propertyFiltersProvider).forPage(PageType.likes).searchQuery,
      'Retained query',
    );
    await tester.runAsync(() => h.data.raw.execute('DROP TRIGGER fail_preferences'));
    await tester.runAsync(() async {
      await tester.tap(filtersRetry);
      await waitForQuery(() => h.container.read(propertyFiltersProvider).save.hasValue);
    });
    await tester.pump();
    await tester.pump();
    expect(filtersRetry, findsNothing);
    expect(localRetry, findsOneWidget);
    expect(history(h).saves, 0);
    expect(h.query(PropertyFeed.liked).loads, 0);
    expect(find.text('Retained property'), findsOneWidget);
    await h.close(tester);
  });

  testWidgets('ledger retry coalesces taps and exposes the next failure after success', (
    tester,
  ) async {
    final h = await setup(tester, page: PropertyPageState(storageError: Exception('page')));
    final ledger = history(h)..completion = Completer<void>();
    ledger.emit(SwipeHistoryState(storageError: Exception('ledger'), hydrated: true));
    await pump(tester, h);
    await tester.tap(localRetry);
    await tester.pump();
    expect(tester.widget<TextButton>(localRetry).onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(localRetry);
    expect(ledger.saves, 1);
    expect(h.query(PropertyFeed.liked).loads, 0);
    ledger.completion!.complete();
    await tester.pump();
    expect(tester.widget<TextButton>(localRetry).onPressed, isNotNull);
    await tester.tap(localRetry);
    await tester.pump();
    expect(h.query(PropertyFeed.liked).loads, 1);
    expect(h.query(PropertyFeed.liked).refreshed, true);
    expect(find.text('Retained property'), findsOneWidget);
    await h.close(tester);
  });

  testWidgets('failed ledger retry keeps a usable recovery action', (tester) async {
    final h = await setup(tester);
    final ledger = history(h)..succeeds = false;
    ledger.emit(SwipeHistoryState(storageError: Exception('private-ledger'), hydrated: true));
    await pump(tester, h);
    await tester.tap(localRetry);
    await tester.pump();
    expect(ledger.saves, 1);
    expect(localRetry, findsOneWidget);
    expect(tester.widget<TextButton>(localRetry).onPressed, isNotNull);
    expect(find.textContaining('private-ledger'), findsNothing);
    ledger.succeeds = true;
    await tester.tap(localRetry);
    await tester.pump();
    expect(localRetry, findsNothing);
    await h.close(tester);
  });

  testWidgets('page persistence retry is disabled during an existing refresh', (tester) async {
    final h = await setup(
      tester,
      page: PropertyPageState(
        phase: PropertyLoadPhase.refreshing,
        storageError: Exception('cache'),
        items: [queryProperty(1)],
      ),
    );
    await pump(tester, h);
    expect(tester.widget<TextButton>(localRetry).onPressed, isNull);
    await tester.tap(localRetry);
    expect(h.query(PropertyFeed.liked).loads, 0);
    expect(find.text('Retained property'), findsOneWidget);
    await h.close(tester);
  });

  testWidgets('disposing a pending local retry cannot update an unmounted banner', (tester) async {
    final h = await setup(tester);
    final ledger = history(h)
      ..completion = Completer<void>()
      ..succeeds = false;
    ledger.emit(SwipeHistoryState(storageError: Exception('ledger')));
    await pump(tester, h);
    await tester.tap(localRetry);
    await tester.pumpWidget(const SizedBox.shrink());
    ledger.completion!.complete();
    await tester.pump();
    expect(tester.takeException(), isNull);
    await h.close(tester);
  });

  for (final dark in [false, true]) {
    for (final filter in [false, true]) {
      testWidgets(
        'Hindi 2x 320px ${dark ? 'dark' : 'light'} ${filter ? 'filter' : 'local'} recovery fits',
        (tester) async {
          final h = await setup(tester);
          if (filter) {
            await tester.runAsync(() => failFilters(h));
          } else {
            history(h).emit(SwipeHistoryState(storageError: Exception('ledger')));
          }
          await pump(tester, h, dark: dark, narrow: true);
          final button = filter ? filtersRetry : localRetry;
          expect(button, findsOneWidget);
          expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
          expect(find.text('Retained property'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await h.close(tester);
        },
      );
    }
  }
}
