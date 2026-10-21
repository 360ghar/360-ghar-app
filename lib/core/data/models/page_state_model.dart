// The page enums. The state of a page lives in the query providers
// (`propertyQueryProvider`, `propertyLocationProvider`). `PageStateModel` and
// `PageStateSnapshot` had no caller and are removed.

enum PageType { explore, discover, likes }

/// Where a page's selected location came from. Drives whether the location
/// update triggers a data refresh and/or reverse geocoding.
enum LocationSource {
  gps,
  ip,
  manual,
  initial,
  hydrate,
  gpsPassive,
  fallback;

  /// Persisted form (snake_case, matches historical storage values).
  String get stored => switch (this) {
    gpsPassive => 'gps_passive',
    _ => name,
  };

  static LocationSource tryParse(String? raw) => switch (raw) {
    'gps' => gps,
    'ip' => ip,
    'manual' => manual,
    'initial' => initial,
    'hydrate' => hydrate,
    'gps_passive' => gpsPassive,
    'fallback' => fallback,
    _ => manual,
  };
}
