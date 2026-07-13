// test/features/explore/presentation/bindings/explore_binding_test.dart
//
// Binding test for [ExploreBinding]. Verifies that calling `dependencies()`
// registers [ExploreController] into the GetX container. Repositories and core
// services are registered by DashboardBinding and are not this binding's
// responsibility.

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:ghar360/features/explore/presentation/bindings/explore_binding.dart';
import 'package:ghar360/features/explore/presentation/controllers/explore_controller.dart';
import '../../../../helpers/getx_test_binding.dart';

void main() {
  setUp(() => GetxTestBinding.init());
  tearDown(() => GetxTestBinding.reset());

  test('ExploreBinding registers ExploreController', () {
    final binding = ExploreBinding();
    binding.dependencies();

    expect(Get.isRegistered<ExploreController>(), isTrue);
  });
}
