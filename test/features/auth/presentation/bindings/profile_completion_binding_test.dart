// test/features/auth/presentation/bindings/profile_completion_binding_test.dart
//
// Binding test for [ProfileCompletionBinding]. Verifies that calling
// `dependencies()` registers [ProfileCompletionController] into the GetX
// container.

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:ghar360/features/auth/presentation/bindings/profile_completion_binding.dart';
import 'package:ghar360/features/auth/presentation/controllers/profile_completion_controller.dart';
import '../../../../helpers/getx_test_binding.dart';

void main() {
  setUp(() => GetxTestBinding.init());
  tearDown(() => GetxTestBinding.reset());

  test('ProfileCompletionBinding registers ProfileCompletionController', () {
    final binding = ProfileCompletionBinding();
    binding.dependencies();

    expect(Get.isRegistered<ProfileCompletionController>(), isTrue);
  });
}
