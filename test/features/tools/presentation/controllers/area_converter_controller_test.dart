// test/features/tools/presentation/controllers/area_converter_controller_test.dart
//
// Unit tests for [AreaConverterController]. Covers:
// - Initial state (selectedUnit, empty conversions)
// - convert() with sqFt input
// - convert() with all unit types
// - Zero and negative input clearing conversions
// - clear() resets everything

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/features/tools/presentation/controllers/area_converter_controller.dart';
import '../../../../helpers/getx_test_binding.dart';

void main() {
  setUp(() {
    GetxTestBinding.init();
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  AreaConverterController createController() {
    final c = AreaConverterController();
    c.onInit();
    return c;
  }

  group('AreaConverterController', () {
    // ── Initial state ────────────────────────────────────────────────────

    test('initial state has sqFt selected and empty conversions', () {
      final controller = createController();

      expect(controller.selectedUnit.value, AreaUnit.sqFt);
      expect(controller.conversions, isEmpty);
      expect(controller.inputController.text, isEmpty);
    });

    // ── convert() with sqFt input ────────────────────────────────────────

    test('convert() with sqFt input populates all unit conversions', () {
      final controller = createController();
      controller.inputController.text = '1000';
      controller.convert();

      // 1000 sqft → 1000 sqft (identity)
      expect(controller.conversions[AreaUnit.sqFt], closeTo(1000, 0.1));
      // 1000 sqft / 10.7639 ≈ 92.9 sqm
      expect(controller.conversions[AreaUnit.sqM], closeTo(92.9, 0.1));
      // 1000 sqft / 9 ≈ 111.11 sq yards
      expect(controller.conversions[AreaUnit.sqYards], closeTo(111.11, 0.1));
      // 1000 sqft / 9 ≈ 111.11 gaj
      expect(controller.conversions[AreaUnit.gaj], closeTo(111.11, 0.1));
      // 1000 sqft / 43560 ≈ 0.02296 acres
      expect(controller.conversions[AreaUnit.acres], closeTo(0.02296, 0.0001));
      // 1000 sqft / 27000 ≈ 0.03704 bigha
      expect(controller.conversions[AreaUnit.bigha], closeTo(0.03704, 0.0001));
    });

    // ── convert() with acres input ───────────────────────────────────────

    test('convert() with acres input converts correctly to all units', () {
      final controller = createController();
      controller.selectedUnit.value = AreaUnit.acres;
      controller.inputController.text = '1';
      controller.convert();

      // 1 acre = 43560 sqft
      expect(controller.conversions[AreaUnit.sqFt], closeTo(43560, 0.1));
      // 1 acre = 43560 / 10.7639 ≈ 4046.86 sqm
      expect(controller.conversions[AreaUnit.sqM], closeTo(4046.86, 0.1));
      // 1 acre = 43560 / 9 ≈ 4840 sq yards
      expect(controller.conversions[AreaUnit.sqYards], closeTo(4840, 0.1));
      // 1 acre = 1 acre
      expect(controller.conversions[AreaUnit.acres], closeTo(1, 0.0001));
    });

    // ── Zero input clears conversions ────────────────────────────────────

    test('convert() with zero input clears conversions', () {
      final controller = createController();
      controller.inputController.text = '0';
      controller.convert();

      expect(controller.conversions, isEmpty);
    });

    // ── Negative input clears conversions ────────────────────────────────

    test('convert() with negative input clears conversions', () {
      final controller = createController();
      controller.inputController.text = '-50';
      controller.convert();

      expect(controller.conversions, isEmpty);
    });

    // ── onUnitChanged triggers re-conversion ─────────────────────────────

    test('onUnitChanged updates selectedUnit and recalculates', () {
      final controller = createController();
      controller.inputController.text = '100';
      controller.convert();

      final sqYardsBefore = controller.conversions[AreaUnit.sqYards];
      controller.onUnitChanged(AreaUnit.sqYards);

      expect(controller.selectedUnit.value, AreaUnit.sqYards);
      // With 100 sq yards as input: 100 * 9 = 900 sqft
      expect(controller.conversions[AreaUnit.sqFt], closeTo(900, 0.1));
      // Original 100 sqFt input gives different result than 100 sq yards
      expect(controller.conversions[AreaUnit.sqYards], isNot(closeTo(sqYardsBefore!, 0.1)));
    });

    // ── clear() resets everything ────────────────────────────────────────

    test('clear() resets all state', () {
      final controller = createController();
      controller.inputController.text = '500';
      controller.selectedUnit.value = AreaUnit.sqM;
      controller.convert();

      expect(controller.conversions, isNotEmpty);

      controller.clear();

      expect(controller.inputController.text, isEmpty);
      expect(controller.conversions, isEmpty);
    });

    // ── convert() with sqM input ──────────────────────────────────────────

    test('convert() with sqM input converts correctly to all units', () {
      final controller = createController();
      controller.selectedUnit.value = AreaUnit.sqM;
      controller.inputController.text = '100';
      controller.convert();

      // 100 sqm * 10.7639 = 1076.39 sqft
      expect(controller.conversions[AreaUnit.sqFt], closeTo(1076.39, 0.1));
      // 100 sqm = 100 sqm (identity)
      expect(controller.conversions[AreaUnit.sqM], closeTo(100, 0.1));
      // 1076.39 sqft / 9 ≈ 119.6 sq yards
      expect(controller.conversions[AreaUnit.sqYards], closeTo(119.6, 0.1));
      expect(controller.conversions[AreaUnit.gaj], closeTo(119.6, 0.1));
      // 1076.39 sqft / 43560 ≈ 0.0247 acres
      expect(controller.conversions[AreaUnit.acres], closeTo(0.0247, 0.0001));
      // 1076.39 sqft / 27000 ≈ 0.03987 bigha
      expect(controller.conversions[AreaUnit.bigha], closeTo(0.03987, 0.0001));
    });

    // ── convert() with sqYards input ──────────────────────────────────────

    test('convert() with sqYards input converts correctly to all units', () {
      final controller = createController();
      controller.selectedUnit.value = AreaUnit.sqYards;
      controller.inputController.text = '100';
      controller.convert();

      // 100 sq yards * 9 = 900 sqft
      expect(controller.conversions[AreaUnit.sqFt], closeTo(900, 0.1));
      // 900 sqft / 10.7639 ≈ 83.61 sqm
      expect(controller.conversions[AreaUnit.sqM], closeTo(83.61, 0.1));
      // 100 sq yards = 100 sq yards (identity)
      expect(controller.conversions[AreaUnit.sqYards], closeTo(100, 0.1));
      expect(controller.conversions[AreaUnit.gaj], closeTo(100, 0.1));
    });

    // ── convert() with gaj input ──────────────────────────────────────────

    test('convert() with gaj input converts correctly to all units', () {
      final controller = createController();
      controller.selectedUnit.value = AreaUnit.gaj;
      controller.inputController.text = '100';
      controller.convert();

      // 100 gaj * 9 = 900 sqft (gaj = sq yard)
      expect(controller.conversions[AreaUnit.sqFt], closeTo(900, 0.1));
      expect(controller.conversions[AreaUnit.sqYards], closeTo(100, 0.1));
      expect(controller.conversions[AreaUnit.gaj], closeTo(100, 0.1));
    });

    // ── convert() with bigha input ────────────────────────────────────────

    test('convert() with bigha input converts correctly to all units', () {
      final controller = createController();
      controller.selectedUnit.value = AreaUnit.bigha;
      controller.inputController.text = '1';
      controller.convert();

      // 1 bigha * 27000 = 27000 sqft
      expect(controller.conversions[AreaUnit.sqFt], closeTo(27000, 0.1));
      // 27000 sqft / 10.7639 ≈ 2508.38 sqm
      expect(controller.conversions[AreaUnit.sqM], closeTo(2508.38, 0.1));
      // 27000 sqft / 9 = 3000 sq yards
      expect(controller.conversions[AreaUnit.sqYards], closeTo(3000, 0.1));
      expect(controller.conversions[AreaUnit.gaj], closeTo(3000, 0.1));
      // 27000 sqft / 43560 ≈ 0.6198 acres
      expect(controller.conversions[AreaUnit.acres], closeTo(0.6198, 0.0001));
      // 1 bigha = 1 bigha (identity)
      expect(controller.conversions[AreaUnit.bigha], closeTo(1, 0.0001));
    });

    // ── convert() with invalid input ──────────────────────────────────────

    test('convert() with non-numeric input clears conversions', () {
      final controller = createController();
      controller.inputController.text = 'abc';
      controller.convert();

      expect(controller.conversions, isEmpty);
    });

    test('convert() with empty input clears conversions', () {
      final controller = createController();
      controller.inputController.text = '';
      controller.convert();

      expect(controller.conversions, isEmpty);
    });

    test('convert() with decimal input works correctly', () {
      final controller = createController();
      controller.inputController.text = '100.5';
      controller.convert();

      expect(controller.conversions[AreaUnit.sqFt], closeTo(100.5, 0.1));
      expect(controller.conversions[AreaUnit.sqM], closeTo(9.337, 0.01));
    });

    // ── onUnitChanged with null ────────────────────────────────────────────

    test('onUnitChanged with null does not change selectedUnit', () {
      final controller = createController();
      controller.inputController.text = '100';
      controller.convert();
      final originalUnit = controller.selectedUnit.value;

      controller.onUnitChanged(null);

      expect(controller.selectedUnit.value, originalUnit);
    });

    // ── onUnitChanged triggers re-conversion with new unit ─────────────────

    test('onUnitChanged to sqM recalculates using sqM as base', () {
      final controller = createController();
      controller.inputController.text = '100';
      controller.convert();
      // Initially sqFt: 100 sqft

      controller.onUnitChanged(AreaUnit.sqM);
      // Now 100 sqm * 10.7639 = 1076.39 sqft
      expect(controller.conversions[AreaUnit.sqFt], closeTo(1076.39, 0.1));
      expect(controller.conversions[AreaUnit.sqM], closeTo(100, 0.1));
    });

    // ── onUnitChanged with empty input ─────────────────────────────────────

    test('onUnitChanged with empty input clears conversions', () {
      final controller = createController();
      controller.onUnitChanged(AreaUnit.acres);

      expect(controller.selectedUnit.value, AreaUnit.acres);
      expect(controller.conversions, isEmpty);
    });

    // ── getUnitLabel ───────────────────────────────────────────────────────

    test('getUnitLabel returns label for each unit', () {
      final controller = createController();

      // .tr returns the key itself when no translation is registered.
      for (final unit in AreaUnit.values) {
        final label = controller.getUnitLabel(unit);
        expect(label, isNotEmpty);
      }
    });

    // ── convert() identity check for each unit ─────────────────────────────

    test('convert() produces identity value for the selected unit', () {
      for (final unit in AreaUnit.values) {
        GetxTestBinding.init();
        final controller = AreaConverterController();
        controller.onInit();
        controller.selectedUnit.value = unit;
        controller.inputController.text = '1';
        controller.convert();

        expect(
          controller.conversions[unit],
          closeTo(1, 0.0001),
          reason: 'Identity conversion failed for $unit',
        );
        controller.onClose();
        GetxTestBinding.reset();
      }
    });

    // ── onClose disposes TextEditingController ─────────────────────────────

    test('onClose disposes inputController without error', () {
      final controller = createController();
      // Should not throw.
      controller.onClose();
    });

    // ── convert() with very large input ────────────────────────────────────

    test('convert() with very large input handles correctly', () {
      final controller = createController();
      controller.inputController.text = '1000000';
      controller.convert();

      expect(controller.conversions[AreaUnit.sqFt], closeTo(1000000, 1));
      expect(controller.conversions[AreaUnit.acres], closeTo(22.956, 0.001));
    });

    // ── convert() with very small input ────────────────────────────────────

    test('convert() with very small decimal input handles correctly', () {
      final controller = createController();
      controller.inputController.text = '0.001';
      controller.convert();

      expect(controller.conversions[AreaUnit.sqFt], closeTo(0.001, 0.0001));
      expect(controller.conversions, isNotEmpty);
    });
  });
}
