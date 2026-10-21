// test/features/tools/presentation/controllers/carpet_area_controller_test.dart
//
// Unit tests for [CarpetAreaController]. Covers:
// - calculate() with default 25% loading
// - calculate() with different loading percentages
// - Zero area triggers validation error
// - onLoadingChanged recalculates when already calculated
// - clear() resets all state

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/features/tools/presentation/controllers/carpet_area_controller.dart';

void main() {
  late ProviderContainer container;
  setUp(() {
    container = ProviderContainer();
    container.listen(carpetAreaProvider, (_, _) {});
  });
  tearDown(() => container.dispose());
  CarpetAreaController createController() => container.read(carpetAreaProvider.notifier);
  CarpetAreaState readState() => container.read(carpetAreaProvider);

  group('CarpetAreaController', () {
    // ── Default loading (25%) ────────────────────────────────────────────

    test('calculate() with default 25% loading computes correct areas', () {
      final controller = createController();
      controller.updateInputs(superBuiltUp: '1500'); // 1500 sqft super built-up

      controller.calculate();

      expect(readState().hasCalculated, isTrue);
      expect((readState().validationKey ?? ''), isEmpty);

      // Loading 25%: builtUp = 1500 / 1.25 = 1200
      expect(readState().builtUpArea, closeTo(1200, 0.1));
      // Carpet = 1200 * (1 - 0.12) = 1200 * 0.88 = 1056
      expect(readState().carpetArea, closeTo(1056, 0.1));
      // Usable percentage = 1056 / 1500 * 100 = 70.4%
      expect(readState().usablePercentage, closeTo(70.4, 0.1));
    });

    // ── Different loading percentages ────────────────────────────────────

    test('calculate() with 40% loading yields smaller carpet area', () {
      final controller = createController();
      controller.updateInputs(superBuiltUp: '1000');
      controller.onLoadingChanged(40);

      controller.calculate();

      // builtUp = 1000 / 1.4 ≈ 714.29
      expect(readState().builtUpArea, closeTo(714.29, 0.1));
      // carpet = 714.29 * 0.88 ≈ 628.57
      expect(readState().carpetArea, closeTo(628.57, 0.1));
    });

    test('calculate() with 0% loading yields maximum carpet area', () {
      final controller = createController();
      controller.updateInputs(superBuiltUp: '1000');
      controller.onLoadingChanged(0);

      controller.calculate();

      // builtUp = 1000 / 1 = 1000
      expect(readState().builtUpArea, closeTo(1000, 0.1));
      // carpet = 1000 * 0.88 = 880
      expect(readState().carpetArea, closeTo(880, 0.1));
    });

    // ── Zero area ────────────────────────────────────────────────────────

    test('calculate() with zero area shows validation error', () {
      final controller = createController();
      controller.updateInputs(superBuiltUp: '0');

      controller.calculate();

      expect(readState().hasCalculated, isFalse);
      expect((readState().validationKey ?? ''), isNotEmpty);
    });

    // ── onLoadingChanged recalculates ────────────────────────────────────

    test('onLoadingChanged recalculates when hasCalculated is true', () {
      final controller = createController();
      controller.updateInputs(superBuiltUp: '1000');
      controller.calculate();

      final carpetBefore = readState().carpetArea;

      // Change loading to 50%
      controller.onLoadingChanged(50);

      expect(readState().loadingPercentage, 50);
      // Higher loading → smaller carpet
      expect(readState().carpetArea, lessThan(carpetBefore));
    });

    // ── clear() resets all state ─────────────────────────────────────────

    test('clear() resets all state to defaults', () {
      final controller = createController();
      controller.updateInputs(superBuiltUp: '1500');
      controller.onLoadingChanged(35);
      controller.calculate();

      controller.clear();

      expect(readState().superBuiltUp, isEmpty);
      expect(readState().loadingPercentage, 25.0);
      expect(readState().hasCalculated, isFalse);
      expect((readState().validationKey ?? ''), isEmpty);
      expect(readState().carpetArea, 0);
      expect(readState().builtUpArea, 0);
      expect(readState().usablePercentage, 0);
    });

    // ── Negative area validation ──────────────────────────────────────────

    test('calculate() with negative area shows validation error', () {
      final controller = createController();
      controller.updateInputs(superBuiltUp: '-500');

      controller.calculate();

      expect(readState().hasCalculated, isFalse);
      expect((readState().validationKey ?? ''), isNotEmpty);
    });

    // ── Non-numeric input ─────────────────────────────────────────────────

    test('calculate() with non-numeric input shows validation error', () {
      final controller = createController();
      controller.updateInputs(superBuiltUp: 'abc');

      controller.calculate();

      expect(readState().hasCalculated, isFalse);
      expect((readState().validationKey ?? ''), isNotEmpty);
    });

    // ── Empty input ───────────────────────────────────────────────────────

    test('calculate() with empty input shows validation error', () {
      final controller = createController();

      controller.calculate();

      expect(readState().hasCalculated, isFalse);
      expect((readState().validationKey ?? ''), isNotEmpty);
    });

    // ── onLoadingChanged does not recalculate when not calculated ─────────

    test('onLoadingChanged does not recalculate when hasCalculated is false', () {
      final controller = createController();
      controller.updateInputs(superBuiltUp: '1000');

      controller.onLoadingChanged(50);

      expect(readState().loadingPercentage, 50);
      expect(readState().hasCalculated, isFalse);
      expect(readState().carpetArea, 0);
    });

    // ── 100% loading ──────────────────────────────────────────────────────

    test('calculate() with 100% loading gives very small carpet area', () {
      final controller = createController();
      controller.updateInputs(superBuiltUp: '1000');
      controller.onLoadingChanged(100);

      controller.calculate();

      // builtUp = 1000 / 2 = 500
      expect(readState().builtUpArea, closeTo(500, 0.1));
      // carpet = 500 * 0.88 = 440
      expect(readState().carpetArea, closeTo(440, 0.1));
    });

    // ── Decimal input ─────────────────────────────────────────────────────

    test('calculate() with decimal input works correctly', () {
      final controller = createController();
      controller.updateInputs(superBuiltUp: '1500.5');

      controller.calculate();

      expect(readState().hasCalculated, isTrue);
      // builtUp = 1500.5 / 1.25 = 1200.4
      expect(readState().builtUpArea, closeTo(1200.4, 0.1));
    });

    // ── Very large input ──────────────────────────────────────────────────

    test('calculate() with very large input handles correctly', () {
      final controller = createController();
      controller.updateInputs(superBuiltUp: '1000000');

      controller.calculate();

      expect(readState().hasCalculated, isTrue);
      expect(readState().builtUpArea, closeTo(800000, 1));
    });

    // ── Very small input ──────────────────────────────────────────────────

    test('calculate() with very small input handles correctly', () {
      final controller = createController();
      controller.updateInputs(superBuiltUp: '0.01');

      controller.calculate();

      expect(readState().hasCalculated, isTrue);
      expect(readState().carpetArea, greaterThan(0));
    });

    // ── usablePercentage is always less than 100 ──────────────────────────

    test('calculate() usablePercentage is less than 100 for positive loading', () {
      final controller = createController();
      controller.updateInputs(superBuiltUp: '1000');
      controller.onLoadingChanged(25);

      controller.calculate();

      expect(readState().usablePercentage, lessThan(100));
      expect(readState().usablePercentage, greaterThan(0));
    });

    // ── onClose disposes controller ───────────────────────────────────────

    test('provider invalidation resets calculation state', () {
      container.invalidate(carpetAreaProvider);
      expect(readState().hasCalculated, isFalse);
    });

    // ── onLoadingChanged recalculates with lower loading ──────────────────

    test('onLoadingChanged to lower value increases carpet area', () {
      final controller = createController();
      controller.updateInputs(superBuiltUp: '1000');
      controller.onLoadingChanged(50);
      controller.calculate();
      final carpetAt50 = readState().carpetArea;

      controller.onLoadingChanged(10);
      // Lower loading → larger carpet
      expect(readState().carpetArea, greaterThan(carpetAt50));
    });
  });
}
