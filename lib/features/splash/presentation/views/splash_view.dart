import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/app_design_tokens.dart';
import 'package:ghar360/core/utils/app_spacing.dart';
import 'package:ghar360/core/utils/responsive.dart';
import 'package:ghar360/core/widgets/common/max_content_width.dart';
import 'package:ghar360/core/widgets/frosted_glass_container.dart';
import 'package:ghar360/features/splash/presentation/controllers/splash_controller.dart';

class SplashView extends GetView<SplashController> {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    final slides = _onboardingSlides;
    // Width cap for the centered content column on tablet/desktop so the
    // skip button, slide text and bottom dock don't stretch full-bleed.
    // `null` on compact → MaxContentWidth is a full-bleed no-op (phone unchanged).
    final dockWidthCap = context.isTabletWidth ? 560.0 : null;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      key: const ValueKey('qa.splash.screen'),
      backgroundColor: AppDesign.overlayDark,
      body: Stack(
        children: [
          // Full-bleed paged background (image + gradient stay edge-to-edge).
          PageView.builder(
            controller: controller.pageController,
            itemCount: slides.length,
            onPageChanged: (index) => controller.currentStep.value = index,
            itemBuilder: (context, index) => _OnboardingSlideCard(
              slide: slides[index],
              fadeAnimation: controller.fadeAnimation,
              slideAnimation: controller.slideAnimation,
            ),
          ),
          // Skip button anchored to the top-right of the centered content area,
          // not the raw screen edge — so it tracks the capped column on tablets.
          Positioned(
            top: topPadding + 16,
            left: 0,
            right: 0,
            child: MaxContentWidth(
              maxWidth: dockWidthCap,
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: Semantics(
                    label: 'qa.splash.skip',
                    identifier: 'qa.splash.skip',
                    child: TextButton(
                      key: const ValueKey('qa.splash.skip'),
                      onPressed: controller.skipToHome,
                      style: TextButton.styleFrom(
                        backgroundColor: AppDesign.overlayDark.withValues(alpha: 0.3),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: Text(
                        'skip'.tr,
                        style: const TextStyle(
                          color: AppDesign.overlayLight,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Bottom dock centered + capped so it doesn't span the full iPad width.
          Positioned(
            bottom: bottomInset + 20,
            left: 0,
            right: 0,
            child: MaxContentWidth(
              maxWidth: dockWidthCap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _FrostedBottomDock(slides: slides, controller: controller),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_OnboardingSlideModel> get _onboardingSlides => const [
    _OnboardingSlideModel(
      backgroundImagePath: 'assets/images/onboarding_slide_1.jpg',
      titleKey: 'onboarding_slide_1_title',
      descriptionKey: 'onboarding_slide_1_desc',
      points: [
        'onboarding_slide_1_point_1',
        'onboarding_slide_1_point_2',
        'onboarding_slide_1_point_3',
      ],
      accentColor: AppDesignTokens.brandGold,
      chipLabelKey: 'onboarding_chip_live_tours',
    ),
    _OnboardingSlideModel(
      backgroundImagePath: 'assets/images/onboarding_slide_2.jpg',
      titleKey: 'onboarding_slide_2_title',
      descriptionKey: 'onboarding_slide_2_desc',
      points: [
        'onboarding_slide_2_point_1',
        'onboarding_slide_2_point_2',
        'onboarding_slide_2_point_3',
      ],
      accentColor: AppDesignTokens.accentBlue,
      chipLabelKey: 'onboarding_chip_verified',
    ),
    _OnboardingSlideModel(
      backgroundImagePath: 'assets/images/onboarding_slide_3.jpg',
      titleKey: 'onboarding_slide_3_title',
      descriptionKey: 'onboarding_slide_3_desc',
      points: [
        'onboarding_slide_3_point_1',
        'onboarding_slide_3_point_2',
        'onboarding_slide_3_point_3',
      ],
      accentColor: AppDesignTokens.accentGreen,
      chipLabelKey: 'onboarding_chip_support',
    ),
  ];
}

class _OnboardingSlideCard extends StatelessWidget {
  const _OnboardingSlideCard({
    required this.slide,
    required this.fadeAnimation,
    required this.slideAnimation,
  });

  final _OnboardingSlideModel slide;
  final Animation<double> fadeAnimation;
  final Animation<Offset> slideAnimation;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom + 180;

    return FadeTransition(
      opacity: fadeAnimation,
      child: SlideTransition(
        position: slideAnimation,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildBackgroundImage(),
            _buildGradientScrim(),
            _buildContent(context, bottomPadding),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundImage() {
    return Positioned.fill(
      child: Image.asset(
        slide.backgroundImagePath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                slide.accentColor.withValues(alpha: 0.3),
                AppDesign.overlayDark.withValues(alpha: 0.6),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGradientScrim() {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.35, 0.65, 1.0],
            colors: [
              AppDesign.overlayDark.withValues(alpha: 0.15),
              AppDesign.transparent,
              AppDesign.overlayDark.withValues(alpha: 0.4),
              AppDesign.overlayDark.withValues(alpha: 0.7),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, double bottomPadding) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: MaxContentWidth(
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, bottomPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildChip(context),
                const SizedBox(height: 16),
                _buildTitle(context),
                const SizedBox(height: 12),
                _buildDescription(context),
                const SizedBox(height: 24),
                _buildBulletPoints(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChip(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: slide.accentColor.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        slide.chipLabelKey.tr,
        style: const TextStyle(
          color: AppDesign.overlayDark,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    return Text(
      slide.titleKey.tr,
      style: const TextStyle(
        color: AppDesign.overlayLight,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.15,
        letterSpacing: -0.5,
      ),
    );
  }

  Widget _buildDescription(BuildContext context) {
    return Text(
      slide.descriptionKey.tr,
      style: TextStyle(
        color: AppDesign.overlayLight.withValues(alpha: 0.85),
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.5,
      ),
    );
  }

  Widget _buildBulletPoints(BuildContext context) {
    return FrostedGlassContainer(
      opacity: 0.08,
      blur: 12,
      borderRadius: 16,
      borderOpacity: 0.25,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: slide.points.map((point) => _buildBulletItem(point)).toList(),
      ),
    );
  }

  Widget _buildBulletItem(String pointKey) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: slide.accentColor.withValues(alpha: 0.25),
              shape: BoxShape.circle,
              border: Border.all(color: slide.accentColor, width: 1.5),
            ),
            child: Icon(Icons.check, size: 12, color: slide.accentColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              pointKey.tr,
              style: TextStyle(
                color: AppDesign.overlayLight.withValues(alpha: 0.95),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FrostedBottomDock extends StatelessWidget {
  const _FrostedBottomDock({required this.slides, required this.controller});

  final List<_OnboardingSlideModel> slides;
  final SplashController controller;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: AppDesign.overlayLight.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppDesign.overlayLight.withValues(alpha: 0.2), width: 1),
          ),
          child: Obx(() {
            final currentStep = controller.currentStep.value;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLineIndicators(currentStep),
                const SizedBox(height: 14),
                _buildNavigationButtons(currentStep),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildLineIndicators(int currentStep) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(slides.length, (index) {
        final selected = index == currentStep;
        return AnimatedContainer(
          duration: AppDurations.fast,
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          height: 2,
          width: selected ? 40 : 24,
          decoration: BoxDecoration(
            color: selected
                ? AppDesignTokens.brandGold
                : AppDesign.overlayLight.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }

  Widget _buildNavigationButtons(int currentStep) {
    return Row(
      children: [
        if (currentStep > 0)
          Expanded(
            child: Semantics(
              label: 'qa.splash.back',
              identifier: 'qa.splash.back',
              child: _FrostedOutlinedButton(
                key: const ValueKey('qa.splash.back'),
                onPressed: controller.previousStep,
                icon: Icons.arrow_back,
                label: 'back'.tr,
              ),
            ),
          )
        else
          const Spacer(),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Semantics(
            label: currentStep < slides.length - 1 ? 'qa.splash.next' : 'qa.splash.get_started',
            identifier: currentStep < slides.length - 1
                ? 'qa.splash.next'
                : 'qa.splash.get_started',
            child: FilledButton.icon(
              key: ValueKey(
                currentStep < slides.length - 1 ? 'qa.splash.next' : 'qa.splash.get_started',
              ),
              onPressed: controller.nextStep,
              style: FilledButton.styleFrom(
                backgroundColor: AppDesignTokens.brandGold,
                foregroundColor: AppDesign.overlayDark,
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: Icon(
                currentStep < slides.length - 1 ? Icons.arrow_forward : Icons.check_circle_outline,
                size: 18,
              ),
              label: Text(
                currentStep < slides.length - 1 ? 'next'.tr : 'get_started'.tr,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FrostedOutlinedButton extends StatelessWidget {
  const _FrostedOutlinedButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: key,
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppDesign.overlayLight,
        side: BorderSide(color: AppDesign.overlayLight.withValues(alpha: 0.4), width: 1.5),
        backgroundColor: AppDesign.overlayLight.withValues(alpha: 0.1),
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

class _OnboardingSlideModel {
  const _OnboardingSlideModel({
    required this.backgroundImagePath,
    required this.titleKey,
    required this.descriptionKey,
    required this.points,
    required this.accentColor,
    required this.chipLabelKey,
  });

  final String backgroundImagePath;
  final String titleKey;
  final String descriptionKey;
  final List<String> points;
  final Color accentColor;
  final String chipLabelKey;
}
