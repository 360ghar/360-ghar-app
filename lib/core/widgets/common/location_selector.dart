import 'dart:async';

import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:ghar360/core/controllers/location_controller.dart';
import 'package:ghar360/core/controllers/page_state_service.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/services/google_places_service.dart';
import 'package:ghar360/core/utils/app_toast.dart';
import 'package:ghar360/core/utils/debug_logger.dart';

class LocationSelector extends GetView<LocationController> {
  final PageType pageType;

  const LocationSelector({super.key, required this.pageType});

  @override
  Widget build(BuildContext context) {
    final pageStateService = Get.find<PageStateService>();

    return Obx(() {
      final currentPageState = _getPageState(pageStateService);
      final locationText = currentPageState.locationDisplayText;
      final selectorId = 'qa.location.selector.trigger.${pageType.name}';

      return Semantics(
        label: locationText.isNotEmpty ? locationText : 'location'.tr,
        identifier: selectorId,
        button: true,
        child: GestureDetector(
          key: ValueKey(selectorId),
          onTap: () => _showLocationPicker(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppDesign.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppDesign.divider, width: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on, size: 16, color: AppDesign.primaryYellow),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    locationText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppDesign.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down, size: 16, color: AppDesign.textSecondary),
              ],
            ),
          ),
        ),
      );
    });
  }

  PageStateModel _getPageState(PageStateService pageStateService) {
    switch (pageType) {
      case PageType.explore:
        return pageStateService.exploreState.value;
      case PageType.discover:
        return pageStateService.discoverState.value;
      case PageType.likes:
        return pageStateService.likesState.value;
    }
  }

  void _showLocationPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppDesign.transparent,
      builder: (context) => LocationPickerModal(pageType: pageType),
    );
  }
}

class LocationPickerModal extends StatefulWidget {
  final PageType pageType;

  const LocationPickerModal({super.key, required this.pageType});

  @override
  State<LocationPickerModal> createState() => _LocationPickerModalState();
}

class _LocationPickerModalState extends State<LocationPickerModal> {
  final TextEditingController _searchController = TextEditingController();
  final LocationController locationController = Get.find<LocationController>();
  final PageStateService pageStateService = Get.find<PageStateService>();
  double? _radiusKm;
  Timer? _searchDebounce;
  bool _isSelectingPlace = false;
  bool _isUsingCurrentLocation = false;

  bool _hasOverlay() {
    final overlayContext = Get.overlayContext;
    if (overlayContext == null) return false;
    return Overlay.maybeOf(overlayContext) != null;
  }

  void _showSnackbarSafe({
    required String title,
    required String message,
    Duration? duration,
    Color? backgroundColor,
    Color? textColor,
  }) {
    if (!_hasOverlay()) {
      DebugLogger.warning('Skipped snackbar (no overlay): $title');
      return;
    }

    try {
      AppToast.custom(
        title: title,
        message: message,
        backgroundColor: backgroundColor ?? AppDesign.snackbarBackground,
        textColor: textColor,
        duration: duration ?? const Duration(seconds: 3),
      );
    } catch (e, stackTrace) {
      DebugLogger.error('Failed to show snackbar: $title', e, stackTrace);
    }
  }

  // Local helper to fetch the correct page state for this modal
  PageStateModel _getPageState(PageStateService service) {
    switch (widget.pageType) {
      case PageType.explore:
        return service.exploreState.value;
      case PageType.discover:
        return service.discoverState.value;
      case PageType.likes:
        return service.likesState.value;
    }
  }

  @override
  void initState() {
    super.initState();
    // Clear previous suggestions
    locationController.clearPlaceSuggestions();
    // Initialize radius from current page filters (default 10km)
    final pageState = _getPageState(pageStateService);
    _radiusKm = (pageState.filters.radiusKm ?? 10.0).clamp(5.0, 50.0).toDouble();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      locationController.clearPlaceSuggestions();
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      // Skip if the field was cleared/changed while the timer was pending.
      if (!mounted || _searchController.text.trim() != query.trim()) return;
      locationController.getPlaceSuggestions(query.trim());
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    locationController.clearPlaceSuggestions();
  }

  @override
  Widget build(BuildContext context) {
    final modalId = 'qa.location.selector.modal.${widget.pageType.name}';
    final viewInsets = MediaQuery.viewInsetsOf(context);
    return Semantics(
      label: 'select_location'.tr,
      identifier: modalId,
      child: Padding(
        padding: EdgeInsets.only(bottom: viewInsets.bottom),
        child: Material(
          key: ValueKey(modalId),
          color: AppDesign.scaffoldBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppDesign.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: AppDesign.primaryYellow),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'select_location'.tr,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppDesign.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: AppDesign.textSecondary),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                // Search bar
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppDesign.inputBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppDesign.divider, width: 0.5),
                  ),
                  child: Semantics(
                    label: 'qa.location.selector.search_input.${widget.pageType.name}',
                    identifier: 'qa.location.selector.search_input.${widget.pageType.name}',
                    child: TextField(
                      key: ValueKey('qa.location.selector.search_input.${widget.pageType.name}'),
                      controller: _searchController,
                      style: TextStyle(color: AppDesign.textPrimary),
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'search_location_hint'.tr,
                        hintStyle: TextStyle(color: AppDesign.textSecondary),
                        prefixIcon: Icon(Icons.search, color: AppDesign.iconColor),
                        suffixIcon: Obx(() {
                          if (locationController.isSearchingPlaces.value) {
                            return Container(
                              width: 20,
                              height: 20,
                              margin: const EdgeInsets.all(12),
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(AppDesign.primaryYellow),
                              ),
                            );
                          } else if (_searchController.text.isNotEmpty) {
                            return IconButton(
                              icon: Icon(Icons.clear, color: AppDesign.iconColor),
                              onPressed: _clearSearch,
                            );
                          }
                          return const SizedBox.shrink();
                        }),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Radius selector
                _buildRadiusSelector(),

                // Quick actions
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _buildQuickActionTile(
                        qaKey: 'qa.location.selector.use_current_location.${widget.pageType.name}',
                        icon: Icons.my_location,
                        title: 'use_current_location'.tr,
                        subtitle: 'get_location_from_gps'.tr,
                        iconColor: AppDesign.primaryYellow,
                        onTap: () => _useCurrentLocation(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Search results
                Expanded(
                  child: Obx(() {
                    final suggestions = locationController.placeSuggestions;
                    final placesError = locationController.placesError.value;
                    final isSearching = locationController.isSearchingPlaces.value;
                    final hasQuery = _searchController.text.trim().isNotEmpty;

                    if (isSearching && suggestions.isEmpty) {
                      return const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppDesign.primaryYellow),
                        ),
                      );
                    }

                    if (placesError.isNotEmpty && suggestions.isEmpty && hasQuery) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: AppDesign.errorRed),
                              const SizedBox(height: 16),
                              Text(
                                placesError,
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 16, color: AppDesign.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    if (suggestions.isEmpty && hasQuery) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.location_off, size: 48, color: AppDesign.textSecondary),
                            const SizedBox(height: 16),
                            Text(
                              'no_locations_found'.tr,
                              style: TextStyle(fontSize: 16, color: AppDesign.textSecondary),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: suggestions.length,
                      itemBuilder: (context, index) {
                        final suggestion = suggestions[index];
                        return _buildLocationTile(
                          title: suggestion.mainText,
                          subtitle: suggestion.secondaryText,
                          onTap: () => _selectPlaceSuggestion(suggestion),
                        );
                      },
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRadiusSelector() {
    final current = _getPageState(pageStateService);
    final radiusValue = (_radiusKm ?? current.filters.radiusKm ?? 10.0).clamp(5.0, 50.0).toDouble();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppDesign.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppDesign.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'search_radius'.tr,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppDesign.textPrimary,
                ),
              ),
              Text(
                '${radiusValue.toInt()} ${'km_unit'.tr}',
                style: TextStyle(fontSize: 12, color: AppDesign.textSecondary),
              ),
            ],
          ),
          Slider(
            value: radiusValue,
            min: 5,
            max: 50,
            divisions: 9, // 5,10,15,...,50
            label: '${radiusValue.toInt()} km',
            activeColor: AppDesign.primaryYellow,
            onChanged: (val) {
              setState(() => _radiusKm = val);
              final state = _getPageState(pageStateService);
              final updatedFilters = state.filters.copyWith(radiusKm: val);
              pageStateService.updatePageFilters(widget.pageType, updatedFilters);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionTile({
    String? qaKey,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Semantics(
      label: qaKey,
      identifier: qaKey,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        // Material so ListTile ink/tileColor are not blocked by parent DecoratedBox.
        child: Material(
          color: AppDesign.surface,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            key: qaKey != null ? ValueKey(qaKey) : null,
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            title: Text(
              title,
              style: TextStyle(fontWeight: FontWeight.w500, color: AppDesign.textPrimary),
            ),
            subtitle: Text(
              subtitle,
              style: TextStyle(color: AppDesign.textSecondary, fontSize: 12),
            ),
            trailing: Icon(Icons.arrow_forward_ios, size: 16, color: AppDesign.textSecondary),
            onTap: onTap,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationTile({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppDesign.transparent,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppDesign.accentBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.location_on, color: AppDesign.accentBlue, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.w500, color: AppDesign.textPrimary),
        ),
        subtitle: subtitle.isNotEmpty
            ? Text(subtitle, style: TextStyle(color: AppDesign.textSecondary, fontSize: 12))
            : null,
        onTap: onTap,
      ),
    );
  }

  void _useCurrentLocation() async {
    if (_isUsingCurrentLocation || _isSelectingPlace) return;
    _isUsingCurrentLocation = true;
    // Capture any theme-derived colors up-front to avoid using context across awaits
    final onErrorColor = Theme.of(context).colorScheme.onError;
    try {
      // Persist first; only dismiss the sheet after success (matches
      // LocationSearchController.useCurrentLocation).
      await pageStateService.useCurrentLocationForPage(widget.pageType);

      if (mounted) {
        Navigator.of(context).pop();
      }

      _showSnackbarSafe(
        title: 'location_updated'.tr,
        message: 'using_current_location'.tr,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      _showSnackbarSafe(
        title: 'error'.tr,
        message: 'unable_to_get_current_location'.tr,
        backgroundColor: AppDesign.errorRed,
        textColor: onErrorColor,
      );
    } finally {
      _isUsingCurrentLocation = false;
    }
  }

  void _selectPlaceSuggestion(PlaceSuggestion suggestion) async {
    if (_isSelectingPlace || _isUsingCurrentLocation) return;
    _isSelectingPlace = true;
    // Capture any theme-derived colors up-front to avoid using context across awaits
    final onErrorColor = Theme.of(context).colorScheme.onError;
    try {
      // Resolve details before closing so failures stay visible in the sheet.
      final locationData = await locationController.getPlaceDetails(
        suggestion.placeId,
        preferredName: suggestion.mainText,
      );
      if (locationData == null) {
        final detailError = locationController.placesError.value;
        _showSnackbarSafe(
          title: 'error'.tr,
          message: detailError.isNotEmpty ? detailError : 'unable_to_select_location'.tr,
          backgroundColor: AppDesign.errorRed,
          textColor: onErrorColor,
        );
        return;
      }

      // Persist first; only dismiss the sheet after success (matches
      // LocationSearchController.selectPlace).
      await pageStateService.updateLocationForPage(widget.pageType, locationData, source: 'manual');

      if (mounted) {
        Navigator.of(context).pop();
      }

      _showSnackbarSafe(
        title: 'location_selected'.tr,
        message: suggestion.mainText,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      _showSnackbarSafe(
        title: 'error'.tr,
        message: 'unable_to_select_location'.tr,
        backgroundColor: AppDesign.errorRed,
        textColor: onErrorColor,
      );
    } finally {
      _isSelectingPlace = false;
    }
  }
}
