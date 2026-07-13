// test/features/tools/presentation/controllers/emi_calculator_controller_test.dart
//
// Unit tests for [EmiCalculatorController]. Covers:
// - calculate() with valid inputs
// - Validation error for zero/negative principal, rate, tenure
// - toggleTenureUnit flips between years and months
// - clear() resets all state
// - Edge case: very long tenure

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/features/tools/presentation/controllers/emi_calculator_controller.dart';
import '../../../../helpers/getx_test_binding.dart';

void main() {
  setUp(() {
    GetxTestBinding.init();
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  EmiCalculatorController createController() {
    final c = EmiCalculatorController();
    c.onInit();
    return c;
  }

  group('EmiCalculatorController', () {
    // ── Valid inputs ─────────────────────────────────────────────────────

    test('calculate() with valid inputs sets EMI, totalPayment, totalInterest', () {
      final controller = createController();
      controller.principalController.text = '1000000'; // 10L
      controller.rateController.text = '8.5';
      controller.tenureController.text = '20'; // 20 years

      controller.calculate();

      expect(controller.hasCalculated.value, isTrue);
      expect(controller.validationError.value, isEmpty);
      // EMI for 10L @ 8.5% for 20 years ≈ ₹8678.23
      expect(controller.monthlyEmi.value, closeTo(8678.23, 1));
      // Total payment = EMI * 240 months
      expect(controller.totalPayment.value, closeTo(8678.23 * 240, 100));
      // Total interest = total payment - principal
      expect(controller.totalInterest.value, closeTo(controller.totalPayment.value - 1000000, 100));
    });

    // ── Validation errors ────────────────────────────────────────────────

    test('calculate() with zero principal shows validation error', () {
      final controller = createController();
      controller.principalController.text = '0';
      controller.rateController.text = '8.5';
      controller.tenureController.text = '20';

      controller.calculate();

      expect(controller.hasCalculated.value, isFalse);
      expect(controller.validationError.value, isNotEmpty);
    });

    test('calculate() with negative rate shows validation error', () {
      final controller = createController();
      controller.principalController.text = '1000000';
      controller.rateController.text = '-5';
      controller.tenureController.text = '20';

      controller.calculate();

      expect(controller.hasCalculated.value, isFalse);
      expect(controller.validationError.value, isNotEmpty);
    });

    // ── toggleTenureUnit ─────────────────────────────────────────────────

    test('toggleTenureUnit flips between years and months', () {
      final controller = createController();

      expect(controller.tenureInYears.value, isTrue);

      controller.toggleTenureUnit();
      expect(controller.tenureInYears.value, isFalse);

      controller.toggleTenureUnit();
      expect(controller.tenureInYears.value, isTrue);
    });

    test('toggleTenureUnit recalculates EMI when already calculated', () {
      final controller = createController();
      controller.principalController.text = '1000000';
      controller.rateController.text = '8.5';
      controller.tenureController.text = '20'; // 20 years
      controller.calculate();

      final emiYears = controller.monthlyEmi.value;

      // Switch to months: 20 months is much shorter than 20 years
      controller.toggleTenureUnit();
      expect(controller.tenureInYears.value, isFalse);
      expect(controller.monthlyEmi.value, greaterThan(emiYears));
    });

    // ── clear() resets all state ─────────────────────────────────────────

    test('clear() resets all state to defaults', () {
      final controller = createController();
      controller.principalController.text = '1000000';
      controller.rateController.text = '8.5';
      controller.tenureController.text = '20';
      controller.calculate();

      controller.clear();

      expect(controller.principalController.text, isEmpty);
      expect(controller.rateController.text, isEmpty);
      expect(controller.tenureController.text, isEmpty);
      expect(controller.tenureInYears.value, isTrue);
      expect(controller.hasCalculated.value, isFalse);
      expect(controller.validationError.value, isEmpty);
      expect(controller.monthlyEmi.value, 0);
      expect(controller.totalInterest.value, 0);
      expect(controller.totalPayment.value, 0);
    });

    // ── Zero rate validation ──────────────────────────────────────────────

    test('calculate() with zero rate shows validation error', () {
      final controller = createController();
      controller.principalController.text = '1000000';
      controller.rateController.text = '0';
      controller.tenureController.text = '20';

      controller.calculate();

      expect(controller.hasCalculated.value, isFalse);
      expect(controller.validationError.value, isNotEmpty);
    });

    // ── Zero tenure validation ────────────────────────────────────────────

    test('calculate() with zero tenure shows validation error', () {
      final controller = createController();
      controller.principalController.text = '1000000';
      controller.rateController.text = '8.5';
      controller.tenureController.text = '0';

      controller.calculate();

      expect(controller.hasCalculated.value, isFalse);
      expect(controller.validationError.value, isNotEmpty);
    });

    // ── Negative principal validation ─────────────────────────────────────

    test('calculate() with negative principal shows validation error', () {
      final controller = createController();
      controller.principalController.text = '-1000000';
      controller.rateController.text = '8.5';
      controller.tenureController.text = '20';

      controller.calculate();

      expect(controller.hasCalculated.value, isFalse);
      expect(controller.validationError.value, isNotEmpty);
    });

    // ── Negative tenure validation ────────────────────────────────────────

    test('calculate() with negative tenure shows validation error', () {
      final controller = createController();
      controller.principalController.text = '1000000';
      controller.rateController.text = '8.5';
      controller.tenureController.text = '-5';

      controller.calculate();

      expect(controller.hasCalculated.value, isFalse);
      expect(controller.validationError.value, isNotEmpty);
    });

    // ── Non-numeric inputs ────────────────────────────────────────────────

    test('calculate() with non-numeric principal shows validation error', () {
      final controller = createController();
      controller.principalController.text = 'abc';
      controller.rateController.text = '8.5';
      controller.tenureController.text = '20';

      controller.calculate();

      expect(controller.hasCalculated.value, isFalse);
      expect(controller.validationError.value, isNotEmpty);
    });

    // ── Empty inputs ──────────────────────────────────────────────────────

    test('calculate() with all empty inputs shows validation error', () {
      final controller = createController();

      controller.calculate();

      expect(controller.hasCalculated.value, isFalse);
      expect(controller.validationError.value, isNotEmpty);
    });

    // ── Tenure in months ──────────────────────────────────────────────────

    test('calculate() with tenure in months computes correctly', () {
      final controller = createController();
      controller.principalController.text = '1000000';
      controller.rateController.text = '8.5';
      controller.tenureController.text = '240'; // 240 months = 20 years
      controller.tenureInYears.value = false;

      controller.calculate();

      expect(controller.hasCalculated.value, isTrue);
      // Should match the 20-year calculation
      expect(controller.monthlyEmi.value, closeTo(8678.23, 1));
    });

    // ── toggleTenureUnit does not recalculate when not calculated ─────────

    test('toggleTenureUnit does not recalculate when hasCalculated is false', () {
      final controller = createController();
      controller.principalController.text = '1000000';
      controller.rateController.text = '8.5';
      controller.tenureController.text = '20';

      controller.toggleTenureUnit();

      expect(controller.tenureInYears.value, isFalse);
      expect(controller.hasCalculated.value, isFalse);
      expect(controller.monthlyEmi.value, 0);
    });

    // ── Total payment = EMI * months ──────────────────────────────────────

    test('calculate() totalPayment equals EMI times months', () {
      final controller = createController();
      controller.principalController.text = '500000';
      controller.rateController.text = '10';
      controller.tenureController.text = '15';

      controller.calculate();

      expect(controller.totalPayment.value, closeTo(controller.monthlyEmi.value * 15 * 12, 1));
    });

    // ── Total interest = total payment - principal ────────────────────────

    test('calculate() totalInterest equals totalPayment minus principal', () {
      final controller = createController();
      controller.principalController.text = '500000';
      controller.rateController.text = '10';
      controller.tenureController.text = '15';

      controller.calculate();

      expect(controller.totalInterest.value, closeTo(controller.totalPayment.value - 500000, 1));
    });

    // ── Higher rate gives higher EMI ──────────────────────────────────────

    test('calculate() higher interest rate gives higher EMI', () {
      final controller = createController();
      controller.principalController.text = '1000000';
      controller.tenureController.text = '20';

      controller.rateController.text = '8';
      controller.calculate();
      final emiAt8 = controller.monthlyEmi.value;

      controller.rateController.text = '12';
      controller.calculate();
      final emiAt12 = controller.monthlyEmi.value;

      expect(emiAt12, greaterThan(emiAt8));
    });

    // ── Longer tenure gives lower EMI ─────────────────────────────────────

    test('calculate() longer tenure gives lower EMI', () {
      final controller = createController();
      controller.principalController.text = '1000000';
      controller.rateController.text = '8.5';

      controller.tenureController.text = '10';
      controller.calculate();
      final emi10yr = controller.monthlyEmi.value;

      controller.tenureController.text = '20';
      controller.calculate();
      final emi20yr = controller.monthlyEmi.value;

      expect(emi20yr, lessThan(emi10yr));
    });

    // ── Decimal rate works ────────────────────────────────────────────────

    test('calculate() with decimal rate works correctly', () {
      final controller = createController();
      controller.principalController.text = '1000000';
      controller.rateController.text = '8.75';
      controller.tenureController.text = '20';

      controller.calculate();

      expect(controller.hasCalculated.value, isTrue);
      expect(controller.monthlyEmi.value, greaterThan(0));
    });

    // ── onClose disposes controllers ──────────────────────────────────────

    test('onClose disposes TextEditingControllers without error', () {
      final controller = createController();
      controller.onClose();
    });

    // ── Very short tenure (1 year) ────────────────────────────────────────

    test('calculate() with 1-year tenure computes correctly', () {
      final controller = createController();
      controller.principalController.text = '1000000';
      controller.rateController.text = '8.5';
      controller.tenureController.text = '1';

      controller.calculate();

      expect(controller.hasCalculated.value, isTrue);
      expect(controller.monthlyEmi.value, greaterThan(80000));
    });

    // ── Very long tenure (30 years) ───────────────────────────────────────

    test('calculate() with 30-year tenure computes correctly', () {
      final controller = createController();
      controller.principalController.text = '1000000';
      controller.rateController.text = '8.5';
      controller.tenureController.text = '30';

      controller.calculate();

      expect(controller.hasCalculated.value, isTrue);
      expect(controller.monthlyEmi.value, lessThan(10000));
    });
  });
}
