import 'package:flutter/widgets.dart';

import 'package:ghar360/core/storage/storage_failure.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';

/// Display only known localized messages. Backend diagnostics and response
/// bodies belong in diagnostics, never in a user's error surface.
String errorMessage(BuildContext context, Object? error) =>
    context.l10n.text(errorMessageKey(error));

String errorMessageKey(Object? error) {
  if (error is StorageFailure || error is CacheException) return 'local_save_failed';
  if (error is RateLimitException) return 'rate_limited_message';
  if (error is! AppException) return 'something_went_wrong';
  switch (error.code) {
    case 'TIMEOUT':
    case 'CONNECTION_TIMEOUT':
      return 'error_timeout';
    case 'FORBIDDEN':
    case 'PERMISSION_DENIED':
      return 'error_forbidden';
    case 'RATE_LIMITED':
    case 'TOO_MANY_REQUESTS':
      return 'too_many_attempts';
    case 'CONFLICT':
      return 'request_conflict';
    case 'LOCATION_DISABLED':
      return 'location_services_disabled';
    case 'LOCATION_DENIED_FOREVER':
      return 'location_permission_permanently_denied';
    case 'LOCATION_DENIED':
      return 'location_permission_denied';
  }
  return switch (error) {
    AuthenticationException() => 'session_expired_signin',
    NetworkException() => 'error_no_connection',
    ValidationException() => 'error_validation_body',
    NotFoundException() => 'error_not_found_body',
    LocationException() => 'failed_to_get_location_message',
    ServerException() => 'error_server_generic',
    _ => 'something_went_wrong',
  };
}

/// Whether a later attempt can succeed without the user changing anything.
/// A rate limit is retryable once its wait has passed.
bool isRetryableFailure(Object? error) => switch (error) {
  NetworkException(code: 'CANCELLED') => false,
  NetworkException() || ServerException() || RateLimitException() => true,
  StorageFailure() || CacheException() => true,
  AuthenticationException(code: AppException.missingAuthHeaderCode) => true,
  AppException() => false,
  _ => true,
};

/// The wait a failure asks for before the next attempt, if any.
Duration? retryWaitOf(Object? error) => switch (error) {
  RateLimitException(:final retryAfter) => retryAfter,
  ServerException(:final retryAfter?) when retryAfter > const Duration(seconds: 1) => retryAfter,
  _ => null,
};
