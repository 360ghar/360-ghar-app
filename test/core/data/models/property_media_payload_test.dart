import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/data/models/property_image_model.dart';
import 'package:ghar360/core/data/models/property_media_payload.dart';

void main() {
  group('PropertyMediaPayload.fromJson', () {
    test('parses full JSON correctly', () {
      final json = <String, dynamic>{
        'main_image_url': 'https://example.com/main.jpg',
        'images': [
          {'id': 1, 'property_id': 10, 'image_url': 'https://example.com/1.jpg'},
          {'id': 2, 'property_id': 10, 'image_url': 'https://example.com/2.jpg'},
        ],
        'video_tour_url': 'https://example.com/tour.mp4',
        'video_urls': ['https://example.com/v1.mp4', 'https://example.com/v2.mp4'],
        'virtual_tour_url': 'https://example.com/virtual',
        'google_street_view_url': 'https://example.com/street',
        'floor_plan_url': 'https://example.com/floor.png',
      };

      final payload = PropertyMediaPayload.fromJson(json);

      expect(payload.mainImageUrl, 'https://example.com/main.jpg');
      expect(payload.images, isNotNull);
      expect(payload.images!.length, 2);
      expect(payload.images![0].id, 1);
      expect(payload.images![1].imageUrl, 'https://example.com/2.jpg');
      expect(payload.videoTourUrl, 'https://example.com/tour.mp4');
      expect(payload.videoUrls, ['https://example.com/v1.mp4', 'https://example.com/v2.mp4']);
      expect(payload.virtualTourUrl, 'https://example.com/virtual');
      expect(payload.googleStreetViewUrl, 'https://example.com/street');
      expect(payload.floorPlanUrl, 'https://example.com/floor.png');
    });

    test('parses empty JSON with all nulls', () {
      final payload = PropertyMediaPayload.fromJson({});

      expect(payload.mainImageUrl, isNull);
      expect(payload.images, isNull);
      expect(payload.videoTourUrl, isNull);
      expect(payload.videoUrls, isNull);
      expect(payload.virtualTourUrl, isNull);
      expect(payload.googleStreetViewUrl, isNull);
      expect(payload.floorPlanUrl, isNull);
    });
  });

  group('PropertyMediaPayload.toJson', () {
    test('excludes null fields due to includeIfNull false', () {
      const payload = PropertyMediaPayload();

      final json = payload.toJson();

      expect(json.containsKey('main_image_url'), false);
      expect(json.containsKey('images'), false);
      expect(json.containsKey('video_tour_url'), false);
      expect(json.containsKey('video_urls'), false);
      expect(json.containsKey('virtual_tour_url'), false);
      expect(json.containsKey('google_street_view_url'), false);
      expect(json.containsKey('floor_plan_url'), false);
    });

    test('includes non-null fields with snake_case keys', () {
      final payload = const PropertyMediaPayload(
        mainImageUrl: 'https://example.com/main.jpg',
        videoTourUrl: 'https://example.com/tour.mp4',
        videoUrls: ['https://example.com/v.mp4'],
        floorPlanUrl: 'https://example.com/floor.png',
      );

      final json = payload.toJson();

      expect(json['main_image_url'], 'https://example.com/main.jpg');
      expect(json['video_tour_url'], 'https://example.com/tour.mp4');
      expect(json['video_urls'], ['https://example.com/v.mp4']);
      expect(json['floor_plan_url'], 'https://example.com/floor.png');
      expect(json.containsKey('images'), false);
      expect(json.containsKey('virtual_tour_url'), false);
      expect(json.containsKey('google_street_view_url'), false);
    });

    test('serializes nested images via explicitToJson', () {
      final payload = const PropertyMediaPayload(
        images: [PropertyImageModel(id: 1, propertyId: 10, imageUrl: 'https://example.com/1.jpg')],
      );

      final json = payload.toJson();

      expect(json['images'], isA<List>());
      final images = json['images'] as List;
      expect(images.length, 1);
      expect(images[0], isA<Map<String, dynamic>>());
      expect((images[0] as Map<String, dynamic>)['image_url'], 'https://example.com/1.jpg');
    });
  });

  group('PropertyMediaPayload.toPropertyUpdateJson', () {
    test('removes the images key from the payload', () {
      final payload = const PropertyMediaPayload(
        mainImageUrl: 'https://example.com/main.jpg',
        images: [PropertyImageModel(id: 1, propertyId: 10, imageUrl: 'https://example.com/1.jpg')],
        videoTourUrl: 'https://example.com/tour.mp4',
      );

      final updateJson = payload.toPropertyUpdateJson();

      expect(updateJson.containsKey('images'), false, reason: 'images must be removed');
      expect(updateJson['main_image_url'], 'https://example.com/main.jpg');
      expect(updateJson['video_tour_url'], 'https://example.com/tour.mp4');
    });

    test('works when images is already null', () {
      const payload = PropertyMediaPayload(mainImageUrl: 'https://example.com/main.jpg');

      final updateJson = payload.toPropertyUpdateJson();

      expect(updateJson.containsKey('images'), false);
      expect(updateJson['main_image_url'], 'https://example.com/main.jpg');
    });
  });

  group('PropertyMediaPayload.copyWith', () {
    test('preserves unmodified fields', () {
      final original = const PropertyMediaPayload(
        mainImageUrl: 'https://example.com/main.jpg',
        images: [PropertyImageModel(id: 1, propertyId: 10, imageUrl: 'https://example.com/1.jpg')],
        videoTourUrl: 'https://example.com/tour.mp4',
        videoUrls: ['https://example.com/v.mp4'],
        virtualTourUrl: 'https://example.com/virtual',
        googleStreetViewUrl: 'https://example.com/street',
        floorPlanUrl: 'https://example.com/floor.png',
      );

      final copy = original.copyWith();

      expect(copy.mainImageUrl, original.mainImageUrl);
      expect(copy.images?.length, original.images?.length);
      expect(copy.images?[0].id, original.images![0].id);
      expect(copy.videoTourUrl, original.videoTourUrl);
      expect(copy.videoUrls, original.videoUrls);
      expect(copy.virtualTourUrl, original.virtualTourUrl);
      expect(copy.googleStreetViewUrl, original.googleStreetViewUrl);
      expect(copy.floorPlanUrl, original.floorPlanUrl);
    });

    test('updates only modified fields', () {
      final original = const PropertyMediaPayload(
        mainImageUrl: 'https://example.com/main.jpg',
        videoTourUrl: 'https://example.com/tour.mp4',
        floorPlanUrl: 'https://example.com/floor.png',
      );

      final copy = original.copyWith(
        mainImageUrl: 'https://example.com/new-main.jpg',
        videoUrls: ['https://example.com/new-v.mp4'],
      );

      expect(copy.mainImageUrl, 'https://example.com/new-main.jpg');
      expect(copy.videoUrls, ['https://example.com/new-v.mp4']);
      expect(copy.videoTourUrl, original.videoTourUrl, reason: 'unmodified field preserved');
      expect(copy.floorPlanUrl, original.floorPlanUrl, reason: 'unmodified field preserved');
    });
  });

  group('PropertyMediaPayload.toJson roundtrip', () {
    test('roundtrip preserves all fields', () {
      final original = const PropertyMediaPayload(
        mainImageUrl: 'https://example.com/main.jpg',
        images: [PropertyImageModel(id: 1, propertyId: 10, imageUrl: 'https://example.com/1.jpg')],
        videoTourUrl: 'https://example.com/tour.mp4',
        videoUrls: ['https://example.com/v1.mp4'],
        virtualTourUrl: 'https://example.com/virtual',
        googleStreetViewUrl: 'https://example.com/street',
        floorPlanUrl: 'https://example.com/floor.png',
      );

      final json = original.toJson();
      final restored = PropertyMediaPayload.fromJson(json);

      expect(restored.mainImageUrl, original.mainImageUrl);
      expect(restored.images?.length, original.images?.length);
      expect(restored.images?[0].id, original.images![0].id);
      expect(restored.images?[0].imageUrl, original.images![0].imageUrl);
      expect(restored.videoTourUrl, original.videoTourUrl);
      expect(restored.videoUrls, original.videoUrls);
      expect(restored.virtualTourUrl, original.virtualTourUrl);
      expect(restored.googleStreetViewUrl, original.googleStreetViewUrl);
      expect(restored.floorPlanUrl, original.floorPlanUrl);
    });
  });
}
