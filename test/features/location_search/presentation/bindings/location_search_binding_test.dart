// test/features/location_search/presentation/bindings/location_search_binding_test.dart
//
// Binding test for [LocationSearchBinding]. Verifies that calling
// `dependencies()` registers [LocationSearchController] into the GetX
// container.

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:ghar360/features/location_search/presentation/bindings/location_search_binding.dart';
import 'package:ghar360/features/location_search/presentation/controllers/location_search_controller.dart';
import '../../../../helpers/getx_test_binding.dart';

void main() {
  setUp(() => GetxTestBinding.init());
  tearDown(() => GetxTestBinding.reset());

  test('LocationSearchBinding registers LocationSearchController', () {
    final binding = LocationSearchBinding();
    binding.dependencies();

    expect(Get.isRegistered<LocationSearchController>(), isTrue);
  });
}
