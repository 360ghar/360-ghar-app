import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:ghar360/core/routes/app_pages.dart';
import 'package:ghar360/core/routes/app_routes.dart';

void main() {
  test('AppPages registers every route declared in AppRoutes', () {
    final registered = <String>{};

    void collectRouteNames(GetPage<dynamic> route) {
      registered.add(route.name);
      for (final child in route.children) {
        collectRouteNames(child);
      }
    }

    for (final route in AppPages.routes) {
      collectRouteNames(route);
    }

    const expected = <String>{
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
    };

    expect(registered, equals(expected));
  });
}
