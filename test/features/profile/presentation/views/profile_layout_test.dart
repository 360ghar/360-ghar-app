// Every profile screen at 320 px, Hindi, 2x text, both themes: no overflow,
// scrolled from top to bottom, with its dialogs open.

import 'package:flutter/material.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/controllers/localization_controller.dart';
import 'package:ghar360/core/data/models/static_page_model.dart';
import 'package:ghar360/core/design/app_design_theme.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/providers/auth_providers.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/utils/app_toast.dart';
import 'package:ghar360/features/profile/presentation/controllers/feedback_controller.dart';
import 'package:ghar360/features/profile/presentation/controllers/preferences_controller.dart';
import 'package:ghar360/features/profile/presentation/views/about_view.dart';
import 'package:ghar360/features/profile/presentation/views/edit_profile_view.dart';
import 'package:ghar360/features/profile/presentation/views/feedback_view.dart';
import 'package:ghar360/features/profile/presentation/views/help_view.dart';
import 'package:ghar360/features/profile/presentation/views/policy_page_view.dart';
import 'package:ghar360/features/profile/presentation/views/preferences_view.dart';
import 'package:ghar360/features/profile/presentation/views/privacy_view.dart';
import 'package:ghar360/features/profile/presentation/views/profile_view.dart';
import '../../../../helpers/c_notification_settings.dart';
import '../../../../helpers/profile_test_harness.dart';
import '../../../../helpers/settings_test_database.dart';
import '../../../../helpers/visits_test_support.dart';

void main() {
  late ProfileHarness h;
  late AppDatabase scopeDatabase;
  late ProviderContainer container;
  setUp(() async {
    h = ProfileHarness();
    scopeDatabase = await visitTestDatabase();
    container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(() => h.session),
        authRepositoryProvider.overrideWithValue(h.repository),
        supportRepositoryProvider.overrideWithValue(h.support),
        staticPageRepositoryProvider.overrideWithValue(h.pages),
        feedbackPackageInfoProvider.overrideWithValue(() async => h.info),
        packageVersionProvider.overrideWith((ref) async => h.info),
        appDatabaseProvider.overrideWithValue(SettingsTestDatabase()),
        deviceLocaleProvider.overrideWithValue(const Locale('hi', 'IN')),
        storageScopeProvider.overrideWith(() => TestVisitScope(scopeDatabase)),
        notificationSettingsRepositoryProvider.overrideWithValue(FakeNotificationSettings()),
      ],
    );
    when(() => h.pages.fetchPublicPage(any())).thenAnswer(
      (_) async => StaticPageModel(
        title: 'नीति',
        content:
            '# गोपनीयता नीति\n\n${'यह एक लंबा अनुच्छेद है जो कई पंक्तियों में लिपटता है। ' * 12}',
      ),
    );
  });
  tearDown(() async {
    container.dispose();
    h.close();
    await scopeDatabase.close();
  });

  Future<void> pumpScreen(WidgetTester tester, Widget screen, {required bool dark}) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: dark ? AppDesignTheme.dark() : AppDesignTheme.light(),
          locale: const Locale('hi', 'IN'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
            child: AppToastHost(child: child!),
          ),
          home: screen,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  }

  /// Drags the screen's main scroll view to the end, checking each frame.
  Future<void> scrollThrough(WidgetTester tester) async {
    final scrollable = find.byType(Scrollable).first;
    for (var i = 0; i < 12; i++) {
      await tester.drag(scrollable, const Offset(0, -500), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    }
  }

  /// A layout test that unmounts its tree at the end, so autoDispose timers
  /// run inside the test.
  void layoutTest(String name, Future<void> Function(WidgetTester tester) body) =>
      testWidgets(name, (tester) async {
        await body(tester);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 10));
      });

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    layoutTest('profile menu and sign-out dialog fit ($mode)', (tester) async {
      await pumpScreen(tester, const ProfileView(), dark: dark);
      await scrollThrough(tester);
      await tester.tap(find.byKey(const ValueKey('qa.profile.logout')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    layoutTest('profile load error fits ($mode)', (tester) async {
      h.session.initial = h.session.initial.copyWith(user: null);
      await pumpScreen(tester, const ProfileView(), dark: dark);
      await scrollThrough(tester);
    });

    layoutTest('edit profile with server field errors fits ($mode)', (tester) async {
      h.session.save = () async => throw ValidationException(
        'invalid',
        code: 'VALIDATION_ERROR',
        fieldErrors: {
          'full_name': ['string_too_long'],
          'date_of_birth': ['date_parsing'],
        },
      );
      await pumpScreen(tester, const EditProfileView(), dark: dark);
      await tester.ensureVisible(find.byKey(const ValueKey('qa.profile.edit.save')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('qa.profile.edit.save')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('qa.profile.form_error')), findsOneWidget);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
      await tester.pump();
      await scrollThrough(tester);
    });

    layoutTest('preferences and the theme dialog fit ($mode)', (tester) async {
      await pumpScreen(tester, const PreferencesView(), dark: dark);
      expect(find.byType(Switch), findsNWidgets(3));
      await scrollThrough(tester);
      final selector = find.byKey(const ValueKey('qa.profile.preferences.theme_selector'));
      await tester.ensureVisible(selector);
      await tester.pumpAndSettle();
      await tester.tap(selector);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    layoutTest('privacy and its dialogs fit ($mode)', (tester) async {
      await pumpScreen(tester, const PrivacyView(), dark: dark);
      await tester.tap(find.byKey(const ValueKey('qa.profile.privacy.change_password')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      Navigator.of(tester.element(find.byType(AlertDialog))).pop();
      await tester.pumpAndSettle();
      await scrollThrough(tester);
      await tester.tap(find.byKey(const ValueKey('qa.profile.privacy.delete_account')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    layoutTest('help fits ($mode)', (tester) async {
      await pumpScreen(tester, const HelpView(), dark: dark);
      await tester.tap(find.byType(ExpansionTile).first);
      await tester.pumpAndSettle();
      await scrollThrough(tester);
    });

    layoutTest('feedback form fits ($mode)', (tester) async {
      await pumpScreen(tester, const FeedbackView(), dark: dark);
      await scrollThrough(tester);
    });

    layoutTest('about fits ($mode)', (tester) async {
      await pumpScreen(tester, const AboutView(), dark: dark);
      await scrollThrough(tester);
    });

    layoutTest('policy page fits ($mode)', (tester) async {
      await pumpScreen(
        tester,
        const PolicyPageView(uniqueName: 'privacy-policy', titleText: 'गोपनीयता नीति'),
        dark: dark,
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('लंबा अनुच्छेद'), findsOneWidget);
      await scrollThrough(tester);
    });
  }
}
