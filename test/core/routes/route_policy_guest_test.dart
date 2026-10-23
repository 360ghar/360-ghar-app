import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/data/models/auth_status.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/core/routes/route_policy.dart';

void main() {
  String? guest(String path, {bool onboarded = true}) => authRedirect(
    status: AuthStatus.unauthenticated,
    onboardingComplete: onboarded,
    location: Uri.parse(path),
  );

  group('guest browsing', () {
    test('public screens are allowed', () {
      for (final path in [
        AppRoutes.discover,
        AppRoutes.explore,
        '${AppRoutes.propertyDetails}?id=7',
        '/property/7',
        '/p/7',
        '${AppRoutes.tour}?url=https%3A%2F%2Ftour.example.com%2Fa',
        AppRoutes.tools,
        AppRoutes.emiCalculator,
        AppRoutes.help,
        AppRoutes.about,
        '/policy/privacy-policy',
        ...authEntryPaths,
      ]) {
        expect(guest(path), isNull, reason: path);
      }
    });

    test('account screens go to sign-in and keep the destination', () {
      for (final path in protectedPaths) {
        expect(guest(path), routeWithReturn(AppRoutes.phoneEntry, path), reason: path);
      }
      expect(guest(AppRoutes.likes), '${AppRoutes.phoneEntry}?from=%2Flikes');
    });

    test('root and splash lead to Discover, or to the safe return', () {
      expect(guest('/'), AppRoutes.discover);
      expect(guest(AppRoutes.splash), AppRoutes.discover);
      expect(guest('/?from=%2Fproperty%2F9'), '/property/9');
      expect(guest('${AppRoutes.splash}?from=%2Fvisits'), AppRoutes.visits);
      expect(guest('/?from=https%3A%2F%2Fevil.test'), AppRoutes.discover);
    });

    test('before onboarding a guest goes to splash', () {
      expect(guest(AppRoutes.discover, onboarded: false), '${AppRoutes.splash}?from=%2Fdiscover');
      expect(guest(AppRoutes.likes, onboarded: false), '${AppRoutes.splash}?from=%2Flikes');
      expect(guest(AppRoutes.splash, onboarded: false), isNull);
      expect(guest('/property/7', onboarded: false), isNull);
    });

    test('a signed-in user at sign-in goes to the return location', () {
      String? signedIn(String path) => authRedirect(
        status: AuthStatus.authenticated,
        onboardingComplete: true,
        location: Uri.parse(path),
      );
      expect(signedIn('${AppRoutes.phoneEntry}?from=%2Flikes'), AppRoutes.likes);
      expect(signedIn('${AppRoutes.phoneEntry}?from=https%3A%2F%2Fevil.test'), AppRoutes.discover);
    });
  });
}
