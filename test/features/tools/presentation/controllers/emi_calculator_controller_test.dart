// test/features/tools/presentation/controllers/emi_calculator_controller_test.dart
//
// Unit tests for [EmiCalculatorController]. Covers:
// - calculate() with valid inputs
// - Validation error for zero/negative principal, rate, tenure
// - toggleTenureUnit flips between years and months
// - clear() resets all state
// - Edge case: very long tenure

import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/features/tools/presentation/controllers/emi_calculator_controller.dart';

void main() {
  late ProviderContainer container;
  setUp(() {
    container = ProviderContainer();
    container.listen(emiCalculatorProvider, (_, _) {});
  });
  tearDown(() => container.dispose());
  EmiCalculatorController createController() => container.read(emiCalculatorProvider.notifier);
  EmiCalculatorState readState() => container.read(emiCalculatorProvider);

  group('EmiCalculatorController', () {
    // ── Valid inputs ─────────────────────────────────────────────────────

    test('calculate() with valid inputs sets EMI, totalPayment, totalInterest', () {
      final controller = createController();
      controller.updateInputs(principal: '1000000'); // 10L
      controller.updateInputs(rate: '8.5');
      controller.updateInputs(tenure: '20'); // 20 years

      controller.calculate();

      expect(readState().hasCalculated, isTrue);
      expect((readState().validationKey ?? ''), isEmpty);
      // EMI for 10L @ 8.5% for 20 years ≈ ₹8678.23
      expect(readState().monthlyEmi, closeTo(8678.23, 1));
      // Total payment = EMI * 240 months
      expect(readState().totalPayment, closeTo(8678.23 * 240, 100));
      // Total interest = total payment - principal
      expect(readState().totalInterest, closeTo(readState().totalPayment - 1000000, 100));
    });

    // ── Validation errors ────────────────────────────────────────────────

    test('calculate() with zero principal shows validation error', () {
      final controller = createController();
      controller.updateInputs(principal: '0');
      controller.updateInputs(rate: '8.5');
      controller.updateInputs(tenure: '20');

      controller.calculate();

      expect(readState().hasCalculated, isFalse);
      expect((readState().validationKey ?? ''), isNotEmpty);
    });

    test('calculate() with negative rate shows validation error', () {
      final controller = createController();
      controller.updateInputs(principal: '1000000');
      controller.updateInputs(rate: '-5');
      controller.updateInputs(tenure: '20');

      controller.calculate();

      expect(readState().hasCalculated, isFalse);
      expect((readState().validationKey ?? ''), isNotEmpty);
    });

    // ── toggleTenureUnit ─────────────────────────────────────────────────

    test('toggleTenureUnit flips between years and months', () {
      final controller = createController();

      expect(readState().tenureInYears, isTrue);

      controller.toggleTenureUnit();
      expect(readState().tenureInYears, isFalse);

      controller.toggleTenureUnit();
      expect(readState().tenureInYears, isTrue);
    });

    test('toggleTenureUnit recalculates EMI when already calculated', () {
      final controller = createController();
      controller.updateInputs(principal: '1000000');
      controller.updateInputs(rate: '8.5');
      controller.updateInputs(tenure: '20'); // 20 years
      controller.calculate();

      final emiYears = readState().monthlyEmi;

      // Switch to months: 20 months is much shorter than 20 years
      controller.toggleTenureUnit();
      expect(readState().tenureInYears, isFalse);
      expect(readState().monthlyEmi, greaterThan(emiYears));
    });

    // ── clear() resets all state ─────────────────────────────────────────

    test('clear() resets all state to defaults', () {
      final controller = createController();
      controller.updateInputs(principal: '1000000');
      controller.updateInputs(rate: '8.5');
      controller.updateInputs(tenure: '20');
      controller.calculate();

      controller.clear();

      expect(readState().principal, isEmpty);
      expect(readState().rate, isEmpty);
      expect(readState().tenure, isEmpty);
      expect(readState().tenureInYears, isTrue);
      expect(readState().hasCalculated, isFalse);
      expect((readState().validationKey ?? ''), isEmpty);
      expect(readState().monthlyEmi, 0);
      expect(readState().totalInterest, 0);
      expect(readState().totalPayment, 0);
    });

    // ── Zero rate validation ──────────────────────────────────────────────

    test('calculate() with zero rate shows validation error', () {
      final controller = createController();
      controller.updateInputs(principal: '1000000');
      controller.updateInputs(rate: '0');
      controller.updateInputs(tenure: '20');

      controller.calculate();

      expect(readState().hasCalculated, isFalse);
      expect((readState().validationKey ?? ''), isNotEmpty);
    });

    // ── Zero tenure validation ────────────────────────────────────────────

    test('calculate() with zero tenure shows validation error', () {
      final controller = createController();
      controller.updateInputs(principal: '1000000');
      controller.updateInputs(rate: '8.5');
      controller.updateInputs(tenure: '0');

      controller.calculate();

      expect(readState().hasCalculated, isFalse);
      expect((readState().validationKey ?? ''), isNotEmpty);
    });

    // ── Negative principal validation ─────────────────────────────────────

    test('calculate() with negative principal shows validation error', () {
      final controller = createController();
      controller.updateInputs(principal: '-1000000');
      controller.updateInputs(rate: '8.5');
      controller.updateInputs(tenure: '20');

      controller.calculate();

      expect(readState().hasCalculated, isFalse);
      expect((readState().validationKey ?? ''), isNotEmpty);
    });

    // ── Negative tenure validation ────────────────────────────────────────

    test('calculate() with negative tenure shows validation error', () {
      final controller = createController();
      controller.updateInputs(principal: '1000000');
      controller.updateInputs(rate: '8.5');
      controller.updateInputs(tenure: '-5');

      controller.calculate();

      expect(readState().hasCalculated, isFalse);
      expect((readState().validationKey ?? ''), isNotEmpty);
    });

    // ── Non-numeric inputs ────────────────────────────────────────────────

    test('calculate() with non-numeric principal shows validation error', () {
      final controller = createController();
      controller.updateInputs(principal: 'abc');
      controller.updateInputs(rate: '8.5');
      controller.updateInputs(tenure: '20');

      controller.calculate();

      expect(readState().hasCalculated, isFalse);
      expect((readState().validationKey ?? ''), isNotEmpty);
    });

    // ── Empty inputs ──────────────────────────────────────────────────────

    test('calculate() with all empty inputs shows validation error', () {
      final controller = createController();

      controller.calculate();

      expect(readState().hasCalculated, isFalse);
      expect((readState().validationKey ?? ''), isNotEmpty);
    });

    // ── Tenure in months ──────────────────────────────────────────────────

    test('calculate() with tenure in months computes correctly', () {
      final controller = createController();
      controller.updateInputs(principal: '1000000');
      controller.updateInputs(rate: '8.5');
      controller.updateInputs(tenure: '240'); // 240 months = 20 years
      controller.setTenureInYears(false);

      controller.calculate();

      expect(readState().hasCalculated, isTrue);
      // Should match the 20-year calculation
      expect(readState().monthlyEmi, closeTo(8678.23, 1));
    });

    // ── toggleTenureUnit does not recalculate when not calculated ─────────

    test('toggleTenureUnit does not recalculate when hasCalculated is false', () {
      final controller = createController();
      controller.updateInputs(principal: '1000000');
      controller.updateInputs(rate: '8.5');
      controller.updateInputs(tenure: '20');

      controller.toggleTenureUnit();

      expect(readState().tenureInYears, isFalse);
      expect(readState().hasCalculated, isFalse);
      expect(readState().monthlyEmi, 0);
    });

    // ── Total payment = EMI * months ──────────────────────────────────────

    test('calculate() totalPayment equals EMI times months', () {
      final controller = createController();
      controller.updateInputs(principal: '500000');
      controller.updateInputs(rate: '10');
      controller.updateInputs(tenure: '15');

      controller.calculate();

      expect(readState().totalPayment, closeTo(readState().monthlyEmi * 15 * 12, 1));
    });

    // ── Total interest = total payment - principal ────────────────────────

    test('calculate() totalInterest equals totalPayment minus principal', () {
      final controller = createController();
      controller.updateInputs(principal: '500000');
      controller.updateInputs(rate: '10');
      controller.updateInputs(tenure: '15');

      controller.calculate();

      expect(readState().totalInterest, closeTo(readState().totalPayment - 500000, 1));
    });

    // ── Higher rate gives higher EMI ──────────────────────────────────────

    test('calculate() higher interest rate gives higher EMI', () {
      final controller = createController();
      controller.updateInputs(principal: '1000000');
      controller.updateInputs(tenure: '20');

      controller.updateInputs(rate: '8');
      controller.calculate();
      final emiAt8 = readState().monthlyEmi;

      controller.updateInputs(rate: '12');
      controller.calculate();
      final emiAt12 = readState().monthlyEmi;

      expect(emiAt12, greaterThan(emiAt8));
    });

    // ── Longer tenure gives lower EMI ─────────────────────────────────────

    test('calculate() longer tenure gives lower EMI', () {
      final controller = createController();
      controller.updateInputs(principal: '1000000');
      controller.updateInputs(rate: '8.5');

      controller.updateInputs(tenure: '10');
      controller.calculate();
      final emi10yr = readState().monthlyEmi;

      controller.updateInputs(tenure: '20');
      controller.calculate();
      final emi20yr = readState().monthlyEmi;

      expect(emi20yr, lessThan(emi10yr));
    });

    // ── Decimal rate works ────────────────────────────────────────────────

    test('calculate() with decimal rate works correctly', () {
      final controller = createController();
      controller.updateInputs(principal: '1000000');
      controller.updateInputs(rate: '8.75');
      controller.updateInputs(tenure: '20');

      controller.calculate();

      expect(readState().hasCalculated, isTrue);
      expect(readState().monthlyEmi, greaterThan(0));
    });

    // ── onClose disposes controllers ──────────────────────────────────────

    test('onClose disposes TextEditingControllers without error', () {
      container.invalidate(emiCalculatorProvider);
      expect(readState().hasCalculated, isFalse);
    });

    // ── Very short tenure (1 year) ────────────────────────────────────────

    test('calculate() with 1-year tenure computes correctly', () {
      final controller = createController();
      controller.updateInputs(principal: '1000000');
      controller.updateInputs(rate: '8.5');
      controller.updateInputs(tenure: '1');

      controller.calculate();

      expect(readState().hasCalculated, isTrue);
      expect(readState().monthlyEmi, greaterThan(80000));
    });

    // ── Very long tenure (30 years) ───────────────────────────────────────

    test('calculate() with 30-year tenure computes correctly', () {
      final controller = createController();
      controller.updateInputs(principal: '1000000');
      controller.updateInputs(rate: '8.5');
      controller.updateInputs(tenure: '30');

      controller.calculate();

      expect(readState().hasCalculated, isTrue);
      expect(readState().monthlyEmi, lessThan(10000));
    });

    // ── Overflow guards (P1) ──────────────────────────────────────────────
    //
    // pow(1+r, n) overflows to Infinity for an absurd n, and Infinity/Infinity
    // is NaN. NaN.round() then throws UnsupportedError inside build().

    test('tenure 999999 months is rejected, never publishing NaN', () {
      final controller = createController();
      controller.updateInputs(principal: '5000000');
      controller.updateInputs(rate: '8.5');
      controller.setTenureInYears(false);
      controller.updateInputs(tenure: '999999');

      controller.calculate();

      expect((readState().validationKey ?? ''), isNotEmpty);
      expect(readState().hasCalculated, isFalse);
      expect(readState().monthlyEmi.isNaN, isFalse);
      expect(readState().monthlyEmi.isFinite, isTrue);
      expect(readState().totalPayment.isFinite, isTrue);
      expect(readState().totalInterest.isFinite, isTrue);
    });

    test('tenure 999999 years is rejected too', () {
      final controller = createController();
      controller.updateInputs(principal: '5000000');
      controller.updateInputs(rate: '8.5');
      controller.updateInputs(tenure: '999999'); // years

      controller.calculate();

      expect((readState().validationKey ?? ''), isNotEmpty);
      expect(readState().hasCalculated, isFalse);
      expect(readState().monthlyEmi.isNaN, isFalse);
    });

    test('tenure exactly at the cap is accepted, one month past it is not', () {
      final controller = createController();
      controller.updateInputs(principal: '5000000');
      controller.updateInputs(rate: '8.5');
      controller.setTenureInYears(false);

      controller.updateInputs(tenure: '${EmiCalculatorController.maxTenureMonths}');
      controller.calculate();
      expect(readState().hasCalculated, isTrue);
      expect((readState().validationKey ?? ''), isEmpty);
      expect(readState().monthlyEmi.isFinite, isTrue);

      controller.updateInputs(tenure: '${EmiCalculatorController.maxTenureMonths + 1}');
      controller.calculate();
      expect(readState().hasCalculated, isFalse);
      expect((readState().validationKey ?? ''), isNotEmpty);
    });

    test('an absurd interest rate is rejected by the non-finite guard', () {
      final controller = createController();
      controller.updateInputs(principal: '5000000');
      controller.updateInputs(rate: '1e308'); // pow() overflows -> NaN
      controller.updateInputs(tenure: '20');

      controller.calculate();

      expect((readState().validationKey ?? ''), isNotEmpty);
      expect(readState().hasCalculated, isFalse);
      expect(readState().monthlyEmi.isNaN, isFalse);
    });

    test('toggling the unit past the cap surfaces a validation error, not NaN', () {
      final controller = createController();
      controller.updateInputs(principal: '5000000');
      controller.updateInputs(rate: '8.5');
      controller.setTenureInYears(false);
      controller.updateInputs(tenure: '600'); // 600 months = at the cap
      controller.calculate();
      expect(readState().hasCalculated, isTrue);

      controller.toggleTenureUnit(); // 600 YEARS = 7200 months, past the cap

      expect((readState().validationKey ?? ''), isNotEmpty);
      expect(readState().hasCalculated, isFalse);
      expect(readState().monthlyEmi.isNaN, isFalse);
    });

    // ── The EMI formula itself is correct and must stay that way ──────────

    test('EMI matches P*r*(1+r)^n / ((1+r)^n - 1) exactly', () {
      final controller = createController();
      const principal = 5000000.0;
      const annualRate = 8.5;
      const years = 20;
      controller.updateInputs(principal: '$principal');
      controller.updateInputs(rate: '$annualRate');
      controller.updateInputs(tenure: '$years');

      controller.calculate();

      const months = years * 12;
      const r = annualRate / 12 / 100;
      final factor = pow(1 + r, months);
      final expected = principal * r * factor / (factor - 1);

      expect(readState().hasCalculated, isTrue);
      // ₹50L @ 8.5% over 20 years = ₹43,391.16/month.
      expect(expected, closeTo(43391.16, 0.01));
      expect(readState().monthlyEmi, closeTo(expected, 1e-6));
      expect(readState().totalPayment, closeTo(expected * months, 1e-6));
      expect(readState().totalInterest, closeTo(expected * months - principal, 1e-6));
    });
  });
}
