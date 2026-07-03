import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:ghar360/core/controllers/page_state_service.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/utils/app_toast.dart';

class PropertyFilterWidget extends StatelessWidget {
  final String pageType; // 'discover', 'explore', 'likes'
  final VoidCallback? onFiltersApplied;

  const PropertyFilterWidget({super.key, required this.pageType, this.onFiltersApplied});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.tune, color: AppDesign.iconColor),
      onPressed: () => _showFilterBottomSheet(context),
    );
  }

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppDesign.transparent,
      useSafeArea: true,
      builder: (context) =>
          _FilterBottomSheet(pageType: pageType, onFiltersApplied: onFiltersApplied),
    );
  }
}

class _FilterBottomSheet extends StatefulWidget {
  final String pageType;
  final VoidCallback? onFiltersApplied;

  const _FilterBottomSheet({required this.pageType, this.onFiltersApplied});

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  late final PageStateService pageStateService;
  late final PageType _targetPageType;

  late String _selectedPurpose;
  late double _minPrice;
  late double _maxPrice;
  late int _minBedrooms;
  late int _maxBedrooms;
  late List<String> _selectedPropertyTypes;
  late List<String> _selectedAmenities;
  late String _selectedGenderPreference;
  late String _selectedSharingType;

  final List<String> purposes = ['buy', 'rent', 'short_stay'];

  final List<String> propertyTypes = [
    'all',
    'apartment',
    'house',
    'builder_floor',
    'room',
    'villa',
    'plot',
    'condo',
    'penthouse',
    'studio',
    'loft',
    'pg',
    'flatmate',
    'office',
    'shop',
    'warehouse',
  ];

  final List<String> amenitiesList = [
    'Gym',
    'Pool',
    'Parking',
    'Balcony',
    'Garden',
    'Security',
    'Elevator',
    'Terrace',
    'Club House',
    'Kids Play Area',
    'Power Backup',
    'Water Supply',
  ];

  @override
  void initState() {
    super.initState();
    _targetPageType = _resolvePageType(widget.pageType);
    // Guard PageStateService lookup to prevent runtime exceptions
    if (Get.isRegistered<PageStateService>()) {
      pageStateService = Get.find<PageStateService>();
      _initializeFilters();
    } else {
      // Initialize with defaults if PageStateService is not available
      _initializeFiltersWithDefaults();
    }
  }

  void _initializeFilters() {
    final currentFilter = pageStateService.getStateForPage(_targetPageType).filters;
    _selectedPurpose = _mapPurpose(currentFilter.purpose ?? 'buy');
    // Clamp values to ensure they're within the slider range
    final maxRange = _getPriceMax(currentFilter.purpose ?? 'buy');
    _minPrice = (currentFilter.priceMin ?? _getPriceMin(currentFilter.purpose ?? 'buy')).clamp(
      0.0,
      maxRange,
    );
    _maxPrice = (currentFilter.priceMax ?? _getPriceMax(currentFilter.purpose ?? 'buy')).clamp(
      0.0,
      maxRange,
    );
    _minBedrooms = (currentFilter.bedroomsMin ?? 0).clamp(0, 10);
    _maxBedrooms = (currentFilter.bedroomsMax ?? 10).clamp(0, 10);
    _selectedPropertyTypes = UnifiedFilterModel.normalizePropertyTypes(
      currentFilter.propertyType ?? const <String>[],
    );
    _selectedAmenities = List<String>.from(currentFilter.amenities ?? []);
    _selectedGenderPreference =
        UnifiedFilterModel.normalizeGenderPreferenceToken(currentFilter.genderPreference) ?? '';
    _selectedSharingType =
        UnifiedFilterModel.normalizeSharingTypeToken(currentFilter.sharingType) ?? '';
    if (!_hasPgOrFlatmateSelection) {
      _selectedGenderPreference = '';
      _selectedSharingType = '';
    }
  }

  PageType _resolvePageType(String value) {
    switch (value.trim().toLowerCase()) {
      case 'discover':
      case 'home':
        return PageType.discover;
      case 'likes':
      case 'favourites':
      case 'favorites':
        return PageType.likes;
      case 'explore':
      default:
        return PageType.explore;
    }
  }

  void _initializeFiltersWithDefaults() {
    // Initialize with sensible defaults when PageStateService is not available
    _selectedPurpose = 'buy';
    _minPrice = _getPriceMin('buy');
    _maxPrice = _getPriceMax('buy');
    _minBedrooms = 0;
    _maxBedrooms = 10;
    _selectedPropertyTypes = <String>[];
    _selectedAmenities = <String>[];
    _selectedGenderPreference = '';
    _selectedSharingType = '';
  }

  String _mapPurpose(String purpose) {
    switch (purpose) {
      case 'buy':
        return 'buy';
      case 'rent':
        return 'rent';
      case 'short_stay':
        return 'short_stay';
      default:
        return 'buy';
    }
  }

  String _mapPurposeToApi(String purpose) {
    return purpose;
  }

  bool get _hasPgOrFlatmateSelection =>
      _selectedPropertyTypes.any((type) => type == 'pg' || type == 'flatmate');

  bool _isPropertyTypeSelected(String type) {
    if (type == 'all') {
      return _selectedPropertyTypes.isEmpty;
    }
    return _selectedPropertyTypes.contains(type);
  }

  void _togglePropertyType(String type) {
    setState(() {
      if (type == 'all') {
        _selectedPropertyTypes = <String>[];
        _selectedGenderPreference = '';
        _selectedSharingType = '';
        return;
      }

      final nextTypes = List<String>.from(_selectedPropertyTypes);
      if (nextTypes.contains(type)) {
        nextTypes.remove(type);
      } else {
        if ((type == 'pg' || type == 'flatmate') && _selectedPurpose != 'rent') {
          _selectedPurpose = 'rent';
          _minPrice = _getPriceMin('rent');
          _maxPrice = _getPriceMax('rent');
        }
        nextTypes.add(type);
      }

      _selectedPropertyTypes = nextTypes;
      if (!_hasPgOrFlatmateSelection) {
        _selectedGenderPreference = '';
        _selectedSharingType = '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPurposeFilter(),
                  const SizedBox(height: 30),
                  _buildPriceFilter(),
                  const SizedBox(height: 30),
                  _buildBedroomsFilter(),
                  const SizedBox(height: 30),
                  _buildPropertyTypeFilter(),
                  const SizedBox(height: 30),
                  if (_hasPgOrFlatmateSelection) ...[
                    _buildListingPreferencesFilter(),
                    const SizedBox(height: 30),
                  ],
                  _buildAmenitiesFilter(),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppDesign.border, width: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'filter_properties'.tr,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppDesign.textPrimary,
            ),
          ),
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
        ],
      ),
    );
  }

  Widget _buildPurposeFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'purpose'.tr,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppDesign.textPrimary),
        ),
        const SizedBox(height: 15),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: purposes.map((purpose) {
            final isSelected = _selectedPurpose == purpose;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedPurpose = purpose;
                  // Update price range based on new purpose
                  _minPrice = _getPriceMin(_mapPurposeToApi(purpose));
                  _maxPrice = _getPriceMax(_mapPurposeToApi(purpose));
                  if (purpose != 'rent') {
                    _selectedPropertyTypes.removeWhere(
                      (type) => type == 'pg' || type == 'flatmate',
                    );
                    _selectedGenderPreference = '';
                    _selectedSharingType = '';
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: isSelected ? AppDesign.primaryYellow : AppDesign.inputBackground,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isSelected ? AppDesign.primaryYellow : AppDesign.border,
                    width: 2,
                  ),
                ),
                child: Text(
                  purpose.tr,
                  style: TextStyle(
                    fontSize: 16,
                    color: isSelected ? AppDesign.surface : AppDesign.textPrimary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPriceFilter() {
    final priceLabel = _selectedPurpose == 'rent'
        ? 'price_per_month'.tr
        : _selectedPurpose == 'short_stay'
        ? 'daily_rate'.tr
        : 'property_price'.tr;
    final minRange = _getPriceMin(_mapPurposeToApi(_selectedPurpose));
    final maxRange = _getPriceMax(_mapPurposeToApi(_selectedPurpose));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          priceLabel,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppDesign.textPrimary),
        ),
        const SizedBox(height: 15),
        RangeSlider(
          values: RangeValues(
            _minPrice.clamp(minRange, maxRange),
            _maxPrice.clamp(minRange, maxRange),
          ),
          min: minRange,
          max: maxRange,
          divisions: 100,
          activeColor: AppDesign.primaryYellow,
          inactiveColor: AppDesign.primaryYellow.withValues(alpha: 0.2),
          labels: RangeLabels('₹${_formatPrice(_minPrice)}', '₹${_formatPrice(_maxPrice)}'),
          onChanged: (RangeValues values) {
            setState(() {
              _minPrice = values.start;
              _maxPrice = values.end;
            });
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '₹${_formatPrice(_minPrice)}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppDesign.textPrimary,
              ),
            ),
            Text(
              '₹${_formatPrice(_maxPrice)}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppDesign.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBedroomsFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'bedrooms'.tr,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppDesign.textPrimary),
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'min_bedrooms'.tr,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                      color: AppDesign.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: _minBedrooms,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppDesign.border),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: List.generate(6, (index) => index)
                        .map(
                          (bedroom) => DropdownMenuItem(
                            value: bedroom,
                            child: Text(bedroom == 0 ? 'any'.tr : '$bedroom+'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _minBedrooms = value!;
                        if (_maxBedrooms < _minBedrooms) {
                          _maxBedrooms = _minBedrooms;
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'max_bedrooms'.tr,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                      color: AppDesign.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: _maxBedrooms,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppDesign.border),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: List.generate(11, (index) => index)
                        .where((bedroom) => bedroom >= _minBedrooms)
                        .map(
                          (bedroom) => DropdownMenuItem(
                            value: bedroom,
                            child: Text(bedroom == 10 ? '10+' : '$bedroom'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _maxBedrooms = value!;
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPropertyTypeFilter() {
    final typesToShow = propertyTypes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'property_type'.tr,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppDesign.textPrimary),
        ),
        const SizedBox(height: 15),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: typesToShow.map((type) {
            final isSelected = _isPropertyTypeSelected(type);
            return GestureDetector(
              onTap: () => _togglePropertyType(type),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? AppDesign.primaryYellow : AppDesign.inputBackground,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: isSelected ? AppDesign.primaryYellow : AppDesign.border,
                  ),
                ),
                child: Text(
                  _displayPropertyType(type),
                  style: TextStyle(
                    fontSize: 14,
                    color: isSelected ? AppDesign.surface : AppDesign.textPrimary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildListingPreferencesFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'pg_flatmate_preferences'.tr,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppDesign.textPrimary),
        ),
        const SizedBox(height: 15),
        DropdownButtonFormField<String>(
          initialValue: _selectedGenderPreference.isNotEmpty ? _selectedGenderPreference : null,
          decoration: InputDecoration(
            labelText: 'gender_preference'.tr,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppDesign.border),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: [
            DropdownMenuItem<String>(value: '', child: Text('any_gender'.tr)),
            DropdownMenuItem<String>(value: 'any', child: Text('open_to_all'.tr)),
            DropdownMenuItem<String>(value: 'male', child: Text('male_only'.tr)),
            DropdownMenuItem<String>(value: 'female', child: Text('female_only'.tr)),
          ],
          onChanged: (value) {
            setState(() {
              _selectedGenderPreference = value ?? '';
            });
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _selectedSharingType.isNotEmpty ? _selectedSharingType : null,
          decoration: InputDecoration(
            labelText: 'room_type'.tr,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppDesign.border),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: [
            DropdownMenuItem<String>(value: '', child: Text('any_room_type'.tr)),
            DropdownMenuItem<String>(value: 'private_room', child: Text('private_room'.tr)),
            DropdownMenuItem<String>(value: 'shared_room', child: Text('shared_room'.tr)),
          ],
          onChanged: (value) {
            setState(() {
              _selectedSharingType = value ?? '';
            });
          },
        ),
      ],
    );
  }

  Widget _buildAmenitiesFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'amenities'.tr,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppDesign.textPrimary),
        ),
        const SizedBox(height: 15),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: amenitiesList.map((amenity) {
            final isSelected = _selectedAmenities.contains(amenity);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedAmenities.remove(amenity);
                  } else {
                    _selectedAmenities.add(amenity);
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppDesign.primaryYellow.withValues(alpha: 0.1)
                      : AppDesign.inputBackground,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? AppDesign.primaryYellow : AppDesign.border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected)
                      const Icon(Icons.check_circle, size: 16, color: AppDesign.primaryYellow),
                    if (isSelected) const SizedBox(width: 6),
                    Text(
                      _displayAmenity(amenity),
                      style: TextStyle(
                        fontSize: 14,
                        color: isSelected ? AppDesign.primaryYellow : AppDesign.textPrimary,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppDesign.border, width: 0.2)),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _clearFilters,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: AppDesign.primaryYellow),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'clear_filters'.tr,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppDesign.primaryYellow,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _applyFilters,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppDesign.primaryYellow,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'apply_filters'.tr,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppDesign.surface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _clearFilters() {
    setState(() {
      final p = Get.isRegistered<PageStateService>()
          ? _mapPurpose(pageStateService.getStateForPage(_targetPageType).filters.purpose ?? 'buy')
          : 'buy';
      _selectedPurpose = p;
      _minPrice = _getPriceMin(p);
      _maxPrice = _getPriceMax(p);
      _minBedrooms = 0;
      _maxBedrooms = 10;
      _selectedPropertyTypes = <String>[];
      _selectedAmenities.clear();
      _selectedGenderPreference = '';
      _selectedSharingType = '';
    });
  }

  void _applyFilters() {
    // Apply filters only if PageStateService is available
    if (Get.isRegistered<PageStateService>()) {
      final currentFilters = pageStateService.getStateForPage(_targetPageType).filters;

      final updatedFilters = currentFilters.copyWith(
        purpose: _mapPurposeToApi(_selectedPurpose),
        priceMin: _minPrice,
        priceMax: _maxPrice,
        bedroomsMin: _minBedrooms,
        bedroomsMax: _maxBedrooms,
        propertyType: List<String>.from(_selectedPropertyTypes),
        amenities: _selectedAmenities,
        genderPreference: _hasPgOrFlatmateSelection ? _selectedGenderPreference : '',
        sharingType: _hasPgOrFlatmateSelection ? _selectedSharingType : '',
      );

      pageStateService.updatePageFilters(_targetPageType, updatedFilters);
    }

    Navigator.pop(context);

    if (widget.onFiltersApplied != null) {
      widget.onFiltersApplied!();
    }

    AppToast.success('filters_applied'.tr, 'filters_applied_message'.tr);
  }

  String _displayPropertyType(String type) {
    switch (type) {
      case 'all':
        return 'all'.tr;
      case 'apartment':
      case 'house':
      case 'condo':
      case 'penthouse':
      case 'villa':
      case 'studio':
      case 'loft':
      case 'pg':
      case 'flatmate':
      case 'office':
      case 'shop':
      case 'warehouse':
      case 'room':
      case 'plot':
        return type.tr;
      case 'builder_floor':
        return 'builder_floor'.tr;
      default:
        return type
            .replaceAll('_', ' ')
            .split(' ')
            .where((part) => part.isNotEmpty)
            .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
            .join(' ');
    }
  }

  String _displayAmenity(String amenity) {
    final map = {
      'Gym': 'amenity_gym',
      'Pool': 'amenity_pool',
      'Parking': 'amenity_parking',
      'Balcony': 'amenity_balcony',
      'Garden': 'amenity_garden',
      'Security': 'amenity_security',
      'Elevator': 'amenity_elevator',
      'Terrace': 'amenity_terrace',
      'Club House': 'amenity_club_house',
      'Kids Play Area': 'amenity_kids_play_area',
      'Power Backup': 'amenity_power_backup',
      'Water Supply': 'amenity_water_supply',
    };
    final key = map[amenity];
    return key != null ? key.tr : amenity;
  }

  // Helper methods for price ranges based on purpose
  double _getPriceMin(String purpose) {
    switch (purpose) {
      case 'rent':
        return 5000.0; // ₹5K per month
      case 'short_stay':
        return 500.0; // ₹500 per day
      case 'buy':
      default:
        return 500000.0; // ₹5L
    }
  }

  double _getPriceMax(String purpose) {
    switch (purpose) {
      case 'rent':
        return 500000.0; // ₹5L per month
      case 'short_stay':
        return 50000.0; // ₹50K per day
      case 'buy':
      default:
        return 150000000.0; // ₹15Cr
    }
  }

  String _formatPrice(double price) {
    if (price >= 10000000) {
      return '${(price / 10000000).toStringAsFixed(1)}Cr';
    } else if (price >= 100000) {
      return '${(price / 100000).toStringAsFixed(1)}L';
    } else if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(0)}K';
    } else {
      return price.toStringAsFixed(0);
    }
  }
}

// Public helper to show the same filter bottom sheet from anywhere
void showPropertyFilterBottomSheet(
  BuildContext context, {
  String pageType = 'explore',
  VoidCallback? onFiltersApplied,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppDesign.transparent,
    useSafeArea: true,
    builder: (ctx) => _FilterBottomSheet(pageType: pageType, onFiltersApplied: onFiltersApplied),
  );
}
