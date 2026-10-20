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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/features/tools/presentation/controllers/capital_gains_controller.dart';

void main() {
  late ProviderContainer container;
  setUp(() {
    container = ProviderContainer();
    container.listen(capitalGainsProvider, (_, _) {});
  });
  tearDown(() => container.dispose());
  CapitalGainsController createController() => container.read(capitalGainsProvider.notifier);
  CapitalGainsState readState() => container.read(capitalGainsProvider);

  group('CapitalGainsController', () {
    // ── Holding period: the P0 regression ────────────────────────────────
    //
    // Bought 15 Mar 2023, sold 20 Jun 2025 = 27 months = genuinely long-term.
    // A ₹10,00,000 gain must be taxed at 12.5% without indexation
    // (₹1,25,000), NOT at the 30% short-term slab (₹3,00,000).

    test('27-month holding is long-term and taxes a ₹10L gain at ₹1,25,000 not ₹3,00,000', () {
      final controller = createController();
      controller.updateInputs(purchasePrice: '5000000');
      controller.updateInputs(salePrice: '6000000');
      controller.setPurchaseDate(DateTime(2023, 3, 15));
      controller.setSaleDate(DateTime(2025, 6, 20));

      controller.calculate();

      expect(readState().isLongTerm, isTrue);
      // 12.5% of the ₹10,00,000 unindexed gain.
      expect(readState().taxWithoutIndexation, closeTo(125000, 0.01));
      // Emphatically NOT the 30% short-term slab figure.
      expect(readState().taxWithoutIndexation, isNot(closeTo(300000, 1)));
      // March 2023 belongs to FY2022-23 (331); June 2025 uses FY2025-26 (376).
      expect(readState().indexedCost, closeTo(5679758.31, 0.5));
      expect(readState().taxWithIndexation, closeTo(64048.34, 0.5));
      expect(readState().taxWithIndexation, lessThan(readState().taxWithoutIndexation));
    });

    // ── The 24-month boundary, to the day ────────────────────────────────

    test('exactly 24 months is NOT long-term (bought 15 Jan 2023, sold 15 Jan 2025)', () {
      final controller = createController();
      controller.updateInputs(purchasePrice: '5000000');
      controller.updateInputs(salePrice: '6000000');
      controller.setPurchaseDate(DateTime(2023, 1, 15));
      controller.setSaleDate(DateTime(2025, 1, 15));

      controller.calculate();

      expect(readState().isLongTerm, isFalse);
    });

    test('24 months plus one day IS long-term (bought 15 Jan 2023, sold 16 Jan 2025)', () {
      final controller = createController();
      controller.updateInputs(purchasePrice: '5000000');
      controller.updateInputs(salePrice: '6000000');
      controller.setPurchaseDate(DateTime(2023, 1, 15));
      controller.setSaleDate(DateTime(2025, 1, 16));

      controller.calculate();

      expect(readState().isLongTerm, isTrue);
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
      final today = DateUtils.dateOnly(DateTime.now());

      expect(readState().saleDate, today);
      expect(readState().purchaseDate, DateTime(today.year - 2, today.month, today.day));
      // Date-only: no stray time component to tip the 24-month boundary.
      expect(readState().saleDate.hour, 0);
      expect(readState().purchaseDate.hour, 0);
    });

    test('default state calculates as short-term (exactly 24 months, not > 24)', () {
      final controller = createController();
      controller.updateInputs(purchasePrice: '5000000');
      controller.updateInputs(salePrice: '6000000');

      controller.calculate();

      expect(readState().hasCalculated, isTrue);
      expect(readState().isLongTerm, isFalse);
      // 30% slab estimate on the ₹10,00,000 gain.
      expect(readState().taxWithIndexation, closeTo(300000, 1));
    });

    test('default state flips to long-term when purchase is one day earlier', () {
      final controller = createController();
      controller.updateInputs(purchasePrice: '5000000');
      controller.updateInputs(salePrice: '6000000');
      controller.setPurchaseDate(readState().purchaseDate.subtract(const Duration(days: 1)));

      controller.calculate();

      expect(readState().isLongTerm, isTrue);
    });

    // ── Sale date before purchase date ───────────────────────────────────

    test('calculate() with sale date before purchase date shows validation error', () {
      final controller = createController();
      controller.updateInputs(purchasePrice: '2000000');
      controller.updateInputs(salePrice: '5000000');
      controller.setPurchaseDate(DateTime(2024, 6, 10));
      controller.setSaleDate(DateTime(2024, 6, 9));

      controller.calculate();

      expect(readState().hasCalculated, isFalse);
      expect((readState().validationKey ?? ''), isNotEmpty);
    });

    test('calculate() with sale date equal to purchase date is allowed (short-term)', () {
      final controller = createController();
      controller.updateInputs(purchasePrice: '2000000');
      controller.updateInputs(salePrice: '2500000');
      controller.setPurchaseDate(DateTime(2024, 6, 10));
      controller.setSaleDate(DateTime(2024, 6, 10));

      controller.calculate();

      expect(readState().hasCalculated, isTrue);
      expect((readState().validationKey ?? ''), isEmpty);
      expect(readState().isLongTerm, isFalse);
    });

    // ── Date setters normalise to date-only ──────────────────────────────

    test('setPurchaseDate and setSaleDate strip the time component', () {
      final controller = createController();

      controller.setPurchaseDate(DateTime(2020, 4, 5, 13, 45, 30));
      controller.setSaleDate(DateTime(2024, 9, 8, 22, 10));

      expect(readState().purchaseDate, DateTime(2020, 4, 5));
      expect(readState().saleDate, DateTime(2024, 9, 8));
    });

    // ── Selectable range for the pickers ─────────────────────────────────

    test('picker range starts at FY2001-02 and ends today', () {
      expect(CapitalGainsController.firstSelectableDate, DateTime(2001, 4));
      expect(CapitalGainsController.lastSelectableDate, DateUtils.dateOnly(DateTime.now()));
    });

    // ── LTCG ─────────────────────────────────────────────────────────────

    test('calculate() with LTCG computes indexed cost and both tax options', () {
      final controller = createController();
      // Purchase ₹5L in 2010 (CII 167), sale ₹50L in 2024 (CII 363).
      controller.updateInputs(purchasePrice: '500000');
      controller.updateInputs(salePrice: '5000000');
      controller.updateInputs(improvementCost: '100000');
      controller.setPurchaseDate(DateTime(2010, 6, 15));
      controller.setSaleDate(DateTime(2024, 6, 15));

      controller.calculate();

      expect(readState().hasCalculated, isTrue);
      expect((readState().validationKey ?? ''), isEmpty);
      expect(readState().isLongTerm, isTrue);
      // Indexed cost = (500000 + 100000) * 363/167 = 1,304,191.62
      expect(readState().indexedCost, closeTo(1304191.62, 0.5));
      expect(readState().capitalGain, greaterThan(0));
      expect(readState().taxWithIndexation, closeTo(readState().capitalGain * 0.20, 1));
      const gainWithoutIndexation = 5000000 - 500000 - 100000;
      expect(readState().taxWithoutIndexation, closeTo(gainWithoutIndexation * 0.125, 1));
    });

    test('calculate() LTCG with sale below indexed cost gives zero gain', () {
      final controller = createController();
      controller.updateInputs(purchasePrice: '5000000');
      controller.updateInputs(salePrice: '1000000');
      controller.setPurchaseDate(DateTime(2010, 6, 15));
      controller.setSaleDate(DateTime(2024, 6, 15));

      controller.calculate();

      expect(readState().isLongTerm, isTrue);
      expect(readState().capitalGain, 0);
      expect(readState().taxWithIndexation, 0);
    });

    test('calculate() LTCG with loss without indexation gives zero tax', () {
      final controller = createController();
      controller.updateInputs(purchasePrice: '4000000');
      controller.updateInputs(salePrice: '3000000');
      controller.updateInputs(improvementCost: '500000');
      controller.setPurchaseDate(DateTime(2010, 6, 15));
      controller.setSaleDate(DateTime(2024, 6, 15));

      controller.calculate();

      expect(readState().isLongTerm, isTrue);
      expect(readState().taxWithoutIndexation, 0);
    });

    test('calculate() rejects future dates instead of silently substituting a CII', () {
      final controller = createController();
      controller.updateInputs(purchasePrice: '1000000');
      controller.updateInputs(salePrice: '2000000');
      controller.setPurchaseDate(DateTime(2024, 1, 1));
      controller.setSaleDate(DateTime(2027, 1, 1)); // 36 months; 2027 not in ciiValues

      controller.calculate();

      expect(readState().hasCalculated, isFalse);
      expect(readState().validationKey, 'capital_gains_dates_invalid');
      expect(readState().indexedCost, 0);
    });

    test('CII uses the published 2025 and 2026 financial-year indices', () {
      expect(CapitalGainsController.ciiValues[2025], 376);
      expect(CapitalGainsController.ciiValues[2026], 384);
      expect(CapitalGainsController.financialYear(DateTime(2025, 3, 31)), 2024);
      expect(CapitalGainsController.financialYear(DateTime(2025, 4, 1)), 2025);
    });

    test('calculate() with empty improvement cost defaults to 0', () {
      final controller = createController();
      controller.updateInputs(purchasePrice: '1000000');
      controller.updateInputs(salePrice: '2000000');
      controller.updateInputs(improvementCost: '');
      controller.setPurchaseDate(DateTime(2010, 6, 15));
      controller.setSaleDate(DateTime(2024, 6, 15));

      controller.calculate();

      expect(readState().hasCalculated, isTrue);
      // 1000000 * 363/167; improvement contributes nothing.
      expect(readState().indexedCost, closeTo(2173652.69, 0.5));
    });

    // ── STCG ─────────────────────────────────────────────────────────────

    test('calculate() with STCG (12 months) uses the slab-rate estimate', () {
      final controller = createController();
      controller.updateInputs(purchasePrice: '3000000');
      controller.updateInputs(salePrice: '3500000');
      controller.updateInputs(improvementCost: '100000');
      controller.setPurchaseDate(DateTime(2023, 6, 15));
      controller.setSaleDate(DateTime(2024, 6, 15));

      controller.calculate();

      expect(readState().hasCalculated, isTrue);
      expect(readState().isLongTerm, isFalse);
      expect(readState().indexedCost, closeTo(3100000, 1));
      expect(readState().capitalGain, closeTo(400000, 1));
      expect(readState().taxWithIndexation, closeTo(400000 * 0.30, 1));
      expect(readState().taxWithoutIndexation, closeTo(400000 * 0.30, 1));
    });

    test('calculate() STCG with sale below purchase gives zero gain', () {
      final controller = createController();
      controller.updateInputs(purchasePrice: '3000000');
      controller.updateInputs(salePrice: '2000000');
      controller.setPurchaseDate(DateTime(2023, 6, 15));
      controller.setSaleDate(DateTime(2024, 6, 15));

      controller.calculate();

      expect(readState().isLongTerm, isFalse);
      expect(readState().capitalGain, 0);
      expect(readState().taxWithIndexation, 0);
      expect(readState().taxWithoutIndexation, 0);
    });

    // ── Amount validation ────────────────────────────────────────────────

    test('calculate() with zero purchase price shows validation error', () {
      final controller = createController();
      controller.updateInputs(purchasePrice: '0');
      controller.updateInputs(salePrice: '5000000');

      controller.calculate();

      expect(readState().hasCalculated, isFalse);
      expect((readState().validationKey ?? ''), isNotEmpty);
    });

    test('calculate() with zero sale price shows validation error', () {
      final controller = createController();
      controller.updateInputs(purchasePrice: '500000');
      controller.updateInputs(salePrice: '0');

      controller.calculate();

      expect(readState().hasCalculated, isFalse);
      expect((readState().validationKey ?? ''), isNotEmpty);
    });

    test('calculate() with negative purchase price shows validation error', () {
      final controller = createController();
      controller.updateInputs(purchasePrice: '-100000');
      controller.updateInputs(salePrice: '500000');

      controller.calculate();

      expect(readState().hasCalculated, isFalse);
      expect((readState().validationKey ?? ''), isNotEmpty);
    });

    test('calculate() with non-numeric input shows validation error', () {
      final controller = createController();
      controller.updateInputs(purchasePrice: 'abc');
      controller.updateInputs(salePrice: '500000');

      controller.calculate();

      expect(readState().hasCalculated, isFalse);
      expect((readState().validationKey ?? ''), isNotEmpty);
    });

    test('calculate() with empty input fields shows validation error', () {
      final controller = createController();

      controller.calculate();

      expect(readState().hasCalculated, isFalse);
      expect((readState().validationKey ?? ''), isNotEmpty);
    });

    // ── clear() ──────────────────────────────────────────────────────────

    test('clear() resets all state to defaults', () {
      final controller = createController();
      controller.updateInputs(purchasePrice: '500000');
      controller.updateInputs(salePrice: '5000000');
      controller.updateInputs(improvementCost: '100000');
      controller.setPurchaseDate(DateTime(2010, 6, 15));
      controller.setSaleDate(DateTime(2024, 6, 15));
      controller.calculate();

      controller.clear();

      final today = DateUtils.dateOnly(DateTime.now());
      expect(readState().purchasePrice, isEmpty);
      expect(readState().salePrice, isEmpty);
      expect(readState().improvementCost, isEmpty);
      expect(readState().purchaseDate, DateTime(today.year - 2, today.month, today.day));
      expect(readState().saleDate, today);
      expect(readState().hasCalculated, isFalse);
      expect((readState().validationKey ?? ''), isEmpty);
      expect(readState().isLongTerm, isFalse);
      expect(readState().indexedCost, 0);
      expect(readState().capitalGain, 0);
      expect(readState().taxWithIndexation, 0);
      expect(readState().taxWithoutIndexation, 0);
    });

    test('onClose disposes TextEditingControllers without error', () {
      container.invalidate(capitalGainsProvider);
      expect(readState().hasCalculated, isFalse);
    });
  });
}
