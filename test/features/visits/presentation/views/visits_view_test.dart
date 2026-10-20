import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/data/models/visit_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/app_design_theme.dart';
import 'package:ghar360/core/design/app_design_tokens.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/providers/pending_actions_provider.dart';
import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/widgets/common/loading_states.dart';
import 'package:ghar360/core/widgets/paper/folder_tabs.dart';
import 'package:ghar360/features/properties/application/swipe_history.dart';
import 'package:ghar360/features/property_details/presentation/controllers/property_details_controller.dart';
import 'package:ghar360/features/property_details/presentation/views/property_details_view.dart';
import 'package:ghar360/features/visits/presentation/controllers/visits_controller.dart';
import 'package:ghar360/features/visits/presentation/views/visits_view.dart';
import 'package:ghar360/features/visits/presentation/widgets/agent_card.dart';
import 'package:ghar360/features/visits/presentation/widgets/visit_card.dart';
import 'package:ghar360/features/visits/presentation/widgets/visit_edit_dialog.dart';
import '../../../../helpers/knife_finders.dart';
import '../../../../helpers/provider_test_app.dart';
import '../../../../helpers/visits_test_support.dart';

void main() {
  late SeededVisitsController controller;
  late SeededPendingActions pending;
  VisitsState content({List<VisitModel>? visits}) => VisitsState(
    phase: VisitLoadPhase.content,
    visits: visits ?? [visitFixture(property: propertyFixture())],
    agent: const VisitAgentState(phase: VisitLoadPhase.content),
  );
  setUp(() {
    controller = SeededVisitsController(content());
    pending = SeededPendingActions();
  });
  Future<void> pump(
    WidgetTester tester, {
    VisitsState? state,
    double textScale = 1,
    ThemeData? theme,
  }) async {
    if (state != null) controller = SeededVisitsController(state);
    await tester.pumpProviderApp(
      const VisitsView(),
      textScale: textScale,
      theme: theme,
      overrides: [
        visitsProvider.overrideWith(() => controller),
        pendingActionsProvider.overrideWith(() => pending),
        unownedActionsProvider.overrideWith((ref) async => []),
      ],
    );
    await tester.pump();
  }

  testWidgets('initial load has content-shaped skeletons and one loading announcement', (
    tester,
  ) async {
    await pump(tester, state: VisitsState(phase: VisitLoadPhase.loading));
    expect(find.byType(Skeleton), findsOneWidget);
    expect(find.bySemanticsLabel('Loading...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(VisitCard), findsNothing);
  });
  testWidgets('initial error has typed localized retry without raw exception', (tester) async {
    await pump(
      tester,
      state: VisitsState(phase: VisitLoadPhase.failed, failure: ServerException('secret SQL')),
    );
    expect(find.textContaining('secret SQL'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
    // On a short window the state sits under the scene header; it scrolls up.
    await tester.ensureVisible(find.text('Retry'));
    await tester.pump();
    await tester.tap(find.text('Retry'));
    expect(controller.loads, 1);
  });
  testWidgets('a listing with no price for its purpose shows no price and no dangling dot', (
    tester,
  ) async {
    // The visit property has no purpose, so the app has no price to show for it.
    final property = const PropertyModel(
      id: 100,
      title: 'Test Property 100',
      basePrice: 5000000,
      isAvailable: true,
      viewCount: 0,
      likeCount: 0,
      interestCount: 0,
    );
    await pump(
      tester,
      state: content(visits: [visitFixture(property: property)]),
    );
    expect(find.textContaining('₹'), findsNothing);
    expect(find.textContaining(RegExp(r'^\s*·')), findsNothing);
  });
  testWidgets('empty screen retains tabs and separate past empty state', (tester) async {
    await pump(tester, state: content(visits: []));
    expect(find.text('No visits scheduled'), findsOneWidget);
    expect(find.text('Discover'), findsOneWidget);
    await tester.tap(find.text('Past Visits'));
    await tester.pumpAndSettle();
    expect(find.text('No past visits yet'), findsOneWidget);
  });
  testWidgets('content and card information survive a refresh error', (tester) async {
    await pump(
      tester,
      state: content().copyWith(failure: NetworkException('offline'), stale: true),
    );
    expect(find.byType(VisitCard), findsOneWidget);
    expect(find.text('Test Property 100'), findsOneWidget);
    expect(find.text('Saved appointments. Refresh to check for changes.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(controller.loads, 1);
  });
  testWidgets('refresh shows inline progress without replacing appointments', (tester) async {
    await pump(tester, state: content().copyWith(phase: VisitLoadPhase.refreshing));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byType(VisitCard), findsOneWidget);
    expect(find.byType(Skeleton), findsNothing);
    expect(find.byType(RefreshIndicator), findsOneWidget);
  });
  testWidgets('tabs show their own sorted appointments', (tester) async {
    await pump(
      tester,
      state: content(
        visits: [
          visitFixture(property: propertyFixture()),
          visitFixture(id: 2, status: VisitStatus.completed, property: propertyFixture(id: 200)),
        ],
      ),
    );
    expect(find.text('Test Property 100'), findsOneWidget);
    await tester.tap(find.text('Past Visits'));
    await tester.pumpAndSettle();
    expect(find.text('Test Property 200'), findsOneWidget);
    expect(find.text('Test Property 100'), findsNothing);
  });
  testWidgets('missing property data still renders title and visit actions', (tester) async {
    await pump(tester, state: content(visits: [visitFixture()]));
    expect(find.text('Property #100'), findsOneWidget);
    expect(find.text('Reschedule'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });
  testWidgets('agent error is inline and does not turn no visits into a failed screen', (
    tester,
  ) async {
    await pump(
      tester,
      state: content(visits: []).copyWith(
        agent: VisitAgentState(
          phase: VisitLoadPhase.failed,
          error: ServerException('agent secret'),
        ),
      ),
    );
    expect(find.text('No visits scheduled'), findsOneWidget);
    expect(find.textContaining('agent secret'), findsNothing);
    await tester.tap(find.text('Retry'));
    expect(controller.agents, 1);
    expect(controller.loads, 0);
  });
  testWidgets('agent skeleton transitions to loaded contact card', (tester) async {
    await pump(tester, state: content().copyWith(agent: const VisitAgentState()));
    expect(find.byKey(const ValueKey('qa.visits.agent_loading')), findsOneWidget);
    controller.replace(
      content().copyWith(
        agent: VisitAgentState(value: agentFixture(), phase: VisitLoadPhase.content),
      ),
    );
    await tester.pump();
    expect(find.byType(AgentCard), findsOneWidget);
    expect(find.text('Test Agent'), findsOneWidget);
    expect(find.byKey(const ValueKey('qa.visits.agent_loading')), findsNothing);
  });
  for (final icon in [KnifeIcon.phone, KnifeIcon.chat]) {
    testWidgets('missing agent contact recovers without throwing for $icon', (tester) async {
      await pump(
        tester,
        state: content().copyWith(
          agent: VisitAgentState(value: agentFixture(), phase: VisitLoadPhase.content),
        ),
      );
      await tester.tap(findKnife(icon));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 4));
    });
  }
  testWidgets('pagination failure retains cards and retries with footer control', (tester) async {
    await pump(
      tester,
      state: content().copyWith(
        nextCursor: 'next',
        pagePhase: VisitPagePhase.failed,
        pageFailure: NetworkException('offline'),
      ),
    );
    expect(find.byType(VisitCard), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('qa.visits.pagination.retry')));
    expect(controller.pages, 1);
    expect(controller.loads, 0);
  });
  testWidgets('short first page has explicit load-more control', (tester) async {
    await pump(
      tester,
      state: content(visits: []).copyWith(nextCursor: 'next'),
    );
    await tester.tap(find.text('Load more visits'));
    expect(controller.pages, 1);
  });
  testWidgets('scroll pagination starts near the bottom', (tester) async {
    await pump(
      tester,
      state: content(
        visits: List.generate(
          15,
          (i) => visitFixture(
            id: i,
            property: propertyFixture(id: i),
          ),
        ),
      ).copyWith(nextCursor: 'next'),
    );
    await tester.drag(find.byKey(const ValueKey('qa.visits.list')), const Offset(0, -5000));
    await tester.pumpAndSettle();
    expect(controller.pages, greaterThan(0));
    expect(tester.takeException(), isNull);
  });
  testWidgets('reschedule opens date and time picker, then preserves form after failure', (
    tester,
  ) async {
    controller.mutationResult = false;
    await pump(tester);
    await tester.tap(find.text('Reschedule'));
    await tester.pumpAndSettle();
    expect(find.byType(VisitEditDialog), findsOneWidget);
    expect(find.text('Date'), findsOneWidget);
    expect(find.text('Time'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Reschedule'));
    await tester.pumpAndSettle();
    expect(controller.reschedules, 1);
    expect(find.byType(VisitEditDialog), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Reschedule')).onPressed,
      isNotNull,
    );
  });
  testWidgets('reschedule success closes dialog', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Reschedule'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Reschedule'));
    await tester.pumpAndSettle();
    expect(controller.reschedules, 1);
    expect(find.byType(VisitEditDialog), findsNothing);
  });
  testWidgets('cancel validates reason inline and retains it after failure', (tester) async {
    controller.mutationResult = false;
    await pump(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes, Cancel'));
    await tester.pump();
    expect(controller.cancellations, 0);
    expect(find.text('Enter a reason to cancel this visit.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Not available');
    await tester.tap(find.text('Yes, Cancel'));
    await tester.pumpAndSettle();
    expect(controller.cancellations, 1);
    expect(controller.lastReason, 'Not available');
    expect(find.text('Not available'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
  });
  testWidgets('cancel success and dismiss keep controller lifecycle safe', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Busy');
    await tester.tap(find.text('Yes, Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
  for (final days in [60, 400, -3]) {
    testWidgets('date picker accepts existing visit $days days away', (tester) async {
      final visit = visitFixture(date: DateTime.now().add(Duration(days: days)));
      await tester.pumpProviderApp(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showVisitEditDialog(context, visit, cancel: false),
              child: const Text('Open'),
            ),
          ),
        ),
        overrides: [visitsProvider.overrideWith(() => controller)],
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Date'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('pending booking is not a confirmed card and supports reconciliation', (
    tester,
  ) async {
    pending = SeededPendingActions([
      PendingAction(
        operationId: 'op',
        scopeKey: 'a',
        kind: 'visit',
        payload: {'scheduled_date': '2030-01-01T00:00:00Z'},
        createdAt: DateTime.now(),
        status: PendingActionStatus.needsReconciliation,
      ),
    ]);
    await pump(tester, state: content(visits: []));
    expect(find.text('Booking is not confirmed'), findsOneWidget);
    expect(find.byType(VisitCard), findsNothing);
    await tester.tap(find.text('Check bookings'));
    await tester.pump();
    expect(controller.reconciliations, 1);
    expect(find.textContaining('No matching booking found'), findsOneWidget);
  });
  testWidgets('discard requires confirmation and does not claim to cancel server booking', (
    tester,
  ) async {
    pending = SeededPendingActions([
      PendingAction(
        operationId: 'op',
        scopeKey: 'a',
        kind: 'visit',
        payload: {},
        createdAt: DateTime.now(),
        status: PendingActionStatus.failed,
      ),
    ]);
    await pump(tester, state: content(visits: []));
    await tester.tap(find.text('Discard request'));
    await tester.pumpAndSettle();
    expect(find.textContaining('does not cancel a booking'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Discard request').last);
    await tester.pumpAndSettle();
    expect(pending.discarded, 'op');
    expect(find.text('Request failed'), findsNothing);
  });
  for (final dark in [false, true]) {
    testWidgets('narrow large-text ${dark ? 'dark' : 'light'} layout has readable selected tabs', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final theme = dark ? AppDesignTheme.dark() : AppDesignTheme.light();
      await pump(
        tester,
        textScale: 1.8,
        theme: theme,
        state: content().copyWith(
          agent: VisitAgentState(value: agentFixture(), phase: VisitLoadPhase.content),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(VisitCard), findsOneWidget);
      final labelColor = dark ? AppDesignTokens.nightText : AppDesignTokens.ink900;
      expect(find.byType(FolderTabs), findsOneWidget);
      expect(labelColor, isNot(theme.colorScheme.primary));
      // The chosen tab is the sheet itself, so its label reads on the sheet.
      final foreground = labelColor.computeLuminance();
      final background = AppPalette(isDark: dark).surface.computeLuminance();
      final contrast = foreground > background
          ? (foreground + 0.05) / (background + 0.05)
          : (background + 0.05) / (foreground + 0.05);
      expect(contrast, greaterThanOrEqualTo(4.5));
      expect(tester.widget<Text>(find.text('Scheduled Visits')).style?.color, labelColor);
      await tester.tap(find.byKey(const ValueKey('qa.visits.past')));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.text('Past Visits')).style?.color, labelColor);
      expect(tester.widget<Text>(find.text('Scheduled Visits')).style?.color, isNot(labelColor));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('no assigned agent (404) is a quiet line, not an error', (tester) async {
    await pump(tester);
    expect(find.byKey(const ValueKey('qa.visits.no_agent')), findsOneWidget);
    expect(find.text('No relationship manager is assigned to you yet.'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    expect(find.byType(AgentCard), findsNothing);
  });
  testWidgets('empty tabs each offer one way on: Discover', (tester) async {
    await pump(tester, state: content(visits: []));
    expect(find.byKey(const ValueKey('qa.state.empty.action')), findsOneWidget);
    await tester.tap(find.text('Past Visits'));
    await tester.pumpAndSettle();
    expect(find.text('Visits you have been on appear here.'), findsOneWidget);
    expect(find.byKey(const ValueKey('qa.state.empty.action')), findsOneWidget);
  });
  testWidgets('status is coloured text and a missing photo is not an icon tile', (tester) async {
    await pump(
      tester,
      state: content(visits: [visitFixture(status: VisitStatus.confirmed)]),
    );
    expect(find.byType(Chip), findsNothing);
    expect(findKnife(KnifeIcon.home), findsNothing);
    expect(find.textContaining('Confirmed', findRichText: true), findsOneWidget);
  });
  group('two panes at 1280 x 800', () {
    late AppDatabase database;
    setUp(() async => database = await visitTestDatabase());
    tearDown(() => database.close());
    Future<void> pumpWide(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      controller = SeededVisitsController(
        content(visits: [visitFixture(property: propertyFixture())]),
      );
      await tester.pumpProviderApp(
        const VisitsView(),
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          storageScopeProvider.overrideWith(() => TestVisitScope(database)),
          visitsProvider.overrideWith(() => controller),
          pendingActionsProvider.overrideWith(() => pending),
          unownedActionsProvider.overrideWith((ref) async => []),
          swipeHistoryProvider.overrideWith(_IdleSwipes.new),
          propertyDetailsProvider(100).overrideWith(
            () => _SeededDetail(
              100,
              PropertyDetailsState(property: propertyFixture(), phase: PropertyDetailPhase.content),
            ),
          ),
        ],
      );
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('nothing selected shows the pane empty state', (tester) async {
      await pumpWide(tester);
      expect(find.text('Select a visit'), findsOneWidget);
      expect(find.byType(PropertyDetailsView), findsNothing);
      expect(tester.takeException(), isNull);
    });
    testWidgets('selecting a row shows its facts and actions over the home', (tester) async {
      await pumpWide(tester);
      await tester.tap(find.text('Test Property 100').first);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('qa.visits.pane.facts')), findsOneWidget);
      expect(find.byKey(const ValueKey('qa.visits.pane.reschedule')), findsOneWidget);
      expect(find.byType(PropertyDetailsView), findsOneWidget);
      // The pane shows the visit actions itself; the details booking bar would repeat them.
      expect(
        tester.widget<PropertyDetailsView>(find.byType(PropertyDetailsView)).showBookingBar,
        isFalse,
      );
      expect(find.text('Select a visit'), findsNothing);
      expect(
        tester.getTopLeft(find.byType(PropertyDetailsView)).dx,
        greaterThan(tester.getTopRight(find.byKey(const ValueKey('visit-1'))).dx),
      );
      await tester.tap(find.byKey(const ValueKey('qa.visits.pane.cancel')));
      await tester.pumpAndSettle();
      expect(find.byType(VisitEditDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
  for (final dark in [false, true]) {
    testWidgets('Hindi 2x text at 320 px ${dark ? 'dark' : 'light'} does not overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      pending = SeededPendingActions([
        PendingAction(
          operationId: 'op',
          scopeKey: 'a',
          kind: 'visit',
          payload: {'scheduled_date': '2030-01-01T00:00:00Z'},
          createdAt: DateTime.now(),
          status: PendingActionStatus.needsReconciliation,
        ),
      ]);
      controller = SeededVisitsController(
        content(
          visits: [
            visitFixture(property: propertyFixture()),
            visitFixture(id: 2, status: VisitStatus.completed, property: propertyFixture(id: 7)),
          ],
        ).copyWith(
          agent: VisitAgentState(value: agentFixture(), phase: VisitLoadPhase.content),
          nextCursor: 'next',
        ),
      );
      await tester.pumpProviderApp(
        const VisitsView(),
        locale: const Locale('hi', 'IN'),
        textScale: 2,
        theme: dark ? AppDesignTheme.dark() : AppDesignTheme.light(),
        overrides: [
          visitsProvider.overrideWith(() => controller),
          pendingActionsProvider.overrideWith(() => pending),
          unownedActionsProvider.overrideWith((ref) async => []),
        ],
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.drag(find.byKey(const ValueKey('qa.visits.list')), const Offset(0, -3000));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.drag(find.byKey(const ValueKey('qa.visits.list')), const Offset(0, 3000));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byType(OutlinedButton),
        200,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('qa.visits.list')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.ensureVisible(find.byType(OutlinedButton).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(OutlinedButton).first);
      await tester.pumpAndSettle();
      expect(find.byType(VisitEditDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextButton)).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('पिछले दौरे').first);
      await tester.pumpAndSettle();
      expect(find.byType(VisitCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  for (final dark in [false, true]) {
    testWidgets('Hindi 2x empty and error states fit 320 px ${dark ? 'dark' : 'light'}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final state in [
        content(visits: []),
        VisitsState(phase: VisitLoadPhase.failed, failure: NetworkException('offline')),
      ]) {
        controller = SeededVisitsController(state);
        await tester.pumpProviderApp(
          const VisitsView(),
          locale: const Locale('hi', 'IN'),
          textScale: 2,
          theme: dark ? AppDesignTheme.dark() : AppDesignTheme.light(),
          overrides: [
            visitsProvider.overrideWith(() => controller),
            pendingActionsProvider.overrideWith(() => pending),
            unownedActionsProvider.overrideWith((ref) async => []),
          ],
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    });
  }
}

class _SeededDetail extends PropertyDetailsController {
  _SeededDetail(super.propertyId, this.value);
  final PropertyDetailsState value;
  @override
  PropertyDetailsState build() => value;
  @override
  Future<void> refresh() async {}
}

class _IdleSwipes extends SwipeHistory {
  @override
  SwipeHistoryState build() => SwipeHistoryState();
}
