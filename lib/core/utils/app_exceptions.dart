// Custom exception classes for better error handling
abstract class AppException implements Exception {
  /// Fallback code of a 401 that carries no backend code.
  static const String unauthorizedCode = 'UNAUTHORIZED';

  /// Backend code of a 403 for a deactivated account. It ends the session like a 401.
  static const String userInactiveCode = 'USER_INACTIVE';

  /// Authentication code meaning the SDK could not mint a token at all (dead refresh token, or
  /// an expired token while offline). It carries no status, so it does not end the session
  /// ([AuthenticationException.endsSession]); repositories that persist actions locally treat it
  /// as offline-retryable. A dead session is ended by the 401 the server returns.
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
      (this is NetworkException && code != 'CANCELLED') ||
      (this is AuthenticationException && code == missingAuthHeaderCode);

  @override
  String toString() => 'AppException: $message';
}

class NetworkException extends AppException {
  NetworkException(super.message, {super.code, super.details});
}

/// 401 and 403. [code] is the backend code (`TOKEN_INVALID`, `USER_INACTIVE`,
/// `USER_ACCESS_DENIED`, ...); a failure raised on the device (no token yet) has no [statusCode].
class AuthenticationException extends AppException {
  final int? statusCode;

  AuthenticationException(super.message, {super.code, super.details, this.statusCode});

  /// The session cannot continue: a 401 that survived the token refresh, or a deactivated
  /// account. A failure raised on the device never ends it, because a refresh that could not
  /// reach the auth server proves nothing about the session.
  bool get endsSession => statusCode == 401 || code == AppException.userInactiveCode;

  /// A 403 for any reason except a deactivated account: a plain permission refusal.
  bool get isPermissionDenied => statusCode == 403 && code != AppException.userInactiveCode;
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

  /// How long the server asked clients to wait (`Retry-After`), if it said.
  final Duration? retryAfter;

  ServerException(super.message, {super.code, super.details, this.statusCode, this.retryAfter});
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

/// HTTP 429. The UI waits [retryAfter] before it offers another attempt.
class RateLimitException extends ApiException {
  /// The wait from `Retry-After`, or [defaultWait] when the header is missing.
  final Duration retryAfter;

  static const defaultWait = Duration(seconds: 30);

  RateLimitException(super.message, {String? code, super.details, this.retryAfter = defaultWait})
    : super(code: code ?? 'RATE_LIMITED', statusCode: 429);
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
