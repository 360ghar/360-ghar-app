import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/data/models/auth_status.dart';
import 'package:ghar360/core/routes/app_pages.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/image_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/auth_test_harness.dart';
import '../../helpers/image_test_cache.dart';

void main() {
  testWidgets('real session: deleting the account on Privacy lands on guest Discover', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(800, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = AuthHarness();
    await tester.runAsync(() => h.open());
    await tester.runAsync(() => h.database.writePreferences({'has_seen_onboarding': true}));
    when(() => h.notifications.unregisterDeviceToken(any())).thenAnswer((_) async => true);
    final container = ProviderContainer(
      parent: h.container,
      overrides: [imageCacheServiceProvider.overrideWithValue(ImageTestCache().service)],
    );
    addTearDown(container.dispose);
    await tester.runAsync(h.authenticate);
    expect(container.read(authProvider).status, AuthStatus.authenticated);
    final router = container.read(appRouterProvider)..go('/privacy');
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
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/privacy');
    final open = find.byKey(const ValueKey('qa.profile.privacy.delete_account'));
    await tester.scrollUntilVisible(open, 250);
    await tester.ensureVisible(open);
    await tester.pumpAndSettle();
    await tester.tap(open);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('qa.profile.privacy.delete_confirm_input')),
      'DELETE',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('qa.profile.privacy.delete_confirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    verify(() => h.repository.deleteAccount()).called(1);
    expect(container.read(authProvider).status, AuthStatus.unauthenticated);
    expect(router.state.uri.path, '/discover');
    await tester.runAsync(h.close);
  });
}
