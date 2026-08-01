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

  /// Sets purchase/sale dates so the holding period is exactly [monthsAgo].
  void setHolding(int monthsAgo) {
    final today = DateUtils.dateOnly(DateTime.now());
    controller.saleDate.value = today;
    controller.purchaseDate.value = DateTime(today.year, today.month - monthsAgo, today.day);
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

    testWidgets('renders date fields with labels and formatted values', (tester) async {
      await pumpView(tester);

      expect(find.text('Purchase Date'), findsOneWidget);
      expect(find.text('Sale Date'), findsOneWidget);
      expect(find.byKey(const ValueKey('qa.tools.capital_gains.purchase_date')), findsOneWidget);
      expect(find.byKey(const ValueKey('qa.tools.capital_gains.sale_date')), findsOneWidget);
      expect(find.byIcon(Icons.calendar_today_outlined), findsNWidgets(2));

      String fmt(DateTime d) =>
          '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
      expect(find.text(fmt(controller.purchaseDate.value)), findsOneWidget);
      expect(find.text(fmt(controller.saleDate.value)), findsOneWidget);
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

    testWidgets('shows validation error when sale date is before purchase date', (tester) async {
      await pumpView(tester);

      // Set values directly on controller for reliability
      controller.purchasePriceController.text = '5000000';
      controller.salePriceController.text = '6000000';
      controller.purchaseDate.value = DateTime(2024, 6, 10);
      controller.saleDate.value = DateTime(2024, 6, 9);
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
      setHolding(60);
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
      setHolding(12);
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
      setHolding(60);
      await tester.pump();

      await tapCalculate(tester);

      expect(find.text('Recommended'), findsOneWidget);
    });

    testWidgets('shows exemptions info section in results', (tester) async {
      await pumpView(tester);

      controller.purchasePriceController.text = '5000000';
      controller.salePriceController.text = '8000000';
      setHolding(60);
      await tester.pump();

      await tapCalculate(tester);

      expect(find.text('Exemptions Available'), findsOneWidget);
    });

    testWidgets('refresh button clears all fields and results', (tester) async {
      await pumpView(tester);

      controller.purchasePriceController.text = '5000000';
      controller.salePriceController.text = '8000000';
      setHolding(60);
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

    testWidgets('tapping the purchase date field opens a date picker', (tester) async {
      await pumpView(tester);

      final field = find.byKey(const ValueKey('qa.tools.capital_gains.purchase_date'));
      await tester.ensureVisible(field);
      await tester.pumpAndSettle();
      await tester.tap(field);
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsNothing);
    });

    testWidgets('picking a date updates the field and the controller', (tester) async {
      await pumpView(tester);

      final field = find.byKey(const ValueKey('qa.tools.capital_gains.sale_date'));
      await tester.ensureVisible(field);
      await tester.pumpAndSettle();
      await tester.tap(field);
      await tester.pumpAndSettle();

      // Step back a month (every day there is selectable) and pick the 15th.
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsNothing);
      final picked = controller.saleDate.value;
      expect(picked.day, 15);
      expect(picked.isBefore(DateUtils.dateOnly(DateTime.now())), isTrue);
      // Stored date-only, and rendered back into the field.
      expect(picked.hour, 0);
      expect(
        find.text('15/${picked.month.toString().padLeft(2, '0')}/${picked.year}'),
        findsOneWidget,
      );
    });

    testWidgets('formats currency in Cr for large values', (tester) async {
      await pumpView(tester);

      controller.purchasePriceController.text = '100000000';
      controller.salePriceController.text = '150000000';
      setHolding(60);
      await tester.pump();

      await tapCalculate(tester);

      // Results should contain "Cr" suffix for crore values
      expect(find.textContaining(' Cr'), findsWidgets);
    });

    testWidgets('formats currency in L for lakh values', (tester) async {
      await pumpView(tester);

      controller.purchasePriceController.text = '5000000';
      controller.salePriceController.text = '8000000';
      setHolding(60);
      await tester.pump();

      await tapCalculate(tester);

      expect(find.textContaining(' L'), findsWidgets);
    });

    testWidgets('shows indexed cost and capital gain rows in long-term results', (tester) async {
      await pumpView(tester);

      controller.purchasePriceController.text = '5000000';
      controller.salePriceController.text = '8000000';
      setHolding(60);
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
      setHolding(12);
      await tester.pump();

      await tapCalculate(tester);

      expect(controller.isLongTerm.value, isFalse);
      expect(find.text('Estimated Tax'), findsOneWidget);
    });

    testWidgets('no longer renders the holding-period approximation caveat', (tester) async {
      await pumpView(tester);

      // The holding period is now exact, so the caveat was removed.
      expect(find.textContaining('approximat'), findsNothing);
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

    // ── P1: result colour contrast in both themes ─────────────────────────
    double ratio(Color fg, Color bg) {
      final la = fg.computeLuminance();
      final lb = bg.computeLuminance();
      final hi = la > lb ? la : lb;
      final lo = la > lb ? lb : la;
      return (hi + 0.05) / (lo + 0.05);
    }

    Future<List<double>> resultContrasts(WidgetTester tester, ThemeData theme) async {
      await tester.pumpApp(const CapitalGainsView(), theme: theme);
      await tester.pump();
      controller.purchasePriceController.text = '5000000';
      controller.salePriceController.text = '8000000';
      setHolding(60);
      await tester.pump();
      await tapCalculate(tester);
      final card = tester.widget<Card>(find.byType(Card).last);
      final bg = card.color!;
      // 18px tax-option amounts + the 11px "Recommended" label
      final texts = find
          .byWidgetPredicate(
            (w) => w is Text && (w.style?.fontSize == 18 || w.style?.fontSize == 11),
          )
          .evaluate()
          .map((e) => (e.widget as Text).style!.color!)
          .toList();
      return texts.map((c) => ratio(c, bg)).toList();
    }

    testWidgets('tax-option result text clears 3:1 in LIGHT mode', (tester) async {
      final ratios = await resultContrasts(tester, ThemeData.light());
      expect(ratios, isNotEmpty);
      final worst = ratios.reduce((a, b) => a < b ? a : b);
      expect(
        worst,
        greaterThanOrEqualTo(3.0),
        reason: 'light worst is ${worst.toStringAsFixed(2)}:1',
      );
    });

    testWidgets('tax-option result text clears 3:1 in DARK mode', (tester) async {
      final ratios = await resultContrasts(tester, ThemeData.dark());
      final worst = ratios.reduce((a, b) => a < b ? a : b);
      expect(
        worst,
        greaterThanOrEqualTo(3.0),
        reason: 'dark worst is ${worst.toStringAsFixed(2)}:1',
      );
    });
  });
}
