import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/design/app_design_theme.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/app_toast.dart';
import 'package:ghar360/core/utils/image_cache_service.dart';
import 'package:ghar360/features/properties/application/property_location.dart';
import 'package:ghar360/features/properties/application/property_queries.dart';
import 'package:ghar360/features/properties/application/swipe_history.dart';
import 'package:go_router/go_router.dart';

import 'image_test_cache.dart';
import 'property_query_test_support.dart';

class ScreenQuery extends PropertyQuery {
  ScreenQuery(super.feed, this.initial);
  final PropertyPageState initial;
  int loads = 0, more = 0;
  bool? refreshed, retried;
  @override
  PropertyPageState build() => initial;
  void emit(PropertyPageState next) => state = next;
  @override
  Future<void> load({bool refresh = false}) async {
    loads++;
    refreshed = refresh;
  }

  @override
  Future<void> loadMore({bool retry = false}) async {
    more++;
    retried = retry;
  }
}

class ScreenHistory extends SwipeHistory {
  @override
  SwipeHistoryState build() => SwipeHistoryState(hydrated: true);
  void emit(SwipeHistoryState next) => state = next;
}

class PropertyScreenHarness {
  PropertyScreenHarness(
    this.data, {
    Map<PropertyFeed, PropertyPageState> pages = const {},
    SwipeHistory Function()? historyFactory,
  }) {
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appDatabaseProvider.overrideWithValue(data.database),
        storageScopeProvider.overrideWith(QueryScope.new),
        propertiesRepositoryProvider.overrideWithValue(data.properties),
        swipesRepositoryProvider.overrideWithValue(data.swipes),
        imageCacheServiceProvider.overrideWithValue(images.service),
        swipeHistoryProvider.overrideWith(historyFactory ?? ScreenHistory.new),
        for (final page in PageType.values)
          propertyLocationProvider(page).overrideWith(() => QueryLocation(page)),
        for (final feed in PropertyFeed.values)
          propertyQueryProvider(feed).overrideWith(
            () =>
                ScreenQuery(feed, pages[feed] ?? PropertyPageState(phase: PropertyLoadPhase.empty)),
          ),
      ],
    );
  }
  final PropertyQueryHarness data;
  final images = ImageTestCache();
  late final ProviderContainer container;
  GoRouter? router;
  ScreenQuery query(PropertyFeed feed) =>
      container.read(propertyQueryProvider(feed).notifier) as ScreenQuery;
  ScreenHistory get history => container.read(swipeHistoryProvider.notifier) as ScreenHistory;
  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    Size size = const Size(390, 844),
    double scale = 1,
    bool dark = false,
    Locale locale = const Locale('en', 'US'),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => screen),
        GoRoute(
          path: AppRoutes.propertyDetails,
          builder: (_, state) => Scaffold(body: Text('Details ${state.uri.queryParameters['id']}')),
        ),
        GoRoute(
          path: AppRoutes.assistant,
          builder: (_, _) => const Scaffold(body: Text('Assistant destination')),
        ),
        GoRoute(
          path: AppRoutes.phoneEntry,
          builder: (_, state) =>
              Scaffold(body: Text('Sign-in destination ${state.uri.queryParameters['from']}')),
        ),
        GoRoute(
          path: AppRoutes.discover,
          builder: (_, _) => const Scaffold(body: Text('Discover destination')),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppDesignTheme.light(),
          darkTheme: AppDesignTheme.dark(),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: true),
            child: AppToastHost(child: child!),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    router?.dispose();
    container.dispose();
    await tester.runAsync(data.close);
  }
}
