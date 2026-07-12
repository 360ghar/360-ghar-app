// test/features/location_search/presentation/views/location_search_view_test.dart

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

import 'package:ghar360/core/controllers/location_controller.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/services/google_places_service.dart';
import 'package:ghar360/features/location_search/presentation/controllers/location_search_controller.dart';
import 'package:ghar360/features/location_search/presentation/views/location_search_view.dart';
import '../../../../helpers/getx_test_binding.dart';
import '../../../../helpers/pump_app.dart';

// ---------------------------------------------------------------------------
// Fake LocationController — provides reactive fields the view reads without
// touching Geolocator/GooglePlaces/AuthController.
// ---------------------------------------------------------------------------

class _FakeLocationController extends LocationController {
  final RxList<PlaceSuggestion> suggestions = <PlaceSuggestion>[].obs;
  final RxBool searching = false.obs;

  @override
  RxList<PlaceSuggestion> get placeSuggestions => suggestions;

  @override
  RxBool get isSearchingPlaces => searching;

  @override
  void clearPlaceSuggestions() => suggestions.clear();

  @override
  Future<List<PlaceSuggestion>> getPlaceSuggestions(String query) async => suggestions;

  @override
  Future<LocationData?> getPlaceDetails(String placeId, {String? preferredName}) async => null;

  @override
  Future<void> getCurrentLocation({bool forceRefresh = false}) async {}

  @override
  Future<String> getAddressFromCoordinates(double latitude, double longitude) async =>
      'Test Address';

  /// Sets a fake current position so [hasLocation] returns true.
  void setHasLocation(bool value) {
    currentPosition.value = value
        ? Position(
            longitude: 77.0,
            latitude: 12.0,
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            altitudeAccuracy: 0,
            heading: 0,
            headingAccuracy: 0,
            speed: 0,
            speedAccuracy: 0,
          )
        : null;
  }
}

PlaceSuggestion _suggestion({String id = '1'}) => PlaceSuggestion(
      placeId: id,
      description: 'Test Description $id',
      mainText: 'Main Text $id',
      secondaryText: 'Secondary Text $id',
    );

// ---------------------------------------------------------------------------
// Test controller — overrides async actions that would call AppToast/Get.back
// so widget tests stay deterministic and free of pending snackbar timers.
// ---------------------------------------------------------------------------

class _TestLocationSearchController extends LocationSearchController {
  PlaceSuggestion? selectedPlace;

  @override
  Future<void> selectPlace(PlaceSuggestion suggestion) async {
    selectedPlace = suggestion;
  }

  @override
  Future<void> useCurrentLocation() async {}
}

void main() {
  late _FakeLocationController locationController;
  late _TestLocationSearchController searchController;

  setUp(() {
    GetxTestBinding.init();
    locationController = _FakeLocationController();
    searchController = _TestLocationSearchController();
    GetxTestBinding.bind()
      ..register<LocationController>(locationController)
      ..register<LocationSearchController>(searchController);
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  group('LocationSearchView', () {
    testWidgets('renders screen with search input', (tester) async {
      await tester.pumpApp(const LocationSearchView());
      await tester.pump();

      expect(find.byKey(const ValueKey('qa.location_search.screen')), findsOneWidget);
      expect(find.byKey(const ValueKey('qa.location_search.search_input')), findsOneWidget);
    });

    testWidgets('shows search prompt when no query and no suggestions', (tester) async {
      await tester.pumpApp(const LocationSearchView());
      await tester.pump();

      expect(find.byIcon(Icons.search), findsWidgets);
      expect(find.text('search_city_or_area_hint'.tr), findsWidgets);
    });

    testWidgets('shows clear button when query is non-empty and clears on tap',
        (tester) async {
      await tester.pumpApp(const LocationSearchView());
      await tester.pump();

      // Type into the search field.
      await tester.enterText(
        find.byKey(const ValueKey('qa.location_search.search_input')),
        'Mumbai',
      );
      await tester.pump();

      // Clear button (Icons.clear) appears.
      expect(find.byIcon(Icons.clear), findsOneWidget);

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();

      // Query is cleared.
      expect(searchController.searchQuery.value, isEmpty);
      expect(locationController.suggestions, isEmpty);

      // Let the debounce worker fire so no pending timer remains.
      await tester.pump(const Duration(milliseconds: 600));
    });

    testWidgets('shows current location tile without location', (tester) async {
      locationController.setHasLocation(false);

      await tester.pumpApp(const LocationSearchView());
      await tester.pump();

      expect(
        find.byKey(const ValueKey('qa.location_search.use_current_location')),
        findsOneWidget,
      );
      expect(find.text('use_current_location'.tr), findsOneWidget);
      expect(find.text('tap_to_get_current_location'.tr), findsOneWidget);
    });

    testWidgets('shows current location tile with address when location available',
        (tester) async {
      locationController.setHasLocation(true);
      locationController.currentAddress.value = 'Bangalore, IN';

      await tester.pumpApp(const LocationSearchView());
      await tester.pump();

      expect(find.text('Bangalore, IN'), findsOneWidget);
    });

    testWidgets('shows current location tile with fallback text when address empty',
        (tester) async {
      locationController.setHasLocation(true);
      locationController.currentAddress.value = '';

      await tester.pumpApp(const LocationSearchView());
      await tester.pump();

      expect(find.text('location_found'.tr), findsOneWidget);
    });

    testWidgets('shows loading indicator when searching places', (tester) async {
      locationController.searching.value = true;

      await tester.pumpApp(const LocationSearchView());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows loading indicator when controller isLoading', (tester) async {
      searchController.isLoading.value = true;

      await tester.pumpApp(const LocationSearchView());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows empty state when query non-empty and no suggestions', (tester) async {
      searchController.searchQuery.value = 'XYZ';
      locationController.suggestions.clear();

      await tester.pumpApp(const LocationSearchView());
      await tester.pump();

      expect(find.byIcon(Icons.search_off), findsOneWidget);
      expect(find.text('no_locations_found'.tr), findsOneWidget);

      // Let the debounce worker fire so no pending timer remains.
      await tester.pump(const Duration(milliseconds: 600));
    });

    testWidgets('shows error state when searchError is set', (tester) async {
      searchController.searchError.value = 'Something went wrong';

      await tester.pumpApp(const LocationSearchView());
      await tester.pump();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Something went wrong'), findsOneWidget);
    });

    testWidgets('renders suggestion list and tapping a suggestion calls selectPlace',
        (tester) async {
      locationController.suggestions.assignAll([_suggestion(id: '1'), _suggestion(id: '2')]);

      await tester.pumpApp(const LocationSearchView());
      await tester.pump();

      expect(find.text('Main Text 1'), findsOneWidget);
      expect(find.text('Main Text 2'), findsOneWidget);
      expect(find.text('Secondary Text 1'), findsOneWidget);

      // Tap the first suggestion.
      await tester.tap(find.text('Main Text 1'));
      await tester.pump();

      expect(searchController.selectedPlace, isNotNull);
      expect(searchController.selectedPlace!.placeId, '1');
    });

    testWidgets('suggestion with empty secondaryText renders without subtitle',
        (tester) async {
      locationController.suggestions.assignAll([
        PlaceSuggestion(
          placeId: '3',
          description: 'No Secondary',
          mainText: 'No Secondary',
          secondaryText: '',
        ),
      ]);

      await tester.pumpApp(const LocationSearchView());
      await tester.pump();

      expect(find.text('No Secondary'), findsOneWidget);
    });
  });
}
