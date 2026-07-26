import 'package:flutter/foundation.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/utils/debug_logger.dart';

void main() {
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
