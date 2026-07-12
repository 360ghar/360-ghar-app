import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/utils/password_validators.dart';
import 'package:ghar360/features/auth/presentation/controllers/set_password_controller.dart';
import 'package:ghar360/features/auth/presentation/widgets/auth_premium_shell.dart';

/// Mandatory set-password screen (non-skippable, no back) shown after an OTP
/// login when the account has no password yet.
class SetPasswordView extends GetView<SetPasswordController> {
  const SetPasswordView({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();

    return Semantics(
      label: 'qa.auth.set_password.screen',
      identifier: 'qa.auth.set_password.screen',
      child: PopScope(
        canPop: false,
        child: Stack(
          children: [
            AuthPremiumShell(
              title: 'set_password_title'.tr,
              subtitle: 'set_password_subtitle'.tr,
              chips: const [],
              child: AutofillGroup(
                child: Form(
                  key: controller.formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildAccountHint(),
                      _buildPasswordField(),
                      const SizedBox(height: 10),
                      Obx(() => _PasswordStrengthBar(strength: controller.passwordStrength.value)),
                      const SizedBox(height: 14),
                      _buildConfirmField(),
                      Obx(() => AuthInlineError(message: controller.errorMessage.value)),
                      const SizedBox(height: 20),
                      _buildSubmitButton(),
                    ],
                  ),
                ),
              ),
            ),
            _buildResolvingOverlay(authController),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountHint() {
    final masked = controller.maskedIdentifier;
    if (masked.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppDesign.overlayLight.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppDesign.overlayLight.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            const Icon(Icons.account_circle_outlined, color: AppDesign.primaryYellow, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'set_password_for_account'.trParams({'identifier': masked}),
                style: TextStyle(
                  color: AppDesign.overlayLight.withValues(alpha: 0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return Obx(
      () => Semantics(
        label: 'qa.auth.set_password.password_input',
        identifier: 'qa.auth.set_password.password_input',
        child: TextFormField(
          key: const ValueKey('qa.auth.set_password.password_input'),
          controller: controller.passwordController,
          autofocus: true,
          obscureText: !controller.isPasswordVisible.value,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.newPassword],
          style: const TextStyle(color: AppDesign.overlayLight),
          decoration: InputDecoration(
            labelText: 'new_password'.tr,
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              onPressed: controller.togglePasswordVisibility,
              icon: Icon(
                controller.isPasswordVisible.value ? Icons.visibility_off : Icons.visibility,
              ),
            ),
          ),
          validator: PasswordValidators.validate,
        ),
      ),
    );
  }

  Widget _buildConfirmField() {
    return Obx(
      () => Semantics(
        label: 'qa.auth.set_password.confirm_password_input',
        identifier: 'qa.auth.set_password.confirm_password_input',
        child: TextFormField(
          key: const ValueKey('qa.auth.set_password.confirm_password_input'),
          controller: controller.confirmPasswordController,
          obscureText: !controller.isConfirmPasswordVisible.value,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.newPassword],
          onFieldSubmitted: (_) => controller.submit(),
          style: const TextStyle(color: AppDesign.overlayLight),
          decoration: InputDecoration(
            labelText: 'confirm_password'.tr,
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              onPressed: controller.toggleConfirmPasswordVisibility,
              icon: Icon(
                controller.isConfirmPasswordVisible.value ? Icons.visibility_off : Icons.visibility,
              ),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'confirm_password_required'.tr;
            }
            if (value != controller.passwordController.text) {
              return 'passwords_dont_match'.tr;
            }
            return null;
          },
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      height: 56,
      child: Obx(
        () => Semantics(
          label: 'qa.auth.set_password.submit',
          identifier: 'qa.auth.set_password.submit',
          child: FilledButton(
            key: const ValueKey('qa.auth.set_password.submit'),
            onPressed: controller.isLoading.value ? null : controller.submit,
            child: controller.isLoading.value
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2, color: AppDesign.editorialInk),
                  )
                : Text(
                    'set_password_cta'.tr,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppDesign.editorialInk,
                      fontSize: 16,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildResolvingOverlay(AuthController authController) {
    return Obx(() {
      if (!authController.isAuthResolving.value) {
        return const SizedBox.shrink();
      }
      return Positioned.fill(
        child: Stack(
          children: [
            ModalBarrier(dismissible: false, color: AppDesign.overlayDark.withValues(alpha: 0.7)),
            const Center(
              child: SizedBox(
                height: 28,
                width: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: AppDesign.primaryYellow),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _PasswordStrengthBar extends StatelessWidget {
  const _PasswordStrengthBar({required this.strength});

  final int strength;

  @override
  Widget build(BuildContext context) {
    if (strength == 0) {
      return const SizedBox.shrink();
    }

    late Color color;
    late String text;
    late double value;

    switch (strength) {
      case 1:
        color = AppDesign.errorRed;
        text = 'password_strength_weak'.tr;
        value = 0.33;
        break;
      case 2:
        color = AppDesign.warningAmber;
        text = 'password_strength_medium'.tr;
        value = 0.66;
        break;
      default:
        color = AppDesign.successGreen;
        text = 'password_strength_strong'.tr;
        value = 1.0;
    }

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 5,
              backgroundColor: AppDesign.overlayLight.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
