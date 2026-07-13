// test/features/tools/presentation/controllers/loan_eligibility_controller_test.dart
//
// Unit tests for [LoanEligibilityController]. Covers:
// - calculate() with valid inputs
// - Default age of 30 when age is empty
// - Zero income triggers validation error
// - High existing EMI exceeds FOIR → maxLoanAmount = 0
// - clear() resets all state

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/features/tools/presentation/controllers/loan_eligibility_controller.dart';
import '../../../../helpers/getx_test_binding.dart';

void main() {
  setUp(() {
    GetxTestBinding.init();
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  LoanEligibilityController createController() {
    final c = LoanEligibilityController();
    c.onInit();
    return c;
  }

  group('LoanEligibilityController', () {
    // ── Valid inputs ─────────────────────────────────────────────────────

    test('calculate() with valid inputs sets maxLoanAmount, maxTenure, eligibleEmi', () {
      final controller = createController();
      controller.incomeController.text = '100000'; // ₹1L/month
      controller.ageController.text = '30';
      controller.existingEmiController.text = '0';

      controller.calculate();

      expect(controller.hasCalculated.value, isTrue);
      expect(controller.validationError.value, isEmpty);
      // FOIR 50% for credit score 750 → eligible EMI = 100000 * 0.50 = 50000
      expect(controller.eligibleEmi.value, closeTo(50000, 1));
      // Max tenure = 60 - 30 = 30 years
      expect(controller.maxTenure.value, 30);
      // Max loan should be positive
      expect(controller.maxLoanAmount.value, greaterThan(0));
    });

    // ── Default age ──────────────────────────────────────────────────────

    test('calculate() defaults age to 30 when age field is empty', () {
      final controller = createController();
      controller.incomeController.text = '80000';
      controller.ageController.text = ''; // empty → defaults to 30
      controller.existingEmiController.text = '0';

      controller.calculate();

      expect(controller.hasCalculated.value, isTrue);
      // 60 - 30 = 30
      expect(controller.maxTenure.value, 30);
    });

    // ── Zero income ──────────────────────────────────────────────────────

    test('calculate() with zero income shows validation error', () {
      final controller = createController();
      controller.incomeController.text = '0';
      controller.ageController.text = '30';

      controller.calculate();

      expect(controller.hasCalculated.value, isFalse);
      expect(controller.validationError.value, isNotEmpty);
    });

    // ── High existing EMI exceeds FOIR ───────────────────────────────────

    test('calculate() returns zero loan when existing EMI exceeds FOIR', () {
      final controller = createController();
      controller.incomeController.text = '50000'; // ₹50K/month
      controller.ageController.text = '35';
      controller.existingEmiController.text = '30000'; // Existing EMI ₹30K

      controller.calculate();

      // FOIR = 50% of 50000 = 25000; 25000 - 30000 = -5000 → 0
      expect(controller.hasCalculated.value, isTrue);
      expect(controller.eligibleEmi.value, 0);
      expect(controller.maxLoanAmount.value, 0);
      expect(controller.maxTenure.value, 0);
    });

    // ── clear() resets all state ─────────────────────────────────────────

    test('clear() resets all state to defaults', () {
      final controller = createController();
      controller.incomeController.text = '100000';
      controller.ageController.text = '40';
      controller.existingEmiController.text = '10000';
      controller.creditScore.value = 650;
      controller.calculate();

      controller.clear();

      expect(controller.incomeController.text, isEmpty);
      expect(controller.ageController.text, isEmpty);
      expect(controller.existingEmiController.text, isEmpty);
      expect(controller.creditScore.value, 750.0);
      expect(controller.interestRate.value, 8.5);
      expect(controller.hasCalculated.value, isFalse);
      expect(controller.validationError.value, isEmpty);
      expect(controller.maxLoanAmount.value, 0);
      expect(controller.maxTenure.value, 0);
      expect(controller.eligibleEmi.value, 0);
    });

    // ── Negative income validation ────────────────────────────────────────

    test('calculate() with negative income shows validation error', () {
      final controller = createController();
      controller.incomeController.text = '-50000';
      controller.ageController.text = '30';

      controller.calculate();

      expect(controller.hasCalculated.value, isFalse);
      expect(controller.validationError.value, isNotEmpty);
    });

    // ── Non-numeric income ────────────────────────────────────────────────

    test('calculate() with non-numeric income shows validation error', () {
      final controller = createController();
      controller.incomeController.text = 'abc';
      controller.ageController.text = '30';

      controller.calculate();

      expect(controller.hasCalculated.value, isFalse);
      expect(controller.validationError.value, isNotEmpty);
    });

    // ── Empty income ──────────────────────────────────────────────────────

    test('calculate() with empty income shows validation error', () {
      final controller = createController();
      controller.incomeController.text = '';
      controller.ageController.text = '30';

      controller.calculate();

      expect(controller.hasCalculated.value, isFalse);
      expect(controller.validationError.value, isNotEmpty);
    });

    // ── Credit score 700-749 uses 45% FOIR ────────────────────────────────

    test('calculate() with credit score 720 uses 45% FOIR', () {
      final controller = createController();
      controller.incomeController.text = '100000';
      controller.ageController.text = '30';
      controller.existingEmiController.text = '0';
      controller.creditScore.value = 720;

      controller.calculate();

      expect(controller.hasCalculated.value, isTrue);
      // 45% of 100000 = 45000
      expect(controller.eligibleEmi.value, closeTo(45000, 1));
    });

    // ── Credit score 650-699 uses 40% FOIR ────────────────────────────────

    test('calculate() with credit score 680 uses 40% FOIR', () {
      final controller = createController();
      controller.incomeController.text = '100000';
      controller.ageController.text = '30';
      controller.existingEmiController.text = '0';
      controller.creditScore.value = 680;

      controller.calculate();

      expect(controller.hasCalculated.value, isTrue);
      // 40% of 100000 = 40000
      expect(controller.eligibleEmi.value, closeTo(40000, 1));
    });

    // ── Credit score below 650 uses 35% FOIR ──────────────────────────────

    test('calculate() with credit score 600 uses 35% FOIR', () {
      final controller = createController();
      controller.incomeController.text = '100000';
      controller.ageController.text = '30';
      controller.existingEmiController.text = '0';
      controller.creditScore.value = 600;

      controller.calculate();

      expect(controller.hasCalculated.value, isTrue);
      // 35% of 100000 = 35000
      expect(controller.eligibleEmi.value, closeTo(35000, 1));
    });

    // ── Age clamping: minimum 5 years tenure ──────────────────────────────

    test('calculate() with age 58 clamps tenure to minimum 5 years', () {
      final controller = createController();
      controller.incomeController.text = '100000';
      controller.ageController.text = '58'; // 60 - 58 = 2, clamped to 5
      controller.existingEmiController.text = '0';

      controller.calculate();

      expect(controller.hasCalculated.value, isTrue);
      expect(controller.maxTenure.value, 5);
    });

    // ── Age clamping: maximum 30 years tenure ─────────────────────────────

    test('calculate() with age 25 gives max 30 years tenure', () {
      final controller = createController();
      controller.incomeController.text = '100000';
      controller.ageController.text = '25'; // 60 - 25 = 35, clamped to 30
      controller.existingEmiController.text = '0';

      controller.calculate();

      expect(controller.hasCalculated.value, isTrue);
      expect(controller.maxTenure.value, 30);
    });

    // ── Existing EMI exactly equals FOIR ──────────────────────────────────

    test('calculate() with existing EMI exactly equal to FOIR gives zero loan', () {
      final controller = createController();
      controller.incomeController.text = '100000';
      controller.ageController.text = '30';
      controller.existingEmiController.text = '50000'; // exactly 50% of 100000

      controller.calculate();

      expect(controller.hasCalculated.value, isTrue);
      expect(controller.eligibleEmi.value, 0);
      expect(controller.maxLoanAmount.value, 0);
      expect(controller.maxTenure.value, 0);
    });

    // ── Different interest rate affects loan amount ───────────────────────

    test('calculate() with higher interest rate gives lower loan amount', () {
      final controller = createController();
      controller.incomeController.text = '100000';
      controller.ageController.text = '30';
      controller.existingEmiController.text = '0';
      controller.interestRate.value = 8.5;
      controller.calculate();
      final loanAt8_5 = controller.maxLoanAmount.value;

      controller.interestRate.value = 12.0;
      controller.calculate();
      final loanAt12 = controller.maxLoanAmount.value;

      expect(loanAt12, lessThan(loanAt8_5));
    });

    // ── onClose disposes controllers ──────────────────────────────────────

    test('onClose disposes TextEditingControllers without error', () {
      final controller = createController();
      controller.onClose();
    });

    // ── Default existing EMI is 0 when empty ──────────────────────────────

    test('calculate() with empty existing EMI defaults to 0', () {
      final controller = createController();
      controller.incomeController.text = '100000';
      controller.ageController.text = '30';
      controller.existingEmiController.text = '';

      controller.calculate();

      expect(controller.hasCalculated.value, isTrue);
      expect(controller.eligibleEmi.value, closeTo(50000, 1));
    });

    // ── Credit score exactly 750 uses 50% FOIR ────────────────────────────

    test('calculate() with credit score exactly 750 uses 50% FOIR', () {
      final controller = createController();
      controller.incomeController.text = '100000';
      controller.ageController.text = '30';
      controller.creditScore.value = 750;

      controller.calculate();

      expect(controller.eligibleEmi.value, closeTo(50000, 1));
    });

    // ── Credit score exactly 700 uses 45% FOIR ────────────────────────────

    test('calculate() with credit score exactly 700 uses 45% FOIR', () {
      final controller = createController();
      controller.incomeController.text = '100000';
      controller.ageController.text = '30';
      controller.creditScore.value = 700;

      controller.calculate();

      expect(controller.eligibleEmi.value, closeTo(45000, 1));
    });

    // ── Credit score exactly 650 uses 40% FOIR ────────────────────────────

    test('calculate() with credit score exactly 650 uses 40% FOIR', () {
      final controller = createController();
      controller.incomeController.text = '100000';
      controller.ageController.text = '30';
      controller.creditScore.value = 650;

      controller.calculate();

      expect(controller.eligibleEmi.value, closeTo(40000, 1));
    });
  });
}
