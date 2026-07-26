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

  /// Initialization related logs
  static void startup(String message, [dynamic error, StackTrace? stackTrace]) {
    _ensureInitialized();
    _logger.i('🔧 $message', error: error, stackTrace: stackTrace);
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
