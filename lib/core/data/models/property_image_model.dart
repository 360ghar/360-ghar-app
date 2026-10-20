import 'package:json_annotation/json_annotation.dart';

import 'package:ghar360/core/data/models/wire_enums.dart';

export 'package:ghar360/core/data/models/wire_enums.dart' show ImageCategory;

part 'property_image_model.g.dart';

/// `PropertyImage`. Photos arrive in `Property.images`. Floor plans arrive in
/// `Property.floor_plans`, never in `images`.
@JsonSerializable()
class PropertyImageModel {
  @JsonKey(required: true)
  final int id;
  @JsonKey(name: 'property_id', required: true)
  final int propertyId;
  @JsonKey(name: 'image_url', required: true)
  final String imageUrl;
  final String? caption;
  @JsonKey(name: 'display_order')
  final int displayOrder;
  @JsonKey(name: 'is_main_image')
  final bool isMainImage;

  /// A room name, `others` or `floor_plan`. The backend defaults it to `others`. Null for a value
  /// this app does not know.
  @JsonKey(name: 'image_category')
  @ImageCategoryConverter()
  final ImageCategory? category;

  const PropertyImageModel({
    required this.id,
    required this.propertyId,
    required this.imageUrl,
    this.caption,
    this.displayOrder = 0,
    this.isMainImage = false,
    this.category = ImageCategory.others,
  });

  factory PropertyImageModel.fromJson(Map<String, dynamic> json) =>
      _$PropertyImageModelFromJson(json);

  Map<String, dynamic> toJson() => _$PropertyImageModelToJson(this);

  /// Create an empty placeholder for properties with no image data.
  factory PropertyImageModel.empty({int propertyId = -1}) =>
      PropertyImageModel(id: -1, propertyId: propertyId, imageUrl: '');

  // Helper methods
  bool get isValid => imageUrl.isNotEmpty;

  bool get isPrimary => isMainImage;

  bool get isFloorPlan => category == ImageCategory.floorPlan;

  /// Every photo that is not a floor plan belongs in the gallery.
  bool get isGallery => !isFloorPlan;

  String get thumbnailUrl {
    // If using a CDN, can append thumbnail parameters
    if (imageUrl.contains('cloudinary.com') || imageUrl.contains('imgur.com')) {
      final uri = Uri.parse(imageUrl);
      final newParams = {'w': '300', 'h': '200', 'fit': 'crop'};
      final mergedParams = {...uri.queryParameters, ...newParams};
      return uri.replace(queryParameters: mergedParams).toString();
    }
    return imageUrl;
  }

  String get fullSizeUrl {
    // If using a CDN, can append full size parameters
    if (imageUrl.contains('cloudinary.com') || imageUrl.contains('imgur.com')) {
      final uri = Uri.parse(imageUrl);
      final newParams = {'w': '1200', 'h': '800', 'fit': 'crop'};
      final mergedParams = {...uri.queryParameters, ...newParams};
      return uri.replace(queryParameters: mergedParams).toString();
    }
    return imageUrl;
  }
}
