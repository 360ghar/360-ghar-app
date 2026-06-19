import 'package:get/get.dart';

import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/data/models/user_model.dart';

/// Controller for the profile view. Decouples profile-specific loading state
/// from [AuthController], so `isLoading` on the profile screen refers to
/// profile operations rather than the global auth bootstrap state.
///
/// User data is delegated to [AuthController] (the single source of truth for
/// the current user), but profile actions (refresh, sign out) are surfaced
/// here with their own loading flag.
class ProfileController extends GetxController {
  late final AuthController _authController;

  /// Profile-specific loading flag (e.g. for refresh / sign-out actions).
  final RxBool isProfileLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    _authController = Get.find<AuthController>();
  }

  /// The current user (reactive). Delegates to AuthController so profile
  /// updates propagate to the UI without duplicating user state.
  Rxn<UserModel> get currentUser => _authController.currentUser;

  /// True only when a profile action (refresh/sign-out) is in progress,
  /// NOT when the global auth bootstrap is resolving.
  bool get isLoading => isProfileLoading.value;

  Future<void> signOut() async {
    try {
      isProfileLoading.value = true;
      await _authController.signOut();
    } finally {
      isProfileLoading.value = false;
    }
  }
}
