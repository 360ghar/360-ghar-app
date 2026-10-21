import 'package:flutter/foundation.dart';

import 'package:ghar360/core/utils/debug_logger.dart';

/// Debug-only diagnostic for tracking null-check operator exceptions.
/// All methods are no-ops in release builds.
class NullCheckTrap {
  static bool _fired = false;
  static bool _stringFired = false;

  static bool get hasFired => _fired;

  static void _logCommonContext({String source = 'unknown'}) {
    if (!kDebugMode) return;
    try {
      DebugLogger.error('🚨 [NULL_CHECK_TRAP] SOURCE: $source');
      // Route/query, GPS, and account values are deliberately excluded.
      DebugLogger.error('NULL_CHECK_TRAP: Flutter ${defaultTargetPlatform.name}');
    } catch (e) {
      // Avoid throwing from the trap itself
      DebugLogger.warning('NULL_CHECK_TRAP context logging failed', e);
    }
  }

  static void capture(dynamic error, StackTrace stack, {String source = 'zone'}) {
    if (!kDebugMode || _fired) return;
    String text;
    try {
      text = error?.toString() ?? '';
    } catch (_) {
      return;
    }
    if (!text.contains('Null check operator used on a null value')) return;
    _fired = true;

    DebugLogger.error('🔥 [NULL_CHECK_TRAP] FIRST NULL CHECK OPERATOR EXCEPTION CAPTURED');
    DebugLogger.error('🔥 [NULL_CHECK_TRAP] Error type: ${error.runtimeType}');
    _logCommonContext(source: source);
    DebugLogger.error('🔥 [NULL_CHECK_TRAP] STACK TRACE (full):');
    DebugLogger.error(stack.toString());
  }

  static void captureFlutterError(FlutterErrorDetails details) {
    if (!kDebugMode || _fired) return;
    String text;
    try {
      text = details.exception.toString();
    } catch (_) {
      return;
    }
    if (!text.contains('Null check operator used on a null value')) return;
    _fired = true;

    DebugLogger.error('🔥 [NULL_CHECK_TRAP] FIRST NULL CHECK OPERATOR (FlutterError)');
    DebugLogger.error('NULL_CHECK_TRAP exception type: ${details.exception.runtimeType}');
    _logCommonContext(source: 'flutter_error');
    DebugLogger.error('🔥 [NULL_CHECK_TRAP] STACK TRACE (FlutterError):');
    DebugLogger.error(details.stack?.toString() ?? 'no stack');
  }

  // Capture one-time occurrences where the null-check message is only a String,
  // e.g., when UI passes error text into an error mapper. This logs the current
  // stack to pinpoint call sites even without a thrown exception.
  static void captureStringOccurrence(String message, {String source = 'mapper'}) {
    if (!kDebugMode || _stringFired) return;
    if (!message.contains('Null check operator used on a null value')) return;
    _stringFired = true;

    DebugLogger.error('🔥 [NULL_CHECK_TRAP] STRING-ONLY NULL CHECK MESSAGE CAPTURED');
    _logCommonContext(source: source);
    final stack = StackTrace.current;
    DebugLogger.error('🔥 [NULL_CHECK_TRAP] STACK TRACE (call site):');
    DebugLogger.error(stack.toString());
  }
}
