// test/features/tools/presentation/controllers/carpet_area_controller_test.dart
//
// Unit tests for [CarpetAreaController]. Covers:
// - calculate() with default 25% loading
// - calculate() with different loading percentages
// - Zero area triggers validation error
// - onLoadingChanged recalculates when already calculated
// - clear() resets all state

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/features/tools/presentation/controllers/carpet_area_controller.dart';
import '../../../../helpers/getx_test_binding.dart';

void main() {
  setUp(() {
    GetxTestBinding.init();
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  CarpetAreaController createController() {
    final c = CarpetAreaController();
    c.onInit();
    return c;
  }

  group('CarpetAreaController', () {
    // ── Default loading (25%) ────────────────────────────────────────────

    test('calculate() with default 25% loading computes correct areas', () {
      final controller = createController();
      controller.superBuiltUpController.text = '1500'; // 1500 sqft super built-up

      controller.calculate();

      expect(controller.hasCalculated.value, isTrue);
      expect(controller.validationError.value, isEmpty);

      // Loading 25%: builtUp = 1500 / 1.25 = 1200
      expect(controller.builtUpArea.value, closeTo(1200, 0.1));
      // Carpet = 1200 * (1 - 0.12) = 1200 * 0.88 = 1056
      expect(controller.carpetArea.value, closeTo(1056, 0.1));
      // Usable percentage = 1056 / 1500 * 100 = 70.4%
      expect(controller.usablePercentage.value, closeTo(70.4, 0.1));
    });

    // ── Different loading percentages ────────────────────────────────────

    test('calculate() with 40% loading yields smaller carpet area', () {
      final controller = createController();
      controller.superBuiltUpController.text = '1000';
      controller.loadingPercentage.value = 40;

      controller.calculate();

      // builtUp = 1000 / 1.4 ≈ 714.29
      expect(controller.builtUpArea.value, closeTo(714.29, 0.1));
      // carpet = 714.29 * 0.88 ≈ 628.57
      expect(controller.carpetArea.value, closeTo(628.57, 0.1));
    });

    test('calculate() with 0% loading yields maximum carpet area', () {
      final controller = createController();
      controller.superBuiltUpController.text = '1000';
      controller.loadingPercentage.value = 0;

      controller.calculate();

      // builtUp = 1000 / 1 = 1000
      expect(controller.builtUpArea.value, closeTo(1000, 0.1));
      // carpet = 1000 * 0.88 = 880
      expect(controller.carpetArea.value, closeTo(880, 0.1));
    });

    // ── Zero area ────────────────────────────────────────────────────────

    test('calculate() with zero area shows validation error', () {
      final controller = createController();
      controller.superBuiltUpController.text = '0';

      controller.calculate();

      expect(controller.hasCalculated.value, isFalse);
      expect(controller.validationError.value, isNotEmpty);
    });

    // ── onLoadingChanged recalculates ────────────────────────────────────

    test('onLoadingChanged recalculates when hasCalculated is true', () {
      final controller = createController();
      controller.superBuiltUpController.text = '1000';
      controller.calculate();

      final carpetBefore = controller.carpetArea.value;

      // Change loading to 50%
      controller.onLoadingChanged(50);

      expect(controller.loadingPercentage.value, 50);
      // Higher loading → smaller carpet
      expect(controller.carpetArea.value, lessThan(carpetBefore));
    });

    // ── clear() resets all state ─────────────────────────────────────────

    test('clear() resets all state to defaults', () {
      final controller = createController();
      controller.superBuiltUpController.text = '1500';
      controller.loadingPercentage.value = 35;
      controller.calculate();

      controller.clear();

      expect(controller.superBuiltUpController.text, isEmpty);
      expect(controller.loadingPercentage.value, 25.0);
      expect(controller.hasCalculated.value, isFalse);
      expect(controller.validationError.value, isEmpty);
      expect(controller.carpetArea.value, 0);
      expect(controller.builtUpArea.value, 0);
      expect(controller.usablePercentage.value, 0);
    });

    // ── Negative area validation ──────────────────────────────────────────

    test('calculate() with negative area shows validation error', () {
      final controller = createController();
      controller.superBuiltUpController.text = '-500';

      controller.calculate();

      expect(controller.hasCalculated.value, isFalse);
      expect(controller.validationError.value, isNotEmpty);
    });

    // ── Non-numeric input ─────────────────────────────────────────────────

    test('calculate() with non-numeric input shows validation error', () {
      final controller = createController();
      controller.superBuiltUpController.text = 'abc';

      controller.calculate();

      expect(controller.hasCalculated.value, isFalse);
      expect(controller.validationError.value, isNotEmpty);
    });

    // ── Empty input ───────────────────────────────────────────────────────

    test('calculate() with empty input shows validation error', () {
      final controller = createController();

      controller.calculate();

      expect(controller.hasCalculated.value, isFalse);
      expect(controller.validationError.value, isNotEmpty);
    });

    // ── onLoadingChanged does not recalculate when not calculated ─────────

    test('onLoadingChanged does not recalculate when hasCalculated is false', () {
      final controller = createController();
      controller.superBuiltUpController.text = '1000';

      controller.onLoadingChanged(50);

      expect(controller.loadingPercentage.value, 50);
      expect(controller.hasCalculated.value, isFalse);
      expect(controller.carpetArea.value, 0);
    });

    // ── 100% loading ──────────────────────────────────────────────────────

    test('calculate() with 100% loading gives very small carpet area', () {
      final controller = createController();
      controller.superBuiltUpController.text = '1000';
      controller.loadingPercentage.value = 100;

      controller.calculate();

      // builtUp = 1000 / 2 = 500
      expect(controller.builtUpArea.value, closeTo(500, 0.1));
      // carpet = 500 * 0.88 = 440
      expect(controller.carpetArea.value, closeTo(440, 0.1));
    });

    // ── Decimal input ─────────────────────────────────────────────────────

    test('calculate() with decimal input works correctly', () {
      final controller = createController();
      controller.superBuiltUpController.text = '1500.5';

      controller.calculate();

      expect(controller.hasCalculated.value, isTrue);
      // builtUp = 1500.5 / 1.25 = 1200.4
      expect(controller.builtUpArea.value, closeTo(1200.4, 0.1));
    });

    // ── Very large input ──────────────────────────────────────────────────

    test('calculate() with very large input handles correctly', () {
      final controller = createController();
      controller.superBuiltUpController.text = '1000000';

      controller.calculate();

      expect(controller.hasCalculated.value, isTrue);
      expect(controller.builtUpArea.value, closeTo(800000, 1));
    });

    // ── Very small input ──────────────────────────────────────────────────

    test('calculate() with very small input handles correctly', () {
      final controller = createController();
      controller.superBuiltUpController.text = '0.01';

      controller.calculate();

      expect(controller.hasCalculated.value, isTrue);
      expect(controller.carpetArea.value, greaterThan(0));
    });

    // ── usablePercentage is always less than 100 ──────────────────────────

    test('calculate() usablePercentage is less than 100 for positive loading', () {
      final controller = createController();
      controller.superBuiltUpController.text = '1000';
      controller.loadingPercentage.value = 25;

      controller.calculate();

      expect(controller.usablePercentage.value, lessThan(100));
      expect(controller.usablePercentage.value, greaterThan(0));
    });

    // ── onClose disposes controller ───────────────────────────────────────

    test('onClose disposes TextEditingController without error', () {
      final controller = createController();
      controller.onClose();
    });

    // ── onLoadingChanged recalculates with lower loading ──────────────────

    test('onLoadingChanged to lower value increases carpet area', () {
      final controller = createController();
      controller.superBuiltUpController.text = '1000';
      controller.loadingPercentage.value = 50;
      controller.calculate();
      final carpetAt50 = controller.carpetArea.value;

      controller.onLoadingChanged(10);
      // Lower loading → larger carpet
      expect(controller.carpetArea.value, greaterThan(carpetAt50));
    });
  });
}
