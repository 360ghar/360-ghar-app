// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'property_image_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PropertyImageModel _$PropertyImageModelFromJson(Map<String, dynamic> json) {
  $checkKeys(json, requiredKeys: const ['id', 'property_id', 'image_url']);
  return PropertyImageModel(
    id: (json['id'] as num).toInt(),
    propertyId: (json['property_id'] as num).toInt(),
    imageUrl: json['image_url'] as String,
    caption: json['caption'] as String?,
    displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
    isMainImage: json['is_main_image'] as bool? ?? false,
    category: json['image_category'] == null
        ? ImageCategory.others
        : const ImageCategoryConverter().fromJson(json['image_category']),
  );
}

Map<String, dynamic> _$PropertyImageModelToJson(PropertyImageModel instance) => <String, dynamic>{
  'id': instance.id,
  'property_id': instance.propertyId,
  'image_url': instance.imageUrl,
  'caption': instance.caption,
  'display_order': instance.displayOrder,
  'is_main_image': instance.isMainImage,
  'image_category': const ImageCategoryConverter().toJson(instance.category),
};
