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
    test('verbose does not throw', () {
      expect(() => DebugLogger.verbose('test verbose'), returnsNormally);
    });

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

    test('wtf does not throw', () {
      expect(() => DebugLogger.wtf('test wtf'), returnsNormally);
    });

    test('verbose with error and stackTrace does not throw', () {
      final error = StateError('boom');
      expect(
        () => DebugLogger.verbose('test verbose with error', error, StackTrace.current),
        returnsNormally,
      );
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

    test('jwt does not throw', () {
      expect(() => DebugLogger.jwt('test jwt'), returnsNormally);
    });

    test('user does not throw', () {
      expect(() => DebugLogger.user('test user'), returnsNormally);
    });

    test('property does not throw', () {
      expect(() => DebugLogger.property('test property'), returnsNormally);
    });

    test('network does not throw (no-op when shouldLogAPICalls is false)', () {
      expect(() => DebugLogger.network('test network'), returnsNormally);
    });

    test('connection does not throw', () {
      expect(() => DebugLogger.connection('test connection'), returnsNormally);
    });

    test('startup does not throw', () {
      expect(() => DebugLogger.startup('test startup'), returnsNormally);
    });
  });

  group('DebugLogger.logJWTToken', () {
    test('does not throw with a valid token', () {
      expect(
        () => DebugLogger.logJWTToken('a'.padRight(32, 'a')),
        returnsNormally,
      );
    });

    test('does not throw with expiresAt, userId, and userEmail', () {
      expect(
        () => DebugLogger.logJWTToken(
          'a'.padRight(32, 'a'),
          expiresAt: DateTime(2025, 1, 1),
          userId: 'user-12345678',
          userEmail: 'test@example.com',
        ),
        returnsNormally,
      );
    });
  });

  group('DebugLogger.logAPIRequest', () {
    test('does not throw (no-op when shouldLogAPICalls is false)', () {
      expect(
        () => DebugLogger.logAPIRequest(
          method: 'GET',
          endpoint: '/api/properties',
        ),
        returnsNormally,
      );
    });

    test('does not throw with headers and body', () {
      expect(
        () => DebugLogger.logAPIRequest(
          method: 'POST',
          endpoint: '/api/properties',
          headers: {'Authorization': 'Bearer token'},
          body: '{"title": "Test"}',
        ),
        returnsNormally,
      );
    });
  });

  group('DebugLogger.logAPIResponse', () {
    test('does not throw (no-op when shouldLogAPICalls is false)', () {
      expect(
        () => DebugLogger.logAPIResponse(
          statusCode: 200,
          endpoint: '/api/properties',
        ),
        returnsNormally,
      );
    });

    test('does not throw with body and responseTime', () {
      expect(
        () => DebugLogger.logAPIResponse(
          statusCode: 404,
          endpoint: '/api/properties/999',
          body: '{"error": "not found"}',
          responseTime: 150,
        ),
        returnsNormally,
      );
    });
  });

  group('DebugLogger.logDetailedError', () {
    test('does not throw with required parameters', () {
      expect(
        () => DebugLogger.logDetailedError(
          operation: 'testOperation',
          error: StateError('boom'),
        ),
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

  group('DebugLogger.reportError', () {
    test('does not throw with required parameters', () {
      expect(
        () => DebugLogger.reportError(
          context: 'testContext',
          error: StateError('boom'),
        ),
        returnsNormally,
      );
    });

    test('does not throw with all optional parameters', () {
      expect(
        () => DebugLogger.reportError(
          context: 'testContext',
          error: StateError('boom'),
          stackTrace: StackTrace.current,
          userId: 'user-123',
          operationId: 'op-456',
          metadata: {'key': 'value'},
        ),
        returnsNormally,
      );
    });

    test('does not throw with empty metadata map', () {
      expect(
        () => DebugLogger.reportError(
          context: 'testContext',
          error: StateError('boom'),
          metadata: {},
        ),
        returnsNormally,
      );
    });
  });
}
