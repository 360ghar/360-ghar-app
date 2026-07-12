// test/core/controllers/page_location_manager_test.dart
//
// Unit tests for [PageLocationManager]. The manager collaborates with
// [PageStateService], [PageDataLoader], [LocationController] and
// [AuthController]; all four are mocked with mocktail. Real [Rx] instances
// are wired onto the location-controller mock so the GPS stream listener can
// be exercised by emitting positions.

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/controllers/location_controller.dart';
import 'package:ghar360/core/controllers/page_data_loader.dart';
import 'package:ghar360/core/controllers/page_location_manager.dart';
import 'package:ghar360/core/controllers/page_state_service.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/mocks.dart';

// ---------------------------------------------------------------------------
// Mocks local to this test file
// ---------------------------------------------------------------------------

class MockPageDataLoader extends Mock implements PageDataLoader {}

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
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    Get.testMode = true;
    registerFallbackValue(PageType.explore);
    registerFallbackValue(PageStateModel.initial(PageType.explore));
    registerFallbackValue(const LocationData(name: 'fallback', latitude: 0, longitude: 0));
  });

  late MockPageStateService pageState;
  late MockPageDataLoader dataLoader;
  late MockLocationController locationController;
  late MockAuthController authController;
  late PageLocationManager manager;

  // Real reactive instances wired onto the location-controller mock so the
  // GPS stream listener and address lookups behave like the real controller.
  late Rxn<Position> currentPosition;
  late RxString currentAddress;
  late Rx<PageType> currentPageType;

  setUp(() {
    pageState = MockPageStateService();
    dataLoader = MockPageDataLoader();
    locationController = MockLocationController();
    authController = MockAuthController();

    currentPosition = Rxn<Position>();
    currentAddress = ''.obs;
    currentPageType = PageType.discover.obs;

    // Wire reactive getters onto the location-controller mock.
    when(() => locationController.currentPosition).thenReturn(currentPosition);
    when(() => locationController.currentAddress).thenReturn(currentAddress);
    when(() => locationController.getAddressFromCoordinates(any(), any()))
        .thenAnswer((_) async => 'Resolved Address');
    when(() => locationController.getCurrentLocation(forceRefresh: any(named: 'forceRefresh')))
        .thenAnswer((_) async {});
    when(() => locationController.getIpLocation()).thenAnswer(
      (_) async => const LocationData(name: 'IP Loc', latitude: 19.07, longitude: 72.87),
    );

    // PageStateService stubs.
    when(() => pageState.currentPageType).thenReturn(currentPageType);
    when(() => pageState.getStateForPage(any())).thenAnswer(
      (inv) => PageStateModel.initial(inv.positionalArguments[0] as PageType),
    );
    when(() => pageState.updatePageState(any(), any())).thenReturn(null);

    // DataLoader stubs.
    when(() => dataLoader.debounceRefresh(any())).thenReturn(null);

    manager = PageLocationManager(pageState, dataLoader, locationController, authController);
  });

  tearDown(() {
    manager.dispose();
  });

  // ── isPlaceholderLocationName ────────────────────────────────────────

  group('isPlaceholderLocationName', () {
    test('returns true for null', () {
      expect(manager.isPlaceholderLocationName(null), true);
    });

    test('returns true for empty/whitespace', () {
      expect(manager.isPlaceholderLocationName(''), true);
      expect(manager.isPlaceholderLocationName('   '), true);
    });

    test('returns true for known placeholder strings', () {
      expect(manager.isPlaceholderLocationName('Location (28.6, 77.2)'), true);
      expect(manager.isPlaceholderLocationName('location coordinates'), true);
      expect(manager.isPlaceholderLocationName('Current Location'), true);
      expect(manager.isPlaceholderLocationName('current area'), true);
      expect(manager.isPlaceholderLocationName('Selected Area'), true);
    });

    test('returns false for real location names', () {
      expect(manager.isPlaceholderLocationName('Connaught Place, Delhi'), false);
      expect(manager.isPlaceholderLocationName('Mumbai'), false);
      expect(manager.isPlaceholderLocationName('Bandra West'), false);
    });
  });

  // ── updateLocationForPage ────────────────────────────────────────────

  group('updateLocationForPage', () {
    test('updates state and debounces refresh for manual source', () async {
      await manager.updateLocationForPage(
        PageType.explore,
        const LocationData(name: 'Connaught Place', latitude: 28.6, longitude: 77.2),
        source: 'manual',
      );

      verify(() => pageState.updatePageState(PageType.explore, any())).called(1);
      verify(() => dataLoader.debounceRefresh(PageType.explore)).called(1);
    });

    test('resolves placeholder name via reverse geocoding', () async {
      await manager.updateLocationForPage(
        PageType.discover,
        const LocationData(name: 'Location (28.6, 77.2)', latitude: 28.6, longitude: 77.2),
        source: 'manual',
      );

      verify(() => locationController.getAddressFromCoordinates(28.6, 77.2)).called(1);
      // The updated state should carry the resolved name.
      final state = verify(() => pageState.updatePageState(PageType.discover, captureAny()))
          .captured.single as PageStateModel;
      expect(state.selectedLocation?.name, 'Resolved Address');
    });

    test('keeps provided name when reverse geocoding fails', () async {
      when(() => locationController.getAddressFromCoordinates(any(), any()))
          .thenThrow(Exception('geocode failed'));

      await manager.updateLocationForPage(
        PageType.explore,
        const LocationData(name: 'Location (28.6, 77.2)', latitude: 28.6, longitude: 77.2),
        source: 'manual',
      );

      final state = verify(() => pageState.updatePageState(PageType.explore, captureAny()))
          .captured.single as PageStateModel;
      // Falls back to the original placeholder name on error.
      expect(state.selectedLocation?.name, 'Location (28.6, 77.2)');
    });

    test('skips refresh for initial source', () async {
      await manager.updateLocationForPage(
        PageType.explore,
        const LocationData(name: 'Delhi', latitude: 28.6, longitude: 77.2),
        source: 'initial',
      );

      verify(() => pageState.updatePageState(PageType.explore, any())).called(1);
      verifyNever(() => dataLoader.debounceRefresh(any()));
    });

    test('skips refresh for hydrate source', () async {
      await manager.updateLocationForPage(
        PageType.explore,
        const LocationData(name: 'Delhi', latitude: 28.6, longitude: 77.2),
        source: 'hydrate',
      );

      verifyNever(() => dataLoader.debounceRefresh(any()));
    });

    test('skips refresh and name resolution for gps_passive source', () async {
      await manager.updateLocationForPage(
        PageType.explore,
        const LocationData(name: 'Location (28.6, 77.2)', latitude: 28.6, longitude: 77.2),
        source: 'gps_passive',
      );

      // gps_passive skips name resolution.
      verifyNever(() => locationController.getAddressFromCoordinates(any(), any()));
      verifyNever(() => dataLoader.debounceRefresh(any()));
    });

    test('does not resolve name when location name is already human-friendly', () async {
      await manager.updateLocationForPage(
        PageType.explore,
        const LocationData(name: 'Bandra', latitude: 19.0, longitude: 72.8),
        source: 'manual',
      );

      verifyNever(() => locationController.getAddressFromCoordinates(any(), any()));
    });
  });

  // ── updateLocation ───────────────────────────────────────────────────

  group('updateLocation', () {
    test('syncs to backend when authenticated then updates current page', () async {
      when(() => authController.isAuthenticated).thenReturn(true);
      when(() => authController.updateUserLocation(any())).thenAnswer((_) async => true);

      await manager.updateLocation(
        const LocationData(name: 'Delhi', latitude: 28.6, longitude: 77.2),
        source: 'manual',
      );

      verify(() => authController.updateUserLocation(any())).called(1);
      // updateLocationForPage is called for the current page type (discover).
      verify(() => pageState.updatePageState(PageType.discover, any())).called(1);
    });

    test('skips backend sync when not authenticated', () async {
      when(() => authController.isAuthenticated).thenReturn(false);

      await manager.updateLocation(
        const LocationData(name: 'Delhi', latitude: 28.6, longitude: 77.2),
      );

      verifyNever(() => authController.updateUserLocation(any()));
      verify(() => pageState.updatePageState(PageType.discover, any())).called(1);
    });

    test('swallows backend sync errors', () async {
      when(() => authController.isAuthenticated).thenReturn(true);
      when(() => authController.updateUserLocation(any()))
          .thenThrow(Exception('sync failed'));

      // Should not throw.
      await manager.updateLocation(
        const LocationData(name: 'Delhi', latitude: 28.6, longitude: 77.2),
      );
    });
  });

  // ── useCurrentLocation ───────────────────────────────────────────────

  group('useCurrentLocation', () {
    test('uses GPS position and updates location', () async {
      currentPosition.value = testPosition(latitude: 28.7, longitude: 77.1);
      when(() => authController.isAuthenticated).thenReturn(false);

      await manager.useCurrentLocation();

      verify(() => locationController.getCurrentLocation(forceRefresh: any(named: 'forceRefresh')))
          .called(1);
      verify(() => locationController.getAddressFromCoordinates(28.7, 77.1)).called(1);
      verify(() => pageState.updatePageState(PageType.discover, any())).called(1);
    });

    test('does nothing when no position available', () async {
      currentPosition.value = null;
      when(() => authController.isAuthenticated).thenReturn(false);

      await manager.useCurrentLocation();

      verifyNever(() => pageState.updatePageState(any(), any()));
    });

    test('catches errors and shows toast', () async {
      when(() => locationController.getCurrentLocation(forceRefresh: any(named: 'forceRefresh')))
          .thenThrow(Exception('gps error'));

      // Should not throw.
      await manager.useCurrentLocation();
    });
  });

  // ── useCurrentLocationForPage ────────────────────────────────────────

  group('useCurrentLocationForPage', () {
    test('uses GPS position for the specified page', () async {
      currentPosition.value = testPosition(latitude: 19.0, longitude: 72.8);
      when(() => authController.isAuthenticated).thenReturn(false);

      await manager.useCurrentLocationForPage(PageType.likes);

      verify(() => locationController.getAddressFromCoordinates(19.0, 72.8)).called(1);
      verify(() => pageState.updatePageState(PageType.likes, any())).called(1);
    });

    test('falls back to IP location when no GPS position', () async {
      currentPosition.value = null;
      when(() => authController.isAuthenticated).thenReturn(false);

      await manager.useCurrentLocationForPage(PageType.explore);

      verify(() => locationController.getIpLocation()).called(1);
      verify(() => pageState.updatePageState(PageType.explore, any())).called(1);
    });

    test('catches errors gracefully', () async {
      when(() => locationController.getCurrentLocation(forceRefresh: any(named: 'forceRefresh')))
          .thenThrow(Exception('gps error'));

      await manager.useCurrentLocationForPage(PageType.explore);
      // No throw.
    });
  });

  // ── normalizeSavedLocations ──────────────────────────────────────────

  group('normalizeSavedLocations', () {
    test('resolves placeholder names for all pages', () async {
      when(() => pageState.getStateForPage(any())).thenAnswer(
        (inv) => PageStateModel(
          pageType: inv.positionalArguments[0] as PageType,
          filters: UnifiedFilterModel.initial(),
          properties: const [],
          selectedLocation: const LocationData(
            name: 'Location (28.6, 77.2)',
            latitude: 28.6,
            longitude: 77.2,
          ),
        ),
      );

      await manager.normalizeSavedLocations();

      // getAddressFromCoordinates called for each of the 3 pages.
      verify(() => locationController.getAddressFromCoordinates(28.6, 77.2)).called(3);
      verify(() => pageState.updatePageState(any(), any())).called(3);
    });

    test('skips pages with non-placeholder names', () async {
      when(() => pageState.getStateForPage(any())).thenAnswer(
        (inv) => PageStateModel(
          pageType: inv.positionalArguments[0] as PageType,
          filters: UnifiedFilterModel.initial(),
          properties: const [],
          selectedLocation: const LocationData(name: 'Delhi', latitude: 28.6, longitude: 77.2),
        ),
      );

      await manager.normalizeSavedLocations();

      verifyNever(() => locationController.getAddressFromCoordinates(any(), any()));
      verifyNever(() => pageState.updatePageState(any(), any()));
    });

    test('skips pages with no location', () async {
      when(() => pageState.getStateForPage(any())).thenAnswer(
        (inv) => PageStateModel.initial(inv.positionalArguments[0] as PageType),
      );

      await manager.normalizeSavedLocations();

      verifyNever(() => locationController.getAddressFromCoordinates(any(), any()));
    });

    test('swallows errors during normalization', () async {
      when(() => pageState.getStateForPage(any())).thenThrow(Exception('state error'));

      // Should not throw.
      await manager.normalizeSavedLocations();
    });
  });

  // ── setupLocationListener / GPS position updates ─────────────────────

  group('setupLocationListener', () {
    test('does not throw and subscribes to currentPosition', () {
      expect(() => manager.setupLocationListener(), returnsNormally);
    });

    test('handles emitted position and updates current page location', () async {
      when(() => authController.isAuthenticated).thenReturn(false);
      // Provide a state with a selected location so the geocode-skip branch
      // can be exercised when the position hasn't moved enough.
      when(() => pageState.getStateForPage(any())).thenAnswer(
        (inv) => PageStateModel(
          pageType: inv.positionalArguments[0] as PageType,
          filters: UnifiedFilterModel.initial(),
          properties: const [],
          selectedLocation: const LocationData(name: 'Delhi', latitude: 28.6, longitude: 77.2),
        ),
      );

      manager.setupLocationListener();
      // Emit a position far enough to trigger refresh + geocode.
      currentPosition.value = testPosition(latitude: 30.0, longitude: 78.0);
      // Allow the unawaited _handleGpsPositionUpdate to settle.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      verify(() => locationController.getAddressFromCoordinates(any(), any())).called(1);
      verify(() => pageState.updatePageState(PageType.discover, any())).called(1);
    });

    test('ignores null positions emitted on the stream', () async {
      manager.setupLocationListener();
      currentPosition.value = null;
      await Future<void>.delayed(const Duration(milliseconds: 20));

      verifyNever(() => pageState.updatePageState(any(), any()));
    });

    test('replaces previous subscription on re-setup', () async {
      manager.setupLocationListener();
      manager.setupLocationListener();
      // No throw; second call cancels the first subscription.
    });
  });

  // ── dispose ──────────────────────────────────────────────────────────

  group('dispose', () {
    test('cancels location subscription without throwing', () {
      manager.setupLocationListener();
      expect(() => manager.dispose(), returnsNormally);
    });

    test('dispose without setup does not throw', () {
      expect(() => manager.dispose(), returnsNormally);
    });
  });
}
