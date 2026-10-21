import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/utils/api_date_time.dart';

void main() {
  group('api_date_time helpers', () {
    test('parses naive timestamps as UTC', () {
      final parsed = parseApiDateTime('2026-03-12T10:15:30');

      expect(parsed, isNotNull);
      expect(parsed!.isUtc, isTrue);
      expect(parsed.toIso8601String(), '2026-03-12T10:15:30.000Z');
    });

    test('parses aware timestamps with +00:00 offsets', () {
      final parsed = parseApiDateTime('2026-03-12T10:15:30+00:00');

      expect(parsed, isNotNull);
      expect(parsed!.isUtc, isTrue);
      expect(parsed.toIso8601String(), '2026-03-12T10:15:30.000Z');
    });

    test('formats date-only values without shifting calendar day', () {
      expect(formatDateOnlyForApi(DateTime(2026, 3, 12, 23, 59)), '2026-03-12');
    });

    test('serializes instants back to UTC ISO strings', () {
      expect(
        toApiUtcInstant(DateTime.parse('2026-03-12T10:15:30+05:30')),
        '2026-03-12T04:45:30.000Z',
      );
    });
  });
}
