// test/features/auth/presentation/bindings/forgot_password_binding_test.dart
//
// Binding test for [ForgotPasswordBinding]. Verifies that calling
// `dependencies()` registers [ForgotPasswordController] into the GetX
// container. AuthController/AuthRepository are expected to be registered
// globally by InitialBinding and are not this binding's responsibility.

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:ghar360/features/auth/presentation/bindings/forgot_password_binding.dart';
import 'package:ghar360/features/auth/presentation/controllers/forgot_password_controller.dart';
import '../../../../helpers/getx_test_binding.dart';

void main() {
  setUp(() => GetxTestBinding.init());
  tearDown(() => GetxTestBinding.reset());

  test('ForgotPasswordBinding registers ForgotPasswordController', () {
    final binding = ForgotPasswordBinding();
    binding.dependencies();

    expect(Get.isRegistered<ForgotPasswordController>(), isTrue);
  });
}
