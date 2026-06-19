// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'unified_property_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UnifiedPropertyResponse _$UnifiedPropertyResponseFromJson(Map<String, dynamic> json) =>
    UnifiedPropertyResponse(
      items:
          (json['items'] as List<dynamic>?)
              ?.map((e) => PropertyModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      limit: (json['limit'] as num?)?.toInt() ?? 20,
      nextCursor: json['next_cursor'] as String?,
      hasMore: json['has_more'] as bool? ?? false,
      filtersApplied: json['filters_applied'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      searchCenter: json['search_center'] == null
          ? null
          : SearchCenter.fromJson(json['search_center'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$UnifiedPropertyResponseToJson(UnifiedPropertyResponse instance) =>
    <String, dynamic>{
      'items': instance.items.map((e) => e.toJson()).toList(),
      'limit': instance.limit,
      'next_cursor': instance.nextCursor,
      'has_more': instance.hasMore,
      'filters_applied': instance.filtersApplied,
      'search_center': instance.searchCenter?.toJson(),
    };

SearchCenter _$SearchCenterFromJson(Map<String, dynamic> json) => SearchCenter(
  latitude: (json['latitude'] as num).toDouble(),
  longitude: (json['longitude'] as num).toDouble(),
);

Map<String, dynamic> _$SearchCenterToJson(SearchCenter instance) => <String, dynamic>{
  'latitude': instance.latitude,
  'longitude': instance.longitude,
};
