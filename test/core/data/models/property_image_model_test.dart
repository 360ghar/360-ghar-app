import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/data/models/property_image_model.dart';

void main() {
  group('PropertyImageModel.fromJson', () {
    test('parses full JSON correctly', () {
      final json = <String, dynamic>{
        'id': 1,
        'property_id': 42,
        'image_url': 'https://example.com/image.jpg',
        'caption': 'Front view',
        'display_order': 3,
        'is_main_image': true,
        'image_category': 'floor_plan',
      };

      final model = PropertyImageModel.fromJson(json);

      expect(model.id, 1);
      expect(model.propertyId, 42);
      expect(model.imageUrl, 'https://example.com/image.jpg');
      expect(model.caption, 'Front view');
      expect(model.displayOrder, 3);
      expect(model.isMainImage, true);
      expect(model.category, ImageCategory.floorPlan);
    });

    test('the keys the backend defaults read as its defaults', () {
      final json = <String, dynamic>{
        'id': 2,
        'property_id': 10,
        'image_url': 'https://example.com/2.jpg',
      };

      final model = PropertyImageModel.fromJson(json);

      expect(model.caption, isNull);
      expect(model.displayOrder, 0, reason: 'display_order defaults to 0');
      expect(model.isMainImage, false, reason: 'is_main_image defaults to false');
      expect(model.category, ImageCategory.others, reason: 'image_category defaults to others');
    });

    test('id, property_id and image_url are required', () {
      for (final key in ['id', 'property_id', 'image_url']) {
        final body = <String, dynamic>{'id': 2, 'property_id': 10, 'image_url': 'u'}..remove(key);
        expect(() => PropertyImageModel.fromJson(body), throwsA(anything), reason: key);
      }
    });

    test('an unknown category reads as null, so the photo is not a floor plan', () {
      final model = PropertyImageModel.fromJson({
        'id': 2,
        'property_id': 10,
        'image_url': 'u',
        'image_category': 'drone',
      });

      expect(model.category, isNull);
      expect(model.isFloorPlan, isFalse);
      expect(model.isGallery, isTrue);
    });
  });

  group('PropertyImageModel.empty', () {
    test('creates a placeholder with id -1 and empty url', () {
      final model = PropertyImageModel.empty();

      expect(model.id, -1);
      expect(model.propertyId, -1);
      expect(model.imageUrl, '');
      expect(model.isValid, false, reason: 'empty url is not valid');
    });

    test('accepts a custom propertyId', () {
      final model = PropertyImageModel.empty(propertyId: 99);

      expect(model.id, -1);
      expect(model.propertyId, 99);
      expect(model.imageUrl, '');
    });
  });

  group('PropertyImageModel convenience getters', () {
    PropertyImageModel make({
      String imageUrl = 'https://example.com/image.jpg',
      bool isMainImage = false,
      ImageCategory? category = ImageCategory.others,
    }) {
      return PropertyImageModel(
        id: 1,
        propertyId: 1,
        imageUrl: imageUrl,
        isMainImage: isMainImage,
        category: category,
      );
    }

    test('isValid is true when imageUrl is non-empty', () {
      expect(make(imageUrl: 'https://example.com/i.jpg').isValid, true);
      expect(make(imageUrl: '').isValid, false);
    });

    test('isPrimary follows is_main_image', () {
      expect(make().isPrimary, false);
      expect(make(isMainImage: true).isPrimary, true);
    });

    test('only floor_plan leaves the gallery', () {
      for (final room in [
        ImageCategory.room,
        ImageCategory.hall,
        ImageCategory.kitchen,
        ImageCategory.bathroom,
        ImageCategory.others,
      ]) {
        expect(make(category: room).isGallery, true, reason: room.wire);
        expect(make(category: room).isFloorPlan, false, reason: room.wire);
      }
      expect(make(category: ImageCategory.floorPlan).isFloorPlan, true);
      expect(make(category: ImageCategory.floorPlan).isGallery, false);
    });

    test('thumbnailUrl appends params for cloudinary URLs', () {
      final model = make(imageUrl: 'https://res.cloudinary.com/demo/image/upload/v1/photo.jpg');
      final thumb = model.thumbnailUrl;

      final uri = Uri.parse(thumb);
      expect(uri.host, 'res.cloudinary.com');
      expect(uri.queryParameters['w'], '300');
      expect(uri.queryParameters['h'], '200');
      expect(uri.queryParameters['fit'], 'crop');
    });

    test('thumbnailUrl appends params for imgur URLs', () {
      final model = make(imageUrl: 'https://i.imgur.com/abc.png');
      final thumb = model.thumbnailUrl;

      final uri = Uri.parse(thumb);
      expect(uri.host, 'i.imgur.com');
      expect(uri.queryParameters['w'], '300');
      expect(uri.queryParameters['h'], '200');
      expect(uri.queryParameters['fit'], 'crop');
    });

    test('thumbnailUrl preserves existing query params on CDN URLs', () {
      final model = make(
        imageUrl: 'https://res.cloudinary.com/demo/image/upload/w_500/v1/photo.jpg',
      );
      final thumb = model.thumbnailUrl;
      final uri = Uri.parse(thumb);

      expect(uri.queryParameters['w'], '300', reason: 'new w param overrides existing');
      expect(uri.queryParameters['h'], '200');
      expect(uri.queryParameters['fit'], 'crop');
    });

    test('thumbnailUrl returns as-is for non-CDN URLs', () {
      final model = make(imageUrl: 'https://example.com/image.jpg');
      expect(model.thumbnailUrl, 'https://example.com/image.jpg');
    });

    test('fullSizeUrl appends larger params for cloudinary URLs', () {
      final model = make(imageUrl: 'https://res.cloudinary.com/demo/image/upload/v1/photo.jpg');
      final full = model.fullSizeUrl;
      final uri = Uri.parse(full);

      expect(uri.queryParameters['w'], '1200');
      expect(uri.queryParameters['h'], '800');
      expect(uri.queryParameters['fit'], 'crop');
    });

    test('fullSizeUrl returns as-is for non-CDN URLs', () {
      final model = make(imageUrl: 'https://example.com/image.jpg');
      expect(model.fullSizeUrl, 'https://example.com/image.jpg');
    });
  });

  group('PropertyImageModel.toJson roundtrip', () {
    test('roundtrip preserves all fields and writes image_category', () {
      final original = const PropertyImageModel(
        id: 5,
        propertyId: 50,
        imageUrl: 'https://example.com/roundtrip.jpg',
        caption: 'Roundtrip caption',
        displayOrder: 7,
        isMainImage: true,
        category: ImageCategory.kitchen,
      );

      final json = original.toJson();
      expect(json['image_category'], 'kitchen');
      final restored = PropertyImageModel.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.propertyId, original.propertyId);
      expect(restored.imageUrl, original.imageUrl);
      expect(restored.caption, original.caption);
      expect(restored.displayOrder, original.displayOrder);
      expect(restored.isMainImage, original.isMainImage);
      expect(restored.category, original.category);
    });

    test('toJson includes caption as null when not set', () {
      final model = const PropertyImageModel(id: 1, propertyId: 1, imageUrl: 'url');
      final json = model.toJson();

      expect(json.containsKey('caption'), true);
      expect(json['caption'], isNull);
    });
  });
}
