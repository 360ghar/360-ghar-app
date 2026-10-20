/// One page of the `CursorPage` envelope: `{items, next_cursor, has_more, limit, total}`.
///
/// The server always sends all five keys. `total` is null unless the request set
/// `include_total=true`. A cursor is opaque: pass [nextCursor] back unchanged, with the same
/// filters, and never decode it.
class CursorPageData<T> {
  const CursorPageData({
    required this.items,
    required this.hasMore,
    this.nextCursor,
    this.limit = 0,
    this.total,
  });

  final List<T> items;
  final String? nextCursor;
  final bool hasMore;
  final int limit;
  final int? total;

  /// True when another page can be fetched: the server says so and gave a cursor.
  bool get hasMorePages => hasMore && (nextCursor?.isNotEmpty ?? false);
}

/// Strict readers for response bodies. A body that does not have the contract shape throws a
/// [FormatException]; the callers turn it into a typed failure.
class ResponseParser {
  const ResponseParser._();

  /// The JSON object of a response body.
  static Map<String, dynamic> object(dynamic body) {
    if (body is Map) return Map<String, dynamic>.from(body);
    throw FormatException('Expected a JSON object, got ${body?.runtimeType ?? 'null'}');
  }

  /// A `CursorPage` body. Each item goes through [parse].
  static CursorPageData<T> cursorPage<T>(
    dynamic body,
    T Function(Map<String, dynamic> json) parse,
  ) {
    final page = object(body);
    final items = page['items'];
    final hasMore = page['has_more'];
    final nextCursor = page['next_cursor'];
    final limit = page['limit'];
    final total = page['total'];
    if (items is! List ||
        hasMore is! bool ||
        nextCursor is! String? ||
        limit is! int ||
        total is! int? ||
        !page.containsKey('next_cursor') ||
        !page.containsKey('total')) {
      throw const FormatException(
        'Expected a CursorPage: items, next_cursor, has_more, limit, total',
      );
    }
    return CursorPageData(
      items: List.unmodifiable([for (final item in items) parse(object(item))]),
      nextCursor: nextCursor == null || nextCursor.isEmpty ? null : nextCursor,
      hasMore: hasMore,
      limit: limit,
      total: total,
    );
  }
}
