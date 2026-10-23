import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/services/google_places_service.dart';
import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/widgets/common/location_selector.dart';
import 'package:ghar360/features/location/application/location_search_controller.dart';
import 'package:ghar360/features/properties/application/property_filters.dart';
import '../../../helpers/knife_finders.dart';
import '../../../helpers/location_test_harness.dart';
import '../../../helpers/provider_test_app.dart';

void main() {
  late LocationTestHarness harness;
  setUp(() => harness = LocationTestHarness());
  tearDown(() => harness.dispose());
  Future<void> pump(
    WidgetTester tester, [
    PageType page = PageType.discover,
    double scale = 1,
    ThemeData? theme,
  ]) async {
    await tester.pumpProviderApp(
      UncontrolledProviderScope(
        container: harness.container,
        child: Scaffold(body: LocationSelector(pageType: page)),
      ),
      textScale: scale,
      theme: theme,
    );
    await tester.pumpAndSettle();
  }

  Future<void> open(
    WidgetTester tester, [
    PageType page = PageType.discover,
    double scale = 1,
    ThemeData? theme,
  ]) async {
    await pump(tester, page, scale, theme);
    await tester.tap(find.byType(LocationSelector));
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String value) async {
    await tester.enterText(find.byType(TextField), value);
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
  }

  Future<void> disposeWidget(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  testWidgets('renders icons, selected label, native identifier, and 48px target', (tester) async {
    await pump(tester);
    expect(findKnife(KnifeIcon.pin), findsOneWidget);
    expect(findKnife(KnifeIcon.chevronDown), findsOneWidget);
    expect(find.text('Select Location'), findsOneWidget);
    final target = find.byKey(const ValueKey('qa.location.selector.trigger.discover'));
    expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
    final node = tester.getSemantics(target);
    expect(node.identifier, 'qa.location.selector.trigger.discover');
    expect(node.label, isNot(contains('qa.')));
    await disposeWidget(tester);
  });
  testWidgets('shows saved location and uses Current Location for empty name', (tester) async {
    await harness.location(PageType.discover).select(delhi);
    await pump(tester);
    expect(
      find.descendant(of: find.byType(LocationSelector), matching: find.text('Delhi')),
      findsOneWidget,
    );
    await harness
        .location(PageType.discover)
        .select(const LocationData(name: '', latitude: 28.6, longitude: 77.2));
    await tester.pumpAndSettle();
    expect(find.text('Current Location'), findsOneWidget);
    await disposeWidget(tester);
  });
  testWidgets('opens picker with search, current location, radius, and close', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await open(tester, PageType.explore);
      expect(
        find.bySemanticsIdentifier('qa.location.selector.search_input.explore'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('qa.location.selector.use_current_location.explore'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp(r'qa\.location')), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      expect(find.text('Search radius'), findsOneWidget);
      expect(findKnife(KnifeIcon.locate), findsOneWidget);
      expect(find.text('Use Current Location'), findsOneWidget);
      await tester.tap(findKnife(KnifeIcon.close));
      await tester.pumpAndSettle();
      expect(find.byType(LocationPickerModal), findsNothing);
      await disposeWidget(tester);
    } finally {
      semantics.dispose();
    }
  });
  testWidgets('typing fetches suggestions and clear removes remote results', (tester) async {
    await open(tester, PageType.explore);
    await type(tester, 'Delhi');
    expect(find.textContaining('India'), findsOneWidget);
    expect(find.text('Delhi'), findsNWidgets(2));
    expect(harness.places.requests.single.fallback, isFalse);
    // The sheet close and the field clear are both bare close marks.
    expect(find.byTooltip('Clear Search'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear Search'));
    await tester.pumpAndSettle();
    expect(harness.container.read(locationSearchProvider(PageType.explore)).suggestions, isEmpty);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    await disposeWidget(tester);
  });
  testWidgets('empty response shows no locations and no error', (tester) async {
    await open(tester, PageType.explore);
    await type(tester, 'zzzzz');
    expect(find.text('No locations found'), findsOneWidget);
    expect(find.byKey(const ValueKey('failed_to_search_locations')), findsNothing);
    await disposeWidget(tester);
  });
  for (final page in [PageType.explore, PageType.likes]) {
    testWidgets('selecting a suggestion updates ${page.name} and selector', (tester) async {
      await open(tester, page);
      await type(tester, 'Delhi');
      await tester.tap(find.text('Delhi').last);
      await tester.pumpAndSettle();
      expect(harness.state(page).location?.name, 'Delhi');
      expect(harness.state(page).source, LocationSource.manual);
      expect(find.byType(LocationPickerModal), findsNothing);
      expect(
        find.descendant(of: find.byType(LocationSelector), matching: find.text('Delhi')),
        findsOneWidget,
      );
      await disposeWidget(tester);
    });
  }
  testWidgets('current location updates page and closes on committed result', (tester) async {
    await open(tester);
    await tester.tap(find.text('Use Current Location'));
    await tester.pumpAndSettle();
    expect(harness.state(PageType.discover).location?.name, 'Delhi');
    expect(harness.state(PageType.discover).source, LocationSource.gps);
    expect(find.byType(LocationPickerModal), findsNothing);
    await disposeWidget(tester);
  });
  testWidgets('radius range and changes update page filter', (tester) async {
    await open(tester, PageType.explore);
    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.min, 5);
    expect(slider.max, 50);
    slider.onChanged!(30);
    slider.onChangeEnd!(30);
    await tester.pumpAndSettle();
    expect(harness.container.read(propertyFiltersProvider).forPage(PageType.explore).radiusKm, 30);
    await disposeWidget(tester);
  });
  testWidgets('loading, search failure, retained input, and retry are distinct from empty', (
    tester,
  ) async {
    final pending = Completer<List<PlaceSuggestion>>();
    harness.places.response = (_) => pending.future;
    await open(tester, PageType.explore);
    await tester.enterText(find.byType(TextField), 'zzzzz');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('No locations found'), findsNothing);
    pending.completeError(NetworkException('secret response'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('failed_to_search_locations')), findsOneWidget);
    expect(find.text('No locations found'), findsNothing);
    expect(find.textContaining('secret response'), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'zzzzz');
    harness.places.response = (_) async => [
      const PlaceSuggestion(
        placeId: 'test',
        description: 'Local area',
        mainText: 'Local area',
        secondaryText: '',
      ),
    ];
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Local area'), findsOneWidget);
    expect(find.byKey(const ValueKey('failed_to_search_locations')), findsNothing);
    await disposeWidget(tester);
  });
  testWidgets('place details failure keeps query and offers retry without closing', (tester) async {
    harness.places.response = (_) async => [
      const PlaceSuggestion(
        placeId: 'test',
        description: 'Central',
        mainText: 'Central',
        secondaryText: '',
      ),
    ];
    harness.places.details = () async => throw NetworkException('details');
    await open(tester, PageType.explore);
    await type(tester, 'Central');
    await tester.tap(find.text('Central').last);
    await tester.pumpAndSettle();
    expect(find.byType(LocationPickerModal), findsOneWidget);
    expect(find.byKey(const ValueKey('location_details_failed')), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Central');
    harness.places.details = () async => mumbai;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(harness.state().location?.name, 'Mumbai');
    expect(find.byType(LocationPickerModal), findsNothing);
    await disposeWidget(tester);
  });
  testWidgets('GPS denial preserves manual location and manual search remains available', (
    tester,
  ) async {
    await harness.location(PageType.discover).select(mumbai);
    harness.device.response = () async =>
        throw LocationException('denied', code: 'LOCATION_DENIED_FOREVER');
    await open(tester);
    await tester.tap(find.text('Use Current Location'));
    await tester.pumpAndSettle();
    expect(harness.state(PageType.discover).location?.name, 'Mumbai');
    expect(find.byKey(const ValueKey('location_permission_permanently_denied')), findsOneWidget);
    await tester.ensureVisible(find.text('Open Settings'));
    await tester.tap(find.text('Open Settings'));
    await tester.pumpAndSettle();
    expect(harness.device.settingsCalls, 1);
    await type(tester, 'Delhi');
    final item = find.text('Delhi').last;
    await tester.ensureVisible(item);
    await tester.tap(item);
    await tester.pumpAndSettle();
    expect(harness.state(PageType.discover).location?.name, 'Delhi');
    await disposeWidget(tester);
  });
  testWidgets('a skipped location prompt shows no error in the picker', (tester) async {
    harness.device.response = () async =>
        throw LocationException('not asked', code: 'LOCATION_NOT_ASKED');
    await harness.location(PageType.discover).useCurrent(prompt: false);
    await open(tester);
    expect(find.text('Unable to get current location'), findsNothing);
    expect(find.text('Use Current Location'), findsOneWidget);
    await disposeWidget(tester);
  });
  testWidgets('disk failure retains selected area and exposes retry before closing', (
    tester,
  ) async {
    harness.database.writeError = StorageFailure('disk full');
    await open(tester, PageType.explore);
    await type(tester, 'Delhi');
    await tester.tap(find.text('Delhi').last);
    await tester.pumpAndSettle();
    expect(find.byType(LocationPickerModal), findsOneWidget);
    expect(harness.state().location?.name, 'Delhi');
    expect(find.byKey(const ValueKey('location_storage_failed')), findsOneWidget);
    harness.database.writeError = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(harness.state().save.hasError, isFalse);
    expect(find.byKey(const ValueKey('location_storage_failed')), findsNothing);
    await disposeWidget(tester);
  });
  testWidgets('account transition clears local input and previous results', (tester) async {
    await open(tester, PageType.explore);
    await type(tester, 'Delhi');
    harness.changeAccount('b');
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    expect(harness.container.read(locationSearchProvider(PageType.explore)).suggestions, isEmpty);
    await disposeWidget(tester);
  });
  for (final dark in [false, true]) {
    testWidgets(
      'narrow ${dark ? 'dark' : 'light'} picker supports large text and keyboard without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(320, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await open(tester, PageType.explore, 2, dark ? ThemeData.dark() : ThemeData.light());
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        addTearDown(tester.view.resetViewInsets);
        await tester.pump();
        await type(tester, 'Delhi');
        expect(tester.takeException(), isNull);
        expect(find.byType(LocationPickerModal), findsOneWidget);
        await disposeWidget(tester);
      },
    );
  }
}
