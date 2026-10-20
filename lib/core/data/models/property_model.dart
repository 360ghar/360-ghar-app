import 'package:json_annotation/json_annotation.dart';

import 'package:ghar360/core/data/models/property_image_model.dart';
import 'package:ghar360/core/data/models/wire_enums.dart';
import 'package:ghar360/core/utils/indian_currency.dart';

export 'package:ghar360/core/data/models/wire_enums.dart'
    show
        FurnishingLevel,
        KitchenType,
        ListingGenderPreference,
        ListingSharingType,
        PropertyPurpose,
        PropertyStatus,
        PropertyType,
        VentilationType;

part 'property_model.g.dart';

/// An amenity of a listing. `id` is the amenity id, the value `amenity_ids` takes on a write.
@JsonSerializable()
class PropertyAmenity {
  final int id;
  final String title;
  final String? icon;
  final String? category;

  const PropertyAmenity({required this.id, required this.title, this.icon, this.category});

  factory PropertyAmenity.fromJson(Map<String, dynamic> json) => _$PropertyAmenityFromJson(json);
  Map<String, dynamic> toJson() => _$PropertyAmenityToJson(this);
}

/// The agent who handles a listing. Only `GET /properties/{id}` sends it;
/// lists, swipes and visits send null.
@JsonSerializable()
class PropertyAgent {
  final int id;
  final String name;
  @JsonKey(name: 'contact_number')
  final String? contactNumber;
  @JsonKey(name: 'avatar_url')
  final String? avatarUrl;

  const PropertyAgent({required this.id, required this.name, this.contactNumber, this.avatarUrl});

  factory PropertyAgent.fromJson(Map<String, dynamic> json) => _$PropertyAgentFromJson(json);
  Map<String, dynamic> toJson() => _$PropertyAgentToJson(this);
}

/// The public keys of `listing_preferences` that this app reads. An unknown enum value is null.
@JsonSerializable()
class ListingPreferences {
  @JsonKey(name: 'gender_preference')
  @ListingGenderPreferenceConverter()
  final ListingGenderPreference? genderPreference;
  @JsonKey(name: 'sharing_type')
  @ListingSharingTypeConverter()
  final ListingSharingType? sharingType;

  const ListingPreferences({this.genderPreference, this.sharingType});

  factory ListingPreferences.fromJson(Map<String, dynamic> json) =>
      _$ListingPreferencesFromJson(json);
  Map<String, dynamic> toJson() => _$ListingPreferencesToJson(this);
}

/// A `YYYY-MM-DD` value as a local calendar date. Anything else is a contract break.
DateTime? _dateOnlyFromJson(Object? value) {
  if (value == null) return null;
  final match = value is String ? RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value) : null;
  if (match == null) throw FormatException('Expected a YYYY-MM-DD date, got ${value.runtimeType}');
  return DateTime(int.parse(match[1]!), int.parse(match[2]!), int.parse(match[3]!));
}

String? _dateOnlyToJson(DateTime? value) {
  if (value == null) return null;
  String two(int part) => part.toString().padLeft(2, '0');
  return '${value.year.toString().padLeft(4, '0')}-${two(value.month)}-${two(value.day)}';
}

/// `Property` (list, search, swipes) and `PropertyDetail` (`GET /properties/{id}`).
///
/// A key the backend always sends is `required` here, so a renamed or dropped key fails the parse
/// instead of reading as a default. A field no screen shows (`ownerId`, the two timestamps) is
/// nullable in Dart so callers need not invent one, but its key is still required on the wire.
@JsonSerializable(explicitToJson: true, checked: true)
class PropertyModel {
  @JsonKey(required: true)
  final int id;
  @JsonKey(name: 'owner_id', required: true, disallowNullValue: true)
  final int? ownerId;
  @JsonKey(required: true)
  final String title;
  final String? description;
  @JsonKey(name: 'property_type', required: true)
  @PropertyTypeConverter()
  final PropertyType? propertyType;
  @JsonKey(required: true)
  @PropertyPurposeConverter()
  final PropertyPurpose? purpose;
  @JsonKey(name: 'base_price', required: true)
  final double basePrice;
  @JsonKey(required: true)
  @PropertyStatusConverter()
  final PropertyStatus? status;

  // Location fields
  final double? latitude;
  final double? longitude;
  final String? city;
  final String? state;
  @JsonKey(required: true)
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
  @JsonKey(name: 'furnishing_level')
  @FurnishingLevelConverter()
  final FurnishingLevel? furnishingLevel;
  @JsonKey(name: 'kitchen_type')
  @KitchenTypeConverter()
  final KitchenType? kitchenType;
  @JsonKey(name: 'ventilation_type')
  @VentilationTypeConverter()
  final VentilationType? ventilationType;
  @JsonKey(name: 'windows_count')
  final int? windowsCount;
  @JsonKey(name: 'ventilation_shafts')
  final int? ventilationShafts;

  // Pricing. The price a listing shows depends on its purpose (see [effectivePrice]).
  // `price_per_sqft` is computed by the backend from that price and the area.
  @JsonKey(name: 'price_per_sqft')
  final double? pricePerSqft;
  @JsonKey(name: 'monthly_rent')
  final double? monthlyRent;
  @JsonKey(name: 'daily_rate')
  final double? dailyRate;

  /// Per-night price of a short stay. Null for every other purpose.
  @JsonKey(name: 'nightly_rate')
  final double? nightlyRate;
  @JsonKey(name: 'security_deposit')
  final double? securityDeposit;
  @JsonKey(name: 'maintenance_charges')
  final double? maintenanceCharges;
  @JsonKey(name: 'setup_cost')
  final double? setupCost;
  @JsonKey(name: 'other_charges')
  final double? otherCharges;
  @JsonKey(name: 'other_charges_description')
  final String? otherChargesDescription;

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

  /// Photos. Floor plans are in [floorPlans].
  @JsonKey(name: 'images')
  final List<PropertyImageModel>? images;
  @JsonKey(name: 'floor_plans')
  final List<PropertyImageModel>? floorPlans;
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
  @JsonKey(name: 'is_available', required: true)
  final bool isAvailable;

  /// A calendar date (`YYYY-MM-DD`), not an instant.
  @JsonKey(name: 'available_from', fromJson: _dateOnlyFromJson, toJson: _dateOnlyToJson)
  final DateTime? availableFrom;
  @JsonKey(name: 'calendar_data')
  final Map<String, dynamic>? calendarData;

  // SEO and metadata
  final List<String>? tags;
  @JsonKey(name: 'owner_name')
  final String? ownerName;

  /// A phone number to call about the listing. The owner and admins get the owner's number.
  /// Everyone else gets the assigned agent's number, else the company number. Read it through
  /// [contactNumber], never as the owner's number.
  @JsonKey(name: 'owner_contact')
  final String? ownerContact;
  @JsonKey(name: 'builder_name')
  final String? builderName;
  final PropertyAgent? agent;

  // Performance metrics
  @JsonKey(name: 'view_count', required: true)
  final int viewCount;
  @JsonKey(name: 'like_count', required: true)
  final int likeCount;
  @JsonKey(name: 'interest_count', required: true)
  final int interestCount;

  // Timestamps (UTC)
  @JsonKey(name: 'created_at', required: true, disallowNullValue: true)
  final DateTime? createdAt;
  @JsonKey(name: 'updated_at', required: true, disallowNullValue: true)
  final DateTime? updatedAt;

  // Client-side calculated fields
  @JsonKey(name: 'distance_km')
  final double? distanceKm;

  // Swipe-related fields. The backend sends null where a flag does not apply.
  @JsonKey(name: 'liked', defaultValue: false)
  final bool liked;

  // User visit scheduling fields (the detail route only; the viewer's own visits)
  @JsonKey(name: 'user_has_scheduled_visit', defaultValue: false)
  final bool userHasScheduledVisit;
  @JsonKey(name: 'user_scheduled_visit_count', defaultValue: 0)
  final int userScheduledVisitCount;
  @JsonKey(name: 'user_next_visit_date')
  final DateTime? userNextVisitDate;

  const PropertyModel({
    required this.id,
    this.ownerId,
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
    this.furnishingLevel,
    this.kitchenType,
    this.ventilationType,
    this.windowsCount,
    this.ventilationShafts,
    this.pricePerSqft,
    this.monthlyRent,
    this.dailyRate,
    this.nightlyRate,
    this.securityDeposit,
    this.maintenanceCharges,
    this.setupCost,
    this.otherCharges,
    this.otherChargesDescription,
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
    this.floorPlans,
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
    this.agent,
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

  factory PropertyModel.fromJson(Map<String, dynamic> json) => _$PropertyModelFromJson(json);

  Map<String, dynamic> toJson() => _$PropertyModelToJson(this);

  /// The copy that is safe to keep on the device: no phone number of the owner, the agent or
  /// the company. The server marks property responses `private, no-store`.
  Map<String, dynamic> toStorableJson() {
    final json = toJson();
    json.remove('owner_contact');
    final agentJson = json['agent'];
    if (agentJson is Map<String, dynamic>) agentJson.remove('contact_number');
    return json;
  }

  /// Compact Indian-format price (e.g. `₹2.5 Cr`, `₹50.0 L`, `₹50,000`), or an empty string when
  /// the listing has no price for its purpose.
  ///
  /// Single-digit precision for crore/lakh forms; smaller amounts get Indian digit grouping.
  String get formattedPrice {
    final price = effectivePrice;
    return price == null ? '' : IndianCurrency.compact(price, fractionDigits: 1);
  }

  /// The price that matches the purpose: `monthly_rent` for rent, `nightly_rate` for a short
  /// stay, `base_price` for a sale. Null when that field is empty (or the purpose is unknown).
  /// There is no fallback to `base_price`: a short stay with no nightly rate has no nightly price.
  double? get effectivePrice => switch (purpose) {
    PropertyPurpose.rent => monthlyRent,
    PropertyPurpose.shortStay => nightlyRate,
    PropertyPurpose.buy => basePrice,
    null => null,
  };

  /// Plain type label for non-UI exports. Widgets use localizedType(context).

  String get propertyTypeLabelKey {
    switch (propertyType) {
      case PropertyType.house:
        return 'property_type_house';
      case PropertyType.apartment:
        return 'property_type_apartment';
      case PropertyType.builderFloor:
        return 'property_type_builder_floor';
      case PropertyType.room:
        return 'property_type_room';
      case PropertyType.villa:
        return 'property_type_villa';
      case PropertyType.plot:
        return 'property_type_plot';
      case PropertyType.condo:
        return 'property_type_condo';
      case PropertyType.penthouse:
        return 'property_type_penthouse';
      case PropertyType.studio:
        return 'property_type_studio';
      case PropertyType.loft:
        return 'property_type_loft';
      case PropertyType.pg:
        return 'property_type_pg';
      case PropertyType.flatmate:
        return 'property_type_flatmate';
      case PropertyType.office:
        return 'property_type_office';
      case PropertyType.shop:
        return 'property_type_shop';
      case PropertyType.warehouse:
        return 'property_type_warehouse';
      default:
        return 'property_type_default';
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

  String? get sharingTypeTranslationKey => switch (listingPreferences?.sharingType) {
    ListingSharingType.privateRoom => 'private_room',
    ListingSharingType.sharedRoom => 'shared_room',
    ListingSharingType.masterBedroom => 'master_bedroom',
    ListingSharingType.entireFlat => 'entire_flat',
    null => null,
  };

  /// English status label for non-UI exports. Empty for a status this app does not know.
  String get statusString => switch (status) {
    PropertyStatus.available => 'Available',
    PropertyStatus.sold => 'Sold',
    PropertyStatus.rented => 'Rented',
    PropertyStatus.underOffer => 'Under Offer',
    PropertyStatus.maintenance => 'Maintenance',
    null => '',
  };

  String get addressDisplay {
    if (fullAddress?.isNotEmpty == true) return fullAddress!;
    if (locality?.isNotEmpty == true && city?.isNotEmpty == true) {
      return '$locality, $city';
    }
    return city ?? '';
  }

  // Short address that never exposes full_address. Prefer locality/subLocality + city.
  String get shortAddressDisplay {
    final parts = <String>[];
    if (locality != null && locality!.isNotEmpty) parts.add(locality!);
    if (subLocality != null && subLocality!.isNotEmpty) parts.add(subLocality!);
    if (city != null && city!.isNotEmpty) parts.add(city!);
    // Empty when unknown: the UI hides the line rather than print a placeholder.
    if (parts.isEmpty) return '';
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

  /// Floor plans come from `floor_plans`; `images` holds photos only.
  List<PropertyImageModel> get floorPlanImages {
    final plans = [...(floorPlans ?? const <PropertyImageModel>[])]
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return plans.where((img) => _looksLikeImageUrl(img.imageUrl)).toList();
  }

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

  // Contact convenience methods
  /// The number to call about this listing. For the owner and admins it is the owner's number.
  /// For everyone else it is the assigned agent's number, else the company number. Never present
  /// it as the owner's number.
  String? get contactNumber {
    for (final number in [agent?.contactNumber, ownerContact]) {
      final trimmed = number?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  bool get hasContact => contactNumber != null;

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

  // User visit helpers
  bool get hasUserScheduled => userHasScheduledVisit || userNextVisitDate != null;
}
