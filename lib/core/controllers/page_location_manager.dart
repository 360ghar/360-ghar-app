import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/controllers/location_controller.dart';
import 'package:ghar360/core/controllers/page_data_loader.dart';
import 'package:ghar360/core/controllers/page_state_service.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/firebase/analytics_service.dart';
import 'package:ghar360/core/utils/app_toast.dart';
import 'package:ghar360/core/utils/debug_logger.dart';

/// Handles location updates, GPS position tracking, geocoding, and
/// location normalization for [PageStateService].
class PageLocationManager {
  final PageStateService _pageState;
  final PageDataLoader _dataLoader;
  final LocationController _locationController;
  final AuthController _authController;

  StreamSubscription? _locationSubscription;
  Position? _lastGpsPosition;
  Position? _lastGpsGeocodePosition;
  DateTime? _lastGpsRefreshAt;
  DateTime? _lastGpsGeocodeAt;

  /// Reverse-geocode results keyed by ~110m coordinate grid cells. Map pans
  /// repeatedly resolve names for nearby points; this keeps that at one
  /// platform geocode per cell. Bounded and rebuilt per session.
  final Map<String, String> _geocodeCache = {};

  String _geocodeCacheKey(double lat, double lng) {
    // ~0.001° ≈ 110 m; rounding gives a stable cell key for jittery pans.
    return '${lat.toStringAsFixed(3)}:${lng.toStringAsFixed(3)}';
  }

  static const Duration _gpsRefreshMinInterval = Duration(minutes: 3);
  static const double _gpsRefreshMinDistanceMeters = 300;
  static const Duration _gpsGeocodeMinInterval = Duration(minutes: 2);
  static const double _gpsGeocodeMinDistanceMeters = 150;

  PageLocationManager(
    this._pageState,
    this._dataLoader,
    this._locationController,
    this._authController,
  );

  void dispose() {
    _locationSubscription?.cancel();
  }

  /// Starts listening to GPS position updates.
  void setupLocationListener() {
    _locationSubscription?.cancel();
    _locationSubscription = _locationController.currentPosition.listen((position) {
      if (position == null) return;
      unawaited(_handleGpsPositionUpdate(position));
    });
  }

  /// Detects placeholder or non-human-friendly location names that
  /// should be reverse geocoded.
  bool isPlaceholderLocationName(String? name) {
    if (name == null) return true;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return true;
    final lower = trimmed.toLowerCase();
    return lower.startsWith('location (') ||
        lower == 'location coordinates' ||
        lower == 'current location' ||
        lower == 'current area' ||
        lower == 'selected area';
  }

  /// Ensure loaded states have a proper human-friendly location name.
  Future<void> normalizeSavedLocations() async {
    try {
      Future<void> fixFor(PageType page) async {
        final state = _pageState.getStateForPage(page);
        final loc = state.selectedLocation;
        if (loc != null && isPlaceholderLocationName(loc.name)) {
          final resolved = await _locationController.getAddressFromCoordinates(
            loc.latitude,
            loc.longitude,
          );
          final updated = state.copyWith(
            selectedLocation: LocationData(
              name: resolved,
              latitude: loc.latitude,
              longitude: loc.longitude,
            ),
            locationSource: state.locationSource == LocationSource.manual
                ? LocationSource.hydrate
                : state.locationSource,
          );
          _pageState.updatePageState(page, updated);
        }
      }

      await Future.wait([
        fixFor(PageType.explore),
        fixFor(PageType.discover),
        fixFor(PageType.likes),
      ]);

      DebugLogger.success('🔤 Normalized saved location names where needed');
    } catch (e, st) {
      DebugLogger.warning('Failed to normalize saved locations: $e');
      DebugLogger.warning(st.toString());
    }
  }

  // Update location only for a specific page
  Future<void> updateLocationForPage(
    PageType pageType,
    LocationData location, {
    LocationSource source = LocationSource.manual,
  }) async {
    DebugLogger.info(
      '📍 Updating location for ${pageType.name}: ${location.name} '
      '(${location.latitude}, ${location.longitude}) from $source',
    );

    // Resolve human-friendly name if placeholder
    LocationData finalLocation = location;
    final shouldResolveName = source.resolvesName;
    if (shouldResolveName && isPlaceholderLocationName(location.name)) {
      final cacheKey = _geocodeCacheKey(location.latitude, location.longitude);
      final cachedName = _geocodeCache[cacheKey];
      if (cachedName != null) {
        finalLocation = LocationData(
          name: cachedName,
          latitude: location.latitude,
          longitude: location.longitude,
        );
      } else {
        try {
          final resolvedName = await _locationController.getAddressFromCoordinates(
            location.latitude,
            location.longitude,
          );
          // Keep the cache bounded: one entry per grid cell, cleared wholesale
          // on the rare overflow rather than growing without limit.
          if (_geocodeCache.length >= 128) _geocodeCache.clear();
          _geocodeCache[cacheKey] = resolvedName;
          finalLocation = LocationData(
            name: resolvedName,
            latitude: location.latitude,
            longitude: location.longitude,
          );
          DebugLogger.info('🧭 Resolved location name to "$resolvedName"');
        } catch (e, st) {
          DebugLogger.warning('Reverse geocoding failed, keeping provided name. $e');
          DebugLogger.warning(st.toString());
        }
      }
    }

    final current = _pageState.getStateForPage(pageType);
    final updated = current.copyWith(selectedLocation: finalLocation, locationSource: source);
    _pageState.updatePageState(pageType, updated);

    // Only trigger a data refresh if the source is not passive/initial
    if (source.triggersRefresh) {
      DebugLogger.info('🔄 Debouncing refresh for ${pageType.name} after location update');
      try {
        AnalyticsService.locationChanged(source: source.stored);
      } catch (e, st) {
        DebugLogger.warning('Analytics locationChanged failed', e, st);
      }
      _dataLoader.debounceRefresh(pageType);
    } else {
      DebugLogger.info('Skipping refresh for passive or initial location update.');
    }
  }

  // Location management
  Future<void> updateLocation(
    LocationData location, {
    LocationSource source = LocationSource.manual,
  }) async {
    try {
      // Update backend if authenticated
      if (_authController.isAuthenticated) {
        await _authController.updateUserLocation({
          'current_latitude': location.latitude,
          'current_longitude': location.longitude,
        });
      }
      // Update only current page to keep independent state per page
      await updateLocationForPage(_pageState.currentPageType.value, location, source: source);

      DebugLogger.success('✅ Location updated: ${location.name}');
    } catch (e) {
      DebugLogger.error('Failed to update location: $e');
    }
  }

  Future<void> useCurrentLocation() async {
    try {
      await _locationController.getCurrentLocation(forceRefresh: true);
      final position = _locationController.currentPosition.value;
      if (position != null) {
        // Get real address from coordinates
        final locationName = await _locationController.getAddressFromCoordinates(
          position.latitude,
          position.longitude,
        );
        final location = LocationData(
          name: locationName,
          latitude: position.latitude,
          longitude: position.longitude,
        );
        await updateLocation(location, source: LocationSource.gps);
      }
    } catch (e) {
      DebugLogger.error('Failed to get current location: $e');
      AppToast.error('location_error'.tr, 'unable_to_get_current_location'.tr);
    }
  }

  // Page-specific current location (with IP fallback).
  //
  // A fresh cached position (<2 min old) is reused as-is so activating a page
  // never blocks the first properties fetch on a full GPS fix; the live GPS
  // stream keeps refining the location afterwards via [_handleGpsPositionUpdate].
  Future<void> useCurrentLocationForPage(PageType pageType) async {
    try {
      final cached = _locationController.currentPosition.value;
      if (cached == null) {
        // Nothing usable yet — ask for a real fix.
        await _locationController.getCurrentLocation();
      }
      final position = _locationController.currentPosition.value;
      if (position != null) {
        // Get real address from coordinates
        final locationName = await _locationController.getAddressFromCoordinates(
          position.latitude,
          position.longitude,
        );
        final loc = LocationData(
          name: locationName,
          latitude: position.latitude,
          longitude: position.longitude,
        );
        await updateLocationForPage(pageType, loc, source: LocationSource.gps);
        return;
      }

      // Fallback to IP-based location
      final ipLoc = await _locationController.getIpLocation();
      if (ipLoc != null) {
        await updateLocationForPage(pageType, ipLoc, source: LocationSource.ip);
        return;
      }
    } catch (e) {
      DebugLogger.warning('IP fallback failed for ${pageType.name}: $e');
    }
  }

  double _distanceMeters(Position a, Position b) {
    return Geolocator.distanceBetween(a.latitude, a.longitude, b.latitude, b.longitude);
  }

  Future<void> _handleGpsPositionUpdate(Position position) async {
    final now = DateTime.now();
    final last = _lastGpsPosition;
    _lastGpsPosition = position;

    final movedMeters = last == null ? double.infinity : _distanceMeters(last, position);
    final shouldRefresh =
        movedMeters >= _gpsRefreshMinDistanceMeters ||
        _lastGpsRefreshAt == null ||
        now.difference(_lastGpsRefreshAt!) >= _gpsRefreshMinInterval;

    final lastGeocode = _lastGpsGeocodePosition;
    final geocodeMoved = lastGeocode == null
        ? double.infinity
        : _distanceMeters(lastGeocode, position);
    final shouldGeocode =
        _lastGpsGeocodeAt == null ||
        geocodeMoved >= _gpsGeocodeMinDistanceMeters ||
        now.difference(_lastGpsGeocodeAt!) >= _gpsGeocodeMinInterval;

    final pageType = _pageState.currentPageType.value;
    final currentState = _pageState.getStateForPage(pageType);

    String locationName;
    if (shouldGeocode) {
      locationName = await _locationController.getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );
      _lastGpsGeocodeAt = now;
      _lastGpsGeocodePosition = position;
    } else {
      locationName =
          currentState.selectedLocation?.name ?? _locationController.currentAddress.value;
      if (locationName.isEmpty) {
        locationName = 'location_found'.tr;
      }
    }

    final loc = LocationData(
      name: locationName,
      latitude: position.latitude,
      longitude: position.longitude,
    );

    await updateLocationForPage(
      pageType,
      loc,
      source: shouldRefresh ? LocationSource.gps : LocationSource.gpsPassive,
    );

    if (shouldRefresh) {
      _lastGpsRefreshAt = now;
    }
  }
}
