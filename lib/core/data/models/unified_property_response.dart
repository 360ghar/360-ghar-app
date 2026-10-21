import 'package:ghar360/core/data/models/property_model.dart';
import 'package:json_annotation/json_annotation.dart';

part 'unified_property_response.g.dart';

/// `CursorPage` of `Property`, returned by `GET /properties` and `GET /swipes`.
///
/// Shape: `{items: [...], next_cursor: an opaque string or null, has_more: bool, limit: int,
/// total: int|null}`. The server always sends all five keys. `total` is null unless the request
/// set `include_total=true`. Pagination is driven by [nextCursor] and [hasMore]; a cursor is
/// opaque and is passed back unchanged with the same filters.
@JsonSerializable(explicitToJson: true)
class UnifiedPropertyResponse {
  @JsonKey(required: true, disallowNullValue: true)
  final List<PropertyModel> items;
  @JsonKey(required: true, disallowNullValue: true)
  final int limit;
  @JsonKey(name: 'next_cursor', required: true)
  final String? nextCursor;
  @JsonKey(name: 'has_more', required: true, disallowNullValue: true)
  final bool hasMore;
  @JsonKey(required: true)
  final int? total;

  const UnifiedPropertyResponse({
    this.items = const [],
    this.limit = 20,
    this.nextCursor,
    this.hasMore = false,
    this.total,
  });

  factory UnifiedPropertyResponse.fromJson(Map<String, dynamic> json) =>
      _$UnifiedPropertyResponseFromJson(json);

  Map<String, dynamic> toJson() => _$UnifiedPropertyResponseToJson(this);

  /// True when another page can be fetched. Requires both the backend
  /// `has_more` flag and a non-null [nextCursor] token to be present.
  bool get hasMorePages => hasMore && (nextCursor?.isNotEmpty ?? false);

  bool get isEmpty => items.isEmpty;
  int get currentItemCount => items.length;
}
