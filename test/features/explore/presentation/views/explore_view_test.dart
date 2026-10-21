import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/config/app_config.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/data/ports/properties_port.dart';
import 'package:ghar360/core/design/app_design_theme.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/providers/pending_actions_provider.dart';
import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/explore/presentation/views/explore_view.dart';
import 'package:ghar360/features/explore/presentation/widgets/explore_map.dart';
import 'package:ghar360/features/explore/presentation/widgets/property_detail_pane.dart';
import 'package:ghar360/features/explore/presentation/widgets/property_horizontal_list.dart';
import 'package:ghar360/features/properties/application/property_filters.dart';
import 'package:ghar360/features/properties/application/property_queries.dart';
import 'package:ghar360/features/property_details/presentation/views/property_details_view.dart';
import 'package:ghar360/features/visits/presentation/controllers/visits_controller.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../../helpers/explore_test_harness.dart';
import '../../../../helpers/fake_explore_map_platform.dart';
import '../../../../helpers/knife_finders.dart';
import '../../../../helpers/provider_test_app.dart';
import '../../../../helpers/visits_test_support.dart';

class _DetailPort extends Fake implements PropertiesPort {
  @override
  Future<PropertyModel> getPropertyDetail(int propertyId) async => exploreProperty(propertyId);
}

void main() {
  late ExploreTestHarness harness;
  late MapLibrePlatform Function() original;
  setUp(() {
    harness = ExploreTestHarness(items: [exploreProperty(1), exploreProperty(2)]);
    original = MapLibrePlatform.createInstance;
    MapLibrePlatform.createInstance = FakeExploreMapPlatform.new;
  });
  tearDown(() async {
    MapLibrePlatform.createInstance = original;
    await harness.dispose();
  });
  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(400, 800),
    bool dark = false,
    double scale = 1,
    ThemeData? theme,
    Locale locale = const Locale('en', 'US'),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpProviderApp(
      UncontrolledProviderScope(container: harness.container, child: const ExploreView()),
      textScale: scale,
      locale: locale,
      theme: theme ?? (dark ? ThemeData.dark() : ThemeData.light()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  void seed(
    PropertyLoadPhase phase, {
    bool empty = false,
    AppException? error,
    AppException? paginationError,
  }) => harness.query.seed(
    PropertyPageState(
      phase: phase,
      items: empty ? [] : [exploreProperty(1), exploreProperty(2)],
      error: error,
      paginationError: paginationError,
      nextCursor: paginationError == null ? null : 'next',
    ),
  );
  for (final dark in [false, true]) {
    testWidgets(
      'loaded ${dark ? 'dark' : 'light'} screen keeps map, count, controls and QA identifier',
      (tester) async {
        await pump(tester, dark: dark);
        expect(find.byType(ExploreMap), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (widget) => widget is Semantics && widget.properties.identifier == 'qa.explore.screen',
          ),
          findsOneWidget,
        );
        expect(find.text('2 properties'), findsOneWidget);
        expect(find.textContaining('10 km'), findsOneWidget);
        expect(findKnife(KnifeIcon.plus), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsNothing);
        await dispose(tester);
      },
    );
    testWidgets('empty ${dark ? 'dark' : 'light'} screen preserves map and filter recovery', (
      tester,
    ) async {
      seed(PropertyLoadPhase.empty, empty: true);
      await pump(tester, dark: dark);
      expect(find.byType(ExploreMap), findsOneWidget);
      // The empty state takes the list's place; the map and its controls stay clear.
      expect(find.byKey(const ValueKey('qa.explore.empty.action')), findsOneWidget);
      expect(findKnife(KnifeIcon.plus), findsOneWidget);
      expect(find.text('Adjust Filters'), findsOneWidget);
      await tester.ensureVisible(find.text('Adjust Filters'));
      await tester.pump();
      await tester.tap(find.text('Adjust Filters'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Filter Properties'), findsOneWidget);
      await dispose(tester);
    });
    testWidgets('refresh failure ${dark ? 'dark' : 'light'} retains map/cards and retry', (
      tester,
    ) async {
      seed(PropertyLoadPhase.content, error: NetworkException('raw private details'));
      await pump(tester, dark: dark);
      expect(find.byType(ExploreMap), findsOneWidget);
      expect(find.text('Property 1'), findsOneWidget);
      expect(find.textContaining('raw private details'), findsNothing);
      final retry = find.byKey(const ValueKey('qa.explore.content.retry'));
      expect(retry, findsOneWidget);
      await tester.tap(retry);
      await tester.pump();
      expect(harness.query.refreshCalls, 1);
      await dispose(tester);
    });
  }
  for (final phase in [PropertyLoadPhase.loading, PropertyLoadPhase.idle]) {
    testWidgets('$phase without location shows loading; same phase with location keeps map', (
      tester,
    ) async {
      await harness.dispose();
      harness = ExploreTestHarness(located: false);
      seed(phase, empty: true);
      await pump(tester);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byType(ExploreMap), findsNothing);
      await harness.location.select(delhi);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(find.byType(ExploreMap), findsOneWidget);
      await dispose(tester);
    });
  }
  testWidgets('refresh progress retains cards and pagination retry follows failed cursor', (
    tester,
  ) async {
    seed(PropertyLoadPhase.refreshing);
    await pump(tester);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Property 1'), findsOneWidget);
    seed(PropertyLoadPhase.content, paginationError: NetworkException('offline'));
    await tester.pump();
    final retry = find.byKey(const ValueKey('qa.explore.content.retry'));
    await tester.tap(retry);
    await tester.pump();
    expect(harness.query.lastRetry, isTrue);
    expect(find.text('Property 1'), findsOneWidget);
    await dispose(tester);
  });
  for (final size in [const Size(400, 800), const Size(1000, 800), const Size(1400, 900)]) {
    testWidgets('map controls and loading-more layout work at width ${size.width}', (tester) async {
      seed(PropertyLoadPhase.paginating);
      await pump(tester, size: size);
      expect(find.byType(ExploreMap), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(find.byType(PropertyHorizontalList), findsOneWidget);
      expect(find.byType(PropertyDetailPane), size.width >= 840 ? findsOneWidget : findsNothing);
      await tester.tap(findKnife(KnifeIcon.plus));
      await tester.pump();
      expect(harness.state.zoom, 13);
      await tester.tap(findKnife(KnifeIcon.minus));
      await tester.pump();
      expect(harness.state.zoom, 12);
      await tester.tap(findKnife(KnifeIcon.map));
      await tester.pump();
      expect(harness.state.fitBounds, isTrue);
      await tester.tap(findKnife(KnifeIcon.locate));
      await tester.pump();
      expect(harness.device.currentCalls, 1);
      await dispose(tester);
    });
  }
  testWidgets('phone list handle supports collapse and expand with count retained', (tester) async {
    await pump(tester);
    final gesture = find.byWidgetPredicate(
      (widget) => widget is GestureDetector && widget.onVerticalDragEnd != null,
    );
    expect(gesture, findsOneWidget);
    await tester.tap(gesture);
    await tester.pump(const Duration(milliseconds: 300));
    expect(harness.state.collapsed, isTrue);
    expect(findKnife(KnifeIcon.chevronUp), findsOneWidget);
    await tester.tap(gesture);
    await tester.pump(const Duration(milliseconds: 300));
    expect(harness.state.collapsed, isFalse);
    expect(find.text('2 properties'), findsOneWidget);
    await dispose(tester);
  });
  testWidgets('search slip over the map writes the Explore search; controls clear the list', (
    tester,
  ) async {
    await pump(tester, size: const Size(320, 800), scale: 2);
    final input = find.byKey(const ValueKey('qa.topbar.search_input.explore'));
    expect(input, findsOneWidget);
    final map = tester.getRect(find.byType(ExploreMap));
    expect(map.contains(tester.getRect(input).center), isTrue);
    await tester.enterText(input, 'Sector 57');
    await tester.pump();
    expect(
      harness.container.read(propertyFiltersProvider).forPage(PageType.explore).searchQuery,
      'Sector 57',
    );
    // The map controls hang under the slip and stay above the list sheet.
    final fit = tester.getRect(find.byTooltip('Fit map to properties'));
    expect(fit.bottom, lessThan(tester.getRect(find.text('2 properties')).top));
    expect(tester.takeException(), isNull);
    await dispose(tester);
  });
  testWidgets('GPS failure retains usable map with location-specific retry', (tester) async {
    harness.device.response = () async => throw LocationException('GPS unavailable');
    await pump(tester);
    await tester.tap(findKnife(KnifeIcon.locate));
    await tester.pump();
    expect(find.byType(ExploreMap), findsOneWidget);
    expect(find.byKey(const ValueKey('qa.explore.location.gps_retry')), findsOneWidget);
    expect(find.text('Property 1'), findsOneWidget);
    await dispose(tester);
  });
  testWidgets('saved content and cache persistence failure remain visible beside the map', (
    tester,
  ) async {
    harness.query.seed(
      PropertyPageState(phase: PropertyLoadPhase.content, items: [exploreProperty(1)], stale: true),
    );
    await pump(tester);
    expect(find.text('Showing saved properties. Refresh to check for changes.'), findsOneWidget);
    expect(find.byType(ExploreMap), findsOneWidget);
    harness.query.seed(
      PropertyPageState(
        phase: PropertyLoadPhase.content,
        items: [exploreProperty(1)],
        storageError: StorageFailure('full'),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('qa.properties.save.retry')));
    await tester.pump();
    expect(harness.query.refreshCalls, 1);
    expect(find.byType(ExploreMap), findsOneWidget);
    await dispose(tester);
  });
  testWidgets('filter-save retry persists draft without clearing usable map or cards', (
    tester,
  ) async {
    harness.database.writeError = StorageFailure('full');
    await harness.container
        .read(propertyFiltersProvider.notifier)
        .update(PageType.explore, const UnifiedFilterModel(purpose: 'rent'));
    await pump(tester);
    expect(find.byKey(const ValueKey('qa.filters.save.retry')), findsOneWidget);
    expect(find.text('Property 1'), findsOneWidget);
    harness.database.writeError = null;
    await tester.tap(find.byKey(const ValueKey('qa.filters.save.retry')));
    await tester.pump();
    expect(find.byKey(const ValueKey('qa.filters.save.retry')), findsNothing);
    expect(find.byType(ExploreMap), findsOneWidget);
    await dispose(tester);
  });
  testWidgets('320px large-text content has no suppressed overflow errors', (tester) async {
    await pump(tester, size: const Size(320, 800), scale: 2);
    expect(find.byType(ExploreMap), findsOneWidget);
    expect(tester.takeException(), isNull);
    await dispose(tester);
  });
  testWidgets('320px Hindi 2x dark paper theme has no overflow', (tester) async {
    await pump(
      tester,
      size: const Size(320, 700),
      scale: 2,
      theme: AppDesignTheme.dark(),
      locale: const Locale('hi', 'IN'),
    );
    expect(find.byType(ExploreMap), findsOneWidget);
    expect(find.text('Property 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await dispose(tester);
  });
  testWidgets('camera moves and highlights do not rebuild the screen frame', (tester) async {
    await pump(tester);
    var frames = 0;
    final prior = debugOnRebuildDirtyWidget;
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      if (element.widget is ExploreView) frames++;
      prior?.call(element, builtOnce);
    };
    addTearDown(() => debugOnRebuildDirtyWidget = prior);
    harness.controller.onCameraIdle(const LatLng(28.7, 77.3), 13);
    await tester.pump();
    harness.controller.highlightPropertyFromCard(exploreProperty(2));
    await tester.pump();
    debugOnRebuildDirtyWidget = prior;
    expect(frames, 0);
    await dispose(tester);
  });

  group('two panes from 840 px', () {
    // The detail pane reads the app configuration.
    setUp(
      () => AppConfig.initialize(
        overrides: {'API_BASE_URL': 'https://test.invalid', 'GOOGLE_PLACES_API_KEY': ''},
      ),
    );
    tearDown(AppConfig.resetForTest);
    Future<ProviderContainer> pumpPanes(WidgetTester tester, Size size) async {
      final container = ProviderContainer(
        overrides: [
          ...harness.overrides,
          propertiesRepositoryProvider.overrideWithValue(_DetailPort()),
          visitsProvider.overrideWith(
            () => SeededVisitsController(VisitsState(phase: VisitLoadPhase.content)),
          ),
          pendingActionsProvider.overrideWith(SeededPendingActions.new),
        ],
        retry: (_, _) => null,
      );
      addTearDown(container.dispose);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpProviderApp(
        UncontrolledProviderScope(container: container, child: const ExploreView()),
        theme: AppDesignTheme.light(),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      return container;
    }

    testWidgets('1280x800: map and strip left; a tapped card opens in the right pane', (
      tester,
    ) async {
      await pumpPanes(tester, const Size(1280, 800));
      expect(find.byType(ExploreMap), findsOneWidget);
      expect(find.text('Pick a home'), findsOneWidget);
      await tester.tap(find.text('Property 2'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final pane = tester.widget<PropertyDetailsView>(find.byType(PropertyDetailsView));
      expect(pane.propertyId, 2);
      expect(pane.embedded, isTrue);
      expect(find.text('Pick a home'), findsNothing);
      // The pane opened in place: no route was pushed.
      expect(find.byType(ExploreView), findsOneWidget);
      expect(tester.takeException(), isNull);
      await dispose(tester);
    });

    testWidgets('834x1112 portrait tablet stays one pane', (tester) async {
      await pumpPanes(tester, const Size(834, 1112));
      expect(find.byType(PropertyDetailPane), findsNothing);
      expect(find.byType(PropertyHorizontalList), findsOneWidget);
      expect(tester.takeException(), isNull);
      await dispose(tester);
    });
  });
}
