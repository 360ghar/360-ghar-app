export 'package:ghar360/core/data/models/wire_enums.dart' show SortBy;

// Note: legacy page/offset-based PaginationParams, PaginatedResponse<T>, SearchParams and the
// `{message, success}` MessageResponse are gone. No REST response carries a `success` flag.
// Every list endpoint uses the `CursorPage` envelope (`{items, next_cursor, has_more, limit,
// total}`) consumed by [UnifiedPropertyResponse] and the repositories' own page readers.
