// test/features/assistant/presentation/bindings/assistant_binding_test.dart
//
// Binding test for [AssistantBinding]. Verifies that calling `dependencies()`
// registers both [AssistantRepository] and [AssistantController] into the GetX
// container. Both are registered lazily (fenix: true), so the registration is
// verified via [Get.isRegistered] without instantiating them — their
// constructors resolve [SseClient]/[ApiClient] via Get.find only on first
// access, which is the responsibility of the global InitialBinding.

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ghar360/features/assistant/data/assistant_repository.dart';
import 'package:ghar360/features/assistant/presentation/bindings/assistant_binding.dart';
import 'package:ghar360/features/assistant/presentation/controllers/assistant_controller.dart';

import '../../../../helpers/getx_test_binding.dart';

void main() {
  setUp(() => GetxTestBinding.init());
  tearDown(() => GetxTestBinding.reset());

  test('AssistantBinding registers AssistantRepository and AssistantController', () {
    final binding = AssistantBinding();
    binding.dependencies();

    expect(Get.isRegistered<AssistantRepository>(), isTrue);
    expect(Get.isRegistered<AssistantController>(), isTrue);
  });
}
