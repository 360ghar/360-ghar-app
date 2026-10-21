@TestOn('mac-os')
library;

// Visits and Profile tab goldens: loading, empty, error and content states in
// {light, dark} × {(390, en, 1x), (320, hi, 2x)}, plus content at 834 px.

import 'package:flutter/material.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/controllers/localization_controller.dart';
import 'package:ghar360/core/data/models/auth_status.dart';
import 'package:ghar360/core/data/models/visit_model.dart';
import 'package:ghar360/core/design/app_design_theme.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/providers/auth_providers.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/providers/pending_actions_provider.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/utils/app_toast.dart';
import 'package:ghar360/features/profile/presentation/controllers/feedback_controller.dart';
import 'package:ghar360/features/profile/presentation/controllers/preferences_controller.dart';
import 'package:ghar360/features/profile/presentation/views/about_view.dart';
import 'package:ghar360/features/profile/presentation/views/policy_page_view.dart';
import 'package:ghar360/features/profile/presentation/views/profile_view.dart';
import 'package:ghar360/features/visits/presentation/controllers/visits_controller.dart';
import 'package:ghar360/features/visits/presentation/views/visits_view.dart';
import '../helpers/c_notification_settings.dart';
import '../helpers/load_app_fonts.dart';
import '../helpers/profile_test_harness.dart';
import '../helpers/settings_test_database.dart';
import '../helpers/visits_test_support.dart';

typedef _Variant = ({String name, Size size, double scale, Locale locale});

const _variants = <_Variant>[
  (name: '390_en_1x', size: Size(390, 844), scale: 1, locale: Locale('en', 'US')),
  (name: '320_hi_2x', size: Size(320, 844), scale: 2, locale: Locale('hi', 'IN')),
];
const _tablet = (name: '834_en_1x', size: Size(834, 1112), scale: 1.0, locale: Locale('en', 'US'));

VisitsState _visits(String state) => switch (state) {
  'loading' => VisitsState(phase: VisitLoadPhase.loading),
  'error' => VisitsState(phase: VisitLoadPhase.failed, failure: ServerException('private')),
  'empty' => VisitsState(
    phase: VisitLoadPhase.content,
    agent: const VisitAgentState(phase: VisitLoadPhase.content),
  ),
  _ => VisitsState(
    phase: VisitLoadPhase.content,
    visits: [
      visitFixture(date: DateTime(2030, 10, 4, 11), property: propertyFixture()),
      visitFixture(
        id: 2,
        propertyId: 200,
        date: DateTime(2030, 10, 9, 16, 30),
        status: VisitStatus.confirmed,
        property: propertyFixture(id: 200),
      ),
    ],
    agent: VisitAgentState(
      value: agentFixture(phone: '+919811111111'),
      phase: VisitLoadPhase.content,
    ),
  ),
};

Widget _app({required Widget home, required bool dark, required _Variant variant}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: dark ? AppDesignTheme.dark() : AppDesignTheme.light(),
  locale: variant.locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(variant.scale)),
    child: AppToastHost(child: child!),
  ),
  home: RepaintBoundary(key: const ValueKey('visual.screen'), child: home),
);

Future<void> _size(WidgetTester tester, _Variant variant) async {
  tester.view.physicalSize = variant.size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _settle(WidgetTester tester) async {
  // Past the 150 ms skeleton gate; shimmer is a repeating animation, so no settle.
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 200));
  expect(tester.takeException(), isNull);
  expect(find.textContaining('private'), findsNothing);
}

void main() {
  setUpAll(loadAppFonts);

  for (final state in ['content', 'loading', 'empty', 'error']) {
    for (final dark in [false, true]) {
      for (final variant in [..._variants, if (state == 'content') _tablet]) {
        final name = 'visits_${state}_${dark ? 'dark' : 'light'}_${variant.name}';
        testWidgets(name, (tester) async {
          await _size(tester, variant);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                visitsProvider.overrideWith(() => SeededVisitsController(_visits(state))),
                pendingActionsProvider.overrideWith(SeededPendingActions.new),
                unownedActionsProvider.overrideWith((ref) async => []),
              ],
              child: _app(home: const VisitsView(), dark: dark, variant: variant),
            ),
          );
          await _settle(tester);
          await expectLater(
            find.byKey(const ValueKey('visual.screen')),
            matchesGoldenFile('goldens/$name.png'),
          );
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  }

  for (final state in ['content', 'loading', 'error']) {
    for (final dark in [false, true]) {
      for (final variant in [..._variants, if (state == 'content') _tablet]) {
        final name = 'profile_${state}_${dark ? 'dark' : 'light'}_${variant.name}';
        testWidgets(name, (tester) async {
          await _size(tester, variant);
          final h = ProfileHarness();
          final scopeDatabase = (await tester.runAsync(visitTestDatabase))!;
          h.session.initial = switch (state) {
            'loading' => const AuthState(status: AuthStatus.authenticated, resolving: true),
            'error' => const AuthState(status: AuthStatus.authenticated),
            _ => h.session.initial,
          };
          final container = ProviderContainer(
            overrides: [
              authProvider.overrideWith(() => h.session),
              authRepositoryProvider.overrideWithValue(h.repository),
              supportRepositoryProvider.overrideWithValue(h.support),
              staticPageRepositoryProvider.overrideWithValue(h.pages),
              feedbackPackageInfoProvider.overrideWithValue(() async => h.info),
              packageVersionProvider.overrideWith((ref) async => h.info),
              appDatabaseProvider.overrideWithValue(SettingsTestDatabase()),
              deviceLocaleProvider.overrideWithValue(variant.locale),
              storageScopeProvider.overrideWith(() => TestVisitScope(scopeDatabase)),
              notificationSettingsRepositoryProvider.overrideWithValue(FakeNotificationSettings()),
            ],
          );
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: _app(home: const ProfileView(), dark: dark, variant: variant),
            ),
          );
          await _settle(tester);
          await expectLater(
            find.byKey(const ValueKey('visual.screen')),
            matchesGoldenFile('goldens/$name.png'),
          );
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(milliseconds: 10));
          container.dispose();
          h.close();
          await tester.runAsync(scopeDatabase.close);
        });
      }
    }
  }
}
