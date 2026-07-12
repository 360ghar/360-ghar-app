import 'package:get/get.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/features/auth/data/auth_repository.dart';

/// Result of [ChangePasswordController.changePassword].
enum ChangePasswordResult { success, incorrectCurrent, verificationUnavailable, updateFailed }

/// Domain logic for verifying the current password and setting a new one.
/// Keeps repository access out of the privacy view / dialog.
class ChangePasswordController extends GetxController {
  ChangePasswordController({AuthRepository? authRepository})
    : _authRepository = authRepository ?? Get.find<AuthRepository>();

  final AuthRepository _authRepository;

  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  Future<ChangePasswordResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      try {
        await _verifyCurrentPassword(currentPassword);
      } on PasswordVerificationUnavailable catch (e, st) {
        errorMessage.value = 'password_verification_unavailable'.tr;
        DebugLogger.warning('Password verification unavailable', e, st);
        return ChangePasswordResult.verificationUnavailable;
      } catch (e, st) {
        errorMessage.value = 'incorrect_password'.tr;
        DebugLogger.warning('Current password verification failed', e, st);
        return ChangePasswordResult.incorrectCurrent;
      }

      await _authRepository.updateUserPassword(newPassword);
      DebugLogger.success('Password changed from profile');
      return ChangePasswordResult.success;
    } catch (e, st) {
      errorMessage.value = 'failed_to_update_password'.tr;
      DebugLogger.error('Failed to change password from profile', e, st);
      return ChangePasswordResult.updateFailed;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _verifyCurrentPassword(String currentPassword) async {
    final authUser = _authRepository.currentUser;
    final email = authUser?.email?.trim();
    final phone = authUser?.phone?.trim();

    if (email != null && email.isNotEmpty) {
      await _authRepository.signInWithEmailPassword(email, currentPassword);
      return;
    }

    if (phone != null && phone.isNotEmpty) {
      await _authRepository.signInWithPhonePassword(phone, currentPassword);
      return;
    }

    throw const PasswordVerificationUnavailable();
  }
}

/// Thrown when the session has neither email nor phone to re-authenticate with.
class PasswordVerificationUnavailable implements Exception {
  const PasswordVerificationUnavailable();
}
