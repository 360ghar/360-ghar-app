import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/bootstrap/app_effects.dart';
import 'package:ghar360/core/config/app_config.dart';
import 'package:ghar360/core/controllers/app_update_controller.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/providers/deep_link_provider.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/routes/app_pages.dart';
import 'package:ghar360/core/services/deep_link_service.dart';
import 'package:ghar360/features/properties/application/property_location.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/location_test_harness.dart';

class _Updates extends AppUpdateController {
  @override
  AppUpdateState build() => const AppUpdateState();
}

class _Visibility extends PropertyLocation {
  _Visibility(super.page, this.events);
  final List<(PageType, bool, String?)> events;
  @override
  PropertyLocationState build() {
    ref.watch(storageScopeProvider);
    return const PropertyLocationState();
  }

  @override
  void setVisible(bool visible) {
    events.add((page, visible, ref.read(storageScopeProvider).accountId));
  }
}

void main() {
  late GoRouter router;
  late ProviderContainer container;
  late LocationTestDatabase database;
  final events = <(PageType, bool, String?)>[];
  setUp(() {
    AppConfig.initialize(
      overrides: {
        'SUPABASE_URL': 'https://example.supabase.co',
        'SUPABASE_PUBLISHABLE_KEY': 'test',
        'FIREBASE_ENABLED': 'false',
      },
    );
    database = LocationTestDatabase();
    events.clear();
    final navigator = GlobalKey<NavigatorState>();
    router = GoRouter(
      navigatorKey: navigator,
      initialLocation: '/discover',
      routes: [
        for (final path in ['/discover', '/explore', '/likes', '/property/42', '/tour', '/profile'])
          GoRoute(
            path: path,
            builder: (_, _) => Scaffold(body: Text(path)),
          ),
      ],
    );
    container = ProviderContainer(
      overrides: [
        appRouterProvider.overrideWithValue(router),
        rootNavigatorKeyProvider.overrideWithValue(navigator),
        appDatabaseProvider.overrideWithValue(database),
        storageScopeProvider.overrideWith(() => LocationScopeNotifier(database)),
        appUpdateProvider.overrideWith(_Updates.new),
        deepLinkServiceProvider.overrideWithValue(
          DeepLinkService(
            initialLink: () async => null,
            links: const Stream.empty(),
            completeOAuth: (_) async {},
            navigate: (_) {},
            oauthState: (_) {},
          ),
        ),
        for (final page in PageType.values)
          propertyLocationProvider(page).overrideWith(() => _Visibility(page, events)),
      ],
    );
  });
  tearDown(() {
    container.dispose();
    router.dispose();
    AppConfig.resetForTest();
  });
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          builder: (_, child) => AppEffects(child: child!),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('imperative push stops the covered feed and pop resumes only it', (tester) async {
    await pump(tester);
    expect(events, [(PageType.discover, true, 'a')]);
    unawaited(router.push('/property/42'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/property/42');
    expect(events.last, (PageType.discover, false, 'a'));
    unawaited(router.push('/tour'));
    await tester.pumpAndSettle();
    expect(events, hasLength(2));
    router.pop();
    await tester.pumpAndSettle();
    expect(events, hasLength(2));
    router.pop();
    await tester.pumpAndSettle();
    expect(events.last, (PageType.discover, true, 'a'));
  });

  testWidgets('branch changes deactivate old location before activating new one', (tester) async {
    await pump(tester);
    router.go('/explore');
    await tester.pumpAndSettle();
    router.go('/likes');
    await tester.pumpAndSettle();
    router.go('/profile');
    await tester.pumpAndSettle();
    expect(events, [
      (PageType.discover, true, 'a'),
      (PageType.discover, false, 'a'),
      (PageType.explore, true, 'a'),
      (PageType.explore, false, 'a'),
      (PageType.likes, true, 'a'),
      (PageType.likes, false, 'a'),
    ]);
  });

  testWidgets('background and resumed state follow the current top route', (tester) async {
    await pump(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(events.last, (PageType.discover, false, 'a'));
    router.go('/explore');
    await tester.pumpAndSettle();
    expect(events.last, (PageType.discover, false, 'a'));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(events.last, (PageType.explore, true, 'a'));
  });

  testWidgets('an effects owner mounted while inactive does not start GPS', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await pump(tester);
    expect(events, isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(events, [(PageType.discover, true, 'a')]);
  });

  testWidgets('account transition restores visibility to the rebuilt current provider', (
    tester,
  ) async {
    await pump(tester);
    (container.read(storageScopeProvider.notifier) as LocationScopeNotifier).change('b');
    await tester.pumpAndSettle();
    expect(events.last, (PageType.discover, true, 'b'));
    expect(events.where((event) => event.$2 && event.$3 == 'b'), hasLength(1));
  });
}
