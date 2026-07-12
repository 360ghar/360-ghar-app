import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/core/utils/app_toast.dart';
import 'package:ghar360/core/utils/password_validators.dart';
import 'package:ghar360/features/auth/presentation/controllers/signup_controller.dart';
import 'package:ghar360/features/auth/presentation/widgets/auth_premium_shell.dart';
import 'package:ghar360/features/auth/presentation/widgets/otp_input_field.dart';
import 'package:url_launcher/url_launcher.dart';

class SignUpView extends GetView<SignUpController> {
  const SignUpView({super.key});

  static final Uri _termsUri = Uri.parse('https://360ghar.com/policies');

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    final theme = Theme.of(context);

    return Semantics(
      label: 'qa.auth.signup.screen',
      identifier: 'qa.auth.signup.screen',
      child: Stack(
        children: [
          Obx(() {
            final step = controller.currentStep.value;
            final title = step == 0
                ? 'create_account'.tr
                : step == 1
                ? 'auth_signup_security_title'.tr
                : 'verify_your_account'.tr;

            return AuthPremiumShell(
              title: title,
              subtitle: '',
              chips: const [],
              onBack: step == 0
                  ? () => Get.offNamed(AppRoutes.phoneEntry)
                  : controller.previousStep,
              footer: step == 0
                  ? TextButton(
                      onPressed: () => Get.offNamed(AppRoutes.phoneEntry),
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            color: AppDesign.overlayLight.withValues(alpha: 0.7),
                            fontSize: 14,
                          ),
                          children: [
                            TextSpan(text: 'already_have_account'.tr),
                            TextSpan(
                              text: ' ${'sign_in'.tr}',
                              style: const TextStyle(
                                color: AppDesign.primaryYellow,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : null,
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildProgress(theme),
                    const SizedBox(height: 20),
                    if (step == 0) _buildPersonalStep(theme),
                    if (step == 1) _buildSecurityStep(theme),
                    if (step == 2) _buildOtpStep(theme),
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

  Widget _buildProgress(ThemeData theme) {
    return Obx(() {
      final step = controller.currentStep.value;
      final progress = (step + 1) / 3;

      return Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppDesign.overlayLight.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(AppDesign.primaryYellow),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                step == 0
                    ? 'personal_info_step'.tr
                    : step == 1
                    ? 'security_step'.tr
                    : 'verify_step'.tr,
                style: TextStyle(
                  color: AppDesign.overlayLight.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'step_of'.trParams({'step': '${step + 1}', 'total': '3'}),
                style: TextStyle(
                  color: AppDesign.overlayLight.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      );
    });
  }

  Widget _buildPersonalStep(ThemeData theme) {
    return Form(
      key: controller.personalInfoFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildIdentifierBanner(),
          Semantics(
            label: 'qa.auth.signup.full_name_input',
            identifier: 'qa.auth.signup.full_name_input',
            child: TextFormField(
              key: const ValueKey('qa.auth.signup.full_name_input'),
              controller: controller.fullNameController,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              style: const TextStyle(color: AppDesign.overlayLight),
              decoration: InputDecoration(
                labelText: 'full_name'.tr,
                prefixIcon: const Icon(Icons.person_outline),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'full_name_required'.tr;
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 14),
          _buildSecondaryIdentifierField(),
          const SizedBox(height: 14),
          Semantics(
            label: 'qa.auth.signup.dob_input',
            identifier: 'qa.auth.signup.dob_input',
            child: TextFormField(
              key: const ValueKey('qa.auth.signup.dob_input'),
              controller: controller.dateOfBirthController,
              readOnly: true,
              onTap: controller.selectDateOfBirth,
              style: const TextStyle(color: AppDesign.overlayLight),
              decoration: InputDecoration(
                labelText: 'date_of_birth'.tr,
                hintText: 'dob_format_hint'.tr,
                prefixIcon: const Icon(Icons.cake_outlined),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'dob_required'.tr;
                }
                return null;
              },
            ),
          ),
          Obx(() => AuthInlineError(message: controller.errorMessage.value)),
          const SizedBox(height: 20),
          SizedBox(
            height: 56,
            child: Semantics(
              label: 'qa.auth.signup.next',
              identifier: 'qa.auth.signup.next',
              child: FilledButton(
                key: const ValueKey('qa.auth.signup.next'),
                onPressed: controller.nextStep,
                child: Text(
                  'next'.tr,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppDesign.editorialInk,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentifierBanner() {
    return Obx(() {
      final isEmail = controller.isEmailSignup;
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppDesign.overlayLight.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppDesign.overlayLight.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppDesign.primaryYellow.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isEmail ? Icons.alternate_email : Icons.phone_outlined,
                color: AppDesign.primaryYellow,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                controller.identifier.value,
                style: const TextStyle(
                  color: AppDesign.overlayLight,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
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

  Widget _buildSecondaryIdentifierField() {
    return Obx(() {
      final isEmailSignup = controller.isEmailSignup;
      // Signing up by email → optional phone; by phone → optional email.
      return Semantics(
        label: 'qa.auth.signup.secondary_identifier_input',
        identifier: 'qa.auth.signup.secondary_identifier_input',
        child: TextFormField(
          key: const ValueKey('qa.auth.signup.secondary_identifier_input'),
          controller: controller.secondaryIdentifierController,
          keyboardType: isEmailSignup ? TextInputType.phone : TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: isEmailSignup
              ? const [AutofillHints.telephoneNumber]
              : const [AutofillHints.email],
          style: const TextStyle(color: AppDesign.overlayLight),
          decoration: InputDecoration(
            labelText: isEmailSignup ? 'phone_optional'.tr : 'email_optional'.tr,
            prefixIcon: Icon(isEmailSignup ? Icons.phone_outlined : Icons.email_outlined),
          ),
          validator: controller.validateSecondaryIdentifier,
        ),
      );
    });
  }

  Widget _buildSecurityStep(ThemeData theme) {
    return Form(
      key: controller.securityFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Obx(
            () => Semantics(
              label: 'qa.auth.signup.password_input',
              identifier: 'qa.auth.signup.password_input',
              child: TextFormField(
                key: const ValueKey('qa.auth.signup.password_input'),
                controller: controller.passwordController,
                obscureText: !controller.isPasswordVisible.value,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                style: const TextStyle(color: AppDesign.overlayLight),
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
                validator: PasswordValidators.validate,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Obx(() => _PasswordStrengthBar(strength: controller.passwordStrength.value)),
          const SizedBox(height: 14),
          Obx(
            () => Semantics(
              label: 'qa.auth.signup.confirm_password_input',
              identifier: 'qa.auth.signup.confirm_password_input',
              child: TextFormField(
                key: const ValueKey('qa.auth.signup.confirm_password_input'),
                controller: controller.confirmPasswordController,
                obscureText: !controller.isConfirmPasswordVisible.value,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                style: const TextStyle(color: AppDesign.overlayLight),
                decoration: InputDecoration(
                  labelText: 'confirm_password'.tr,
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: controller.toggleConfirmPasswordVisibility,
                    icon: Icon(
                      controller.isConfirmPasswordVisible.value
                          ? Icons.visibility_off
                          : Icons.visibility,
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
          ),
          const SizedBox(height: 12),
          Obx(
            () => CheckboxListTile(
              value: controller.isTermsAccepted.value,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (value) => controller.isTermsAccepted.value = value ?? false,
              title: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                children: [
                  Text(
                    'i_agree_to_the'.tr,
                    style: TextStyle(
                      color: AppDesign.overlayLight.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                  ),
                  GestureDetector(
                    onTap: _openTerms,
                    child: Text(
                      'terms_and_conditions'.tr,
                      style: const TextStyle(
                        color: AppDesign.primaryYellow,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Obx(() => AuthInlineError(message: controller.errorMessage.value)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: controller.isLoading.value ? null : controller.previousStep,
                  child: Text('back'.tr),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Obx(
                  () => Semantics(
                    label: 'qa.auth.signup.create_account',
                    identifier: 'qa.auth.signup.create_account',
                    child: FilledButton(
                      key: const ValueKey('qa.auth.signup.create_account'),
                      onPressed: controller.isLoading.value ? null : controller.nextStep,
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
                              'create_account'.tr,
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
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOtpStep(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Obx(
          () => Text(
            'otp_sent_to'.trParams({'identifier': controller.identifier.value}),
            style: TextStyle(color: AppDesign.overlayLight.withValues(alpha: 0.7), fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 20),
        OtpInputField(
          controller: controller.otpController,
          semanticsLabel: 'qa.auth.signup.otp_input',
          onCompleted: controller.verifyOtp,
        ),
        Obx(() => AuthInlineError(message: controller.errorMessage.value)),
        const SizedBox(height: 18),
        SizedBox(
          height: 56,
          child: Obx(
            () => Semantics(
              label: 'qa.auth.signup.verify_otp',
              identifier: 'qa.auth.signup.verify_otp',
              child: FilledButton(
                key: const ValueKey('qa.auth.signup.verify_otp'),
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
        const SizedBox(height: 8),
        OutlinedButton(onPressed: controller.goBackToForm, child: Text('back'.tr)),
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

  Future<void> _openTerms() async {
    try {
      final launched = await launchUrl(_termsUri, mode: LaunchMode.externalApplication);
      if (!launched) {
        AppToast.error('error'.tr, 'unable_to_open_link'.tr);
      }
    } catch (_) {
      AppToast.error('error'.tr, 'unable_to_open_link'.tr);
    }
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
