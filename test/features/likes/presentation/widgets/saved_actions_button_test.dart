import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/controllers/offline_queue_service.dart';
import 'package:ghar360/core/data/ports/swipes_port.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/providers/pending_actions_provider.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/likes/presentation/widgets/saved_actions_button.dart';
import 'package:ghar360/features/properties/application/swipe_history.dart';
import '../../../../helpers/property_query_test_support.dart';
import '../../../../helpers/property_screen_harness.dart';

void main() {
  Future<PropertyScreenHarness> setup(WidgetTester tester) async {
    final data = (await tester.runAsync(PropertyQueryHarness.create))!;
    final h = PropertyScreenHarness(data, historyFactory: SwipeHistory.new);
    await tester.runAsync(() async {
      h.container.read(swipeHistoryProvider);
      await waitForQuery(() => h.container.read(swipeHistoryProvider).hydrated);
      h.container.read(pendingActionsProvider);
      await h.container.read(pendingActionsProvider.notifier).reload();
    });
    return h;
  }

  OfflineQueueService queue(PropertyScreenHarness h) =>
      h.container.read(offlineQueueServiceProvider);
  Future<PendingAction> create(
    PropertyScreenHarness h, {
    int id = 1,
    PendingActionStatus status = PendingActionStatus.pending,
    String? failure,
    String kind = 'swipe',
  }) async {
    final action = await queue(
      h,
    ).create(kind: kind, payload: {'property_id': id, 'is_liked': id.isOdd}, status: status);
    if (failure != null) {
      await queue(h).update(
        action,
        scope: h.container.read(storageScopeProvider),
        status: status,
        failureCode: failure,
      );
    }
    await h.container.read(pendingActionsProvider.notifier).reload();
    return action;
  }

  Future<void> pump(
    WidgetTester tester,
    PropertyScreenHarness h, {
    bool dark = false,
    bool narrow = false,
  }) => h.pump(
    tester,
    const Scaffold(body: SingleChildScrollView(child: SavedActionsButton())),
    size: narrow ? const Size(320, 700) : const Size(390, 844),
    scale: narrow ? 2 : 1,
    locale: narrow ? const Locale('hi', 'IN') : const Locale('en', 'US'),
    dark: dark,
  );
  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('qa.saved.actions')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Finder retry(PendingAction action) =>
      find.byKey(ValueKey('qa.saved.action.retry.${action.operationId}'));
  Finder discard(PendingAction action) =>
      find.byKey(ValueKey('qa.saved.action.discard.${action.operationId}'));
  Future<void> reload(WidgetTester tester, PropertyScreenHarness h) async {
    await tester.runAsync(() => h.container.read(pendingActionsProvider.notifier).reload());
    await tester.pump();
  }

  testWidgets('only pending swipe requests are counted and status controls are explicit', (
    tester,
  ) async {
    final h = await setup(tester);
    final actions = (await tester.runAsync(
      () async => [
        await create(h, id: 1),
        await create(h, id: 2, status: PendingActionStatus.failed, failure: 'REJECTED'),
        await create(h, id: 3, status: PendingActionStatus.failed, failure: 'SUPERSEDED'),
        await create(h, id: 4, status: PendingActionStatus.confirmed),
        await create(h, id: 5, kind: 'visit'),
      ],
    ))!;
    await pump(tester, h);
    expect(find.text('Saved actions (3)'), findsOneWidget);
    await open(tester);
    expect(find.text('Saved on this device. Not yet confirmed.'), findsOneWidget);
    expect(find.text('This action was not confirmed. Try again or discard it.'), findsOneWidget);
    expect(retry(actions[0]), findsOneWidget);
    expect(retry(actions[1]), findsOneWidget);
    await tester.scrollUntilVisible(
      discard(actions[2]),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('A newer action replaced this request. You can discard it.'), findsOneWidget);
    expect(retry(actions[2]), findsNothing);
    expect(discard(actions[2]), findsOneWidget);
    expect(find.textContaining('Property 4'), findsNothing);
    expect(find.textContaining('Property 5'), findsNothing);
    expect(h.data.swipes.retryRequests, isEmpty);
    await h.close(tester);
  });

  testWidgets('retry disables both controls and keeps unresolved intent on failure', (
    tester,
  ) async {
    final h = await setup(tester);
    final action = (await tester.runAsync(() => create(h)))!;
    final completion = Completer<SwipeOutcome>();
    h.data.swipes.retryResponse = (_) => completion.future;
    await pump(tester, h);
    await open(tester);
    await tester.tap(retry(action));
    await tester.runAsync(() => waitForQuery(() => h.data.swipes.retryRequests.isNotEmpty));
    await tester.pump();
    expect(tester.widget<TextButton>(retry(action)).onPressed, isNull);
    expect(tester.widget<TextButton>(discard(action)).onPressed, isNull);
    expect(find.byKey(ValueKey('qa.saved.action.busy.${action.operationId}')), findsOneWidget);
    await tester.tap(retry(action));
    completion.complete(PendingSwipe(action));
    await tester.runAsync(
      () => waitForQuery(
        () =>
            h.container
                .read(swipeHistoryProvider)
                .pendingOperations[action.operationId]
                ?.hasError ==
            true,
      ),
    );
    await tester.pump();
    expect(h.data.swipes.retryRequests, hasLength(1));
    expect(tester.widget<TextButton>(retry(action)).onPressed, isNotNull);
    expect(
      find.text('Unable to reach the server. Please check your internet connection.'),
      findsOneWidget,
    );
    expect(h.container.read(swipeHistoryProvider).excluded, contains(1));
    expect((await tester.runAsync(() => queue(h).list()))!.single.operationId, action.operationId);
    await h.close(tester);
  });

  testWidgets('confirmed retry removes its row without creating another operation', (tester) async {
    final h = await setup(tester);
    final action = (await tester.runAsync(() => create(h, status: PendingActionStatus.failed)))!;
    h.data.swipes.retryResponse = (action) async {
      await queue(h).update(
        action,
        scope: h.container.read(storageScopeProvider),
        status: PendingActionStatus.confirmed,
      );
      return ConfirmedSwipe(operationId: action.operationId);
    };
    await pump(tester, h);
    await open(tester);
    await tester.tap(retry(action));
    await tester.runAsync(
      () => waitForQuery(
        () =>
            h.container
                .read(swipeHistoryProvider)
                .pendingOperations[action.operationId]
                ?.hasValue ==
            true,
      ),
    );
    await reload(tester, h);
    expect(retry(action), findsNothing);
    expect(find.text('No saved actions to review.'), findsOneWidget);
    expect((await tester.runAsync(() => queue(h).list()))!, hasLength(1));
    expect(h.data.swipes.retryRequests.single.operationId, action.operationId);
    await h.close(tester);
  });

  testWidgets('discard deletes the request but retains its unresolved exclusion', (tester) async {
    final h = await setup(tester);
    final action = (await tester.runAsync(() => create(h)))!;
    await pump(tester, h);
    await open(tester);
    await tester.tap(discard(action));
    await tester.runAsync(
      () => waitForQuery(
        () =>
            h.container
                .read(swipeHistoryProvider)
                .pendingOperations[action.operationId]
                ?.hasValue ==
            true,
      ),
    );
    await reload(tester, h);
    expect(find.text('No saved actions to review.'), findsOneWidget);
    expect(h.container.read(swipeHistoryProvider).excluded, contains(1));
    expect(h.data.swipes.retryRequests, isEmpty);
    expect((await tester.runAsync(() => queue(h).list()))!, isEmpty);
    await h.close(tester);
  });

  testWidgets('failed discard shows a safe error and leaves both controls available', (
    tester,
  ) async {
    final h = await setup(tester);
    final action = (await tester.runAsync(() => create(h)))!;
    await tester.runAsync(
      () => h.data.raw.execute(
        "CREATE TRIGGER fail_draft BEFORE INSERT ON drafts BEGIN SELECT RAISE(ABORT,'private-diagnostic'); END",
      ),
    );
    await pump(tester, h);
    await open(tester);
    await tester.tap(discard(action));
    await tester.runAsync(
      () => waitForQuery(
        () =>
            h.container
                .read(swipeHistoryProvider)
                .pendingOperations[action.operationId]
                ?.hasError ==
            true,
      ),
    );
    await tester.pump();
    expect(
      find.text('Could not save on this device. Free some space and try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('private-diagnostic'), findsNothing);
    expect(tester.widget<TextButton>(retry(action)).onPressed, isNotNull);
    expect(tester.widget<TextButton>(discard(action)).onPressed, isNotNull);
    expect((await tester.runAsync(() => queue(h).list()))!.single.operationId, action.operationId);
    await h.close(tester);
  });

  testWidgets('reload failure retains access to saved rows and can recover in the sheet', (
    tester,
  ) async {
    final h = await setup(tester);
    final action = (await tester.runAsync(() => create(h)))!;
    await tester.runAsync(
      () => h.data.raw.execute('ALTER TABLE actions RENAME TO unavailable_actions'),
    );
    await tester.runAsync(() => h.container.read(pendingActionsProvider.notifier).reload());
    await pump(tester, h);
    expect(find.byKey(const ValueKey('qa.saved.actions.load.retry')), findsOneWidget);
    expect(find.text('Saved actions (1)'), findsOneWidget);
    await open(tester);
    expect(retry(action), findsOneWidget);
    expect(find.byKey(const ValueKey('qa.saved.actions.sheet.load.retry')), findsOneWidget);
    expect(find.text('No saved actions to review.'), findsNothing);
    await tester.runAsync(
      () => h.data.raw.execute('ALTER TABLE unavailable_actions RENAME TO actions'),
    );
    await tester.tap(find.byKey(const ValueKey('qa.saved.actions.sheet.load.retry')));
    await tester.runAsync(
      () => waitForQuery(
        () => h.container.read(pendingActionsProvider).phase == PendingActionsPhase.ready,
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('qa.saved.actions.sheet.load.retry')), findsNothing);
    expect(retry(action), findsOneWidget);
    await h.close(tester);
  });

  testWidgets('account change clears open-sheet rows before the new queue finishes loading', (
    tester,
  ) async {
    final h = await setup(tester);
    final action = (await tester.runAsync(() => create(h)))!;
    await pump(tester, h);
    await open(tester);
    late Completer<void> released;
    late Future<void> transaction;
    await tester.runAsync(() async {
      released = Completer<void>();
      final started = Completer<void>();
      transaction = h.data.raw.transaction((_) async {
        started.complete();
        await released.future;
      });
      await started.future;
    });
    (h.container.read(storageScopeProvider.notifier) as QueryScope).change('b');
    await tester.pump();
    expect(retry(action), findsNothing);
    expect(find.byKey(const ValueKey('qa.saved.actions.loading')), findsOneWidget);
    expect(find.text('No saved actions to review.'), findsNothing);
    await tester.runAsync(() async {
      released.complete();
      await transaction;
      await h.container.read(pendingActionsProvider.notifier).reload();
    });
    await tester.pump();
    expect(find.text('No saved actions to review.'), findsOneWidget);
    expect(h.data.swipes.retryRequests, isEmpty);
    await h.close(tester);
  });

  testWidgets('old account retry result cannot return a row to the open sheet', (tester) async {
    final h = await setup(tester);
    final action = (await tester.runAsync(() => create(h)))!;
    final completion = Completer<SwipeOutcome>();
    h.data.swipes.retryResponse = (_) => completion.future;
    await pump(tester, h);
    await open(tester);
    await tester.tap(retry(action));
    await tester.runAsync(() => waitForQuery(() => h.data.swipes.retryRequests.isNotEmpty));
    (h.container.read(storageScopeProvider.notifier) as QueryScope).change('b');
    await reload(tester, h);
    completion.completeError(ServerException('private-old-account'));
    await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(retry(action), findsNothing);
    expect(find.textContaining('private-old-account'), findsNothing);
    expect(h.container.read(swipeHistoryProvider).pendingOperations, isEmpty);
    await h.close(tester);
  });

  for (final dark in [false, true]) {
    testWidgets('Hindi 2x at 320px keeps ${dark ? 'dark' : 'light'} sheet controls reachable', (
      tester,
    ) async {
      final h = await setup(tester);
      final action = (await tester.runAsync(() => create(h, status: PendingActionStatus.failed)))!;
      await pump(tester, h, dark: dark, narrow: true);
      await open(tester);
      await tester.scrollUntilVisible(
        discard(action),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pump();
      expect(tester.getSize(discard(action)).height, greaterThanOrEqualTo(48));
      expect(tester.getSize(retry(action)).height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
      await tester.tap(discard(action));
      await tester.runAsync(
        () => waitForQuery(
          () =>
              h.container
                  .read(swipeHistoryProvider)
                  .pendingOperations[action.operationId]
                  ?.hasValue ==
              true,
        ),
      );
      await reload(tester, h);
      expect(discard(action), findsNothing);
      expect(tester.takeException(), isNull);
      await h.close(tester);
    });
  }
}
