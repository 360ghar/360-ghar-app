import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/data/models/auth_status.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/providers/auth_providers.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/routes/app_pages.dart';
import 'package:ghar360/core/routes/route_policy.dart';
import 'package:ghar360/core/services/deep_link_service.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/image_cache_service.dart';
import 'package:ghar360/features/property_details/presentation/controllers/property_details_controller.dart';
import 'package:ghar360/features/property_details/presentation/views/property_details_view.dart';
import 'package:ghar360/features/tour/presentation/views/tour_view.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/auth_form_harness.dart';
import '../../helpers/auth_test_harness.dart' show profile;
import '../../helpers/fake_webview_platform.dart';
import '../../helpers/image_test_cache.dart';
import '../../helpers/location_test_harness.dart';

class _PublicDetail extends PropertyDetailsController {
  _PublicDetail(super.propertyId);
  @override
  PropertyDetailsState build() => const PropertyDetailsState(phase: PropertyDetailPhase.failed);
}

void main() {
  late AuthFormHarness auth;
  late ProviderContainer container;
  late GoRouter router;
  late LocationTestDatabase database;
  const tour = 'https://kuula.co/share/example?logo=0&autorotate=1';
  setUp(() {
    installFakeWebViewPlatform();
    auth = AuthFormHarness();
    database = LocationTestDatabase();
    database.preferences['has_seen_onboarding'] = true;
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        storageScopeProvider.overrideWith(() => LocationScopeNotifier(database)),
        authProvider.overrideWith(() => auth.session),
        authRepositoryProvider.overrideWithValue(auth.repository),
        profileRepositoryProvider.overrideWithValue(auth.profiles),
        imageCacheServiceProvider.overrideWithValue(ImageTestCache().service),
        for (final id in [42, 99])
          propertyDetailsProvider(id).overrideWith(() => _PublicDetail(id)),
      ],
    );
  });
  tearDown(() {
    container.dispose();
    auth.close();
    uninstallFakeWebViewPlatform();
  });
  Future<void> pump(WidgetTester tester, String location, {Object? extra}) async {
    router = container.read(appRouterProvider);
    router.go(location, extra: extra);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en', 'US'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );
    // WebView readiness has a timeout; route transitions do not require it.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  testWidgets('guest can open a validated tour from extra and cold reconstruction', (tester) async {
    await pump(tester, '/tour', extra: {'url': tour, 'title': 'Public tour'});
    expect(router.state.uri.path, '/tour');
    expect(router.state.uri.queryParameters, {'url': tour, 'title': 'Public tour'});
    expect(tester.widget<TourView>(find.byType(TourView)).url, tour);
    router.go(tourRouteLocation(tour)!);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.widget<TourView>(find.byType(TourView)).url, tour);
    await unmount(tester);
  });

  testWidgets('mandatory auth gates preserve the complete tour destination', (tester) async {
    auth.session.initial = AuthState(status: AuthStatus.requiresPasswordSetup, user: profile());
    await pump(tester, '/tour', extra: tour);
    expect(router.state.uri.path, '/set-password');
    final destination = router.state.uri.queryParameters['from'];
    expect(destination, tourRouteLocation(tour));
    auth.session.set(
      AuthState(status: AuthStatus.requiresProfileCompletion, user: profile('account-a', false)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(router.state.uri.path, '/profile-completion');
    expect(router.state.uri.queryParameters['from'], destination);
    auth.session.set(AuthState(status: AuthStatus.authenticated, user: profile()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(router.state.uri.toString(), destination);
    expect(tester.widget<TourView>(find.byType(TourView)).url, tour);
    await unmount(tester);
  });

  testWidgets('cold public property and warm notification remain public before auth', (
    tester,
  ) async {
    auth.session.initial = const AuthState(status: AuthStatus.initial);
    database.preferences['has_seen_onboarding'] = false;
    final cold = DeepLinkService.propertyPathForUri(Uri.parse('https://360ghar.com/p/42'))!;
    await pump(tester, cold);
    expect(router.state.uri.path, '/property/42');
    expect(tester.widget<PropertyDetailsView>(find.byType(PropertyDetailsView)).propertyId, 42);
    router.go(notificationDestination({'property_id': 99})!);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(router.state.uri.path, '/property/99');
    expect(tester.widget<PropertyDetailsView>(find.byType(PropertyDetailsView)).propertyId, 99);
    auth.session.set(const AuthState(status: AuthStatus.unauthenticated));
    await tester.pump();
    expect(router.state.uri.path, '/property/99');
    await unmount(tester);
  });

  testWidgets('mandatory password form resets on account identity change', (tester) async {
    auth.session.initial = AuthState(status: AuthStatus.requiresPasswordSetup, user: profile());
    await pump(tester, '/set-password');
    final input = find.byKey(const ValueKey('qa.auth.set_password.password_input'));
    await tester.enterText(input, 'AccountASecret1!');
    auth.session.set(
      AuthState(status: AuthStatus.requiresPasswordSetup, user: profile('account-b')),
    );
    (container.read(storageScopeProvider.notifier) as LocationScopeNotifier).change('b');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.widget<TextFormField>(input).controller!.text, isEmpty);
    expect(router.state.uri.path, '/set-password');
    await unmount(tester);
  });

  testWidgets('account-keyed edit and feedback forms discard prior account drafts', (tester) async {
    auth.session.initial = AuthState(status: AuthStatus.authenticated, user: profile());
    await pump(tester, '/edit-profile');
    final name = find.byKey(const ValueKey('qa.profile.edit.full_name_input'));
    expect(name, findsOneWidget);
    await tester.enterText(name, 'Account A draft');
    auth.session.set(AuthState(status: AuthStatus.authenticated, user: profile('account-b')));
    (container.read(storageScopeProvider.notifier) as LocationScopeNotifier).change('b');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.widget<TextFormField>(name).controller!.text, isNot('Account A draft'));
    router.go('/feedback');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final title = find.byKey(const ValueKey('qa.profile.feedback.title_input'));
    await tester.enterText(title, 'Account B draft');
    auth.session.set(AuthState(status: AuthStatus.authenticated, user: profile('account-c')));
    (container.read(storageScopeProvider.notifier) as LocationScopeNotifier).change('c');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.widget<TextFormField>(title).controller!.text, isEmpty);
    await unmount(tester);
  });

  testWidgets('sign-out on an account screen lands on guest Discover, not a wall', (tester) async {
    auth.session.initial = AuthState(status: AuthStatus.authenticated, user: profile());
    await pump(tester, '/edit-profile');
    expect(router.state.uri.path, '/edit-profile');
    auth.session.set(const AuthState(status: AuthStatus.unauthenticated));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(router.state.uri.path, '/discover');
    await unmount(tester);
  });
}
