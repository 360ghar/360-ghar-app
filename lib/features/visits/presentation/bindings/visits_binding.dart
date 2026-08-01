import 'package:get/get.dart';

import 'package:ghar360/core/utils/repository_registration.dart';
import 'package:ghar360/features/visits/presentation/controllers/visits_controller.dart';

class VisitsBinding extends Bindings {
  @override
  void dependencies() {
    RepositoryRegistration.ensureVisitsRepository();

    if (!Get.isRegistered<VisitsController>()) {
      Get.lazyPut<VisitsController>(() => VisitsController(), fenix: true);
    }
  }
}
