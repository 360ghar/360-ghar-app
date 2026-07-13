// test/features/profile/presentation/bindings/profile_binding_test.dart
//
// Binding test for [ProfileBinding]. Verifies that calling `dependencies()`
// registers both [ProfileController] and [EditProfileController] into the GetX
// container. AuthController is registered globally by InitialBinding and is
// not this binding's responsibility.

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:ghar360/features/profile/presentation/bindings/profile_binding.dart';
import 'package:ghar360/features/profile/presentation/controllers/edit_profile_controller.dart';
import 'package:ghar360/features/profile/presentation/controllers/profile_controller.dart';
import '../../../../helpers/getx_test_binding.dart';

void main() {
  setUp(() => GetxTestBinding.init());
  tearDown(() => GetxTestBinding.reset());

  test('ProfileBinding registers ProfileController and EditProfileController', () {
    final binding = ProfileBinding();
    binding.dependencies();

    expect(Get.isRegistered<ProfileController>(), isTrue);
    expect(Get.isRegistered<EditProfileController>(), isTrue);
  });
}
