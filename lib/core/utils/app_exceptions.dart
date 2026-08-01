// Custom exception classes for better error handling
abstract class AppException implements Exception {
  /// Authentication code meaning the session is no longer valid (server 401).
  static const String unauthorizedCode = 'UNAUTHORIZED';

  /// Authentication code meaning the SDK could not mint a token at all
  /// (dead refresh token). Treated as session-fatal in [AuthController], and
  /// as offline-retryable in repositories that persist actions locally.
  static const String missingAuthHeaderCode = 'MISSING_AUTH_HEADER';

  final String message;
  final String? code;
  final dynamic details;

  AppException(this.message, {this.code, this.details});

  /// True when a later retry could plausibly recover from this failure, i.e.
  /// the device is offline. Being offline with an expired cached token
  /// surfaces as [missingAuthHeaderCode] (ApiClient throws before opening a
  /// socket), so it must queue too, or the action is lost.
  bool get isRetryableOffline =>
      this is NetworkException ||
      (this is AuthenticationException && code == missingAuthHeaderCode);

  @override
  String toString() => 'AppException: $message';
}

class NetworkException extends AppException {
  NetworkException(super.message, {super.code, super.details});
}

class AuthenticationException extends AppException {
  AuthenticationException(super.message, {super.code, super.details});
}

class ValidationException extends AppException {
  final Map<String, List<String>>? fieldErrors;

  ValidationException(super.message, {super.code, super.details, this.fieldErrors});
}

class NotFoundException extends AppException {
  NotFoundException(super.message, {super.code, super.details});
}

class ServerException extends AppException {
  final int? statusCode;

  ServerException(super.message, {super.code, super.details, this.statusCode});
}

class LocationException extends AppException {
  LocationException(super.message, {super.code, super.details});
}

class CacheException extends AppException {
  CacheException(super.message, {super.code, super.details});
}

class ApiException extends AppException {
  final int? statusCode;
  final String? response;

  ApiException(super.message, {super.code, super.details, this.statusCode, this.response});

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}

// HTTP caching: 304 Not Modified signal
class NotModifiedException extends AppException {
  NotModifiedException(super.message, {super.code, super.details});
}

/// A wrapper class to hold an error and its associated stack trace.
class AppError {
  final Object error;
  final StackTrace stackTrace;

  AppError({required this.error, required this.stackTrace});

  @override
  String toString() {
    return 'AppError: ${error.toString()}';
  }
}
