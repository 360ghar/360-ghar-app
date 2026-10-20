// test/features/tools/presentation/views/capital_gains_view_test.dart

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/design/app_design_theme.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/features/tools/presentation/controllers/capital_gains_controller.dart';
import 'package:ghar360/features/tools/presentation/views/capital_gains_view.dart';
import '../../../../helpers/knife_finders.dart';
import '../../../../helpers/provider_test_app.dart';

void main() {
  late ProviderContainer container;
  CapitalGainsController getController() => container.read(capitalGainsProvider.notifier);
  CapitalGainsState readState() => container.read(capitalGainsProvider);

  Future<void> pumpView(WidgetTester tester) async {
    await tester.pumpProviderApp(const CapitalGainsView());
    container = ProviderScope.containerOf(tester.element(find.byType(CapitalGainsView)));
    await tester.pump();
  }

  /// Sets purchase/sale dates so the holding period is exactly [monthsAgo].
  void setHolding(int monthsAgo) {
    final today = DateUtils.dateOnly(DateTime.now());
    getController().setSaleDate(today);
    getController().setPurchaseDate(DateTime(today.year, today.month - monthsAgo, today.day));
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
      final semantics = tester.ensureSemantics();
      try {
        await pumpView(tester);

        expect(find.byKey(const ValueKey('qa.tools.capital_gains.screen')), findsOneWidget);
        expect(find.bySemanticsIdentifier('qa.tools.capital_gains.screen'), findsOneWidget);
        expect(find.bySemanticsLabel(RegExp(r'qa\.tools')), findsNothing);
        expect(find.text('Capital Gains Tax'), findsOneWidget);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('renders back and refresh icons in app bar', (tester) async {
      await pumpView(tester);

      expect(find.byTooltip('Back'), findsOneWidget);
      expect(findKnife(KnifeIcon.retry), findsOneWidget);
    });

    testWidgets('renders disclaimer info container', (tester) async {
      await pumpView(tester);

      expect(findKnife(KnifeIcon.info), findsOneWidget);
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
      expect(findKnife(KnifeIcon.calendar), findsNWidgets(2));

      String fmt(DateTime d) =>
          '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
      expect(find.text(fmt(readState().purchaseDate)), findsOneWidget);
      expect(find.text(fmt(readState().saleDate)), findsOneWidget);
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

      expect((readState().validationKey ?? ''), isNotEmpty);
      expect(readState().hasCalculated, isFalse);
      // The inline error widget (Container with error styling) should be present
      expect(findKnife(KnifeIcon.alert), findsOneWidget);
    });

    testWidgets('shows validation error when sale date is before purchase date', (tester) async {
      await pumpView(tester);

      // Set values directly on controller for reliability
      tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text = '5000000';
      tester.widget<TextField>(find.byType(TextField).at(2)).controller!.text = '6000000';
      getController().setPurchaseDate(DateTime(2024, 6, 10));
      getController().setSaleDate(DateTime(2024, 6, 9));
      await tester.pump();

      await tapCalculate(tester);

      expect((readState().validationKey ?? ''), isNotEmpty);
      expect(readState().hasCalculated, isFalse);
    });

    testWidgets('calculates long-term capital gains and shows results', (tester) async {
      await pumpView(tester);

      tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text = '5000000';
      tester.widget<TextField>(find.byType(TextField).at(2)).controller!.text = '8000000';
      tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text = '500000';
      setHolding(60);
      await tester.pump();

      await tapCalculate(tester);

      expect(readState().hasCalculated, isTrue);
      expect(readState().isLongTerm, isTrue);
      expect(find.text('Tax Calculation'), findsOneWidget);
      expect(find.text('Long Term'), findsOneWidget);
      expect(find.text('With Indexation'), findsOneWidget);
      expect(find.text('Without Indexation'), findsOneWidget);
    });

    testWidgets('calculates short-term capital gains and shows results', (tester) async {
      await pumpView(tester);

      tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text = '5000000';
      tester.widget<TextField>(find.byType(TextField).at(2)).controller!.text = '6000000';
      setHolding(12);
      await tester.pump();

      await tapCalculate(tester);

      expect(readState().hasCalculated, isTrue);
      expect(readState().isLongTerm, isFalse);
      expect(find.text('Short Term'), findsOneWidget);
      expect(find.text('Estimated Tax'), findsOneWidget);
    });

    testWidgets('shows lower-estimate label for the smaller illustrative figure in long-term', (
      tester,
    ) async {
      await pumpView(tester);

      tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text = '5000000';
      tester.widget<TextField>(find.byType(TextField).at(2)).controller!.text = '8000000';
      setHolding(60);
      await tester.pump();

      await tapCalculate(tester);

      expect(find.text('Lower estimate'), findsOneWidget);
    });

    testWidgets('shows exemptions info section in results', (tester) async {
      await pumpView(tester);

      tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text = '5000000';
      tester.widget<TextField>(find.byType(TextField).at(2)).controller!.text = '8000000';
      setHolding(60);
      await tester.pump();

      await tapCalculate(tester);

      expect(find.text('Exemptions Available'), findsOneWidget);
    });

    testWidgets('refresh button clears all fields and results', (tester) async {
      await pumpView(tester);

      tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text = '5000000';
      tester.widget<TextField>(find.byType(TextField).at(2)).controller!.text = '8000000';
      setHolding(60);
      await tester.pump();

      await tapCalculate(tester);
      expect(readState().hasCalculated, isTrue);

      await tester.tap(findKnife(KnifeIcon.retry));
      await tester.pumpAndSettle();

      expect(readState().hasCalculated, isFalse);
      expect(tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text, isEmpty);
      expect(tester.widget<TextField>(find.byType(TextField).at(2)).controller!.text, isEmpty);
      expect(tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text, isEmpty);
    });

    testWidgets('back button is wired to Navigator.maybePop', (tester) async {
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
      final picked = readState().saleDate;
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

      tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text = '100000000';
      tester.widget<TextField>(find.byType(TextField).at(2)).controller!.text = '150000000';
      setHolding(60);
      await tester.pump();

      await tapCalculate(tester);

      // Results should contain "Cr" suffix for crore values
      expect(find.textContaining(' Cr'), findsWidgets);
    });

    testWidgets('formats currency in L for lakh values', (tester) async {
      await pumpView(tester);

      tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text = '5000000';
      tester.widget<TextField>(find.byType(TextField).at(2)).controller!.text = '8000000';
      setHolding(60);
      await tester.pump();

      await tapCalculate(tester);

      expect(find.textContaining(' L'), findsWidgets);
    });

    testWidgets('shows indexed cost and capital gain rows in long-term results', (tester) async {
      await pumpView(tester);

      tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text = '5000000';
      tester.widget<TextField>(find.byType(TextField).at(2)).controller!.text = '8000000';
      setHolding(60);
      await tester.pump();

      await tapCalculate(tester);

      expect(find.text('Indexed Cost'), findsOneWidget);
      expect(find.text('Capital Gain'), findsOneWidget);
      expect(find.text('Tax Options'), findsOneWidget);
    });

    testWidgets('shows short term tax note for short-term results', (tester) async {
      await pumpView(tester);

      tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text = '5000000';
      tester.widget<TextField>(find.byType(TextField).at(2)).controller!.text = '6000000';
      setHolding(12);
      await tester.pump();

      await tapCalculate(tester);

      expect(readState().isLongTerm, isFalse);
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

      expect(tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text, '123456');
      expect(tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text, '789');
      expect(tester.widget<TextField>(find.byType(TextField).at(2)).controller!.text, '654321');
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
      await tester.pumpProviderApp(const CapitalGainsView(), theme: theme);
      container = ProviderScope.containerOf(tester.element(find.byType(CapitalGainsView)));
      await tester.pump();
      tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text = '5000000';
      tester.widget<TextField>(find.byType(TextField).at(2)).controller!.text = '8000000';
      setHolding(60);
      await tester.pump();
      await tapCalculate(tester);
      final page = tester.widget<Scaffold>(
        find.byKey(const ValueKey('qa.tools.capital_gains.screen')),
      );
      final bg = page.backgroundColor!;
      // Both tax-option amounts and the "Lower estimate" label.
      const key = 'qa.tools.capital_gains.tax_with_indexation';
      final texts = [
        for (final finder in [
          find.byKey(const ValueKey(key)),
          find.byKey(const ValueKey('qa.tools.capital_gains.tax_without_indexation')),
          find.byKey(const ValueKey('$key.lower')),
          find.byKey(const ValueKey('qa.tools.capital_gains.tax_without_indexation.lower')),
        ])
          ...tester.widgetList<Text>(finder).map((text) => text.style!.color!),
      ];
      expect(texts, hasLength(3));
      return texts.map((c) => ratio(c, bg)).toList();
    }

    testWidgets('tax-option result text clears 4.5:1 in LIGHT mode', (tester) async {
      final ratios = await resultContrasts(tester, AppDesignTheme.light());
      expect(ratios, isNotEmpty);
      final worst = ratios.reduce((a, b) => a < b ? a : b);
      expect(
        worst,
        greaterThanOrEqualTo(4.5),
        reason: 'light worst is ${worst.toStringAsFixed(2)}:1',
      );
    });

    testWidgets('tax-option result text clears 4.5:1 in DARK mode', (tester) async {
      final ratios = await resultContrasts(tester, AppDesignTheme.dark());
      final worst = ratios.reduce((a, b) => a < b ? a : b);
      expect(
        worst,
        greaterThanOrEqualTo(4.5),
        reason: 'dark worst is ${worst.toStringAsFixed(2)}:1',
      );
    });
  });
}
