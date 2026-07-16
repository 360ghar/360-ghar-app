import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:ghar360/core/controllers/location_controller.dart';
import 'package:ghar360/core/data/models/popular_city.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/services/google_places_service.dart';
import 'package:ghar360/features/location_search/presentation/controllers/location_search_controller.dart';

class LocationSearchView extends GetView<LocationSearchController> {
  const LocationSearchView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('qa.location_search.screen'),
      appBar: AppBar(title: Text('search_location'.tr)),
      body: Column(
        children: [
          _buildSearchBar(context),
          _buildCurrentLocationTile(context),
          Expanded(child: _buildSuggestionsList(context)),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: AppDesign.shadowColor.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        key: const ValueKey('qa.location_search.search_input'),
        controller: controller.searchController,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'search_city_or_area_hint'.tr,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: Obx(
            () => controller.searchQuery.value.isNotEmpty
                ? IconButton(icon: const Icon(Icons.clear), onPressed: controller.clearSearch)
                : const SizedBox.shrink(),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Theme.of(context).dividerColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppDesign.primaryYellow, width: 2),
          ),
          filled: true,
          fillColor: Theme.of(context).scaffoldBackgroundColor,
        ),
        onChanged: controller.onSearchChanged,
      ),
    );
  }

  Widget _buildCurrentLocationTile(BuildContext context) {
    final locationController = Get.find<LocationController>();

    return Obx(() {
      if (!locationController.hasLocation) {
        return ListTile(
          key: const ValueKey('qa.location_search.use_current_location'),
          leading: const Icon(Icons.my_location, color: AppDesign.primaryYellow),
          title: Text('use_current_location'.tr),
          subtitle: Text('tap_to_get_current_location'.tr),
          onTap: controller.useCurrentLocation,
        );
      }

      return ListTile(
        key: const ValueKey('qa.location_search.use_current_location'),
        leading: const Icon(Icons.my_location, color: AppDesign.primaryYellow),
        title: Text('use_current_location'.tr),
        subtitle: Text(
          locationController.currentAddress.value.isNotEmpty
              ? locationController.currentAddress.value
              : 'location_found'.tr,
        ),
        onTap: controller.useCurrentLocation,
      );
    });
  }

  Widget _buildSuggestionsList(BuildContext context) {
    final locationController = Get.find<LocationController>();

    return Obx(() {
      if (controller.isLoading.value || locationController.isSearchingPlaces.value) {
        final query = controller.searchQuery.value.trim();
        final remote = locationController.placeSuggestions.toList(growable: false);
        final suggestions = PopularCity.mergeWithRemote(query, remote);
        // Keep showing known results (incl. popular cities) while a network
        // search is in flight instead of blanking the list.
        if (suggestions.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
      }

      if (controller.searchError.value.isNotEmpty) {
        final query = controller.searchQuery.value.trim();
        final popular = PopularCity.suggestionsForQuery(query);
        if (popular.isEmpty) {
          return _buildErrorState(context);
        }
      }

      final query = controller.searchQuery.value.trim();
      final remote = locationController.placeSuggestions.toList(growable: false);
      final suggestions = PopularCity.mergeWithRemote(query, remote);
      final popularOnly = PopularCity.suggestionsForQuery(query);
      final showPopularHeader = popularOnly.isNotEmpty && (remote.isEmpty || query.isEmpty);

      if (suggestions.isEmpty && query.isNotEmpty) {
        return _buildEmptyState(context);
      }

      if (suggestions.isEmpty) {
        return _buildSearchPrompt(context);
      }

      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: suggestions.length + (showPopularHeader ? 1 : 0),
        itemBuilder: (context, index) {
          if (showPopularHeader && index == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                'popular_cities'.tr,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).hintColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }
          final suggestionIndex = showPopularHeader ? index - 1 : index;
          final suggestion = suggestions[suggestionIndex];
          return _buildSuggestionTile(context, suggestion);
        },
      );
    });
  }

  Widget _buildSuggestionTile(BuildContext context, PlaceSuggestion suggestion) {
    final isPopular = PopularCity.isPopularPlaceId(suggestion.placeId);
    return ListTile(
      leading: Icon(
        isPopular ? Icons.location_city : Icons.location_on_outlined,
        color: isPopular ? AppDesign.primaryYellow : null,
      ),
      title: Text(suggestion.mainText),
      subtitle: suggestion.secondaryText.isNotEmpty ? Text(suggestion.secondaryText) : null,
      onTap: () => controller.selectPlace(suggestion),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Theme.of(context).disabledColor),
          const SizedBox(height: 16),
          Text('no_locations_found'.tr, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('try_search_different_location'.tr, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 16),
          Text(controller.searchError.value, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('try_search_different_location'.tr, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildSearchPrompt(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 64, color: Theme.of(context).disabledColor),
          const SizedBox(height: 16),
          Text(
            'search_city_or_area_hint'.tr,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
