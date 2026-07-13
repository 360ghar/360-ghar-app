import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/network/response_parser.dart';

void main() {
  group('ResponseParser.unwrapObject', () {
    test('unwraps the data wrapper when present', () {
      const body = <String, dynamic>{
        'data': <String, dynamic>{'id': 1, 'name': 'Test'},
      };

      final result = ResponseParser.unwrapObject(body);

      expect(result, <String, dynamic>{'id': 1, 'name': 'Test'});
    });

    test('returns the body itself when no data wrapper', () {
      const body = <String, dynamic>{'id': 2, 'name': 'No Wrapper'};

      final result = ResponseParser.unwrapObject(body);

      expect(result, same(body));
    });

    test('returns the body when data is not a Map (e.g. a List)', () {
      const body = <String, dynamic>{
        'data': <dynamic>[1, 2, 3],
        'meta': <String, dynamic>{'page': 1},
      };

      final result = ResponseParser.unwrapObject(body);

      // data is a List, so the wrapper is ignored and the body returned.
      expect(result, same(body));
    });

    test('returns the body when data is null', () {
      const body = <String, dynamic>{'data': null, 'other': 'value'};

      final result = ResponseParser.unwrapObject(body);

      expect(result, same(body));
    });

    test('throws FormatException when body is null', () {
      expect(() => ResponseParser.unwrapObject(null), throwsFormatException);
    });

    test('throws FormatException when body is a List', () {
      expect(() => ResponseParser.unwrapObject(<dynamic>[1, 2, 3]), throwsFormatException);
    });

    test('throws FormatException when body is a String', () {
      expect(() => ResponseParser.unwrapObject('hello'), throwsFormatException);
    });

    test('throws FormatException when body is an int', () {
      expect(() => ResponseParser.unwrapObject(42), throwsFormatException);
    });

    test('handles empty Map without data wrapper', () {
      final result = ResponseParser.unwrapObject(<String, dynamic>{});
      expect(result, <String, dynamic>{});
    });
  });

  group('ResponseParser.unwrapList', () {
    test('returns the body directly when it is a List', () {
      final body = <dynamic>[1, 2, 3];

      final result = ResponseParser.unwrapList(body);

      expect(result, <dynamic>[1, 2, 3]);
    });

    test('unwraps via items key (cursor envelope)', () {
      const body = <String, dynamic>{
        'items': <dynamic>[
          {'id': 1},
        ],
        'has_more': false,
      };

      final result = ResponseParser.unwrapList(body);

      expect(result, <dynamic>[
        {'id': 1},
      ]);
    });

    test('unwraps via data key when items absent', () {
      const body = <String, dynamic>{
        'data': <dynamic>[
          {'id': 2},
        ],
      };

      final result = ResponseParser.unwrapList(body);

      expect(result, <dynamic>[
        {'id': 2},
      ]);
    });

    test('prefers items over data when both present', () {
      const body = <String, dynamic>{
        'items': <dynamic>[
          {'id': 1},
        ],
        'data': <dynamic>[
          {'id': 2},
        ],
      };

      final result = ResponseParser.unwrapList(body);

      expect(result, <dynamic>[
        {'id': 1},
      ]);
    });

    test('falls back to provided fallbackKeys', () {
      const body = <String, dynamic>{
        'results': <dynamic>[
          {'id': 3},
        ],
      };

      final result = ResponseParser.unwrapList(body, fallbackKeys: const ['results']);

      expect(result, <dynamic>[
        {'id': 3},
      ]);
    });

    test('tries fallbackKeys in order and uses the first List found', () {
      const body = <String, dynamic>{
        'second': <dynamic>[
          {'id': 9},
        ],
      };

      final result = ResponseParser.unwrapList(
        body,
        fallbackKeys: const ['first', 'second', 'third'],
      );

      expect(result, <dynamic>[
        {'id': 9},
      ]);
    });

    test('skips non-List fallback keys', () {
      const body = <String, dynamic>{
        'first': 'not a list',
        'second': <dynamic>[
          {'id': 7},
        ],
      };

      final result = ResponseParser.unwrapList(body, fallbackKeys: const ['first', 'second']);

      expect(result, <dynamic>[
        {'id': 7},
      ]);
    });

    test('throws FormatException when Map has no list under any key', () {
      const body = <String, dynamic>{
        'meta': <String, dynamic>{'page': 1},
      };

      expect(
        () => ResponseParser.unwrapList(body, fallbackKeys: const ['results']),
        throwsFormatException,
      );
    });

    test('throws FormatException when body is null', () {
      expect(() => ResponseParser.unwrapList(null), throwsFormatException);
    });

    test('throws FormatException when body is a String', () {
      expect(() => ResponseParser.unwrapList('hello'), throwsFormatException);
    });

    test('throws FormatException when body is an int', () {
      expect(() => ResponseParser.unwrapList(42), throwsFormatException);
    });

    test('returns empty list when items is an empty list', () {
      const body = <String, dynamic>{'items': <dynamic>[]};

      final result = ResponseParser.unwrapList(body);

      expect(result, <dynamic>[]);
    });
  });

  group('ResponseParser.extractHasMore', () {
    test('returns true when has_more is true', () {
      const body = <String, dynamic>{'has_more': true};
      expect(ResponseParser.extractHasMore(body), isTrue);
    });

    test('returns false when has_more is false', () {
      const body = <String, dynamic>{'has_more': false};
      expect(ResponseParser.extractHasMore(body), isFalse);
    });

    test('returns false when has_more is missing', () {
      const body = <String, dynamic>{'items': <dynamic>[]};
      expect(ResponseParser.extractHasMore(body), isFalse);
    });

    test('returns false when has_more is null', () {
      const body = <String, dynamic>{'has_more': null};
      expect(ResponseParser.extractHasMore(body), isFalse);
    });

    test('returns false when has_more is a non-bool value (string)', () {
      const body = <String, dynamic>{'has_more': 'true'};
      expect(ResponseParser.extractHasMore(body), isFalse);
    });

    test('returns false when has_more is a non-bool value (int)', () {
      const body = <String, dynamic>{'has_more': 1};
      expect(ResponseParser.extractHasMore(body), isFalse);
    });

    test('returns false when body is null', () {
      expect(ResponseParser.extractHasMore(null), isFalse);
    });

    test('returns false when body is a List', () {
      expect(ResponseParser.extractHasMore(<dynamic>[1, 2]), isFalse);
    });
  });

  group('ResponseParser.extractNextCursor', () {
    test('returns the cursor when present and non-empty', () {
      const body = <String, dynamic>{'next_cursor': 'abc123'};
      expect(ResponseParser.extractNextCursor(body), 'abc123');
    });

    test('returns null when next_cursor is empty string', () {
      const body = <String, dynamic>{'next_cursor': ''};
      expect(ResponseParser.extractNextCursor(body), isNull);
    });

    test('returns null when next_cursor is missing', () {
      const body = <String, dynamic>{'items': <dynamic>[]};
      expect(ResponseParser.extractNextCursor(body), isNull);
    });

    test('returns null when next_cursor is null', () {
      const body = <String, dynamic>{'next_cursor': null};
      expect(ResponseParser.extractNextCursor(body), isNull);
    });

    test('returns null when next_cursor is a non-string value (int)', () {
      const body = <String, dynamic>{'next_cursor': 123};
      expect(ResponseParser.extractNextCursor(body), isNull);
    });

    test('returns null when body is null', () {
      expect(ResponseParser.extractNextCursor(null), isNull);
    });

    test('returns null when body is a List', () {
      expect(ResponseParser.extractNextCursor(<dynamic>[1, 2]), isNull);
    });
  });

  group('ResponseParser.extractTotal', () {
    test('returns the total when present as int', () {
      const body = <String, dynamic>{'total': 42};
      expect(ResponseParser.extractTotal(body), 42);
    });

    test('returns the total when present as double', () {
      const body = <String, dynamic>{'total': 42.0};
      expect(ResponseParser.extractTotal(body), 42);
    });

    test('falls back to count when total is absent', () {
      const body = <String, dynamic>{'count': 7};
      expect(ResponseParser.extractTotal(body), 7);
    });

    test('prefers total over count when both present', () {
      const body = <String, dynamic>{'total': 10, 'count': 20};
      expect(ResponseParser.extractTotal(body), 10);
    });

    test('falls back to listLength when both total and count are missing', () {
      const body = <String, dynamic>{'items': <dynamic>[]};
      expect(ResponseParser.extractTotal(body, listLength: 5), 5);
    });

    test('falls back to default listLength (0) when missing', () {
      const body = <String, dynamic>{'items': <dynamic>[]};
      expect(ResponseParser.extractTotal(body), 0);
    });

    test('falls back to listLength when total is null', () {
      const body = <String, dynamic>{'total': null};
      expect(ResponseParser.extractTotal(body, listLength: 3), 3);
    });

    test('falls back to listLength when total is a non-num value', () {
      const body = <String, dynamic>{'total': 'many'};
      expect(ResponseParser.extractTotal(body, listLength: 9), 9);
    });

    test('falls back to listLength when body is null', () {
      expect(ResponseParser.extractTotal(null, listLength: 4), 4);
    });

    test('falls back to listLength when body is a List', () {
      expect(ResponseParser.extractTotal(<dynamic>[1, 2, 3], listLength: 6), 6);
    });
  });
}
