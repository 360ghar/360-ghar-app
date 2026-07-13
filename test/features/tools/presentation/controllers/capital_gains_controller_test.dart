// test/features/tools/presentation/controllers/capital_gains_controller_test.dart
//
// Unit tests for [CapitalGainsController]. Covers:
// - calculate() with LTCG (holding > 24 months)
// - calculate() with STCG (holding <= 24 months)
// - Sale year < purchase year validation
// - Dynamic year defaults (purchaseYear = now-2, saleYear = now)
// - Zero purchase/sale price validation
// - clear() resets all state

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/features/tools/presentation/controllers/capital_gains_controller.dart';
import '../../../../helpers/getx_test_binding.dart';

void main() {
  setUp(() {
    GetxTestBinding.init();
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  CapitalGainsController createController() {
    final c = CapitalGainsController();
    c.onInit();
    return c;
  }

  group('CapitalGainsController', () {
    // ── Dynamic year defaults ────────────────────────────────────────────

    test('initial year defaults: purchaseYear = now-2, saleYear = now', () {
      final controller = createController();
      final now = DateTime.now().year;

      expect(controller.purchaseYear.value, now - 2);
      expect(controller.saleYear.value, now);
    });

    // ── LTCG (long-term) ─────────────────────────────────────────────────

    test('calculate() with LTCG (held > 24 months) computes indexed cost and taxes', () {
      final controller = createController();
      // Use small purchase price so indexed cost < sale price
      // Purchase ₹5L in 2010 (CII 167), Sale ₹50L in 2024 (CII 363)
      // Indexed cost = 500000 * 363/167 ≈ 1086826
      // Gain with indexation ≈ 5000000 - 1086826 ≈ 3913174
      controller.purchasePriceController.text = '500000';
      controller.salePriceController.text = '5000000';
      controller.improvementCostController.text = '100000';
      controller.purchaseYear.value = 2010;
      controller.saleYear.value = 2024;

      controller.calculate();

      expect(controller.hasCalculated.value, isTrue);
      expect(controller.validationError.value, isEmpty);
      expect(controller.isLongTerm.value, isTrue);
      // Indexed cost = (500000 + 100000) * 363/167 ≈ 1304191.62
      expect(controller.indexedCost.value, greaterThan(600000));
      // Capital gain = sale - indexed cost (positive for ₹50L sale)
      expect(controller.capitalGain.value, greaterThan(0));
      // Tax with indexation = 20% of gain
      expect(controller.taxWithIndexation.value, closeTo(controller.capitalGain.value * 0.20, 1));
      // Tax without indexation = 12.5% of (sale - purchase - improvement)
      final gainWithoutIndexation = 5000000 - 500000 - 100000;
      expect(controller.taxWithoutIndexation.value, closeTo(gainWithoutIndexation * 0.125, 1));
    });

    // ── STCG (short-term) ────────────────────────────────────────────────

    test('calculate() with STCG (held <= 24 months) uses slab rate', () {
      final controller = createController();
      controller.purchasePriceController.text = '3000000';
      controller.salePriceController.text = '3500000';
      controller.improvementCostController.text = '100000';
      controller.purchaseYear.value = 2023;
      controller.saleYear.value = 2024;

      controller.calculate();

      expect(controller.hasCalculated.value, isTrue);
      expect(controller.isLongTerm.value, isFalse);
      // Indexed cost = purchase + improvement (no indexation for STCG)
      expect(controller.indexedCost.value, closeTo(3100000, 1));
      // Capital gain = 3500000 - 3100000 = 400000
      expect(controller.capitalGain.value, closeTo(400000, 1));
      // Tax at 30% slab
      expect(controller.taxWithIndexation.value, closeTo(400000 * 0.30, 1));
      expect(controller.taxWithoutIndexation.value, closeTo(400000 * 0.30, 1));
    });

    // ── Sale year < purchase year ────────────────────────────────────────

    test('calculate() with sale year before purchase year shows validation error', () {
      final controller = createController();
      controller.purchasePriceController.text = '2000000';
      controller.salePriceController.text = '5000000';
      controller.purchaseYear.value = 2024;
      controller.saleYear.value = 2020;

      controller.calculate();

      expect(controller.hasCalculated.value, isFalse);
      expect(controller.validationError.value, isNotEmpty);
    });

    // ── Zero price validation ────────────────────────────────────────────

    test('calculate() with zero purchase price shows validation error', () {
      final controller = createController();
      controller.purchasePriceController.text = '0';
      controller.salePriceController.text = '5000000';

      controller.calculate();

      expect(controller.hasCalculated.value, isFalse);
      expect(controller.validationError.value, isNotEmpty);
    });

    // ── clear() resets all state ─────────────────────────────────────────

    test('clear() resets all state to defaults', () {
      final controller = createController();
      controller.purchasePriceController.text = '500000';
      controller.salePriceController.text = '5000000';
      controller.improvementCostController.text = '100000';
      controller.purchaseYear.value = 2010;
      controller.saleYear.value = 2024;
      controller.calculate();

      controller.clear();

      expect(controller.purchasePriceController.text, isEmpty);
      expect(controller.salePriceController.text, isEmpty);
      expect(controller.improvementCostController.text, isEmpty);
      expect(controller.purchaseYear.value, DateTime.now().year - 2);
      expect(controller.saleYear.value, DateTime.now().year);
      expect(controller.hasCalculated.value, isFalse);
      expect(controller.validationError.value, isEmpty);
      expect(controller.isLongTerm.value, isFalse);
      expect(controller.indexedCost.value, 0);
      expect(controller.capitalGain.value, 0);
      expect(controller.taxWithIndexation.value, 0);
      expect(controller.taxWithoutIndexation.value, 0);
    });

    // ── Zero sale price validation ────────────────────────────────────────

    test('calculate() with zero sale price shows validation error', () {
      final controller = createController();
      controller.purchasePriceController.text = '500000';
      controller.salePriceController.text = '0';

      controller.calculate();

      expect(controller.hasCalculated.value, isFalse);
      expect(controller.validationError.value, isNotEmpty);
    });

    // ── Negative price validation ─────────────────────────────────────────

    test('calculate() with negative purchase price shows validation error', () {
      final controller = createController();
      controller.purchasePriceController.text = '-100000';
      controller.salePriceController.text = '500000';

      controller.calculate();

      expect(controller.hasCalculated.value, isFalse);
      expect(controller.validationError.value, isNotEmpty);
    });

    // ── Non-numeric input defaults to 0 and shows validation ──────────────

    test('calculate() with non-numeric input shows validation error', () {
      final controller = createController();
      controller.purchasePriceController.text = 'abc';
      controller.salePriceController.text = '500000';

      controller.calculate();

      expect(controller.hasCalculated.value, isFalse);
      expect(controller.validationError.value, isNotEmpty);
    });

    // ── Empty input fields ────────────────────────────────────────────────

    test('calculate() with empty input fields shows validation error', () {
      final controller = createController();

      controller.calculate();

      expect(controller.hasCalculated.value, isFalse);
      expect(controller.validationError.value, isNotEmpty);
    });

    // ── Same purchase and sale year (short-term) ──────────────────────────

    test('calculate() with same purchase and sale year is short-term', () {
      final controller = createController();
      controller.purchasePriceController.text = '1000000';
      controller.salePriceController.text = '1200000';
      controller.purchaseYear.value = 2024;
      controller.saleYear.value = 2024;

      controller.calculate();

      expect(controller.hasCalculated.value, isTrue);
      expect(controller.isLongTerm.value, isFalse);
      expect(controller.capitalGain.value, closeTo(200000, 1));
    });

    // ── Long-term with exactly 3 year difference ──────────────────────────

    test('calculate() with 3-year holding period is long-term', () {
      final controller = createController();
      controller.purchasePriceController.text = '1000000';
      controller.salePriceController.text = '2000000';
      controller.purchaseYear.value = 2021;
      controller.saleYear.value = 2024;

      controller.calculate();

      expect(controller.hasCalculated.value, isTrue);
      expect(controller.isLongTerm.value, isTrue); // 36 months > 24
    });

    // ── Long-term with loss (sale < indexed cost) ─────────────────────────

    test('calculate() LTCG with sale below indexed cost gives zero gain', () {
      final controller = createController();
      // Purchase high, sale low → indexed cost > sale price
      controller.purchasePriceController.text = '5000000';
      controller.salePriceController.text = '1000000';
      controller.purchaseYear.value = 2010;
      controller.saleYear.value = 2024;

      controller.calculate();

      expect(controller.hasCalculated.value, isTrue);
      expect(controller.isLongTerm.value, isTrue);
      expect(controller.capitalGain.value, 0);
      expect(controller.taxWithIndexation.value, 0);
    });

    // ── STCG with loss (sale < purchase) ──────────────────────────────────

    test('calculate() STCG with sale below purchase gives zero gain', () {
      final controller = createController();
      controller.purchasePriceController.text = '3000000';
      controller.salePriceController.text = '2000000';
      controller.purchaseYear.value = 2023;
      controller.saleYear.value = 2024;

      controller.calculate();

      expect(controller.hasCalculated.value, isTrue);
      expect(controller.isLongTerm.value, isFalse);
      expect(controller.capitalGain.value, 0);
      expect(controller.taxWithIndexation.value, 0);
      expect(controller.taxWithoutIndexation.value, 0);
    });

    // ── Without indexation loss gives zero tax ────────────────────────────

    test('calculate() LTCG with loss without indexation gives zero tax', () {
      final controller = createController();
      // Sale price < purchase + improvement → no gain without indexation
      controller.purchasePriceController.text = '4000000';
      controller.salePriceController.text = '3000000';
      controller.improvementCostController.text = '500000';
      controller.purchaseYear.value = 2010;
      controller.saleYear.value = 2024;

      controller.calculate();

      expect(controller.hasCalculated.value, isTrue);
      expect(controller.isLongTerm.value, isTrue);
      expect(controller.taxWithoutIndexation.value, 0);
    });

    // ── availableYears list ───────────────────────────────────────────────

    test('availableYears contains years from 2001 to current year', () {
      final controller = createController();
      final now = DateTime.now().year;

      expect(controller.availableYears.first, 2001);
      expect(controller.availableYears.last, now);
      expect(controller.availableYears.length, now - 2000);
    });

    // ── CII fallback for years beyond 2025 ────────────────────────────────

    test('calculate() uses CII fallback for years beyond 2025', () {
      final controller = createController();
      controller.purchasePriceController.text = '1000000';
      controller.salePriceController.text = '2000000';
      // Use 2025 for both (CII 363)
      controller.purchaseYear.value = 2025;
      controller.saleYear.value = DateTime.now().year;

      controller.calculate();

      // Should not crash and should produce results
      expect(controller.hasCalculated.value, isTrue);
    });

    // ── onClose disposes controllers ──────────────────────────────────────

    test('onClose disposes TextEditingControllers without error', () {
      final controller = createController();
      controller.onClose();
    });

    // ── Improvement cost default 0 when empty ─────────────────────────────

    test('calculate() with empty improvement cost defaults to 0', () {
      final controller = createController();
      controller.purchasePriceController.text = '1000000';
      controller.salePriceController.text = '2000000';
      controller.improvementCostController.text = '';
      controller.purchaseYear.value = 2010;
      controller.saleYear.value = 2024;

      controller.calculate();

      expect(controller.hasCalculated.value, isTrue);
      // Indexed cost should only include purchase price (no improvement)
      expect(controller.indexedCost.value, greaterThan(0));
    });

    // ── 2-year holding period is short-term ───────────────────────────────

    test('calculate() with 2-year holding period is short-term', () {
      final controller = createController();
      controller.purchasePriceController.text = '1000000';
      controller.salePriceController.text = '1500000';
      controller.purchaseYear.value = 2022;
      controller.saleYear.value = 2024;

      controller.calculate();

      expect(controller.hasCalculated.value, isTrue);
      // 24 months is NOT > 24, so short-term
      expect(controller.isLongTerm.value, isFalse);
    });
  });
}
