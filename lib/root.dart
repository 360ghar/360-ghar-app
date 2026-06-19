// lib/root.dart

import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/data/models/auth_status.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/core/widgets/common/error_states.dart';

class Root extends StatelessWidget {
  const Root({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    return Obx(() {
      final currentStatus = authController.authStatus.value;
      final isAuthResolving = authController.isAuthResolving.value;
      DebugLogger.info('🏠 Root widget rebuilding with authStatus: $currentStatus');

      switch (currentStatus) {
        case AuthStatus.initial:
          // Only show loading during initial auth check
          // AuthNavigationService will handle navigation once state is determined
          DebugLogger.debug('📱 Root: Showing loading state for initial auth check');
          return const Scaffold(body: Center(child: CircularProgressIndicator()));

        case AuthStatus.unauthenticated:
        case AuthStatus.requiresPasswordSetup:
        case AuthStatus.requiresProfileCompletion:
        case AuthStatus.authenticated:
          // AuthNavigationService handles navigation for these states.
          // Show a loading indicator (never a blank SizedBox) so that if
          // AuthNavigationService navigation fails or is delayed, the user
          // still sees actionable feedback instead of a white screen.
          DebugLogger.debug(
            '📱 Root: Auth state resolved to $currentStatus, navigation handled by AuthNavigationService',
          );
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'loading'.tr,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          );

        case AuthStatus.error:
          DebugLogger.debug('📱 Root: Showing error state');
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
