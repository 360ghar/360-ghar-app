import 'package:flutter/foundation.dart';

import 'package:ghar360/core/config/app_config.dart';
import 'package:logger/logger.dart';

class DebugLogger {
  static late final Logger _logger;
  static bool _initialized = false;

  static bool get isDebugMode {
    try {
      if (AppConfig.isInitialized) return AppConfig.instance.debugMode;
    } catch (_) {}
    return kDebugMode;
  }

  static bool get shouldLogAPICalls {
    try {
      if (AppConfig.isInitialized) return AppConfig.instance.logApiCalls;
    } catch (_) {}
    return false;
  }

  /// Initialize the logger with appropriate configuration
  static void initialize() {
    if (_initialized) return;

    _logger = Logger(
      filter: _LoggerFilter(),
      // Use a clean printer to avoid boxes and divider lines
      printer: SimplePrinter(),
      output: ConsoleOutput(),
    );
    _initialized = true;
  }

  /// Verbose level - Most detailed logs (only in verbose debug mode)
  static void verbose(String message, [dynamic error, StackTrace? stackTrace]) {
    _ensureInitialized();
    _logger.t(message, error: error, stackTrace: stackTrace);
  }

  /// Debug level - Development debugging info (removed in production)
  static void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    _ensureInitialized();
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  /// Info level - General information about app state
  static void info(String message, [dynamic error, StackTrace? stackTrace]) {
    _ensureInitialized();
    _logger.i('ℹ️ $message', error: error, stackTrace: stackTrace);
  }

  /// Success level - Successful operations
  static void success(String message, [dynamic error, StackTrace? stackTrace]) {
    _ensureInitialized();
    _logger.i('✅ $message', error: error, stackTrace: stackTrace);
  }

  /// Warning level - Important issues that don't stop execution
  static void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    _ensureInitialized();
    _logger.w('⚠️ $message', error: error, stackTrace: stackTrace);
  }

  /// Error level - Errors and exceptions
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _ensureInitialized();
    // Always capture stack trace if not provided for errors
    final effectiveStackTrace = stackTrace ?? (error != null ? StackTrace.current : null);
    _logger.e('❌ $message', error: error, stackTrace: effectiveStackTrace);
  }

  /// WTF level - What a Terrible Failure - Should never happen
  static void wtf(String message, [dynamic error, StackTrace? stackTrace]) {
    _ensureInitialized();
    _logger.f('💥 $message', error: error, stackTrace: stackTrace);
  }

  // Categorized logging methods

  /// API related logs
  static void api(String message, [dynamic error, StackTrace? stackTrace]) {
    if (shouldLogAPICalls) {
      _ensureInitialized();
      _logger.d('🌐 $message', error: error, stackTrace: stackTrace);
    }
  }

  /// Authentication related logs
  static void auth(String message, [dynamic error, StackTrace? stackTrace]) {
    _ensureInitialized();
    _logger.i('🔐 $message', error: error, stackTrace: stackTrace);
  }

  /// JWT token related logs
  static void jwt(String message, [dynamic error, StackTrace? stackTrace]) {
    _ensureInitialized();
    _logger.i('🔑 $message', error: error, stackTrace: stackTrace);
  }

  /// User related logs
  static void user(String message, [dynamic error, StackTrace? stackTrace]) {
    _ensureInitialized();
    _logger.i('👤 $message', error: error, stackTrace: stackTrace);
  }

  /// Property related logs
  static void property(String message, [dynamic error, StackTrace? stackTrace]) {
    _ensureInitialized();
    _logger.i('🏠 $message', error: error, stackTrace: stackTrace);
  }

  /// Network related logs
  static void network(String message, [dynamic error, StackTrace? stackTrace]) {
    if (shouldLogAPICalls) {
      _ensureInitialized();
      _logger.d('📡 $message', error: error, stackTrace: stackTrace);
    }
  }

  /// Connection related logs
  static void connection(String message, [dynamic error, StackTrace? stackTrace]) {
    _ensureInitialized();
    _logger.i('🔌 $message', error: error, stackTrace: stackTrace);
  }

  /// Initialization related logs
  static void startup(String message, [dynamic error, StackTrace? stackTrace]) {
    _ensureInitialized();
    _logger.i('🔧 $message', error: error, stackTrace: stackTrace);
  }

  /// Log JWT token details securely (only in debug mode)
  static void logJWTToken(String token, {DateTime? expiresAt, String? userId, String? userEmail}) {
    if (!isDebugMode) return;

    _ensureInitialized();

    // Never log token material - just confirm token presence and metadata
    String message = '🔑 JWT Token received (length: ${token.length})';
    if (expiresAt != null) message += '\n   Expires: $expiresAt';
    if (userId != null) message += '\n   User ID: ${_truncateId(userId)}';
    // Never log email - PII concern

    _logger.d(message);
  }

  /// Truncate IDs to first 8 chars for logging (avoid full exposure)
  static String _truncateId(String id) {
    if (id.length <= 8) return id;
    return '${id.substring(0, 8)}...';
  }

  /// Log API request details
  static void logAPIRequest({
    required String method,
    required String endpoint,
    Map<String, String>? headers,
    dynamic body,
  }) {
    if (!shouldLogAPICalls) return;

    _ensureInitialized();

    StringBuffer message = StringBuffer('🌐 API REQUEST\n');
    message.write('   $method $endpoint\n');
    if (headers != null && headers.isNotEmpty) {
      message.write('   Headers: $headers\n');
    }
    if (body != null) {
      message.write('   Body: ${_sanitizeBody(body)}');
    }

    _logger.d(message.toString().trim());
  }

  /// Log API response details
  static void logAPIResponse({
    required int statusCode,
    required String endpoint,
    dynamic body,
    int? responseTime,
  }) {
    if (!shouldLogAPICalls) return;

    _ensureInitialized();

    StringBuffer message = StringBuffer('📨 API RESPONSE\n');
    message.write('   Status: $statusCode\n');
    message.write('   Endpoint: $endpoint\n');
    if (responseTime != null) {
      message.write('   Time: ${responseTime}ms\n');
    }
    if (body != null) {
      message.write('   Body Type: ${_sanitizeBody(body).runtimeType}');
    }

    if (statusCode >= 200 && statusCode < 300) {
      _logger.i(message.toString().trim());
    } else if (statusCode >= 400) {
      _logger.w(message.toString().trim());
    } else {
      _logger.d(message.toString().trim());
    }
  }

  /// Log detailed error information for debugging
  static void logDetailedError({
    required String operation,
    required dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? additionalData,
  }) {
    _ensureInitialized();

    // Always capture stack trace if not provided
    final effectiveStackTrace = stackTrace ?? StackTrace.current;

    StringBuffer message = StringBuffer('💥 DETAILED ERROR\n');
    message.write('   Operation: $operation\n');
    message.write('   Error: ${error.toString()}\n');
    message.write('   Type: ${error.runtimeType}');

    if (additionalData != null && additionalData.isNotEmpty) {
      message.write('\n   Additional Data:');
      additionalData.forEach((key, value) {
        message.write('\n     $key: $value');
      });
    }

    _logger.e(message.toString(), error: error, stackTrace: effectiveStackTrace);
  }

  /// Comprehensive error reporting method
  static void reportError({
    required String context,
    required dynamic error,
    StackTrace? stackTrace,
    String? userId,
    String? operationId,
    Map<String, dynamic>? metadata,
  }) {
    _ensureInitialized();

    final effectiveStackTrace = stackTrace ?? StackTrace.current;
    final timestamp = DateTime.now().toIso8601String();

    StringBuffer report = StringBuffer('🚨 ERROR REPORT\n');
    report.write('   Timestamp: $timestamp\n');
    report.write('   Context: $context\n');
    report.write('   Error: ${error.toString()}\n');
    report.write('   Error Type: ${error.runtimeType}');

    if (userId != null) {
      report.write('\n   User ID: $userId');
    }
    if (operationId != null) {
      report.write('\n   Operation ID: $operationId');
    }

    if (metadata != null && metadata.isNotEmpty) {
      report.write('\n   Metadata:');
      metadata.forEach((key, value) {
        report.write('\n     $key: ${_sanitizeForLogging(value)}');
      });
    }

    // Extract key info from stack trace
    if (effectiveStackTrace.toString().isNotEmpty) {
      final lines = effectiveStackTrace.toString().split('\n');
      if (lines.isNotEmpty) {
        report.write('\n   Stack (top 3 frames):');
        for (int i = 0; i < 3 && i < lines.length; i++) {
          report.write('\n     ${lines[i].trim()}');
        }
      }
    }

    _logger.f(report.toString(), error: error, stackTrace: effectiveStackTrace);
  }

  /// Sanitize sensitive values for logging
  static String _sanitizeForLogging(dynamic value) {
    if (value == null) return 'null';
    final str = value.toString();

    // Check for potential sensitive data
    final sensitive = ['password', 'token', 'key', 'secret', 'auth'];
    final lowerStr = str.toLowerCase();

    for (final keyword in sensitive) {
      if (lowerStr.contains(keyword)) {
        return '***SANITIZED***';
      }
    }

    // Truncate very long strings
    return str.length > 200 ? '${str.substring(0, 200)}...' : str;
  }

  /// Sanitize sensitive data from logs
  static dynamic _sanitizeBody(dynamic body) {
    if (body is String) {
      // Remove potential passwords, tokens, etc.
      return body.replaceAllMapped(
        RegExp(r'"(password|token|key|secret)":\s*"[^"]*"', caseSensitive: false),
        (match) => '"${match.group(1)}": "***HIDDEN***"',
      );
    }
    return body;
  }

  /// Ensure logger is initialized
  static void _ensureInitialized() {
    if (!_initialized) {
      initialize();
    }
  }
}

/// Custom filter for controlling log levels based on environment
class _LoggerFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    // In release mode, only show warnings and errors
    if (kReleaseMode) {
      return event.level.value >= Level.warning.value;
    }

    // In debug mode, show based on DEBUG_MODE setting
    if (!DebugLogger.isDebugMode) {
      return event.level.value >= Level.info.value;
    }

    // In verbose debug mode, show everything
    return true;
  }
}
