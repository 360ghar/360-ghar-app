// test/features/tools/presentation/controllers/capital_gains_controller_test.dart
//
// Unit tests for [CapitalGainsController]. Covers:
// - Holding period derived from REAL DATES, long-term iff > 24 months
// - The 24-month boundary (exactly 24 months is short-term)
// - The default screen state (purchase = today-2y, sale = today)
// - calculate() with LTCG (post-Budget-2024 dual 20%-indexed / 12.5%-flat)
// - calculate() with STCG (slab-rate estimate)
// - Sale date before purchase date validation
// - Amount validation and clear()

import 'package:flutter/material.dart';

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
    // ── Holding period: the P0 regression ────────────────────────────────
    //
    // Bought 15 Mar 2023, sold 20 Jun 2025 = 27 months = genuinely long-term.
    // A ₹10,00,000 gain must be taxed at 12.5% without indexation
    // (₹1,25,000), NOT at the 30% short-term slab (₹3,00,000).

    test('27-month holding is long-term and taxes a ₹10L gain at ₹1,25,000 not ₹3,00,000', () {
      final controller = createController();
      controller.purchasePriceController.text = '5000000';
      controller.salePriceController.text = '6000000';
      controller.purchaseDate.value = DateTime(2023, 3, 15);
      controller.saleDate.value = DateTime(2025, 6, 20);

      controller.calculate();

      expect(controller.isLongTerm.value, isTrue);
      // 12.5% of the ₹10,00,000 unindexed gain.
      expect(controller.taxWithoutIndexation.value, closeTo(125000, 0.01));
      // Emphatically NOT the 30% short-term slab figure.
      expect(controller.taxWithoutIndexation.value, isNot(closeTo(300000, 1)));
      // 20%-with-indexation alternative: CII 2023 = 348, CII 2025 = 363.
      // Indexed cost = 5000000 * 363/348 = 5,215,517.24
      // Indexed gain = 784,482.76 -> 20% = 156,896.55
      expect(controller.indexedCost.value, closeTo(5215517.24, 0.5));
      expect(controller.taxWithIndexation.value, closeTo(156896.55, 0.5));
      // 12.5% flat is the cheaper option here.
      expect(controller.taxWithoutIndexation.value, lessThan(controller.taxWithIndexation.value));
    });

    // ── The 24-month boundary, to the day ────────────────────────────────

    test('exactly 24 months is NOT long-term (bought 15 Jan 2023, sold 15 Jan 2025)', () {
      final controller = createController();
      controller.purchasePriceController.text = '5000000';
      controller.salePriceController.text = '6000000';
      controller.purchaseDate.value = DateTime(2023, 1, 15);
      controller.saleDate.value = DateTime(2025, 1, 15);

      controller.calculate();

      expect(controller.isLongTerm.value, isFalse);
    });

    test('24 months plus one day IS long-term (bought 15 Jan 2023, sold 16 Jan 2025)', () {
      final controller = createController();
      controller.purchasePriceController.text = '5000000';
      controller.salePriceController.text = '6000000';
      controller.purchaseDate.value = DateTime(2023, 1, 15);
      controller.saleDate.value = DateTime(2025, 1, 16);

      controller.calculate();

      expect(controller.isLongTerm.value, isTrue);
    });

    test('isLongTermHolding handles the month/day boundary across a year roll', () {
      const isLongTerm = CapitalGainsController.isLongTermHolding;
      final purchase = DateTime(2023, 1, 15);

      expect(isLongTerm(purchase, DateTime(2025, 1, 14)), isFalse);
      expect(isLongTerm(purchase, DateTime(2025, 1, 15)), isFalse);
      expect(isLongTerm(purchase, DateTime(2025, 1, 16)), isTrue);
      // Month-end purchase: 31 Aug 2023 + 24 months = 31 Aug 2025.
      expect(isLongTerm(DateTime(2023, 8, 31), DateTime(2025, 8, 31)), isFalse);
      expect(isLongTerm(DateTime(2023, 8, 31), DateTime(2025, 9, 1)), isTrue);
      // A time-of-day component on the sale date must not tip the boundary.
      expect(isLongTerm(purchase, DateTime(2025, 1, 15, 23, 59)), isFalse);
    });

    // ── Default screen state ─────────────────────────────────────────────

    test('default state: purchase = today-2y, sale = today, both date-only', () {
      final controller = createController();
      final today = DateUtils.dateOnly(DateTime.now());

      expect(controller.saleDate.value, today);
      expect(controller.purchaseDate.value, DateTime(today.year - 2, today.month, today.day));
      // Date-only: no stray time component to tip the 24-month boundary.
      expect(controller.saleDate.value.hour, 0);
      expect(controller.purchaseDate.value.hour, 0);
    });

    test('default state calculates as short-term (exactly 24 months, not > 24)', () {
      final controller = createController();
      controller.purchasePriceController.text = '5000000';
      controller.salePriceController.text = '6000000';

      controller.calculate();

      expect(controller.hasCalculated.value, isTrue);
      expect(controller.isLongTerm.value, isFalse);
      // 30% slab estimate on the ₹10,00,000 gain.
      expect(controller.taxWithIndexation.value, closeTo(300000, 1));
    });

    test('default state flips to long-term when purchase is one day earlier', () {
      final controller = createController();
      controller.purchasePriceController.text = '5000000';
      controller.salePriceController.text = '6000000';
      controller.purchaseDate.value = controller.purchaseDate.value.subtract(
        const Duration(days: 1),
      );

      controller.calculate();

      expect(controller.isLongTerm.value, isTrue);
    });

    // ── Sale date before purchase date ───────────────────────────────────

    test('calculate() with sale date before purchase date shows validation error', () {
      final controller = createController();
      controller.purchasePriceController.text = '2000000';
      controller.salePriceController.text = '5000000';
      controller.purchaseDate.value = DateTime(2024, 6, 10);
      controller.saleDate.value = DateTime(2024, 6, 9);

      controller.calculate();

      expect(controller.hasCalculated.value, isFalse);
      expect(controller.validationError.value, isNotEmpty);
    });

    test('calculate() with sale date equal to purchase date is allowed (short-term)', () {
      final controller = createController();
      controller.purchasePriceController.text = '2000000';
      controller.salePriceController.text = '2500000';
      controller.purchaseDate.value = DateTime(2024, 6, 10);
      controller.saleDate.value = DateTime(2024, 6, 10);

      controller.calculate();

      expect(controller.hasCalculated.value, isTrue);
      expect(controller.validationError.value, isEmpty);
      expect(controller.isLongTerm.value, isFalse);
    });

    // ── Date setters normalise to date-only ──────────────────────────────

    test('setPurchaseDate and setSaleDate strip the time component', () {
      final controller = createController();

      controller.setPurchaseDate(DateTime(2020, 4, 5, 13, 45, 30));
      controller.setSaleDate(DateTime(2024, 9, 8, 22, 10));

      expect(controller.purchaseDate.value, DateTime(2020, 4, 5));
      expect(controller.saleDate.value, DateTime(2024, 9, 8));
    });

    // ── Selectable range for the pickers ─────────────────────────────────

    test('picker range spans 2001 through today', () {
      expect(CapitalGainsController.firstSelectableDate, DateTime(2001));
      expect(CapitalGainsController.lastSelectableDate, DateUtils.dateOnly(DateTime.now()));
    });

    // ── LTCG ─────────────────────────────────────────────────────────────

    test('calculate() with LTCG computes indexed cost and both tax options', () {
      final controller = createController();
      // Purchase ₹5L in 2010 (CII 167), sale ₹50L in 2024 (CII 363).
      controller.purchasePriceController.text = '500000';
      controller.salePriceController.text = '5000000';
      controller.improvementCostController.text = '100000';
      controller.purchaseDate.value = DateTime(2010, 6, 15);
      controller.saleDate.value = DateTime(2024, 6, 15);

      controller.calculate();

      expect(controller.hasCalculated.value, isTrue);
      expect(controller.validationError.value, isEmpty);
      expect(controller.isLongTerm.value, isTrue);
      // Indexed cost = (500000 + 100000) * 363/167 = 1,304,191.62
      expect(controller.indexedCost.value, closeTo(1304191.62, 0.5));
      expect(controller.capitalGain.value, greaterThan(0));
      expect(controller.taxWithIndexation.value, closeTo(controller.capitalGain.value * 0.20, 1));
      const gainWithoutIndexation = 5000000 - 500000 - 100000;
      expect(controller.taxWithoutIndexation.value, closeTo(gainWithoutIndexation * 0.125, 1));
    });

    test('calculate() LTCG with sale below indexed cost gives zero gain', () {
      final controller = createController();
      controller.purchasePriceController.text = '5000000';
      controller.salePriceController.text = '1000000';
      controller.purchaseDate.value = DateTime(2010, 6, 15);
      controller.saleDate.value = DateTime(2024, 6, 15);

      controller.calculate();

      expect(controller.isLongTerm.value, isTrue);
      expect(controller.capitalGain.value, 0);
      expect(controller.taxWithIndexation.value, 0);
    });

    test('calculate() LTCG with loss without indexation gives zero tax', () {
      final controller = createController();
      controller.purchasePriceController.text = '4000000';
      controller.salePriceController.text = '3000000';
      controller.improvementCostController.text = '500000';
      controller.purchaseDate.value = DateTime(2010, 6, 15);
      controller.saleDate.value = DateTime(2024, 6, 15);

      controller.calculate();

      expect(controller.isLongTerm.value, isTrue);
      expect(controller.taxWithoutIndexation.value, 0);
    });

    test('calculate() uses the CII fallback for a sale year beyond the table', () {
      final controller = createController();
      controller.purchasePriceController.text = '1000000';
      controller.salePriceController.text = '2000000';
      controller.purchaseDate.value = DateTime(2024, 1, 1);
      controller.saleDate.value = DateTime(2027, 1, 1); // 36 months; 2027 not in ciiValues

      controller.calculate();

      expect(controller.hasCalculated.value, isTrue);
      expect(controller.isLongTerm.value, isTrue);
      // Purchase CII 2024 = 363, sale falls back to 363, so indexed cost = cost.
      expect(controller.indexedCost.value, closeTo(1000000, 1));
    });

    test('ciiValues reuses the 2024 index for 2025', () {
      expect(CapitalGainsController.ciiValues[2025], CapitalGainsController.ciiValues[2024]);
    });

    test('calculate() with empty improvement cost defaults to 0', () {
      final controller = createController();
      controller.purchasePriceController.text = '1000000';
      controller.salePriceController.text = '2000000';
      controller.improvementCostController.text = '';
      controller.purchaseDate.value = DateTime(2010, 6, 15);
      controller.saleDate.value = DateTime(2024, 6, 15);

      controller.calculate();

      expect(controller.hasCalculated.value, isTrue);
      // 1000000 * 363/167; improvement contributes nothing.
      expect(controller.indexedCost.value, closeTo(2173652.69, 0.5));
    });

    // ── STCG ─────────────────────────────────────────────────────────────

    test('calculate() with STCG (12 months) uses the slab-rate estimate', () {
      final controller = createController();
      controller.purchasePriceController.text = '3000000';
      controller.salePriceController.text = '3500000';
      controller.improvementCostController.text = '100000';
      controller.purchaseDate.value = DateTime(2023, 6, 15);
      controller.saleDate.value = DateTime(2024, 6, 15);

      controller.calculate();

      expect(controller.hasCalculated.value, isTrue);
      expect(controller.isLongTerm.value, isFalse);
      expect(controller.indexedCost.value, closeTo(3100000, 1));
      expect(controller.capitalGain.value, closeTo(400000, 1));
      expect(controller.taxWithIndexation.value, closeTo(400000 * 0.30, 1));
      expect(controller.taxWithoutIndexation.value, closeTo(400000 * 0.30, 1));
    });

    test('calculate() STCG with sale below purchase gives zero gain', () {
      final controller = createController();
      controller.purchasePriceController.text = '3000000';
      controller.salePriceController.text = '2000000';
      controller.purchaseDate.value = DateTime(2023, 6, 15);
      controller.saleDate.value = DateTime(2024, 6, 15);

      controller.calculate();

      expect(controller.isLongTerm.value, isFalse);
      expect(controller.capitalGain.value, 0);
      expect(controller.taxWithIndexation.value, 0);
      expect(controller.taxWithoutIndexation.value, 0);
    });

    // ── Amount validation ────────────────────────────────────────────────

    test('calculate() with zero purchase price shows validation error', () {
      final controller = createController();
      controller.purchasePriceController.text = '0';
      controller.salePriceController.text = '5000000';

      controller.calculate();

      expect(controller.hasCalculated.value, isFalse);
      expect(controller.validationError.value, isNotEmpty);
    });

    test('calculate() with zero sale price shows validation error', () {
      final controller = createController();
      controller.purchasePriceController.text = '500000';
      controller.salePriceController.text = '0';

      controller.calculate();

      expect(controller.hasCalculated.value, isFalse);
      expect(controller.validationError.value, isNotEmpty);
    });

    test('calculate() with negative purchase price shows validation error', () {
      final controller = createController();
      controller.purchasePriceController.text = '-100000';
      controller.salePriceController.text = '500000';

      controller.calculate();

      expect(controller.hasCalculated.value, isFalse);
      expect(controller.validationError.value, isNotEmpty);
    });

    test('calculate() with non-numeric input shows validation error', () {
      final controller = createController();
      controller.purchasePriceController.text = 'abc';
      controller.salePriceController.text = '500000';

      controller.calculate();

      expect(controller.hasCalculated.value, isFalse);
      expect(controller.validationError.value, isNotEmpty);
    });

    test('calculate() with empty input fields shows validation error', () {
      final controller = createController();

      controller.calculate();

      expect(controller.hasCalculated.value, isFalse);
      expect(controller.validationError.value, isNotEmpty);
    });

    // ── clear() ──────────────────────────────────────────────────────────

    test('clear() resets all state to defaults', () {
      final controller = createController();
      controller.purchasePriceController.text = '500000';
      controller.salePriceController.text = '5000000';
      controller.improvementCostController.text = '100000';
      controller.purchaseDate.value = DateTime(2010, 6, 15);
      controller.saleDate.value = DateTime(2024, 6, 15);
      controller.calculate();

      controller.clear();

      final today = DateUtils.dateOnly(DateTime.now());
      expect(controller.purchasePriceController.text, isEmpty);
      expect(controller.salePriceController.text, isEmpty);
      expect(controller.improvementCostController.text, isEmpty);
      expect(controller.purchaseDate.value, DateTime(today.year - 2, today.month, today.day));
      expect(controller.saleDate.value, today);
      expect(controller.hasCalculated.value, isFalse);
      expect(controller.validationError.value, isEmpty);
      expect(controller.isLongTerm.value, isFalse);
      expect(controller.indexedCost.value, 0);
      expect(controller.capitalGain.value, 0);
      expect(controller.taxWithIndexation.value, 0);
      expect(controller.taxWithoutIndexation.value, 0);
    });

    test('onClose disposes TextEditingControllers without error', () {
      final controller = createController();
      controller.onClose();
    });
  });
}
