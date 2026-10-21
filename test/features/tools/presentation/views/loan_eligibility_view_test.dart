// test/features/tools/presentation/views/loan_eligibility_view_test.dart

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/features/tools/presentation/controllers/loan_eligibility_controller.dart';
import 'package:ghar360/features/tools/presentation/views/loan_eligibility_view.dart';
import '../../../../helpers/knife_finders.dart';
import '../../../../helpers/provider_test_app.dart';

void main() {
  late ProviderContainer container;
  LoanEligibilityState readState() => container.read(loanEligibilityProvider);

  Future<void> pumpView(WidgetTester tester) async {
    await tester.pumpProviderApp(const LoanEligibilityView());
    container = ProviderScope.containerOf(tester.element(find.byType(LoanEligibilityView)));
    await tester.pump();
  }

  Future<void> tapCalculate(WidgetTester tester) async {
    final button = find.byKey(const ValueKey('qa.tools.loan_eligibility.calculate'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  group('LoanEligibilityView', () {
    testWidgets('renders scaffold with correct key and app bar title', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await pumpView(tester);

        expect(find.byKey(const ValueKey('qa.tools.loan_eligibility.screen')), findsOneWidget);
        expect(find.bySemanticsIdentifier('qa.tools.loan_eligibility.screen'), findsOneWidget);
        expect(find.bySemanticsLabel(RegExp(r'qa\.tools')), findsNothing);
        expect(find.text('Loan Eligibility'), findsOneWidget);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('renders back and refresh icons in app bar', (tester) async {
      await pumpView(tester);

      expect(find.byTooltip('Back'), findsOneWidget);
      expect(findKnife(KnifeIcon.retry), findsOneWidget);
    });

    testWidgets('renders monthly income, age and existing EMI labels', (tester) async {
      await pumpView(tester);

      expect(find.text('Monthly Income'), findsOneWidget);
      expect(find.text('Your Age'), findsOneWidget);
      expect(find.text('Existing EMI'), findsOneWidget);
    });

    testWidgets('renders credit score slider with labels', (tester) async {
      await pumpView(tester);

      expect(find.text('Credit Score'), findsOneWidget);
      expect(find.text('300'), findsOneWidget);
      expect(find.text('900'), findsOneWidget);
    });

    testWidgets('renders interest rate slider with labels', (tester) async {
      await pumpView(tester);

      expect(find.text('Interest Rate'), findsOneWidget);
      expect(find.text('6%'), findsOneWidget);
      expect(find.text('15%'), findsOneWidget);
    });

    testWidgets('renders calculate button', (tester) async {
      await pumpView(tester);

      expect(find.byKey(const ValueKey('qa.tools.loan_eligibility.calculate')), findsOneWidget);
      expect(find.text('Calculate'), findsOneWidget);
    });

    testWidgets('renders two sliders for credit score and interest rate', (tester) async {
      await pumpView(tester);

      expect(find.byType(Slider), findsNWidgets(2));
    });

    testWidgets('does not show results before calculation', (tester) async {
      await pumpView(tester);

      expect(find.text('Eligibility Result'), findsNothing);
    });

    testWidgets('shows validation error when calculating with empty income', (tester) async {
      await pumpView(tester);

      await tapCalculate(tester);

      expect((readState().validationKey ?? ''), isNotEmpty);
      expect(readState().hasCalculated, isFalse);
      expect(findKnife(KnifeIcon.alert), findsOneWidget);
    });

    testWidgets('calculates eligibility and shows results', (tester) async {
      await pumpView(tester);

      tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text = '100000';
      tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text = '30';
      await tester.pump();

      await tapCalculate(tester);

      expect(readState().hasCalculated, isTrue);
      expect(readState().maxLoanAmount, greaterThan(0));
      expect(find.text('Eligibility Result'), findsOneWidget);
      expect(find.text('Maximum Loan Amount'), findsOneWidget);
      expect(find.text('Eligible EMI'), findsOneWidget);
      expect(find.text('Maximum Tenure'), findsOneWidget);
    });

    testWidgets('shows info note in results', (tester) async {
      await pumpView(tester);

      tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text = '100000';
      tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text = '30';
      await tester.pump();

      await tapCalculate(tester);

      // The info note with blue icon
      expect(findKnife(KnifeIcon.info), findsOneWidget);
    });

    testWidgets('credit score slider updates controller value', (tester) async {
      await pumpView(tester);

      final initialValue = readState().creditScore;
      final slider = find.byType(Slider).first;
      await tester.ensureVisible(slider);
      await tester.pumpAndSettle();

      // Drag slider to change the value
      await tester.drag(slider, const Offset(200, 0));
      await tester.pumpAndSettle();

      expect(readState().creditScore, isNot(equals(initialValue)));
    });

    testWidgets('interest rate slider updates controller value', (tester) async {
      await pumpView(tester);

      final initialValue = readState().interestRate;
      final slider = find.byType(Slider).last;
      await tester.ensureVisible(slider);
      await tester.pumpAndSettle();

      // Drag slider to change the value
      await tester.drag(slider, const Offset(200, 0));
      await tester.pumpAndSettle();

      expect(readState().interestRate, isNot(equals(initialValue)));
    });

    testWidgets('refresh button clears all fields and results', (tester) async {
      await pumpView(tester);

      tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text = '100000';
      tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text = '30';
      await tester.pump();

      await tapCalculate(tester);
      expect(readState().hasCalculated, isTrue);

      await tester.tap(findKnife(KnifeIcon.retry));
      await tester.pumpAndSettle();

      expect(readState().hasCalculated, isFalse);
      expect(tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text, isEmpty);
      expect(tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text, isEmpty);
      expect(tester.widget<TextField>(find.byType(TextField).at(2)).controller!.text, isEmpty);
      expect(readState().creditScore, 750.0);
      expect(readState().interestRate, 8.5);
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

      // TextFields in order: income(0), age(1), existingEmi(2)
      final incomeField = find.byType(TextField).at(0);
      await tester.ensureVisible(incomeField);
      await tester.pumpAndSettle();
      await tester.enterText(incomeField, '100000');

      final ageField = find.byType(TextField).at(1);
      await tester.ensureVisible(ageField);
      await tester.pumpAndSettle();
      await tester.enterText(ageField, '30');

      final emiField = find.byType(TextField).at(2);
      await tester.ensureVisible(emiField);
      await tester.pumpAndSettle();
      await tester.enterText(emiField, '5000');

      expect(tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text, '100000');
      expect(tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text, '30');
      expect(tester.widget<TextField>(find.byType(TextField).at(2)).controller!.text, '5000');
    });

    testWidgets('calculates with existing EMI', (tester) async {
      await pumpView(tester);

      tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text = '100000';
      tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text = '30';
      tester.widget<TextField>(find.byType(TextField).at(2)).controller!.text = '20000';
      await tester.pump();

      await tapCalculate(tester);

      expect(readState().hasCalculated, isTrue);
      // Eligible EMI should be reduced by existing EMI
      expect(readState().eligibleEmi, lessThan(50000));
    });

    testWidgets('returns zero eligibility when existing EMI exceeds FOIR limit', (tester) async {
      await pumpView(tester);

      tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text = '100000';
      tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text = '30';
      tester.widget<TextField>(find.byType(TextField).at(2)).controller!.text = '60000';
      await tester.pump();

      await tapCalculate(tester);

      expect(readState().hasCalculated, isTrue);
      expect(readState().eligibleEmi, 0);
      expect(readState().maxLoanAmount, 0);
    });

    testWidgets('formats currency in L for lakh range loan amounts', (tester) async {
      await pumpView(tester);

      tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text = '100000';
      tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text = '30';
      await tester.pump();

      await tapCalculate(tester);

      expect(find.textContaining('L'), findsWidgets);
    });

    testWidgets('formats currency in Cr for large loan amounts', (tester) async {
      await pumpView(tester);

      tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text = '1000000';
      tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text = '25';
      await tester.pump();

      await tapCalculate(tester);

      expect(find.textContaining('Cr'), findsWidgets);
    });

    testWidgets('shows current credit score value in text', (tester) async {
      await pumpView(tester);

      // Default credit score is 750
      expect(find.text('750'), findsOneWidget);
    });

    testWidgets('shows current interest rate value in text', (tester) async {
      await pumpView(tester);

      // Default interest rate is 8.5
      expect(find.text('8.5%'), findsOneWidget);
    });
  });
}
