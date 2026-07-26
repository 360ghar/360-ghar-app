import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/utils/app_toast.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/core/utils/error_mapper.dart';
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
      } else if (code == 'otp_disabled') {
        message = 'invalid_otp'.tr;
      } else if (code == 'over_request_rate_limit' ||
          code == 'over_email_send_rate_limit' ||
          code == 'over_sms_send_rate_limit' ||
          containsAny(['rate limit exceeded', 'too many requests'])) {
        message = 'too_many_attempts'.tr;
        backgroundColor = AppDesign.warningAmber;
      } else if (code == 'sms_send_failed') {
        message = 'failed_to_send_otp'.tr;
      } else if (code == 'bad_jwt') {
        message = 'session_expired_signin'.tr;
      } else if (code == 'email_address_not_authorized') {
        message = 'registration_disabled'.tr;
      } else if (containsAny([
        'invalid login credentials',
        'wrong password',
        'incorrect password',
      ])) {
        message = 'invalid_phone_password'.tr;
      } else if (code == 'email_not_confirmed' ||
          code == 'phone_not_confirmed' ||
          containsAny(['email not confirmed', 'phone not confirmed', 'user not confirmed'])) {
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

    // Single mapping path — never classify HTTP codes via error.toString().
    final mapped = error is AppException
        ? error
        : ErrorMapper.mapApiError(error, stackTrace ?? StackTrace.current);

    String title = 'network_error'.tr;
    Color backgroundColor = AppDesign.warningAmber;
    if (mapped is AuthenticationException) {
      title = 'authentication_error'.tr;
      backgroundColor = AppDesign.errorRed;
    } else if (mapped is ServerException) {
      title = 'server_error'.tr;
    } else if (mapped is ValidationException) {
      title = 'validation_error'.tr;
    } else if (mapped is NotFoundException) {
      title = 'not_found'.tr;
    }

    AppToast.custom(
      title: title,
      message: mapped.message,
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

  static void showInfo(String message) {
    AppToast.info('info'.tr, message);
  }
}
