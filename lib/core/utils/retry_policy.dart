import 'dart:async';

import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/utils/error_mapper.dart';

/// Signature for the delay seam used by [RetryPolicy].
///
/// Defaults to [Future.delayed]; tests can inject a no-op so they don't have to
/// wait real time while still exercising the retry loop.
typedef SleepFn = Future<void> Function(Duration duration);

/// A single, configurable retry primitive shared across the app.
///
/// Centralises the previously-scattered backoff strategies (the [ApiClient]
/// GET/idempotent-mutation retries and the [AuthController] profile-boot retry)
/// so the max-attempt counts, exponential-backoff timings and retry predicates
/// live in one documented place.
///
/// Behaviour is intentionally identical to the hand-rolled loops it replaces —
/// see the named presets ([apiGet], [idempotentMutation], [profileBoot]) for
/// the exact limits and timings.
class RetryPolicy {
  /// Total number of attempts (the initial try plus retries). Must be >= 1.
  final int maxAttempts;

  /// Base delay applied before the first retry.
  final Duration initialDelay;

  /// Exponential multiplier applied per retry. Delay before retry `n`
  /// (1-based) is `initialDelay * multiplier^(n-1)`.
  final double multiplier;

  /// Optional cap on the computed backoff delay.
  final Duration? maxDelay;

  /// Predicate deciding whether a thrown error is worth retrying. When null,
  /// every error is retried until attempts are exhausted.
  final bool Function(Object error)? retryIf;

  const RetryPolicy({
    required this.maxAttempts,
    required this.initialDelay,
    this.multiplier = 2.0,
    this.maxDelay,
    this.retryIf,
  }) : assert(maxAttempts >= 1, 'maxAttempts must be at least 1');

  /// Computes the exponential-backoff delay before retry [attempt] (1-based).
  ///
  /// `attempt == 1` returns [initialDelay]; each subsequent retry multiplies by
  /// [multiplier]. The result is clamped to [maxDelay] when set.
  Duration delayForAttempt(int attempt) {
    if (attempt < 1) return Duration.zero;
    final factor = _intPow(multiplier, attempt - 1);
    final micros = (initialDelay.inMicroseconds * factor).round();
    final delay = Duration(microseconds: micros);
    final cap = maxDelay;
    if (cap != null && delay > cap) return cap;
    return delay;
  }

  /// Whether another attempt should be made after [attempt] (1-based, the
  /// number of attempts already performed) failed with [error].
  bool shouldRetry(int attempt, Object error) {
    if (attempt >= maxAttempts) return false;
    final predicate = retryIf;
    return predicate == null || predicate(error);
  }

  /// Runs [action], retrying per this policy. Delays between attempts via
  /// [sleep] (defaults to [Future.delayed]). Rethrows the last error once
  /// attempts are exhausted or [retryIf] rejects the error.
  Future<T> execute<T>(Future<T> Function() action, {SleepFn? sleep}) async {
    final sleepFn = sleep ?? Future.delayed;
    var attempt = 0;
    while (true) {
      try {
        return await action();
      } catch (error) {
        attempt++;
        if (!shouldRetry(attempt, error)) rethrow;
        await sleepFn(delayForAttempt(attempt));
      }
    }
  }

  static double _intPow(double base, int exponent) {
    var result = 1.0;
    for (var i = 0; i < exponent; i++) {
      result *= base;
    }
    return result;
  }

  /// Default retry predicate reused across presets: retries the transient
  /// transport-layer failures the old loops retried on.
  ///
  /// Mirrors the previous [ApiClient] gate (`NetworkException` /
  /// `ServerException`) and defers to the typed [ErrorMapper.isRetryable] for
  /// other mapped [AppException]s.
  static bool isTransientError(Object error) {
    if (error is NetworkException || error is ServerException) return true;
    if (error is AppException) return ErrorMapper.isRetryable(error);
    return false;
  }

  /// GET requests: 1 initial attempt + 2 retries, 250ms base backoff
  /// (250ms, then 500ms), retrying transient transport errors.
  static RetryPolicy apiGet({bool Function(Object error)? retryIf}) => RetryPolicy(
    maxAttempts: 3,
    initialDelay: const Duration(milliseconds: 250),
    retryIf: retryIf ?? isTransientError,
  );

  /// Idempotent mutations: 1 initial attempt + 1 retry, 250ms base backoff,
  /// retrying transient transport errors.
  static RetryPolicy idempotentMutation({bool Function(Object error)? retryIf}) => RetryPolicy(
    maxAttempts: 2,
    initialDelay: const Duration(milliseconds: 250),
    retryIf: retryIf ?? isTransientError,
  );

  /// Profile-boot load: up to 3 attempts, 2s base backoff (2s, then 4s),
  /// retrying transient errors as classified by the caller's [retryIf].
  static RetryPolicy profileBoot({bool Function(Object error)? retryIf}) => RetryPolicy(
    maxAttempts: 3,
    initialDelay: const Duration(seconds: 2),
    retryIf: retryIf ?? isTransientError,
  );
}
