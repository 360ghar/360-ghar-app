import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:ghar360/core/controllers/page_state_service.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/translations/app_translations.dart';
import 'package:ghar360/core/widgets/common/property_filter_widget.dart';
import '../../../helpers/getx_test_binding.dart';
import '../../../helpers/mocks.dart';

class _FakePageStateService extends GetxServiceMock implements PageStateService {
  @override
  Rx<PageStateModel> discoverState = PageStateModel.initial(
    PageType.discover,
  ).copyWith(filters: const UnifiedFilterModel(purpose: 'buy')).obs;

  @override
  Rx<PageStateModel> exploreState = PageStateModel.initial(
    PageType.explore,
  ).copyWith(filters: const UnifiedFilterModel(purpose: 'buy')).obs;

  @override
  Rx<PageStateModel> likesState = PageStateModel.initial(
    PageType.likes,
  ).copyWith(filters: const UnifiedFilterModel(purpose: 'buy')).obs;

  @override
  final Rx<PageType> currentPageType = PageType.discover.obs;

  PageType? lastUpdatedPage;
  UnifiedFilterModel? lastUpdatedFilters;

  @override
  PageStateModel getStateForPage(PageType pageType) {
    switch (pageType) {
      case PageType.discover:
        return discoverState.value;
      case PageType.explore:
        return exploreState.value;
      case PageType.likes:
        return likesState.value;
    }
  }

  @override
  void updatePageFilters(PageType pageType, UnifiedFilterModel filters) {
    lastUpdatedPage = pageType;
    lastUpdatedFilters = filters;
    final state = getStateForPage(pageType).copyWith(filters: filters);
    switch (pageType) {
      case PageType.discover:
        discoverState.value = state;
        break;
      case PageType.explore:
        exploreState.value = state;
        break;
      case PageType.likes:
        likesState.value = state;
        break;
    }
  }
}

void main() {
  late _FakePageStateService pageStateService;

  setUp(() {
    GetxTestBinding.init();
    pageStateService = _FakePageStateService();
    GetxTestBinding.bind().register<PageStateService>(pageStateService);
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  // Suppress RenderFlex overflow errors from the dense filter chip layouts.
  FlutterError.onError = (FlutterErrorDetails details) {
    if (!details.summary.toString().contains('overflowed')) {
      FlutterError.presentError(details);
    }
  };

  Future<void> pumpFilterSheet(
    WidgetTester tester, {
    String pageType = 'explore',
    VoidCallback? onFiltersApplied,
  }) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        fallbackLocale: const Locale('en', 'US'),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: PropertyFilterWidget(pageType: pageType, onFiltersApplied: onFiltersApplied),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(PropertyFilterWidget));
    await tester.pumpAndSettle();
  }

  /// Scrolls the bottom sheet until [finder] is visible, then taps it.
  Future<void> scrollAndTap(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    await tester.tap(finder.first);
    await tester.pumpAndSettle();
  }

  /// Pumps past the AppToast snackbar timer so no timers remain pending.
  Future<void> clearToasts(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle(const Duration(seconds: 1));
  }

  testWidgets('applies filters to the page that opened the sheet, not the active tab', (
    tester,
  ) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        fallbackLocale: const Locale('en', 'US'),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showPropertyFilterBottomSheet(context, pageType: 'explore'),
              child: const Text('Open filters'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open filters'));
    await tester.pumpAndSettle();

    expect(find.text('Filter Properties'), findsOneWidget);

    await tester.tap(find.text('Rent').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Apply Filters'));
    await tester.pumpAndSettle();

    expect(pageStateService.lastUpdatedPage, PageType.explore);
    expect(pageStateService.exploreState.value.filters.purpose, 'rent');
    expect(pageStateService.discoverState.value.filters.purpose, 'buy');

    await clearToasts(tester);
  });

  testWidgets('renders the filter icon button', (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        fallbackLocale: const Locale('en', 'US'),
        home: const Scaffold(
          body: Center(child: PropertyFilterWidget(pageType: 'explore')),
        ),
      ),
    );

    expect(find.byIcon(Icons.tune), findsOneWidget);
    expect(find.byType(PropertyFilterWidget), findsOneWidget);
  });

  testWidgets('shows all filter section headers when opened', (tester) async {
    await pumpFilterSheet(tester);

    expect(find.text('Filter Properties'), findsOneWidget);
    expect(find.text('Purpose'), findsOneWidget);
    expect(find.text('Property price'), findsOneWidget);
    expect(find.text('Bedrooms'), findsOneWidget);
    expect(find.text('Property Type'), findsOneWidget);
    expect(find.text('Apply Filters'), findsOneWidget);
    expect(find.text('Clear Filters'), findsOneWidget);
  });

  testWidgets('switching purpose to rent updates the price label', (tester) async {
    await pumpFilterSheet(tester);

    expect(find.text('Property price'), findsOneWidget);

    await tester.tap(find.text('Rent').first);
    await tester.pumpAndSettle();

    expect(find.text('Price per month'), findsOneWidget);
  });

  testWidgets('switching purpose to short stay updates the price label', (tester) async {
    await pumpFilterSheet(tester);

    await tester.tap(find.text('Short Stay').first);
    await tester.pumpAndSettle();

    expect(find.text('Daily Rate'), findsOneWidget);
  });

  testWidgets('selecting pg property type auto-switches purpose to rent', (tester) async {
    await pumpFilterSheet(tester);

    await scrollAndTap(tester, find.text('PG'));

    expect(find.text('Price per month'), findsOneWidget);
    expect(find.text('PG / Flatmate Preferences'), findsOneWidget);
  });

  testWidgets('selecting flatmate shows preferences and auto-switches to rent', (tester) async {
    await pumpFilterSheet(tester);

    await scrollAndTap(tester, find.text('Flatmate'));

    expect(find.text('Price per month'), findsOneWidget);
    expect(find.text('PG / Flatmate Preferences'), findsOneWidget);
  });

  testWidgets('tapping "All" property type clears selected types', (tester) async {
    await pumpFilterSheet(tester);

    await scrollAndTap(tester, find.text('Apartment'));
    await scrollAndTap(tester, find.text('All'));

    expect(find.text('PG / Flatmate Preferences'), findsNothing);
  });

  testWidgets('toggling an amenity selects and deselects it', (tester) async {
    await pumpFilterSheet(tester);

    await scrollAndTap(tester, find.text('Gym'));
    expect(find.byIcon(Icons.check_circle), findsOneWidget);

    await scrollAndTap(tester, find.text('Gym'));
    expect(find.byIcon(Icons.check_circle), findsNothing);
  });

  testWidgets('clear filters resets to defaults', (tester) async {
    await pumpFilterSheet(tester);

    await tester.tap(find.text('Rent').first);
    await tester.pumpAndSettle();
    expect(find.text('Price per month'), findsOneWidget);

    await tester.tap(find.text('Clear Filters'));
    await tester.pumpAndSettle();

    expect(find.text('Property price'), findsOneWidget);
  });

  testWidgets('apply filters invokes onFiltersApplied callback', (tester) async {
    var callbackCalled = false;
    await pumpFilterSheet(tester, onFiltersApplied: () => callbackCalled = true);

    await tester.tap(find.text('Apply Filters'));
    await tester.pumpAndSettle();

    expect(callbackCalled, isTrue);
    await clearToasts(tester);
  });

  testWidgets('apply filters writes purpose and price to page state', (tester) async {
    await pumpFilterSheet(tester, pageType: 'likes');

    await tester.tap(find.text('Rent').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Apply Filters'));
    await tester.pumpAndSettle();

    expect(pageStateService.lastUpdatedPage, PageType.likes);
    expect(pageStateService.lastUpdatedFilters?.purpose, 'rent');
    expect(pageStateService.lastUpdatedFilters?.priceMin, isNotNull);
    await clearToasts(tester);
  });

  testWidgets('close button dismisses the filter sheet', (tester) async {
    await pumpFilterSheet(tester);

    expect(find.text('Filter Properties'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close).last);
    await tester.pumpAndSettle();

    expect(find.text('Filter Properties'), findsNothing);
  });

  testWidgets('resolves discover/home page type alias', (tester) async {
    await pumpFilterSheet(tester, pageType: 'discover');

    await tester.tap(find.text('Apply Filters'));
    await tester.pumpAndSettle();

    expect(pageStateService.lastUpdatedPage, PageType.discover);
    await clearToasts(tester);
  });

  testWidgets('resolves likes/favourites page type alias', (tester) async {
    await pumpFilterSheet(tester, pageType: 'favourites');

    await tester.tap(find.text('Apply Filters'));
    await tester.pumpAndSettle();

    expect(pageStateService.lastUpdatedPage, PageType.likes);
    await clearToasts(tester);
  });

  testWidgets('resolves favorites page type alias', (tester) async {
    await pumpFilterSheet(tester, pageType: 'favorites');

    await tester.tap(find.text('Apply Filters'));
    await tester.pumpAndSettle();

    expect(pageStateService.lastUpdatedPage, PageType.likes);
    await clearToasts(tester);
  });

  testWidgets('resolves home page type alias to discover', (tester) async {
    await pumpFilterSheet(tester, pageType: 'home');

    await tester.tap(find.text('Apply Filters'));
    await tester.pumpAndSettle();

    expect(pageStateService.lastUpdatedPage, PageType.discover);
    await clearToasts(tester);
  });

  testWidgets('loads existing filter state from PageStateService on open', (tester) async {
    pageStateService.exploreState.value = pageStateService.exploreState.value.copyWith(
      filters: const UnifiedFilterModel(purpose: 'rent', amenities: ['Gym']),
    );

    await pumpFilterSheet(tester, pageType: 'explore');

    expect(find.text('Price per month'), findsOneWidget);
    await scrollAndTap(tester, find.text('Gym'));
    // Gym was pre-selected, tapping deselects it → no check icon.
    expect(find.byIcon(Icons.check_circle), findsNothing);
  });

  testWidgets('falls back to defaults when PageStateService is not registered', (tester) async {
    GetxTestBinding.reset();
    GetxTestBinding.init();

    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        fallbackLocale: const Locale('en', 'US'),
        home: Scaffold(
          body: Builder(
            builder: (context) => const Center(child: PropertyFilterWidget(pageType: 'explore')),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(PropertyFilterWidget));
    await tester.pumpAndSettle();

    expect(find.text('Property price'), findsOneWidget);
    expect(find.text('Filter Properties'), findsOneWidget);
  });

  testWidgets('price range slider is rendered with correct bounds', (tester) async {
    await pumpFilterSheet(tester);

    final slider = tester.widget<RangeSlider>(find.byType(RangeSlider));
    expect(slider.min, 500000.0);
    expect(slider.max, 150000000.0);
  });

  testWidgets('selecting then deselecting a property type chip toggles state', (tester) async {
    await pumpFilterSheet(tester);

    await scrollAndTap(tester, find.text('Villa'));
    await scrollAndTap(tester, find.text('Villa'));

    expect(find.text('PG / Flatmate Preferences'), findsNothing);
  });

  testWidgets('switching away from rent removes pg/flatmate selections', (tester) async {
    await pumpFilterSheet(tester);

    await scrollAndTap(tester, find.text('PG'));
    expect(find.text('PG / Flatmate Preferences'), findsOneWidget);

    // Scroll back up to the purpose chips and tap Buy.
    await tester.scrollUntilVisible(
      find.text('Buy'),
      -200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buy').first);
    await tester.pumpAndSettle();

    expect(find.text('PG / Flatmate Preferences'), findsNothing);
  });

  testWidgets('apply filters persists selected amenities', (tester) async {
    await pumpFilterSheet(tester, pageType: 'explore');

    await scrollAndTap(tester, find.text('Pool'));

    await tester.tap(find.text('Apply Filters'));
    await tester.pumpAndSettle();

    expect(pageStateService.lastUpdatedFilters?.amenities, contains('Pool'));
    await clearToasts(tester);
  });

  testWidgets('apply filters persists selected property types', (tester) async {
    await pumpFilterSheet(tester, pageType: 'explore');

    await scrollAndTap(tester, find.text('Apartment'));

    await tester.tap(find.text('Apply Filters'));
    await tester.pumpAndSettle();

    expect(pageStateService.lastUpdatedFilters?.propertyType, contains('apartment'));
    await clearToasts(tester);
  });

  testWidgets('pg selection shows gender and sharing preference dropdowns', (tester) async {
    await pumpFilterSheet(tester, pageType: 'explore');

    await scrollAndTap(tester, find.text('PG'));
    await tester.pumpAndSettle();

    // The listing preferences section renders both dropdowns.
    expect(find.text('PG / Flatmate Preferences'), findsOneWidget);
    expect(find.text('Gender Preference'), findsOneWidget);
    expect(find.text('Room Type'), findsOneWidget);
    // Two dropdown form fields for gender + sharing type.
    expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(2));
  });
}
