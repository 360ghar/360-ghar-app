import 'package:get/get.dart';

import 'package:ghar360/core/controllers/page_state_service.dart';
import 'package:ghar360/core/utils/repository_registration.dart';
import 'package:ghar360/features/likes/presentation/controllers/likes_controller.dart';
import 'package:ghar360/features/property_details/presentation/controllers/property_details_controller.dart';
import 'package:ghar360/features/visits/presentation/controllers/visits_controller.dart';

class PropertyDetailsBinding extends Bindings {
  @override
  void dependencies() {
    RepositoryRegistration.ensurePropertiesRepository();
    RepositoryRegistration.ensureSwipesRepository();
    RepositoryRegistration.ensureVisitsRepository();

    // Register PageStateService if not already registered (required by LikesController)
    if (!Get.isRegistered<PageStateService>()) {
      Get.lazyPut<PageStateService>(() => PageStateService(), fenix: true);
    }

    // Register LikesController for favorite management
    if (!Get.isRegistered<LikesController>()) {
      Get.lazyPut<LikesController>(() => LikesController(), fenix: true);
    }

    // Register VisitsController if not already registered
    if (!Get.isRegistered<VisitsController>()) {
      Get.lazyPut<VisitsController>(() => VisitsController(), fenix: true);
    }

    // Always create a fresh PropertyDetailsController for each navigation
    // This ensures Get.arguments/parameters are read correctly for the new property
    if (Get.isRegistered<PropertyDetailsController>()) {
      Get.delete<PropertyDetailsController>(force: true);
    }
    Get.put<PropertyDetailsController>(PropertyDetailsController());
  }
}
