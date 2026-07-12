// test/features/dashboard/presentation/bindings/dashboard_binding_test.dart
//
// Binding test for [DashboardBinding]. This is the composition root for the
// main app screens: it ensures the properties/swipes repositories are
// registered (via [RepositoryRegistration], which needs an [ApiClient]),
// registers [ProfileRepository] and [PageStateService], then delegates to the
// feature bindings ([ProfileBinding], [ExploreBinding], [DiscoverBinding],
// [LikesBinding], [VisitsBinding], [AssistantBinding]).
//
// Upstream dependencies pre-registered before calling `dependencies()`:
//   - [MockApiClient] — required by RepositoryRegistration and by the
//     ProfileRepository lazy factory (only resolved on first Get.find, so
//     registration itself does not require it, but it is seeded for fidelity).

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/controllers/page_state_service.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/features/assistant/data/assistant_repository.dart';
import 'package:ghar360/features/assistant/presentation/controllers/assistant_controller.dart';
import 'package:ghar360/features/dashboard/presentation/bindings/dashboard_binding.dart';
import 'package:ghar360/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:ghar360/features/discover/presentation/controllers/discover_controller.dart';
import 'package:ghar360/features/explore/presentation/controllers/explore_controller.dart';
import 'package:ghar360/features/likes/presentation/controllers/likes_controller.dart';
import 'package:ghar360/features/profile/data/profile_repository.dart';
import 'package:ghar360/features/profile/presentation/controllers/edit_profile_controller.dart';
import 'package:ghar360/features/profile/presentation/controllers/profile_controller.dart';
import 'package:ghar360/features/properties/data/properties_repository.dart';
import 'package:ghar360/features/swipes/data/swipes_repository.dart';
import 'package:ghar360/features/visits/presentation/controllers/visits_controller.dart';

import '../../../../helpers/getx_test_binding.dart';
import '../../../../helpers/mocks.dart';

void main() {
  setUp(() {
    GetxTestBinding.init();
    // RepositoryRegistration and the ProfileRepository factory resolve ApiClient
    // via Get.find; seed the container with a mock before running the binding.
    GetxTestBinding.bind().register<ApiClient>(MockApiClient());
  });

  tearDown(() => GetxTestBinding.reset());

  test('DashboardBinding registers all dependencies', () {
    final binding = DashboardBinding();
    binding.dependencies();

    // Repositories ensured via RepositoryRegistration.
    expect(Get.isRegistered<PropertiesRepository>(), isTrue);
    expect(Get.isRegistered<SwipesRepository>(), isTrue);

    // ProfileRepository + PageStateService registered directly by DashboardBinding.
    expect(Get.isRegistered<ProfileRepository>(), isTrue);
    expect(Get.isRegistered<PageStateService>(), isTrue);

    // Dashboard screen controller.
    expect(Get.isRegistered<DashboardController>(), isTrue);

    // Feature controllers registered via delegated feature bindings.
    expect(Get.isRegistered<ProfileController>(), isTrue);
    expect(Get.isRegistered<EditProfileController>(), isTrue);
    expect(Get.isRegistered<ExploreController>(), isTrue);
    expect(Get.isRegistered<DiscoverController>(), isTrue);
    expect(Get.isRegistered<LikesController>(), isTrue);
    expect(Get.isRegistered<VisitsController>(), isTrue);

    // AssistantBinding registers both the repository and the controller.
    expect(Get.isRegistered<AssistantRepository>(), isTrue);
    expect(Get.isRegistered<AssistantController>(), isTrue);
  });
}
