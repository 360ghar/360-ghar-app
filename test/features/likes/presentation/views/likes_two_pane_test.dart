import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:ghar360/core/config/app_config.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/data/ports/properties_port.dart';
import 'package:ghar360/core/design/app_design_theme.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/providers/pending_actions_provider.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/image_cache_service.dart';
import 'package:ghar360/core/widgets/common/property_list_card.dart';
import 'package:ghar360/core/widgets/navigation/bottom_nav_bar.dart';
import 'package:ghar360/features/dashboard/presentation/views/dashboard_view.dart';
import 'package:ghar360/features/explore/presentation/widgets/property_detail_pane.dart';
import 'package:ghar360/features/likes/presentation/views/likes_view.dart';
import 'package:ghar360/features/properties/application/property_location.dart';
import 'package:ghar360/features/properties/application/property_queries.dart';
import 'package:ghar360/features/properties/application/swipe_history.dart';
import 'package:ghar360/features/property_details/presentation/views/property_details_view.dart';
import 'package:ghar360/features/visits/presentation/controllers/visits_controller.dart';
import '../../../../helpers/fake_explore_map_platform.dart';
import '../../../../helpers/image_test_cache.dart';
import '../../../../helpers/property_query_test_support.dart';
import '../../../../helpers/property_screen_harness.dart';
import '../../../../helpers/visits_test_support.dart';

class _DetailPort extends Fake implements PropertiesPort {
  @override
  Future<PropertyModel> getPropertyDetail(int propertyId) async => queryProperty(propertyId);
}

/// Saved inside the real dashboard shell, so a portrait tablet shows the rail.
void main() {
  late PropertyQueryHarness data;
  late ProviderContainer container;
  late GoRouter router;
  late MapLibrePlatform Function() originalMap;
  setUp(() {
    AppConfig.initialize(
      overrides: {'API_BASE_URL': 'https://test.invalid', 'GOOGLE_PLACES_API_KEY': ''},
    );
    originalMap = MapLibrePlatform.createInstance;
    MapLibrePlatform.createInstance = FakeExploreMapPlatform.new;
  });
  tearDown(() {
    MapLibrePlatform.createInstance = originalMap;
    AppConfig.resetForTest();
  });

  Future<void> pump(WidgetTester tester, Size size) async {
    data = (await tester.runAsync(PropertyQueryHarness.create))!;
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appDatabaseProvider.overrideWithValue(data.database),
        storageScopeProvider.overrideWith(QueryScope.new),
        propertiesRepositoryProvider.overrideWithValue(_DetailPort()),
        swipesRepositoryProvider.overrideWithValue(data.swipes),
        imageCacheServiceProvider.overrideWithValue(ImageTestCache().service),
        swipeHistoryProvider.overrideWith(ScreenHistory.new),
        visitsProvider.overrideWith(
          () => SeededVisitsController(VisitsState(phase: VisitLoadPhase.content)),
        ),
        pendingActionsProvider.overrideWith(SeededPendingActions.new),
        for (final page in PageType.values)
          propertyLocationProvider(page).overrideWith(() => QueryLocation(page)),
        for (final feed in PropertyFeed.values)
          propertyQueryProvider(feed).overrideWith(
            () => ScreenQuery(
              feed,
              feed == PropertyFeed.liked
                  ? PropertyPageState(
                      phase: PropertyLoadPhase.content,
                      items: [queryProperty(1), queryProperty(2)],
                    )
                  : PropertyPageState(phase: PropertyLoadPhase.empty),
            ),
          ),
      ],
    );
    router = GoRouter(
      initialLocation: '/likes',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, _, shell) => DashboardView(navigationShell: shell),
          branches: [
            for (final path in ['/discover', '/explore', '/likes', '/visits', '/profile'])
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: path,
                    builder: (_, _) =>
                        path == '/likes' ? const LikesView() : Scaffold(body: Text(path)),
                  ),
                ],
              ),
          ],
        ),
        GoRoute(
          path: AppRoutes.propertyDetails,
          builder: (_, state) => Scaffold(body: Text('Details ${state.uri.queryParameters['id']}')),
        ),
      ],
    );
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppDesignTheme.light(),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    container.dispose();
    await tester.runAsync(data.close);
  }

  testWidgets('1280x800: rail, list left, the tapped row opens in the right pane', (tester) async {
    await pump(tester, const Size(1280, 800));
    expect(find.byType(PaperNavigationRail), findsOneWidget);
    expect(find.byType(PropertyDetailPane), findsOneWidget);
    expect(find.text('Pick a home'), findsOneWidget);
    await tester.tap(find.text('Property 2'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final pane = tester.widget<PropertyDetailsView>(find.byType(PropertyDetailsView));
    expect(pane.propertyId, 2);
    expect(pane.embedded, isTrue);
    expect(router.state.uri.path, '/likes');
    final open = tester.widgetList<PropertyListCard>(find.byType(PropertyListCard));
    expect(open.where((card) => card.selected).map((card) => card.property.id), [2]);
    expect(tester.takeException(), isNull);
    // The row and the pane show the same home; only the row's photo is a
    // hero, so pushing a page does not find two heroes with one tag.
    expect(
      find.ancestor(of: find.byType(PropertyDetailsView), matching: find.byType(HeroMode)),
      findsWidgets,
    );
    expect(
      tester
          .widgetList<HeroMode>(
            find.ancestor(of: find.byType(PropertyDetailsView), matching: find.byType(HeroMode)),
          )
          .first
          .enabled,
      isFalse,
    );
    unawaited(router.push(AppRoutes.detailsFor(2)));
    await tester.pumpAndSettle();
    expect(find.text('Details 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('834x1112 portrait tablet: rail and one pane; a row pushes details', (tester) async {
    await pump(tester, const Size(834, 1112));
    expect(find.byType(PaperNavigationRail), findsOneWidget);
    expect(find.byType(PropertyDetailPane), findsNothing);
    await tester.tap(find.text('Property 1'));
    await tester.pumpAndSettle();
    expect(find.text('Details 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await close(tester);
  });
}
