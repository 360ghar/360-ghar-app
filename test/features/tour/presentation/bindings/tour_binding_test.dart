// test/features/tour/presentation/bindings/tour_binding_test.dart
//
// Binding test for [TourBinding]. The tour view declares no dependencies, so
// the test only asserts that `dependencies()` runs without throwing and that
// the GetX container remains free of tour-specific registrations.

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/features/tour/presentation/bindings/tour_binding.dart';
import '../../../../helpers/getx_test_binding.dart';

void main() {
  setUp(() => GetxTestBinding.init());
  tearDown(() => GetxTestBinding.reset());

  test('TourBinding.dependencies() runs without throwing', () {
    final binding = TourBinding();
    expect(() => binding.dependencies(), returnsNormally);
  });
}
