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
        'is_main': false,
        'category': 'floor_plan',
      };

      final model = PropertyImageModel.fromJson(json);

      expect(model.id, 1);
      expect(model.propertyId, 42);
      expect(model.imageUrl, 'https://example.com/image.jpg');
      expect(model.caption, 'Front view');
      expect(model.displayOrder, 3);
      expect(model.isMainImage, true);
      expect(model.isMain, false);
      expect(model.category, 'floor_plan');
    });

    test('applies defaults for missing optional fields', () {
      final json = <String, dynamic>{
        'id': 2,
        'property_id': 10,
      };

      final model = PropertyImageModel.fromJson(json);

      expect(model.imageUrl, '', reason: 'image_url defaults to empty string');
      expect(model.caption, isNull);
      expect(model.displayOrder, 0, reason: 'display_order defaults to 0');
      expect(model.isMainImage, false, reason: 'is_main_image defaults to false');
      expect(model.isMain, false, reason: 'is_main defaults to false');
      expect(model.category, 'gallery', reason: 'category defaults to gallery');
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
      bool isMain = false,
      String category = 'gallery',
    }) {
      return PropertyImageModel(
        id: 1,
        propertyId: 1,
        imageUrl: imageUrl,
        isMainImage: isMainImage,
        isMain: isMain,
        category: category,
      );
    }

    test('isValid is true when imageUrl is non-empty', () {
      expect(make(imageUrl: 'https://example.com/i.jpg').isValid, true);
      expect(make(imageUrl: '').isValid, false);
    });

    test('isPrimary is true when isMain or isMainImage is true', () {
      expect(make(isMain: false, isMainImage: false).isPrimary, false);
      expect(make(isMain: true, isMainImage: false).isPrimary, true);
      expect(make(isMain: false, isMainImage: true).isPrimary, true);
      expect(make(isMain: true, isMainImage: true).isPrimary, true);
    });

    test('resolvedCategory falls back to gallery when empty', () {
      expect(make(category: 'floor_plan').resolvedCategory, 'floor_plan');
      expect(make(category: 'gallery').resolvedCategory, 'gallery');
      expect(make(category: '').resolvedCategory, 'gallery');
    });

    test('isGallery is true for gallery or photo categories', () {
      expect(make(category: 'gallery').isGallery, true);
      expect(make(category: 'photo').isGallery, true);
      expect(make(category: 'floor_plan').isGallery, false);
      expect(make(category: '').isGallery, true, reason: 'empty resolves to gallery');
    });

    test('isFloorPlan is true only for floor_plan category', () {
      expect(make(category: 'floor_plan').isFloorPlan, true);
      expect(make(category: 'gallery').isFloorPlan, false);
      expect(make(category: '').isFloorPlan, false);
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

  group('PropertyImageModel.toApiJson', () {
    test('syncs is_main and is_main_image flags', () {
      final model = PropertyImageModel(
        id: 1,
        propertyId: 1,
        imageUrl: 'https://example.com/i.jpg',
        isMainImage: true,
        isMain: false,
        category: 'floor_plan',
      );

      final api = model.toApiJson();

      expect(api['is_main'], true, reason: 'is_main synced to isMain || isMainImage');
      expect(api['is_main_image'], true, reason: 'is_main_image synced to isMainImage || isMain');
      expect(api['category'], 'floor_plan');
    });

    test('syncs both flags true when only isMain is true', () {
      final model = PropertyImageModel(
        id: 1,
        propertyId: 1,
        imageUrl: 'https://example.com/i.jpg',
        isMainImage: false,
        isMain: true,
      );

      final api = model.toApiJson();

      expect(api['is_main'], true);
      expect(api['is_main_image'], true);
    });

    test('defaults empty category to gallery', () {
      final model = PropertyImageModel(
        id: 1,
        propertyId: 1,
        imageUrl: 'https://example.com/i.jpg',
        category: '',
      );

      final api = model.toApiJson();

      expect(api['category'], 'gallery');
    });
  });

  group('PropertyImageModel.toJson roundtrip', () {
    test('roundtrip preserves all fields', () {
      final original = PropertyImageModel(
        id: 5,
        propertyId: 50,
        imageUrl: 'https://example.com/roundtrip.jpg',
        caption: 'Roundtrip caption',
        displayOrder: 7,
        isMainImage: true,
        isMain: true,
        category: 'photo',
      );

      final json = original.toJson();
      final restored = PropertyImageModel.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.propertyId, original.propertyId);
      expect(restored.imageUrl, original.imageUrl);
      expect(restored.caption, original.caption);
      expect(restored.displayOrder, original.displayOrder);
      expect(restored.isMainImage, original.isMainImage);
      expect(restored.isMain, original.isMain);
      expect(restored.category, original.category);
    });

    test('toJson includes caption as null when not set', () {
      final model = PropertyImageModel(id: 1, propertyId: 1, imageUrl: 'url');
      final json = model.toJson();

      expect(json.containsKey('caption'), true);
      expect(json['caption'], isNull);
    });
  });
}
