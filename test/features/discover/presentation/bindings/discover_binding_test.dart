// test/features/discover/presentation/bindings/discover_binding_test.dart
//
// Binding test for [DiscoverBinding]. Verifies that calling `dependencies()`
// registers [DiscoverController] into the GetX container. Repositories and core
// services are registered by DashboardBinding and are not this binding's
// responsibility.

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:ghar360/features/discover/presentation/bindings/discover_binding.dart';
import 'package:ghar360/features/discover/presentation/controllers/discover_controller.dart';
import '../../../../helpers/getx_test_binding.dart';

void main() {
  setUp(() => GetxTestBinding.init());
  tearDown(() => GetxTestBinding.reset());

  test('DiscoverBinding registers DiscoverController', () {
    final binding = DiscoverBinding();
    binding.dependencies();

    expect(Get.isRegistered<DiscoverController>(), isTrue);
  });
}
