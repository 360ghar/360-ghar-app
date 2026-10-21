// test/features/tools/presentation/views/emi_calculator_view_test.dart

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/design/app_design_theme.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/features/tools/presentation/controllers/emi_calculator_controller.dart';
import 'package:ghar360/features/tools/presentation/views/emi_calculator_view.dart';
import '../../../../helpers/knife_finders.dart';
import '../../../../helpers/provider_test_app.dart';

void main() {
  late ProviderContainer container;
  EmiCalculatorController getController() => container.read(emiCalculatorProvider.notifier);
  EmiCalculatorState readState() => container.read(emiCalculatorProvider);

  Future<void> pumpView(WidgetTester tester) async {
    await tester.pumpProviderApp(const EmiCalculatorView());
    container = ProviderScope.containerOf(tester.element(find.byType(EmiCalculatorView)));
    await tester.pump();
  }

  Future<void> tapCalculate(WidgetTester tester) async {
    final button = find.byKey(const ValueKey('qa.tools.emi.calculate'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  group('EmiCalculatorView', () {
    testWidgets('renders scaffold with correct key and app bar title', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await pumpView(tester);

        expect(find.byKey(const ValueKey('qa.tools.emi.screen')), findsOneWidget);
        expect(find.bySemanticsIdentifier('qa.tools.emi.screen'), findsOneWidget);
        expect(find.bySemanticsLabel(RegExp(r'qa\.tools')), findsNothing);
        expect(find.text('EMI Calculator'), findsOneWidget);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('renders back and refresh icons in app bar', (tester) async {
      await pumpView(tester);

      expect(find.byTooltip('Back'), findsOneWidget);
      expect(findKnife(KnifeIcon.retry), findsOneWidget);
    });

    testWidgets('renders loan amount, interest rate and tenure labels', (tester) async {
      await pumpView(tester);

      expect(find.text('Loan Amount'), findsOneWidget);
      expect(find.text('Interest Rate'), findsOneWidget);
      expect(find.text('Tenure'), findsOneWidget);
    });

    testWidgets('renders calculate button', (tester) async {
      await pumpView(tester);

      expect(find.byKey(const ValueKey('qa.tools.emi.calculate')), findsOneWidget);
      expect(find.text('Calculate'), findsOneWidget);
    });

    testWidgets('renders tenure segmented button with Years and Months', (tester) async {
      await pumpView(tester);

      expect(find.byType(SegmentedButton<bool>), findsOneWidget);
      expect(find.text('Years'), findsOneWidget);
      expect(find.text('Months'), findsOneWidget);
    });

    testWidgets('does not show results before calculation', (tester) async {
      await pumpView(tester);

      expect(find.text('EMI Calculation'), findsNothing);
    });

    testWidgets('shows validation error when calculating with empty fields', (tester) async {
      await pumpView(tester);

      await tapCalculate(tester);

      expect((readState().validationKey ?? ''), isNotEmpty);
      expect(readState().hasCalculated, isFalse);
      expect(findKnife(KnifeIcon.alert), findsOneWidget);
    });

    testWidgets('calculates EMI and shows results', (tester) async {
      await pumpView(tester);

      tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text = '5000000';
      tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text = '8.5';
      tester.widget<TextField>(find.byType(TextField).at(2)).controller!.text = '20';
      await tester.pump();

      await tapCalculate(tester);

      expect(readState().hasCalculated, isTrue);
      expect(readState().monthlyEmi, greaterThan(0));
      expect(find.text('EMI Calculation'), findsOneWidget);
      expect(find.text('Monthly EMI'), findsOneWidget);
      expect(find.text('Total Interest'), findsOneWidget);
      expect(find.text('Total Payment'), findsOneWidget);
    });

    testWidgets('shows breakdown chart after calculation', (tester) async {
      await pumpView(tester);

      tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text = '5000000';
      tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text = '8.5';
      tester.widget<TextField>(find.byType(TextField).at(2)).controller!.text = '20';
      await tester.pump();

      await tapCalculate(tester);

      expect(find.text('Breakdown'), findsOneWidget);
      expect(find.text('Principal'), findsOneWidget);
      expect(find.text('Interest'), findsOneWidget);
    });

    testWidgets('toggling tenure unit switches between years and months', (tester) async {
      await pumpView(tester);

      expect(readState().tenureInYears, isTrue);

      final segmentedButton = find.byType(SegmentedButton<bool>);
      await tester.ensureVisible(segmentedButton);
      await tester.pumpAndSettle();

      // Tap "Months" segment (the second segment, value: false)
      await tester.tap(find.text('Months'));
      await tester.pumpAndSettle();

      expect(readState().tenureInYears, isFalse);
    });

    testWidgets('toggling tenure unit recalculates if already calculated', (tester) async {
      await pumpView(tester);

      tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text = '5000000';
      tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text = '8.5';
      tester.widget<TextField>(find.byType(TextField).at(2)).controller!.text = '20';
      await tester.pump();

      await tapCalculate(tester);
      expect(readState().hasCalculated, isTrue);
      final emiInYears = readState().monthlyEmi;

      // Toggle to months - should recalculate
      await tester.ensureVisible(find.byType(SegmentedButton<bool>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Months'));
      await tester.pumpAndSettle();

      expect(readState().tenureInYears, isFalse);
      // With 20 months instead of 20 years, EMI should be higher
      expect(readState().monthlyEmi, greaterThan(emiInYears));
    });

    testWidgets('refresh button clears all fields and results', (tester) async {
      await pumpView(tester);

      tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text = '5000000';
      tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text = '8.5';
      tester.widget<TextField>(find.byType(TextField).at(2)).controller!.text = '20';
      await tester.pump();

      await tapCalculate(tester);
      expect(readState().hasCalculated, isTrue);

      await tester.tap(findKnife(KnifeIcon.retry));
      await tester.pumpAndSettle();

      expect(readState().hasCalculated, isFalse);
      expect(tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text, isEmpty);
      expect(tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text, isEmpty);
      expect(tester.widget<TextField>(find.byType(TextField).at(2)).controller!.text, isEmpty);
      expect(readState().tenureInYears, isTrue);
    });

    testWidgets('back button is wired to Navigator.maybePop', (tester) async {
      await pumpView(tester);

      final backButton = find.byTooltip('Back');
      expect(backButton, findsOneWidget);

      await tester.tap(backButton);
      await tester.pump();
    });

    testWidgets('entering text in fields updates controllers', (tester) async {
      await pumpView(tester);

      // TextFields in order: principal(0), rate(1), tenure(2)
      final principalField = find.byType(TextField).at(0);
      await tester.ensureVisible(principalField);
      await tester.pumpAndSettle();
      await tester.enterText(principalField, '5000000');

      final rateField = find.byType(TextField).at(1);
      await tester.ensureVisible(rateField);
      await tester.pumpAndSettle();
      await tester.enterText(rateField, '8.5');

      final tenureField = find.byType(TextField).at(2);
      await tester.ensureVisible(tenureField);
      await tester.pumpAndSettle();
      await tester.enterText(tenureField, '20');

      expect(tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text, '5000000');
      expect(tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text, '8.5');
      expect(tester.widget<TextField>(find.byType(TextField).at(2)).controller!.text, '20');
    });

    testWidgets('sub-lakh EMI renders Indian-grouped, never with a K suffix', (tester) async {
      await pumpView(tester);

      // ₹50L @ 8.5% over 20 years -> EMI ₹43,391.16 (below a lakh).
      tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text = '5000000';
      tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text = '8.5';
      tester.widget<TextField>(find.byType(TextField).at(2)).controller!.text = '20';
      await tester.pump();

      await tapCalculate(tester);

      // Was "43.4K" before the shared formatter; Indian grouping now.
      expect(find.text('\u20B943,391'), findsOneWidget);
      expect(find.textContaining('K'), findsNothing);
      // Larger figures still compact to lakh/crore.
      expect(find.text('\u20B954.14 L'), findsOneWidget); // total interest
      expect(find.text('\u20B91.04 Cr'), findsOneWidget); // total payment
    });

    testWidgets('formats currency in Cr for large total payment', (tester) async {
      await pumpView(tester);

      tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text = '50000000';
      tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text = '10';
      tester.widget<TextField>(find.byType(TextField).at(2)).controller!.text = '30';
      await tester.pump();

      await tapCalculate(tester);

      // ₹5Cr @ 10% over 30 years.
      expect(find.text('\u20B94.39 L'), findsOneWidget); // monthly EMI
      expect(find.text('\u20B910.8 Cr'), findsOneWidget); // total interest
      expect(find.text('\u20B915.8 Cr'), findsOneWidget); // total payment
    });

    testWidgets('shows validation error with only principal entered', (tester) async {
      await pumpView(tester);

      tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text = '5000000';
      await tester.pump();

      await tapCalculate(tester);

      expect((readState().validationKey ?? ''), isNotEmpty);
      expect(readState().hasCalculated, isFalse);
    });

    testWidgets('calculates with tenure in months', (tester) async {
      await pumpView(tester);

      tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text = '5000000';
      tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text = '8.5';
      tester.widget<TextField>(find.byType(TextField).at(2)).controller!.text = '240';
      getController().setTenureInYears(false);
      await tester.pump();

      await tapCalculate(tester);

      expect(readState().hasCalculated, isTrue);
      expect(readState().monthlyEmi, greaterThan(0));
    });

    // ── P1: NaN must never reach build() ──────────────────────────────────
    testWidgets('tenure 999999 months renders a validation error, not a crash', (tester) async {
      await pumpView(tester);
      tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text = '5000000';
      tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text = '8.5';
      getController().setTenureInYears(false);
      tester.widget<TextField>(find.byType(TextField).at(2)).controller!.text = '999999';
      await tester.pump();

      await tapCalculate(tester);

      expect(tester.takeException(), isNull);
      expect(find.textContaining('NaN'), findsNothing);
      expect(readState().hasCalculated, isFalse);
      expect(findKnife(KnifeIcon.alert), findsOneWidget);
      // trParams must actually substitute; a bad key would leave "@years" on screen.
      expect(find.text('Tenure cannot exceed 50 years'), findsOneWidget);
      expect(find.textContaining('@'), findsNothing);
    });

    testWidgets('tenure field caps input at 3 digits', (tester) async {
      await pumpView(tester);
      final tenureField = find.byType(TextField).at(2);
      await tester.ensureVisible(tenureField);
      await tester.pumpAndSettle();

      await tester.enterText(tenureField, '999999');

      expect(tester.widget<TextField>(find.byType(TextField).at(2)).controller!.text, '999');
    });

    // ── P1: hero EMI colour contrast in both themes ───────────────────────
    Future<double> heroContrast(WidgetTester tester, ThemeData theme) async {
      await tester.pumpProviderApp(const EmiCalculatorView(), theme: theme);
      container = ProviderScope.containerOf(tester.element(find.byType(EmiCalculatorView)));
      await tester.pump();
      tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text = '1000000';
      tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text = '8.5';
      tester.widget<TextField>(find.byType(TextField).at(2)).controller!.text = '20';
      await tester.pump();
      await tapCalculate(tester);
      final hero = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('qa.tools.emi.monthly')),
          matching: find.byType(Text),
        ),
      );
      final page = tester.widget<Scaffold>(find.byKey(const ValueKey('qa.tools.emi.screen')));
      final fg = hero.style!.color!;
      final bg = page.backgroundColor!;
      final la = fg.computeLuminance();
      final lb = bg.computeLuminance();
      final hi = la > lb ? la : lb;
      final lo = la > lb ? lb : la;
      return (hi + 0.05) / (lo + 0.05);
    }

    testWidgets('hero EMI text clears 4.5:1 in LIGHT mode', (tester) async {
      final ratio = await heroContrast(tester, AppDesignTheme.light());
      expect(
        ratio,
        greaterThanOrEqualTo(4.5),
        reason: 'light contrast is ${ratio.toStringAsFixed(2)}:1',
      );
    });

    testWidgets('hero EMI text clears 4.5:1 in DARK mode', (tester) async {
      final ratio = await heroContrast(tester, AppDesignTheme.dark());
      expect(
        ratio,
        greaterThanOrEqualTo(4.5),
        reason: 'dark contrast is ${ratio.toStringAsFixed(2)}:1',
      );
    });
  });
}
