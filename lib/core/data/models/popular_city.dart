import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/services/google_places_service.dart';

/// Curated quick-pick cities for location search (NCR focus).
///
/// Shown at the top of location pickers and merged into autocomplete so
/// common destinations are always one tap away even when Places APIs lag.
class PopularCity {
  final String name;
  final String region;
  final double latitude;
  final double longitude;

  /// Alternate spellings / names used for local filtering (e.g. Gurgaon/Gurugram).
  final List<String> aliases;

  const PopularCity({
    required this.name,
    required this.region,
    required this.latitude,
    required this.longitude,
    this.aliases = const [],
  });

  LocationData toLocationData() =>
      LocationData(name: name, latitude: latitude, longitude: longitude);

  PlaceSuggestion toPlaceSuggestion() {
    final placeId = 'popular:$name|$latitude|$longitude';
    return PlaceSuggestion(
      placeId: placeId,
      description: '$name, $region',
      mainText: name,
      secondaryText: region,
      latitude: latitude,
      longitude: longitude,
    );
  }

  bool matchesQuery(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (name.toLowerCase().contains(q)) return true;
    if (region.toLowerCase().contains(q)) return true;
    return aliases.any((a) => a.toLowerCase().contains(q));
  }

  static bool isPopularPlaceId(String placeId) => placeId.startsWith('popular:');

  /// Default popular cities for the India NCR market.
  static const List<PopularCity> defaults = [
    PopularCity(
      name: 'Gurgaon',
      region: 'Haryana, India',
      latitude: 28.4595,
      longitude: 77.0266,
      aliases: ['gurugram', 'gurgaon'],
    ),
    PopularCity(
      name: 'Noida',
      region: 'Uttar Pradesh, India',
      latitude: 28.5355,
      longitude: 77.3910,
      aliases: ['noida'],
    ),
    PopularCity(
      name: 'Delhi',
      region: 'Delhi, India',
      latitude: 28.6139,
      longitude: 77.2090,
      aliases: ['new delhi', 'delhi ncr', 'ncr'],
    ),
  ];

  /// Cities matching [query] (all when empty).
  static List<PopularCity> matching(String query) {
    return defaults.where((c) => c.matchesQuery(query)).toList(growable: false);
  }

  /// Place suggestions for UI lists, filtered by [query].
  static List<PlaceSuggestion> suggestionsForQuery(String query) {
    return matching(query).map((c) => c.toPlaceSuggestion()).toList(growable: false);
  }

  /// Merges popular matches ahead of remote suggestions, de-duplicating remote
  /// rows that collide with a popular city by exact case-insensitive main text.
  ///
  /// Remote rows are **not** de-duplicated against each other — two Places
  /// results can share a neighborhood-style `mainText` in different cities.
  /// Do not use substring matching — that drops areas like "Greater Noida"
  /// when popular "Noida" is present.
  static List<PlaceSuggestion> mergeWithRemote(String query, List<PlaceSuggestion> remote) {
    final popular = suggestionsForQuery(query);
    if (popular.isEmpty) return remote;

    final popularKeys = <String>{for (final p in popular) p.mainText.trim().toLowerCase()};

    final merged = <PlaceSuggestion>[...popular];
    for (final r in remote) {
      final key = r.mainText.trim().toLowerCase();
      if (key.isEmpty || popularKeys.contains(key)) continue;
      merged.add(r);
    }
    return merged;
  }

  /// Shared view-model for location pickers (modal + full-screen search).
  static PopularSuggestionsList buildSuggestionsList(String query, List<PlaceSuggestion> remote) {
    final popularCount = matching(query).length;
    final suggestions = mergeWithRemote(query, remote);
    final showPopularHeader = popularCount > 0 && (remote.isEmpty || query.trim().isEmpty);
    return PopularSuggestionsList(suggestions: suggestions, showPopularHeader: showPopularHeader);
  }
}

/// Result of merging popular cities with remote autocomplete for a query.
class PopularSuggestionsList {
  final List<PlaceSuggestion> suggestions;
  final bool showPopularHeader;

  const PopularSuggestionsList({required this.suggestions, required this.showPopularHeader});

  bool get isEmpty => suggestions.isEmpty;

  int get listItemCount => suggestions.length + (showPopularHeader ? 1 : 0);

  /// Returns null when [index] is the popular-cities header row.
  PlaceSuggestion? suggestionAt(int index) {
    if (showPopularHeader) {
      if (index == 0) return null;
      return suggestions[index - 1];
    }
    return suggestions[index];
  }
}
