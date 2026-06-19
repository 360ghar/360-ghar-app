import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/utils/retry_policy.dart';

/// No-op sleep seam so tests exercise the retry loop without waiting.
Future<void> _noSleep(Duration _) async {}

void main() {
  group('RetryPolicy.delayForAttempt', () {
    test('matches the 250ms ApiClient formula for attempts 1..3', () {
      const policy = RetryPolicy(maxAttempts: 3, initialDelay: Duration(milliseconds: 250));
      // 250ms * 2^(n-1)
      expect(policy.delayForAttempt(1), const Duration(milliseconds: 250));
      expect(policy.delayForAttempt(2), const Duration(milliseconds: 500));
      expect(policy.delayForAttempt(3), const Duration(milliseconds: 1000));
    });

    test('matches the 2s AuthController formula for attempts 1..3', () {
      const policy = RetryPolicy(maxAttempts: 3, initialDelay: Duration(seconds: 2));
      // 2s * 2^(n-1)
      expect(policy.delayForAttempt(1), const Duration(seconds: 2));
      expect(policy.delayForAttempt(2), const Duration(seconds: 4));
      expect(policy.delayForAttempt(3), const Duration(seconds: 8));
    });

    test('clamps to maxDelay when provided', () {
      const policy = RetryPolicy(
        maxAttempts: 5,
        initialDelay: Duration(seconds: 2),
        maxDelay: Duration(seconds: 5),
      );
      expect(policy.delayForAttempt(1), const Duration(seconds: 2));
      expect(policy.delayForAttempt(2), const Duration(seconds: 4));
      expect(policy.delayForAttempt(3), const Duration(seconds: 5)); // capped
    });

    test('attempt < 1 returns Duration.zero', () {
      const policy = RetryPolicy(maxAttempts: 3, initialDelay: Duration(seconds: 2));
      expect(policy.delayForAttempt(0), Duration.zero);
    });
  });

  group('RetryPolicy.execute', () {
    test('returns on first success without invoking sleep', () async {
      const policy = RetryPolicy(maxAttempts: 3, initialDelay: Duration(seconds: 2));
      var calls = 0;
      var sleeps = 0;

      final result = await policy.execute(() async {
        calls++;
        return 'ok';
      }, sleep: (_) async => sleeps++);

      expect(result, 'ok');
      expect(calls, 1);
      expect(sleeps, 0);
    });

    test('retries exactly maxAttempts times then rethrows the last error', () async {
      const policy = RetryPolicy(maxAttempts: 3, initialDelay: Duration(seconds: 2));
      var calls = 0;
      var sleeps = 0;

      await expectLater(
        policy.execute(() async {
          calls++;
          throw NetworkException('boom $calls');
        }, sleep: (_) async => sleeps++),
        throwsA(isA<NetworkException>()),
      );

      // 3 total attempts (1 initial + 2 retries), so 2 backoff sleeps.
      expect(calls, 3);
      expect(sleeps, 2);
    });

    test('retryIf=false short-circuits with no retry', () async {
      final policy = RetryPolicy(
        maxAttempts: 5,
        initialDelay: const Duration(seconds: 2),
        retryIf: (_) => false,
      );
      var calls = 0;
      var sleeps = 0;

      await expectLater(
        policy.execute(() async {
          calls++;
          throw NetworkException('nope');
        }, sleep: (_) async => sleeps++),
        throwsA(isA<NetworkException>()),
      );

      expect(calls, 1);
      expect(sleeps, 0);
    });

    test('succeeds after a transient failure', () async {
      const policy = RetryPolicy(maxAttempts: 3, initialDelay: Duration(seconds: 2));
      var calls = 0;

      final result = await policy.execute(() async {
        calls++;
        if (calls < 2) throw NetworkException('transient');
        return calls;
      }, sleep: _noSleep);

      expect(result, 2);
      expect(calls, 2);
    });
  });

  group('RetryPolicy.shouldRetry', () {
    test('stops once attempts are exhausted', () {
      const policy = RetryPolicy(maxAttempts: 3, initialDelay: Duration(milliseconds: 250));
      expect(policy.shouldRetry(1, NetworkException('x')), isTrue);
      expect(policy.shouldRetry(2, NetworkException('x')), isTrue);
      expect(policy.shouldRetry(3, NetworkException('x')), isFalse);
    });

    test('honours the retryIf predicate', () {
      final policy = RetryPolicy(
        maxAttempts: 3,
        initialDelay: const Duration(milliseconds: 250),
        retryIf: (e) => e is NetworkException,
      );
      expect(policy.shouldRetry(1, NetworkException('x')), isTrue);
      expect(policy.shouldRetry(1, ValidationException('x')), isFalse);
    });
  });

  group('RetryPolicy.isTransientError', () {
    test('retries network and server exceptions', () {
      expect(RetryPolicy.isTransientError(NetworkException('x')), isTrue);
      expect(RetryPolicy.isTransientError(ServerException('x', statusCode: 500)), isTrue);
    });

    test('does not retry auth/validation exceptions', () {
      expect(
        RetryPolicy.isTransientError(AuthenticationException('x', code: 'UNAUTHORIZED')),
        isFalse,
      );
      expect(RetryPolicy.isTransientError(ValidationException('x')), isFalse);
    });

    test('does not retry non-AppException errors', () {
      expect(RetryPolicy.isTransientError(Exception('raw')), isFalse);
    });
  });

  group('RetryPolicy presets', () {
    test('apiGet: 3 attempts, 250ms base backoff', () {
      final policy = RetryPolicy.apiGet();
      expect(policy.maxAttempts, 3);
      expect(policy.delayForAttempt(1), const Duration(milliseconds: 250));
      expect(policy.delayForAttempt(2), const Duration(milliseconds: 500));
    });

    test('idempotentMutation: 2 attempts, 250ms base backoff', () {
      final policy = RetryPolicy.idempotentMutation();
      expect(policy.maxAttempts, 2);
      expect(policy.delayForAttempt(1), const Duration(milliseconds: 250));
    });

    test('profileBoot: 3 attempts, 2s base backoff', () {
      final policy = RetryPolicy.profileBoot();
      expect(policy.maxAttempts, 3);
      expect(policy.delayForAttempt(1), const Duration(seconds: 2));
      expect(policy.delayForAttempt(2), const Duration(seconds: 4));
    });

    test('presets default to the transient-error predicate', () {
      final policy = RetryPolicy.apiGet();
      expect(policy.shouldRetry(1, NetworkException('x')), isTrue);
      expect(policy.shouldRetry(1, ValidationException('x')), isFalse);
    });

    test('presets accept a custom retryIf override', () {
      final policy = RetryPolicy.profileBoot(retryIf: (_) => true);
      expect(policy.shouldRetry(1, ValidationException('x')), isTrue);
    });
  });
}
