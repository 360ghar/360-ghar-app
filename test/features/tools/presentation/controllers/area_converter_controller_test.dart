// test/features/tools/presentation/controllers/area_converter_controller_test.dart
//
// Unit tests for [AreaConverterController]. Covers:
// - Initial state (selectedUnit, empty conversions)
// - convert() with sqFt input
// - convert() with all unit types
// - Zero and negative input clearing conversions
// - clear() resets everything

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/features/tools/presentation/controllers/area_converter_controller.dart';

void main() {
  late ProviderContainer container;
  setUp(() => container = ProviderContainer.test());

  AreaConverterController createController() {
    container.listen(areaConverterProvider, (_, _) {});
    return container.read(areaConverterProvider.notifier);
  }

  group('AreaConverterController', () {
    // ── Initial state ────────────────────────────────────────────────────

    test('initial state has sqFt selected and empty conversions', () {
      createController();

      expect(container.read(areaConverterProvider).selectedUnit, AreaUnit.sqFt);
      expect(container.read(areaConverterProvider).conversions, isEmpty);
      expect(container.read(areaConverterProvider).input, isEmpty);
    });

    // ── convert() with sqFt input ────────────────────────────────────────

    test('convert() with sqFt input populates all unit conversions', () {
      final controller = createController();
      controller.convert('1000');

      // 1000 sqft → 1000 sqft (identity)
      expect(container.read(areaConverterProvider).conversions[AreaUnit.sqFt], closeTo(1000, 0.1));
      // 1000 sqft / 10.7639 ≈ 92.9 sqm
      expect(container.read(areaConverterProvider).conversions[AreaUnit.sqM], closeTo(92.9, 0.1));
      // 1000 sqft / 9 ≈ 111.11 sq yards
      expect(
        container.read(areaConverterProvider).conversions[AreaUnit.sqYards],
        closeTo(111.11, 0.1),
      );
      // 1000 sqft / 9 ≈ 111.11 gaj
      expect(container.read(areaConverterProvider).conversions[AreaUnit.gaj], closeTo(111.11, 0.1));
      // 1000 sqft / 43560 ≈ 0.02296 acres
      expect(
        container.read(areaConverterProvider).conversions[AreaUnit.acres],
        closeTo(0.02296, 0.0001),
      );
      // 1000 sqft / 27000 ≈ 0.03704 bigha
      expect(
        container.read(areaConverterProvider).conversions[AreaUnit.bigha],
        closeTo(0.03704, 0.0001),
      );
    });

    // ── convert() with acres input ───────────────────────────────────────

    test('convert() with acres input converts correctly to all units', () {
      final controller = createController();
      controller.onUnitChanged(AreaUnit.acres);
      controller.convert('1');

      // 1 acre = 43560 sqft
      expect(container.read(areaConverterProvider).conversions[AreaUnit.sqFt], closeTo(43560, 0.1));
      // 1 acre = 43560 / 10.7639 ≈ 4046.86 sqm
      expect(
        container.read(areaConverterProvider).conversions[AreaUnit.sqM],
        closeTo(4046.86, 0.1),
      );
      // 1 acre = 43560 / 9 ≈ 4840 sq yards
      expect(
        container.read(areaConverterProvider).conversions[AreaUnit.sqYards],
        closeTo(4840, 0.1),
      );
      // 1 acre = 1 acre
      expect(container.read(areaConverterProvider).conversions[AreaUnit.acres], closeTo(1, 0.0001));
    });

    // ── Zero input clears conversions ────────────────────────────────────

    test('convert() with zero input clears conversions', () {
      final controller = createController();
      controller.convert('0');

      expect(container.read(areaConverterProvider).conversions, isEmpty);
    });

    // ── Negative input clears conversions ────────────────────────────────

    test('convert() with negative input clears conversions', () {
      final controller = createController();
      controller.convert('-50');

      expect(container.read(areaConverterProvider).conversions, isEmpty);
    });

    // ── onUnitChanged triggers re-conversion ─────────────────────────────

    test('onUnitChanged updates selectedUnit and recalculates', () {
      final controller = createController();
      controller.convert('100');

      final sqYardsBefore = container.read(areaConverterProvider).conversions[AreaUnit.sqYards];
      controller.onUnitChanged(AreaUnit.sqYards);

      expect(container.read(areaConverterProvider).selectedUnit, AreaUnit.sqYards);
      // With 100 sq yards as input: 100 * 9 = 900 sqft
      expect(container.read(areaConverterProvider).conversions[AreaUnit.sqFt], closeTo(900, 0.1));
      // Original 100 sqFt input gives different result than 100 sq yards
      expect(
        container.read(areaConverterProvider).conversions[AreaUnit.sqYards],
        isNot(closeTo(sqYardsBefore!, 0.1)),
      );
    });

    // ── clear() resets everything ────────────────────────────────────────

    test('clear() resets all state', () {
      final controller = createController();
      controller.convert('500');
      controller.onUnitChanged(AreaUnit.sqM);
      controller.convert(container.read(areaConverterProvider).input);

      expect(container.read(areaConverterProvider).conversions, isNotEmpty);

      controller.clear();

      expect(container.read(areaConverterProvider).input, isEmpty);
      expect(container.read(areaConverterProvider).conversions, isEmpty);
    });

    // ── convert() with sqM input ──────────────────────────────────────────

    test('convert() with sqM input converts correctly to all units', () {
      final controller = createController();
      controller.onUnitChanged(AreaUnit.sqM);
      controller.convert('100');

      // 100 sqm * 10.7639 = 1076.39 sqft
      expect(
        container.read(areaConverterProvider).conversions[AreaUnit.sqFt],
        closeTo(1076.39, 0.1),
      );
      // 100 sqm = 100 sqm (identity)
      expect(container.read(areaConverterProvider).conversions[AreaUnit.sqM], closeTo(100, 0.1));
      // 1076.39 sqft / 9 ≈ 119.6 sq yards
      expect(
        container.read(areaConverterProvider).conversions[AreaUnit.sqYards],
        closeTo(119.6, 0.1),
      );
      expect(container.read(areaConverterProvider).conversions[AreaUnit.gaj], closeTo(119.6, 0.1));
      // 1076.39 sqft / 43560 ≈ 0.0247 acres
      expect(
        container.read(areaConverterProvider).conversions[AreaUnit.acres],
        closeTo(0.0247, 0.0001),
      );
      // 1076.39 sqft / 27000 ≈ 0.03987 bigha
      expect(
        container.read(areaConverterProvider).conversions[AreaUnit.bigha],
        closeTo(0.03987, 0.0001),
      );
    });

    // ── convert() with sqYards input ──────────────────────────────────────

    test('convert() with sqYards input converts correctly to all units', () {
      final controller = createController();
      controller.onUnitChanged(AreaUnit.sqYards);
      controller.convert('100');

      // 100 sq yards * 9 = 900 sqft
      expect(container.read(areaConverterProvider).conversions[AreaUnit.sqFt], closeTo(900, 0.1));
      // 900 sqft / 10.7639 ≈ 83.61 sqm
      expect(container.read(areaConverterProvider).conversions[AreaUnit.sqM], closeTo(83.61, 0.1));
      // 100 sq yards = 100 sq yards (identity)
      expect(
        container.read(areaConverterProvider).conversions[AreaUnit.sqYards],
        closeTo(100, 0.1),
      );
      expect(container.read(areaConverterProvider).conversions[AreaUnit.gaj], closeTo(100, 0.1));
    });

    // ── convert() with gaj input ──────────────────────────────────────────

    test('convert() with gaj input converts correctly to all units', () {
      final controller = createController();
      controller.onUnitChanged(AreaUnit.gaj);
      controller.convert('100');

      // 100 gaj * 9 = 900 sqft (gaj = sq yard)
      expect(container.read(areaConverterProvider).conversions[AreaUnit.sqFt], closeTo(900, 0.1));
      expect(
        container.read(areaConverterProvider).conversions[AreaUnit.sqYards],
        closeTo(100, 0.1),
      );
      expect(container.read(areaConverterProvider).conversions[AreaUnit.gaj], closeTo(100, 0.1));
    });

    // ── convert() with bigha input ────────────────────────────────────────

    test('convert() with bigha input converts correctly to all units', () {
      final controller = createController();
      controller.onUnitChanged(AreaUnit.bigha);
      controller.convert('1');

      // 1 bigha * 27000 = 27000 sqft
      expect(container.read(areaConverterProvider).conversions[AreaUnit.sqFt], closeTo(27000, 0.1));
      // 27000 sqft / 10.7639 ≈ 2508.38 sqm
      expect(
        container.read(areaConverterProvider).conversions[AreaUnit.sqM],
        closeTo(2508.38, 0.1),
      );
      // 27000 sqft / 9 = 3000 sq yards
      expect(
        container.read(areaConverterProvider).conversions[AreaUnit.sqYards],
        closeTo(3000, 0.1),
      );
      expect(container.read(areaConverterProvider).conversions[AreaUnit.gaj], closeTo(3000, 0.1));
      // 27000 sqft / 43560 ≈ 0.6198 acres
      expect(
        container.read(areaConverterProvider).conversions[AreaUnit.acres],
        closeTo(0.6198, 0.0001),
      );
      // 1 bigha = 1 bigha (identity)
      expect(container.read(areaConverterProvider).conversions[AreaUnit.bigha], closeTo(1, 0.0001));
    });

    // ── convert() with invalid input ──────────────────────────────────────

    test('convert() with non-numeric input clears conversions', () {
      final controller = createController();
      controller.convert('abc');

      expect(container.read(areaConverterProvider).conversions, isEmpty);
    });

    test('convert() with empty input clears conversions', () {
      final controller = createController();
      controller.convert('');

      expect(container.read(areaConverterProvider).conversions, isEmpty);
    });

    test('convert() with decimal input works correctly', () {
      final controller = createController();
      controller.convert('100.5');

      expect(container.read(areaConverterProvider).conversions[AreaUnit.sqFt], closeTo(100.5, 0.1));
      expect(container.read(areaConverterProvider).conversions[AreaUnit.sqM], closeTo(9.337, 0.01));
    });

    // ── onUnitChanged with null ────────────────────────────────────────────

    test('onUnitChanged with null does not change selectedUnit', () {
      final controller = createController();
      controller.convert('100');
      final originalUnit = container.read(areaConverterProvider).selectedUnit;

      controller.onUnitChanged(null);

      expect(container.read(areaConverterProvider).selectedUnit, originalUnit);
    });

    // ── onUnitChanged triggers re-conversion with new unit ─────────────────

    test('onUnitChanged to sqM recalculates using sqM as base', () {
      final controller = createController();
      controller.convert('100');
      // Initially sqFt: 100 sqft

      controller.onUnitChanged(AreaUnit.sqM);
      // Now 100 sqm * 10.7639 = 1076.39 sqft
      expect(
        container.read(areaConverterProvider).conversions[AreaUnit.sqFt],
        closeTo(1076.39, 0.1),
      );
      expect(container.read(areaConverterProvider).conversions[AreaUnit.sqM], closeTo(100, 0.1));
    });

    // ── onUnitChanged with empty input ─────────────────────────────────────

    test('onUnitChanged with empty input clears conversions', () {
      final controller = createController();
      controller.onUnitChanged(AreaUnit.acres);

      expect(container.read(areaConverterProvider).selectedUnit, AreaUnit.acres);
      expect(container.read(areaConverterProvider).conversions, isEmpty);
    });

    // ── getUnitLabel ───────────────────────────────────────────────────────

    test('getUnitLabel returns label for each unit', () {
      createController();

      // The view resolves these keys through Flutter localizations.
      for (final unit in AreaUnit.values) {
        final label = unit.labelKey;
        expect(label, isNotEmpty);
      }
    });

    // ── convert() identity check for each unit ─────────────────────────────

    test('convert() produces identity value for the selected unit', () {
      for (final unit in AreaUnit.values) {
        final controller = createController();
        controller.onUnitChanged(unit);
        controller.convert('1');

        expect(
          container.read(areaConverterProvider).conversions[unit],
          closeTo(1, 0.0001),
          reason: 'Identity conversion failed for $unit',
        );
        controller.clear();
      }
    });

    // ── onClose disposes TextEditingController ─────────────────────────────

    test('provider lifecycle disposes calculator state', () async {
      container.read(areaConverterProvider);
      await container.pump();
      expect(container.exists(areaConverterProvider), isFalse);
    });

    test('overflow and non-finite input produce validation, not infinite results', () {
      final controller = createController();
      controller.onUnitChanged(AreaUnit.acres);
      for (final input in ['NaN', 'Infinity', '1e308']) {
        controller.convert(input);
        expect(container.read(areaConverterProvider).conversions, isEmpty);
        expect(container.read(areaConverterProvider).validationKey, 'please_enter_valid_area');
      }
    });

    test('results cannot be mutated outside the notifier', () {
      createController().convert('100');
      expect(
        () => container.read(areaConverterProvider).conversions.clear(),
        throwsUnsupportedError,
      );
    });

    // ── convert() with very large input ────────────────────────────────────

    test('convert() with very large input handles correctly', () {
      final controller = createController();
      controller.convert('1000000');

      expect(container.read(areaConverterProvider).conversions[AreaUnit.sqFt], closeTo(1000000, 1));
      expect(
        container.read(areaConverterProvider).conversions[AreaUnit.acres],
        closeTo(22.956, 0.001),
      );
    });

    // ── convert() with very small input ────────────────────────────────────

    test('convert() with very small decimal input handles correctly', () {
      final controller = createController();
      controller.convert('0.001');

      expect(
        container.read(areaConverterProvider).conversions[AreaUnit.sqFt],
        closeTo(0.001, 0.0001),
      );
      expect(container.read(areaConverterProvider).conversions, isNotEmpty);
    });
  });
}
