// lib/features/splash/presentation/controllers/splash_controller.dart

import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/data/models/auth_status.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/core/utils/debug_logger.dart';

class SplashController extends GetxController with GetTickerProviderStateMixin {
  // The splash controller is now only responsible for splash screen animations,
  // not navigation. All navigation logic is handled by the Root widget.

  PageController? pageController;
  AnimationController? animationController;
  Animation<double>? fadeAnimation;
  Animation<Offset>? slideAnimation;
  Animation<double>? scaleAnimation;
  Animation<double>? rotationAnimation;

  final RxInt currentStep = 0.obs;
  final GetStorage _storage = GetStorage();

  @override
  void onInit() {
    super.onInit();
    _initializeAnimations();
    pageController = PageController();
  }

  void _initializeAnimations() {
    final ac = AnimationController(duration: const Duration(milliseconds: 1000), vsync: this);
    animationController = ac;

    fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: ac, curve: Curves.easeInOut));

    slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: ac, curve: Curves.easeOutCubic));

    scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: ac, curve: Curves.easeOutBack));

    rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: ac, curve: Curves.easeInOut));

    ac.forward();
  }

  void nextStep() {
    if (currentStep.value < 2) {
      currentStep.value++;
      pageController?.animateToPage(
        currentStep.value,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboardingAndNavigate();
    }
  }

  void previousStep() {
    if (currentStep.value > 0) {
      currentStep.value--;
      pageController?.animateToPage(
        currentStep.value,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void skipToHome() {
    _completeOnboardingAndNavigate();
  }

  void _completeOnboardingAndNavigate() {
    try {
      _storage.write('has_seen_onboarding', true);
    } catch (e) {
      DebugLogger.warning('Failed to persist onboarding flag; will show again next launch', e);
    }

    // AuthNavigationService is the single source of truth for navigation
    // based on authStatus. Manually calling Get.offAllNamed here would race
    // with AuthNavigationService's ever() worker (which also reacts to
    // authStatus changes), causing double navigation. Persist the onboarding
    // flag (done above) and trigger a re-evaluation of the current auth
    // status so AuthNavigationService routes the user to the right screen.
    try {
      final auth = Get.find<AuthController>();
      if (auth.authStatus.value == AuthStatus.initial) {
        // Auth hasn't resolved yet; wait for it to settle, then navigate.
        Worker? worker;
        worker = ever(auth.authStatus, (AuthStatus status) {
          if (status != AuthStatus.initial) {
            worker?.dispose();
            auth.authStatus.refresh();
          }
        });
      } else {
        // Re-fire the navigation worker for the current status. This is safe
        // because AuthNavigationService's _handleAuthNavigation no-ops when
        // already on the target route.
        auth.authStatus.refresh();
      }
    } catch (_) {
      // If AuthController isn't registered, fall back to phone entry.
      Get.offAllNamed(AppRoutes.phoneEntry);
    }
  }

  @override
  void onClose() {
    animationController?.dispose();
    pageController?.dispose();
    super.onClose();
  }
}
