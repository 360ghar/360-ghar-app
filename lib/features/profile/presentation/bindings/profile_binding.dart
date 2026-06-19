import 'package:get/get.dart';

import 'package:ghar360/features/profile/presentation/controllers/edit_profile_controller.dart';
import 'package:ghar360/features/profile/presentation/controllers/profile_controller.dart';

class ProfileBinding extends Bindings {
  @override
  void dependencies() {
    // AuthController is already registered in InitialBinding.
    Get.lazyPut<ProfileController>(() => ProfileController());
    Get.lazyPut<EditProfileController>(() => EditProfileController());
  }
}
