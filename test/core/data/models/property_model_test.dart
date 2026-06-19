import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

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

    test('wire value helpers use canonical backend tokens', () {
      expect(PropertyType.builderFloor.wireValue, 'builder_floor');
      expect(PropertyType.penthouse.wireValue, 'penthouse');
      expect(PropertyType.pg.wireValue, 'pg');
      expect(PropertyType.warehouse.wireValue, 'warehouse');
      expect(PropertyPurpose.shortStay.wireValue, 'short_stay');
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
}
