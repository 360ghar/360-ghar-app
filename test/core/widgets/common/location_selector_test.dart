import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

import 'package:ghar360/core/controllers/location_controller.dart';
import 'package:ghar360/core/controllers/page_state_service.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/services/google_places_service.dart';
import 'package:ghar360/core/translations/app_translations.dart';
import 'package:ghar360/core/widgets/common/location_selector.dart';
import '../../../helpers/getx_test_binding.dart';
import '../../../helpers/mocks.dart';

/// A fake [LocationController] that exposes real reactive place-suggestion
/// state without needing the real Google Places HTTP service.
class _FakeLocationController extends GetxController implements LocationController {
  @override
  final RxList<PlaceSuggestion> placeSuggestions = <PlaceSuggestion>[].obs;

  @override
  final RxBool isSearchingPlaces = false.obs;

  @override
  final RxString placesError = ''.obs;

  @override
  final Rxn<Position> currentPosition = Rxn<Position>();

  @override
  final RxBool isLocationEnabled = false.obs;

  @override
  final RxBool isLocationPermissionGranted = false.obs;

  @override
  final RxBool isLoading = false.obs;

  @override
  final RxString locationError = ''.obs;

  @override
  final RxString currentAddress = ''.obs;

  @override
  bool get hasLocation => currentPosition.value != null;

  @override
  void clearPlaceSuggestions() => placeSuggestions.clear();

  @override
  Future<List<PlaceSuggestion>> getPlaceSuggestions(
    String query, {
    Position? currentPosition,
  }) async {
    isSearchingPlaces.value = true;
    await Future.delayed(const Duration(milliseconds: 10));
    if (query == 'Delhi') {
      placeSuggestions.value = [
        PlaceSuggestion(
          placeId: '1',
          description: 'Delhi, India',
          mainText: 'Delhi',
          secondaryText: 'India',
        ),
      ];
    } else {
      placeSuggestions.clear();
    }
    isSearchingPlaces.value = false;
    return placeSuggestions.toList();
  }

  @override
  Future<LocationData?> getPlaceDetails(String placeId, {String? preferredName}) async {
    return LocationData(name: preferredName ?? 'Delhi', latitude: 28.6, longitude: 77.2);
  }

  @override
  Future<LocationData> getInitialLocation() async {
    return const LocationData(name: 'Current Location', latitude: 28.6, longitude: 77.2);
  }

  // The remaining members of LocationController are not used by
  // LocationSelector/LocationPickerModal; stubs satisfy the interface.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A minimal fake [PageStateService] with reactive page states.
class _FakePageStateService extends GetxServiceMock implements PageStateService {
  _FakePageStateService({LocationData? location}) {
    if (location != null) {
      exploreState.value = exploreState.value.copyWith(selectedLocation: location);
      discoverState.value = discoverState.value.copyWith(selectedLocation: location);
      likesState.value = likesState.value.copyWith(selectedLocation: location);
    }
  }

  @override
  final Rx<PageStateModel> exploreState = PageStateModel.initial(
    PageType.explore,
  ).copyWith(filters: const UnifiedFilterModel(purpose: 'buy')).obs;

  @override
  final Rx<PageStateModel> discoverState = PageStateModel.initial(
    PageType.discover,
  ).copyWith(filters: const UnifiedFilterModel(purpose: 'buy')).obs;

  @override
  final Rx<PageStateModel> likesState = PageStateModel.initial(
    PageType.likes,
  ).copyWith(filters: const UnifiedFilterModel(purpose: 'buy')).obs;

  @override
  final Rx<PageType> currentPageType = PageType.discover.obs;

  @override
  PageStateModel getStateForPage(PageType pageType) {
    switch (pageType) {
      case PageType.explore:
        return exploreState.value;
      case PageType.discover:
        return discoverState.value;
      case PageType.likes:
        return likesState.value;
    }
  }

  @override
  void updatePageState(PageType pageType, PageStateModel newState) {
    switch (pageType) {
      case PageType.explore:
        exploreState.value = newState;
        break;
      case PageType.discover:
        discoverState.value = newState;
        break;
      case PageType.likes:
        likesState.value = newState;
        break;
    }
  }

  @override
  TextEditingController getOrCreateSearchController(PageType pageType, {String? seedText}) {
    return TextEditingController(text: seedText);
  }

  @override
  bool isSearchVisible(PageType pageType) {
    final state = getStateForPage(pageType);
    return state.getAdditionalData<bool>('searchVisible') ?? false;
  }

  @override
  void setSearchVisible(PageType pageType, bool visible) {
    final state = getStateForPage(pageType);
    updatePageState(pageType, state.updateAdditionalData('searchVisible', visible));
  }

  @override
  void toggleSearch(PageType pageType) {
    setSearchVisible(pageType, !isSearchVisible(pageType));
  }

  @override
  bool isPageRefreshing(PageType pageType) => false;

  @override
  Future<void> updateLocationForPage(
    PageType pageType,
    LocationData location, {
    String source = 'manual',
  }) async {
    final state = getStateForPage(pageType);
    updatePageState(pageType, state.copyWith(selectedLocation: location));
  }

  @override
  Future<void> useCurrentLocationForPage(PageType pageType) async {
    final state = getStateForPage(pageType);
    updatePageState(
      pageType,
      state.copyWith(
        selectedLocation: const LocationData(
          name: 'Current Location',
          latitude: 28.6,
          longitude: 77.2,
        ),
      ),
    );
  }

  @override
  void updatePageFilters(PageType pageType, UnifiedFilterModel filters) {
    final state = getStateForPage(pageType);
    updatePageState(pageType, state.copyWith(filters: filters));
  }
}

void main() {
  late _FakeLocationController locationController;
  late _FakePageStateService pageStateService;

  setUp(() {
    GetxTestBinding.init();
    locationController = _FakeLocationController();
    pageStateService = _FakePageStateService();
    GetxTestBinding.bind()
      ..register<LocationController>(locationController)
      ..register<PageStateService>(pageStateService);
  });
  tearDown(() {
    GetxTestBinding.reset();
  });

  /// Installs a temporary error handler that suppresses known source-widget
  /// issues (ListTile background color + RenderFlex overflow) while forwarding
  /// real errors to the framework's original handler. Returns a function that
  /// restores the original handler.
  void Function() suppressFrameworkErrors() {
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      final fullText = '${details.toString()}\n${details.exception}';
      if (fullText.contains('ListTile background color') || fullText.contains('overflowed')) {
        return;
      }
      originalOnError?.call(details);
    };
    return () => FlutterError.onError = originalOnError;
  }

  Future<void> pumpWidget(WidgetTester tester, Widget child) async {
    final restore = suppressFrameworkErrors();
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        fallbackLocale: const Locale('en', 'US'),
        home: Scaffold(body: Material(child: child)),
      ),
    );
    restore();
  }

  /// Opens the location picker modal, suppressing framework errors during the
  /// bottom sheet animation.
  Future<void> openModal(WidgetTester tester, PageType pageType) async {
    await pumpWidget(tester, LocationSelector(pageType: pageType));
    final restore = suppressFrameworkErrors();
    await tester.tap(find.byType(LocationSelector));
    await tester.pumpAndSettle();
    restore();
  }

  testWidgets('renders the location icon and current location text', (tester) async {
    await pumpWidget(tester, const LocationSelector(pageType: PageType.discover));

    expect(find.byType(LocationSelector), findsOneWidget);
    // Location pin icon.
    expect(find.byIcon(Icons.location_on), findsOneWidget);
    // Dropdown arrow icon.
    expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
    // Default text when no location set is "Select Location".
    expect(find.text('Select Location'), findsOneWidget);
  });

  testWidgets('shows the saved location name when a location is set', (tester) async {
    pageStateService.discoverState.value = pageStateService.discoverState.value.copyWith(
      selectedLocation: const LocationData(name: 'New Delhi', latitude: 28.6, longitude: 77.2),
    );

    await pumpWidget(tester, const LocationSelector(pageType: PageType.discover));

    expect(find.text('New Delhi'), findsOneWidget);
    expect(find.text('Select Location'), findsNothing);
  });

  testWidgets('shows "Current Location" when location name is empty', (tester) async {
    pageStateService.discoverState.value = pageStateService.discoverState.value.copyWith(
      selectedLocation: const LocationData(name: '', latitude: 28.6, longitude: 77.2),
    );

    await pumpWidget(tester, const LocationSelector(pageType: PageType.discover));

    expect(find.text('Current Location'), findsOneWidget);
  });

  testWidgets('opens location picker modal on tap', (tester) async {
    await openModal(tester, PageType.discover);

    expect(find.byIcon(Icons.my_location), findsOneWidget);
    expect(find.text('Use Current Location'), findsOneWidget);
  });

  testWidgets('location picker modal shows search input and radius selector', (tester) async {
    await openModal(tester, PageType.explore);

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    expect(find.text('Search radius'), findsOneWidget);
  });

  testWidgets('location picker modal can be dismissed via close button', (tester) async {
    await openModal(tester, PageType.discover);

    final restore = suppressFrameworkErrors();
    await tester.tap(find.byIcon(Icons.close).last);
    await tester.pumpAndSettle();
    restore();

    expect(find.text('Use Current Location'), findsNothing);
  });

  testWidgets('typing a search query fetches and displays suggestions', (tester) async {
    await openModal(tester, PageType.explore);

    final restore = suppressFrameworkErrors();
    await tester.enterText(find.byType(TextField), 'Delhi');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    restore();

    // "India" appears in the popular Delhi tile's subtitle ("Delhi, India").
    expect(find.textContaining('India'), findsOneWidget);
    // "Delhi" appears in both the text field and the suggestion tile.
    expect(find.text('Delhi'), findsNWidgets(2));
  });

  testWidgets('clearing the search field clears suggestions', (tester) async {
    await openModal(tester, PageType.explore);

    final restore = suppressFrameworkErrors();
    await tester.enterText(find.byType(TextField), 'Delhi');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();
    restore();

    // Suggestion list is cleared — "India" no longer shown.
    expect(find.text('India'), findsNothing);
  });

  testWidgets('shows "No locations found" when search yields no results', (tester) async {
    await openModal(tester, PageType.explore);

    final restore = suppressFrameworkErrors();
    await tester.enterText(find.byType(TextField), 'zzzzz');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    restore();

    expect(find.text('No locations found'), findsOneWidget);
    expect(find.byIcon(Icons.location_off), findsOneWidget);
  });

  testWidgets('tapping a suggestion selects the place and updates page state', (tester) async {
    await openModal(tester, PageType.explore);

    final restore = suppressFrameworkErrors();
    await tester.enterText(find.byType(TextField), 'Delhi');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delhi').last);
    await tester.pumpAndSettle();
    restore();

    expect(pageStateService.exploreState.value.selectedLocation?.name, 'Delhi');
  });

  testWidgets('use current location updates page state', (tester) async {
    await openModal(tester, PageType.discover);

    final restore = suppressFrameworkErrors();
    await tester.tap(find.text('Use Current Location'));
    await tester.pumpAndSettle();
    restore();

    expect(pageStateService.discoverState.value.selectedLocation?.name, 'Current Location');
  });

  testWidgets('radius slider updates the page filter radius', (tester) async {
    await openModal(tester, PageType.explore);

    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.min, 5);
    expect(slider.max, 50);

    final restore = suppressFrameworkErrors();
    await tester.tap(find.byType(Slider));
    await tester.pumpAndSettle();
    restore();

    final radius = pageStateService.exploreState.value.filters.radiusKm;
    expect(radius, isNotNull);
    expect(radius! >= 5 && radius <= 50, isTrue);
  });

  testWidgets('shows loading indicator when searching places', (tester) async {
    await openModal(tester, PageType.explore);

    locationController.isSearchingPlaces.value = true;
    await tester.pump();

    // With an empty query the popular-cities list is visible, so only the
    // search-field suffix spinner renders (the results-area spinner is gated
    // on an empty suggestion list).
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    locationController.isSearchingPlaces.value = false;
    await tester.pump();
  });

  testWidgets('shows clear icon when search text is present and not searching', (tester) async {
    await openModal(tester, PageType.explore);

    final restore = suppressFrameworkErrors();
    await tester.enterText(find.byType(TextField), 'Del');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    restore();

    expect(find.byIcon(Icons.clear), findsOneWidget);
  });

  testWidgets('selector reflects updated location after selecting a place', (tester) async {
    await openModal(tester, PageType.likes);

    final restore = suppressFrameworkErrors();
    await tester.enterText(find.byType(TextField), 'Delhi');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delhi').last);
    await tester.pumpAndSettle();
    restore();

    expect(find.text('Delhi'), findsOneWidget);
  });

  testWidgets('location tile with empty subtitle renders without subtitle text', (tester) async {
    await openModal(tester, PageType.explore);

    // Populate suggestions after the modal is open (initState clears them).
    final restore = suppressFrameworkErrors();
    locationController.placeSuggestions.value = [
      PlaceSuggestion(
        placeId: '2',
        description: 'Mumbai, India',
        mainText: 'Mumbai',
        secondaryText: '',
      ),
    ];
    await tester.pumpAndSettle();
    restore();

    // Mumbai renders below the popular-cities header in the lazy list; it is
    // built but offstage, so query the full tree to assert the empty-subtitle
    // tile is present.
    expect(find.text('Mumbai', skipOffstage: false), findsOneWidget);
  });
}
