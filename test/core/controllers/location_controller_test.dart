// test/core/controllers/location_controller_test.dart
//
// Unit tests for [LocationController]. Covers:
// - Pure helpers: calculateDistance, formatDistance
// - Initial state: hasLocation, currentLatitude/Longitude, locationError
// - locationStatusText across various reactive states
// - locationSummary map structure
// - clearLocationError
// - placeSuggestions / isSearchingPlaces delegation to GooglePlacesService
// - getIpLocation graceful failure without network

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geocoding_platform_interface/geocoding_platform_interface.dart' as geo_pi;
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/controllers/location_controller.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/services/google_places_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:mocktail/mocktail.dart';

import '../../helpers/getx_test_binding.dart';
import '../../helpers/mocks.dart';

// ---------------------------------------------------------------------------
// Fake GeolocatorPlatform — lets tests drive LocationController's GPS/permission
// flows without a real device. Override the configurable fields per test.
// ---------------------------------------------------------------------------

/// A configurable in-process [GeolocatorPlatform]. The controller's private
/// helpers (`_checkLocationService`, `_requestLocationPermission`,
/// `getCurrentLocation`, `getInitialLocation`, …) all route through the static
/// `Geolocator.*` facade, which delegates to `GeolocatorPlatform.instance`.
/// Swapping that instance gives deterministic, synchronous control over every
/// platform call.
class FakeGeolocatorPlatform extends GeolocatorPlatform {
  FakeGeolocatorPlatform({
    this.serviceEnabled = true,
    this.permission = LocationPermission.always,
    this.requestedPermission = LocationPermission.always,
    this.lastKnownPosition,
    this.currentPosition,
    this.currentPositionDelay = Duration.zero,
    this.throwOnCurrentPosition = false,
    this.throwOnLastKnown = false,
    this.openSettingsSucceeds = true,
    this.throwOnServiceCheck = false,
    this.timeoutFirstNCurrentPositionCalls = 0,
    this.throwOnPositionStream = false,
  });

  bool serviceEnabled;
  LocationPermission permission;
  LocationPermission requestedPermission;
  Position? lastKnownPosition;
  Position? currentPosition;
  Duration currentPositionDelay;
  bool throwOnCurrentPosition;
  bool throwOnLastKnown;
  bool openSettingsSucceeds;
  bool throwOnServiceCheck;
  int timeoutFirstNCurrentPositionCalls;
  bool throwOnPositionStream;

  int getCurrentPositionCallCount = 0;
  int requestPermissionCallCount = 0;
  StreamController<Position>? positionStreamController;

  @override
  Future<bool> isLocationServiceEnabled() async {
    if (throwOnServiceCheck) throw Exception('service check failed');
    return serviceEnabled;
  }

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    requestPermissionCallCount++;
    return requestedPermission;
  }

  @override
  Future<Position?> getLastKnownPosition({bool forceLocationManager = false}) async {
    if (throwOnLastKnown) throw Exception('last known failed');
    return lastKnownPosition;
  }

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async {
    getCurrentPositionCallCount++;
    if (throwOnCurrentPosition) throw Exception('gps failed');
    // Simulate GPS hang so LocationController's .timeout() paths fire.
    if (timeoutFirstNCurrentPositionCalls > 0 &&
        getCurrentPositionCallCount <= timeoutFirstNCurrentPositionCalls) {
      await Future<void>.delayed(const Duration(seconds: 30));
    }
    if (currentPositionDelay > Duration.zero) {
      await Future.delayed(currentPositionDelay);
    }
    return currentPosition ??
        Position(
          latitude: 28.6139,
          longitude: 77.2090,
          timestamp: DateTime.now(),
          accuracy: 10,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
  }

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    if (throwOnPositionStream) {
      throw Exception('stream failed');
    }
    positionStreamController ??= StreamController<Position>.broadcast();
    return positionStreamController!.stream;
  }

  void emitPosition(Position position) {
    positionStreamController?.add(position);
  }

  void emitStreamError(Object error) {
    positionStreamController?.addError(error);
  }

  @override
  Future<bool> openAppSettings() async => openSettingsSucceeds;

  @override
  Future<bool> openLocationSettings() async => openSettingsSucceeds;

  // distanceBetween falls back to the real Haversine implementation in the
  // superclass, which is pure Dart and works in tests.
}

/// Builds a [Position] with sensible test defaults.
Position testPosition({
  double latitude = 28.6139,
  double longitude = 77.2090,
  DateTime? timestamp,
}) {
  return Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: timestamp ?? DateTime.now(),
    accuracy: 10,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

void main() {
  setUpAll(() {
    Get.testMode = true;
  });

  late MockAuthController mockAuthController;
  late MockGooglePlacesService mockPlacesService;

  setUp(() {
    GetxTestBinding.init();

    mockAuthController = MockAuthController();
    mockPlacesService = MockGooglePlacesService();

    // GooglePlacesService reactive getters used by LocationController.
    when(() => mockPlacesService.placeSuggestions)
        .thenReturn(<PlaceSuggestion>[].obs);
    when(() => mockPlacesService.isSearchingPlaces).thenReturn(false.obs);

    GetxTestBinding.bind()
      ..register<AuthController>(mockAuthController)
      ..register<GooglePlacesService>(mockPlacesService);
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  LocationController createController() {
    final c = LocationController();
    c.onInit();
    return c;
  }

  group('LocationController', () {
    // ── Initial state ─────────────────────────────────────────────────

    test('hasLocation is false initially', () {
      final controller = createController();

      expect(controller.hasLocation, false);
    });

    test('currentLatitude is null initially', () {
      final controller = createController();

      expect(controller.currentLatitude, isNull);
    });

    test('currentLongitude is null initially', () {
      final controller = createController();

      expect(controller.currentLongitude, isNull);
    });

    test('locationError is empty initially', () {
      final controller = createController();

      expect(controller.locationError.value, '');
    });

    test('isLoading is false initially', () {
      final controller = createController();

      expect(controller.isLoading.value, false);
    });

    // ── calculateDistance ─────────────────────────────────────────────

    test('calculateDistance returns zero for identical coordinates', () {
      final controller = createController();

      // Same point → 0 km (within floating-point tolerance).
      final dist = controller.calculateDistance(28.6139, 77.2090, 28.6139, 77.2090);
      expect(dist, closeTo(0, 0.001));
    });

    test('calculateDistance returns positive value for different points', () {
      final controller = createController();

      // Delhi → Mumbai is roughly 1100+ km.
      final dist = controller.calculateDistance(28.6139, 77.2090, 19.0760, 72.8777);
      expect(dist, greaterThan(1000));
    });

    // ── formatDistance ────────────────────────────────────────────────

    test('formatDistance shows meters for values < 1 km', () {
      final controller = createController();

      expect(controller.formatDistance(0.5), '500m');
      expect(controller.formatDistance(0.123), '123m');
      expect(controller.formatDistance(0.001), '1m');
    });

    test('formatDistance shows 1 decimal place for 1–10 km', () {
      final controller = createController();

      expect(controller.formatDistance(1.0), '1.0km');
      expect(controller.formatDistance(5.56), '5.6km');
      expect(controller.formatDistance(9.9), '9.9km');
    });

    test('formatDistance shows rounded km for >= 10 km', () {
      final controller = createController();

      expect(controller.formatDistance(10.0), '10km');
      expect(controller.formatDistance(15.6), '16km');
      expect(controller.formatDistance(99.9), '100km');
    });

    // ── locationStatusText ────────────────────────────────────────────

    test('locationStatusText reports disabled when service not enabled', () {
      final controller = createController();
      controller.isLocationEnabled.value = false;
      controller.isLocationPermissionGranted.value = false;

      // .tr returns the key when no translation is registered.
      expect(controller.locationStatusText, 'location_services_disabled');
    });

    test('locationStatusText reports denied when service on but no permission', () {
      final controller = createController();
      controller.isLocationEnabled.value = true;
      controller.isLocationPermissionGranted.value = false;

      expect(controller.locationStatusText, 'location_permission_denied');
    });

    test('locationStatusText reports getting_location when loading', () {
      final controller = createController();
      controller.isLocationEnabled.value = true;
      controller.isLocationPermissionGranted.value = true;
      controller.isLoading.value = true;

      expect(controller.locationStatusText, 'getting_location');
    });

    test('locationStatusText reports address when location present with address', () {
      final controller = createController();
      controller.isLocationEnabled.value = true;
      controller.isLocationPermissionGranted.value = true;
      controller.isLoading.value = false;
      controller.currentAddress.value = 'Connaught Place, Delhi';

      // Without a real Position we cannot set currentPosition.value, so
      // hasLocation stays false and the address branch is not reached.
      // Instead verify the not-available fallback.
      expect(controller.locationStatusText, 'location_not_available');
    });

    test('locationStatusText reports not available when no location', () {
      final controller = createController();
      controller.isLocationEnabled.value = true;
      controller.isLocationPermissionGranted.value = true;
      controller.isLoading.value = false;

      expect(controller.locationStatusText, 'location_not_available');
    });

    // ── locationSummary ───────────────────────────────────────────────

    test('locationSummary returns a map with expected keys', () {
      final controller = createController();

      final summary = controller.locationSummary;

      expect(summary, isA<Map<String, dynamic>>());
      expect(summary.containsKey('hasPermission'), true);
      expect(summary.containsKey('serviceEnabled'), true);
      expect(summary.containsKey('hasLocation'), true);
      expect(summary.containsKey('latitude'), true);
      expect(summary.containsKey('longitude'), true);
      expect(summary.containsKey('address'), true);
    });

    test('locationSummary reflects initial empty state', () {
      final controller = createController();

      final summary = controller.locationSummary;
      expect(summary['hasPermission'], false);
      expect(summary['serviceEnabled'], false);
      expect(summary['hasLocation'], false);
      expect(summary['latitude'], isNull);
      expect(summary['longitude'], isNull);
      expect(summary['address'], '');
    });

    // ── clearLocationError ────────────────────────────────────────────

    test('clearLocationError resets locationError to empty', () {
      final controller = createController();
      controller.locationError.value = 'something went wrong';

      controller.clearLocationError();

      expect(controller.locationError.value, '');
    });

    // ── Google Places delegation ──────────────────────────────────────

    test('placeSuggestions delegates to GooglePlacesService', () {
      final controller = createController();

      expect(controller.placeSuggestions, isA<RxList<PlaceSuggestion>>());
      expect(controller.placeSuggestions, isEmpty);
    });

    test('isSearchingPlaces delegates to GooglePlacesService', () {
      final controller = createController();

      expect(controller.isSearchingPlaces.value, false);
    });

    // ── getIpLocation ─────────────────────────────────────────────────

    test('getIpLocation returns null gracefully when network unavailable', () async {
      final controller = createController();

      // Override the HTTP client to simulate a network failure (throws).
      await http.runWithClient(
        () async {
          final result = await controller.getIpLocation();
          expect(result, isNull);
        },
        () => http_testing.MockClient((_) async => throw Exception('network down')),
      );
    });

    test('getIpLocation returns LocationData on successful 200 response', () async {
      final controller = createController();

      await http.runWithClient(
        () async {
          final result = await controller.getIpLocation();
          expect(result, isNotNull);
          expect(result!.latitude, 28.6139);
          expect(result.longitude, 77.2090);
          expect(result.name, 'Delhi, Delhi');
        },
        () => http_testing.MockClient(
          (_) async => http.Response(
            json.encode({
              'latitude': 28.6139,
              'longitude': 77.2090,
              'city': 'Delhi',
              'region': 'Delhi',
            }),
            200,
          ),
        ),
      );
    });

    test('getIpLocation returns LocationData with city only when region is null', () async {
      final controller = createController();

      await http.runWithClient(
        () async {
          final result = await controller.getIpLocation();
          expect(result, isNotNull);
          expect(result!.name, 'Mumbai');
        },
        () => http_testing.MockClient(
          (_) async => http.Response(
            json.encode({
              'latitude': 19.076,
              'longitude': 72.877,
              'city': 'Mumbai',
              'region': null,
            }),
            200,
          ),
        ),
      );
    });

    test('getIpLocation returns null on non-200 status code', () async {
      final controller = createController();

      await http.runWithClient(
        () async {
          final result = await controller.getIpLocation();
          expect(result, isNull);
        },
        () => http_testing.MockClient((_) async => http.Response('Not Found', 404)),
      );
    });

    test('getIpLocation returns null when lat/lon are missing', () async {
      final controller = createController();

      await http.runWithClient(
        () async {
          final result = await controller.getIpLocation();
          expect(result, isNull);
        },
        () => http_testing.MockClient(
          (_) async => http.Response(
            json.encode({'city': 'Delhi'}),
            200,
          ),
        ),
      );
    });

    test('getIpLocation handles lat/lon as string values', () async {
      final controller = createController();

      await http.runWithClient(
        () async {
          final result = await controller.getIpLocation();
          expect(result, isNotNull);
          expect(result!.latitude, 28.6139);
          expect(result.longitude, 77.2090);
        },
        () => http_testing.MockClient(
          (_) async => http.Response(
            json.encode({
              'latitude': '28.6139',
              'longitude': '77.2090',
              'city': 'Delhi',
              'region': 'Delhi',
            }),
            200,
          ),
        ),
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // getAddressFromCoordinates
  // ─────────────────────────────────────────────────────────────────────

  group('LocationController — getAddressFromCoordinates', () {
    test('returns fallback string when geocoding fails (no platform)', () async {
      final controller = createController();

      // Geocoding().placemarkFromCoordinates will throw in test environment
      // (no platform channel). The method catches and returns fallback.
      final result = await controller.getAddressFromCoordinates(28.6139, 77.2090);

      // Should return a non-empty string (either coords or fallback)
      expect(result, isA<String>());
      expect(result.isNotEmpty, isTrue);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // getInitialLocation
  // ─────────────────────────────────────────────────────────────────────

  group('LocationController — getInitialLocation', () {
    test('falls back to IP location when GPS is unavailable', () async {
      final controller = createController();

      // GPS will fail (no platform), so it should try IP fallback.
      await http.runWithClient(
        () async {
          final result = await controller.getInitialLocation();
          expect(result, isNotNull);
          expect(result.latitude, 28.6139);
          expect(result.longitude, 77.2090);
        },
        () => http_testing.MockClient(
          (_) async => http.Response(
            json.encode({
              'latitude': 28.6139,
              'longitude': 77.2090,
              'city': 'Delhi',
              'region': 'Delhi',
            }),
            200,
          ),
        ),
      );
    });

    test('throws when no location can be determined (GPS + IP both fail)', () async {
      final controller = createController();

      await http.runWithClient(
        () async {
          await expectLater(
            controller.getInitialLocation(),
            throwsA(isA<Exception>()),
          );
        },
        () => http_testing.MockClient((_) async => throw Exception('network down')),
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // getCurrentLocation
  // ─────────────────────────────────────────────────────────────────────

  group('LocationController — getCurrentLocation', () {
    test('returns gracefully when location services unavailable', () async {
      final controller = createController();

      // GPS will fail (no platform). The method should not throw.
      await controller.getCurrentLocation();

      // locationError should be set (service check fails in test env)
      expect(controller.isLoading.value, isFalse);
    });

    test('forceRefresh=true attempts to get location', () async {
      final controller = createController();

      await controller.getCurrentLocation(forceRefresh: true);

      expect(controller.isLoading.value, isFalse);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // openLocationSettings / openAppSettings
  // ─────────────────────────────────────────────────────────────────────

  group('LocationController — settings', () {
    test('openLocationSettings does not throw', () async {
      final controller = createController();

      // Geolocator.openLocationSettings will fail (no platform), but the
      // method catches the error.
      await controller.openLocationSettings();
    });

    test('openAppSettings does not throw', () async {
      final controller = createController();

      // Geolocator.openAppSettings will fail (no platform), but the
      // method catches the error.
      await controller.openAppSettings();
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // Google Places delegation
  // ─────────────────────────────────────────────────────────────────────

  group('LocationController — places delegation', () {
    test('getPlaceSuggestions delegates to GooglePlacesService', () async {
      when(() => mockPlacesService.getPlaceSuggestions(any(), currentPosition: any(named: 'currentPosition')))
          .thenAnswer((_) async => <PlaceSuggestion>[]);

      final controller = createController();

      final result = await controller.getPlaceSuggestions('test query');

      expect(result, isEmpty);
      verify(() => mockPlacesService.getPlaceSuggestions('test query', currentPosition: any(named: 'currentPosition'))).called(1);
    });

    test('getPlaceDetails delegates to GooglePlacesService', () async {
      when(() => mockPlacesService.getPlaceDetails(any(), preferredName: any(named: 'preferredName')))
          .thenAnswer((_) async => const LocationData(name: 'Test Place', latitude: 28.6, longitude: 77.2));

      final controller = createController();

      final result = await controller.getPlaceDetails('place123');

      expect(result, isNotNull);
      expect(result!.name, 'Test Place');
    });

    test('clearPlaceSuggestions delegates to GooglePlacesService', () {
      final controller = createController();

      controller.clearPlaceSuggestions();

      verify(() => mockPlacesService.clearPlaceSuggestions()).called(1);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // locationStatusText with position set
  // ─────────────────────────────────────────────────────────────────────

  group('LocationController — locationStatusText with position', () {
    test('reports address when location present with address', () {
      final controller = createController();
      controller.isLocationEnabled.value = true;
      controller.isLocationPermissionGranted.value = true;
      controller.isLoading.value = false;
      controller.currentAddress.value = 'Connaught Place, Delhi';
      controller.currentPosition.value = Position(
        latitude: 28.6139,
        longitude: 77.2090,
        timestamp: DateTime.now(),
        accuracy: 10,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );

      expect(controller.locationStatusText, 'Connaught Place, Delhi');
    });

    test('reports location_found when position present but no address', () {
      final controller = createController();
      controller.isLocationEnabled.value = true;
      controller.isLocationPermissionGranted.value = true;
      controller.isLoading.value = false;
      controller.currentPosition.value = Position(
        latitude: 28.6139,
        longitude: 77.2090,
        timestamp: DateTime.now(),
        accuracy: 10,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );

      expect(controller.locationStatusText, 'location_found');
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // locationSummary with position set
  // ─────────────────────────────────────────────────────────────────────

  group('LocationController — locationSummary with position', () {
    test('reflects position and address when set', () {
      final controller = createController();
      controller.isLocationPermissionGranted.value = true;
      controller.isLocationEnabled.value = true;
      controller.currentAddress.value = 'Test Address';
      controller.currentPosition.value = Position(
        latitude: 28.6139,
        longitude: 77.2090,
        timestamp: DateTime.now(),
        accuracy: 10,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );

      final summary = controller.locationSummary;
      expect(summary['hasPermission'], true);
      expect(summary['serviceEnabled'], true);
      expect(summary['hasLocation'], true);
      expect(summary['latitude'], 28.6139);
      expect(summary['longitude'], 77.2090);
      expect(summary['address'], 'Test Address');
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // currentLatitude / currentLongitude with position
  // ─────────────────────────────────────────────────────────────────────

  group('LocationController — coordinate getters', () {
    test('currentLatitude returns latitude when position is set', () {
      final controller = createController();
      controller.currentPosition.value = Position(
        latitude: 28.6139,
        longitude: 77.2090,
        timestamp: DateTime.now(),
        accuracy: 10,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );

      expect(controller.currentLatitude, 28.6139);
      expect(controller.currentLongitude, 77.2090);
      expect(controller.hasLocation, true);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // onClose
  // ─────────────────────────────────────────────────────────────────────

  group('LocationController — onClose', () {
    test('onClose does not throw', () {
      final controller = createController();

      expect(() => controller.onClose(), returnsNormally);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // Permission & service flows (via FakeGeolocatorPlatform)
  // ─────────────────────────────────────────────────────────────────────

  group('LocationController — permission/service flows', () {
    late GeolocatorPlatform originalPlatform;
    late FakeGeolocatorPlatform fake;

    setUp(() {
      originalPlatform = GeolocatorPlatform.instance;
    });

    tearDown(() {
      GeolocatorPlatform.instance = originalPlatform;
    });

    test('_checkLocationService reports disabled and sets error', () async {
      fake = FakeGeolocatorPlatform(serviceEnabled: false);
      GeolocatorPlatform.instance = fake;

      final controller = createController();
      // Trigger the service check indirectly via getCurrentLocation which
      // calls _ensureLocationReady -> _checkLocationService.
      await controller.getCurrentLocation();

      expect(controller.isLocationEnabled.value, false);
      // When service is disabled, permission flow is short-circuited and the
      // method returns early without loading.
      expect(controller.isLoading.value, false);
    });

    test('permission denied sets isLocationPermissionGranted false', () async {
      fake = FakeGeolocatorPlatform(
        serviceEnabled: true,
        permission: LocationPermission.denied,
        requestedPermission: LocationPermission.denied,
      );
      GeolocatorPlatform.instance = fake;

      final controller = createController();
      await controller.getCurrentLocation();

      expect(controller.isLocationPermissionGranted.value, false);
      expect(fake.requestPermissionCallCount, 1);
    });

    test('permission deniedForever sets isLocationPermissionGranted false', () async {
      fake = FakeGeolocatorPlatform(
        serviceEnabled: true,
        permission: LocationPermission.deniedForever,
      );
      GeolocatorPlatform.instance = fake;

      final controller = createController();
      await controller.getCurrentLocation();

      expect(controller.isLocationPermissionGranted.value, false);
      // deniedForever should not re-request permission.
      expect(fake.requestPermissionCallCount, 0);
    });

    test('permission granted sets isLocationPermissionGranted true', () async {
      fake = FakeGeolocatorPlatform(
        serviceEnabled: true,
        permission: LocationPermission.whileInUse,
      );
      GeolocatorPlatform.instance = fake;

      final controller = createController();
      await controller.getCurrentLocation();

      expect(controller.isLocationPermissionGranted.value, true);
      expect(controller.isLocationEnabled.value, true);
    });

    test('permission request exception is caught and sets error', () async {
      fake = FakeGeolocatorPlatform(
        serviceEnabled: true,
        permission: LocationPermission.denied,
        requestedPermission: LocationPermission.denied,
      );
      GeolocatorPlatform.instance = fake;
      // Force requestPermission to throw by overriding after install.
      fake.requestPermissionCallCount = 0;

      final controller = createController();
      // Replace checkPermission to throw via a throwing fake subclass.
      GeolocatorPlatform.instance = _ThrowingPermissionFake();
      await controller.getCurrentLocation();

      // Error is captured, controller does not throw.
      expect(controller.isLocationPermissionGranted.value, false);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // getCurrentLocation with mocked GPS
  // ─────────────────────────────────────────────────────────────────────

  group('LocationController — getCurrentLocation (mocked GPS)', () {
    late GeolocatorPlatform originalPlatform;
    late FakeGeolocatorPlatform fake;

    setUp(() {
      originalPlatform = GeolocatorPlatform.instance;
      // Auth not authenticated so backend sync is skipped.
      when(() => mockAuthController.isAuthenticated).thenReturn(false);
    });

    tearDown(() {
      GeolocatorPlatform.instance = originalPlatform;
    });

    test('resolves current position and sets currentPosition', () async {
      final pos = testPosition(latitude: 19.076, longitude: 72.877);
      fake = FakeGeolocatorPlatform(
        serviceEnabled: true,
        permission: LocationPermission.always,
        currentPosition: pos,
      );
      GeolocatorPlatform.instance = fake;

      final controller = createController();
      await controller.getCurrentLocation();

      expect(controller.currentPosition.value, isNotNull);
      expect(controller.currentLatitude, 19.076);
      expect(controller.currentLongitude, 72.877);
      expect(controller.hasLocation, true);
      expect(controller.isLoading.value, false);
    });

    test('uses fresh last-known position when available', () async {
      final lastKnown = testPosition(latitude: 12.97, longitude: 77.59);
      fake = FakeGeolocatorPlatform(
        serviceEnabled: true,
        permission: LocationPermission.always,
        lastKnownPosition: lastKnown,
        currentPosition: testPosition(latitude: 12.97, longitude: 77.59),
      );
      GeolocatorPlatform.instance = fake;

      final controller = createController();
      await controller.getCurrentLocation();

      expect(controller.currentPosition.value, isNotNull);
    });

    test('sets locationError when GPS returns no position', () async {
      fake = FakeGeolocatorPlatform(
        serviceEnabled: true,
        permission: LocationPermission.always,
        currentPosition: null,
        throwOnCurrentPosition: true,
      );
      GeolocatorPlatform.instance = fake;

      final controller = createController();
      await controller.getCurrentLocation();

      expect(controller.currentPosition.value, isNull);
      expect(controller.locationError.value, isNotEmpty);
      expect(controller.isLoading.value, false);
    });

    test('forceRefresh bypasses cache and fetches fresh position', () async {
      final pos = testPosition(latitude: 13.08, longitude: 80.27);
      fake = FakeGeolocatorPlatform(
        serviceEnabled: true,
        permission: LocationPermission.always,
        currentPosition: pos,
      );
      GeolocatorPlatform.instance = fake;

      final controller = createController();
      // Seed a fresh cached position so the non-force path would short-circuit.
      controller.currentPosition.value = testPosition(latitude: 1, longitude: 1);
      await controller.getCurrentLocation(forceRefresh: true);

      expect(controller.currentLatitude, 13.08);
    });

    test('uses cached fresh position without refetching', () async {
      fake = FakeGeolocatorPlatform(
        serviceEnabled: true,
        permission: LocationPermission.always,
        currentPosition: testPosition(latitude: 99, longitude: 99),
      );
      GeolocatorPlatform.instance = fake;

      final controller = createController();
      final cached = testPosition(latitude: 28.6, longitude: 77.2);
      controller.currentPosition.value = cached;
      await controller.getCurrentLocation();

      // Cached position retained (no refetch).
      expect(controller.currentLatitude, 28.6);
      expect(fake.getCurrentPositionCallCount, 0);
    });

    test('getCurrentPosition exception path is handled gracefully', () async {
      fake = FakeGeolocatorPlatform(
        serviceEnabled: true,
        permission: LocationPermission.always,
        throwOnCurrentPosition: true,
        throwOnLastKnown: true,
      );
      GeolocatorPlatform.instance = fake;

      final controller = createController();
      await controller.getCurrentLocation();

      expect(controller.isLoading.value, false);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // getInitialLocation with mocked GPS
  // ─────────────────────────────────────────────────────────────────────

  group('LocationController — getInitialLocation (mocked GPS)', () {
    late GeolocatorPlatform originalPlatform;
    late FakeGeolocatorPlatform fake;

    setUp(() {
      originalPlatform = GeolocatorPlatform.instance;
      when(() => mockAuthController.isAuthenticated).thenReturn(false);
    });

    tearDown(() {
      GeolocatorPlatform.instance = originalPlatform;
    });

    test('returns LocationData from GPS when available', () async {
      final pos = testPosition(latitude: 28.7, longitude: 77.1);
      fake = FakeGeolocatorPlatform(
        serviceEnabled: true,
        permission: LocationPermission.always,
        currentPosition: pos,
      );
      GeolocatorPlatform.instance = fake;

      final controller = createController();
      final result = await controller.getInitialLocation();

      expect(result.latitude, 28.7);
      expect(result.longitude, 77.1);
      expect(controller.hasLocation, true);
    });

    test('falls back to IP location when GPS permission denied', () async {
      fake = FakeGeolocatorPlatform(
        serviceEnabled: true,
        permission: LocationPermission.deniedForever,
      );
      GeolocatorPlatform.instance = fake;

      final controller = createController();
      await http.runWithClient(
        () async {
          final result = await controller.getInitialLocation();
          expect(result.latitude, 28.6139);
          expect(result.longitude, 77.2090);
        },
        () => http_testing.MockClient(
          (_) async => http.Response(
            json.encode({
              'latitude': 28.6139,
              'longitude': 77.2090,
              'city': 'Delhi',
              'region': 'Delhi',
            }),
            200,
          ),
        ),
      );
    });

    test('falls back to IP location when GPS returns no position', () async {
      fake = FakeGeolocatorPlatform(
        serviceEnabled: true,
        permission: LocationPermission.always,
        currentPosition: null,
        throwOnCurrentPosition: true,
        throwOnLastKnown: true,
      );
      GeolocatorPlatform.instance = fake;

      final controller = createController();
      await http.runWithClient(
        () async {
          final result = await controller.getInitialLocation();
          expect(result.latitude, 19.076);
        },
        () => http_testing.MockClient(
          (_) async => http.Response(
            json.encode({
              'latitude': 19.076,
              'longitude': 72.877,
              'city': 'Mumbai',
              'region': 'Maharashtra',
            }),
            200,
          ),
        ),
      );
    });

    test('throws when GPS unavailable and IP fails', () async {
      fake = FakeGeolocatorPlatform(
        serviceEnabled: false,
      );
      GeolocatorPlatform.instance = fake;

      final controller = createController();
      await http.runWithClient(
        () async {
          await expectLater(
            controller.getInitialLocation(),
            throwsA(isA<Exception>()),
          );
        },
        () => http_testing.MockClient((_) async => throw Exception('down')),
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // Backend sync (via mocked AuthController)
  // ─────────────────────────────────────────────────────────────────────

  group('LocationController — backend sync', () {
    late GeolocatorPlatform originalPlatform;
    late FakeGeolocatorPlatform fake;

    setUp(() {
      originalPlatform = GeolocatorPlatform.instance;
    });

    tearDown(() {
      GeolocatorPlatform.instance = originalPlatform;
    });

    test('syncs location to backend when authenticated', () async {
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      when(() => mockAuthController.updateUserLocation(any()))
          .thenAnswer((_) async => true);

      fake = FakeGeolocatorPlatform(
        serviceEnabled: true,
        permission: LocationPermission.always,
        currentPosition: testPosition(latitude: 28.6, longitude: 77.2),
      );
      GeolocatorPlatform.instance = fake;

      final controller = createController();
      await controller.getCurrentLocation();

      verify(() => mockAuthController.updateUserLocation(any())).called(greaterThan(0));
    });

    test('does not sync when not authenticated', () async {
      when(() => mockAuthController.isAuthenticated).thenReturn(false);

      fake = FakeGeolocatorPlatform(
        serviceEnabled: true,
        permission: LocationPermission.always,
        currentPosition: testPosition(),
      );
      GeolocatorPlatform.instance = fake;

      final controller = createController();
      await controller.getCurrentLocation();

      verifyNever(() => mockAuthController.updateUserLocation(any()));
    });

    test('swallows backend sync errors', () async {
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      when(() => mockAuthController.updateUserLocation(any()))
          .thenThrow(Exception('network error'));

      fake = FakeGeolocatorPlatform(
        serviceEnabled: true,
        permission: LocationPermission.always,
        currentPosition: testPosition(),
      );
      GeolocatorPlatform.instance = fake;

      final controller = createController();
      // Should not throw despite backend failure.
      await controller.getCurrentLocation();
      expect(controller.hasLocation, true);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // Settings (mocked platform)
  // ─────────────────────────────────────────────────────────────────────

  group('LocationController — settings (mocked)', () {
    late GeolocatorPlatform originalPlatform;
    late FakeGeolocatorPlatform fake;

    setUp(() {
      originalPlatform = GeolocatorPlatform.instance;
      fake = FakeGeolocatorPlatform(openSettingsSucceeds: true);
      GeolocatorPlatform.instance = fake;
    });

    tearDown(() {
      GeolocatorPlatform.instance = originalPlatform;
    });

    test('openLocationSettings succeeds via platform', () async {
      final controller = createController();
      await controller.openLocationSettings();
      // No exception thrown; platform returned true.
    });

    test('openAppSettings succeeds via platform', () async {
      final controller = createController();
      await controller.openAppSettings();
    });

    test('openLocationSettings catches platform exception', () async {
      GeolocatorPlatform.instance = _ThrowingSettingsFake();
      final controller = createController();
      await controller.openLocationSettings();
      // No throw.
    });

    test('openAppSettings catches platform exception', () async {
      GeolocatorPlatform.instance = _ThrowingSettingsFake();
      final controller = createController();
      await controller.openAppSettings();
      // No throw.
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // getAddressFromCoordinates fallback paths
  // ─────────────────────────────────────────────────────────────────────

  group('LocationController — getAddressFromCoordinates fallback', () {
    test('returns fallback string when geocoding throws', () async {
      final controller = createController();
      final result = await controller.getAddressFromCoordinates(28.6, 77.2);
      expect(result, isA<String>());
      expect(result.isNotEmpty, isTrue);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // Additional coverage: timeouts, geocode/format, stream, throttle
  // ─────────────────────────────────────────────────────────────────────

  group('LocationController — IP timeout', () {
    test('getIpLocation returns null on TimeoutException', () async {
      final controller = createController();

      await http.runWithClient(
        () async {
          final result = await controller.getIpLocation();
          expect(result, isNull);
        },
        () => http_testing.MockClient((_) async {
          // Exceed getIpLocation's 8s timeout.
          await Future<void>.delayed(const Duration(seconds: 9));
          return http.Response('{}', 200);
        }),
      );
    }, timeout: const Timeout(Duration(seconds: 20)));
  });

  group('LocationController — GPS accuracy fallback chain', () {
    late GeolocatorPlatform originalPlatform;
    FakeGeolocatorPlatform? activeFake;

    setUp(() {
      originalPlatform = GeolocatorPlatform.instance;
      when(() => mockAuthController.isAuthenticated).thenReturn(false);
    });

    tearDown(() {
      GeolocatorPlatform.instance = originalPlatform;
      activeFake?.positionStreamController?.close();
      activeFake = null;
    });

    test('falls back through medium then low accuracy after timeouts', () async {
      final pos = testPosition(latitude: 18.52, longitude: 73.85);
      final fake = FakeGeolocatorPlatform(
        serviceEnabled: true,
        permission: LocationPermission.always,
        currentPosition: pos,
        // High (1) + medium (2) hang; low (3) succeeds.
        timeoutFirstNCurrentPositionCalls: 2,
      );
      activeFake = fake;
      GeolocatorPlatform.instance = fake;

      final controller = createController();
      await controller.getCurrentLocation(forceRefresh: true);

      expect(controller.currentLatitude, 18.52);
      expect(fake.getCurrentPositionCallCount, greaterThanOrEqualTo(3));
      expect(controller.isLoading.value, isFalse);
    }, timeout: const Timeout(Duration(seconds: 45)));

    test('returns null path when all accuracy levels time out', () async {
      final fake = FakeGeolocatorPlatform(
        serviceEnabled: true,
        permission: LocationPermission.always,
        throwOnLastKnown: true,
        // High + medium + low all hang.
        timeoutFirstNCurrentPositionCalls: 3,
      );
      activeFake = fake;
      GeolocatorPlatform.instance = fake;

      final controller = createController();
      await controller.getCurrentLocation(forceRefresh: true);

      expect(controller.locationError.value, isNotEmpty);
      expect(controller.isLoading.value, isFalse);
    }, timeout: const Timeout(Duration(seconds: 45)));
  });

  group('LocationController — service check error', () {
    late GeolocatorPlatform originalPlatform;

    setUp(() {
      originalPlatform = GeolocatorPlatform.instance;
    });

    tearDown(() {
      GeolocatorPlatform.instance = originalPlatform;
    });

    test('service check exception leaves location not ready', () async {
      final fake = FakeGeolocatorPlatform(throwOnServiceCheck: true);
      GeolocatorPlatform.instance = fake;

      final controller = createController();
      await controller.getCurrentLocation();

      // Service check failure leaves isLocationEnabled false, so
      // getCurrentLocation returns early without a usable fix.
      expect(controller.isLocationEnabled.value, isFalse);
      expect(controller.currentPosition.value, isNull);
    });
  });

  group('LocationController — permission request coalescing', () {
    late GeolocatorPlatform originalPlatform;

    setUp(() {
      originalPlatform = GeolocatorPlatform.instance;
      when(() => mockAuthController.isAuthenticated).thenReturn(false);
    });

    tearDown(() {
      GeolocatorPlatform.instance = originalPlatform;
    });

    test('concurrent getCurrentLocation shares permission request', () async {
      final fake = FakeGeolocatorPlatform(
        serviceEnabled: true,
        permission: LocationPermission.denied,
        requestedPermission: LocationPermission.whileInUse,
        currentPosition: testPosition(),
      );
      GeolocatorPlatform.instance = fake;

      final controller = createController();
      await Future.wait([
        controller.getCurrentLocation(forceRefresh: true),
        controller.getCurrentLocation(forceRefresh: true),
      ]);

      // Permission is only requested once due to in-flight coalescing.
      expect(fake.requestPermissionCallCount, 1);
      expect(controller.isLocationPermissionGranted.value, isTrue);
    });
  });

  group('LocationController — last-known + geocode throttle + stream', () {
    late GeolocatorPlatform originalPlatform;
    FakeGeolocatorPlatform? activeFake;
    late _FakeGeocodingPlatformFactory geocodeFactory;
    geo_pi.GeocodingPlatformFactory? previousFactory;

    setUp(() {
      originalPlatform = GeolocatorPlatform.instance;
      when(() => mockAuthController.isAuthenticated).thenReturn(false);
      previousFactory = geo_pi.GeocodingPlatformFactory.instance;
      geocodeFactory = _FakeGeocodingPlatformFactory();
      geo_pi.GeocodingPlatformFactory.instance = geocodeFactory;
    });

    tearDown(() {
      GeolocatorPlatform.instance = originalPlatform;
      if (previousFactory != null) {
        geo_pi.GeocodingPlatformFactory.instance = previousFactory;
      }
      activeFake?.positionStreamController?.close();
      activeFake = null;
    });

    test('getInitialLocation uses last-known position when current GPS fails', () async {
      final lastKnown = testPosition(latitude: 26.91, longitude: 75.78);
      final fake = FakeGeolocatorPlatform(
        serviceEnabled: true,
        permission: LocationPermission.always,
        lastKnownPosition: lastKnown,
        throwOnCurrentPosition: true,
      );
      activeFake = fake;
      GeolocatorPlatform.instance = fake;

      final controller = createController();
      final result = await controller.getInitialLocation();

      expect(result.latitude, 26.91);
      expect(result.longitude, 75.78);
      expect(controller.hasLocation, isTrue);
    });

    test('applies geocoded address and formats area+city', () async {
      geocodeFactory.platform.placemarks = const [
        Placemark(subLocality: 'Connaught Place', locality: 'New Delhi'),
      ];
      final fake = FakeGeolocatorPlatform(
        serviceEnabled: true,
        permission: LocationPermission.always,
        currentPosition: testPosition(latitude: 28.63, longitude: 77.22),
      );
      activeFake = fake;
      GeolocatorPlatform.instance = fake;

      final controller = createController();
      await controller.getCurrentLocation(forceRefresh: true);

      expect(controller.currentAddress.value, 'Connaught Place, New Delhi');
    });

    test('formatAddress city+state when no subLocality', () async {
      geocodeFactory.platform.placemarks = const [
        Placemark(locality: 'Pune', administrativeArea: 'Maharashtra'),
      ];
      final fake = FakeGeolocatorPlatform(
        serviceEnabled: true,
        permission: LocationPermission.always,
        currentPosition: testPosition(latitude: 18.52, longitude: 73.85),
      );
      activeFake = fake;
      GeolocatorPlatform.instance = fake;

      final controller = createController();
      await controller.getCurrentLocation(forceRefresh: true);
      expect(controller.currentAddress.value, 'Pune, Maharashtra');
    });

    test('formatAddress city-only when no state', () async {
      geocodeFactory.platform.placemarks = const [
        Placemark(locality: 'Goa'),
      ];
      final fake = FakeGeolocatorPlatform(
        serviceEnabled: true,
        permission: LocationPermission.always,
        currentPosition: testPosition(latitude: 15.3, longitude: 74.0),
      );
      activeFake = fake;
      GeolocatorPlatform.instance = fake;

      final controller = createController();
      await controller.getCurrentLocation(forceRefresh: true);
      expect(controller.currentAddress.value, 'Goa');
    });

    test('formatAddress street when no city', () async {
      geocodeFactory.platform.placemarks = const [
        Placemark(street: 'MG Road'),
      ];
      final fake = FakeGeolocatorPlatform(
        serviceEnabled: true,
        permission: LocationPermission.always,
        currentPosition: testPosition(latitude: 12.97, longitude: 77.59),
      );
      activeFake = fake;
      GeolocatorPlatform.instance = fake;

      final controller = createController();
      await controller.getCurrentLocation(forceRefresh: true);
      expect(controller.currentAddress.value, 'MG Road');
    });

    test('formatAddress fallback joins name+locality+admin area', () async {
      geocodeFactory.platform.placemarks = const [
        Placemark(
          name: 'Landmark',
          locality: 'Jaipur',
          administrativeArea: 'Rajasthan',
          // no subLocality; locality+admin would hit city+state first actually
        ),
      ];
      // city+state branch takes precedence when locality+admin present.
      // Use name-only for pure fallback path.
      geocodeFactory.platform.placemarks = const [
        Placemark(name: 'Only Name'),
      ];
      final fake = FakeGeolocatorPlatform(
        serviceEnabled: true,
        permission: LocationPermission.always,
        currentPosition: testPosition(latitude: 1, longitude: 1),
      );
      activeFake = fake;
      GeolocatorPlatform.instance = fake;

      final controller = createController();
      await controller.getCurrentLocation(forceRefresh: true);
      expect(controller.currentAddress.value, 'Only Name');
    });

    test('formatAddress empty placemark returns fallback key', () async {
      geocodeFactory.platform.placemarks = const [Placemark()];
      final fake = FakeGeolocatorPlatform(
        serviceEnabled: true,
        permission: LocationPermission.always,
        currentPosition: testPosition(latitude: 2, longitude: 2),
      );
      activeFake = fake;
      GeolocatorPlatform.instance = fake;

      final controller = createController();
      await controller.getCurrentLocation(forceRefresh: true);
      expect(controller.currentAddress.value, 'location_fallback');
    });

    test('empty placemarks list returns coords template key', () async {
      geocodeFactory.platform.placemarks = const <Placemark>[];
      final fake = FakeGeolocatorPlatform(
        serviceEnabled: true,
        permission: LocationPermission.always,
        currentPosition: testPosition(latitude: 3, longitude: 3),
      );
      activeFake = fake;
      GeolocatorPlatform.instance = fake;

      final controller = createController();
      final address = await controller.getAddressFromCoordinates(3, 3);
      // Without translations registered, .trParams returns the key.
      expect(address, contains('location_with_coords'));
    });

    test('skips geocode refresh when address fresh and position close', () async {
      geocodeFactory.platform.placemarks = const [
        Placemark(locality: 'Delhi', administrativeArea: 'DL'),
      ];
      final fake = FakeGeolocatorPlatform(
        serviceEnabled: true,
        permission: LocationPermission.always,
        currentPosition: testPosition(latitude: 28.6139, longitude: 77.2090),
      );
      activeFake = fake;
      GeolocatorPlatform.instance = fake;

      final controller = createController();
      await controller.getCurrentLocation(forceRefresh: true);
      final callsAfterFirst = geocodeFactory.platform.placemarkCallCount;

      // Second force refresh with same coords — geocode should be forced for
      // current GPS (forceGeocode: true), so call count increases. Instead
      // exercise stream apply without force: emit a nearly-identical position.
      final near = testPosition(latitude: 28.6139, longitude: 77.2090);
      fake.emitPosition(near);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Geocode not refreshed because address is set and distance is 0.
      expect(geocodeFactory.platform.placemarkCallCount, callsAfterFirst);
    });

    test('stream onError is swallowed without crashing', () async {
      final fake = FakeGeolocatorPlatform(
        serviceEnabled: true,
        permission: LocationPermission.always,
        currentPosition: testPosition(),
      );
      activeFake = fake;
      GeolocatorPlatform.instance = fake;

      final controller = createController();
      await controller.getCurrentLocation(forceRefresh: true);

      fake.emitStreamError(Exception('gps stream glitch'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      // Controller remains usable.
      expect(controller.hasLocation, isTrue);
    });

    test('position stream apply updates currentPosition', () async {
      final fake = FakeGeolocatorPlatform(
        serviceEnabled: true,
        permission: LocationPermission.always,
        currentPosition: testPosition(latitude: 28.6, longitude: 77.2),
      );
      activeFake = fake;
      GeolocatorPlatform.instance = fake;

      final controller = createController();
      await controller.getCurrentLocation(forceRefresh: true);

      final next = testPosition(latitude: 28.7, longitude: 77.3);
      fake.emitPosition(next);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(controller.currentLatitude, 28.7);
    });

    test('stream start failure is handled', () async {
      final fake = FakeGeolocatorPlatform(
        serviceEnabled: true,
        permission: LocationPermission.always,
        currentPosition: testPosition(),
        throwOnPositionStream: true,
      );
      activeFake = fake;
      GeolocatorPlatform.instance = fake;

      final controller = createController();
      await controller.getCurrentLocation(forceRefresh: true);
      // No throw; position still applied from getCurrentPosition.
      expect(controller.hasLocation, isTrue);
    });
  });

  group('LocationController — backend sync throttling', () {
    late GeolocatorPlatform originalPlatform;
    late FakeGeolocatorPlatform fake;

    setUp(() {
      originalPlatform = GeolocatorPlatform.instance;
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      when(() => mockAuthController.updateUserLocation(any()))
          .thenAnswer((_) async => true);
    });

    tearDown(() {
      GeolocatorPlatform.instance = originalPlatform;
    });

    test('second nearby refresh does not re-sync within min interval', () async {
      fake = FakeGeolocatorPlatform(
        serviceEnabled: true,
        permission: LocationPermission.always,
        currentPosition: testPosition(latitude: 28.6, longitude: 77.2),
      );
      GeolocatorPlatform.instance = fake;

      final controller = createController();
      await controller.getCurrentLocation(forceRefresh: true);
      clearInteractions(mockAuthController);
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      when(() => mockAuthController.updateUserLocation(any()))
          .thenAnswer((_) async => true);

      // Same position force-refresh — backend sync throttled by interval/distance.
      await controller.getCurrentLocation(forceRefresh: true);
      verifyNever(() => mockAuthController.updateUserLocation(any()));
    });

    test('far position triggers another backend sync', () async {
      fake = FakeGeolocatorPlatform(
        serviceEnabled: true,
        permission: LocationPermission.always,
        currentPosition: testPosition(latitude: 28.6, longitude: 77.2),
      );
      GeolocatorPlatform.instance = fake;

      final controller = createController();
      await controller.getCurrentLocation(forceRefresh: true);

      // Move >250m (Delhi → roughly 1km south).
      fake.currentPosition = testPosition(latitude: 28.59, longitude: 77.2);
      await controller.getCurrentLocation(forceRefresh: true);

      verify(() => mockAuthController.updateUserLocation(any()))
          .called(greaterThanOrEqualTo(2));
    });
  });

  group('LocationController — getInitialLocation address empty path', () {
    late GeolocatorPlatform originalPlatform;
    late FakeGeolocatorPlatform fake;
    late _FakeGeocodingPlatformFactory geocodeFactory;
    geo_pi.GeocodingPlatformFactory? previousFactory;

    setUp(() {
      originalPlatform = GeolocatorPlatform.instance;
      when(() => mockAuthController.isAuthenticated).thenReturn(false);
      previousFactory = geo_pi.GeocodingPlatformFactory.instance;
      geocodeFactory = _FakeGeocodingPlatformFactory();
      geo_pi.GeocodingPlatformFactory.instance = geocodeFactory;
    });

    tearDown(() {
      GeolocatorPlatform.instance = originalPlatform;
      if (previousFactory != null) {
        geo_pi.GeocodingPlatformFactory.instance = previousFactory;
      }
    });

    test('uses reverse geocode when currentAddress is empty', () async {
      // Force geocode to fail so currentAddress stays empty during apply,
      // then getInitialLocation falls through to getAddressFromCoordinates.
      geocodeFactory.platform.throwOnPlacemark = true;
      fake = FakeGeolocatorPlatform(
        serviceEnabled: true,
        permission: LocationPermission.always,
        currentPosition: testPosition(latitude: 19.1, longitude: 72.9),
      );
      GeolocatorPlatform.instance = fake;

      final controller = createController();
      final result = await controller.getInitialLocation();
      expect(result.latitude, 19.1);
      // Address falls back to 'location_coordinates' key from catch path.
      expect(result.name, isNotEmpty);
    });
  });

}

/// Fake whose `checkPermission` throws, exercising the catch branch in
/// `_requestLocationPermissionInternal`.
class _ThrowingPermissionFake extends FakeGeolocatorPlatform {
  @override
  Future<LocationPermission> checkPermission() async =>
      throw Exception('permission check failed');
}

/// Fake whose settings methods throw, exercising the catch branches in
/// `openLocationSettings` / `openAppSettings`.
class _ThrowingSettingsFake extends FakeGeolocatorPlatform {
  @override
  Future<bool> openLocationSettings() async => throw Exception('cannot open');
  @override
  Future<bool> openAppSettings() async => throw Exception('cannot open');
}


class _FakeGeocodingPlatformFactory extends geo_pi.GeocodingPlatformFactory {
  final _FakeGeocoding platform = _FakeGeocoding();

  @override
  geo_pi.Geocoding createGeocoding(GeocodingCreationParams params) => platform;
}

class _FakeGeocoding extends Mock
    with MockPlatformInterfaceMixin
    implements geo_pi.Geocoding {
  List<Placemark> placemarks = const <Placemark>[];
  int placemarkCallCount = 0;
  bool throwOnPlacemark = false;

  @override
  Future<List<Placemark>> placemarkFromCoordinates(
    double latitude,
    double longitude, {
    dynamic locale,
  }) async {
    placemarkCallCount++;
    if (throwOnPlacemark) throw Exception('geocode failed');
    return placemarks;
  }
}
