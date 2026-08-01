import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show IconData, Icons;
import 'package:get/get.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/utils/app_toast.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/core/utils/null_check_trap.dart';
import 'package:universal_io/io.dart';

class ErrorMapper {
  // Map API errors to user-friendly messages
  static AppException mapApiError(Object error, [StackTrace? stackTrace]) {
    DebugLogger.debug('🗺️ [ERROR_MAPPER] Mapping error: type=${error.runtimeType}');

    // Deep null-check analysis only in debug builds
    if (kDebugMode && error.toString().contains('Null check operator used on a null value')) {
      if (error is String) {
        NullCheckTrap.captureStringOccurrence(error, source: 'ErrorMapper.mapApiError');
      } else if (error is Error || error is Exception) {
        _logNullCheckAnalysis(error, stackTrace);
      }
    }

    // Handle string error messages by wrapping them appropriately
    if (error is String) {
      // Check if it's a specific error pattern
      if (error.contains('Null check operator used on a null value')) {
        if (kDebugMode) {
          NullCheckTrap.captureStringOccurrence(error, source: 'ErrorMapper.mapApiError(String)');
        }
        return NetworkException('something_went_wrong'.tr, details: error);
      }
      // Return as a generic network exception for string errors
      return NetworkException(error, details: error);
    }

    // Map common platform/network exceptions
    if (error is SocketException) {
      return NetworkException(
        'error_no_connection'.tr,
        code: 'CONNECTION_ERROR',
        details: error.message,
      );
    }

    if (error is TimeoutException) {
      return NetworkException('error_timeout'.tr, code: 'TIMEOUT', details: error.message);
    }

    if (error is HttpException) {
      return NetworkException(
        'error_network_generic'.tr,
        code: 'HTTP_EXCEPTION',
        details: error.message,
      );
    }

    // Note: Avoid referencing GetX-internal exception types directly to keep mapping portable.

    if (error is ApiException) {
      return _mapApiException(error);
    }

    // Handle wrapped ApiException (Exception: ApiException: ...)
    if (error is Exception && error.toString().contains('ApiException:')) {
      final errorString = error.toString();
      final match = RegExp(r'ApiException: (.+) \(Status: (\d+)\)').firstMatch(errorString);
      if (match != null) {
        final message = match.group(1)!;
        final statusCode = int.tryParse(match.group(2)!);
        return _mapHttpStatusCode(statusCode, message);
      }
      return NetworkException('something_went_wrong'.tr, details: error.toString());
    }

    if (error is AppException) {
      return error;
    }

    // Generic error
    return NetworkException('something_went_wrong'.tr, details: error.toString());
  }

  // Note: Previously mapped DioException. Since Dio is not used,
  // we rely on platform and GetConnect exceptions above.

  static AppException _mapApiException(ApiException error) {
    if (error.statusCode != null) {
      return _mapHttpStatusCode(error.statusCode, error.response);
    }

    return NetworkException(error.message, details: error.response);
  }

  static AppException _mapHttpStatusCode(int? statusCode, dynamic responseData) {
    switch (statusCode) {
      case 400:
        return ValidationException(
          'error_bad_request'.tr,
          code: 'BAD_REQUEST',
          details: responseData,
          fieldErrors: _extractFieldErrors(responseData),
        );

      case 401:
        return AuthenticationException(
          'session_expired_signin'.tr,
          code: AppException.unauthorizedCode,
          details: responseData,
        );

      case 403:
        return AuthenticationException(
          'error_forbidden'.tr,
          code: 'FORBIDDEN',
          details: responseData,
        );

      case 404:
        return NotFoundException(
          'error_not_found_body'.tr,
          code: 'NOT_FOUND',
          details: responseData,
        );

      case 405:
        return ValidationException(
          'error_method_not_allowed'.tr,
          code: 'METHOD_NOT_ALLOWED',
          details: responseData,
        );

      case 422:
        return ValidationException(
          _extractValidationMessage(responseData) ?? 'error_validation_body'.tr,
          code: 'VALIDATION_ERROR',
          details: responseData,
          fieldErrors: _extractFieldErrors(responseData),
        );

      case 429:
        return NetworkException(
          'too_many_attempts'.tr,
          code: 'RATE_LIMITED',
          details: responseData,
        );

      case 500:
        return ServerException(
          'error_server_500'.tr,
          code: 'SERVER_ERROR',
          statusCode: 500,
          details: responseData,
        );

      case 502:
      case 503:
      case 504:
        return ServerException(
          'error_server_unavailable'.tr,
          code: 'SERVER_UNAVAILABLE',
          statusCode: statusCode,
          details: responseData,
        );

      default:
        return ServerException(
          'error_server_generic'.tr,
          code: 'UNKNOWN_HTTP_ERROR',
          statusCode: statusCode,
          details: responseData,
        );
    }
  }

  static String? _extractValidationMessage(dynamic responseData) {
    if (responseData is String) {
      try {
        responseData = jsonDecode(responseData);
      } catch (_) {
        return null;
      }
    }
    if (responseData is Map) {
      // Try different message fields
      if (responseData['message'] is String) {
        return responseData['message'];
      }
      if (responseData['error'] is String) {
        return responseData['error'];
      }
      if (responseData['detail'] is String) {
        return responseData['detail'];
      }

      // Extract first error from errors object
      if (responseData['errors'] is Map) {
        final errors = responseData['errors'] as Map;
        final firstError = errors.values.first;
        if (firstError is List && firstError.isNotEmpty) {
          return firstError.first.toString();
        }
        if (firstError is String) {
          return firstError;
        }
      }
    }
    return null;
  }

  static Map<String, List<String>>? _extractFieldErrors(dynamic responseData) {
    if (responseData is String) {
      try {
        responseData = jsonDecode(responseData);
      } catch (_) {
        return null;
      }
    }
    if (responseData is Map && responseData['errors'] is Map) {
      final errors = Map<dynamic, dynamic>.from(responseData['errors'] as Map);
      final fieldErrors = <String, List<String>>{};

      errors.forEach((field, error) {
        final fieldName = field.toString();
        if (error is List) {
          fieldErrors[fieldName] = error.map((value) => value.toString()).toList();
        } else if (error is String) {
          fieldErrors[fieldName] = [error];
        }
      });

      return fieldErrors.isNotEmpty ? fieldErrors : null;
    }
    return null;
  }

  // Show user-friendly error messages
  static void showErrorSnackbar(AppException error) {
    String title = 'error'.tr;

    if (error is NetworkException) {
      title = 'connection_error_title'.tr;
    } else if (error is AuthenticationException) {
      title = 'authentication_error'.tr;
    } else if (error is ValidationException) {
      title = 'validation_error'.tr;
    } else if (error is NotFoundException) {
      title = 'not_found'.tr;
    } else if (error is ServerException) {
      title = 'server_error'.tr;
    }

    AppToast.custom(
      title: title,
      message: error.message,
      backgroundColor: Get.theme.colorScheme.error.withValues(alpha: 0.9),
      duration: const Duration(seconds: 4),
    );

    DebugLogger.error('❌ Error shown to user: title=$title, message=${error.message}');
  }

  // Get appropriate retry action text
  static String getRetryActionText(AppException error) {
    if (error is NetworkException) {
      if (error.code == 'CONNECTION_ERROR' || error.code == 'TIMEOUT') {
        return 'check_connection_and_retry'.tr;
      }
    }

    if (error is ServerException) {
      return 'try_again_later'.tr;
    }

    if (error is AuthenticationException) {
      return 'log_in_again'.tr;
    }

    return 'try_again'.tr;
  }

  // Check if error should trigger authentication flow
  static bool shouldTriggerReauth(AppException error) {
    return error is AuthenticationException && error.code == AppException.unauthorizedCode;
  }

  // Check if error is retryable
  static bool isRetryable(AppException error) {
    if (error is NetworkException) {
      return error.code != 'CANCELLED';
    }

    if (error is ServerException) {
      return error.statusCode != null && error.statusCode! >= 500;
    }

    if (error is AuthenticationException) {
      return false; // Auth errors need manual intervention
    }

    if (error is ValidationException) {
      return false; // Validation errors need input changes
    }

    // Unknown typed errors are not retryable by default — avoids amplifying
    // permanent client bugs / unmapped failures.
    return false;
  }

  /// Deep stack analysis for null-check errors (debug only).
  static void _logNullCheckAnalysis(Object error, StackTrace? stackTrace) {
    DebugLogger.error('🚨 NULL CHECK ERROR: ${error.runtimeType}');
    final st = stackTrace ?? StackTrace.current;
    final lines = st.toString().split('\n');
    for (int i = 0; i < lines.length && i < 5; i++) {
      final line = lines[i].trim();
      if (line.contains('.dart')) {
        DebugLogger.error('🚨 [$i] $line');
      }
    }
  }

  // Get Material icon for UI (no emoji — consistent cross-platform rendering)
  static IconData getErrorIcon(AppException error) {
    if (error is NetworkException) {
      return Icons.wifi_off_rounded;
    } else if (error is AuthenticationException) {
      return Icons.lock_outline_rounded;
    } else if (error is ValidationException) {
      return Icons.warning_amber_rounded;
    } else if (error is NotFoundException) {
      return Icons.search_off_rounded;
    } else if (error is ServerException) {
      return Icons.build_circle_outlined;
    }
    return Icons.error_outline_rounded;
  }
}
