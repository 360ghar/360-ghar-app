import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/property_details/presentation/widgets/property_details_visit_dialog.dart';
import 'package:ghar360/features/visits/data/visits_repository.dart';
import 'package:ghar360/features/visits/presentation/controllers/visits_controller.dart';
import '../../../../helpers/provider_test_app.dart';
import '../../../../helpers/visits_test_support.dart';

class DraftDatabase extends Fake implements AppDatabase {
  Map<String, dynamic>? draft;
  Object? failure;
  int saves = 0;
  @override
  Future<Map<String, dynamic>?> readDraft({
    required StorageScope scope,
    required String key,
  }) async => draft;
  @override
  Future<void> writeDraft({
    required StorageScope scope,
    required String key,
    required Map<String, Object?> value,
  }) async {
    if (failure != null) throw failure!;
    saves++;
    draft = Map.of(value);
  }

  @override
  Future<void> removeDraft({required StorageScope scope, required String key}) async {
    draft = null;
  }
}

void main() {
  late AppDatabase owner;
  late DraftDatabase drafts;
  late SeededVisitsController controller;
  setUp(() async {
    owner = await visitTestDatabase();
    drafts = DraftDatabase();
    controller = SeededVisitsController(VisitsState(phase: VisitLoadPhase.content));
  });
  tearDown(() async {
    await owner.close();
  });
  Future<void> open(WidgetTester tester, {double scale = 1}) async {
    await tester.pumpProviderApp(
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showBookVisitDialog(context, propertyFixture()),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
      textScale: scale,
      overrides: [
        appDatabaseProvider.overrideWithValue(drafts),
        storageScopeProvider.overrideWith(() => TestVisitScope(owner)),
        visitsProvider.overrideWith(() => controller),
      ],
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Schedule Visit'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows property title, date, time, notes, cancel and submit', (tester) async {
    await open(tester);
    expect(find.textContaining('Test Property 100'), findsOneWidget);
    expect(find.text('Date'), findsOneWidget);
    expect(find.text('Time'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Schedule Visit'), findsOneWidget);
  });
  testWidgets('cancel closes with notes controller disposed after route teardown', (tester) async {
    await open(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('booking sends property, future local date, and empty notes as null', (tester) async {
    await open(tester);
    await submit(tester);
    expect(controller.bookings, 1);
    expect(controller.lastProperty, 100);
    expect(controller.lastNotes, isNull);
    expect(controller.lastDate!.isAfter(DateTime.now()), true);
    expect(find.byType(AlertDialog), findsNothing);
    expect(drafts.draft, isNull);
  });
  testWidgets('notes and date persist before sending a booking', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), '  Need ground floor access  ');
    await submit(tester);
    expect(controller.lastNotes, 'Need ground floor access');
    expect(drafts.saves, greaterThan(0));
    expect(controller.bookings, 1);
  });
  testWidgets('failed booking keeps form and input, and allows explicit retry', (tester) async {
    controller.bookingResult = VisitFailed(NetworkException('raw socket details'));
    await open(tester);
    await tester.enterText(find.byType(TextField), 'Keep these notes');
    await submit(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Keep these notes'), findsOneWidget);
    expect(find.textContaining('raw socket'), findsNothing);
    expect(find.text('Network error. Please try again.'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Schedule Visit')).onPressed,
      isNotNull,
    );
    expect(drafts.draft!['notes'], 'Keep these notes');
  });
  testWidgets('unresolved booking is visibly unconfirmed and cannot blindly resubmit', (
    tester,
  ) async {
    controller.bookingResult = VisitUnresolved(
      PendingAction(
        operationId: 'op',
        scopeKey: 'a',
        kind: 'visit',
        payload: {},
        createdAt: DateTime.now(),
        status: PendingActionStatus.needsReconciliation,
      ),
    );
    await open(tester);
    await submit(tester);
    expect(find.text('Request saved for review'), findsOneWidget);
    expect(find.text('View Visits'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Schedule Visit'), findsNothing);
    expect(controller.bookings, 1);
    expect(drafts.draft, isNotNull);
  });
  testWidgets('disk failure keeps draft visible and never claims saved or sends POST', (
    tester,
  ) async {
    drafts.failure = StorageFailure('disk full');
    await open(tester);
    await tester.enterText(find.byType(TextField), 'Keep this');
    await submit(tester);
    expect(controller.bookings, 0);
    expect(find.text('Keep this'), findsOneWidget);
    expect(
      find.text('Could not save your request. Keep this form open and try again.'),
      findsOneWidget,
    );
    expect(find.text('Request saved for review'), findsNothing);
  });
  testWidgets('restores an account-owned draft after reopening', (tester) async {
    final date = DateTime.now().add(const Duration(days: 5));
    drafts.draft = {'date': date.toUtc().toIso8601String(), 'notes': 'Saved access notes'};
    await open(tester);
    expect(find.text('Saved access notes'), findsOneWidget);
    await submit(tester);
    expect(controller.lastNotes, 'Saved access notes');
    expect(controller.lastDate!.day, date.day);
  });
  testWidgets('date and time pickers open without losing notes', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), 'Notes');
    await tester.tap(find.text('Date'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(
      find.descendant(of: find.byType(DatePickerDialog), matching: find.text('Cancel')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Time'));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tester.tap(
      find.descendant(of: find.byType(TimePickerDialog), matching: find.text('Cancel')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Notes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('narrow large-text dialog scrolls with the keyboard', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 250);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await open(tester, scale: 1.8);
    expect(tester.takeException(), isNull);
    expect(find.byType(AlertDialog), findsOneWidget);
  });
}
