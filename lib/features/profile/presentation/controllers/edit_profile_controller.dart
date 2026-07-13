import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/utils/app_toast.dart';
import 'package:ghar360/features/profile/data/profile_repository.dart';
import 'package:image_picker/image_picker.dart';

class EditProfileController extends GetxController {
  final AuthController _authController = Get.find<AuthController>();
  final ProfileRepository _profileRepository = Get.find<ProfileRepository>();

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  // Form controllers
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController locationController = TextEditingController();

  // Observable fields
  final RxString profileImageUrl = ''.obs;
  final Rx<DateTime?> dateOfBirth = Rx<DateTime?>(null);

  /// True while saving profile form fields.
  final RxBool isSaving = false.obs;

  /// True while uploading a new profile image (form stays interactive).
  final RxBool isUploadingImage = false.obs;

  /// True when any profile mutation is in progress.
  bool get isBusy => isSaving.value || isUploadingImage.value;

  @override
  void onInit() {
    super.onInit();
    _loadUserData();
  }

  @override
  void onClose() {
    nameController.dispose();
    emailController.dispose();
    locationController.dispose();
    super.onClose();
  }

  void _loadUserData() {
    final user = _authController.currentUser.value;
    if (user != null) {
      nameController.text = user.name;
      emailController.text = user.email;
      profileImageUrl.value = user.profileImage ?? '';

      // Load date of birth from top-level field if present
      dateOfBirth.value = user.dateOfBirthAsDate;

      // Load additional fields from preferences if available
      final prefs = user.preferences;
      if (prefs?.containsKey('location') == true) {
        final location = prefs!['location'];
        locationController.text = location is String ? location : '';
      }
    }
  }

  Future<void> pickProfileImage() async {
    try {
      final picker = ImagePicker();
      final source = await Get.bottomSheet<ImageSource>(
        SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: Text('take_photo'.tr),
                onTap: () => Get.back(result: ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text('choose_from_gallery'.tr),
                onTap: () => Get.back(result: ImageSource.gallery),
              ),
            ],
          ),
        ),
      );

      if (source == null) return;

      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (pickedFile == null) return;

      // Upload immediately so the profile persists a real URL, not a local
      // device file path. The backend returns the updated user.
      isUploadingImage.value = true;
      final updatedUser = await _profileRepository.updateProfileImage(pickedFile.path);
      profileImageUrl.value = updatedUser.profileImage ?? '';
      _authController.currentUser.value = updatedUser;
      AppToast.success('success'.tr, 'profile_image_selected'.tr);
    } catch (e) {
      AppToast.error('error'.tr, 'failed_to_pick_image'.tr);
    } finally {
      isUploadingImage.value = false;
    }
  }

  Future<void> selectDateOfBirth(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: dateOfBirth.value ?? DateTime.now().subtract(const Duration(days: 365 * 25)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 13)), // Minimum 13 years old
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: const Color(0xFFFFBC05), // AppDesign.primaryYellow
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      dateOfBirth.value = picked;
    }
  }

  void clearDateOfBirth() {
    dateOfBirth.value = null;
  }

  String formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> saveProfile() async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    try {
      isSaving.value = true;

      final currentUser = _authController.currentUser.value;
      if (currentUser == null) {
        AppToast.error('error'.tr, 'user_data_not_found'.tr);
        return;
      }

      // Prepare updated preferences (keep app-specific data like location)
      final updatedPreferences = Map<String, dynamic>.from(currentUser.preferences ?? {});
      updatedPreferences['location'] = locationController.text.trim();

      // Prepare profile data for update (align with backend fields)
      final profileData = <String, dynamic>{
        'full_name': nameController.text.trim(),
        'profile_image_url': profileImageUrl.value.isEmpty ? null : profileImageUrl.value,
        'preferences': updatedPreferences,
      };

      // Save date of birth to top-level user field
      if (dateOfBirth.value != null) {
        final dob = dateOfBirth.value!;
        profileData['date_of_birth'] =
            '${dob.year.toString().padLeft(4, '0')}-${dob.month.toString().padLeft(2, '0')}-${dob.day.toString().padLeft(2, '0')}';
      } else {
        profileData['date_of_birth'] = null;
      }

      // Update user profile
      // Note: _authController.updateUserProfile() already shows a success toast
      await _authController.updateUserProfile(profileData);

      Get.back();
    } catch (e) {
      AppToast.error('error'.tr, 'profile_update_failed'.trParams({'error': e.toString()}));
    } finally {
      isSaving.value = false;
    }
  }
}
