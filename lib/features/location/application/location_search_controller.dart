import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghar360/core/bootstrap/provider_policy.dart';
import 'package:ghar360/core/config/app_config.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/services/google_places_service.dart';
import 'package:http/http.dart' as http;

final googlePlacesServiceProvider = Provider<GooglePlacesService>((ref) {
  final config = AppConfig.instance;
  final service = GooglePlacesService(
    client: http.Client(),
    apiKey: config.googlePlacesApiKey,
    country: config.defaultCountry,
    radiusMeters: int.tryParse(config.placesRadiusMeters) ?? 25000,
    strictBounds: config.placesStrictBounds,
  );
  ref.onDispose(service.dispose);
  return service;
}, retry: noProviderRetry);

class LocationSearchState {
  LocationSearchState({
    this.query = '',
    List<PlaceSuggestion> suggestions = const [],
    this.search = const AsyncData(null),
    this.selection = const AsyncData(null),
    this.usedFallback = false,
  }) : suggestions = List.unmodifiable(suggestions);
  final String query;
  final List<PlaceSuggestion> suggestions;
  final AsyncValue<void> search;
  final AsyncValue<void> selection;
  final bool usedFallback;
}

final locationSearchProvider = NotifierProvider.autoDispose
    .family<LocationSearchController, LocationSearchState, PageType>(
      LocationSearchController.new,
      retry: noProviderRetry,
    );

class LocationSearchController extends Notifier<LocationSearchState> {
  LocationSearchController(this.page);
  final PageType page;
  late GooglePlacesService _service;
  Timer? _debounce;
  int _generation = 0;
  int _selectionGeneration = 0;
  @override
  LocationSearchState build() {
    _service = ref.watch(googlePlacesServiceProvider);
    ref.watch(storageScopeProvider);
    ++_generation;
    ++_selectionGeneration;
    ref.onDispose(() {
      ++_generation;
      ++_selectionGeneration;
      _debounce?.cancel();
    });
    return LocationSearchState();
  }

  void updateQuery(String query) {
    _debounce?.cancel();
    ++_generation;
    ++_selectionGeneration;
    state = LocationSearchState(query: query);
    if (query.trim().length < 2) return;
    _debounce = Timer(const Duration(milliseconds: 400), () => unawaited(search(explicit: false)));
  }

  Future<void> search({bool explicit = true}) async {
    _debounce?.cancel();
    final query = state.query.trim();
    final generation = ++_generation;
    if (query.length < 2) return;
    state = LocationSearchState(
      query: state.query,
      suggestions: state.suggestions,
      search: const AsyncLoading(),
      usedFallback: state.usedFallback,
    );
    try {
      final results = await _service.getPlaceSuggestions(
        query,
        allowFallback: explicit,
        isCurrent: () => ref.mounted && generation == _generation,
      );
      if (!ref.mounted || generation != _generation) return;
      state = LocationSearchState(
        query: state.query,
        suggestions: results,
        usedFallback: results.any((item) => item.placeId.startsWith('osm:')),
      );
    } catch (error, stack) {
      if (!ref.mounted || generation != _generation) return;
      state = LocationSearchState(
        query: state.query,
        suggestions: state.suggestions,
        search: AsyncError(error, stack),
        usedFallback: state.usedFallback,
      );
    }
  }

  Future<LocationData?> resolve(PlaceSuggestion suggestion) async {
    if (state.selection.isLoading) return null;
    final generation = ++_selectionGeneration;
    state = LocationSearchState(
      query: state.query,
      suggestions: state.suggestions,
      search: state.search,
      selection: const AsyncLoading(),
      usedFallback: state.usedFallback,
    );
    try {
      final location = suggestion.hasCoordinates
          ? LocationData(
              name: suggestion.mainText,
              latitude: suggestion.latitude!,
              longitude: suggestion.longitude!,
            )
          : await _service.getPlaceDetails(suggestion.placeId, preferredName: suggestion.mainText);
      if (!ref.mounted || generation != _selectionGeneration) return null;
      state = LocationSearchState(
        query: state.query,
        suggestions: state.suggestions,
        search: state.search,
        usedFallback: state.usedFallback,
      );
      return location;
    } catch (error, stack) {
      if (!ref.mounted || generation != _selectionGeneration) return null;
      state = LocationSearchState(
        query: state.query,
        suggestions: state.suggestions,
        search: state.search,
        selection: AsyncError(error, stack),
        usedFallback: state.usedFallback,
      );
      return null;
    }
  }
}
