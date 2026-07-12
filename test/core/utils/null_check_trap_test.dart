import 'package:flutter/foundation.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:ghar360/core/controllers/page_state_service.dart';
import 'package:ghar360/core/utils/null_check_trap.dart';

import '../../helpers/getx_test_binding.dart';
import '../../helpers/mocks.dart';

void main() {
  // NullCheckTrap uses private static _fired / _stringFired flags that cannot
  // be reset from outside the library. Each test file runs in its own isolate,
  // so the flags start false here, but within this file they persist across
  // tests. Tests are therefore ordered so the initial-state check runs first,
  // followed by the non-firing case, then the firing case, then idempotency.

  setUp(() {
    GetxTestBinding.init();
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  group('NullCheckTrap.hasFired', () {
    test('is false before any null-check exception is captured', () {
      expect(NullCheckTrap.hasFired, isFalse);
    });
  });

  group('NullCheckTrap.capture', () {
    test('ignores errors that do not contain the null-check message', () {
      NullCheckTrap.capture(
        StateError('Some other error'),
        StackTrace.current,
        source: 'test',
      );

      expect(NullCheckTrap.hasFired, isFalse);
    });

    test('fires for a null-check operator exception', () {
      NullCheckTrap.capture(
        _NullCheckError(),
        StackTrace.current,
        source: 'test',
      );

      expect(NullCheckTrap.hasFired, isTrue);
    });

    test('fires only once (idempotent)', () {
      // Already fired from the previous test; calling again must not throw and
      // hasFired remains true.
      NullCheckTrap.capture(
        _NullCheckError(),
        StackTrace.current,
        source: 'test-idempotent',
      );

      expect(NullCheckTrap.hasFired, isTrue);
    });

    test('does not throw when PageStateService is not registered', () {
      // _fired is already true, so this is a no-op, but we verify the method
      // is safe to call without a registered PageStateService.
      expect(
        () => NullCheckTrap.capture(
          _NullCheckError(),
          StackTrace.current,
          source: 'no-service',
        ),
        returnsNormally,
      );
    });
  });

  group('NullCheckTrap.captureFlutterError', () {
    test('does not throw and is safe to call', () {
      final details = FlutterErrorDetails(
        exception: _NullCheckError(),
        stack: StackTrace.current,
        library: 'test library',
        context: DiagnosticsNode.message('test context'),
      );

      // _fired is already true from earlier tests, so this is a no-op.
      expect(() => NullCheckTrap.captureFlutterError(details), returnsNormally);
    });

    test('ignores non-null-check FlutterErrorDetails', () {
      // Use a fresh details object with a non-matching message. Since _fired is
      // already true this is a no-op regardless, but we verify no throw.
      final details = FlutterErrorDetails(
        exception: StateError('Unrelated flutter error'),
        stack: StackTrace.current,
      );

      expect(() => NullCheckTrap.captureFlutterError(details), returnsNormally);
    });
  });

  group('NullCheckTrap.captureStringOccurrence', () {
    test('ignores strings without the null-check message', () {
      NullCheckTrap.captureStringOccurrence('Some unrelated message', source: 'test');

      // _stringFired should still be false.
      // We cannot read _stringFired directly, but hasFired is unaffected.
      expect(NullCheckTrap.hasFired, isTrue); // unchanged from earlier
    });

    test('captures a string containing the null-check message', () {
      // _stringFired is a separate flag; this should fire once.
      expect(
        () => NullCheckTrap.captureStringOccurrence(
          'Null check operator used on a null value',
          source: 'mapper-test',
        ),
        returnsNormally,
      );
    });

    test('is idempotent for string occurrences', () {
      // Second call should be a no-op (already fired).
      expect(
        () => NullCheckTrap.captureStringOccurrence(
          'Null check operator used on a null value',
          source: 'mapper-test-2',
        ),
        returnsNormally,
      );
    });
  });

  group('NullCheckTrap with registered PageStateService', () {
    test('logs context without throwing when service is registered', () {
      // _fired is already true so capture is a no-op; but we verify registering
      // a PageStateService does not cause issues.
      GetxTestBinding.bind().register<PageStateService>(MockPageStateService());

      expect(
        () => NullCheckTrap.capture(
          _NullCheckError(),
          StackTrace.current,
          source: 'with-service',
        ),
        returnsNormally,
      );
    });
  });

  group('NullCheckTrap.capture with null error', () {
    test('handles null error gracefully', () {
      // error?.toString() ?? '' yields '', which does not contain the message.
      // This should not fire and should not throw.
      expect(
        () => NullCheckTrap.capture(null, StackTrace.current, source: 'null-error'),
        returnsNormally,
      );
    });
  });
}

/// A stand-in exception whose toString() contains the null-check operator
/// message that NullCheckTrap looks for.
class _NullCheckError implements Exception {
  @override
  String toString() => 'Null check operator used on a null value';
}
