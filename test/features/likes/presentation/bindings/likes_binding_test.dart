// test/features/likes/presentation/bindings/likes_binding_test.dart
//
// Binding test for [LikesBinding]. Verifies that calling `dependencies()`
// registers [LikesController] into the GetX container. Repositories and core
// services are registered by DashboardBinding and are not this binding's
// responsibility.

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ghar360/features/likes/presentation/bindings/likes_binding.dart';
import 'package:ghar360/features/likes/presentation/controllers/likes_controller.dart';

import '../../../../helpers/getx_test_binding.dart';

void main() {
  setUp(() => GetxTestBinding.init());
  tearDown(() => GetxTestBinding.reset());

  test('LikesBinding registers LikesController', () {
    final binding = LikesBinding();
    binding.dependencies();

    expect(Get.isRegistered<LikesController>(), isTrue);
  });
}
