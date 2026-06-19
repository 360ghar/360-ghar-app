// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'page_state_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PageStateSnapshot _$PageStateSnapshotFromJson(Map<String, dynamic> json) => PageStateSnapshot(
  pageType: json['pageType'] as String,
  selectedLocation: LocationData.tryFromJson(json['selectedLocation'] as Map<String, dynamic>?),
  locationSource: json['locationSource'] as String?,
  filters: UnifiedFilterModel.fromJson(json['filters'] as Map<String, dynamic>),
  searchQuery: json['searchQuery'] as String?,
  additionalData: json['additionalData'] as Map<String, dynamic>?,
  lastFetched: json['lastFetched'] == null ? null : DateTime.parse(json['lastFetched'] as String),
);

Map<String, dynamic> _$PageStateSnapshotToJson(PageStateSnapshot instance) => <String, dynamic>{
  'pageType': instance.pageType,
  'selectedLocation': instance.selectedLocation?.toJson(),
  'locationSource': instance.locationSource,
  'filters': instance.filters.toJson(),
  'searchQuery': instance.searchQuery,
  'additionalData': instance.additionalData,
  'lastFetched': instance.lastFetched?.toIso8601String(),
};

PageStateModel _$PageStateModelFromJson(Map<String, dynamic> json) => PageStateModel(
  pageType: $enumDecode(_$PageTypeEnumMap, json['pageType']),
  selectedLocation: LocationData.tryFromJson(json['selectedLocation'] as Map<String, dynamic>?),
  locationSource: json['locationSource'] as String?,
  filters: UnifiedFilterModel.fromJson(json['filters'] as Map<String, dynamic>),
  searchQuery: json['searchQuery'] as String?,
  properties: (json['properties'] as List<dynamic>)
      .map((e) => PropertyModel.fromJson(e as Map<String, dynamic>))
      .toList(),
  nextCursor: json['nextCursor'] as String?,
  hasMore: json['hasMore'] as bool? ?? true,
  isLoading: json['isLoading'] as bool? ?? false,
  isLoadingMore: json['isLoadingMore'] as bool? ?? false,
  isRefreshing: json['isRefreshing'] as bool? ?? false,
  lastFetched: json['lastFetched'] == null ? null : DateTime.parse(json['lastFetched'] as String),
  additionalData: json['additionalData'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$PageStateModelToJson(PageStateModel instance) => <String, dynamic>{
  'pageType': _$PageTypeEnumMap[instance.pageType]!,
  'selectedLocation': instance.selectedLocation?.toJson(),
  'locationSource': instance.locationSource,
  'filters': instance.filters.toJson(),
  'searchQuery': instance.searchQuery,
  'properties': instance.properties.map((e) => e.toJson()).toList(),
  'nextCursor': instance.nextCursor,
  'hasMore': instance.hasMore,
  'isLoading': instance.isLoading,
  'isLoadingMore': instance.isLoadingMore,
  'isRefreshing': instance.isRefreshing,
  'lastFetched': instance.lastFetched?.toIso8601String(),
  'additionalData': instance.additionalData,
};

const _$PageTypeEnumMap = {
  PageType.explore: 'explore',
  PageType.discover: 'discover',
  PageType.likes: 'likes',
};
