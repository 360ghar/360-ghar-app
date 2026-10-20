// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'unified_filter_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UnifiedFilterModel _$UnifiedFilterModelFromJson(Map<String, dynamic> json) => UnifiedFilterModel(
  radiusKm: (json['radius_km'] as num?)?.toDouble(),
  purpose: json['purpose'] as String?,
  propertyType: (json['property_type'] as List<dynamic>?)?.map((e) => e as String).toList(),
  priceMin: (json['price_min'] as num?)?.toDouble(),
  priceMax: (json['price_max'] as num?)?.toDouble(),
  bedroomsMin: (json['bedrooms_min'] as num?)?.toInt(),
  bedroomsMax: (json['bedrooms_max'] as num?)?.toInt(),
  bathroomsMin: (json['bathrooms_min'] as num?)?.toInt(),
  bathroomsMax: (json['bathrooms_max'] as num?)?.toInt(),
  areaMin: (json['area_min'] as num?)?.toDouble(),
  areaMax: (json['area_max'] as num?)?.toDouble(),
  parkingSpacesMin: (json['parking_spaces_min'] as num?)?.toInt(),
  floorNumberMin: (json['floor_number_min'] as num?)?.toInt(),
  floorNumberMax: (json['floor_number_max'] as num?)?.toInt(),
  ageMax: (json['age_max'] as num?)?.toInt(),
  amenities: (json['amenities'] as List<dynamic>?)?.map((e) => e as String).toList(),
  features: (json['features'] as List<dynamic>?)?.map((e) => e as String).toList(),
  genderPreference: json['gender_preference'] as String?,
  sharingType: json['sharing_type'] as String?,
  availableFrom: json['available_from'] == null
      ? null
      : DateTime.parse(json['available_from'] as String),
  checkInDate: json['check_in_date'] == null
      ? null
      : DateTime.parse(json['check_in_date'] as String),
  checkOutDate: json['check_out_date'] == null
      ? null
      : DateTime.parse(json['check_out_date'] as String),
  guests: (json['guests'] as num?)?.toInt(),
  sortBy: const SortByConverter().fromJson(json['sort_by']),
  searchQuery: json['search_query'] as String?,
  includeUnavailable: json['include_unavailable'] as bool?,
  propertyIds: (json['property_ids'] as List<dynamic>?)?.map((e) => (e as num).toInt()).toList(),
);

Map<String, dynamic> _$UnifiedFilterModelToJson(UnifiedFilterModel instance) => <String, dynamic>{
  'radius_km': instance.radiusKm,
  'purpose': instance.purpose,
  'property_type': instance.propertyType,
  'price_min': instance.priceMin,
  'price_max': instance.priceMax,
  'bedrooms_min': instance.bedroomsMin,
  'bedrooms_max': instance.bedroomsMax,
  'bathrooms_min': instance.bathroomsMin,
  'bathrooms_max': instance.bathroomsMax,
  'area_min': instance.areaMin,
  'area_max': instance.areaMax,
  'parking_spaces_min': instance.parkingSpacesMin,
  'floor_number_min': instance.floorNumberMin,
  'floor_number_max': instance.floorNumberMax,
  'age_max': instance.ageMax,
  'amenities': instance.amenities,
  'features': instance.features,
  'gender_preference': instance.genderPreference,
  'sharing_type': instance.sharingType,
  'available_from': instance.availableFrom?.toIso8601String(),
  'check_in_date': instance.checkInDate?.toIso8601String(),
  'check_out_date': instance.checkOutDate?.toIso8601String(),
  'guests': instance.guests,
  'sort_by': const SortByConverter().toJson(instance.sortBy),
  'search_query': instance.searchQuery,
  'include_unavailable': instance.includeUnavailable,
  'property_ids': instance.propertyIds,
};
