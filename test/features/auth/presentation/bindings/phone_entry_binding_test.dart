// test/features/auth/presentation/bindings/phone_entry_binding_test.dart
//
// Binding test for [PhoneEntryBinding]. Verifies that calling
// `dependencies()` registers [PhoneEntryController] into the GetX container.

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:ghar360/features/auth/presentation/bindings/phone_entry_binding.dart';
import 'package:ghar360/features/auth/presentation/controllers/phone_entry_controller.dart';
import '../../../../helpers/getx_test_binding.dart';

void main() {
  setUp(() => GetxTestBinding.init());
  tearDown(() => GetxTestBinding.reset());

  test('PhoneEntryBinding registers PhoneEntryController', () {
    final binding = PhoneEntryBinding();
    binding.dependencies();

    expect(Get.isRegistered<PhoneEntryController>(), isTrue);
  });
}
