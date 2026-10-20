import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/routes/app_pages.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import '../../helpers/profile_test_harness.dart';
import '../../helpers/visits_test_support.dart';

void main() {
  test('router registers every declared destination including public property aliases', () async {
    final database = await visitTestDatabase();
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        authProvider.overrideWith(ProfileTestSession.new),
        storageScopeProvider.overrideWith(() => TestVisitScope(database)),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });
    final router = container.read(appRouterProvider);
    final registered = <String>{};
    void collect(RouteBase route) {
      if (route is GoRoute) registered.add(route.path);
      for (final child in route.routes) {
        collect(child);
      }
    }

    for (final route in router.configuration.routes) {
      collect(route);
    }
    expect(registered, {
      '/',
      '/policy/:slug',
      AppRoutes.splash,
      AppRoutes.phoneEntry,
      AppRoutes.login,
      AppRoutes.signup,
      AppRoutes.forgotPassword,
      AppRoutes.setPassword,
      AppRoutes.profileCompletion,
      AppRoutes.dashboard,
      AppRoutes.discover,
      AppRoutes.propertyDetails,
      AppRoutes.propertyShortLink,
      AppRoutes.propertyDeepLink,
      AppRoutes.profile,
      AppRoutes.editProfile,
      AppRoutes.likes,
      AppRoutes.visits,
      AppRoutes.explore,
      AppRoutes.tour,
      AppRoutes.preferences,
      AppRoutes.privacy,
      AppRoutes.help,
      AppRoutes.feedback,
      AppRoutes.about,
      AppRoutes.tools,
      AppRoutes.areaConverter,
      AppRoutes.loanEligibility,
      AppRoutes.emiCalculator,
      AppRoutes.carpetArea,
      AppRoutes.documentChecklist,
      AppRoutes.capitalGains,
      AppRoutes.assistant,
    });
    expect(container.read(appRouterProvider), same(router));
  });
}
