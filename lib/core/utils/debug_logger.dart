import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:logger/logger.dart';

import 'package:ghar360/core/config/app_config.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';

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
      printer: _DiagnosticPrinter(),
      output: ConsoleOutput(),
    );
    _initialized = true;
  }

  // Messages are developer-authored labels. Never interpolate payloads or
  // exception text; structured errors cross this redaction boundary instead.
  static void debug(String message, [Object? error, StackTrace? stackTrace]) =>
      _write(Level.debug, message, error, stackTrace);
  static void info(String message, [Object? error, StackTrace? stackTrace]) =>
      _write(Level.info, message, error, stackTrace);
  static void success(String message, [Object? error, StackTrace? stackTrace]) =>
      _write(Level.info, message, error, stackTrace);
  static void warning(String message, [Object? error, StackTrace? stackTrace]) =>
      _write(Level.warning, message, error, stackTrace);
  static void error(String message, [Object? error, StackTrace? stackTrace]) => _write(
    Level.error,
    message,
    error,
    stackTrace ?? (error == null ? null : StackTrace.current),
  );
  static void api(String message, [Object? error, StackTrace? stackTrace]) {
    if (shouldLogAPICalls) _write(Level.debug, message, error, stackTrace);
  }

  static void auth(String message, [Object? error, StackTrace? stackTrace]) =>
      _write(Level.info, message, error, stackTrace);
  static void startup(String message, [Object? error, StackTrace? stackTrace]) =>
      _write(Level.info, message, error, stackTrace);

  static String? _errorSummary(Object? error) {
    if (error == null) return null;
    final type = error is Type ? error.toString() : error.runtimeType.toString();
    final code = switch (error) {
      AppException(:final code) => code,
      FirebaseException(:final code) => code,
      PlatformException(:final code) => code,
      _ => null,
    };
    final status = switch (error) {
      ApiException(:final statusCode) => statusCode,
      ServerException(:final statusCode) => statusCode,
      _ => null,
    };
    return [
      type,
      if (code != null && RegExp(r'^[A-Za-z][A-Za-z0-9_-]{0,63}$').hasMatch(code)) 'code=$code',
      if (status != null && status >= 100 && status <= 599) 'status=$status',
    ].join(' ');
  }

  static void _write(Level level, String message, Object? error, StackTrace? stack) {
    try {
      _ensureInitialized();
      _logger.log(level, message, error: _errorSummary(error), stackTrace: stack);
    } catch (_) {
      // Diagnostics must not replace the application outcome or recurse when
      // an output sink fails. No raw fallback print is safe here.
    }
  }

  /// Keep only known diagnostic scalars; arbitrary context can hold credentials,
  /// route queries, coordinates, messages, names, or response bodies.
  static void logDetailedError({
    required String operation,
    required Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? additionalData,
  }) {
    final safe = <String, Object>{};
    final method = additionalData?['method'];
    if (const {'GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'HEAD', 'OPTIONS'}.contains(method)) {
      safe['method'] = method as String;
    }
    for (final key in ['statusCode', 'attempt', 'maxAttempts', 'durationMs', 'count']) {
      final value = additionalData?[key];
      if (value is int && value >= 0) safe[key] = value;
    }
    _write(
      Level.error,
      'Operation failed: $operation; diagnostics=$safe',
      error,
      stackTrace ?? StackTrace.current,
    );
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

class _DiagnosticPrinter extends SimplePrinter {
  @override
  List<String> log(LogEvent event) => [
    ...super.log(event),
    if (event.stackTrace != null) ...event.stackTrace.toString().split('\n').take(30),
  ];
}
