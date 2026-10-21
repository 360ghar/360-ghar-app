import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/data/models/auth_status.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/core/routes/route_policy.dart';

void main() {
  String? redirect(AuthStatus status, String path) =>
      authRedirect(status: status, onboardingComplete: true, location: Uri.parse(path));
  test('all unauthenticated entry routes remain accessible', () {
    for (final path in authEntryPaths) {
      expect(redirect(AuthStatus.unauthenticated, path), isNull);
    }
  });
  test(
    'authenticated user leaves login for Discover',
    () => expect(redirect(AuthStatus.authenticated, AppRoutes.login), AppRoutes.discover),
  );
  test(
    'authenticated user leaves phone entry for Discover',
    () => expect(redirect(AuthStatus.authenticated, AppRoutes.phoneEntry), AppRoutes.discover),
  );
  test('completion returns to validated intended destination', () {
    for (final path in {...authEntryPaths, ...authGatePaths}) {
      expect(
        redirect(AuthStatus.authenticated, routeWithReturn(path, '/property/123')),
        '/property/123',
      );
    }
  });
  test(
    'unsafe from value falls back to Discover',
    () => expect(
      redirect(AuthStatus.authenticated, '${AppRoutes.login}?from=https%3A%2F%2Fevil.test'),
      AppRoutes.discover,
    ),
  );
  test(
    'legacy dashboard resolves to Discover',
    () => expect(redirect(AuthStatus.authenticated, AppRoutes.dashboard), AppRoutes.discover),
  );
}
