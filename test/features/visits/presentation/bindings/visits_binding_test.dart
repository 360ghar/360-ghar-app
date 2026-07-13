// test/features/visits/presentation/bindings/visits_binding_test.dart
//
// Binding test for [VisitsBinding]. Verifies that calling `dependencies()`
// registers [VisitsController] into the GetX container, and that the guard
// (`if (!Get.isRegistered<VisitsController>())`) is idempotent — a second call
// does not throw and the controller remains registered.

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:ghar360/features/visits/presentation/bindings/visits_binding.dart';
import 'package:ghar360/features/visits/presentation/controllers/visits_controller.dart';
import '../../../../helpers/getx_test_binding.dart';

void main() {
  setUp(() => GetxTestBinding.init());
  tearDown(() => GetxTestBinding.reset());

  test('VisitsBinding registers VisitsController', () {
    final binding = VisitsBinding();
    binding.dependencies();

    expect(Get.isRegistered<VisitsController>(), isTrue);
  });

  test('VisitsBinding is idempotent when VisitsController is already registered', () {
    // Pre-register so the binding's guard skips re-registration.
    Get.lazyPut<VisitsController>(() => VisitsController());

    final binding = VisitsBinding();
    expect(() => binding.dependencies(), returnsNormally);

    expect(Get.isRegistered<VisitsController>(), isTrue);
  });
}
