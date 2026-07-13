// test/features/auth/presentation/bindings/signup_binding_test.dart
//
// Binding test for [SignUpBinding]. Verifies that calling `dependencies()`
// registers [SignUpController] into the GetX container. AuthController and
// AuthRepository are registered globally by InitialBinding and are not this
// binding's responsibility.

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:ghar360/features/auth/presentation/bindings/signup_binding.dart';
import 'package:ghar360/features/auth/presentation/controllers/signup_controller.dart';
import '../../../../helpers/getx_test_binding.dart';

void main() {
  setUp(() => GetxTestBinding.init());
  tearDown(() => GetxTestBinding.reset());

  test('SignUpBinding registers SignUpController', () {
    final binding = SignUpBinding();
    binding.dependencies();

    expect(Get.isRegistered<SignUpController>(), isTrue);
  });
}
