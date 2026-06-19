import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/utils/app_toast.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ErrorHandler {
  static void handleAuthError(dynamic error, {VoidCallback? onRetry, StackTrace? stackTrace}) {
    DebugLogger.logDetailedError(
      operation: 'handleAuthError',
      error: error,
      stackTrace: stackTrace ?? StackTrace.current,
      additionalData: {'hasRetryCallback': onRetry != null},
    );

    String message;
    String title = 'error'.tr;
    Color backgroundColor = AppDesign.errorRed;

    if (error is AuthException) {
      title = 'auth_error_title'.tr;
      final msg = error.message;
      String code = '';
      try {
        // ignore: invalid_use_of_visible_for_testing_member
        code = (error as dynamic).code ?? '';
      } catch (_) {}
      // Use normalized (lowercased) contains-matching so minor wording tweaks
      // by Supabase don't silently break classification. Exact-string switch
      // was previously brittle.
      final m = msg.toLowerCase();
      bool containsAny(List<String> phrases) => phrases.any(m.contains);

      if (code == 'otp_expired' || containsAny(['token has expired', 'token is invalid'])) {
        message = 'otp_expired_request_new'.tr;
        backgroundColor = AppDesign.warningAmber;
      } else if (containsAny([
        'invalid login credentials',
        'wrong password',
        'incorrect password',
      ])) {
        message = 'invalid_phone_password'.tr;
      } else if (containsAny([
        'email not confirmed',
        'phone not confirmed',
        'user not confirmed',
      ])) {
        message = 'verify_phone_first'.tr;
        backgroundColor = AppDesign.warningAmber;
      } else if (containsAny(['already registered', 'user already registered'])) {
        message = 'account_exists_signin'.tr;
      } else if (containsAny(['password should be at least', 'password must be at least'])) {
        message = 'password_min_chars'.tr;
      } else if (containsAny(['invalid email'])) {
        message = 'enter_valid_email_error'.tr;
      } else if (containsAny(['invalid phone', 'invalid phone number'])) {
        message = 'enter_valid_phone_error'.tr;
      } else if (containsAny(['signup disabled'])) {
        message = 'registration_disabled'.tr;
      } else if (containsAny(['user not found'])) {
        message = 'no_account_found_error'.tr;
      } else if (containsAny(['rate limit exceeded'])) {
        message = 'too_many_attempts'.tr;
        backgroundColor = AppDesign.warningAmber;
      } else if (containsAny(['session not found'])) {
        message = 'session_expired_signin'.tr;
      } else {
        // Unknown auth error: surface the raw message but log to Crashlytics
        // so backend/auth changes are observable rather than silently broken.
        try {
          FirebaseCrashlytics.instance.recordError(
            error,
            stackTrace ?? StackTrace.current,
            reason: 'Unrecognized AuthException message',
            fatal: false,
          );
        } catch (_) {}
        message = msg;
      }
    } else if (error is Exception) {
      message = error.toString().replaceAll('Exception: ', '');
    } else {
      message = 'something_went_wrong'.tr;
    }

    AppToast.custom(
      title: title,
      message: message,
      backgroundColor: backgroundColor,
      duration: const Duration(seconds: 4),
      mainButton: onRetry != null
          ? TextButton(
              onPressed: onRetry,
              child: Text('retry'.tr, style: const TextStyle(color: AppDesign.darkTextPrimary)),
            )
          : null,
    );
  }

  static void handleNetworkError(dynamic error, {VoidCallback? onRetry, StackTrace? stackTrace}) {
    DebugLogger.logDetailedError(
      operation: 'handleNetworkError',
      error: error,
      stackTrace: stackTrace ?? StackTrace.current,
      additionalData: {'hasRetryCallback': onRetry != null, 'errorString': error.toString()},
    );

    String message;

    if (error.toString().contains('SocketException') ||
        error.toString().contains('TimeoutException')) {
      message = 'no_internet_connection'.tr;
    } else if (error.toString().contains('Connection refused')) {
      message = 'server_unavailable'.tr;
    } else if (error.toString().contains('401')) {
      message = 'auth_failed_signin'.tr;
    } else if (error.toString().contains('403')) {
      message = 'access_denied'.tr;
    } else if (error.toString().contains('404')) {
      message = 'resource_not_found'.tr;
    } else if (error.toString().contains('500')) {
      message = 'server_error_generic'.tr;
    } else {
      message = 'network_error_generic'.tr;
    }

    AppToast.custom(
      title: 'network_error'.tr,
      message: message,
      backgroundColor: AppDesign.warningAmber,
      duration: const Duration(seconds: 4),
      mainButton: onRetry != null
          ? TextButton(
              onPressed: onRetry,
              child: Text('retry'.tr, style: const TextStyle(color: AppDesign.darkTextPrimary)),
            )
          : null,
    );
  }

  static void handleValidationError(String field, String message) {
    AppToast.warning(field, message);
  }

  static void showSuccess(String message) {
    AppToast.success('success'.tr, message);
  }

  static void showInfo(String message) {
    AppToast.info('info'.tr, message);
  }

  static Widget buildErrorWidget(String error, {VoidCallback? onRetry}) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: colorScheme.error),
                const SizedBox(height: 16),
                Text(
                  'something_went_wrong'.tr,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  error,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
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

  static Widget buildLoadingWidget({String? message}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message, style: const TextStyle(fontSize: 16), textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }

  static Widget buildEmptyWidget({
    required String title,
    required String message,
    IconData? icon,
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon ?? Icons.inbox_outlined,
                  size: 64,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                if (onAction != null && actionLabel != null) ...[
                  const SizedBox(height: 24),
                  ElevatedButton(onPressed: onAction, child: Text(actionLabel)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class ApiErrorHandler {
  /// Handles API errors and provides user-friendly messages and debugging info
  static String handleError(dynamic error, {String? context, StackTrace? stackTrace}) {
    final errorMessage = error.toString();

    DebugLogger.error(
      'API Error in ${context ?? 'unknown context'}: $errorMessage',
      error,
      stackTrace,
    );

    // Type casting errors
    if (errorMessage.contains('is not a subtype of type')) {
      return _handleTypeCastingError(errorMessage, context);
    }

    // Network errors
    if (errorMessage.contains('Connection refused') ||
        errorMessage.contains('Failed host lookup') ||
        errorMessage.contains('SocketException') ||
        errorMessage.contains('NetworkException')) {
      return _handleNetworkError(errorMessage, context);
    }

    // HTTP errors
    if (errorMessage.contains('404')) {
      return _handleHttpError(404, context);
    } else if (errorMessage.contains('401')) {
      return _handleHttpError(401, context);
    } else if (errorMessage.contains('403')) {
      return _handleHttpError(403, context);
    } else if (errorMessage.contains('500')) {
      return _handleHttpError(500, context);
    }

    // JSON parsing errors
    if (errorMessage.contains('FormatException') ||
        errorMessage.contains('Unexpected character') ||
        errorMessage.contains('Invalid JSON')) {
      return _handleJsonError(errorMessage, context);
    }

    // Authentication errors
    if (errorMessage.contains('Invalid email or password') ||
        errorMessage.contains('User not found') ||
        errorMessage.contains('Invalid credentials')) {
      return _handleAuthError(errorMessage, context);
    }

    // Generic error
    return _handleGenericError(errorMessage, context);
  }

  static String _handleTypeCastingError(String error, String? context) {
    DebugLogger.warning(
      'Type casting error detected: backend data types don\'t match frontend expectations',
    );

    if (error.contains("'int' is not a subtype of type 'String'")) {
      DebugLogger.info('Solution: Backend is returning integer where string is expected');
      return 'data_format_mismatch'.tr;
    } else if (error.contains("'List<dynamic>' is not a subtype of type 'Map<String, dynamic>'")) {
      DebugLogger.info('Solution: Backend is returning array where object is expected');
      return 'data_structure_mismatch'.tr;
    } else if (error.contains("'String' is not a subtype of type 'int'")) {
      DebugLogger.info('Solution: Backend is returning string where number is expected');
      return 'numeric_format_issue'.tr;
    }

    return 'data_format_error'.tr;
  }

  static String _handleNetworkError(String error, String? context) {
    DebugLogger.warning('Network connectivity issue detected');
    DebugLogger.debug(
      'Solutions: 1. Check backend server 2. Verify connectivity 3. Check firewall',
    );

    return 'unable_connect_server'.tr;
  }

  static String _handleHttpError(int statusCode, String? context) {
    switch (statusCode) {
      case 401:
        DebugLogger.warning('Authentication error: invalid or expired token');
        return 'please_login_again'.tr;

      case 403:
        DebugLogger.warning('Authorization error: insufficient permissions');
        return 'insufficient_permissions'.tr;

      case 404:
        DebugLogger.warning('Resource not found');
        return 'requested_data_not_found'.tr;

      case 500:
        DebugLogger.error('Server error: backend is experiencing issues');
        return 'server_error_later'.tr;

      default:
        DebugLogger.error('HTTP Error $statusCode');
        return 'server_responded_error'.trParams({'statusCode': statusCode.toString()});
    }
  }

  static String _handleJsonError(String error, String? context) {
    DebugLogger.warning('JSON parsing error: invalid response format');
    DebugLogger.debug('Check backend response format and verify valid JSON');

    return 'invalid_data_format'.tr;
  }

  static String _handleAuthError(String error, String? context) {
    DebugLogger.warning('Authentication failed');
    DebugLogger.debug('Verify credentials and account status');

    return 'auth_failed_credentials'.tr;
  }

  static String _handleGenericError(String error, String? context) {
    DebugLogger.error('Unhandled error type: $error');
    DebugLogger.debug('Request failed - please retry');

    return 'unexpected_error_later'.tr;
  }

  /// Logs detailed error information for debugging
  static void logDetailedError({
    required String operation,
    required dynamic error,
    required StackTrace stackTrace,
    Map<String, dynamic>? additionalData,
  }) {
    // Use the enhanced logger's built-in detailed error method
    DebugLogger.logDetailedError(
      operation: operation,
      error: error,
      stackTrace: stackTrace,
      additionalData: additionalData,
    );
  }
}
