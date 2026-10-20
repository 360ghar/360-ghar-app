// Auth route checks moved from imperative middleware into the shared redirect policy.

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/data/models/auth_status.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/core/routes/route_policy.dart';

void main() {
  String? redirect(AuthStatus status, String path, {bool onboarding = true}) =>
      authRedirect(status: status, onboardingComplete: onboarding, location: Uri.parse(path));
  test(
    'authenticated user can access protected content',
    () => expect(redirect(AuthStatus.authenticated, AppRoutes.profile), isNull),
  );
  test('signed-out user goes to phone entry with intended destination', () {
    final route = Uri.parse(redirect(AuthStatus.unauthenticated, AppRoutes.visits)!);
    expect(route.path, AppRoutes.phoneEntry);
    expect(route.queryParameters['from'], AppRoutes.visits);
  });
  test('password setup gate keeps intended destination', () {
    final route = Uri.parse(redirect(AuthStatus.requiresPasswordSetup, AppRoutes.visits)!);
    expect(route.path, AppRoutes.setPassword);
    expect(route.queryParameters['from'], AppRoutes.visits);
  });
  test(
    'password setup route does not redirect to itself',
    () => expect(redirect(AuthStatus.requiresPasswordSetup, AppRoutes.setPassword), isNull),
  );
  test('profile completion gate keeps intended destination', () {
    final route = Uri.parse(redirect(AuthStatus.requiresProfileCompletion, AppRoutes.visits)!);
    expect(route.path, AppRoutes.profileCompletion);
    expect(route.queryParameters['from'], AppRoutes.visits);
  });
  test(
    'profile completion route does not redirect to itself',
    () =>
        expect(redirect(AuthStatus.requiresProfileCompletion, AppRoutes.profileCompletion), isNull),
  );
  test(
    'signed-out entry does not create a recursive destination',
    () => expect(redirect(AuthStatus.unauthenticated, AppRoutes.phoneEntry), isNull),
  );
  test('initial and failed session resolve at root preserving destination', () {
    for (final status in [AuthStatus.initial, AuthStatus.error]) {
      final route = Uri.parse(redirect(status, AppRoutes.visits)!);
      expect(route.path, '/');
      expect(route.queryParameters['from'], AppRoutes.visits);
    }
  });
  test('first launch keeps onboarding before sign-in', () {
    final route = Uri.parse(
      redirect(AuthStatus.unauthenticated, AppRoutes.visits, onboarding: false)!,
    );
    expect(route.path, AppRoutes.splash);
    expect(route.queryParameters['from'], AppRoutes.visits);
  });
  test('shared property links remain public before authentication', () {
    for (final status in [AuthStatus.initial, AuthStatus.error, AuthStatus.unauthenticated]) {
      for (final path in ['/p/123', '/property/123']) {
        expect(redirect(status, path), isNull);
      }
    }
  });
  test(
    'public links still respect mandatory password setup for a signed-in account',
    () => expect(
      Uri.parse(redirect(AuthStatus.requiresPasswordSetup, '/p/123')!).path,
      AppRoutes.setPassword,
    ),
  );
  test('invalid and credential-bearing return destinations are sanitized', () {
    for (final value in [
      'https://example.com',
      '//example.com',
      '/login',
      '/unknown',
      '/visits#access_token=secret',
      '/\\evil',
    ]) {
      expect(safeReturnLocation(value), isNull);
    }
    expect(safeReturnLocation('/visits?access_token=secret'), '/visits');
  });
  test('property query return destination retains only validated id', () {
    expect(
      safeReturnLocation('/property-details?id=12&password=secret'),
      '/property-details?id=12',
    );
    expect(safeReturnLocation('/property-details?id=-1'), isNull);
  });
}
