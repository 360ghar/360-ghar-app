import 'package:flutter/foundation.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/utils/null_check_trap.dart';
import '../../helpers/log_capture.dart';

void main() {
  test('Flutter and string traps retain stacks without error or context payloads', () {
    final logs = LogCapture();
    addTearDown(logs.close);
    final stack = StackTrace.fromString('#0 safeFrame (package:ghar360/example.dart:7:1)');
    NullCheckTrap.captureFlutterError(
      FlutterErrorDetails(
        exception: StateError('Null check operator used on a null value private-token'),
        library: 'private-library',
        context: DiagnosticsNode.message('private-route'),
        stack: stack,
      ),
    );
    NullCheckTrap.captureStringOccurrence(
      'Null check operator used on a null value private-message',
    );
    expect(NullCheckTrap.hasFired, true);
    expect(logs.text, contains('safeFrame'));
    expect(logs.text, contains('StateError'));
    expect(logs.text, isNot(contains('private-')));
  });
}
