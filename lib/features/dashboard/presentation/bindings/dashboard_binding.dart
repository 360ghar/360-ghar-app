import 'package:get/get.dart';

import 'package:ghar360/core/controllers/page_state_service.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/utils/repository_registration.dart';
import 'package:ghar360/features/assistant/presentation/bindings/assistant_binding.dart';
import 'package:ghar360/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:ghar360/features/discover/presentation/bindings/discover_binding.dart';
import 'package:ghar360/features/explore/presentation/bindings/explore_binding.dart';
import 'package:ghar360/features/likes/presentation/bindings/likes_binding.dart';
import 'package:ghar360/features/profile/data/profile_repository.dart';
import 'package:ghar360/features/profile/presentation/bindings/profile_binding.dart';
import 'package:ghar360/features/visits/presentation/bindings/visits_binding.dart';

class DashboardBinding extends Bindings {
  @override
  void dependencies() {
    RepositoryRegistration.ensurePropertiesRepository();
    RepositoryRegistration.ensureSwipesRepository();

    if (!Get.isRegistered<ProfileRepository>()) {
      Get.lazyPut<ProfileRepository>(
        () => ProfileRepository(apiClient: Get.find<ApiClient>()),
        fenix: true,
      );
    }

    // Register PageStateService if not already registered
    if (!Get.isRegistered<PageStateService>()) {
      Get.lazyPut<PageStateService>(() => PageStateService(), fenix: true);
    }

    Get.lazyPut<DashboardController>(() => DashboardController());
    // Register feature bindings lazily; controllers instantiate on first use
    ProfileBinding().dependencies();
    ExploreBinding().dependencies();
    DiscoverBinding().dependencies();
    LikesBinding().dependencies();
    VisitsBinding().dependencies();
    AssistantBinding().dependencies();
  }
}
