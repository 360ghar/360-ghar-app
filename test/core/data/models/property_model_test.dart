import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:ghar360/core/data/models/property_image_model.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/translations/app_translations.dart';

void main() {
  setUpAll(() {
    // Provide translations so `.tr` getters resolve to localized strings
    // during tests.
    Get.testMode = true;
    Get.addTranslations(AppTranslations().keys);
    Get.locale = const Locale('en', 'US');
  });

  group('PropertyModel.fromJson', () {
    test('parses minimal valid JSON with defaults', () {
      final json = <String, dynamic>{
        'id': 42,
        'title': 'Test Property',
        'base_price': 5000000.0,
        'is_active': true,
        'view_count': 10,
        'like_count': 5,
        'interest_count': 3,
      };

      final model = PropertyModel.fromJson(json);

      expect(model.id, 42);
      expect(model.title, 'Test Property');
      expect(model.basePrice, 5000000.0);
      expect(model.isAvailable, true);
      expect(model.viewCount, 10);
      expect(model.likeCount, 5);
      expect(model.country, 'India');
    });

    test('applies default values when fields are missing', () {
      final json = <String, dynamic>{};

      final model = PropertyModel.fromJson(json);

      expect(model.id, -1, reason: 'id should default to -1');
      expect(model.title, 'Unknown Property', reason: 'title should default to Unknown Property');
      expect(model.basePrice, 0.0, reason: 'base_price should default to 0.0');
      expect(model.isAvailable, true, reason: 'is_active should default to true');
      expect(model.viewCount, 0, reason: 'view_count should default to 0');
      expect(model.likeCount, 0, reason: 'like_count should default to 0');
      expect(model.liked, false, reason: 'liked should default to false');
    });

    test('parses property_type enum correctly', () {
      expect(PropertyModel.fromJson({'property_type': 'house'}).propertyType, PropertyType.house);
      expect(
        PropertyModel.fromJson({'property_type': 'apartment'}).propertyType,
        PropertyType.apartment,
      );
      expect(
        PropertyModel.fromJson({'property_type': 'builder_floor'}).propertyType,
        PropertyType.builderFloor,
      );
      expect(PropertyModel.fromJson({'property_type': 'villa'}).propertyType, PropertyType.villa);
      expect(PropertyModel.fromJson({'property_type': 'plot'}).propertyType, PropertyType.plot);
      expect(PropertyModel.fromJson({'property_type': 'condo'}).propertyType, PropertyType.condo);
      expect(
        PropertyModel.fromJson({'property_type': 'penthouse'}).propertyType,
        PropertyType.penthouse,
      );
      expect(PropertyModel.fromJson({'property_type': 'studio'}).propertyType, PropertyType.studio);
      expect(PropertyModel.fromJson({'property_type': 'loft'}).propertyType, PropertyType.loft);
      expect(PropertyModel.fromJson({'property_type': 'pg'}).propertyType, PropertyType.pg);
      expect(
        PropertyModel.fromJson({'property_type': 'flatmate'}).propertyType,
        PropertyType.flatmate,
      );
      expect(PropertyModel.fromJson({'property_type': 'office'}).propertyType, PropertyType.office);
      expect(PropertyModel.fromJson({'property_type': 'shop'}).propertyType, PropertyType.shop);
      expect(
        PropertyModel.fromJson({'property_type': 'warehouse'}).propertyType,
        PropertyType.warehouse,
      );
    });

    test('falls back to house for unknown property_type', () {
      final model = PropertyModel.fromJson({'property_type': 'spaceship'});
      expect(model.propertyType, PropertyType.house);
    });

    test('parses purpose enum correctly', () {
      expect(PropertyModel.fromJson({'purpose': 'buy'}).purpose, PropertyPurpose.buy);
      expect(PropertyModel.fromJson({'purpose': 'rent'}).purpose, PropertyPurpose.rent);
      expect(PropertyModel.fromJson({'purpose': 'short_stay'}).purpose, PropertyPurpose.shortStay);
    });

    test('falls back to buy for unknown purpose', () {
      final model = PropertyModel.fromJson({'purpose': 'barter'});
      expect(model.purpose, PropertyPurpose.buy);
    });

    test('parses location fields', () {
      final model = PropertyModel.fromJson({
        'latitude': 28.6139,
        'longitude': 77.2090,
        'city': 'New Delhi',
        'state': 'Delhi',
        'locality': 'Connaught Place',
        'sub_locality': 'Block A',
        'pincode': '110001',
      });

      expect(model.latitude, 28.6139);
      expect(model.longitude, 77.2090);
      expect(model.city, 'New Delhi');
      expect(model.locality, 'Connaught Place');
      expect(model.subLocality, 'Block A');
      expect(model.hasLocation, true);
    });

    test('normalizes is_available to is_active', () {
      final model = PropertyModel.fromJson({'is_available': false});
      expect(model.isAvailable, false);
    });

    test('parses amenities list', () {
      final model = PropertyModel.fromJson({
        'amenities': [
          {'id': 1, 'title': 'Swimming Pool'},
          {'id': 2, 'title': 'Gym', 'icon': 'http://example.com/gym.png'},
        ],
      });

      expect(model.amenities, isNotNull);
      expect(model.amenities!.length, 2);
      expect(model.amenities![0].title, 'Swimming Pool');
      expect(model.amenities![1].icon, 'http://example.com/gym.png');
    });

    test('parses listing preferences', () {
      final model = PropertyModel.fromJson({
        'listing_preferences': {'gender_preference': 'female', 'sharing_type': 'shared_room'},
      });

      expect(model.listingPreferences?.genderPreference, ListingGenderPreference.female);
      expect(model.listingPreferences?.sharingType, ListingSharingType.sharedRoom);
      expect(model.genderPreferenceTranslationKey, 'female_only');
      expect(model.sharingTypeTranslationKey, 'shared_room');
    });
  });

  group('PropertyModel helper getters', () {
    PropertyModel make({
      double basePrice = 0,
      PropertyPurpose? purpose,
      double? monthlyRent,
      double? dailyRate,
      double? areaSqft,
      int? bedrooms,
      int? bathrooms,
      int? floorNumber,
      int? totalFloors,
      int? ageOfProperty,
      double? distanceKm,
      String? city,
      String? locality,
      String? subLocality,
      double? latitude,
      double? longitude,
    }) {
      return PropertyModel(
        id: 1,
        title: 'Test',
        basePrice: basePrice,
        purpose: purpose,
        monthlyRent: monthlyRent,
        dailyRate: dailyRate,
        areaSqft: areaSqft,
        bedrooms: bedrooms,
        bathrooms: bathrooms,
        floorNumber: floorNumber,
        totalFloors: totalFloors,
        ageOfProperty: ageOfProperty,
        distanceKm: distanceKm,
        city: city,
        locality: locality,
        subLocality: subLocality,
        latitude: latitude,
        longitude: longitude,
        isAvailable: true,
        viewCount: 0,
        likeCount: 0,
        interestCount: 0,
      );
    }

    test('formattedPrice formats crore values', () {
      expect(make(basePrice: 25000000).formattedPrice, '₹2.5 Cr');
    });

    test('formattedPrice formats lakh values', () {
      expect(make(basePrice: 5000000).formattedPrice, '₹50.0 L');
    });

    test('formattedPrice formats small values', () {
      expect(make(basePrice: 50000).formattedPrice, '₹50000');
    });

    test('getEffectivePrice returns monthlyRent for rent', () {
      final model = make(basePrice: 100000, purpose: PropertyPurpose.rent, monthlyRent: 25000);
      expect(model.getEffectivePrice(), 25000);
    });

    test('getEffectivePrice falls back to basePrice for rent without monthlyRent', () {
      final model = make(basePrice: 100000, purpose: PropertyPurpose.rent);
      expect(model.getEffectivePrice(), 100000);
    });

    test('getEffectivePrice returns dailyRate for shortStay', () {
      final model = make(basePrice: 100000, purpose: PropertyPurpose.shortStay, dailyRate: 3000);
      expect(model.getEffectivePrice(), 3000);
    });

    test('areaText formats area correctly', () {
      expect(make(areaSqft: 1200).areaText, '1200 sq ft');
      expect(make().areaText, '');
    });

    test('floorText shows floor/total', () {
      expect(make(floorNumber: 3, totalFloors: 10).floorText, 'Floor 3/10');
      expect(make(floorNumber: 5).floorText, 'Floor 5');
      expect(make().floorText, '');
    });

    test('ageText handles new construction and years', () {
      expect(make(ageOfProperty: 0).ageText, 'New Construction');
      expect(make(ageOfProperty: 1).ageText, '1 year old');
      expect(make(ageOfProperty: 5).ageText, '5 years old');
      expect(make().ageText, '');
    });

    test('distanceText formats km and meters', () {
      expect(make(distanceKm: 2.5).distanceText, '2.5km away');
      expect(make(distanceKm: 0.3).distanceText, '300m away');
      expect(make().distanceText, '');
    });

    test('shortAddressDisplay builds from locality parts', () {
      expect(make(locality: 'Sector 62', city: 'Noida').shortAddressDisplay, 'Sector 62, Noida');
      expect(
        make(locality: 'Sector 62', subLocality: 'Block A', city: 'Noida').shortAddressDisplay,
        'Sector 62, Block A, Noida',
      );
      expect(make(city: 'Noida').shortAddressDisplay, 'Noida');
      expect(make().shortAddressDisplay, 'Unknown Location');
    });

    test('hasLocation requires both coordinates', () {
      expect(make(latitude: 28.0, longitude: 77.0).hasLocation, true);
      expect(make(latitude: 28.0).hasLocation, false);
      expect(make().hasLocation, false);
    });

    test('propertyTypeString maps all enum values', () {
      expect(
        PropertyModel.fromJson({'property_type': 'apartment'}).propertyTypeString,
        'property_type_apartment'.tr,
      );
      expect(
        PropertyModel.fromJson({'property_type': 'villa'}).propertyTypeString,
        'property_type_villa'.tr,
      );
      expect(
        PropertyModel.fromJson({'property_type': 'condo'}).propertyTypeString,
        'property_type_condo'.tr,
      );
      expect(
        PropertyModel.fromJson({'property_type': 'studio'}).propertyTypeString,
        'property_type_studio'.tr,
      );
      expect(
        PropertyModel.fromJson({'property_type': 'pg'}).propertyTypeString,
        'property_type_pg'.tr,
      );
      expect(
        PropertyModel.fromJson({'property_type': 'office'}).propertyTypeString,
        'property_type_office'.tr,
      );
      expect(PropertyModel.fromJson({}).propertyTypeString, 'property_type_default'.tr);
    });

    test('listingTranslationKey prioritizes pg and flatmate labels', () {
      expect(
        PropertyModel.fromJson({'property_type': 'pg', 'purpose': 'rent'}).listingTranslationKey,
        'pg',
      );
      expect(
        PropertyModel.fromJson({
          'property_type': 'flatmate',
          'purpose': 'rent',
        }).listingTranslationKey,
        'flatmate',
      );
      expect(
        PropertyModel.fromJson({
          'property_type': 'apartment',
          'purpose': 'short_stay',
        }).listingTranslationKey,
        'short_stay',
      );
    });

    test('formattedPrice handles very large values (100 Cr+)', () {
      expect(make(basePrice: 1000000000).formattedPrice, '₹100.0 Cr');
      expect(make(basePrice: 150000000).formattedPrice, '₹15.0 Cr');
    });

    test('formattedPrice handles zero price', () {
      expect(make(basePrice: 0).formattedPrice, '₹0');
    });

    test('formattedPrice handles negative price', () {
      // Negative values fall through to the small-value branch
      expect(make(basePrice: -1000).formattedPrice, '₹-1000');
      expect(make(basePrice: -5000000).formattedPrice, '₹-5000000');
    });

    test('virtualTourUrl and hasVirtualTour getters', () {
      final withTour = const PropertyModel(
        id: 1,
        title: 'Test',
        basePrice: 0,
        virtualTourUrl: 'https://kuula.co/share/abc123',
        isAvailable: true,
        viewCount: 0,
        likeCount: 0,
        interestCount: 0,
      );
      expect(withTour.virtualTourUrl, 'https://kuula.co/share/abc123');
      expect(withTour.hasVirtualTour, true);

      final emptyTour = const PropertyModel(
        id: 2,
        title: 'Test',
        basePrice: 0,
        virtualTourUrl: '',
        isAvailable: true,
        viewCount: 0,
        likeCount: 0,
        interestCount: 0,
      );
      expect(emptyTour.hasVirtualTour, false);

      final noTour = make();
      expect(noTour.hasVirtualTour, false);
    });

    test('wire value helpers use canonical backend tokens', () {
      expect(PropertyType.builderFloor.wireValue, 'builder_floor');
      expect(PropertyType.penthouse.wireValue, 'penthouse');
      expect(PropertyType.pg.wireValue, 'pg');
      expect(PropertyType.warehouse.wireValue, 'warehouse');
      expect(PropertyPurpose.shortStay.wireValue, 'short_stay');
    });

    test('shortAddressDisplay handles empty locality with subLocality', () {
      expect(make(subLocality: 'Block B', city: 'Gurgaon').shortAddressDisplay, 'Block B, Gurgaon');
    });

    test('shortAddressDisplay ignores empty strings in parts', () {
      expect(make(locality: '', city: 'Delhi').shortAddressDisplay, 'Delhi');
      expect(make(locality: '', subLocality: '', city: 'Delhi').shortAddressDisplay, 'Delhi');
    });

    test('bedroomBathroomText handles combinations', () {
      expect(make(bedrooms: 3, bathrooms: 2).bedroomBathroomText, '3BHK, 2 Bath');
      expect(make(bedrooms: 2).bedroomBathroomText, '2BHK');
      expect(make(bathrooms: 1).bedroomBathroomText, '1 Bath');
      expect(make().bedroomBathroomText, '');
    });
  });

  group('PropertyModel.toJson roundtrip', () {
    test('roundtrip preserves key fields', () {
      final original = PropertyModel.fromJson({
        'id': 10,
        'title': 'My Flat',
        'base_price': 4500000.0,
        'property_type': 'apartment',
        'purpose': 'rent',
        'bedrooms': 2,
        'bathrooms': 1,
        'is_active': true,
        'view_count': 7,
        'like_count': 3,
        'interest_count': 1,
      });

      final json = original.toJson();
      final restored = PropertyModel.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.basePrice, original.basePrice);
      expect(restored.propertyType, original.propertyType);
      expect(restored.purpose, original.purpose);
      expect(restored.bedrooms, original.bedrooms);
    });
  });

  group('PropertyModel image and media getters', () {
    PropertyModel make({
      String? mainImageUrl,
      List<PropertyImageModel>? images,
      String? videoTourUrl,
      List<String>? videoUrls,
      String? virtualTourUrl,
      String? googleStreetViewUrl,
      String? floorPlanUrl,
      double? latitude,
      double? longitude,
    }) {
      return PropertyModel(
        id: 1,
        title: 'Test',
        basePrice: 0,
        mainImageUrl: mainImageUrl,
        images: images,
        videoTourUrl: videoTourUrl,
        videoUrls: videoUrls,
        virtualTourUrl: virtualTourUrl,
        googleStreetViewUrl: googleStreetViewUrl,
        floorPlanUrl: floorPlanUrl,
        latitude: latitude,
        longitude: longitude,
        isAvailable: true,
        viewCount: 0,
        likeCount: 0,
        interestCount: 0,
      );
    }

    PropertyImageModel img(String url,
        {bool isMain = false, bool isMainImage = false, int order = 0, String category = 'gallery'}) {
      return PropertyImageModel(
        id: order,
        propertyId: 1,
        imageUrl: url,
        isMain: isMain,
        isMainImage: isMainImage,
        displayOrder: order,
        category: category,
      );
    }

    test('mainImage returns mainImageUrl when set', () {
      final model = make(mainImageUrl: 'https://example.com/main.jpg');
      expect(model.mainImage, 'https://example.com/main.jpg');
    });

    test('mainImage returns primary image from list when mainImageUrl is null', () {
      final model = make(images: [
        img('https://example.com/secondary.jpg', order: 0),
        img('https://example.com/primary.jpg', isMain: true, order: 1),
      ]);
      expect(model.mainImage, 'https://example.com/primary.jpg');
    });

    test('mainImage returns first image when no primary and mainImageUrl is null', () {
      final model = make(images: [
        img('https://example.com/first.jpg', order: 0),
      ]);
      expect(model.mainImage, 'https://example.com/first.jpg');
    });

    test('mainImage returns empty string when no images and no mainImageUrl', () {
      final model = make();
      expect(model.mainImage, '');
    });

    test('imageUrls combines mainImageUrl and image list', () {
      final model = make(
        mainImageUrl: 'https://example.com/main.jpg',
        images: [img('https://example.com/1.jpg', order: 0)],
        floorPlanUrl: 'https://example.com/floor.jpg',
      );
      final urls = model.imageUrls;
      expect(urls, contains('https://example.com/main.jpg'));
      expect(urls, contains('https://example.com/1.jpg'));
      expect(urls, contains('https://example.com/floor.jpg'));
    });

    test('imageUrls deduplicates', () {
      final model = make(
        mainImageUrl: 'https://example.com/dup.jpg',
        images: [img('https://example.com/dup.jpg', order: 0)],
      );
      expect(model.imageUrls.where((u) => u == 'https://example.com/dup.jpg').length, 1);
    });

    test('galleryImages filters by category and image extension', () {
      final model = make(images: [
        img('https://example.com/photo1.jpg', order: 0, category: 'gallery'),
        img('https://example.com/floor.jpg', order: 1, category: 'floor_plan'),
        img('https://kuula.co/share/abc', order: 2, category: 'gallery'),
      ]);
      final gallery = model.galleryImages;
      expect(gallery, hasLength(1));
      expect(gallery[0].imageUrl, 'https://example.com/photo1.jpg');
    });

    test('galleryImageUrls falls back to mainImageUrl when no gallery images', () {
      final model = make(mainImageUrl: 'https://example.com/main.jpg');
      expect(model.galleryImageUrls, ['https://example.com/main.jpg']);
    });

    test('floorPlanImages filters by floor_plan category', () {
      final model = make(images: [
        img('https://example.com/photo.jpg', order: 0, category: 'gallery'),
        img('https://example.com/plan.jpg', order: 1, category: 'floor_plan'),
      ]);
      final plans = model.floorPlanImages;
      expect(plans, hasLength(1));
      expect(plans[0].imageUrl, 'https://example.com/plan.jpg');
    });

    test('floorPlanImageUrls includes floorPlanUrl and floor plan images', () {
      final model = make(
        floorPlanUrl: 'https://example.com/external_plan.jpg',
        images: [img('https://example.com/plan.jpg', order: 0, category: 'floor_plan')],
      );
      final urls = model.floorPlanImageUrls;
      expect(urls, hasLength(2));
      expect(urls, contains('https://example.com/external_plan.jpg'));
      expect(urls, contains('https://example.com/plan.jpg'));
    });

    test('mediaVideoUrls combines videoTourUrl and videoUrls', () {
      final model = make(
        videoTourUrl: 'https://example.com/tour.mp4',
        videoUrls: ['https://example.com/video1.mp4', 'https://example.com/video2.mp4'],
      );
      final urls = model.mediaVideoUrls;
      expect(urls, hasLength(3));
      expect(urls, contains('https://example.com/tour.mp4'));
    });

    test('mediaVideoUrls filters empty strings', () {
      final model = make(
        videoTourUrl: '',
        videoUrls: ['', 'https://example.com/video.mp4'],
      );
      expect(model.mediaVideoUrls, ['https://example.com/video.mp4']);
    });

    test('primaryVideoUrl returns first media video URL', () {
      final model = make(videoTourUrl: 'https://example.com/tour.mp4');
      expect(model.primaryVideoUrl, 'https://example.com/tour.mp4');
    });

    test('primaryVideoUrl returns null when no videos', () {
      final model = make();
      expect(model.primaryVideoUrl, isNull);
    });

    test('hasVideos is true when video URLs exist', () {
      expect(make(videoTourUrl: 'https://example.com/tour.mp4').hasVideos, true);
      expect(make().hasVideos, false);
    });

    test('hasVideoTour is true when primaryVideoUrl is not null', () {
      expect(make(videoTourUrl: 'https://example.com/tour.mp4').hasVideoTour, true);
      expect(make().hasVideoTour, false);
    });

    test('hasPhotos is true when galleryImageUrls is not empty', () {
      expect(make(mainImageUrl: 'https://example.com/main.jpg').hasPhotos, true);
      expect(make().hasPhotos, false);
    });

    test('hasFloorPlan is true when floorPlanImageUrls is not empty', () {
      expect(make(floorPlanUrl: 'https://example.com/plan.jpg').hasFloorPlan, true);
      expect(make().hasFloorPlan, false);
    });

    test('hasAnyMedia is true when any media exists', () {
      expect(make(virtualTourUrl: 'https://kuula.co/share/abc').hasAnyMedia, true);
      expect(make(mainImageUrl: 'https://example.com/main.jpg').hasAnyMedia, true);
      expect(make(videoTourUrl: 'https://example.com/tour.mp4').hasAnyMedia, true);
      expect(make(floorPlanUrl: 'https://example.com/plan.jpg').hasAnyMedia, true);
      expect(make().hasAnyMedia, false);
    });

    test('_looksLikeImageUrl filters kuula.co share links', () {
      final model = make(images: [
        img('https://kuula.co/share/abc', order: 0, category: 'gallery'),
      ]);
      expect(model.galleryImages, isEmpty);
    });
  });

  group('PropertyModel street view getters', () {
    test('hasStreetView is true when googleStreetViewUrl is set', () {
      const model = PropertyModel(
        id: 1,
        title: 'Test',
        basePrice: 0,
        googleStreetViewUrl: 'https://maps.google.com/streetview',
        isAvailable: true,
        viewCount: 0,
        likeCount: 0,
        interestCount: 0,
      );
      expect(model.hasStreetView, true);
      expect(model.streetViewTarget, 'https://maps.google.com/streetview');
      expect(model.streetViewLaunchUrl, 'https://maps.google.com/streetview');
      expect(model.streetViewEmbedUrl, 'https://maps.google.com/streetview');
    });

    test('hasStreetView is true when location is available', () {
      const model = PropertyModel(
        id: 1,
        title: 'Test',
        basePrice: 0,
        latitude: 28.6,
        longitude: 77.2,
        isAvailable: true,
        viewCount: 0,
        likeCount: 0,
        interestCount: 0,
      );
      expect(model.hasStreetView, true);
      expect(model.streetViewTarget, '28.6,77.2');
      expect(model.streetViewLaunchUrl,
          'https://www.google.com/maps/@?api=1&map_action=pano&viewpoint=28.6,77.2');
    });

    test('hasStreetView is false when no URL and no location', () {
      const model = PropertyModel(
        id: 1,
        title: 'Test',
        basePrice: 0,
        isAvailable: true,
        viewCount: 0,
        likeCount: 0,
        interestCount: 0,
      );
      expect(model.hasStreetView, false);
      expect(model.streetViewTarget, isNull);
      expect(model.streetViewLaunchUrl, isNull);
      expect(model.streetViewEmbedUrl, isNull);
    });

    test('streetViewStaticImage returns URL with API key and location', () {
      const model = PropertyModel(
        id: 1,
        title: 'Test',
        basePrice: 0,
        latitude: 28.6,
        longitude: 77.2,
        isAvailable: true,
        viewCount: 0,
        likeCount: 0,
        interestCount: 0,
      );
      final url = model.streetViewStaticImage('test-api-key');
      expect(url, isNotNull);
      expect(url, contains('maps.googleapis.com'));
      expect(url, contains('streetview'));
      expect(url, contains('test-api-key'));
      expect(url, contains('28.6'));
      expect(url, contains('77.2'));
    });

    test('streetViewStaticImage returns null when no API key', () {
      const model = PropertyModel(
        id: 1,
        title: 'Test',
        basePrice: 0,
        latitude: 28.6,
        longitude: 77.2,
        isAvailable: true,
        viewCount: 0,
        likeCount: 0,
        interestCount: 0,
      );
      expect(model.streetViewStaticImage(''), isNull);
    });

    test('streetViewStaticImage returns null when no location', () {
      const model = PropertyModel(
        id: 1,
        title: 'Test',
        basePrice: 0,
        isAvailable: true,
        viewCount: 0,
        likeCount: 0,
        interestCount: 0,
      );
      expect(model.streetViewStaticImage('test-api-key'), isNull);
    });
  });

  group('PropertyModel amenities and owner getters', () {
    test('hasAmenities is true when amenities list is not empty', () {
      final model = PropertyModel.fromJson({
        'amenities': [
          {'id': 1, 'title': 'Pool'},
        ],
      });
      expect(model.hasAmenities, true);
      expect(model.amenitiesList, ['Pool']);
      expect(model.amenitiesData, hasLength(1));
    });

    test('hasAmenities is false when amenities is null or empty', () {
      const model = PropertyModel(
        id: 1,
        title: 'Test',
        basePrice: 0,
        isAvailable: true,
        viewCount: 0,
        likeCount: 0,
        interestCount: 0,
      );
      expect(model.hasAmenities, false);
      expect(model.amenitiesList, isEmpty);
      expect(model.amenitiesData, isEmpty);
    });

    test('hasOwner is true when ownerName is set', () {
      const model = PropertyModel(
        id: 1,
        title: 'Test',
        basePrice: 0,
        ownerName: 'John Doe',
        isAvailable: true,
        viewCount: 0,
        likeCount: 0,
        interestCount: 0,
      );
      expect(model.hasOwner, true);
      expect(model.ownerDisplayName, 'John Doe');
    });

    test('hasOwner is false when ownerName is null or empty', () {
      const model = PropertyModel(
        id: 1,
        title: 'Test',
        basePrice: 0,
        isAvailable: true,
        viewCount: 0,
        likeCount: 0,
        interestCount: 0,
      );
      expect(model.hasOwner, false);
      expect(model.ownerDisplayName, 'Property Owner');
    });

    test('hasOwnerContact is true when ownerContact is set', () {
      const model = PropertyModel(
        id: 1,
        title: 'Test',
        basePrice: 0,
        ownerContact: '+1234567890',
        isAvailable: true,
        viewCount: 0,
        likeCount: 0,
        interestCount: 0,
      );
      expect(model.hasOwnerContact, true);
    });

    test('hasOwnerContact is false when ownerContact is null or empty', () {
      const model = PropertyModel(
        id: 1,
        title: 'Test',
        basePrice: 0,
        isAvailable: true,
        viewCount: 0,
        likeCount: 0,
        interestCount: 0,
      );
      expect(model.hasOwnerContact, false);
    });
  });

  group('PropertyModel additional getters', () {
    test('statusString maps all status values', () {
      expect(
        PropertyModel.fromJson({'status': 'available'}).statusString,
        'Available',
      );
      expect(
        PropertyModel.fromJson({'status': 'sold'}).statusString,
        'Sold',
      );
      expect(
        PropertyModel.fromJson({'status': 'rented'}).statusString,
        'Rented',
      );
      expect(
        PropertyModel.fromJson({'status': 'under_offer'}).statusString,
        'Under Offer',
      );
      expect(
        PropertyModel.fromJson({'status': 'maintenance'}).statusString,
        'Maintenance',
      );
    });

    test('statusString defaults to Available', () {
      const model = PropertyModel(
        id: 1,
        title: 'Test',
        basePrice: 0,
        isAvailable: true,
        viewCount: 0,
        likeCount: 0,
        interestCount: 0,
      );
      expect(model.statusString, 'Available');
    });

    test('purposeString maps all purpose values', () {
      expect(
        PropertyModel.fromJson({'purpose': 'buy'}).purposeString,
        'Buy',
      );
      expect(
        PropertyModel.fromJson({'purpose': 'rent'}).purposeString,
        'Rent',
      );
      expect(
        PropertyModel.fromJson({'purpose': 'short_stay'}).purposeString,
        'Short Stay',
      );
    });

    test('purposeString defaults to For Sale', () {
      const model = PropertyModel(
        id: 1,
        title: 'Test',
        basePrice: 0,
        isAvailable: true,
        viewCount: 0,
        likeCount: 0,
        interestCount: 0,
      );
      expect(model.purposeString, 'For Sale');
    });

    test('purposeTranslationKey maps all purpose values', () {
      expect(
        PropertyModel.fromJson({'purpose': 'buy'}).purposeTranslationKey,
        'buy',
      );
      expect(
        PropertyModel.fromJson({'purpose': 'rent'}).purposeTranslationKey,
        'rent',
      );
      expect(
        PropertyModel.fromJson({'purpose': 'short_stay'}).purposeTranslationKey,
        'short_stay',
      );
    });

    test('propertyTypeTranslationKey maps all type values', () {
      expect(
        PropertyModel.fromJson({'property_type': 'house'}).propertyTypeTranslationKey,
        'house',
      );
      expect(
        PropertyModel.fromJson({'property_type': 'apartment'}).propertyTypeTranslationKey,
        'apartment',
      );
      expect(
        PropertyModel.fromJson({'property_type': 'builder_floor'}).propertyTypeTranslationKey,
        'builder_floor',
      );
      expect(
        PropertyModel.fromJson({'property_type': 'pg'}).propertyTypeTranslationKey,
        'pg',
      );
      expect(
        PropertyModel.fromJson({}).propertyTypeTranslationKey,
        'property',
      );
    });

    test('addressDisplay uses fullAddress when available', () {
      const model = PropertyModel(
        id: 1,
        title: 'Test',
        basePrice: 0,
        fullAddress: '123 Main St, City',
        locality: 'Area',
        city: 'City',
        isAvailable: true,
        viewCount: 0,
        likeCount: 0,
        interestCount: 0,
      );
      expect(model.addressDisplay, '123 Main St, City');
    });

    test('addressDisplay uses locality and city when no fullAddress', () {
      const model = PropertyModel(
        id: 1,
        title: 'Test',
        basePrice: 0,
        locality: 'Area',
        city: 'City',
        isAvailable: true,
        viewCount: 0,
        likeCount: 0,
        interestCount: 0,
      );
      expect(model.addressDisplay, 'Area, City');
    });

    test('addressDisplay falls back to city or Unknown Location', () {
      const model = PropertyModel(
        id: 1,
        title: 'Test',
        basePrice: 0,
        city: 'City',
        isAvailable: true,
        viewCount: 0,
        likeCount: 0,
        interestCount: 0,
      );
      expect(model.addressDisplay, 'City');

      const model2 = PropertyModel(
        id: 2,
        title: 'Test',
        basePrice: 0,
        isAvailable: true,
        viewCount: 0,
        likeCount: 0,
        interestCount: 0,
      );
      expect(model2.addressDisplay, 'Unknown Location');
    });

    test('imageDescription combines propertyTypeString and city', () {
      final model = PropertyModel.fromJson({
        'property_type': 'apartment',
        'city': 'Mumbai',
      });
      expect(model.imageDescription, contains('Mumbai'));
    });

    test('imageDescription uses Unknown Location when city is null', () {
      final model = PropertyModel.fromJson({});
      expect(model.imageDescription, contains('Unknown Location'));
    });

    test('titleInitials extracts initials from multi-word title', () {
      const model = PropertyModel(
        id: 1,
        title: 'Beautiful Apartment',
        basePrice: 0,
        isAvailable: true,
        viewCount: 0,
        likeCount: 0,
        interestCount: 0,
      );
      expect(model.titleInitials, 'BA');
    });

    test('titleInitials extracts first letter from single-word title', () {
      const model = PropertyModel(
        id: 1,
        title: 'Villa',
        basePrice: 0,
        isAvailable: true,
        viewCount: 0,
        likeCount: 0,
        interestCount: 0,
      );
      expect(model.titleInitials, 'V');
    });

    test('titleInitials returns P for empty title', () {
      const model = PropertyModel(
        id: 1,
        title: '',
        basePrice: 0,
        isAvailable: true,
        viewCount: 0,
        likeCount: 0,
        interestCount: 0,
      );
      expect(model.titleInitials, 'P');
    });

    test('hasUserScheduled is true when userHasScheduledVisit is true', () {
      const model = PropertyModel(
        id: 1,
        title: 'Test',
        basePrice: 0,
        isAvailable: true,
        viewCount: 0,
        likeCount: 0,
        interestCount: 0,
        userHasScheduledVisit: true,
      );
      expect(model.hasUserScheduled, true);
    });

    test('hasUserScheduled is true when userNextVisitDate is set', () {
      final model = PropertyModel(
        id: 1,
        title: 'Test',
        basePrice: 0,
        isAvailable: true,
        viewCount: 0,
        likeCount: 0,
        interestCount: 0,
        userNextVisitDate: DateTime(2025, 1, 1),
      );
      expect(model.hasUserScheduled, true);
    });

    test('hasUserScheduled is false when neither is set', () {
      const model = PropertyModel(
        id: 1,
        title: 'Test',
        basePrice: 0,
        isAvailable: true,
        viewCount: 0,
        likeCount: 0,
        interestCount: 0,
      );
      expect(model.hasUserScheduled, false);
    });

    test('availableFromDate parses valid date string', () {
      const model = PropertyModel(
        id: 1,
        title: 'Test',
        basePrice: 0,
        isAvailable: true,
        viewCount: 0,
        likeCount: 0,
        interestCount: 0,
        availableFrom: '2025-01-15',
      );
      expect(model.availableFromDate, DateTime(2025, 1, 15));
    });

    test('availableFromDate returns null for empty string', () {
      const model = PropertyModel(
        id: 1,
        title: 'Test',
        basePrice: 0,
        isAvailable: true,
        viewCount: 0,
        likeCount: 0,
        interestCount: 0,
        availableFrom: '',
      );
      expect(model.availableFromDate, isNull);
    });

    test('availableFromDate returns null when availableFrom is null', () {
      const model = PropertyModel(
        id: 1,
        title: 'Test',
        basePrice: 0,
        isAvailable: true,
        viewCount: 0,
        likeCount: 0,
        interestCount: 0,
      );
      expect(model.availableFromDate, isNull);
    });

    test('availableFromDate returns null for invalid date string', () {
      const model = PropertyModel(
        id: 1,
        title: 'Test',
        basePrice: 0,
        isAvailable: true,
        viewCount: 0,
        likeCount: 0,
        interestCount: 0,
        availableFrom: 'not-a-date',
      );
      expect(model.availableFromDate, isNull);
    });

    test('genderPreferenceTranslationKey maps all values', () {
      expect(
        PropertyModel.fromJson({
          'listing_preferences': {'gender_preference': 'any'},
        }).genderPreferenceTranslationKey,
        'open_to_all',
      );
      expect(
        PropertyModel.fromJson({
          'listing_preferences': {'gender_preference': 'male'},
        }).genderPreferenceTranslationKey,
        'male_only',
      );
      expect(
        PropertyModel.fromJson({
          'listing_preferences': {'gender_preference': 'female'},
        }).genderPreferenceTranslationKey,
        'female_only',
      );
      expect(
        PropertyModel.fromJson({}).genderPreferenceTranslationKey,
        isNull,
      );
    });

    test('sharingTypeTranslationKey maps all values', () {
      expect(
        PropertyModel.fromJson({
          'listing_preferences': {'sharing_type': 'private_room'},
        }).sharingTypeTranslationKey,
        'private_room',
      );
      expect(
        PropertyModel.fromJson({
          'listing_preferences': {'sharing_type': 'shared_room'},
        }).sharingTypeTranslationKey,
        'shared_room',
      );
      expect(
        PropertyModel.fromJson({}).sharingTypeTranslationKey,
        isNull,
      );
    });
  });
}
