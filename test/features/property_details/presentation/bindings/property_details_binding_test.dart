// test/features/property_details/presentation/bindings/property_details_binding_test.dart
//
// Binding test for [PropertyDetailsBinding]. This binding eagerly constructs
// [PropertyDetailsController] via `Get.put` (so its `onInit` runs and reads
// `Get.arguments`), and it ensures the properties/swipes repositories are
// registered via [RepositoryRegistration] (which needs an [ApiClient]). The
// binding also lazily registers [VisitsController], which
// `PropertyDetailsController.onInit` instantiates via `Get.find`; that
// controller's `onInit` reads [AuthController], so a mock must be seeded.
//
// Upstream dependencies pre-registered before calling `dependencies()`:
//   - [MockApiClient] — required by RepositoryRegistration to construct the
//     repositories.
//   - [MockAuthController] — required by VisitsController.onInit. Stubbed as
//     unauthenticated so VisitsController does not attempt to fetch visits.
//
// `Get.arguments` is reset to null so the eagerly-constructed controller's
// `onInit` resolves to the "property not found" path without throwing.

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/controllers/page_state_service.dart';
import 'package:ghar360/core/data/models/auth_status.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/features/likes/presentation/controllers/likes_controller.dart';
import 'package:ghar360/features/properties/data/properties_repository.dart';
import 'package:ghar360/features/property_details/presentation/bindings/property_details_binding.dart';
import 'package:ghar360/features/property_details/presentation/controllers/property_details_controller.dart';
import 'package:ghar360/features/swipes/data/swipes_repository.dart';
import 'package:ghar360/features/visits/presentation/controllers/visits_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/getx_test_binding.dart';
import '../../../../helpers/mocks.dart';

void main() {
  setUp(() {
    GetxTestBinding.init();

    final mockAuthController = MockAuthController();
    when(() => mockAuthController.authStatus).thenReturn(AuthStatus.unauthenticated.obs);
    when(() => mockAuthController.isAuthenticated).thenReturn(false);

    GetxTestBinding.bind()
      ..register<ApiClient>(MockApiClient())
      ..register<AuthController>(mockAuthController);

    // PropertyDetailsController.onInit reads Get.arguments; reset it to null so
    // the eager construction resolves to the "property not found" branch.
    Get.routing.update((r) => r.args = null);
  });

  tearDown(() => GetxTestBinding.reset());

  test('PropertyDetailsBinding registers all dependencies', () {
    final binding = PropertyDetailsBinding();
    binding.dependencies();

    // Repositories ensured via RepositoryRegistration.
    expect(Get.isRegistered<PropertiesRepository>(), isTrue);
    expect(Get.isRegistered<SwipesRepository>(), isTrue);

    // Shared services/controllers registered by the binding.
    expect(Get.isRegistered<PageStateService>(), isTrue);
    expect(Get.isRegistered<LikesController>(), isTrue);
    expect(Get.isRegistered<VisitsController>(), isTrue);

    // Screen controller — eagerly constructed via Get.put.
    expect(Get.isRegistered<PropertyDetailsController>(), isTrue);
  });
}
