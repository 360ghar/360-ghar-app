/// Standardized API response parsing utilities.
///
/// All backend responses may be wrapped in `{ "data": ... }` or returned
/// unwrapped. This utility normalises both formats so datasources can
/// focus on domain logic.
class ResponseParser {
  /// Unwrap a single object from an API response body.
  ///
  /// Handles both `{ "data": { ... } }` and raw `{ ... }` formats.
  /// Returns the inner map, or the body itself if no wrapper.
  /// Throws [FormatException] if body is not a Map.
  static Map<String, dynamic> unwrapObject(dynamic body) {
    if (body is Map<String, dynamic>) {
      final data = body['data'];
      if (data is Map<String, dynamic>) return data;
      return body;
    }
    throw FormatException(
      'Expected Map<String, dynamic> in response body, but got ${body?.runtimeType ?? 'null'}',
    );
  }

  /// Unwrap a list from an API response body.
  ///
  /// Tries `body['items']` (uniform cursor envelope), then `body['data']`,
  /// then [fallbackKeys] in order, then `body` itself. Returns a `List` if
  /// found, otherwise throws [FormatException].
  static List unwrapList(dynamic body, {List<String> fallbackKeys = const []}) {
    if (body is List) return body;
    if (body is Map<String, dynamic>) {
      final items = body['items'];
      if (items is List) return items;
      final data = body['data'];
      if (data is List) return data;
      for (final key in fallbackKeys) {
        final alt = body[key];
        if (alt is List) return alt;
      }
      // If body itself is a map but no list found, throw exception
      throw FormatException(
        'Expected List in response body (checked keys: items, data, '
        '${fallbackKeys.join(', ')}), '
        'but found keys: ${body.keys.take(10).join(', ')}',
      );
    }
    throw FormatException(
      'Expected List or Map<String, dynamic> in response body, but got ${body?.runtimeType ?? 'null'}',
    );
  }

  /// Extract the cursor-pagination `has_more` flag from the response envelope.
  ///
  /// Reads `body['has_more']` (uniform cursor envelope). Returns `false` when
  /// absent or non-bool so callers can safely treat the page as terminal.
  static bool extractHasMore(dynamic body) {
    if (body is Map<String, dynamic>) {
      final value = body['has_more'];
      if (value is bool) return value;
    }
    return false;
  }

  /// Extract the opaque cursor-pagination `next_cursor` token from the
  /// response envelope. Returns `null` on terminal pages or missing keys.
  /// The token is opaque; callers MUST NOT decode it.
  static String? extractNextCursor(dynamic body) {
    if (body is Map<String, dynamic>) {
      final value = body['next_cursor'];
      if (value is String && value.isNotEmpty) return value;
    }
    return null;
  }

  /// Extract pagination total from the response envelope.
  ///
  /// Looks for `total`, then `count` keys. Falls back to [listLength].
  /// Tolerates `null`/missing values (returns [listLength]) for callers that
  /// still reference totals during the cursor migration.
  static int extractTotal(dynamic body, {int listLength = 0}) {
    if (body is Map<String, dynamic>) {
      if (body['total'] is num) return (body['total'] as num).toInt();
      if (body['count'] is num) return (body['count'] as num).toInt();
    }
    return listLength;
  }
}
