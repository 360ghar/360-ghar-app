import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/network/response_parser.dart';

Map<String, dynamic> _row(Map<String, dynamic> json) => json;

Map<String, dynamic> _page({
  Object? items = const <Object?>[],
  Object? nextCursor,
  Object? hasMore = false,
  Object? limit = 20,
  Object? total,
  bool dropNextCursor = false,
  bool dropTotal = false,
}) => {
  'items': items,
  if (!dropNextCursor) 'next_cursor': nextCursor,
  'has_more': hasMore,
  'limit': limit,
  if (!dropTotal) 'total': total,
};

void main() {
  group('ResponseParser.object', () {
    test('returns a copy of a JSON object', () {
      const body = <String, dynamic>{'id': 2, 'name': 'No Wrapper'};

      final result = ResponseParser.object(body);

      expect(result, body);
      expect(identical(result, body), isFalse);
    });

    test('does not unwrap a data key: the contract has no data envelope', () {
      const body = <String, dynamic>{
        'data': {'id': 1},
      };

      expect(ResponseParser.object(body), body);
    });

    test('throws FormatException for a body that is not an object', () {
      expect(() => ResponseParser.object(null), throwsFormatException);
      expect(() => ResponseParser.object(<dynamic>[1, 2, 3]), throwsFormatException);
      expect(() => ResponseParser.object('hello'), throwsFormatException);
      expect(() => ResponseParser.object(42), throwsFormatException);
    });

    test('reads an empty object', () {
      expect(ResponseParser.object(<String, dynamic>{}), isEmpty);
    });
  });

  group('ResponseParser.cursorPage', () {
    test('reads the five keys of a CursorPage', () {
      final page = ResponseParser.cursorPage(
        _page(
          items: [
            {'id': 1},
            {'id': 2},
          ],
          nextCursor: 'abc',
          hasMore: true,
          limit: 2,
          total: 9,
        ),
        (json) => json['id'] as int,
      );

      expect(page.items, [1, 2]);
      expect(page.nextCursor, 'abc');
      expect(page.hasMore, isTrue);
      expect(page.limit, 2);
      expect(page.total, 9);
      expect(page.hasMorePages, isTrue);
    });

    test('total is null unless the request asked for include_total', () {
      final page = ResponseParser.cursorPage(_page(), _row);

      expect(page.total, isNull);
      expect(page.items, isEmpty);
    });

    test('a last page has no cursor and no more pages', () {
      final page = ResponseParser.cursorPage(_page(), _row);

      expect(page.nextCursor, isNull);
      expect(page.hasMorePages, isFalse);
    });

    test('an empty cursor reads as no cursor, so paging cannot loop on it', () {
      final page = ResponseParser.cursorPage(_page(nextCursor: '', hasMore: true), _row);

      expect(page.nextCursor, isNull);
      expect(page.hasMorePages, isFalse);
    });

    test('has_more without a cursor is not another page', () {
      final page = ResponseParser.cursorPage(_page(hasMore: true), _row);

      expect(page.hasMore, isTrue);
      expect(page.hasMorePages, isFalse);
    });

    test('the item list is unmodifiable', () {
      final page = ResponseParser.cursorPage(_page(items: [<String, dynamic>{}]), _row);

      expect(() => page.items.add({}), throwsUnsupportedError);
    });

    test('a bare list is not a CursorPage', () {
      expect(() => ResponseParser.cursorPage(<dynamic>[], _row), throwsFormatException);
    });

    test('a missing next_cursor or total key is a contract break', () {
      expect(
        () => ResponseParser.cursorPage(_page(dropNextCursor: true), _row),
        throwsFormatException,
      );
      expect(() => ResponseParser.cursorPage(_page(dropTotal: true), _row), throwsFormatException);
    });

    test('a key of the wrong type is a contract break', () {
      expect(() => ResponseParser.cursorPage(_page(items: 'x'), _row), throwsFormatException);
      expect(() => ResponseParser.cursorPage(_page(hasMore: 'yes'), _row), throwsFormatException);
      expect(() => ResponseParser.cursorPage(_page(limit: '20'), _row), throwsFormatException);
      expect(() => ResponseParser.cursorPage(_page(total: '9'), _row), throwsFormatException);
      expect(() => ResponseParser.cursorPage(_page(nextCursor: 5), _row), throwsFormatException);
    });

    test('an item that is not an object fails the whole page', () {
      expect(() => ResponseParser.cursorPage(_page(items: [1]), _row), throwsFormatException);
    });
  });
}
