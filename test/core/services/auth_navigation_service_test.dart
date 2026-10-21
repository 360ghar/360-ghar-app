// The old navigation timer service is replaced by a deterministic redirect.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/data/models/auth_status.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/core/routes/route_policy.dart';
import 'package:go_router/go_router.dart';

void main() {
  String? redirect(AuthStatus status, String location, {bool seen = true}) =>
      authRedirect(status: status, onboardingComplete: seen, location: Uri.parse(location));

  test('initial session and load error stay on the recovery route', () {
    for (final status in [AuthStatus.initial, AuthStatus.error]) {
      expect(redirect(status, '/'), isNull);
      expect(redirect(status, '/visits'), '/?from=%2Fvisits');
    }
  });
  test('new user sees onboarding and the intended destination is retained', () {
    expect(redirect(AuthStatus.unauthenticated, '/visits', seen: false), '/splash?from=%2Fvisits');
    expect(redirect(AuthStatus.unauthenticated, '/splash?from=%2Fvisits', seen: false), isNull);
  });
  test('completed onboarding leads to phone entry and keeps the destination', () {
    expect(
      redirect(AuthStatus.unauthenticated, '/splash?from=%2Fvisits'),
      '/phone-entry?from=%2Fvisits',
    );
    expect(redirect(AuthStatus.unauthenticated, '/visits'), '/phone-entry?from=%2Fvisits');
  });
  for (final path in authEntryPaths) {
    test('unauthenticated $path remains stable', () {
      expect(redirect(AuthStatus.unauthenticated, path), isNull);
    });
  }
  test('mandatory password step precedes profile and original destination', () {
    expect(
      redirect(AuthStatus.requiresPasswordSetup, '/login?from=%2Fvisits'),
      '/set-password?from=%2Fvisits',
    );
    expect(redirect(AuthStatus.requiresPasswordSetup, '/set-password?from=%2Fvisits'), isNull);
    expect(
      redirect(AuthStatus.requiresProfileCompletion, '/set-password?from=%2Fvisits'),
      '/profile-completion?from=%2Fvisits',
    );
    expect(
      redirect(AuthStatus.requiresProfileCompletion, '/profile-completion?from=%2Fvisits'),
      isNull,
    );
    expect(redirect(AuthStatus.authenticated, '/profile-completion?from=%2Fvisits'), '/visits');
  });
  test('sign-in without a destination opens Discover', () {
    for (final path in ['/', '/phone-entry', '/signup', '/splash', '/dashboard']) {
      expect(redirect(AuthStatus.authenticated, path), '/discover');
    }
  });
  test('existing authenticated route does not navigate on refresh', () {
    for (final path in ['/visits', '/profile', '/explore', '/likes']) {
      expect(redirect(AuthStatus.authenticated, path), isNull);
    }
  });
  test('public property links remain accessible before session resolution', () {
    for (final status in [AuthStatus.unauthenticated, AuthStatus.initial, AuthStatus.error]) {
      expect(redirect(status, '/p/42', seen: false), isNull);
      expect(redirect(status, '/property/42', seen: false), isNull);
    }
  });
  test('detail identity survives auth through a safe query parameter', () {
    final gate = redirect(AuthStatus.unauthenticated, '/property-details?id=42');
    expect(gate, '/phone-entry?from=%2Fproperty-details%3Fid%3D42');
    expect(redirect(AuthStatus.authenticated, gate!), '/property-details?id=42');
  });
  for (final unsafe in [
    null,
    '',
    '//evil.example',
    'https://evil.example',
    '/login',
    '/phone-entry',
    '/splash',
    '/',
    '/unknown',
    '/property-details',
    '/property/0',
    '/visits#token',
    '/\\evil',
  ]) {
    test('rejects unsafe or recursive return destination $unsafe', () {
      expect(safeReturnLocation(unsafe), isNull);
    });
  }
  test('strips arbitrary parameters, identifiers, and recursive returns', () {
    expect(safeReturnLocation('/visits?from=%2Fprofile&token=secret'), '/visits');
    expect(safeReturnLocation('/property-details?id=42&email=private'), '/property-details?id=42');
  });
  test('invalid return destination falls back to Discover', () {
    expect(
      redirect(AuthStatus.authenticated, '/login?from=https%3A%2F%2Fevil.example'),
      '/discover',
    );
  });
  test('notifications open a known internal route or the property of property_id', () {
    expect(notificationDestination({'route': '/visits'}), '/visits');
    expect(notificationDestination({'property_id': 42}), '/property/42');
    expect(notificationDestination({'property_id': '43'}), '/property/43');
    expect(
      notificationDestination({'route': '/property-details', 'property_id': '44'}),
      '/property/44',
    );
    expect(notificationDestination({'route': 'https://evil.example'}), isNull);
    expect(
      notificationDestination({
        'property_id': {'id': 42},
      }),
      isNull,
    );
  });
  test('notifications read route and property_id only: the old keys are gone', () {
    expect(notificationDestination({'propertyId': '43'}), isNull);
    expect(notificationDestination({'deep_link': '/visits'}), isNull);
    expect(notificationDestination({'deep_link': 'ghar360://property/9'}), isNull);
  });
  test('a push without a route falls back by its top-level type_key', () {
    expect(notificationDestination({'type_key': 'visit_reminder'}), '/visits');
    expect(notificationDestination({'type_key': 'property_recommendation'}), '/discover');
    expect(notificationDestination({'type_key': 'flatmate_new_message'}), isNull);
    expect(notificationDestination({'type_key': 'unknown_type'}), isNull);
    // A route the app knows wins over the type.
    expect(
      notificationDestination({'route': '/profile', 'type_key': 'visit_reminder'}),
      '/profile',
    );
  });
  test('PushPayload reads route, type_key and _meta (JSON text)', () {
    final payload = PushPayload.fromData({
      'route': '/property/12',
      'type_key': 'property_recommendation',
      'property_id': '12',
      '_meta': '{"type_key":"property_recommendation","channel":"push","priority":"high"}',
    });

    expect(payload.route, '/property/12');
    expect(payload.typeKey, 'property_recommendation');
    expect(payload.propertyId, 12);
    expect(payload.meta['channel'], 'push');
    expect(() => payload.meta['x'] = 1, throwsUnsupportedError);
  });
  test('a broken _meta never blocks the route', () {
    expect(PushPayload.fromData({'route': '/visits', '_meta': '{not json'}).meta, isEmpty);
    expect(PushPayload.fromData({'_meta': '[1,2]'}).meta, isEmpty);
    expect(PushPayload.fromData({'_meta': 5}).meta, isEmpty);
    expect(notificationDestination({'route': '/visits', '_meta': '{not json'}), '/visits');
  });
  test('blank or non-string push values read as absent', () {
    final payload = PushPayload.fromData({'route': '  ', 'type_key': 7, 'property_id': 'x'});

    expect(payload.route, isNull);
    expect(payload.typeKey, isNull);
    expect(payload.propertyId, isNull);
  });
  test('validated tours are public but mandatory account gates retain their payload', () {
    final destination = tourRouteLocation(
      'https://kuula.co/share/42?logo=0',
      title: 'Listing tour',
    )!;
    for (final status in [AuthStatus.initial, AuthStatus.error, AuthStatus.unauthenticated]) {
      expect(redirect(status, destination, seen: false), isNull);
    }
    final password = redirect(AuthStatus.requiresPasswordSetup, destination)!;
    expect(Uri.parse(password).queryParameters['from'], destination);
    final profile = redirect(AuthStatus.requiresProfileCompletion, password)!;
    expect(redirect(AuthStatus.authenticated, profile), destination);
    expect(notificationDestination({'route': destination}), destination);
  });
  test('tour recovery rejects unsafe input and strips unrelated route parameters', () {
    for (final raw in [
      'javascript:alert(1)',
      'file:///private/file',
      'https://user:pass@example.com/tour',
      '//example.com/tour',
    ]) {
      expect(tourRouteLocation(raw), isNull);
      expect(
        safeReturnLocation(Uri(path: '/tour', queryParameters: {'url': raw}).toString()),
        isNull,
      );
    }
    expect(safeReturnLocation('/tour'), isNull);
    final route = Uri(
      path: '/tour',
      queryParameters: {'url': 'https://kuula.co/share/42', 'token': 'secret', 'from': '/profile'},
    ).toString();
    expect(safeReturnLocation(route), tourRouteLocation('https://kuula.co/share/42'));
  });
  testWidgets('go_router applies state transitions without timers or duplicate pages', (
    tester,
  ) async {
    final status = ValueNotifier(AuthStatus.initial);
    final router = GoRouter(
      initialLocation: '/visits',
      refreshListenable: status,
      redirect: (_, state) => redirect(status.value, state.uri.toString()),
      routes: [
        for (final path in [
          '/',
          '/phone-entry',
          '/set-password',
          '/profile-completion',
          '/visits',
          '/discover',
        ])
          GoRoute(
            path: path,
            builder: (_, _) => Scaffold(body: Text(path)),
          ),
      ],
    );
    addTearDown(() {
      router.dispose();
      status.dispose();
    });
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/');
    status.value = AuthStatus.unauthenticated;
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.phoneEntry);
    status.value = AuthStatus.requiresPasswordSetup;
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.setPassword);
    status.value = AuthStatus.requiresProfileCompletion;
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.profileCompletion);
    status.value = AuthStatus.authenticated;
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.visits);
    expect(router.canPop(), false);
    status.value = AuthStatus.unauthenticated;
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.phoneEntry);
    expect(router.canPop(), false);
  });
}
