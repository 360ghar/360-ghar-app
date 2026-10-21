import 'dart:async';

import 'package:ghar360/core/utils/debug_logger.dart';

/// Runs fire-and-forget or best-effort work while keeping failures visible.
///
/// The codebase has many `try { ... } catch (_) {}` blocks where swallowing
/// the error is intentional (cleanup, telemetry, optional enhancements), but
/// bare empty catches make "fine to ignore" indistinguishable from a swallowed
/// bug. Route that work through here so it is logged at debug level instead.
class BestEffort {
  BestEffort._();

  /// Awaits [body]; resolves even when [body] throws (after logging at debug level).
  ///
  /// Use inside async flows where a failure must not propagate but the caller
  /// wants to `await` completion ordering.
  static Future<void> runAsync(
    FutureOr<void> Function() body, {
    String label = 'best-effort',
  }) async {
    try {
      await body();
    } catch (e, st) {
      DebugLogger.debug('🟡 [BEST_EFFORT] $label failed (ignored)', e, st);
    }
  }
}
