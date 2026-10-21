import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/features/auth/data/identifier_utils.dart';

void main() {
  group('IdentifierUtils.isEmail', () {
    test('accepts valid addresses, ignoring surrounding whitespace', () {
      for (final value in [
        'john@example.com',
        '  john.doe+tag@mail.example.co.in  ',
        'a_b-c@sub.example.org',
      ]) {
        expect(IdentifierUtils.isEmail(value), isTrue, reason: value);
      }
    });

    test('rejects malformed input and phone numbers', () {
      for (final value in ['', 'john', 'john@', 'john@gmail', '@example.com', '+919876543210']) {
        expect(IdentifierUtils.isEmail(value), isFalse, reason: value);
      }
    });
  });
}
