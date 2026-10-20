import 'package:ghar360/core/data/models/wire_enums.dart';
import 'package:ghar360/core/utils/api_date_time.dart';
import 'package:json_annotation/json_annotation.dart';

export 'package:ghar360/core/data/models/wire_enums.dart' show SortBy;

part 'unified_filter_model.g.dart';

@JsonSerializable()
class UnifiedFilterModel {
  // Location-based filters
  // REMOVED: latitude and longitude are now handled by PageStateModel.selectedLocation
  @JsonKey(name: 'radius_km')
  final double? radiusKm;

  // Core property filters
  final String? purpose; // buy, rent, short_stay
  @JsonKey(name: 'property_type')
  final List<String>? propertyType;
  @JsonKey(name: 'price_min')
  final double? priceMin;
  @JsonKey(name: 'price_max')
  final double? priceMax;
  @JsonKey(name: 'bedrooms_min')
  final int? bedroomsMin;
  @JsonKey(name: 'bedrooms_max')
  final int? bedroomsMax;
  @JsonKey(name: 'bathrooms_min')
  final int? bathroomsMin;
  @JsonKey(name: 'bathrooms_max')
  final int? bathroomsMax;
  @JsonKey(name: 'area_min')
  final double? areaMin;
  @JsonKey(name: 'area_max')
  final double? areaMax;

  // Detailed property filters
  @JsonKey(name: 'parking_spaces_min')
  final int? parkingSpacesMin;
  @JsonKey(name: 'floor_number_min')
  final int? floorNumberMin;
  @JsonKey(name: 'floor_number_max')
  final int? floorNumberMax;
  @JsonKey(name: 'age_max')
  final int? ageMax;
  final List<String>? amenities;
  final List<String>? features;
  @JsonKey(name: 'gender_preference')
  final String? genderPreference;
  @JsonKey(name: 'sharing_type')
  final String? sharingType;

  // Availability & sorting
  @JsonKey(name: 'available_from')
  final DateTime? availableFrom;
  @JsonKey(name: 'check_in_date')
  final DateTime? checkInDate;
  @JsonKey(name: 'check_out_date')
  final DateTime? checkOutDate;
  final int? guests;
  @JsonKey(name: 'sort_by')
  @SortByConverter()
  final SortBy? sortBy;

  // Search query for text-based search
  @JsonKey(name: 'search_query')
  final String? searchQuery;
  @JsonKey(name: 'include_unavailable')
  final bool? includeUnavailable;

  // Additional filters for favorites
  @JsonKey(name: 'property_ids')
  final List<int>? propertyIds;

  const UnifiedFilterModel({
    this.radiusKm,
    this.purpose,
    this.propertyType,
    this.priceMin,
    this.priceMax,
    this.bedroomsMin,
    this.bedroomsMax,
    this.bathroomsMin,
    this.bathroomsMax,
    this.areaMin,
    this.areaMax,
    this.parkingSpacesMin,
    this.floorNumberMin,
    this.floorNumberMax,
    this.ageMax,
    this.amenities,
    this.features,
    this.genderPreference,
    this.sharingType,
    this.availableFrom,
    this.checkInDate,
    this.checkOutDate,
    this.guests,
    this.sortBy,
    this.searchQuery,
    this.includeUnavailable,
    this.propertyIds,
  });

  factory UnifiedFilterModel.initial() {
    return const UnifiedFilterModel(
      radiusKm: 10.0,
      // Default to 'buy' when no user preference is set
      purpose: 'buy',
      sortBy: null,
      includeUnavailable: false,
      propertyType: [],
      amenities: [],
      features: [],
    );
  }

  factory UnifiedFilterModel.fromJson(Map<String, dynamic> json) =>
      _$UnifiedFilterModelFromJson(json);

  /// Radius the backend accepts, in whole kilometres.
  static const minRadiusKm = 1;
  static const maxRadiusKm = 100;

  /// The radius to send: whole kilometres, kept between [minRadiusKm] and [maxRadiusKm].
  static int apiRadiusKm(double km) => km.round().clamp(minRadiusKm, maxRadiusKm);

  static final Set<String> _canonicalPropertyTypes = {
    for (final type in PropertyType.values) type.wire,
  };

  static const Map<String, List<String>> _propertyTypeAliases = <String, List<String>>{
    'builderfloor': <String>['builder_floor'],
    'builder_floor': <String>['builder_floor'],
    'builder-floor': <String>['builder_floor'],
    'flat': <String>['apartment'],
    'flats': <String>['apartment'],
    'apartments': <String>['apartment'],
    'apartment_flat': <String>['apartment'],
    'independent_house': <String>['house'],
    'independent-house': <String>['house'],
    'plots': <String>['plot'],
    'land': <String>['plot'],
    'office_space': <String>['office'],
    'office-space': <String>['office'],
    'showroom': <String>['shop'],
    'roommate': <String>['flatmate'],
  };

  static List<String> normalizePropertyTypeTokens(String? rawValue) {
    if (rawValue == null) return const <String>[];
    final normalized = rawValue.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
    if (normalized.isEmpty || normalized == 'all') return const <String>[];

    final mapped = _propertyTypeAliases[normalized] ?? <String>[normalized];
    return mapped.where(_canonicalPropertyTypes.contains).toList();
  }

  static String? normalizePropertyTypeToken(String? rawValue) {
    final normalized = normalizePropertyTypeTokens(rawValue);
    return normalized.isNotEmpty ? normalized.first : null;
  }

  static List<String> normalizePropertyTypes(Iterable<String>? values) {
    if (values == null) return const <String>[];
    return values.expand(normalizePropertyTypeTokens).toSet().toList();
  }

  static String? normalizePurposeToken(String? rawValue) {
    if (rawValue == null) return null;
    final normalized = rawValue.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
    if (normalized.isEmpty) return null;

    switch (normalized) {
      case 'buy':
      case 'rent':
      case 'short_stay':
      case 'shortstay':
        return normalized == 'shortstay' ? 'short_stay' : normalized;
      case 'pg':
        return 'rent';
      case 'investment':
        // Legacy UI option: closest supported backend value.
        return 'buy';
      default:
        return null;
    }
  }

  static String? normalizeGenderPreferenceToken(String? rawValue) {
    if (rawValue == null) return null;
    final normalized = rawValue.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    return ListingGenderPreference.fromJson(normalized)?.wire;
  }

  static String? normalizeSharingTypeToken(String? rawValue) {
    if (rawValue == null) return null;
    final normalized = rawValue.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
    if (normalized.isEmpty) return null;
    return ListingSharingType.fromJson(normalized)?.wire;
  }

  Map<String, dynamic> toApiQueryParams() {
    final json = toJson();
    final mapped = <String, dynamic>{};

    json.forEach((key, value) {
      if (value == null) return;

      switch (key) {
        // The backend reads the radius from `radius` (sent by the datasource)
        // and has no `include_unavailable` parameter; sending them does nothing.
        case 'radius_km':
        case 'include_unavailable':
          return;
        case 'property_type':
          if (value is List) {
            final normalized = normalizePropertyTypes(value.map((item) => item?.toString() ?? ''));
            if (normalized.isNotEmpty) {
              mapped[key] = normalized;
            }
          }
          return;
        case 'purpose':
          final normalizedPurpose = normalizePurposeToken(value.toString());
          if (normalizedPurpose != null) {
            mapped['purpose'] = normalizedPurpose;
          }
          return;
        case 'check_in_date':
          mapped['check_in'] = value;
          return;
        case 'check_out_date':
          mapped['check_out'] = value;
          return;
        case 'search_query':
          mapped['q'] = value;
          return;
        case 'gender_preference':
          final normalizedGender = normalizeGenderPreferenceToken(value.toString());
          if (normalizedGender != null) {
            mapped[key] = normalizedGender;
          }
          return;
        case 'sharing_type':
          final normalizedSharing = normalizeSharingTypeToken(value.toString());
          if (normalizedSharing != null) {
            mapped[key] = normalizedSharing;
          }
          return;
        case 'property_ids':
          if (value is List && value.isNotEmpty) {
            mapped['ids'] = value;
          }
          return;
        default:
          mapped[key] = value;
      }
    });

    // The backend takes `check_in` and `check_out` together; a lone date is a 422.
    if (mapped.containsKey('check_in') != mapped.containsKey('check_out')) {
      mapped
        ..remove('check_in')
        ..remove('check_out');
    }

    return mapped;
  }

  Map<String, dynamic> toJson() {
    final json = _$UnifiedFilterModelToJson(this);

    // Handle DateTime serialization properly for API
    if (availableFrom != null) {
      json['available_from'] = formatDateOnlyForApi(availableFrom); // YYYY-MM-DD format
    }
    if (checkInDate != null) {
      json['check_in_date'] = formatDateOnlyForApi(checkInDate); // YYYY-MM-DD format
    }
    if (checkOutDate != null) {
      json['check_out_date'] = formatDateOnlyForApi(checkOutDate); // YYYY-MM-DD format
    }

    // Ensure numeric values are within valid ranges
    if (radiusKm != null) json['radius_km'] = apiRadiusKm(radiusKm!).toDouble();
    if (priceMin != null && priceMin! < 0) {
      json.remove('price_min'); // Remove invalid price
    }
    if (priceMax != null && priceMax! < 0) {
      json.remove('price_max'); // Remove invalid price
    }
    if (bedroomsMin != null && bedroomsMin! < 0) {
      json.remove('bedrooms_min'); // Remove invalid bedrooms
    }
    if (bedroomsMax != null && bedroomsMax! < 0) {
      json.remove('bedrooms_max'); // Remove invalid bedrooms
    }
    if (bathroomsMin != null && bathroomsMin! < 0) {
      json.remove('bathrooms_min'); // Remove invalid bathrooms
    }
    if (bathroomsMax != null && bathroomsMax! < 0) {
      json.remove('bathrooms_max'); // Remove invalid bathrooms
    }
    if (areaMin != null && areaMin! < 0) {
      json.remove('area_min'); // Remove invalid area
    }
    if (areaMax != null && areaMax! < 0) {
      json.remove('area_max'); // Remove invalid area
    }
    if (guests != null && guests! <= 0) {
      json.remove('guests'); // Remove invalid guest count
    }

    // Remove null values and empty lists for cleaner API requests
    json.removeWhere(
      (key, value) =>
          value == null ||
          (value is List && value.isEmpty) ||
          (value is String && value.trim().isEmpty),
    );

    return json;
  }

  UnifiedFilterModel copyWith({
    double? radiusKm,
    String? purpose,
    List<String>? propertyType,
    double? priceMin,
    double? priceMax,
    int? bedroomsMin,
    int? bedroomsMax,
    int? bathroomsMin,
    int? bathroomsMax,
    double? areaMin,
    double? areaMax,
    int? parkingSpacesMin,
    int? floorNumberMin,
    int? floorNumberMax,
    int? ageMax,
    List<String>? amenities,
    List<String>? features,
    String? genderPreference,
    String? sharingType,
    DateTime? availableFrom,
    DateTime? checkInDate,
    DateTime? checkOutDate,
    int? guests,
    SortBy? sortBy,
    String? searchQuery,
    bool? includeUnavailable,
    List<int>? propertyIds,
  }) {
    return UnifiedFilterModel(
      radiusKm: radiusKm ?? this.radiusKm,
      purpose: purpose ?? this.purpose,
      propertyType: propertyType ?? this.propertyType,
      priceMin: priceMin ?? this.priceMin,
      priceMax: priceMax ?? this.priceMax,
      bedroomsMin: bedroomsMin ?? this.bedroomsMin,
      bedroomsMax: bedroomsMax ?? this.bedroomsMax,
      bathroomsMin: bathroomsMin ?? this.bathroomsMin,
      bathroomsMax: bathroomsMax ?? this.bathroomsMax,
      areaMin: areaMin ?? this.areaMin,
      areaMax: areaMax ?? this.areaMax,
      parkingSpacesMin: parkingSpacesMin ?? this.parkingSpacesMin,
      floorNumberMin: floorNumberMin ?? this.floorNumberMin,
      floorNumberMax: floorNumberMax ?? this.floorNumberMax,
      ageMax: ageMax ?? this.ageMax,
      amenities: amenities ?? this.amenities,
      features: features ?? this.features,
      genderPreference: genderPreference ?? this.genderPreference,
      sharingType: sharingType ?? this.sharingType,
      availableFrom: availableFrom ?? this.availableFrom,
      checkInDate: checkInDate ?? this.checkInDate,
      checkOutDate: checkOutDate ?? this.checkOutDate,
      guests: guests ?? this.guests,
      sortBy: sortBy ?? this.sortBy,
      searchQuery: searchQuery ?? this.searchQuery,
      includeUnavailable: includeUnavailable ?? this.includeUnavailable,
      propertyIds: propertyIds ?? this.propertyIds,
    );
  }

  // Helper method to count active filters
  int get activeFilterCount {
    int count = 0;
    if (priceMin != null || priceMax != null) count++;
    if (bedroomsMin != null || bedroomsMax != null) count++;
    if (bathroomsMin != null || bathroomsMax != null) count++;
    if (areaMin != null || areaMax != null) count++;
    if (propertyType != null && propertyType!.isNotEmpty) count++;
    if (genderPreference != null && genderPreference!.isNotEmpty) count++;
    if (sharingType != null && sharingType!.isNotEmpty) count++;
    if (amenities != null && amenities!.isNotEmpty) count++;
    if (features != null && features!.isNotEmpty) count++;
    if (parkingSpacesMin != null) count++;
    if (floorNumberMin != null || floorNumberMax != null) count++;
    if (ageMax != null) count++;
    return count;
  }
}

// Location data model for location selection
class LocationData {
  final String name;
  final double latitude;
  final double longitude;

  const LocationData({required this.name, required this.latitude, required this.longitude});

  factory LocationData.fromJson(Map<String, dynamic> json) {
    final latitude = (json['latitude'] as num?)?.toDouble();
    final longitude = (json['longitude'] as num?)?.toDouble();
    if (latitude == null || longitude == null) {
      // Defaulting to 0,0 ("Null Island") would silently break radius search;
      // treat coordinate-less data as invalid instead.
      throw FormatException('LocationData requires latitude and longitude: $json');
    }
    return LocationData(name: json['name'] ?? '', latitude: latitude, longitude: longitude);
  }

  /// Lenient variant for restoring persisted state: returns null (no location
  /// set) when coordinates are missing instead of throwing.
  static LocationData? tryFromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    try {
      return LocationData.fromJson(json);
    } on FormatException {
      return null;
    }
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'latitude': latitude, 'longitude': longitude};
  }
}
