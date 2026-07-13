import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/utils/error_mapper.dart';

class ErrorStates {
  // Generic error widget with retry functionality
  static Widget genericError({
    required dynamic error,
    VoidCallback? onRetry,
    String? customMessage,
    String? customRetryText,
  }) {
    // Derive title, message, and icon safely for both String and AppException
    String title;
    String message;
    IconData icon;

    if (error is AppException) {
      title = _getErrorTitle(error);
      message = error.message;
      icon = ErrorMapper.getErrorIcon(error);
    } else if (error is String) {
      title = 'error'.tr;
      message = error;
      icon = Icons.error_outline_rounded;
    } else {
      title = 'error'.tr;
      message = 'something_went_wrong'.tr;
      icon = Icons.error_outline_rounded;
    }

    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final textTheme = theme.textTheme;
        final onSurface = theme.colorScheme.onSurface;
        final subtle = onSurface.withValues(alpha: 0.7);

        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 56, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  title,
                  style:
                      textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: onSurface,
                      ) ??
                      TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: onSurface),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  customMessage ?? message,
                  style:
                      textTheme.bodyMedium?.copyWith(color: subtle) ??
                      TextStyle(fontSize: 16, color: subtle),
                  textAlign: TextAlign.center,
                ),
                if (onRetry != null &&
                    ((error is AppException && ErrorMapper.isRetryable(error)) ||
                        error is! AppException)) ...[
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: Text(
                      customRetryText ??
                          ((error is AppException)
                              ? ErrorMapper.getRetryActionText(error)
                              : 'retry'.tr),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // Network error specifically
  static Widget networkError({VoidCallback? onRetry, String? customMessage}) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final textTheme = theme.textTheme;
        final onSurface = theme.colorScheme.onSurface;

        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi_off, size: 64, color: AppDesign.placeholderText),
                const SizedBox(height: 16),
                Text(
                  'connection_error_title'.tr,
                  style:
                      textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: onSurface,
                      ) ??
                      TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: onSurface),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  customMessage ?? 'connection_error_message'.tr,
                  style:
                      textTheme.bodyMedium?.copyWith(color: onSurface.withValues(alpha: 0.7)) ??
                      TextStyle(fontSize: 16, color: onSurface.withValues(alpha: 0.7)),
                  textAlign: TextAlign.center,
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: Text('retry'.tr),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // Empty state
  static Widget emptyState({
    required String title,
    required String message,
    IconData? icon,
    String? emoji,
    VoidCallback? onAction,
    String? actionText,
  }) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final textTheme = theme.textTheme;
        final onSurface = theme.colorScheme.onSurface;

        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (emoji != null)
                  Text(
                    emoji,
                    style:
                        textTheme.displayMedium?.copyWith(color: onSurface) ??
                        TextStyle(fontSize: 56, color: onSurface),
                  )
                else if (icon != null)
                  Icon(icon, size: 64, color: AppDesign.placeholderText)
                else
                  Icon(Icons.inbox_outlined, size: 64, color: AppDesign.placeholderText),
                const SizedBox(height: 16),
                Text(
                  title,
                  style:
                      textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: onSurface,
                      ) ??
                      TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: onSurface),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style:
                      textTheme.bodyMedium?.copyWith(color: onSurface.withValues(alpha: 0.7)) ??
                      TextStyle(fontSize: 16, color: onSurface.withValues(alpha: 0.7)),
                  textAlign: TextAlign.center,
                ),
                if (onAction != null && actionText != null) ...[
                  const SizedBox(height: 24),
                  ElevatedButton(onPressed: onAction, child: Text(actionText)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // Search empty state
  static Widget searchEmpty({
    required String searchQuery,
    VoidCallback? onClearSearch,
    VoidCallback? onTryDifferentSearch,
  }) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final textTheme = theme.textTheme;
        final onSurface = theme.colorScheme.onSurface;

        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.search_off, size: 64, color: AppDesign.placeholderText),
                const SizedBox(height: 16),
                Text(
                  'no_results_found'.tr,
                  style:
                      textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: onSurface,
                      ) ??
                      TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: onSurface),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'no_results_message'.trParams({'query': searchQuery}),
                  style:
                      textTheme.bodyMedium?.copyWith(color: onSurface.withValues(alpha: 0.7)) ??
                      TextStyle(fontSize: 16, color: onSurface.withValues(alpha: 0.7)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onClearSearch != null) ...[
                      ElevatedButton(onPressed: onClearSearch, child: Text('clear_search'.tr)),
                      const SizedBox(width: 12),
                    ],
                    if (onTryDifferentSearch != null)
                      OutlinedButton(
                        onPressed: onTryDifferentSearch,
                        child: Text('try_different_search'.tr),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // No location permission state
  static Widget locationPermissionDenied({
    VoidCallback? onRequestPermission,
    VoidCallback? onOpenSettings,
  }) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final textTheme = theme.textTheme;
        final onSurface = theme.colorScheme.onSurface;

        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_off, size: 64, color: AppDesign.placeholderText),
                const SizedBox(height: 16),
                Text(
                  'location_access_needed'.tr,
                  style:
                      textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: onSurface,
                      ) ??
                      TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: onSurface),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'location_access_needed_message'.tr,
                  style:
                      textTheme.bodyMedium?.copyWith(color: onSurface.withValues(alpha: 0.7)) ??
                      TextStyle(fontSize: 16, color: onSurface.withValues(alpha: 0.7)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Column(
                  children: [
                    if (onRequestPermission != null) ...[
                      ElevatedButton.icon(
                        onPressed: onRequestPermission,
                        icon: const Icon(Icons.location_on),
                        label: Text('grant_permission'.tr),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (onOpenSettings != null)
                      TextButton(onPressed: onOpenSettings, child: Text('open_settings'.tr)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Swipe deck empty state
  static Widget swipeDeckEmpty({VoidCallback? onRefresh, VoidCallback? onChangeFilters}) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final textTheme = theme.textTheme;
        final onSurface = theme.colorScheme.onSurface;
        final primary = theme.colorScheme.primary;

        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.9, end: 1.0),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutBack,
                  builder: (context, value, child) {
                    return Transform.scale(scale: value, child: child);
                  },
                  child: Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [primary.withValues(alpha: 0.18), primary.withValues(alpha: 0.06)],
                      ),
                      border: Border.all(color: primary.withValues(alpha: 0.18)),
                    ),
                    child: Icon(Icons.home_outlined, size: 44, color: primary),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'no_more_properties'.tr,
                  style:
                      textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: onSurface,
                      ) ??
                      TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: onSurface),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'no_more_properties_message'.tr,
                  style:
                      textTheme.bodyMedium?.copyWith(color: onSurface.withValues(alpha: 0.7)) ??
                      TextStyle(fontSize: 16, color: onSurface.withValues(alpha: 0.7)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onChangeFilters != null) ...[
                      ElevatedButton.icon(
                        onPressed: onChangeFilters,
                        icon: const Icon(Icons.tune),
                        label: Text('change_filters'.tr),
                      ),
                      const SizedBox(width: 16),
                    ],
                    if (onRefresh != null)
                      OutlinedButton.icon(
                        onPressed: onRefresh,
                        icon: const Icon(Icons.refresh),
                        label: Text('refresh'.tr),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Inline error for smaller spaces
  static Widget inlineError({
    required String message,
    VoidCallback? onRetry,
    bool showIcon = true,
  }) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              if (showIcon) ...[
                Icon(Icons.error_outline, color: theme.colorScheme.error, size: 20),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  message,
                  style:
                      theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ) ??
                      TextStyle(fontSize: 14, color: theme.colorScheme.onErrorContainer),
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(width: 8),
                TextButton(onPressed: onRetry, child: Text('retry'.tr)),
              ],
            ],
          ),
        );
      },
    );
  }

  // Error banner (can be dismissed)
  static Widget errorBanner({
    required String message,
    VoidCallback? onDismiss,
    VoidCallback? onRetry,
  }) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: theme.colorScheme.error, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style:
                      theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ) ??
                      TextStyle(fontSize: 14, color: theme.colorScheme.onErrorContainer),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onRetry != null) ...[
                    TextButton(onPressed: onRetry, child: Text('retry'.tr)),
                    const SizedBox(width: 4),
                  ],
                  if (onDismiss != null)
                    IconButton(
                      onPressed: onDismiss,
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: 'dismiss'.tr,
                      color: theme.colorScheme.onErrorContainer,
                      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Profile loading error with retry and sign out options
  static Widget profileLoadError({
    VoidCallback? onRetry,
    VoidCallback? onSignOut,
    String? customMessage,
    bool isRetrying = false,
  }) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final textTheme = theme.textTheme;
        final onSurface = theme.colorScheme.onSurface;

        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.account_circle_outlined, size: 64, color: AppDesign.placeholderText),
                const SizedBox(height: 16),
                Text(
                  'profile_load_error'.tr,
                  style:
                      textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: onSurface,
                      ) ??
                      TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: onSurface),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  customMessage ?? 'profile_load_error_message'.tr,
                  style:
                      textTheme.bodyMedium?.copyWith(color: onSurface.withValues(alpha: 0.7)) ??
                      TextStyle(fontSize: 16, color: onSurface.withValues(alpha: 0.7)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Column(
                  children: [
                    if (isRetrying) ...[
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'retrying'.tr,
                        style:
                            textTheme.bodySmall?.copyWith(
                              color: onSurface.withValues(alpha: 0.7),
                            ) ??
                            TextStyle(fontSize: 12, color: onSurface.withValues(alpha: 0.7)),
                      ),
                      const SizedBox(height: 12),
                    ] else if (onRetry != null) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: onRetry,
                          icon: const Icon(Icons.refresh),
                          label: Text('retry'.tr),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (onSignOut != null)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: onSignOut,
                          icon: const Icon(Icons.logout),
                          label: Text('sign_out'.tr),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _getErrorTitle(AppException error) {
    if (error is NetworkException) {
      return 'connection_problem'.tr;
    } else if (error is AuthenticationException) {
      return 'authentication_required'.tr;
    } else if (error is ValidationException) {
      return 'invalid_input'.tr;
    } else if (error is NotFoundException) {
      return 'not_found'.tr;
    } else if (error is ServerException) {
      return 'server_error'.tr;
    }
    return 'something_went_wrong'.tr;
  }
}
