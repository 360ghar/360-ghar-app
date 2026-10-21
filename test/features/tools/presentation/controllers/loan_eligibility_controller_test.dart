// test/features/tools/presentation/controllers/loan_eligibility_controller_test.dart
//
// Unit tests for [LoanEligibilityController]. Covers:
// - calculate() with valid inputs
// - Default age of 30 when age is empty
// - Zero income triggers validation error
// - High existing EMI exceeds FOIR → maxLoanAmount = 0
// - clear() resets all state

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/features/tools/presentation/controllers/loan_eligibility_controller.dart';

void main() {
  late ProviderContainer container;
  setUp(() {
    container = ProviderContainer();
    container.listen(loanEligibilityProvider, (_, _) {});
  });
  tearDown(() => container.dispose());
  LoanEligibilityController createController() => container.read(loanEligibilityProvider.notifier);
  LoanEligibilityState readState() => container.read(loanEligibilityProvider);

  group('LoanEligibilityController', () {
    // ── Valid inputs ─────────────────────────────────────────────────────

    test('calculate() with valid inputs sets maxLoanAmount, maxTenure, eligibleEmi', () {
      final controller = createController();
      controller.updateInputs(income: '100000'); // ₹1L/month
      controller.updateInputs(age: '30');
      controller.updateInputs(existingEmi: '0');

      controller.calculate();

      expect(readState().hasCalculated, isTrue);
      expect((readState().validationKey ?? ''), isEmpty);
      // FOIR 50% for credit score 750 → eligible EMI = 100000 * 0.50 = 50000
      expect(readState().eligibleEmi, closeTo(50000, 1));
      // Max tenure = 60 - 30 = 30 years
      expect(readState().maxTenure, 30);
      // Max loan should be positive
      expect(readState().maxLoanAmount, greaterThan(0));
    });

    // ── Default age ──────────────────────────────────────────────────────

    test('calculate() defaults age to 30 when age field is empty', () {
      final controller = createController();
      controller.updateInputs(income: '80000');
      controller.updateInputs(age: ''); // empty → defaults to 30
      controller.updateInputs(existingEmi: '0');

      controller.calculate();

      expect(readState().hasCalculated, isTrue);
      // 60 - 30 = 30
      expect(readState().maxTenure, 30);
    });

    // ── Zero income ──────────────────────────────────────────────────────

    test('calculate() with zero income shows validation error', () {
      final controller = createController();
      controller.updateInputs(income: '0');
      controller.updateInputs(age: '30');

      controller.calculate();

      expect(readState().hasCalculated, isFalse);
      expect((readState().validationKey ?? ''), isNotEmpty);
    });

    // ── High existing EMI exceeds FOIR ───────────────────────────────────

    test('calculate() returns zero loan when existing EMI exceeds FOIR', () {
      final controller = createController();
      controller.updateInputs(income: '50000'); // ₹50K/month
      controller.updateInputs(age: '35');
      controller.updateInputs(existingEmi: '30000'); // Existing EMI ₹30K

      controller.calculate();

      // FOIR = 50% of 50000 = 25000; 25000 - 30000 = -5000 → 0
      expect(readState().hasCalculated, isTrue);
      expect(readState().eligibleEmi, 0);
      expect(readState().maxLoanAmount, 0);
      expect(readState().maxTenure, 0);
    });

    // ── clear() resets all state ─────────────────────────────────────────

    test('clear() resets all state to defaults', () {
      final controller = createController();
      controller.updateInputs(income: '100000');
      controller.updateInputs(age: '40');
      controller.updateInputs(existingEmi: '10000');
      controller.setCreditScore(650);
      controller.calculate();

      controller.clear();

      expect(readState().income, isEmpty);
      expect(readState().age, isEmpty);
      expect(readState().existingEmi, isEmpty);
      expect(readState().creditScore, 750.0);
      expect(readState().interestRate, 8.5);
      expect(readState().hasCalculated, isFalse);
      expect((readState().validationKey ?? ''), isEmpty);
      expect(readState().maxLoanAmount, 0);
      expect(readState().maxTenure, 0);
      expect(readState().eligibleEmi, 0);
    });

    // ── Negative income validation ────────────────────────────────────────

    test('calculate() with negative income shows validation error', () {
      final controller = createController();
      controller.updateInputs(income: '-50000');
      controller.updateInputs(age: '30');

      controller.calculate();

      expect(readState().hasCalculated, isFalse);
      expect((readState().validationKey ?? ''), isNotEmpty);
    });

    // ── Non-numeric income ────────────────────────────────────────────────

    test('calculate() with non-numeric income shows validation error', () {
      final controller = createController();
      controller.updateInputs(income: 'abc');
      controller.updateInputs(age: '30');

      controller.calculate();

      expect(readState().hasCalculated, isFalse);
      expect((readState().validationKey ?? ''), isNotEmpty);
    });

    // ── Empty income ──────────────────────────────────────────────────────

    test('calculate() with empty income shows validation error', () {
      final controller = createController();
      controller.updateInputs(income: '');
      controller.updateInputs(age: '30');

      controller.calculate();

      expect(readState().hasCalculated, isFalse);
      expect((readState().validationKey ?? ''), isNotEmpty);
    });

    // ── Credit score 700-749 uses 45% FOIR ────────────────────────────────

    test('calculate() with credit score 720 uses 45% FOIR', () {
      final controller = createController();
      controller.updateInputs(income: '100000');
      controller.updateInputs(age: '30');
      controller.updateInputs(existingEmi: '0');
      controller.setCreditScore(720);

      controller.calculate();

      expect(readState().hasCalculated, isTrue);
      // 45% of 100000 = 45000
      expect(readState().eligibleEmi, closeTo(45000, 1));
    });

    // ── Credit score 650-699 uses 40% FOIR ────────────────────────────────

    test('calculate() with credit score 680 uses 40% FOIR', () {
      final controller = createController();
      controller.updateInputs(income: '100000');
      controller.updateInputs(age: '30');
      controller.updateInputs(existingEmi: '0');
      controller.setCreditScore(680);

      controller.calculate();

      expect(readState().hasCalculated, isTrue);
      // 40% of 100000 = 40000
      expect(readState().eligibleEmi, closeTo(40000, 1));
    });

    // ── Credit score below 650 uses 35% FOIR ──────────────────────────────

    test('calculate() with credit score 600 uses 35% FOIR', () {
      final controller = createController();
      controller.updateInputs(income: '100000');
      controller.updateInputs(age: '30');
      controller.updateInputs(existingEmi: '0');
      controller.setCreditScore(600);

      controller.calculate();

      expect(readState().hasCalculated, isTrue);
      // 35% of 100000 = 35000
      expect(readState().eligibleEmi, closeTo(35000, 1));
    });

    // ── Age clamping: minimum 5 years tenure ──────────────────────────────

    test('calculate() with age 58 clamps tenure to minimum 5 years', () {
      final controller = createController();
      controller.updateInputs(income: '100000');
      controller.updateInputs(age: '58'); // 60 - 58 = 2, clamped to 5
      controller.updateInputs(existingEmi: '0');

      controller.calculate();

      expect(readState().hasCalculated, isTrue);
      expect(readState().maxTenure, 5);
    });

    // ── Age clamping: maximum 30 years tenure ─────────────────────────────

    test('calculate() with age 25 gives max 30 years tenure', () {
      final controller = createController();
      controller.updateInputs(income: '100000');
      controller.updateInputs(age: '25'); // 60 - 25 = 35, clamped to 30
      controller.updateInputs(existingEmi: '0');

      controller.calculate();

      expect(readState().hasCalculated, isTrue);
      expect(readState().maxTenure, 30);
    });

    // ── Existing EMI exactly equals FOIR ──────────────────────────────────

    test('calculate() with existing EMI exactly equal to FOIR gives zero loan', () {
      final controller = createController();
      controller.updateInputs(income: '100000');
      controller.updateInputs(age: '30');
      controller.updateInputs(existingEmi: '50000'); // exactly 50% of 100000

      controller.calculate();

      expect(readState().hasCalculated, isTrue);
      expect(readState().eligibleEmi, 0);
      expect(readState().maxLoanAmount, 0);
      expect(readState().maxTenure, 0);
    });

    // ── Different interest rate affects loan amount ───────────────────────

    test('calculate() with higher interest rate gives lower loan amount', () {
      final controller = createController();
      controller.updateInputs(income: '100000');
      controller.updateInputs(age: '30');
      controller.updateInputs(existingEmi: '0');
      controller.setInterestRate(8.5);
      controller.calculate();
      final loanAt8_5 = readState().maxLoanAmount;

      controller.setInterestRate(12.0);
      controller.calculate();
      final loanAt12 = readState().maxLoanAmount;

      expect(loanAt12, lessThan(loanAt8_5));
    });

    // ── onClose disposes controllers ──────────────────────────────────────

    test('onClose disposes TextEditingControllers without error', () {
      container.invalidate(loanEligibilityProvider);
      expect(readState().hasCalculated, isFalse);
    });

    // ── Default existing EMI is 0 when empty ──────────────────────────────

    test('calculate() with empty existing EMI defaults to 0', () {
      final controller = createController();
      controller.updateInputs(income: '100000');
      controller.updateInputs(age: '30');
      controller.updateInputs(existingEmi: '');

      controller.calculate();

      expect(readState().hasCalculated, isTrue);
      expect(readState().eligibleEmi, closeTo(50000, 1));
    });

    // ── Credit score exactly 750 uses 50% FOIR ────────────────────────────

    test('calculate() with credit score exactly 750 uses 50% FOIR', () {
      final controller = createController();
      controller.updateInputs(income: '100000');
      controller.updateInputs(age: '30');
      controller.setCreditScore(750);

      controller.calculate();

      expect(readState().eligibleEmi, closeTo(50000, 1));
    });

    // ── Credit score exactly 700 uses 45% FOIR ────────────────────────────

    test('calculate() with credit score exactly 700 uses 45% FOIR', () {
      final controller = createController();
      controller.updateInputs(income: '100000');
      controller.updateInputs(age: '30');
      controller.setCreditScore(700);

      controller.calculate();

      expect(readState().eligibleEmi, closeTo(45000, 1));
    });

    // ── Credit score exactly 650 uses 40% FOIR ────────────────────────────

    test('calculate() with credit score exactly 650 uses 40% FOIR', () {
      final controller = createController();
      controller.updateInputs(income: '100000');
      controller.updateInputs(age: '30');
      controller.setCreditScore(650);

      controller.calculate();

      expect(readState().eligibleEmi, closeTo(40000, 1));
    });
  });
}
