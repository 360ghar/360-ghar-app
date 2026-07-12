// lib/root.dart

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/data/models/auth_status.dart';
import 'package:ghar360/core/services/auth_navigation_service.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/core/widgets/common/app_boot_loader.dart';
import 'package:ghar360/core/widgets/common/error_states.dart';

class Root extends StatefulWidget {
  const Root({super.key});

  @override
  State<Root> createState() => _RootState();
}

class _RootState extends State<Root> {
  Timer? _stuckLoaderTimer;
  AuthStatus? _watchedStatus;

  @override
  void dispose() {
    _stuckLoaderTimer?.cancel();
    super.dispose();
  }

  void _ensureNavigationSafetyNet(AuthStatus status) {
    // Only arm the safety net for statuses that should leave Root immediately.
    final needsNav =
        status == AuthStatus.unauthenticated ||
        status == AuthStatus.authenticated ||
        status == AuthStatus.requiresPasswordSetup ||
        status == AuthStatus.requiresProfileCompletion;

    if (!needsNav) {
      _stuckLoaderTimer?.cancel();
      _stuckLoaderTimer = null;
      _watchedStatus = null;
      return;
    }

    if (_watchedStatus == status && _stuckLoaderTimer != null) {
      return;
    }

    _watchedStatus = status;
    _stuckLoaderTimer?.cancel();
    _stuckLoaderTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      final auth = Get.find<AuthController>();
      if (auth.authStatus.value != status) return;

      final route = Get.currentRoute;
      final stillOnHome = route.isEmpty || route == '/' || route == '/Root';
      if (!stillOnHome) return;

      DebugLogger.warning(
        '🏠 Root safety net: still on home after $status (route=$route) — reapplying navigation',
      );
      if (Get.isRegistered<AuthNavigationService>()) {
        Get.find<AuthNavigationService>().reapply();
      } else {
        auth.authStatus.refresh();
      }
    });
  }

  void _onBootRetry(AuthController auth) {
    DebugLogger.info('🏠 Root boot retry tapped (status=${auth.authStatus.value})');
    if (auth.authStatus.value == AuthStatus.error) {
      unawaited(auth.retryProfileLoad());
      return;
    }
    // Session still resolving or navigation stalled — force a full recheck.
    unawaited(auth.recheckAuthBootstrap());
    if (Get.isRegistered<AuthNavigationService>()) {
      Get.find<AuthNavigationService>().reapply();
    }
  }

  Widget _bootLoader(AuthController auth, {required String message}) {
    return AppBootLoader(message: message, onRetry: () => _onBootRetry(auth));
  }

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    return Obx(() {
      final currentStatus = authController.authStatus.value;
      final isAuthResolving = authController.isAuthResolving.value;
      // Debug-only: avoid INFO spam on every Obx rebuild in production.
      DebugLogger.debug('🏠 Root rebuild authStatus=$currentStatus resolving=$isAuthResolving');

      // Schedule outside the build paint path.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ensureNavigationSafetyNet(currentStatus);
      });

      switch (currentStatus) {
        case AuthStatus.initial:
          // Match native splash branding while the first auth check runs.
          return _bootLoader(
            authController,
            message: isAuthResolving ? 'checking_session'.tr : 'starting_app'.tr,
          );

        case AuthStatus.unauthenticated:
        case AuthStatus.requiresPasswordSetup:
        case AuthStatus.requiresProfileCompletion:
        case AuthStatus.authenticated:
          // AuthNavigationService handles navigation for these states.
          // Show branded loading (never a blank SizedBox) so delayed navigation
          // still feels intentional.
          return _bootLoader(authController, message: 'loading'.tr);

        case AuthStatus.error:
          // User authentication error - show retry/logout options
          return ErrorStates.profileLoadError(
            customMessage: authController.authErrorMessage.value,
            onRetry: isAuthResolving ? null : () => authController.retryProfileLoad(),
            onSignOut: () => authController.signOut(),
            isRetrying: isAuthResolving,
          );
      }
    });
  }
}
