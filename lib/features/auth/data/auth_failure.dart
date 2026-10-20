import 'dart:async';

import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Typed errors cross the application boundary; views choose localized text.
AppException authFailure(Object error) {
  if (error is AppException) return error;
  if (error is TimeoutException) {
    return NetworkException('The authentication request timed out.', code: 'TIMEOUT');
  }
  if (error is AuthRetryableFetchException) {
    return NetworkException('The authentication service is unavailable.', code: 'AUTH_NETWORK');
  }
  if (error is AuthException) {
    return AuthenticationException(
      'Authentication could not be completed.',
      code:
          error.code ??
          (error.message.toLowerCase().contains('invalid login credentials')
              ? 'invalid_credentials'
              : error.message.toLowerCase().contains('already registered')
              ? 'user_already_exists'
              : 'AUTH_FAILED'),
    );
  }
  if (error is FormatException) {
    return ServerException('The authentication response was invalid.', code: 'MALFORMED_RESPONSE');
  }
  return ServerException('Authentication could not be completed.', code: 'AUTH_FAILED');
}

String authFailureMessageKey(AppException? error, {String fallback = 'login_error'}) {
  if (error is NetworkException) return error.code == 'TIMEOUT' ? 'error_timeout' : 'network_error';
  return switch (error?.code) {
    'invalid_credentials' => 'invalid_credentials',
    'otp_expired' => 'otp_verification_error',
    'over_request_rate_limit' ||
    'over_email_send_rate_limit' ||
    'over_sms_send_rate_limit' => 'retry_cooldown_message',
    'LOCAL_STORAGE_FAILED' => 'preferences_save_error',
    'user_already_exists' || 'email_exists' || 'phone_exists' => 'already_have_account',
    _ => fallback,
  };
}
