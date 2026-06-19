import 'dart:async';
import 'dart:convert';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/services/google_places_service.dart';
import 'package:ghar360/core/utils/app_toast.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:http/http.dart' as http;

class LocationController extends GetxController {
  late final AuthController _authController;

  final Rxn<Position> currentPosition = Rxn<Position>();
  final RxBool isLocationEnabled = false.obs;
  final RxBool isLocationPermissionGranted = false.obs;
  final RxBool isLoading = false.obs;
  final RxString locationError = ''.obs;

  final RxString currentAddress = ''.obs;

  Future<void>? _permissionRequestInFlight;
  Future<void>? _streamStartInFlight;
  StreamSubscription<Position>? _positionStreamSubscription;

  Position? _lastBackendSyncPosition;
  DateTime? _lastBackendSyncAt;
  Position? _lastGeocodePosition;
  DateTime? _lastGeocodeAt;

  static const Duration _currentPositionStaleThreshold = Duration(minutes: 2);
  static const Duration _lastKnownMaxAge = Duration(minutes: 10);
  static const Duration _currentPositionTimeout = Duration(seconds: 8);
  static const Duration _currentPositionFallbackTimeout = Duration(seconds: 5);
  static const Duration _currentPositionLowTimeout = Duration(seconds: 3);
  static const Duration _backendSyncMinInterval = Duration(minutes: 2);
  static const double _backendSyncMinDistanceMeters = 250;
  static const Duration _geocodeMinInterval = Duration(minutes: 2);
  static const double _geocodeMinDistanceMeters = 100;
  static const int _streamDistanceFilterMeters = 25;

  // Google Places — delegated to GooglePlacesService
  late final GooglePlacesService _placesService;

  RxList<PlaceSuggestion> get placeSuggestions => _placesService.placeSuggestions;
  RxBool get isSearchingPlaces => _placesService.isSearchingPlaces;

  @override
  void onInit() {
    super.onInit();
    _authController = Get.find<AuthController>();
    _placesService = Get.find<GooglePlacesService>();
  }

  // IP-based location fallback
  Future<LocationData?> getIpLocation() async {
    try {
      // Prefer ipapi.co which returns lat/lon/city reliably
      final uri = Uri.parse('https://ipapi.co/json/');
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final double? lat = (data['latitude'] is num)
            ? (data['latitude'] as num).toDouble()
            : double.tryParse((data['latitude'] ?? '').toString());
        final double? lon = (data['longitude'] is num)
            ? (data['longitude'] as num).toDouble()
            : double.tryParse((data['longitude'] ?? '').toString());
        final String? city = (data['city'] as String?)?.trim();
        final String? region = (data['region'] as String?)?.trim();

        if (lat != null && lon != null) {
          DebugLogger.success('✅ IP-based location: $city, $region ($lat,$lon)');
          return LocationData(
            name: city != null && region != null ? '$city, $region' : (city ?? 'IP-based Location'),
            latitude: lat,
            longitude: lon,
          );
        }
      } else {
        DebugLogger.warning('IP location HTTP ${response.statusCode}: ${response.body}');
      }
    } on TimeoutException catch (e) {
      DebugLogger.error('IP location request timed out', e);
    } catch (e, st) {
      DebugLogger.error('Failed to get IP-based location', e, st);
    }
    return null;
  }

  Future<void> _checkLocationService() async {
    try {
      isLocationEnabled.value = await Geolocator.isLocationServiceEnabled();
      if (!isLocationEnabled.value) {
        locationError.value = 'location_services_disabled'.tr;
        AppToast.warning('location_services'.tr, 'enable_location_services_message'.tr);
      }
    } catch (e, stackTrace) {
      locationError.value = 'failed_to_check_location_service'.tr;
      DebugLogger.error('Error checking location service', e, stackTrace);
    }
  }

  Future<void> _requestLocationPermission() {
    final inFlight = _permissionRequestInFlight;
    if (inFlight != null) return inFlight;

    final future = _requestLocationPermissionInternal();
    _permissionRequestInFlight = future;
    return future.whenComplete(() {
      if (identical(_permissionRequestInFlight, future)) {
        _permissionRequestInFlight = null;
      }
    });
  }

  Future<void> _requestLocationPermissionInternal() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        isLocationPermissionGranted.value = false;
        locationError.value = 'location_permission_permanently_denied'.tr;
        AppToast.warning('location_permission'.tr, 'location_access_permanently_denied_message'.tr);
        return;
      }

      if (permission == LocationPermission.denied) {
        isLocationPermissionGranted.value = false;
        locationError.value = 'location_permission_denied'.tr;
        AppToast.warning('location_permission'.tr, 'location_access_required_message'.tr);
        return;
      }

      isLocationPermissionGranted.value = true;
      locationError.value = '';
    } catch (e, stackTrace) {
      locationError.value = 'error_requesting_location_permission'.tr;
      DebugLogger.error('Error requesting location permission', e, stackTrace);
    }
  }

  Future<bool> _ensureLocationReady() async {
    await _checkLocationService();
    await _requestLocationPermission();
    return isLocationEnabled.value && isLocationPermissionGranted.value;
  }

  bool _isPositionFresh(Position position, Duration maxAge) {
    final timestamp = position.timestamp;
    return DateTime.now().difference(timestamp) <= maxAge;
  }

  double _distanceMeters(Position a, Position b) {
    return Geolocator.distanceBetween(a.latitude, a.longitude, b.latitude, b.longitude);
  }

  bool _shouldRefreshGeocode(Position position) {
    if (currentAddress.value.isEmpty) return true;
    if (_lastGeocodeAt == null || _lastGeocodePosition == null) return true;
    final age = DateTime.now().difference(_lastGeocodeAt!);
    if (age >= _geocodeMinInterval) return true;
    return _distanceMeters(_lastGeocodePosition!, position) >= _geocodeMinDistanceMeters;
  }

  Future<void> _refreshAddressForPosition(Position position, {bool force = false}) async {
    if (!force && !_shouldRefreshGeocode(position)) return;
    await _updateCurrentAddress(position.latitude, position.longitude);
    _lastGeocodeAt = DateTime.now();
    _lastGeocodePosition = position;
  }

  bool _shouldSyncBackend(Position position) {
    if (!_authController.isAuthenticated) return false;
    if (_lastBackendSyncAt == null || _lastBackendSyncPosition == null) return true;
    final age = DateTime.now().difference(_lastBackendSyncAt!);
    if (age >= _backendSyncMinInterval) return true;
    return _distanceMeters(_lastBackendSyncPosition!, position) >= _backendSyncMinDistanceMeters;
  }

  Future<void> _syncBackendLocation(Position position) async {
    if (!_shouldSyncBackend(position)) return;
    try {
      await _authController.updateUserLocation({
        'current_latitude': position.latitude,
        'current_longitude': position.longitude,
      });
      _lastBackendSyncAt = DateTime.now();
      _lastBackendSyncPosition = position;
    } catch (e, stackTrace) {
      DebugLogger.error('Failed to update backend location', e, stackTrace);
    }
  }

  Future<void> _applyPosition(
    Position position, {
    bool allowBackendSync = true,
    bool forceGeocode = false,
  }) async {
    currentPosition.value = position;
    if (allowBackendSync) {
      await _syncBackendLocation(position);
    }
    await _refreshAddressForPosition(position, force: forceGeocode);
  }

  Future<Position?> _getLastKnownPosition() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (e, stackTrace) {
      DebugLogger.warning('Failed to read last known position', e, stackTrace);
      return null;
    }
  }

  Future<Position?> _getCurrentPositionWithTimeout() async {
    // Primary attempt: high accuracy (8s timeout, previously 25s)
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).timeout(_currentPositionTimeout);
    } on TimeoutException {
      DebugLogger.warning(
        'High-accuracy GPS timed out after ${_currentPositionTimeout.inSeconds}s, '
        'retrying at medium accuracy…',
      );
    } catch (e, stackTrace) {
      DebugLogger.error('Failed to get high-accuracy GPS position', e, stackTrace);
      return null;
    }

    // Fallback 1: medium accuracy (5s timeout, previously 10s)
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter: 50,
        ),
      ).timeout(_currentPositionFallbackTimeout);
    } on TimeoutException catch (e) {
      DebugLogger.warning(
        'Medium-accuracy GPS also timed out after ${_currentPositionFallbackTimeout.inSeconds}s',
        e,
      );
    } catch (e, stackTrace) {
      DebugLogger.error('Failed to get medium-accuracy GPS position', e, stackTrace);
      return null;
    }

    // Fallback 2: low accuracy (3s timeout) — coarse but fast, better than
    // leaving the user staring at a spinner. Worst-case total is now ~16s
    // instead of the previous 35s.
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          distanceFilter: 100,
        ),
      ).timeout(_currentPositionLowTimeout);
      AppToast.info('locating_you'.tr, 'using_approximate_location'.tr);
      return pos;
    } on TimeoutException catch (e) {
      DebugLogger.warning(
        'Low-accuracy GPS also timed out after ${_currentPositionLowTimeout.inSeconds}s',
        e,
      );
      return null;
    } catch (e, stackTrace) {
      DebugLogger.error('Failed to get low-accuracy GPS position', e, stackTrace);
      return null;
    }
  }

  Future<void> _startPositionStream() {
    if (_positionStreamSubscription != null) return Future.value();
    if (!isLocationPermissionGranted.value || !isLocationEnabled.value) {
      return Future.value();
    }

    final inFlight = _streamStartInFlight;
    if (inFlight != null) return inFlight;

    final future = _startPositionStreamInternal();
    _streamStartInFlight = future;
    return future.whenComplete(() {
      if (identical(_streamStartInFlight, future)) {
        _streamStartInFlight = null;
      }
    });
  }

  Future<void> _startPositionStreamInternal() async {
    try {
      _positionStreamSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: _streamDistanceFilterMeters,
            ),
          ).listen(
            (position) {
              unawaited(_applyPosition(position));
            },
            onError: (error) {
              DebugLogger.warning('Location stream error: $error');
            },
          );
    } catch (e, stackTrace) {
      DebugLogger.error('Failed to start location stream', e, stackTrace);
    }
  }

  Future<void> getCurrentLocation({bool forceRefresh = false}) async {
    final ready = await _ensureLocationReady();
    if (!ready) return;

    final cached = currentPosition.value;
    if (!forceRefresh &&
        cached != null &&
        _isPositionFresh(cached, _currentPositionStaleThreshold)) {
      await _startPositionStream();
      return;
    }

    try {
      isLoading.value = true;
      locationError.value = '';

      Position? resolved;

      final lastKnown = await _getLastKnownPosition();
      if (lastKnown != null) {
        final lastKnownFresh = _isPositionFresh(lastKnown, _lastKnownMaxAge);
        if (lastKnownFresh || cached == null) {
          await _applyPosition(lastKnown, allowBackendSync: false);
          resolved = lastKnown;
        }
      }

      final current = await _getCurrentPositionWithTimeout();
      if (current != null) {
        await _applyPosition(current, forceGeocode: true);
        resolved = current;
      }

      if (resolved == null && currentPosition.value == null) {
        locationError.value = 'failed_to_get_current_location'.tr;
        AppToast.error('location_error'.tr, 'failed_to_get_location_message'.tr);
      }
    } catch (e, stackTrace) {
      locationError.value = 'failed_to_get_current_location'.tr;
      DebugLogger.error('Error getting current location', e, stackTrace);

      AppToast.error('location_error'.tr, 'failed_to_get_location_message'.tr);
    } finally {
      isLoading.value = false;
    }

    await _startPositionStream();
  }

  Future<void> _updateCurrentAddress(double latitude, double longitude) async {
    try {
      final address = await getAddressFromCoordinates(latitude, longitude);
      currentAddress.value = address;
    } catch (e, stackTrace) {
      DebugLogger.error('Error getting address from coordinates', e, stackTrace);
    }
  }

  // Public method for reverse geocoding that other services can use
  Future<String> getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        return _formatAddress(placemark);
      }
      return 'location_with_coords'.trParams({
        'lat': latitude.toStringAsFixed(4),
        'long': longitude.toStringAsFixed(4),
      });
    } catch (e, stackTrace) {
      DebugLogger.error('Error getting address from coordinates', e, stackTrace);
      return 'location_coordinates'.tr;
    }
  }

  /// Fetches the best possible initial location for the user.
  /// Priority: High-accuracy GPS -> IP-based location.
  /// Throws an exception if no location can be determined.
  Future<LocationData> getInitialLocation() async {
    DebugLogger.info('Getting initial user location...');

    final ready = await _ensureLocationReady();
    Position? resolved;

    if (ready) {
      try {
        isLoading.value = true;

        final lastKnown = await _getLastKnownPosition();
        if (lastKnown != null) {
          final lastKnownFresh = _isPositionFresh(lastKnown, _lastKnownMaxAge);
          if (lastKnownFresh || currentPosition.value == null) {
            await _applyPosition(lastKnown, allowBackendSync: false);
            resolved = lastKnown;
          }
        }

        final current = await _getCurrentPositionWithTimeout();
        if (current != null) {
          await _applyPosition(current, forceGeocode: true);
          resolved = current;
        }
      } catch (e, st) {
        DebugLogger.warning('Failed to get high-accuracy location: $e', e, st);
      } finally {
        isLoading.value = false;
      }
    } else {
      DebugLogger.warning('GPS permissions not granted or service disabled. Falling back...');
    }

    final position = resolved ?? currentPosition.value;
    if (position != null) {
      final locationName = currentAddress.value.isNotEmpty
          ? currentAddress.value
          : await getAddressFromCoordinates(position.latitude, position.longitude);
      await _startPositionStream();
      return LocationData(
        name: locationName,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    }

    if (ready) {
      await _startPositionStream();
    }

    DebugLogger.info('Attempting IP-based location fallback...');
    final ipLocation = await getIpLocation();
    if (ipLocation != null) {
      DebugLogger.success('IP-based location fallback successful: ${ipLocation.name}');
      return ipLocation;
    }

    DebugLogger.error('Critical: Could not determine any user location.');
    throw Exception(
      'Unable to determine user location. Please check network and location settings.',
    );
  }

  String _formatAddress(Placemark placemark) {
    // Improved formatting logic for better location names
    final city = placemark.locality;
    final state = placemark.administrativeArea;
    final area = placemark.subLocality;
    final street = placemark.street;

    // Priority order: Area+City+State, City+State, Street+City, or any available info
    if (area != null && area.isNotEmpty && city != null && city.isNotEmpty) {
      return '$area, $city';
    }
    if (city != null && city.isNotEmpty && state != null && state.isNotEmpty) {
      return '$city, $state';
    }
    if (city != null && city.isNotEmpty) {
      return city;
    }
    if (street != null && street.isNotEmpty) {
      return street;
    }

    // Fallback to any available information
    List<String> addressParts = [];
    if (placemark.name?.isNotEmpty == true) {
      addressParts.add(placemark.name!);
    }
    if (placemark.locality?.isNotEmpty == true) {
      addressParts.add(placemark.locality!);
    }
    if (placemark.administrativeArea?.isNotEmpty == true) {
      addressParts.add(placemark.administrativeArea!);
    }

    return addressParts.isNotEmpty ? addressParts.join(', ') : 'location_fallback'.tr;
  }

  Future<void> openLocationSettings() async {
    try {
      await Geolocator.openLocationSettings();
    } catch (e) {
      AppToast.error('error'.tr, 'unable_to_open_location_settings'.tr);
    }
  }

  Future<void> openAppSettings() async {
    try {
      await Geolocator.openAppSettings();
    } catch (e) {
      AppToast.error('error'.tr, 'unable_to_open_app_settings'.tr);
    }
  }

  double? get currentLatitude => currentPosition.value?.latitude;
  double? get currentLongitude => currentPosition.value?.longitude;

  bool get hasLocation => currentPosition.value != null;

  String get locationStatusText {
    if (!isLocationEnabled.value) return 'location_services_disabled'.tr;
    if (!isLocationPermissionGranted.value) {
      return 'location_permission_denied'.tr;
    }
    if (isLoading.value) return 'getting_location'.tr;
    if (hasLocation) {
      return currentAddress.value.isNotEmpty ? currentAddress.value : 'location_found'.tr;
    }
    return 'location_not_available'.tr;
  }

  Map<String, dynamic> get locationSummary => {
    'hasPermission': isLocationPermissionGranted.value,
    'serviceEnabled': isLocationEnabled.value,
    'hasLocation': hasLocation,
    'latitude': currentLatitude,
    'longitude': currentLongitude,
    'address': currentAddress.value,
  };

  // clearSearchResults removed (no longer used)

  void clearLocationError() {
    locationError.value = '';
  }

  // Distance calculation helper
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000; // Convert to kilometers
  }

  String formatDistance(double distanceInKm) {
    if (distanceInKm < 1) {
      return '${(distanceInKm * 1000).round()}m';
    } else if (distanceInKm < 10) {
      return '${distanceInKm.toStringAsFixed(1)}km';
    } else {
      return '${distanceInKm.round()}km';
    }
  }

  // Google Places API — delegated to GooglePlacesService

  Future<List<PlaceSuggestion>> getPlaceSuggestions(String query) =>
      _placesService.getPlaceSuggestions(query, currentPosition: currentPosition.value);

  Future<LocationData?> getPlaceDetails(String placeId, {String? preferredName}) =>
      _placesService.getPlaceDetails(placeId, preferredName: preferredName);

  void clearPlaceSuggestions() => _placesService.clearPlaceSuggestions();

  @override
  void onClose() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    super.onClose();
  }
}
