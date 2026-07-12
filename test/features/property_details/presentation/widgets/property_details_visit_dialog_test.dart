import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/translations/app_translations.dart';
import 'package:ghar360/features/property_details/presentation/widgets/property_details_visit_dialog.dart';
import 'package:ghar360/features/visits/presentation/controllers/visits_controller.dart';

import '../../../../helpers/getx_test_binding.dart';

/// A lightweight fake [VisitsController] that overrides [bookVisit] to avoid
/// the real implementation's Get.find dependencies. The [isBookingVisit] field
/// is inherited from the parent and initialized to `false.obs`.
class FakeVisitsController extends VisitsController {
  bool bookVisitResult = true;
  int bookVisitCallCount = 0;
  String? lastNotes;

  @override
  Future<bool> bookVisit(
    dynamic property,
    DateTime visitDateTime, {
    String visitType = 'physical',
    String? notes,
    String contactPreference = 'phone',
    int guestsCount = 1,
  }) async {
    bookVisitCallCount++;
    lastNotes = notes;
    return bookVisitResult;
  }
}

PropertyModel _testProperty() {
  return PropertyModel(
    id: 1,
    title: 'Test Villa',
    basePrice: 5000000,
    propertyType: PropertyType.villa,
    purpose: PropertyPurpose.buy,
    isAvailable: true,
    viewCount: 0,
    likeCount: 0,
    interestCount: 0,
  );
}

void main() {
  setUp(() => GetxTestBinding.init());
  tearDown(() => GetxTestBinding.reset());

  Future<void> pumpHost(WidgetTester tester, FakeVisitsController controller) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        fallbackLocale: const Locale('en', 'US'),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showBookVisitDialog(context, _testProperty(), controller),
                  child: const Text('Open Dialog'),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  testWidgets('shows dialog with schedule visit title and property name', (tester) async {
    final controller = FakeVisitsController();
    await pumpHost(tester, controller);

    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Schedule Visit'), findsWidgets);
    expect(find.textContaining('Test Villa'), findsOneWidget);
  });

  testWidgets('shows date tile and notes text field', (tester) async {
    final controller = FakeVisitsController();
    await pumpHost(tester, controller);

    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.calendar_today), findsOneWidget);
    expect(find.text('Date'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('shows cancel and schedule buttons', (tester) async {
    final controller = FakeVisitsController();
    await pumpHost(tester, controller);

    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Cancel'), findsOneWidget);
    // The schedule button label appears in title and button.
    expect(find.text('Schedule Visit'), findsWidgets);
  });

  testWidgets('closes dialog when cancel is tapped', (tester) async {
    final controller = FakeVisitsController();
    await pumpHost(tester, controller);

    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('calls bookVisit when schedule button is tapped', (tester) async {
    final controller = FakeVisitsController();
    await pumpHost(tester, controller);

    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // Tap the "Schedule Visit" ElevatedButton in the dialog actions.
    final scheduleBtn = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(ElevatedButton),
    );
    await tester.tap(scheduleBtn);
    await tester.pumpAndSettle();

    expect(controller.bookVisitCallCount, 1);
  });

  testWidgets('passes notes from text field to bookVisit', (tester) async {
    final controller = FakeVisitsController();
    await pumpHost(tester, controller);

    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Need ground floor access');
    await tester.pumpAndSettle();

    final scheduleBtn = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(ElevatedButton),
    );
    await tester.tap(scheduleBtn);
    await tester.pumpAndSettle();

    expect(controller.lastNotes, 'Need ground floor access');
  });

  testWidgets('passes null notes when text field is empty', (tester) async {
    final controller = FakeVisitsController();
    await pumpHost(tester, controller);

    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    final scheduleBtn = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(ElevatedButton),
    );
    await tester.tap(scheduleBtn);
    await tester.pumpAndSettle();

    expect(controller.lastNotes, isNull);
  });

  testWidgets('closes dialog after successful booking', (tester) async {
    final controller = FakeVisitsController();
    controller.bookVisitResult = true;
    await pumpHost(tester, controller);

    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    final scheduleBtn = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(ElevatedButton),
    );
    await tester.tap(scheduleBtn);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('does not close dialog when booking fails', (tester) async {
    final controller = FakeVisitsController();
    controller.bookVisitResult = false;
    await pumpHost(tester, controller);

    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    final scheduleBtn = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(ElevatedButton),
    );
    await tester.tap(scheduleBtn);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
  });
}
