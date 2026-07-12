// test/features/profile/presentation/bindings/feedback_binding_test.dart
//
// Binding test for [FeedbackBinding]. Verifies that calling `dependencies()`
// registers both [SupportRepository] and [FeedbackController] into the GetX
// container, and that the SupportRepository guard is idempotent.

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ghar360/features/profile/data/support_repository.dart';
import 'package:ghar360/features/profile/presentation/bindings/feedback_binding.dart';
import 'package:ghar360/features/profile/presentation/controllers/feedback_controller.dart';

import '../../../../helpers/getx_test_binding.dart';

void main() {
  setUp(() => GetxTestBinding.init());
  tearDown(() => GetxTestBinding.reset());

  test('FeedbackBinding registers SupportRepository and FeedbackController', () {
    final binding = FeedbackBinding();
    binding.dependencies();

    expect(Get.isRegistered<SupportRepository>(), isTrue);
    expect(Get.isRegistered<FeedbackController>(), isTrue);
  });

  test('FeedbackBinding is idempotent when SupportRepository is already registered', () {
    // Pre-register so the binding's guard skips re-registration of the repo.
    Get.lazyPut<SupportRepository>(() => SupportRepository());

    final binding = FeedbackBinding();
    expect(() => binding.dependencies(), returnsNormally);

    expect(Get.isRegistered<SupportRepository>(), isTrue);
    expect(Get.isRegistered<FeedbackController>(), isTrue);
  });
}
