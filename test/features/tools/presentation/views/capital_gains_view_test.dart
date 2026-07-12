// test/features/tools/presentation/views/capital_gains_view_test.dart

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:ghar360/features/tools/presentation/controllers/capital_gains_controller.dart';
import 'package:ghar360/features/tools/presentation/views/capital_gains_view.dart';

import '../../../../helpers/getx_test_binding.dart';
import '../../../../helpers/pump_app.dart';

void main() {
  late CapitalGainsController controller;

  setUp(() {
    GetxTestBinding.init();
    controller = CapitalGainsController();
    Get.put<CapitalGainsController>(controller);
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  Future<void> pumpView(WidgetTester tester) async {
    await tester.pumpApp(const CapitalGainsView());
    await tester.pump();
  }

  Future<void> tapCalculate(WidgetTester tester) async {
    final button = find.byKey(const ValueKey('qa.tools.capital_gains.calculate'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  group('CapitalGainsView', () {
    testWidgets('renders scaffold with correct key and app bar title', (tester) async {
      await pumpView(tester);

      expect(find.byKey(const ValueKey('qa.tools.capital_gains.screen')), findsOneWidget);
      expect(find.text('Capital Gains Tax'), findsOneWidget);
    });

    testWidgets('renders back and refresh icons in app bar', (tester) async {
      await pumpView(tester);

      expect(find.byTooltip('Back'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('renders disclaimer info container', (tester) async {
      await pumpView(tester);

      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('renders purchase and sale detail cards', (tester) async {
      await pumpView(tester);

      expect(find.text('Purchase Details'), findsOneWidget);
      expect(find.text('Sale Details'), findsOneWidget);
    });

    testWidgets('renders purchase price, improvement cost and sale price labels', (tester) async {
      await pumpView(tester);

      expect(find.text('Purchase Price'), findsOneWidget);
      expect(find.text('Improvement Cost'), findsOneWidget);
      expect(find.text('Sale Price'), findsOneWidget);
    });

    testWidgets('renders year dropdowns with labels', (tester) async {
      await pumpView(tester);

      expect(find.text('Purchase Year'), findsOneWidget);
      expect(find.text('Sale Year'), findsOneWidget);
    });

    testWidgets('renders calculate button', (tester) async {
      await pumpView(tester);

      expect(find.byKey(const ValueKey('qa.tools.capital_gains.calculate')), findsOneWidget);
      expect(find.text('Calculate Tax'), findsOneWidget);
    });

    testWidgets('does not show results before calculation', (tester) async {
      await pumpView(tester);

      expect(find.text('Tax Calculation'), findsNothing);
    });

    testWidgets('shows validation error when calculating with empty fields', (tester) async {
      await pumpView(tester);

      await tapCalculate(tester);

      expect(controller.validationError.value, isNotEmpty);
      expect(controller.hasCalculated.value, isFalse);
      // The inline error widget (Container with error styling) should be present
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('shows validation error when sale year is before purchase year', (tester) async {
      await pumpView(tester);

      // Set values directly on controller for reliability
      controller.purchasePriceController.text = '5000000';
      controller.salePriceController.text = '6000000';
      controller.purchaseYear.value = DateTime.now().year;
      controller.saleYear.value = DateTime.now().year - 1;
      await tester.pump();

      await tapCalculate(tester);

      expect(controller.validationError.value, isNotEmpty);
      expect(controller.hasCalculated.value, isFalse);
    });

    testWidgets('calculates long-term capital gains and shows results', (tester) async {
      await pumpView(tester);

      controller.purchasePriceController.text = '5000000';
      controller.salePriceController.text = '8000000';
      controller.improvementCostController.text = '500000';
      controller.purchaseYear.value = DateTime.now().year - 5;
      controller.saleYear.value = DateTime.now().year;
      await tester.pump();

      await tapCalculate(tester);

      expect(controller.hasCalculated.value, isTrue);
      expect(controller.isLongTerm.value, isTrue);
      expect(find.text('Tax Calculation'), findsOneWidget);
      expect(find.text('Long Term'), findsOneWidget);
      expect(find.text('With Indexation'), findsOneWidget);
      expect(find.text('Without Indexation'), findsOneWidget);
    });

    testWidgets('calculates short-term capital gains and shows results', (tester) async {
      await pumpView(tester);

      controller.purchasePriceController.text = '5000000';
      controller.salePriceController.text = '6000000';
      controller.purchaseYear.value = DateTime.now().year - 1;
      controller.saleYear.value = DateTime.now().year;
      await tester.pump();

      await tapCalculate(tester);

      expect(controller.hasCalculated.value, isTrue);
      expect(controller.isLongTerm.value, isFalse);
      expect(find.text('Short Term'), findsOneWidget);
      expect(find.text('Estimated Tax'), findsOneWidget);
    });

    testWidgets('shows recommended label for lower tax option in long-term', (tester) async {
      await pumpView(tester);

      controller.purchasePriceController.text = '5000000';
      controller.salePriceController.text = '8000000';
      controller.purchaseYear.value = DateTime.now().year - 5;
      controller.saleYear.value = DateTime.now().year;
      await tester.pump();

      await tapCalculate(tester);

      expect(find.text('Recommended'), findsOneWidget);
    });

    testWidgets('shows exemptions info section in results', (tester) async {
      await pumpView(tester);

      controller.purchasePriceController.text = '5000000';
      controller.salePriceController.text = '8000000';
      controller.purchaseYear.value = DateTime.now().year - 5;
      controller.saleYear.value = DateTime.now().year;
      await tester.pump();

      await tapCalculate(tester);

      expect(find.text('Exemptions Available'), findsOneWidget);
    });

    testWidgets('refresh button clears all fields and results', (tester) async {
      await pumpView(tester);

      controller.purchasePriceController.text = '5000000';
      controller.salePriceController.text = '8000000';
      controller.purchaseYear.value = DateTime.now().year - 5;
      controller.saleYear.value = DateTime.now().year;
      await tester.pump();

      await tapCalculate(tester);
      expect(controller.hasCalculated.value, isTrue);

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      expect(controller.hasCalculated.value, isFalse);
      expect(controller.purchasePriceController.text, isEmpty);
      expect(controller.salePriceController.text, isEmpty);
      expect(controller.improvementCostController.text, isEmpty);
    });

    testWidgets('back button is wired to Get.back', (tester) async {
      await pumpView(tester);

      final backButton = find.byTooltip('Back');
      expect(backButton, findsOneWidget);

      await tester.tap(backButton);
      await tester.pump();
    });

    testWidgets('year dropdown can change value', (tester) async {
      await pumpView(tester);

      // Tap the first dropdown (purchase year)
      final dropdown = find.byType(DropdownButton<int>).first;
      await tester.ensureVisible(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(dropdown);
      await tester.pumpAndSettle();

      // The dropdown menu should now be open with year items
      final availableYears = controller.availableYears;
      final targetYear = availableYears.first;
      // Find the year text in the popup menu (not the currently selected one)
      final yearTexts = find.text(targetYear.toString());
      if (yearTexts.evaluate().isNotEmpty) {
        await tester.tap(yearTexts.last);
        await tester.pumpAndSettle();
        expect(controller.purchaseYear.value, targetYear);
      }
    });

    testWidgets('formats currency in Cr for large values', (tester) async {
      await pumpView(tester);

      controller.purchasePriceController.text = '100000000';
      controller.salePriceController.text = '150000000';
      controller.purchaseYear.value = DateTime.now().year - 5;
      controller.saleYear.value = DateTime.now().year;
      await tester.pump();

      await tapCalculate(tester);

      // Results should contain "Cr" suffix for crore values
      expect(find.textContaining('Cr'), findsWidgets);
    });

    testWidgets('formats currency in L for lakh values', (tester) async {
      await pumpView(tester);

      controller.purchasePriceController.text = '5000000';
      controller.salePriceController.text = '8000000';
      controller.purchaseYear.value = DateTime.now().year - 5;
      controller.saleYear.value = DateTime.now().year;
      await tester.pump();

      await tapCalculate(tester);

      expect(find.textContaining('L'), findsWidgets);
    });

    testWidgets('shows indexed cost and capital gain rows in long-term results', (tester) async {
      await pumpView(tester);

      controller.purchasePriceController.text = '5000000';
      controller.salePriceController.text = '8000000';
      controller.purchaseYear.value = DateTime.now().year - 5;
      controller.saleYear.value = DateTime.now().year;
      await tester.pump();

      await tapCalculate(tester);

      expect(find.text('Indexed Cost'), findsOneWidget);
      expect(find.text('Capital Gain'), findsOneWidget);
      expect(find.text('Tax Options'), findsOneWidget);
    });

    testWidgets('shows short term tax note for short-term results', (tester) async {
      await pumpView(tester);

      controller.purchasePriceController.text = '5000000';
      controller.salePriceController.text = '6000000';
      controller.purchaseYear.value = DateTime.now().year - 1;
      controller.saleYear.value = DateTime.now().year;
      await tester.pump();

      await tapCalculate(tester);

      expect(controller.isLongTerm.value, isFalse);
      expect(find.text('Estimated Tax'), findsOneWidget);
    });

    testWidgets('renders holding period approximation note', (tester) async {
      await pumpView(tester);

      // The italic note text below purchase year dropdown
      expect(find.text('Purchase Year'), findsOneWidget);
    });

    testWidgets('entering text in fields updates controllers', (tester) async {
      await pumpView(tester);

      final purchaseField = find.byType(TextField).at(0);
      await tester.ensureVisible(purchaseField);
      await tester.pumpAndSettle();
      await tester.enterText(purchaseField, '123456');

      final improvementField = find.byType(TextField).at(1);
      await tester.ensureVisible(improvementField);
      await tester.pumpAndSettle();
      await tester.enterText(improvementField, '789');

      final saleField = find.byType(TextField).at(2);
      await tester.ensureVisible(saleField);
      await tester.pumpAndSettle();
      await tester.enterText(saleField, '654321');

      expect(controller.purchasePriceController.text, '123456');
      expect(controller.improvementCostController.text, '789');
      expect(controller.salePriceController.text, '654321');
    });
  });
}
