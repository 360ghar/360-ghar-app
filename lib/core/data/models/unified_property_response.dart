import 'package:ghar360/core/data/models/property_model.dart';
import 'package:json_annotation/json_annotation.dart';

part 'unified_property_response.g.dart';

/// Uniform cursor-paginated response envelope returned by all list endpoints.
///
/// Shape: `{items: [...], next_cursor: "<base64>"|null, has_more: bool, limit: int}`.
/// The legacy `total`/`page`/`total_pages` fields are gone; pagination is
/// driven exclusively by [nextCursor] + [hasMore].
@JsonSerializable(explicitToJson: true)
class UnifiedPropertyResponse {
  final List<PropertyModel> items;
  final int limit;
  @JsonKey(name: 'next_cursor')
  final String? nextCursor;
  @JsonKey(name: 'has_more')
  final bool hasMore;
  @JsonKey(name: 'filters_applied')
  final Map<String, dynamic> filtersApplied;
  @JsonKey(name: 'search_center')
  final SearchCenter? searchCenter;

  const UnifiedPropertyResponse({
    this.items = const [],
    this.limit = 20,
    this.nextCursor,
    this.hasMore = false,
    this.filtersApplied = const <String, dynamic>{},
    this.searchCenter,
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

@JsonSerializable(explicitToJson: true)
class SearchCenter {
  final double latitude;
  final double longitude;

  const SearchCenter({required this.latitude, required this.longitude});

  factory SearchCenter.fromJson(Map<String, dynamic> json) => _$SearchCenterFromJson(json);

  Map<String, dynamic> toJson() => _$SearchCenterToJson(this);
}
