import 'package:flutter/foundation.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/utils/best_effort.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import '../../helpers/log_capture.dart';

void main() {
  group('diagnostic redaction', () {
    late LogCapture logs;
    setUp(() => logs = LogCapture());
    tearDown(() => logs.close());
    test('all error-bearing entry points discard exception messages and payloads', () {
      final error = ApiException(
        'Bearer private-token name@example.com',
        code: 'RATE_LIMITED',
        statusCode: 429,
        response: 'private-response',
        details: {'token': 'private-token'},
      );
      final stack = StackTrace.fromString('#0 safeFrame (package:ghar360/example.dart:7:1)');
      for (final log in [
        DebugLogger.debug,
        DebugLogger.info,
        DebugLogger.success,
        DebugLogger.warning,
        DebugLogger.error,
        DebugLogger.auth,
        DebugLogger.startup,
      ]) {
        log('Known operation', error, stack);
      }
      expect(logs.events, hasLength(7));
      expect(logs.text, contains('ApiException code=RATE_LIMITED status=429'));
      expect(logs.text, contains('safeFrame'));
      for (final secret in ['private-token', 'private-response', 'name@example.com']) {
        expect(logs.text, isNot(contains(secret)));
      }
    });
    test('detailed logging keeps known numeric context but drops arbitrary keys and values', () {
      DebugLogger.logDetailedError(
        operation: 'fetchProperties',
        error: StateError('private-error'),
        additionalData: {
          'method': 'GET',
          'statusCode': 500,
          'attempt': 2,
          'count': 4,
          'url': 'https://private/?token=secret',
          'token': 'private-token',
          'body': {'name': 'private-name'},
          'private-key': 'value',
          'durationMs': 'private-value',
        },
      );
      expect(logs.text, contains('fetchProperties'));
      expect(logs.text, contains('statusCode: 500'));
      expect(logs.text, contains('attempt: 2'));
      expect(logs.text, isNot(contains('private-')));
      expect(logs.text, isNot(contains('secret')));
    });
    test('unsafe error codes and hostile toString are never printed or evaluated', () {
      DebugLogger.warning(
        'Failure',
        NetworkException('private-message', code: 'token=private-code'),
      );
      final hostile = _HostileError();
      expect(() => DebugLogger.error('Failure', hostile), returnsNormally);
      expect(hostile.calls, 0);
      expect(logs.text, contains('_HostileError'));
      expect(logs.text, isNot(contains('private-')));
    });
    test('best-effort failures retain operation and type without changing control flow', () async {
      BestEffort.run(() => throw StateError('private-sync'), label: 'closeSheet');
      await BestEffort.runAsync(() async => throw StateError('private-async'), label: 'closeSheet');
      expect(logs.text, contains('closeSheet'));
      expect(logs.text, contains('StateError'));
      expect(logs.text, isNot(contains('private-')));
    });
    test('an output sink failure cannot escape diagnostic logging', () {
      void fail(OutputEvent event) => throw StateError('sink failed');
      Logger.addOutputListener(fail);
      try {
        expect(() => DebugLogger.warning('Failure', StateError('private')), returnsNormally);
      } finally {
        Logger.removeOutputListener(fail);
      }
    });
  });

  group('DebugLogger.initialize', () {
    test('can be called without throwing', () {
      expect(() => DebugLogger.initialize(), returnsNormally);
    });

    test('is idempotent — calling multiple times does not throw', () {
      DebugLogger.initialize();
      DebugLogger.initialize();

      expect(() => DebugLogger.initialize(), returnsNormally);
    });
  });

  group('DebugLogger.isDebugMode', () {
    test('returns kDebugMode when AppConfig is not initialized', () {
      // AppConfig is not initialized in tests, so isDebugMode falls back to
      // kDebugMode, which is true in the test environment.
      expect(DebugLogger.isDebugMode, kDebugMode);
    });

    test('returns a bool', () {
      expect(DebugLogger.isDebugMode, isA<bool>());
    });
  });

  group('DebugLogger.shouldLogAPICalls', () {
    test('returns false when AppConfig is not initialized', () {
      // AppConfig is not initialized in tests, so shouldLogAPICalls falls back
      // to false.
      expect(DebugLogger.shouldLogAPICalls, isFalse);
    });

    test('returns a bool', () {
      expect(DebugLogger.shouldLogAPICalls, isA<bool>());
    });
  });

  group('DebugLogger logging methods — do not throw', () {
    test('debug does not throw', () {
      expect(() => DebugLogger.debug('test debug'), returnsNormally);
    });

    test('info does not throw', () {
      expect(() => DebugLogger.info('test info'), returnsNormally);
    });

    test('success does not throw', () {
      expect(() => DebugLogger.success('test success'), returnsNormally);
    });

    test('warning does not throw', () {
      expect(() => DebugLogger.warning('test warning'), returnsNormally);
    });

    test('error does not throw', () {
      expect(() => DebugLogger.error('test error'), returnsNormally);
    });

    test('error with error and stackTrace does not throw', () {
      final error = StateError('boom');
      expect(
        () => DebugLogger.error('test error with error', error, StackTrace.current),
        returnsNormally,
      );
    });
  });

  group('DebugLogger categorized logging methods — do not throw', () {
    test('api does not throw (no-op when shouldLogAPICalls is false)', () {
      expect(() => DebugLogger.api('test api'), returnsNormally);
    });

    test('auth does not throw', () {
      expect(() => DebugLogger.auth('test auth'), returnsNormally);
    });

    test('startup does not throw', () {
      expect(() => DebugLogger.startup('test startup'), returnsNormally);
    });
  });

  group('DebugLogger.logDetailedError', () {
    test('does not throw with required parameters', () {
      expect(
        () => DebugLogger.logDetailedError(operation: 'testOperation', error: StateError('boom')),
        returnsNormally,
      );
    });

    test('does not throw with stackTrace and additionalData', () {
      expect(
        () => DebugLogger.logDetailedError(
          operation: 'testOperation',
          error: StateError('boom'),
          stackTrace: StackTrace.current,
          additionalData: {'key': 'value', 'count': 42},
        ),
        returnsNormally,
      );
    });
  });
}

class _HostileError implements Exception {
  int calls = 0;
  @override
  String toString() {
    calls++;
    throw StateError('private-data');
  }
}
