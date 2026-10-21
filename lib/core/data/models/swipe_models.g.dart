// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'swipe_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SwipeOut _$SwipeOutFromJson(Map<String, dynamic> json) {
  $checkKeys(json, requiredKeys: const ['id', 'property_id', 'is_liked']);
  return SwipeOut(
    id: (json['id'] as num).toInt(),
    propertyId: (json['property_id'] as num).toInt(),
    isLiked: json['is_liked'] as bool,
  );
}

Map<String, dynamic> _$SwipeOutToJson(SwipeOut instance) => <String, dynamic>{
  'id': instance.id,
  'property_id': instance.propertyId,
  'is_liked': instance.isLiked,
};
