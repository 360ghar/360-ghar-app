import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/mixins/theme_mixin.dart';
import 'package:ghar360/core/widgets/common/robust_network_image.dart';
import 'package:ghar360/features/profile/presentation/controllers/edit_profile_controller.dart';

class EditProfileView extends GetView<EditProfileController> with ThemeMixin {
  const EditProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return buildThemeAwareScaffold(
      title: 'edit_profile'.tr,
      body: Semantics(
        label: 'qa.profile.edit.screen',
        identifier: 'qa.profile.edit.screen',
        child: Obx(() {
          final isSaving = controller.isSaving.value;
          final isUploadingImage = controller.isUploadingImage.value;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: controller.formKey,
              child: Column(
                children: [
                  // Profile Picture Section — form stays mounted during image upload
                  Center(
                    child: Stack(
                      children: [
                        Obx(() {
                          final avatar = controller.profileImageUrl.value.isNotEmpty
                              ? RobustNetworkImageExtension.circular(
                                  imageUrl: controller.profileImageUrl.value,
                                  radius: 60,
                                  errorWidget: CircleAvatar(
                                    radius: 60,
                                    backgroundColor: AppDesign.primaryYellow,
                                    child: Text(
                                      controller.nameController.text.isNotEmpty
                                          ? controller.nameController.text[0].toUpperCase()
                                          : 'user_initial'.tr,
                                      style: TextStyle(
                                        fontSize: 40,
                                        fontWeight: FontWeight.bold,
                                        color: AppDesign.buttonText,
                                      ),
                                    ),
                                  ),
                                )
                              : CircleAvatar(
                                  radius: 60,
                                  backgroundColor: AppDesign.primaryYellow,
                                  child: Text(
                                    controller.nameController.text.isNotEmpty
                                        ? controller.nameController.text[0].toUpperCase()
                                        : 'user_initial'.tr,
                                    style: TextStyle(
                                      fontSize: 40,
                                      fontWeight: FontWeight.bold,
                                      color: AppDesign.buttonText,
                                    ),
                                  ),
                                );

                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              avatar,
                              if (isUploadingImage)
                                Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color: AppDesign.overlayDark.withValues(alpha: 0.45),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: SizedBox(
                                      width: 28,
                                      height: 28,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          AppDesign.primaryYellow,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        }),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppDesign.primaryYellow,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppDesign.surface, width: 3),
                            ),
                            child: IconButton(
                              key: const ValueKey('qa.profile.edit.pick_image'),
                              icon: Icon(Icons.camera_alt, color: AppDesign.buttonText, size: 20),
                              onPressed: isUploadingImage || isSaving
                                  ? null
                                  : controller.pickProfileImage,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Form Fields
                  buildThemeAwareCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        buildSectionTitle('personal_information'.tr),
                        const SizedBox(height: 20),
                        _buildTextField(
                          controller: controller.nameController,
                          label: 'full_name'.tr,
                          icon: Icons.person_outline,
                          qaKey: 'qa.profile.edit.full_name_input',
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'name_required'.tr;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: controller.emailController,
                          label: 'email_address'.tr,
                          icon: Icons.email_outlined,
                          qaKey: 'qa.profile.edit.email_input',
                          keyboardType: TextInputType.emailAddress,
                          enabled: false, // Email is read-only; changes require re-verification
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: controller.locationController,
                          label: 'location'.tr,
                          icon: Icons.location_on_outlined,
                          qaKey: 'qa.profile.edit.location_input',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Date of Birth Section
                  buildThemeAwareCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        buildSectionTitle('additional_information'.tr),
                        const SizedBox(height: 20),
                        Semantics(
                          label: 'qa.profile.edit.dob_input',
                          identifier: 'qa.profile.edit.dob_input',
                          child: GestureDetector(
                            key: const ValueKey('qa.profile.edit.dob_input'),
                            onTap: isSaving ? null : () => controller.selectDateOfBirth(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              decoration: BoxDecoration(
                                color: AppDesign.inputBackground,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppDesign.border),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today, color: AppDesign.iconColor),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Obx(
                                      () => Text(
                                        controller.dateOfBirth.value != null
                                            ? controller.formatDate(controller.dateOfBirth.value!)
                                            : 'select_your_date_of_birth'.tr,
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: controller.dateOfBirth.value != null
                                              ? AppDesign.textPrimary
                                              : AppDesign.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (controller.dateOfBirth.value != null)
                                    GestureDetector(
                                      onTap: isSaving ? null : controller.clearDateOfBirth,
                                      child: Icon(
                                        Icons.clear,
                                        color: AppDesign.iconColor,
                                        size: 20,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: Semantics(
                      label: 'qa.profile.edit.save',
                      identifier: 'qa.profile.edit.save',
                      child: ElevatedButton(
                        key: const ValueKey('qa.profile.edit.save'),
                        onPressed: isSaving || isUploadingImage ? null : controller.saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppDesign.buttonBackground,
                          foregroundColor: AppDesign.buttonText,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: isSaving
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation<Color>(AppDesign.buttonText),
                                ),
                              )
                            : Text(
                                'save_changes'.tr,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? qaKey,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool enabled = true,
  }) {
    return Semantics(
      label: qaKey,
      identifier: qaKey,
      child: TextFormField(
        key: qaKey != null ? ValueKey(qaKey) : null,
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        enabled: enabled,
        style: TextStyle(color: AppDesign.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: AppDesign.textSecondary),
          prefixIcon: Icon(icon, color: AppDesign.iconColor),
          filled: true,
          fillColor: AppDesign.inputBackground,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppDesign.primaryYellow, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppDesign.border),
          ),
        ),
      ),
    );
  }
}
