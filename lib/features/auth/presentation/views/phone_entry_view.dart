import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/utils/app_spacing.dart';
import 'package:ghar360/core/widgets/common/shake_widget.dart';
import 'package:ghar360/features/auth/data/auth_method.dart';
import 'package:ghar360/features/auth/presentation/controllers/phone_entry_controller.dart';
import 'package:ghar360/features/auth/presentation/widgets/auth_premium_shell.dart';
import 'package:ghar360/features/auth/presentation/widgets/google_sign_in_button.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class PhoneEntryView extends GetView<PhoneEntryController> {
  const PhoneEntryView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: 'qa.auth.phone_entry.screen',
      identifier: 'qa.auth.phone_entry.screen',
      child: AuthPremiumShell(
        key: const ValueKey('qa.auth.phone_entry.screen'),
        title: 'auth_entry_title'.tr,
        subtitle: 'auth_entry_subtitle'.tr,
        chips: ['auth_chip_verified'.tr, 'auth_chip_transparent'.tr, 'auth_chip_support'.tr],
        footer: Text('terms_footer'.tr, textAlign: TextAlign.center),
        child: AutofillGroup(
          child: Form(
            key: controller.formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildLastMethodHint(theme),
                _buildSocialButtons(),
                _buildIdentifierField(theme),
                Obx(() => AuthInlineError(message: controller.errorMessage.value)),
                const SizedBox(height: 20),
                _buildContinueButton(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLastMethodHint(ThemeData theme) {
    return Obx(() {
      final method = controller.lastMethod.value;
      if (method == null) {
        return const SizedBox.shrink();
      }
      final hint = controller.lastIdentifierHint.value;
      final label = _lastMethodLabel(method);
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppDesign.primaryYellow.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppDesign.primaryYellow.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.history, size: 18, color: AppDesign.primaryYellow),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hint.isNotEmpty
                    ? 'last_used_method_with_hint'.trParams({'method': label, 'hint': hint})
                    : 'last_used_method'.trParams({'method': label}),
                style: TextStyle(
                  color: AppDesign.overlayLight.withValues(alpha: 0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  String _lastMethodLabel(AuthMethod method) {
    switch (method) {
      case AuthMethod.google:
        return 'auth_method_google'.tr;
      case AuthMethod.apple:
        return 'auth_method_apple'.tr;
      case AuthMethod.emailPassword:
      case AuthMethod.emailOtp:
        return 'auth_method_email'.tr;
      case AuthMethod.phonePassword:
      case AuthMethod.phoneOtp:
        return 'auth_method_phone'.tr;
    }
  }

  Widget _buildSocialButtons() {
    // Platform availability never changes at runtime, so it stays plain
    // (non-reactive) code. Only the Google loading spinner needs an Obx —
    // wrapping the whole tree caused GetX "improper use" on iOS, where the
    // Google button (the only reactive read) is hidden (see RELEASE_IOS.md).
    final showGoogle = controller.isGoogleAvailable && !(kIsWeb || Platform.isIOS);
    final showApple = controller.isAppleAvailable;
    if (!showGoogle && !showApple) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        children: [
          // Apple first on iOS, at least as prominent as Google (HIG).
          if (showApple) ...[
            Semantics(
              label: 'qa.auth.apple_signin',
              identifier: 'qa.auth.apple_signin',
              child: SizedBox(
                height: 54,
                child: SignInWithAppleButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    controller.signInWithApple();
                  },
                  style: SignInWithAppleButtonStyle.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (showGoogle)
            Obx(
              () => GoogleSignInButton(
                isLoading: controller.isGoogleLoading.value,
                onPressed: () {
                  HapticFeedback.selectionClick();
                  controller.signInWithGoogle();
                },
              ),
            ),
          const SizedBox(height: 18),
          _buildDivider(),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: AppDesign.overlayLight.withValues(alpha: 0.2))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'or'.tr,
            style: TextStyle(
              color: AppDesign.overlayLight.withValues(alpha: 0.6),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(child: Divider(color: AppDesign.overlayLight.withValues(alpha: 0.2))),
      ],
    );
  }

  Widget _buildIdentifierField(ThemeData theme) {
    return Obx(() {
      final isFocused = controller.isIdentifierFocused.value;
      final shakeTrigger = controller.validationShakeTrigger.value;
      final looksLikeEmail = controller.looksLikeEmail.value;

      return ShakeWidget(
        trigger: shakeTrigger,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: isFocused
                ? [
                    BoxShadow(
                      color: AppDesign.overlayLight.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : [],
          ),
          child: Semantics(
            label: 'qa.auth.phone_entry.identifier_input',
            identifier: 'qa.auth.phone_entry.identifier_input',
            child: TextFormField(
              key: const ValueKey('qa.auth.phone_entry.identifier_input'),
              controller: controller.identifierController,
              focusNode: controller.identifierFocusNode,
              autofocus: true,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              // Email-friendly keyboard works for both email and phone input
              // (digits remain reachable) and avoids re-rendering on each keystroke.
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.email, AutofillHints.telephoneNumber],
              onTap: controller.requestPhoneNumberHint,
              validator: controller.validateIdentifier,
              onFieldSubmitted: (_) => controller.checkAndNavigate(),
              style: const TextStyle(
                color: AppDesign.overlayLight,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'identifier_hint'.tr,
                labelText: 'identifier_label'.tr,
                prefixIcon: Icon(looksLikeEmail ? Icons.alternate_email : Icons.person_outline),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildContinueButton(ThemeData theme) {
    return SizedBox(
      height: 56,
      child: Obx(
        () => Semantics(
          label: 'qa.auth.phone_entry.continue',
          identifier: 'qa.auth.phone_entry.continue',
          child: FilledButton(
            key: const ValueKey('qa.auth.phone_entry.continue'),
            onPressed: controller.isLoading.value
                ? null
                : () {
                    HapticFeedback.mediumImpact();
                    controller.checkAndNavigate();
                  },
            child: controller.isLoading.value
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Color(0xFF8C6B52),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'checking_account'.tr,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF8C6B52),
                        ),
                      ),
                    ],
                  )
                : Text(
                    'continue_btn'.tr,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF8C6B52),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
