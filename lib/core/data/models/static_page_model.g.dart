// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'static_page_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StaticPageModel _$StaticPageModelFromJson(Map<String, dynamic> json) {
  $checkKeys(
    json,
    requiredKeys: const ['title', 'content', 'format', 'unique_name', 'updated_at'],
    disallowNullValues: const ['unique_name'],
  );
  return StaticPageModel(
    title: json['title'] as String,
    content: json['content'] as String,
    format: json['format'] == null
        ? PageFormat.markdown
        : const PageFormatConverter().fromJson(json['format']),
    uniqueName: json['unique_name'] as String?,
    updatedAt: json['updated_at'] == null ? null : DateTime.parse(json['updated_at'] as String),
  );
}

Map<String, dynamic> _$StaticPageModelToJson(StaticPageModel instance) => <String, dynamic>{
  'title': instance.title,
  'content': instance.content,
  'format': const PageFormatConverter().toJson(instance.format),
  'unique_name': ?instance.uniqueName,
  'updated_at': instance.updatedAt?.toIso8601String(),
};
