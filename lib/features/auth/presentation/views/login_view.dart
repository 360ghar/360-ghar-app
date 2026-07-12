import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:get/get.dart';

import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/features/auth/presentation/controllers/login_controller.dart';
import 'package:ghar360/features/auth/presentation/widgets/auth_premium_shell.dart';
import 'package:ghar360/features/auth/presentation/widgets/otp_input_field.dart';

class LoginView extends GetView<LoginController> {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    final theme = Theme.of(context);

    return Semantics(
      label: 'qa.auth.login.screen',
      identifier: 'qa.auth.login.screen',
      child: Stack(
        children: [
          Obx(() {
            final isOtp = controller.step.value == LoginStep.otp;
            return AuthPremiumShell(
              title: isOtp ? 'verify_your_account'.tr : 'welcome_back'.tr,
              subtitle: isOtp ? '' : 'auth_login_subtitle'.tr,
              onBack: () => Get.offNamed(AppRoutes.phoneEntry),
              chips: ['auth_chip_verified'.tr, 'auth_chip_private'.tr],
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildIdentifierDisplay(theme),
                    const SizedBox(height: 16),
                    if (isOtp) _buildOtpStep(theme) else _buildPasswordStep(theme),
                  ],
                ),
              ),
            );
          }),
          _buildResolvingOverlay(authController),
        ],
      ),
    );
  }

  Widget _buildIdentifierDisplay(ThemeData theme) {
    return Obx(() {
      final isEmail = controller.isEmail;
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppDesign.overlayLight.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppDesign.overlayLight.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppDesign.primaryYellow.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isEmail ? Icons.alternate_email : Icons.phone_outlined,
                color: AppDesign.primaryYellow,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEmail ? 'email_address'.tr : 'phone_number'.tr,
                    style: TextStyle(
                      color: AppDesign.overlayLight.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    controller.identifier.value,
                    style: const TextStyle(
                      color: AppDesign.overlayLight,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Get.offNamed(AppRoutes.phoneEntry),
              style: TextButton.styleFrom(
                foregroundColor: AppDesign.primaryYellow,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text('change'.tr),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildPasswordStep(ThemeData theme) {
    return Form(
      key: controller.passwordFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPasswordField(theme),
          Align(
            alignment: Alignment.centerRight,
            child: Semantics(
              label: 'qa.auth.login.forgot_password',
              identifier: 'qa.auth.login.forgot_password',
              child: TextButton(
                key: const ValueKey('qa.auth.login.forgot_password'),
                onPressed: () => Get.toNamed(AppRoutes.forgotPassword),
                child: Text('forgot_password'.tr),
              ),
            ),
          ),
          Obx(() => AuthInlineError(message: controller.errorMessage.value)),
          const SizedBox(height: 16),
          _buildSubmitButton(theme),
        ],
      ),
    );
  }

  Widget _buildPasswordField(ThemeData theme) {
    return Obx(
      () => Semantics(
        label: 'qa.auth.login.password_input',
        identifier: 'qa.auth.login.password_input',
        child: TextFormField(
          key: const ValueKey('qa.auth.login.password_input'),
          controller: controller.passwordController,
          autofocus: true,
          obscureText: !controller.isPasswordVisible.value,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          onFieldSubmitted: (_) => controller.signIn(),
          style: const TextStyle(color: AppDesign.overlayLight),
          // Login only requires non-empty; min-length is for create/change password.
          // Existing accounts may predate the 8-char policy.
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'password_required'.tr;
            }
            return null;
          },
          decoration: InputDecoration(
            labelText: 'password'.tr,
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              onPressed: controller.togglePasswordVisibility,
              icon: Icon(
                controller.isPasswordVisible.value ? Icons.visibility_off : Icons.visibility,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton(ThemeData theme) {
    return SizedBox(
      height: 56,
      child: Obx(
        () => Semantics(
          label: 'qa.auth.login.submit',
          identifier: 'qa.auth.login.submit',
          child: FilledButton(
            key: const ValueKey('qa.auth.login.submit'),
            onPressed: controller.isLoading.value
                ? null
                : () {
                    HapticFeedback.mediumImpact();
                    controller.signIn();
                  },
            child: controller.isLoading.value
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2, color: AppDesign.editorialInk),
                  )
                : Text(
                    'sign_in'.tr,
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

  Widget _buildOtpStep(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'otp_sent_to'.trParams({'identifier': controller.identifier.value}),
          style: TextStyle(color: AppDesign.overlayLight.withValues(alpha: 0.7), fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        OtpInputField(
          controller: controller.otpController,
          semanticsLabel: 'qa.auth.login.otp_input',
          onCompleted: controller.verifyOtp,
        ),
        Obx(() => AuthInlineError(message: controller.errorMessage.value)),
        const SizedBox(height: 18),
        SizedBox(
          height: 56,
          child: Obx(
            () => Semantics(
              label: 'qa.auth.login.verify_otp',
              identifier: 'qa.auth.login.verify_otp',
              child: FilledButton(
                key: const ValueKey('qa.auth.login.verify_otp'),
                onPressed: controller.isLoading.value ? null : () => controller.verifyOtp(),
                child: controller.isLoading.value
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: AppDesign.editorialInk,
                        ),
                      )
                    : Text(
                        'verify_otp'.tr,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppDesign.editorialInk,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Obx(
          () => TextButton(
            onPressed: controller.canResendOtp.value ? controller.resendOtp : null,
            style: TextButton.styleFrom(
              foregroundColor: controller.canResendOtp.value
                  ? AppDesign.primaryYellow
                  : AppDesign.overlayLight.withValues(alpha: 0.38),
            ),
            child: Text(
              controller.canResendOtp.value
                  ? 'resend_code'.tr
                  : '${'resend_in'.tr} ${controller.otpCountdown.value}s',
            ),
          ),
        ),
      ],
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
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: BoxDecoration(
                  color: AppDesign.overlayLight.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppDesign.overlayLight.withValues(alpha: 0.18)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppDesign.primaryYellow,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'loading'.tr,
                      style: const TextStyle(
                        color: AppDesign.overlayLight,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
