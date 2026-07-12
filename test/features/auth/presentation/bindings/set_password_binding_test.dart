// test/features/auth/presentation/bindings/set_password_binding_test.dart
//
// Binding test for [SetPasswordBinding]. Verifies that calling
// `dependencies()` registers [SetPasswordController] into the GetX container.
// AuthController/AuthRepository are registered globally by InitialBinding and
// are not this binding's responsibility.

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ghar360/features/auth/presentation/bindings/set_password_binding.dart';
import 'package:ghar360/features/auth/presentation/controllers/set_password_controller.dart';

import '../../../../helpers/getx_test_binding.dart';

void main() {
  setUp(() => GetxTestBinding.init());
  tearDown(() => GetxTestBinding.reset());

  test('SetPasswordBinding registers SetPasswordController', () {
    final binding = SetPasswordBinding();
    binding.dependencies();

    expect(Get.isRegistered<SetPasswordController>(), isTrue);
  });
}
