import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/design/app_design_theme.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/widgets/common/property_filter_widget.dart';
import 'package:ghar360/features/properties/application/amenities.dart';
import 'package:ghar360/features/properties/application/property_filters.dart';
import '../../../helpers/knife_finders.dart';
import '../../../helpers/location_test_harness.dart';
import '../../../helpers/provider_test_app.dart';

/// The location fake plus an in-memory cache table.
class _AmenityDatabase extends LocationTestDatabase {
  final cache = <String, CachedEntry>{};
  int cacheWrites = 0;
  @override
  Future<CachedEntry?> readCache({
    required StorageScope scope,
    required String key,
    int expectedSchemaVersion = 1,
    DateTime? now,
  }) async => cache['${scope.key}:$key'];

  @override
  Future<void> writeCache({
    required StorageScope scope,
    required String key,
    required Object? value,
    required DateTime freshUntil,
    required DateTime expiresAt,
    String? etag,
    int schemaVersion = 1,
    DateTime? createdAt,
  }) async {
    cacheWrites++;
    cache['${scope.key}:$key'] = CachedEntry(
      value: value,
      createdAt: createdAt ?? DateTime.now(),
      freshUntil: freshUntil,
      expiresAt: expiresAt,
      schemaVersion: schemaVersion,
    );
  }

  void seedCache(List<String> titles, {required bool fresh}) {
    final now = DateTime.now();
    cache['${scope.key}:${Amenities.cacheKey}'] = CachedEntry(
      value: [
        for (final (index, title) in titles.indexed) {'id': index + 1, 'title': title},
      ],
      createdAt: now,
      freshUntil: fresh
          ? now.add(const Duration(hours: 1))
          : now.subtract(const Duration(hours: 1)),
      expiresAt: now.add(const Duration(days: 30)),
      schemaVersion: 1,
    );
  }
}

List<PropertyAmenity> _amenities(List<String> titles) => [
  for (final (index, title) in titles.indexed) PropertyAmenity(id: index + 1, title: title),
];

const _backendTitles = ['Gym', 'Parking', 'Security', 'Swimming Pool'];

void main() {
  late _AmenityDatabase database;
  late ProviderContainer container;
  late int fetches;
  late Future<List<PropertyAmenity>> Function() response;
  setUp(() {
    database = _AmenityDatabase();
    fetches = 0;
    response = () async => _amenities(_backendTitles);
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        storageScopeProvider.overrideWith(() => LocationScopeNotifier(database)),
        amenitiesFetchProvider.overrideWithValue(() {
          fetches++;
          return response();
        }),
      ],
      retry: (_, _) => null,
    );
  });
  tearDown(() => container.dispose());
  UnifiedFilterModel filters(PageType page) =>
      container.read(propertyFiltersProvider).forPage(page);
  Future<void> pumpHost(
    WidgetTester tester,
    Widget child, {
    Locale locale = const Locale('en', 'US'),
    double scale = 1,
    ThemeData? theme,
  }) => tester.pumpProviderApp(
    UncontrolledProviderScope(
      container: container,
      child: Scaffold(body: child),
    ),
    locale: locale,
    textScale: scale,
    theme: theme,
  );
  Future<void> pumpFilterSheet(
    WidgetTester tester, {
    PageType pageType = PageType.explore,
    VoidCallback? onFiltersApplied,
    Locale locale = const Locale('en', 'US'),
    double scale = 1,
    ThemeData? theme,
  }) async {
    await pumpHost(
      tester,
      Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => showPropertyFilterBottomSheet(
              context,
              pageType: pageType,
              onFiltersApplied: onFiltersApplied,
            ),
            child: const Text('Open filters'),
          ),
        ),
      ),
      locale: locale,
      scale: scale,
      theme: theme,
    );
    await tester.tap(find.text('Open filters'));
    await tester.pumpAndSettle();
  }

  bool chipSelected(WidgetTester tester, String label) =>
      tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label)).selected;

  Future<void> scrollAndTap(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    await tester.tap(finder.first);
    await tester.pumpAndSettle();
  }

  Future<void> clearToasts(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle(const Duration(seconds: 1));
  }

  testWidgets('applies local ranges to opening page and shared purpose to all pages', (
    tester,
  ) async {
    await pumpHost(
      tester,
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showPropertyFilterBottomSheet(context, pageType: PageType.explore),
          child: const Text('Open filters'),
        ),
      ),
    );
    await tester.tap(find.text('Open filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rent').first);
    await tester.tap(find.byKey(const ValueKey('qa.filters.apply')));
    await tester.pumpAndSettle();
    expect(filters(PageType.explore).purpose, 'rent');
    expect(filters(PageType.discover).purpose, 'rent');
    expect(filters(PageType.explore).priceMin, 5000);
    expect(filters(PageType.discover).priceMin, isNull);
    expect(database.preferences['property_filters_v1'], isNotNull);
    await clearToasts(tester);
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
    expect(chipSelected(tester, 'Gym'), isTrue);
    expect(
      find.descendant(
        of: find.widgetWithText(ChoiceChip, 'Gym'),
        matching: findKnife(KnifeIcon.check),
      ),
      findsOneWidget,
    );

    await scrollAndTap(tester, find.text('Gym'));
    expect(chipSelected(tester, 'Gym'), isFalse);
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
    await pumpFilterSheet(tester, pageType: PageType.likes);

    await tester.tap(find.text('Rent').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Apply Filters'));
    await tester.pumpAndSettle();

    expect(filters(PageType.likes).purpose, 'rent');
    expect(filters(PageType.likes).priceMin, isNotNull);
    await clearToasts(tester);
  });

  testWidgets('close button dismisses the filter sheet', (tester) async {
    await pumpFilterSheet(tester);

    expect(find.text('Filter Properties'), findsOneWidget);

    await tester.tap(findKnife(KnifeIcon.close).last);
    await tester.pumpAndSettle();

    expect(find.text('Filter Properties'), findsNothing);
  });

  testWidgets('loads saved filter state from provider on open', (tester) async {
    await container
        .read(propertyFiltersProvider.notifier)
        .update(PageType.explore, const UnifiedFilterModel(purpose: 'rent', amenities: ['Gym']));

    await pumpFilterSheet(tester, pageType: PageType.explore);

    expect(find.text('Price per month'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Gym'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(chipSelected(tester, 'Gym'), isTrue);
    await scrollAndTap(tester, find.text('Gym'));
    expect(chipSelected(tester, 'Gym'), isFalse);
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
    await pumpFilterSheet(tester, pageType: PageType.explore);

    await scrollAndTap(tester, find.text('Swimming Pool'));

    await tester.tap(find.text('Apply Filters'));
    await tester.pumpAndSettle();

    expect(filters(PageType.explore).amenities, contains('Swimming Pool'));
    await clearToasts(tester);
  });

  testWidgets('apply filters persists selected property types', (tester) async {
    await pumpFilterSheet(tester, pageType: PageType.explore);

    await scrollAndTap(tester, find.text('Apartment'));

    await tester.tap(find.text('Apply Filters'));
    await tester.pumpAndSettle();

    expect(filters(PageType.explore).propertyType, contains('apartment'));
    await clearToasts(tester);
  });

  testWidgets('pg selection shows gender and sharing preference dropdowns', (tester) async {
    await pumpFilterSheet(tester, pageType: PageType.explore);

    await scrollAndTap(tester, find.text('PG'));
    await tester.pumpAndSettle();

    // The listing preferences section renders both dropdowns.
    expect(find.text('PG / Flatmate Preferences'), findsOneWidget);
    expect(find.text('Gender Preference'), findsOneWidget);
    expect(find.text('Room Type'), findsOneWidget);
    // Two dropdown form fields for gender + sharing type.
    expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(2));
  });

  testWidgets('failed save retains selected draft and retries before callback or dismiss', (
    tester,
  ) async {
    var applied = 0;
    database.writeError = StorageFailure('disk full');
    await pumpFilterSheet(tester, onFiltersApplied: () => applied++);
    await tester.tap(find.text('Rent').first);
    await scrollAndTap(tester, find.text('Swimming Pool'));
    await tester.tap(find.byKey(const ValueKey('qa.filters.apply')));
    await tester.pumpAndSettle();
    expect(applied, 0);
    expect(find.text('Filter Properties'), findsOneWidget);
    expect(filters(PageType.explore).amenities, ['Swimming Pool']);
    expect(find.byKey(const ValueKey('qa.filters.sheet.retry')), findsOneWidget);
    database.writeError = null;
    await tester.tap(find.byKey(const ValueKey('qa.filters.sheet.retry')));
    await tester.pumpAndSettle();
    expect(applied, 1);
    expect(find.text('Filter Properties'), findsNothing);
    final stored = database.preferences['property_filters_v1'] as Map;
    expect(stored['explore']['amenities'], ['Swimming Pool']);
    await clearToasts(tester);
  });
  testWidgets('cancel does not persist edited draft', (tester) async {
    await pumpFilterSheet(tester);
    await tester.tap(find.text('Rent').first);
    await tester.tap(findKnife(KnifeIcon.close).last);
    await tester.pumpAndSettle();
    expect(filters(PageType.explore).purpose, 'buy');
    expect(database.preferences['property_filters_v1'], isNull);
  });
  testWidgets('saved high and reversed bedroom/price ranges open safely', (tester) async {
    await container
        .read(propertyFiltersProvider.notifier)
        .update(
          PageType.explore,
          const UnifiedFilterModel(
            purpose: 'buy',
            priceMin: 900000,
            priceMax: 600000,
            bedroomsMin: 8,
            bedroomsMax: 2,
          ),
        );
    await pumpFilterSheet(tester);
    final slider = tester.widget<RangeSlider>(find.byType(RangeSlider));
    expect(slider.values.start, 900000);
    expect(slider.values.end, 900000);
    expect(find.text('8+'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Hindi 2x at 320px localizes prices and keeps actions reachable after save failure', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    database.writeError = StorageFailure('disk full');
    await pumpFilterSheet(tester, locale: const Locale('hi', 'IN'), scale: 2);
    expect(find.text('₹5 लाख'), findsOneWidget);
    expect(find.text('₹15 करोड़'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('qa.filters.apply')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('qa.filters.sheet.retry')), findsOneWidget);
    expect(
      tester.getRect(find.byKey(const ValueKey('qa.filters.apply'))).bottom,
      lessThanOrEqualTo(800),
    );
    expect(tester.takeException(), isNull);
  });

  Future<void> showAmenities(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('qa.filters.amenities')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
  }

  group('amenities from GET /amenities', () {
    testWidgets('lists backend titles, so Balcony and Terrace are gone, and caches them', (
      tester,
    ) async {
      await pumpFilterSheet(tester);
      await showAmenities(tester);
      expect(find.text('Swimming Pool'), findsOneWidget);
      expect(find.text('Balcony'), findsNothing);
      expect(find.text('Terrace'), findsNothing);
      expect(fetches, 1);
      expect(database.cacheWrites, 1);
    });

    testWidgets('a fresh cache shows at once and skips the request', (tester) async {
      database.seedCache(['Gym', 'Lift'], fresh: true);
      await pumpFilterSheet(tester);
      await showAmenities(tester);
      expect(find.text('Lift'), findsOneWidget);
      expect(fetches, 0);
    });

    testWidgets('a stale cache shows at once, then the refreshed list replaces it', (tester) async {
      database.seedCache(['Gym', 'Lift'], fresh: false);
      final pending = Completer<List<PropertyAmenity>>();
      response = () => pending.future;
      await pumpFilterSheet(tester);
      await showAmenities(tester);
      expect(find.text('Lift'), findsOneWidget);
      expect(fetches, 1);
      pending.complete(_amenities(_backendTitles));
      await tester.pumpAndSettle();
      expect(find.text('Lift'), findsNothing);
      expect(find.text('Swimming Pool'), findsOneWidget);
    });

    testWidgets('a failed refresh keeps the cached list without an error', (tester) async {
      database.seedCache(['Gym', 'Lift'], fresh: false);
      response = () async => throw NetworkException('offline');
      await pumpFilterSheet(tester);
      await showAmenities(tester);
      expect(find.text('Lift'), findsOneWidget);
      expect(find.text('Amenities could not load.'), findsNothing);
    });

    testWidgets('a failed first load shows retry in the amenities section only', (tester) async {
      response = () async => throw NetworkException('offline');
      await pumpFilterSheet(tester);
      await showAmenities(tester);
      final section = find.byKey(const ValueKey('qa.filters.amenities'));
      expect(
        find.descendant(of: section, matching: find.text('Amenities could not load.')),
        findsOneWidget,
      );
      // The rest of the sheet still works.
      expect(find.byKey(const ValueKey('qa.filters.apply')), findsOneWidget);
      response = () async => _amenities(_backendTitles);
      await tester.tap(find.byKey(const ValueKey('qa.filters.amenities.retry')));
      await tester.pumpAndSettle();
      expect(find.text('Amenities could not load.'), findsNothing);
      expect(find.text('Gym'), findsOneWidget);
      expect(fetches, 2);
    });

    testWidgets('a saved title the backend does not list is dropped on apply', (tester) async {
      await container
          .read(propertyFiltersProvider.notifier)
          .update(PageType.explore, const UnifiedFilterModel(amenities: ['Balcony', 'gym']));
      await pumpFilterSheet(tester);
      await showAmenities(tester);
      expect(chipSelected(tester, 'Gym'), isTrue);
      await tester.tap(find.byKey(const ValueKey('qa.filters.apply')));
      await tester.pumpAndSettle();
      expect(filters(PageType.explore).amenities, ['Gym']);
      await clearToasts(tester);
    });
  });
  testWidgets('320px Hindi 2x dark paper sheet with an amenities failure has no overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    response = () async => throw NetworkException('offline');
    await pumpFilterSheet(
      tester,
      locale: const Locale('hi', 'IN'),
      scale: 2,
      theme: AppDesignTheme.dark(),
    );
    await showAmenities(tester);
    expect(find.byKey(const ValueKey('qa.filters.amenities.retry')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('बिल्डर फ्लोर'),
      -200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(tester.takeException(), isNull);
  });
}
