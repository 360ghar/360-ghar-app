import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/data/models/property_image_model.dart';
import 'package:ghar360/core/data/models/property_model.dart';

Map<String, dynamic> _image(int id, String category) => {
  'id': id,
  'property_id': 42,
  'image_url': 'https://cdn.example.com/p42/$category-$id.jpg',
  'caption': null,
  'image_category': category,
  'display_order': id,
  'is_main_image': false,
};

/// A `Property` or `PropertyDetail` body as the backend sends it. [overrides] replace keys.
Map<String, dynamic> _body([Map<String, dynamic> overrides = const {}]) => {
  'id': 42,
  'owner_id': 7,
  'title': 'Test Property',
  'description': null,
  'property_type': 'apartment',
  'purpose': 'buy',
  'status': 'available',
  'base_price': 5000000.0,
  'price_per_sqft': null,
  'monthly_rent': null,
  'daily_rate': null,
  'nightly_rate': null,
  'country': 'India',
  'is_available': true,
  'available_from': null,
  'view_count': 10,
  'like_count': 5,
  'interest_count': 3,
  'created_at': '2026-09-30T10:15:02Z',
  'updated_at': '2026-09-30T10:15:02Z',
  ...overrides,
};

PropertyModel _parse(Map<String, dynamic> overrides) => PropertyModel.fromJson(_body(overrides));

void main() {
  group('PropertyModel.fromJson', () {
    test('reads a PropertyDetail body', () {
      final model = PropertyModel.fromJson(_body());

      expect(model.id, 42);
      expect(model.ownerId, 7);
      expect(model.title, 'Test Property');
      expect(model.basePrice, 5000000.0);
      expect(model.propertyType, PropertyType.apartment);
      expect(model.purpose, PropertyPurpose.buy);
      expect(model.status, PropertyStatus.available);
      expect(model.isAvailable, true);
      expect(model.viewCount, 10);
      expect(model.likeCount, 5);
      expect(model.country, 'India');
      expect(model.createdAt, DateTime.utc(2026, 9, 30, 10, 15, 2));
    });

    test('a key the backend always sends is required', () {
      for (final key in [
        'id',
        'owner_id',
        'title',
        'property_type',
        'purpose',
        'status',
        'base_price',
        'country',
        'is_available',
        'view_count',
        'like_count',
        'interest_count',
        'created_at',
        'updated_at',
      ]) {
        final body = _body()..remove(key);
        expect(() => PropertyModel.fromJson(body), throwsA(anything), reason: 'missing $key');
      }
    });

    test('an empty body is a contract break, not a property with defaults', () {
      expect(() => PropertyModel.fromJson(<String, dynamic>{}), throwsA(anything));
    });

    test('parses every property_type', () {
      const wire = {
        'house': PropertyType.house,
        'apartment': PropertyType.apartment,
        'builder_floor': PropertyType.builderFloor,
        'room': PropertyType.room,
        'villa': PropertyType.villa,
        'plot': PropertyType.plot,
        'condo': PropertyType.condo,
        'penthouse': PropertyType.penthouse,
        'studio': PropertyType.studio,
        'loft': PropertyType.loft,
        'pg': PropertyType.pg,
        'flatmate': PropertyType.flatmate,
        'office': PropertyType.office,
        'shop': PropertyType.shop,
        'warehouse': PropertyType.warehouse,
      };
      for (final entry in wire.entries) {
        expect(_parse({'property_type': entry.key}).propertyType, entry.value, reason: entry.key);
      }
    });

    test('an unknown property_type reads as null, not as house', () {
      expect(_parse({'property_type': 'spaceship'}).propertyType, isNull);
    });

    test('parses purpose', () {
      expect(_parse({'purpose': 'buy'}).purpose, PropertyPurpose.buy);
      expect(_parse({'purpose': 'rent'}).purpose, PropertyPurpose.rent);
      expect(_parse({'purpose': 'short_stay'}).purpose, PropertyPurpose.shortStay);
    });

    test('an unknown purpose reads as null, not as buy', () {
      expect(_parse({'purpose': 'barter'}).purpose, isNull);
    });

    test('an unknown status reads as null', () {
      expect(_parse({'status': 'demolished'}).status, isNull);
    });

    test('parses location fields', () {
      final model = _parse({
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

    test('is_available is the availability flag', () {
      expect(_parse({'is_available': false}).isAvailable, false);
    });

    test('amenities carry the amenity id', () {
      final model = _parse({
        'amenities': [
          {'id': 11, 'title': 'Swimming Pool', 'icon': null, 'category': 'recreation'},
          {'id': 12, 'title': 'Gym', 'icon': 'gym', 'category': null},
        ],
      });

      expect(model.amenities, isNotNull);
      expect(model.amenities!.length, 2);
      expect(model.amenities![0].id, 11);
      expect(model.amenities![0].title, 'Swimming Pool');
      expect(model.amenities![1].icon, 'gym');
    });

    test('an amenity needs an id and a title', () {
      expect(
        () => _parse({
          'amenities': [
            {'title': 'Gym'},
          ],
        }),
        throwsA(anything),
      );
      expect(
        () => _parse({
          'amenities': [
            {'id': 1},
          ],
        }),
        throwsA(anything),
      );
    });

    test('reads the sharing and gender preference of a flatmate listing', () {
      final model = _parse({
        'listing_preferences': {'gender_preference': 'female', 'sharing_type': 'shared_room'},
      });

      expect(model.listingPreferences?.genderPreference, ListingGenderPreference.female);
      expect(model.listingPreferences?.sharingType, ListingSharingType.sharedRoom);
      expect(model.genderPreferenceTranslationKey, 'female_only');
      expect(model.sharingTypeTranslationKey, 'shared_room');
    });

    test('master_bedroom and entire_flat are sharing types, not private_room', () {
      expect(
        _parse({
          'listing_preferences': {'sharing_type': 'master_bedroom'},
        }).listingPreferences?.sharingType,
        ListingSharingType.masterBedroom,
      );
      expect(
        _parse({
          'listing_preferences': {'sharing_type': 'entire_flat'},
        }).listingPreferences?.sharingType,
        ListingSharingType.entireFlat,
      );
    });

    test('an unknown sharing type reads as null and shows no label', () {
      final model = _parse({
        'listing_preferences': {'sharing_type': 'dormitory'},
      });

      expect(model.listingPreferences?.sharingType, isNull);
      expect(model.sharingTypeTranslationKey, isNull);
    });

    test('available_from is a calendar date', () {
      final model = _parse({'available_from': '2026-11-01'});

      expect(model.availableFrom, DateTime(2026, 11));
    });

    test('available_from must be YYYY-MM-DD, not a timestamp', () {
      expect(() => _parse({'available_from': '2026-11-01T00:00:00Z'}), throwsA(anything));
      expect(() => _parse({'available_from': 'soon'}), throwsA(anything));
    });

    test('reads the PG fields: furnishing, kitchen, ventilation and charges', () {
      final model = _parse({
        'furnishing_level': 'semi_furnished',
        'kitchen_type': 'vegetarian',
        'ventilation_type': 'good',
        'windows_count': 3,
        'ventilation_shafts': 1,
        'setup_cost': 5000.0,
        'other_charges': 1200.0,
        'other_charges_description': 'Electricity and Wi-Fi',
      });

      expect(model.furnishingLevel, FurnishingLevel.semiFurnished);
      expect(model.kitchenType, KitchenType.vegetarian);
      expect(model.ventilationType, VentilationType.good);
      expect(model.windowsCount, 3);
      expect(model.setupCost, 5000.0);
      expect(model.otherCharges, 1200.0);
      expect(model.otherChargesDescription, 'Electricity and Wi-Fi');
    });

    test('an unknown furnishing level reads as null', () {
      expect(_parse({'furnishing_level': 'fully_loaded'}).furnishingLevel, isNull);
    });

    test('price_per_sqft is the backend value, never derived', () {
      final model = _parse({
        'base_price': 5000000.0,
        'area_sqft': 1000.0,
        'price_per_sqft': 6000.0,
      });

      expect(model.pricePerSqft, 6000.0);
      expect(_parse({'price_per_sqft': null}).pricePerSqft, isNull);
    });

    test('floor plans come from floor_plans, never from images', () {
      final model = _parse({
        'images': [_image(1, 'hall')],
        'floor_plans': [_image(2, 'floor_plan')],
      });

      expect(model.galleryImages.map((image) => image.id), [1]);
      expect(model.floorPlanImages.map((image) => image.id), [2]);
    });

    test('agent comes with the detail route only', () {
      expect(_parse({}).agent, isNull);
      final model = _parse({
        'agent': {'id': 4, 'name': 'Ravi Kumar', 'contact_number': '+919811111111'},
      });

      expect(model.agent?.name, 'Ravi Kumar');
      expect(model.agent?.contactNumber, '+919811111111');
    });
  });

  group('PropertyModel helper getters', () {
    PropertyModel make({
      double basePrice = 0,
      PropertyPurpose? purpose = PropertyPurpose.buy,
      double? monthlyRent,
      double? nightlyRate,
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
        nightlyRate: nightlyRate,
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
      expect(make(basePrice: 5000000).formattedPrice, '₹50 L');
    });

    test('formattedPrice formats small values', () {
      expect(make(basePrice: 50000).formattedPrice, '₹50,000');
    });

    test('the price follows the purpose: monthly_rent for rent', () {
      final model = make(basePrice: 100000, purpose: PropertyPurpose.rent, monthlyRent: 25000);
      expect(model.effectivePrice, 25000);
      expect(model.formattedPrice, '₹25,000');
    });

    test('a rent listing with no monthly_rent has no price: no fallback to base_price', () {
      final model = make(basePrice: 100000, purpose: PropertyPurpose.rent);
      expect(model.effectivePrice, isNull);
      expect(model.formattedPrice, isEmpty);
    });

    test('the price follows the purpose: nightly_rate for a short stay', () {
      final model = make(basePrice: 100000, purpose: PropertyPurpose.shortStay, nightlyRate: 3000);
      expect(model.effectivePrice, 3000);
    });

    test('a short stay with no nightly_rate has no nightly price', () {
      final model = make(basePrice: 100000, purpose: PropertyPurpose.shortStay);
      expect(model.effectivePrice, isNull);
    });

    test('the price follows the purpose: base_price for a sale', () {
      expect(make(basePrice: 8500000).effectivePrice, 8500000);
    });

    test('an unknown purpose has no price', () {
      expect(make(purpose: null, basePrice: 8500000).effectivePrice, isNull);
    });

    test('shortAddressDisplay builds from locality parts', () {
      expect(make(locality: 'Sector 62', city: 'Noida').shortAddressDisplay, 'Sector 62, Noida');
      expect(
        make(locality: 'Sector 62', subLocality: 'Block A', city: 'Noida').shortAddressDisplay,
        'Sector 62, Block A, Noida',
      );
      expect(make(city: 'Noida').shortAddressDisplay, 'Noida');
      expect(make().shortAddressDisplay, isEmpty);
    });

    test('hasLocation requires both coordinates', () {
      expect(make(latitude: 28.0, longitude: 77.0).hasLocation, true);
      expect(make(latitude: 28.0).hasLocation, false);
      expect(make().hasLocation, false);
    });

    test('listingTranslationKey prioritizes pg and flatmate labels', () {
      expect(_parse({'property_type': 'pg', 'purpose': 'rent'}).listingTranslationKey, 'pg');
      expect(
        _parse({'property_type': 'flatmate', 'purpose': 'rent'}).listingTranslationKey,
        'flatmate',
      );
      expect(
        _parse({'property_type': 'apartment', 'purpose': 'short_stay'}).listingTranslationKey,
        'short_stay',
      );
    });

    test('formattedPrice handles very large values (100 Cr+)', () {
      expect(make(basePrice: 1000000000).formattedPrice, '₹100 Cr');
      expect(make(basePrice: 150000000).formattedPrice, '₹15 Cr');
    });

    test('formattedPrice handles zero price', () {
      expect(make(basePrice: 0).formattedPrice, '₹0');
    });

    test('formattedPrice handles negative price', () {
      // Negative values keep the Indian sign-before-symbol convention.
      expect(make(basePrice: -1000).formattedPrice, '-₹1,000');
      expect(make(basePrice: -5000000).formattedPrice, '-₹50 L');
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
      expect(PropertyType.builderFloor.wire, 'builder_floor');
      expect(PropertyType.penthouse.wire, 'penthouse');
      expect(PropertyType.pg.wire, 'pg');
      expect(PropertyType.warehouse.wire, 'warehouse');
      expect(PropertyPurpose.shortStay.wire, 'short_stay');
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
      final original = PropertyModel.fromJson(
        _body({
          'id': 10,
          'title': 'My Flat',
          'base_price': 4500000.0,
          'property_type': 'apartment',
          'purpose': 'rent',
          'bedrooms': 2,
          'bathrooms': 1,
        }),
      );

      final json = original.toJson();
      final restored = PropertyModel.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.basePrice, original.basePrice);
      expect(restored.propertyType, original.propertyType);
      expect(restored.purpose, original.purpose);
      expect(restored.bedrooms, original.bedrooms);
    });

    test('a stored copy has no phone number', () {
      final model = PropertyModel.fromJson(
        _body({
          'owner_contact': '+911800000360',
          'agent': {'id': 4, 'name': 'Ravi', 'contact_number': '+919811111111'},
        }),
      );

      final stored = model.toStorableJson();

      expect(stored.containsKey('owner_contact'), isFalse);
      expect((stored['agent'] as Map).containsKey('contact_number'), isFalse);
      expect(model.contactNumber, '+919811111111', reason: 'the live model keeps the number');
    });
  });

  group('PropertyModel image and media getters', () {
    PropertyModel make({
      String? mainImageUrl,
      List<PropertyImageModel>? images,
      List<PropertyImageModel>? floorPlans,
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
        floorPlans: floorPlans,
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

    PropertyImageModel img(
      String url, {
      bool isMainImage = false,
      int order = 0,
      ImageCategory category = ImageCategory.others,
    }) {
      return PropertyImageModel(
        id: order,
        propertyId: 1,
        imageUrl: url,
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
      final model = make(
        images: [
          img('https://example.com/secondary.jpg', order: 0),
          img('https://example.com/primary.jpg', isMainImage: true, order: 1),
        ],
      );
      expect(model.mainImage, 'https://example.com/primary.jpg');
    });

    test('mainImage returns first image when no primary and mainImageUrl is null', () {
      final model = make(images: [img('https://example.com/first.jpg', order: 0)]);
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
      final model = make(
        images: [
          img('https://example.com/photo1.jpg', order: 0, category: ImageCategory.others),
          img('https://example.com/floor.jpg', order: 1, category: ImageCategory.floorPlan),
          img('https://kuula.co/share/abc', order: 2, category: ImageCategory.others),
        ],
      );
      final gallery = model.galleryImages;
      expect(gallery, hasLength(1));
      expect(gallery[0].imageUrl, 'https://example.com/photo1.jpg');
    });

    test('galleryImageUrls falls back to mainImageUrl when no gallery images', () {
      final model = make(mainImageUrl: 'https://example.com/main.jpg');
      expect(model.galleryImageUrls, ['https://example.com/main.jpg']);
    });

    test('floorPlanImages come from floor_plans, and images hold photos only', () {
      final model = make(
        images: [img('https://example.com/photo.jpg', order: 0, category: ImageCategory.others)],
        floorPlans: [
          img('https://example.com/plan.jpg', order: 1, category: ImageCategory.floorPlan),
        ],
      );
      final plans = model.floorPlanImages;
      expect(plans, hasLength(1));
      expect(plans[0].imageUrl, 'https://example.com/plan.jpg');
    });

    test('floorPlanImageUrls includes floorPlanUrl and floor plan images', () {
      final model = make(
        floorPlanUrl: 'https://example.com/external_plan.jpg',
        floorPlans: [
          img('https://example.com/plan.jpg', order: 0, category: ImageCategory.floorPlan),
        ],
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
      final model = make(videoTourUrl: '', videoUrls: ['', 'https://example.com/video.mp4']);
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
      final model = make(
        images: [img('https://kuula.co/share/abc', order: 0, category: ImageCategory.others)],
      );
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
      expect(
        model.streetViewLaunchUrl,
        'https://www.google.com/maps/@?api=1&map_action=pano&viewpoint=28.6,77.2',
      );
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
      final model = _parse({
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

    test('contactNumber is the agent number when the detail route sent an agent', () {
      final model = _parse({
        'owner_contact': '+911800000360',
        'agent': {'id': 4, 'name': 'Ravi', 'contact_number': '+919811111111'},
      });

      expect(model.contactNumber, '+919811111111');
      expect(model.hasContact, true);
    });

    test(
      'contactNumber is owner_contact otherwise: the agent or company number the server chose',
      () {
        final model = _parse({'owner_contact': ' +911800000360 '});

        expect(model.contactNumber, '+911800000360');
      },
    );

    test('contactNumber is null when the server sent no number', () {
      expect(_parse({'owner_contact': null}).contactNumber, isNull);
      expect(_parse({'owner_contact': '  '}).hasContact, false);
    });
  });

  group('PropertyModel additional getters', () {
    test('statusString maps all status values', () {
      expect(_parse({'status': 'available'}).statusString, 'Available');
      expect(_parse({'status': 'sold'}).statusString, 'Sold');
      expect(_parse({'status': 'rented'}).statusString, 'Rented');
      expect(_parse({'status': 'under_offer'}).statusString, 'Under Offer');
      expect(_parse({'status': 'maintenance'}).statusString, 'Maintenance');
    });

    test('statusString is empty for a status the app does not know', () {
      expect(_parse({'status': 'demolished'}).statusString, isEmpty);
    });

    test('purposeTranslationKey maps all purpose values', () {
      expect(_parse({'purpose': 'buy'}).purposeTranslationKey, 'buy');
      expect(_parse({'purpose': 'rent'}).purposeTranslationKey, 'rent');
      expect(_parse({'purpose': 'short_stay'}).purposeTranslationKey, 'short_stay');
    });

    test('propertyTypeLabelKey maps type values to catalogue keys', () {
      expect(_parse({'property_type': 'house'}).propertyTypeLabelKey, 'property_type_house');
      expect(
        _parse({'property_type': 'builder_floor'}).propertyTypeLabelKey,
        'property_type_builder_floor',
      );
      expect(_parse({'property_type': 'pg'}).propertyTypeLabelKey, 'property_type_pg');
      // An unknown type reads "Property", never the raw lowercase key.
      expect(_parse({'property_type': 'spaceship'}).propertyTypeLabelKey, 'property_type_default');
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

    test('addressDisplay falls back to city, else empty', () {
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
      expect(model2.addressDisplay, isEmpty);
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

    test('genderPreferenceTranslationKey maps all values', () {
      expect(
        _parse({
          'listing_preferences': {'gender_preference': 'any'},
        }).genderPreferenceTranslationKey,
        'open_to_all',
      );
      expect(
        _parse({
          'listing_preferences': {'gender_preference': 'male'},
        }).genderPreferenceTranslationKey,
        'male_only',
      );
      expect(
        _parse({
          'listing_preferences': {'gender_preference': 'female'},
        }).genderPreferenceTranslationKey,
        'female_only',
      );
      expect(_parse({}).genderPreferenceTranslationKey, isNull);
    });

    test('sharingTypeTranslationKey maps all values', () {
      expect(
        _parse({
          'listing_preferences': {'sharing_type': 'private_room'},
        }).sharingTypeTranslationKey,
        'private_room',
      );
      expect(
        _parse({
          'listing_preferences': {'sharing_type': 'shared_room'},
        }).sharingTypeTranslationKey,
        'shared_room',
      );
      expect(_parse({}).sharingTypeTranslationKey, isNull);
    });
  });
}
