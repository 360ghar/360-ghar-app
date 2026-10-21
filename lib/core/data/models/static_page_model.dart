import 'package:ghar360/core/data/models/wire_enums.dart';
import 'package:json_annotation/json_annotation.dart';

export 'package:ghar360/core/data/models/wire_enums.dart' show PageFormat;

part 'static_page_model.g.dart';

/// `PagePublicResponse`: a public static page (policy, terms). `custom_config` and `view_count`
/// are not shown anywhere and are not read.
@JsonSerializable()
class StaticPageModel {
  const StaticPageModel({
    required this.title,
    required this.content,
    this.format,
    this.uniqueName,
    this.updatedAt,
  });

  factory StaticPageModel.fromJson(Map<String, dynamic> json) => _$StaticPageModelFromJson(json);

  @JsonKey(required: true)
  final String title;
  @JsonKey(required: true)
  final String content;

  /// How [content] is written. Null for a format this app does not know.
  @JsonKey(required: true)
  @PageFormatConverter()
  final PageFormat? format;
  @JsonKey(name: 'unique_name', required: true, disallowNullValue: true)
  final String? uniqueName;
  @JsonKey(name: 'updated_at', required: true)
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => _$StaticPageModelToJson(this);

  /// Only Markdown is rendered. The backend default format is `html`, and a page stored as
  /// `html` can still hold Markdown text, so an `html` page is rendered unless its content has
  /// tags. A `json` page, or a format this app does not know, is not rendered.
  bool get isRenderable => switch (format) {
    PageFormat.markdown => true,
    PageFormat.html => !RegExp(r'<\s*/?\s*[a-zA-Z][a-zA-Z0-9-]*(\s[^<>]*)?/?>').hasMatch(content),
    PageFormat.json || null => false,
  };
}
