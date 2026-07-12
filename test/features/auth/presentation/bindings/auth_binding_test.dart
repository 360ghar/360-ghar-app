// test/features/auth/presentation/bindings/auth_binding_test.dart
//
// Binding test for [AuthBinding]. Verifies that calling `dependencies()`
// registers both [LoginController] and [ProfileCompletionController] into the
// GetX container. AuthController is registered globally by InitialBinding and
// is not this binding's responsibility.

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ghar360/features/auth/presentation/bindings/auth_binding.dart';
import 'package:ghar360/features/auth/presentation/controllers/login_controller.dart';
import 'package:ghar360/features/auth/presentation/controllers/profile_completion_controller.dart';

import '../../../../helpers/getx_test_binding.dart';

void main() {
  setUp(() => GetxTestBinding.init());
  tearDown(() => GetxTestBinding.reset());

  test('AuthBinding registers LoginController and ProfileCompletionController', () {
    final binding = AuthBinding();
    binding.dependencies();

    expect(Get.isRegistered<LoginController>(), isTrue);
    expect(Get.isRegistered<ProfileCompletionController>(), isTrue);
  });
}
