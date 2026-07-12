import 'dart:async';

import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'package:ghar360/core/controllers/app_update_controller.dart';
import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/data/models/auth_status.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/core/utils/debug_logger.dart';

/// Service responsible for navigating the user based on auth status changes.
///
/// This separates navigation side-effects from [AuthController], which now
/// only manages reactive auth state. Register this service after
/// [AuthController] in the binding so the worker fires for the initial status.
class AuthNavigationService extends GetxService {
  Worker? _authStatusWorker;
  int _navigationGeneration = 0;
  Timer? _retryTimer;
  Timer? _homeRetryTimer;

  @override
  void onInit() {
    super.onInit();
    final authController = Get.find<AuthController>();
    _authStatusWorker = ever(authController.authStatus, _handleAuthNavigation);
    DebugLogger.info('🧭 AuthNavigationService: listening for auth status changes');
    final initialStatus = authController.authStatus.value;
    DebugLogger.info('🧭 AuthNavigationService: handling initial auth status -> $initialStatus');
    _handleAuthNavigation(initialStatus);
  }

  /// Re-applies navigation for the current auth status (Root safety net when
  /// the first navigation attempt raced the navigator).
  void reapply() {
    if (!Get.isRegistered<AuthController>()) return;
    final status = Get.find<AuthController>().authStatus.value;
    DebugLogger.info('🧭 AuthNavigationService: reapply for status -> $status');
    _handleAuthNavigation(status);
  }

  void _handleAuthNavigation(AuthStatus status) {
    final generation = ++_navigationGeneration;
    _retryTimer?.cancel();
    _homeRetryTimer?.cancel();
    var ran = false;

    void runOnce() {
      if (ran || generation != _navigationGeneration) return;
      ran = true;
      DebugLogger.info('🧭 AuthNavigationService: handling auth status -> $status');

      try {
        _navigateForStatus(status);
      } catch (e, st) {
        DebugLogger.error('🧭 AuthNavigationService: navigation failed for $status', e, st);
        _scheduleRetry(status, generation);
        return;
      }

      // Only schedule a home-route retry when we are still on GetMaterialApp home.
      if (status != AuthStatus.initial &&
          status != AuthStatus.error &&
          _isStillOnHomeRoute()) {
        _scheduleRetryIfStillOnHome(status, generation);
      }
    }

    // Microtask: unit tests without a full frame cycle.
    // Post-frame: production, after GetMaterialApp navigator is mounted.
    Future.microtask(runOnce);
    WidgetsBinding.instance.addPostFrameCallback((_) => runOnce());
  }

  void _navigateForStatus(AuthStatus status) {
    switch (status) {
      case AuthStatus.initial:
        break;

      case AuthStatus.unauthenticated:
        final storage = GetStorage();
        final hasSeenOnboarding = storage.read('has_seen_onboarding') == true;
        if (!hasSeenOnboarding) {
          _goNamedIfNeeded(AppRoutes.splash);
        } else {
          _goNamedIfNeeded(AppRoutes.phoneEntry);
        }
        break;

      case AuthStatus.requiresPasswordSetup:
        _goNamedIfNeeded(AppRoutes.setPassword);
        break;

      case AuthStatus.requiresProfileCompletion:
        _goNamedIfNeeded(AppRoutes.profileCompletion);
        break;

      case AuthStatus.authenticated:
        final authController = Get.find<AuthController>();
        if (authController.redirectRoute.value != null) {
          navigateToRedirectRoute();
        } else {
          final navigated = _goNamedIfNeeded(AppRoutes.dashboard);
          if (navigated) {
            try {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (Get.isRegistered<AppUpdateController>()) {
                  Get.find<AppUpdateController>().scheduleCheckAfterFirstFrame();
                }
              });
            } catch (_) {}
          }
        }
        break;

      case AuthStatus.error:
        break;
    }
  }

  bool _goNamedIfNeeded(String route) {
    if (Get.currentRoute == route) return false;
    DebugLogger.info('🧭 AuthNavigationService: Get.offAllNamed($route)');
    Get.offAllNamed(route);
    return true;
  }

  void _scheduleRetry(AuthStatus status, int generation) {
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(milliseconds: 300), () {
      if (generation != _navigationGeneration) return;
      if (!Get.isRegistered<AuthController>()) return;
      if (Get.find<AuthController>().authStatus.value != status) return;
      DebugLogger.warning('🧭 AuthNavigationService: retrying navigation for $status');
      try {
        _navigateForStatus(status);
      } catch (e, st) {
        DebugLogger.error('🧭 AuthNavigationService: retry failed for $status', e, st);
      }
    });
  }

  void _scheduleRetryIfStillOnHome(AuthStatus status, int generation) {
    _homeRetryTimer?.cancel();
    _homeRetryTimer = Timer(const Duration(milliseconds: 400), () {
      if (generation != _navigationGeneration) return;
      if (!Get.isRegistered<AuthController>()) return;
      if (Get.find<AuthController>().authStatus.value != status) return;
      if (!_isStillOnHomeRoute()) return;
      DebugLogger.warning(
        '🧭 AuthNavigationService: still on home route after $status — retrying once',
      );
      try {
        _navigateForStatus(status);
      } catch (e, st) {
        DebugLogger.error('🧭 AuthNavigationService: home-route retry failed', e, st);
      }
    });
  }

  /// True when GetX has not left the MaterialApp [home] (Root) yet.
  bool _isStillOnHomeRoute() {
    final current = Get.currentRoute;
    return current.isEmpty || current == '/' || current == '/Root';
  }

  /// Navigates to the stored redirect route and clears it.
  void navigateToRedirectRoute() {
    final authController = Get.find<AuthController>();
    final route = authController.redirectRoute.value;
    if (route != null && route.name != null) {
      DebugLogger.info('🔄 Navigating to stored redirect route: ${route.name}');
      Get.offAllNamed(route.name!, arguments: route.arguments);
      authController.redirectRoute.value = null;
    }
  }

  @override
  void onClose() {
    _retryTimer?.cancel();
    _homeRetryTimer?.cancel();
    _authStatusWorker?.dispose();
    super.onClose();
  }
}
