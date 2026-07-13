// test/features/tools/presentation/views/loan_eligibility_view_test.dart

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:ghar360/features/tools/presentation/controllers/loan_eligibility_controller.dart';
import 'package:ghar360/features/tools/presentation/views/loan_eligibility_view.dart';
import '../../../../helpers/getx_test_binding.dart';
import '../../../../helpers/pump_app.dart';

void main() {
  late LoanEligibilityController controller;

  setUp(() {
    GetxTestBinding.init();
    controller = LoanEligibilityController();
    Get.put<LoanEligibilityController>(controller);
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  Future<void> pumpView(WidgetTester tester) async {
    await tester.pumpApp(const LoanEligibilityView());
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
      await pumpView(tester);

      expect(find.byKey(const ValueKey('qa.tools.loan_eligibility.screen')), findsOneWidget);
      expect(find.text('Loan Eligibility'), findsOneWidget);
    });

    testWidgets('renders back and refresh icons in app bar', (tester) async {
      await pumpView(tester);

      expect(find.byTooltip('Back'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
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

      expect(controller.validationError.value, isNotEmpty);
      expect(controller.hasCalculated.value, isFalse);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('calculates eligibility and shows results', (tester) async {
      await pumpView(tester);

      controller.incomeController.text = '100000';
      controller.ageController.text = '30';
      await tester.pump();

      await tapCalculate(tester);

      expect(controller.hasCalculated.value, isTrue);
      expect(controller.maxLoanAmount.value, greaterThan(0));
      expect(find.text('Eligibility Result'), findsOneWidget);
      expect(find.text('Maximum Loan Amount'), findsOneWidget);
      expect(find.text('Eligible EMI'), findsOneWidget);
      expect(find.text('Maximum Tenure'), findsOneWidget);
    });

    testWidgets('shows info note in results', (tester) async {
      await pumpView(tester);

      controller.incomeController.text = '100000';
      controller.ageController.text = '30';
      await tester.pump();

      await tapCalculate(tester);

      // The info note with blue icon
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('credit score slider updates controller value', (tester) async {
      await pumpView(tester);

      final initialValue = controller.creditScore.value;
      final slider = find.byType(Slider).first;
      await tester.ensureVisible(slider);
      await tester.pumpAndSettle();

      // Drag slider to change the value
      await tester.drag(slider, const Offset(200, 0));
      await tester.pumpAndSettle();

      expect(controller.creditScore.value, isNot(equals(initialValue)));
    });

    testWidgets('interest rate slider updates controller value', (tester) async {
      await pumpView(tester);

      final initialValue = controller.interestRate.value;
      final slider = find.byType(Slider).last;
      await tester.ensureVisible(slider);
      await tester.pumpAndSettle();

      // Drag slider to change the value
      await tester.drag(slider, const Offset(200, 0));
      await tester.pumpAndSettle();

      expect(controller.interestRate.value, isNot(equals(initialValue)));
    });

    testWidgets('refresh button clears all fields and results', (tester) async {
      await pumpView(tester);

      controller.incomeController.text = '100000';
      controller.ageController.text = '30';
      await tester.pump();

      await tapCalculate(tester);
      expect(controller.hasCalculated.value, isTrue);

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      expect(controller.hasCalculated.value, isFalse);
      expect(controller.incomeController.text, isEmpty);
      expect(controller.ageController.text, isEmpty);
      expect(controller.existingEmiController.text, isEmpty);
      expect(controller.creditScore.value, 750.0);
      expect(controller.interestRate.value, 8.5);
    });

    testWidgets('back button is wired to Get.back', (tester) async {
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

      expect(controller.incomeController.text, '100000');
      expect(controller.ageController.text, '30');
      expect(controller.existingEmiController.text, '5000');
    });

    testWidgets('calculates with existing EMI', (tester) async {
      await pumpView(tester);

      controller.incomeController.text = '100000';
      controller.ageController.text = '30';
      controller.existingEmiController.text = '20000';
      await tester.pump();

      await tapCalculate(tester);

      expect(controller.hasCalculated.value, isTrue);
      // Eligible EMI should be reduced by existing EMI
      expect(controller.eligibleEmi.value, lessThan(50000));
    });

    testWidgets('returns zero eligibility when existing EMI exceeds FOIR limit', (tester) async {
      await pumpView(tester);

      controller.incomeController.text = '100000';
      controller.ageController.text = '30';
      controller.existingEmiController.text = '60000';
      await tester.pump();

      await tapCalculate(tester);

      expect(controller.hasCalculated.value, isTrue);
      expect(controller.eligibleEmi.value, 0);
      expect(controller.maxLoanAmount.value, 0);
    });

    testWidgets('formats currency in L for lakh range loan amounts', (tester) async {
      await pumpView(tester);

      controller.incomeController.text = '100000';
      controller.ageController.text = '30';
      await tester.pump();

      await tapCalculate(tester);

      expect(find.textContaining('L'), findsWidgets);
    });

    testWidgets('formats currency in Cr for large loan amounts', (tester) async {
      await pumpView(tester);

      controller.incomeController.text = '1000000';
      controller.ageController.text = '25';
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
