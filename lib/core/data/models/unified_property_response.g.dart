// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'unified_property_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UnifiedPropertyResponse _$UnifiedPropertyResponseFromJson(Map<String, dynamic> json) {
  $checkKeys(json, requiredKeys: const ['items', 'limit', 'next_cursor', 'has_more', 'total']);
  return UnifiedPropertyResponse(
    items:
        (json['items'] as List<dynamic>?)
            ?.map((e) => PropertyModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    limit: (json['limit'] as num?)?.toInt() ?? 20,
    nextCursor: json['next_cursor'] as String?,
    hasMore: json['has_more'] as bool? ?? false,
    total: (json['total'] as num?)?.toInt(),
  );
}

Map<String, dynamic> _$UnifiedPropertyResponseToJson(UnifiedPropertyResponse instance) =>
    <String, dynamic>{
      'items': instance.items.map((e) => e.toJson()).toList(),
      'limit': instance.limit,
      'next_cursor': instance.nextCursor,
      'has_more': instance.hasMore,
      'total': instance.total,
    };
