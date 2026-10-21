import 'package:json_annotation/json_annotation.dart';

part 'swipe_models.g.dart';

/// `SwipeOut`: one property swipe, returned by `POST /swipes` (201 for a new swipe, 200 for an
/// update) and `PUT /swipes/{id}/toggle`. `id` is the swipe row.
@JsonSerializable()
class SwipeOut {
  const SwipeOut({required this.id, required this.propertyId, required this.isLiked});

  factory SwipeOut.fromJson(Map<String, dynamic> json) => _$SwipeOutFromJson(json);

  @JsonKey(required: true)
  final int id;
  @JsonKey(name: 'property_id', required: true)
  final int propertyId;
  @JsonKey(name: 'is_liked', required: true)
  final bool isLiked;

  Map<String, dynamic> toJson() => _$SwipeOutToJson(this);
}
