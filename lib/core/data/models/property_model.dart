import 'package:get/get.dart';
import 'package:ghar360/core/data/models/property_image_model.dart';
import 'package:json_annotation/json_annotation.dart';

part 'property_model.g.dart';

// Enums matching backend schema
enum PropertyType {
  @JsonValue('house')
  house,
  @JsonValue('apartment')
  apartment,
  @JsonValue('builder_floor')
  builderFloor,
  @JsonValue('room')
  room,
  @JsonValue('villa')
  villa,
  @JsonValue('plot')
  plot,
  @JsonValue('condo')
  condo,
  @JsonValue('penthouse')
  penthouse,
  @JsonValue('studio')
  studio,
  @JsonValue('loft')
  loft,
  @JsonValue('pg')
  pg,
  @JsonValue('flatmate')
  flatmate,
  @JsonValue('office')
  office,
  @JsonValue('shop')
  shop,
  @JsonValue('warehouse')
  warehouse,
}

enum PropertyPurpose {
  @JsonValue('buy')
  buy,
  @JsonValue('rent')
  rent,
  @JsonValue('short_stay')
  shortStay,
}

extension PropertyTypeWireValue on PropertyType {
  String get wireValue {
    switch (this) {
      case PropertyType.house:
        return 'house';
      case PropertyType.apartment:
        return 'apartment';
      case PropertyType.builderFloor:
        return 'builder_floor';
      case PropertyType.room:
        return 'room';
      case PropertyType.villa:
        return 'villa';
      case PropertyType.plot:
        return 'plot';
      case PropertyType.condo:
        return 'condo';
      case PropertyType.penthouse:
        return 'penthouse';
      case PropertyType.studio:
        return 'studio';
      case PropertyType.loft:
        return 'loft';
      case PropertyType.pg:
        return 'pg';
      case PropertyType.flatmate:
        return 'flatmate';
      case PropertyType.office:
        return 'office';
      case PropertyType.shop:
        return 'shop';
      case PropertyType.warehouse:
        return 'warehouse';
    }
  }
}

extension PropertyPurposeWireValue on PropertyPurpose {
  String get wireValue {
    switch (this) {
      case PropertyPurpose.buy:
        return 'buy';
      case PropertyPurpose.rent:
        return 'rent';
      case PropertyPurpose.shortStay:
        return 'short_stay';
    }
  }
}

enum PropertyStatus {
  @JsonValue('available')
  available,
  @JsonValue('sold')
  sold,
  @JsonValue('rented')
  rented,
  @JsonValue('under_offer')
  underOffer,
  @JsonValue('maintenance')
  maintenance,
}

enum ListingGenderPreference {
  @JsonValue('any')
  any,
  @JsonValue('male')
  male,
  @JsonValue('female')
  female,
}

enum ListingSharingType {
  @JsonValue('private_room')
  privateRoom,
  @JsonValue('shared_room')
  sharedRoom,
}

@JsonSerializable()
class PropertyAmenity {
  @JsonKey(defaultValue: -1)
  final int id;
  @JsonKey(defaultValue: 'Unknown')
  final String title;
  final String? icon;
  final String? category;

  const PropertyAmenity({required this.id, required this.title, this.icon, this.category});

  factory PropertyAmenity.fromJson(Map<String, dynamic> json) => _$PropertyAmenityFromJson(json);
  Map<String, dynamic> toJson() => _$PropertyAmenityToJson(this);
}

@JsonSerializable()
class ListingPreferences {
  @JsonKey(name: 'gender_preference', unknownEnumValue: ListingGenderPreference.any)
  final ListingGenderPreference? genderPreference;
  @JsonKey(name: 'sharing_type', unknownEnumValue: ListingSharingType.privateRoom)
  final ListingSharingType? sharingType;

  const ListingPreferences({this.genderPreference, this.sharingType});

  factory ListingPreferences.fromJson(Map<String, dynamic> json) =>
      _$ListingPreferencesFromJson(json);
  Map<String, dynamic> toJson() => _$ListingPreferencesToJson(this);
}

@JsonSerializable(explicitToJson: true, checked: true)
class PropertyModel {
  @JsonKey(defaultValue: -1)
  final int id;
  @JsonKey(defaultValue: 'Unknown Property')
  final String title;
  final String? description;
  @JsonKey(name: 'property_type', unknownEnumValue: PropertyType.house)
  final PropertyType? propertyType;
  @JsonKey(unknownEnumValue: PropertyPurpose.buy)
  final PropertyPurpose? purpose;
  @JsonKey(name: 'base_price', defaultValue: 0.0)
  final double basePrice;
  @JsonKey(unknownEnumValue: PropertyStatus.available)
  final PropertyStatus? status;

  // Location fields
  final double? latitude;
  final double? longitude;
  final String? city;
  final String? state;
  @JsonKey(defaultValue: 'India')
  final String country;
  final String? pincode;
  final String? locality;
  @JsonKey(name: 'sub_locality')
  final String? subLocality;
  final String? landmark;
  @JsonKey(name: 'full_address')
  final String? fullAddress;
  @JsonKey(name: 'area_type')
  final String? areaType;

  // Property details
  @JsonKey(name: 'area_sqft')
  final double? areaSqft;
  final int? bedrooms;
  final int? bathrooms;
  final int? balconies;
  @JsonKey(name: 'parking_spaces')
  final int? parkingSpaces;

  // Pricing
  @JsonKey(name: 'price_per_sqft')
  final double? pricePerSqft;
  @JsonKey(name: 'monthly_rent')
  final double? monthlyRent;
  @JsonKey(name: 'daily_rate')
  final double? dailyRate;
  @JsonKey(name: 'security_deposit')
  final double? securityDeposit;
  @JsonKey(name: 'maintenance_charges')
  final double? maintenanceCharges;

  // Building details
  @JsonKey(name: 'floor_number')
  final int? floorNumber;
  @JsonKey(name: 'total_floors')
  final int? totalFloors;
  @JsonKey(name: 'age_of_property')
  final int? ageOfProperty;

  // Accommodation details
  @JsonKey(name: 'max_occupancy')
  final int? maxOccupancy;
  @JsonKey(name: 'minimum_stay_days')
  final int? minimumStayDays;

  // Features and amenities
  final List<PropertyAmenity>? amenities;
  final List<String>? features;
  @JsonKey(name: 'listing_preferences')
  final ListingPreferences? listingPreferences;
  // Media
  @JsonKey(name: 'main_image_url')
  final String? mainImageUrl;
  @JsonKey(name: 'images')
  final List<PropertyImageModel>? images;
  @JsonKey(name: 'video_tour_url')
  final String? videoTourUrl;
  @JsonKey(name: 'video_urls')
  final List<String>? videoUrls;
  @JsonKey(name: 'virtual_tour_url')
  final String? virtualTourUrl;
  @JsonKey(name: 'google_street_view_url')
  final String? googleStreetViewUrl;
  @JsonKey(name: 'floor_plan_url')
  final String? floorPlanUrl;

  // Availability
  // Backend may send either is_active or is_available
  @JsonKey(name: 'is_active', defaultValue: true)
  final bool isAvailable;
  @JsonKey(name: 'available_from')
  final String? availableFrom;
  @JsonKey(name: 'calendar_data')
  final Map<String, dynamic>? calendarData;

  // SEO and metadata
  final List<String>? tags;
  @JsonKey(name: 'owner_name')
  final String? ownerName;
  @JsonKey(name: 'owner_contact')
  final String? ownerContact;
  @JsonKey(name: 'builder_name')
  final String? builderName;

  // Performance metrics
  @JsonKey(name: 'view_count', defaultValue: 0)
  final int viewCount;
  @JsonKey(name: 'like_count', defaultValue: 0)
  final int likeCount;
  @JsonKey(name: 'interest_count', defaultValue: 0)
  final int interestCount;

  // Timestamps
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  // Client-side calculated fields
  @JsonKey(name: 'distance_km')
  final double? distanceKm;

  // Swipe-related fields
  @JsonKey(name: 'liked', defaultValue: false)
  final bool liked;

  // User visit scheduling fields (per-property, user-scoped)
  @JsonKey(name: 'user_has_scheduled_visit', defaultValue: false)
  final bool userHasScheduledVisit;
  @JsonKey(name: 'user_scheduled_visit_count', defaultValue: 0)
  final int userScheduledVisitCount;
  @JsonKey(name: 'user_next_visit_date')
  final DateTime? userNextVisitDate;

  const PropertyModel({
    required this.id,
    required this.title,
    this.description,
    this.propertyType,
    this.purpose,
    required this.basePrice,
    this.status,
    this.latitude,
    this.longitude,
    this.city,
    this.state,
    this.country = 'India',
    this.pincode,
    this.locality,
    this.subLocality,
    this.landmark,
    this.fullAddress,
    this.areaType,
    this.areaSqft,
    this.bedrooms,
    this.bathrooms,
    this.balconies,
    this.parkingSpaces,
    this.pricePerSqft,
    this.monthlyRent,
    this.dailyRate,
    this.securityDeposit,
    this.maintenanceCharges,
    this.floorNumber,
    this.totalFloors,
    this.ageOfProperty,
    this.maxOccupancy,
    this.minimumStayDays,
    this.amenities,
    this.features,
    this.listingPreferences,
    this.mainImageUrl,
    this.images,
    this.videoTourUrl,
    this.videoUrls,
    this.virtualTourUrl,
    this.googleStreetViewUrl,
    this.floorPlanUrl,
    required this.isAvailable,
    this.availableFrom,
    this.calendarData,
    this.tags,
    this.ownerName,
    this.ownerContact,
    this.builderName,
    required this.viewCount,
    required this.likeCount,
    required this.interestCount,
    this.createdAt,
    this.updatedAt,
    this.distanceKm,
    this.liked = false,
    this.userHasScheduledVisit = false,
    this.userScheduledVisitCount = 0,
    this.userNextVisitDate,
  });

  factory PropertyModel.fromJson(Map<String, dynamic> json) {
    // Normalize backend variations without breaking generated parsing
    final normalized = Map<String, dynamic>.from(json);
    if (!normalized.containsKey('is_active') && normalized.containsKey('is_available')) {
      normalized['is_active'] = normalized['is_available'];
    }
    // Normalize date string for user_next_visit_date into ISO if needed
    final nextVisit = normalized['user_next_visit_date'];
    if (nextVisit is String && nextVisit.isNotEmpty) {
      // Let generated code parse ISO-8601 directly; no-op here
    }
    return _$PropertyModelFromJson(normalized);
  }

  Map<String, dynamic> toJson() => _$PropertyModelToJson(this);

  String get formattedPrice {
    final price = getEffectivePrice();
    if (price >= 10000000) {
      return '₹${(price / 10000000).toStringAsFixed(1)} Cr';
    } else if (price >= 100000) {
      return '₹${(price / 100000).toStringAsFixed(1)} L';
    } else {
      return '₹${price.toStringAsFixed(0)}';
    }
  }

  double getEffectivePrice() {
    switch (purpose) {
      case PropertyPurpose.rent:
        return monthlyRent ?? basePrice;
      case PropertyPurpose.shortStay:
        return dailyRate ?? basePrice;
      case PropertyPurpose.buy:
        return basePrice;
      default:
        return basePrice;
    }
  }

  String get propertyTypeString {
    switch (propertyType) {
      case PropertyType.house:
        return 'property_type_house'.tr;
      case PropertyType.apartment:
        return 'property_type_apartment'.tr;
      case PropertyType.builderFloor:
        return 'property_type_builder_floor'.tr;
      case PropertyType.room:
        return 'property_type_room'.tr;
      case PropertyType.villa:
        return 'property_type_villa'.tr;
      case PropertyType.plot:
        return 'property_type_plot'.tr;
      case PropertyType.condo:
        return 'property_type_condo'.tr;
      case PropertyType.penthouse:
        return 'property_type_penthouse'.tr;
      case PropertyType.studio:
        return 'property_type_studio'.tr;
      case PropertyType.loft:
        return 'property_type_loft'.tr;
      case PropertyType.pg:
        return 'property_type_pg'.tr;
      case PropertyType.flatmate:
        return 'property_type_flatmate'.tr;
      case PropertyType.office:
        return 'property_type_office'.tr;
      case PropertyType.shop:
        return 'property_type_shop'.tr;
      case PropertyType.warehouse:
        return 'property_type_warehouse'.tr;
      default:
        return 'property_type_default'.tr;
    }
  }

  String get propertyTypeTranslationKey {
    switch (propertyType) {
      case PropertyType.house:
        return 'house';
      case PropertyType.apartment:
        return 'apartment';
      case PropertyType.builderFloor:
        return 'builder_floor';
      case PropertyType.room:
        return 'room';
      case PropertyType.villa:
        return 'villa';
      case PropertyType.plot:
        return 'plot';
      case PropertyType.condo:
        return 'condo';
      case PropertyType.penthouse:
        return 'penthouse';
      case PropertyType.studio:
        return 'studio';
      case PropertyType.loft:
        return 'loft';
      case PropertyType.pg:
        return 'pg';
      case PropertyType.flatmate:
        return 'flatmate';
      case PropertyType.office:
        return 'office';
      case PropertyType.shop:
        return 'shop';
      case PropertyType.warehouse:
        return 'warehouse';
      default:
        return 'property';
    }
  }

  String get purposeString {
    switch (purpose) {
      case PropertyPurpose.buy:
        return 'Buy';
      case PropertyPurpose.rent:
        return 'Rent';
      case PropertyPurpose.shortStay:
        return 'Short Stay';
      default:
        return 'For Sale';
    }
  }

  String get purposeTranslationKey {
    switch (purpose) {
      case PropertyPurpose.buy:
        return 'buy';
      case PropertyPurpose.rent:
        return 'rent';
      case PropertyPurpose.shortStay:
        return 'short_stay';
      default:
        return 'sale';
    }
  }

  String get listingTranslationKey {
    switch (propertyType) {
      case PropertyType.pg:
        return 'pg';
      case PropertyType.flatmate:
        return 'flatmate';
      default:
        return purposeTranslationKey;
    }
  }

  String? get genderPreferenceTranslationKey {
    switch (listingPreferences?.genderPreference) {
      case ListingGenderPreference.any:
        return 'open_to_all';
      case ListingGenderPreference.male:
        return 'male_only';
      case ListingGenderPreference.female:
        return 'female_only';
      default:
        return null;
    }
  }

  String? get sharingTypeTranslationKey {
    switch (listingPreferences?.sharingType) {
      case ListingSharingType.privateRoom:
        return 'private_room';
      case ListingSharingType.sharedRoom:
        return 'shared_room';
      default:
        return null;
    }
  }

  String get statusString {
    switch (status) {
      case PropertyStatus.available:
        return 'Available';
      case PropertyStatus.sold:
        return 'Sold';
      case PropertyStatus.rented:
        return 'Rented';
      case PropertyStatus.underOffer:
        return 'Under Offer';
      case PropertyStatus.maintenance:
        return 'Maintenance';
      default:
        return 'Available';
    }
  }

  String get addressDisplay {
    if (fullAddress?.isNotEmpty == true) return fullAddress!;
    if (locality?.isNotEmpty == true && city?.isNotEmpty == true) {
      return '$locality, $city';
    }
    return city ?? 'Unknown Location';
  }

  // Short address that never exposes full_address. Prefer locality/subLocality + city.
  String get shortAddressDisplay {
    final parts = <String>[];
    if (locality != null && locality!.isNotEmpty) parts.add(locality!);
    if (subLocality != null && subLocality!.isNotEmpty) parts.add(subLocality!);
    if (city != null && city!.isNotEmpty) parts.add(city!);
    if (parts.isEmpty) return city ?? 'Unknown Location';
    return parts.join(', ');
  }

  List<PropertyImageModel> get _sortedImages {
    final sorted = [...(images ?? const <PropertyImageModel>[])];
    sorted.sort((a, b) {
      if (a.isPrimary != b.isPrimary) return a.isPrimary ? -1 : 1;
      return a.displayOrder.compareTo(b.displayOrder);
    });
    return sorted;
  }

  List<PropertyImageModel> get galleryImages =>
      _sortedImages.where((img) => img.isGallery && _looksLikeImageUrl(img.imageUrl)).toList();

  List<PropertyImageModel> get floorPlanImages =>
      _sortedImages.where((img) => img.isFloorPlan && _looksLikeImageUrl(img.imageUrl)).toList();

  String get mainImage {
    if (mainImageUrl?.isNotEmpty == true) return mainImageUrl!;
    final primary = _sortedImages.firstWhere(
      (img) => img.isPrimary && img.imageUrl.isNotEmpty,
      orElse: () => _sortedImages.isNotEmpty ? _sortedImages.first : PropertyImageModel.empty(),
    );
    if (primary.isValid) return primary.imageUrl;
    return '';
  }

  // Also make the imageUrls getter safer
  List<String> get imageUrls {
    final urls = <String>[];
    if (mainImageUrl?.isNotEmpty == true) urls.add(mainImageUrl!);
    for (final img in _sortedImages) {
      if (img.imageUrl.isNotEmpty) urls.add(img.imageUrl);
    }
    if (floorPlanUrl?.isNotEmpty == true) urls.add(floorPlanUrl!);
    return urls.toSet().toList();
  }

  // Images suitable for gallery (filter out known non-image URLs like 360 tour links)
  List<String> get galleryImageUrls {
    final candidates = <String>[...galleryImages.map((img) => img.imageUrl)];
    if (candidates.isEmpty && mainImageUrl?.isNotEmpty == true) {
      candidates.add(mainImageUrl!);
    }
    return candidates.toSet().toList();
  }

  List<String> get floorPlanImageUrls {
    final urls = <String>[
      if (floorPlanUrl?.isNotEmpty == true) floorPlanUrl!,
      ...floorPlanImages.map((img) => img.imageUrl),
    ];
    return urls.toSet().toList();
  }

  List<String> get mediaVideoUrls {
    final urls = <String>[];
    if (videoTourUrl?.isNotEmpty == true) urls.add(videoTourUrl!);
    if (videoUrls != null) {
      urls.addAll(videoUrls!.where((url) => url.isNotEmpty));
    }
    return urls.toSet().toList();
  }

  String? get primaryVideoUrl => mediaVideoUrls.isNotEmpty ? mediaVideoUrls.first : null;

  bool get hasVideos => mediaVideoUrls.isNotEmpty;
  bool get hasVideoTour => primaryVideoUrl != null;
  bool get hasPhotos => galleryImageUrls.isNotEmpty;
  bool get hasFloorPlan => floorPlanImageUrls.isNotEmpty;
  bool get hasAnyMedia => hasPhotos || hasVideos || hasVirtualTour || hasStreetView || hasFloorPlan;

  bool _looksLikeImageUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('kuula.co/share')) return false;
    final path = Uri.tryParse(lower)?.path ?? lower;
    return path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.webp') ||
        path.endsWith('.gif');
  }

  // Location convenience methods
  bool get hasLocation => latitude != null && longitude != null;
  bool get hasStreetView => streetViewLaunchUrl != null;

  String? get streetViewTarget {
    if (googleStreetViewUrl?.isNotEmpty == true) return googleStreetViewUrl;
    if (hasLocation) return '$latitude,$longitude';
    return null;
  }

  String? get streetViewLaunchUrl {
    final target = streetViewTarget;
    if (target == null) return null;
    if (googleStreetViewUrl?.isNotEmpty == true) return googleStreetViewUrl;
    return 'https://www.google.com/maps/@?api=1&map_action=pano&viewpoint=$latitude,$longitude';
  }

  String? get streetViewEmbedUrl =>
      googleStreetViewUrl != null && googleStreetViewUrl!.isNotEmpty ? googleStreetViewUrl : null;

  String? streetViewStaticImage(String apiKey, {int width = 640, int height = 320}) {
    if (apiKey.isEmpty) return null;
    final target = hasLocation ? '$latitude,$longitude' : null;
    if (target == null) return null;
    final size = '${width}x$height';
    final query = {
      'size': size,
      'location': target,
      'key': apiKey,
      'pitch': '0',
      'source': 'outdoor',
    };
    final uri = Uri.https('maps.googleapis.com', '/maps/api/streetview', query);
    return uri.toString();
  }

  // Amenities convenience methods
  bool get hasAmenities => amenities?.isNotEmpty == true;
  List<String> get amenitiesList => amenities?.map((a) => a.title).toList() ?? [];
  List<PropertyAmenity> get amenitiesData => amenities ?? [];

  // Virtual tour convenience methods
  bool get hasVirtualTour => virtualTourUrl?.isNotEmpty == true;

  // Agent/Owner convenience methods
  bool get hasOwner => ownerName?.isNotEmpty == true;
  String get ownerDisplayName => ownerName ?? 'Property Owner';
  bool get hasOwnerContact => ownerContact?.isNotEmpty == true;

  // Property details convenience methods
  String get bedroomBathroomText {
    if (bedrooms != null && bathrooms != null) {
      return '${bedrooms}BHK, $bathrooms Bath';
    } else if (bedrooms != null) {
      return '${bedrooms}BHK';
    } else if (bathrooms != null) {
      return '$bathrooms Bath';
    }
    return '';
  }

  String get areaText {
    if (areaSqft != null) {
      return '${areaSqft!.toStringAsFixed(0)} sq ft';
    }
    return '';
  }

  String get distanceText {
    if (distanceKm != null) {
      if (distanceKm! < 1) {
        return '${(distanceKm! * 1000).toStringAsFixed(0)}m away';
      } else {
        return '${distanceKm!.toStringAsFixed(1)}km away';
      }
    }
    return '';
  }

  // Get a fallback description for error widgets
  String get imageDescription {
    return '$propertyTypeString in ${city ?? 'Unknown Location'}';
  }

  // Get initials for fallback display
  String get titleInitials {
    final words = title.split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    } else if (words.isNotEmpty) {
      final String first = words[0];
      return first.isNotEmpty ? first.substring(0, 1).toUpperCase() : 'P';
    }
    return 'P';
  }

  // Floor information
  String get floorText {
    if (floorNumber != null && totalFloors != null) {
      return 'Floor $floorNumber/$totalFloors';
    } else if (floorNumber != null) {
      return 'Floor $floorNumber';
    }
    return '';
  }

  // Age information
  String get ageText {
    if (ageOfProperty != null) {
      if (ageOfProperty! == 0) {
        return 'New Construction';
      } else if (ageOfProperty! == 1) {
        return '1 year old';
      } else {
        return '$ageOfProperty years old';
      }
    }
    return '';
  }

  // User visit helpers
  bool get hasUserScheduled => userHasScheduledVisit || userNextVisitDate != null;

  // Parsed availability date helper
  DateTime? get availableFromDate {
    final v = availableFrom;
    if (v == null || v.isEmpty) return null;
    try {
      return DateTime.parse(v);
    } catch (_) {
      return null;
    }
  }
}
