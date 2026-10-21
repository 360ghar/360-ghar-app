// test/features/profile/presentation/views/preferences_view_test.dart
//
// Widget tests for [PreferencesView]. Covers rendering of preference sections
// (property, display, language), switch toggles, theme and language dialogs,
// and the save button.

import 'package:flutter/material.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/controllers/localization_controller.dart';
import 'package:ghar360/core/controllers/theme_controller.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/utils/app_toast.dart';
import 'package:ghar360/features/profile/data/notification_settings_repository.dart';
import 'package:ghar360/features/profile/presentation/controllers/preferences_controller.dart';
import 'package:ghar360/features/profile/presentation/views/preferences_view.dart';
import '../../../../helpers/c_notification_settings.dart';
import '../../../../helpers/settings_test_database.dart';
import '../../../../helpers/visits_test_support.dart';

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late SettingsTestDatabase database;
  late AppDatabase scopeDatabase;
  late FakeNotificationSettings settings;
  late ProviderContainer container;

  setUp(() async {
    database = SettingsTestDatabase();
    scopeDatabase = await visitTestDatabase();
    settings = FakeNotificationSettings();
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        deviceLocaleProvider.overrideWithValue(const Locale('en', 'US')),
        storageScopeProvider.overrideWith(() => TestVisitScope(scopeDatabase)),
        notificationSettingsRepositoryProvider.overrideWithValue(settings),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await scopeDatabase.close();
  });

  Future<void> pumpView(WidgetTester tester, {double textScale = 1}) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, child) => MaterialApp(
            theme: ThemeData.light(),
            darkTheme: ThemeData.dark(),
            themeMode: ref.watch(themeProvider).flutterMode,
            locale: ref.watch(localizationProvider).locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
              child: AppToastHost(child: child!),
            ),
            home: const PreferencesView(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('PreferencesView rendering', () {
    for (final mode in ['light', 'dark']) {
      testWidgets('$mode theme fits a narrow phone with large text', (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        database.values['themeMode'] = mode;
        await pumpView(tester, textScale: 2);
        expect(find.byType(SwitchListTile), findsNWidgets(3));
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(
          find.byKey(const ValueKey('qa.profile.preferences.language_selector')),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final screen = tester.widget<Semantics>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.identifier == 'qa.profile.preferences.screen',
          ),
        );
        expect(screen.properties.label, isNull);
      });
    }

    testWidgets('renders the preferences screen with app bar title', (tester) async {
      await pumpView(tester);

      expect(find.byType(PreferencesView), findsOneWidget);
      expect(find.text('My Preferences'), findsOneWidget);
    });

    testWidgets('renders the three backend notification switches', (tester) async {
      await pumpView(tester);

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Push Notifications'), findsOneWidget);
      expect(find.text('Email Notifications'), findsOneWidget);
      expect(find.text('Recommendations and offers'), findsOneWidget);
      expect(find.text('Similar Properties'), findsNothing);
    });

    testWidgets('renders display preferences section with theme selector', (tester) async {
      await pumpView(tester);

      expect(find.text('Display Preferences'), findsOneWidget);
      expect(find.text('App Theme'), findsOneWidget);
      // Current theme is system, so 'System Mode' is displayed.
      expect(find.text('System Mode'), findsWidgets);
    });

    testWidgets('renders language preferences section with language selector', (tester) async {
      await pumpView(tester);

      expect(find.text('Language Preferences'), findsOneWidget);
      expect(find.text('Select Language'), findsOneWidget);
      // Current language is English (from stub).
      expect(find.text('English'), findsOneWidget);
    });

    testWidgets('every control saves itself, so there is no save button', (tester) async {
      await pumpView(tester);

      expect(find.byKey(const ValueKey('qa.profile.preferences.save')), findsNothing);
      expect(find.text('Save Preferences'), findsNothing);
    });
  });

  group('PreferencesView switch toggles', () {
    for (final (index, key) in NotificationSettingsRepository.toggles.indexed) {
      testWidgets('toggling $key writes only that key', (tester) async {
        await pumpView(tester);

        final switches = find.byType(Switch);
        expect(switches, findsNWidgets(3));
        final before = container.read(notificationSettingsProvider).valueOf(key);

        await tester.tap(switches.at(index));
        await tester.pumpAndSettle();

        expect(container.read(notificationSettingsProvider).valueOf(key), !before);
        expect(settings.writes.single, (key, !before));
      });
    }

    testWidgets('a failed write turns the switch back and says so inline', (tester) async {
      settings.writeError = NetworkException('offline');
      await pumpView(tester);

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(find.byType(Switch).first).value, isTrue);
      expect(find.text('The change was not saved. Try again.'), findsOneWidget);
      expect(find.textContaining('offline'), findsNothing);
    });

    testWidgets('a failed load shows an inline error with a working retry', (tester) async {
      settings.readError = NetworkException('offline');
      await pumpView(tester);

      expect(find.byType(Switch), findsNothing);
      expect(find.text('Notification settings could not be loaded.'), findsOneWidget);

      settings.readError = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.byType(Switch), findsNWidgets(3));
    });
  });

  group('PreferencesView theme selector', () {
    testWidgets('tapping theme selector opens theme dialog', (tester) async {
      await pumpView(tester);

      await tester.ensureVisible(
        find.byKey(const ValueKey('qa.profile.preferences.theme_selector')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('qa.profile.preferences.theme_selector')));
      await tester.pumpAndSettle();

      expect(find.text('App Theme'), findsWidgets);
      expect(find.text('Light Mode'), findsOneWidget);
      expect(find.text('Dark Mode'), findsOneWidget);
      // 'System Mode' appears in both the selector and the dialog.
      expect(find.text('System Mode'), findsNWidgets(2));
    });

    testWidgets('selecting dark mode calls updateTheme and closes dialog', (tester) async {
      await pumpView(tester);

      await tester.ensureVisible(
        find.byKey(const ValueKey('qa.profile.preferences.theme_selector')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('qa.profile.preferences.theme_selector')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dark Mode'));
      await tester.pumpAndSettle();

      expect(container.read(themeProvider).mode, AppThemeMode.dark);
      // Dialog should be dismissed — 'Light Mode' only appeared in the dialog.
      expect(find.text('Light Mode'), findsNothing);
    });

    testWidgets('selecting light mode calls updateTheme and closes dialog', (tester) async {
      await pumpView(tester);

      await tester.ensureVisible(
        find.byKey(const ValueKey('qa.profile.preferences.theme_selector')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('qa.profile.preferences.theme_selector')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Light Mode'));
      await tester.pumpAndSettle();

      expect(container.read(themeProvider).mode, AppThemeMode.light);
    });

    testWidgets('selecting system mode calls updateTheme and closes dialog', (tester) async {
      // Start from a non-system mode.
      database.values['themeMode'] = 'dark';
      await pumpView(tester);

      await tester.ensureVisible(
        find.byKey(const ValueKey('qa.profile.preferences.theme_selector')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('qa.profile.preferences.theme_selector')));
      await tester.pumpAndSettle();

      // 'System Mode' appears twice (selector shows 'Dark Mode' now, dialog has all 3).
      // Actually with dark mode, selector shows 'Dark Mode', so 'System Mode' is only in dialog.
      await tester.tap(find.text('System Mode'));
      await tester.pumpAndSettle();

      expect(container.read(themeProvider).mode, AppThemeMode.system);
    });

    testWidgets('tapping cancel in theme dialog closes it without changing theme', (tester) async {
      await pumpView(tester);

      await tester.ensureVisible(
        find.byKey(const ValueKey('qa.profile.preferences.theme_selector')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('qa.profile.preferences.theme_selector')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(container.read(themeProvider).mode, AppThemeMode.system);
      // 'Light Mode' only appeared in the dialog.
      expect(find.text('Light Mode'), findsNothing);
    });
  });

  group('PreferencesView language selector', () {
    testWidgets('failed write retains the locale and exposes a working retry', (tester) async {
      database.writeFailure = StorageFailure('write language');
      await pumpView(tester);
      final selector = find.byKey(const ValueKey('qa.profile.preferences.language_selector'));
      await tester.ensureVisible(selector);
      await tester.pump();
      await tester.tap(selector);
      await tester.pumpAndSettle();
      await tester.tap(find.text('हिंदी'));
      await tester.pumpAndSettle();
      expect(find.text('English'), findsOneWidget);
      expect(find.text('Failed to save preferences'), findsOneWidget);
      database.writeFailure = null;
      await tester.ensureVisible(find.text('Retry'));
      await tester.pump();
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('हिंदी'), findsOneWidget);
      expect(database.values['language_code'], 'hi');
      expect(find.text('Failed to save preferences'), findsNothing);
    });

    testWidgets('tapping language selector opens language dialog', (tester) async {
      await pumpView(tester);

      await tester.ensureVisible(
        find.byKey(const ValueKey('qa.profile.preferences.language_selector')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('qa.profile.preferences.language_selector')));
      await tester.pumpAndSettle();

      expect(find.text('Select Language'), findsWidgets);
      // 'English' appears in both the selector and the dialog.
      expect(find.text('English'), findsNWidgets(2));
      expect(find.text('हिंदी'), findsOneWidget);
    });

    testWidgets('selecting Hindi calls changeLanguage and closes dialog', (tester) async {
      await pumpView(tester);

      await tester.ensureVisible(
        find.byKey(const ValueKey('qa.profile.preferences.language_selector')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('qa.profile.preferences.language_selector')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('हिंदी'));
      await tester.pumpAndSettle();

      expect(database.values['language_code'], 'hi');
      expect(database.values['country_code'], 'IN');
    });

    testWidgets('selecting English calls changeLanguage and closes dialog', (tester) async {
      await pumpView(tester);

      await tester.ensureVisible(
        find.byKey(const ValueKey('qa.profile.preferences.language_selector')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('qa.profile.preferences.language_selector')));
      await tester.pumpAndSettle();

      // 'English' appears twice (selector + dialog); tap the last one (dialog).
      await tester.tap(find.text('English').last);
      await tester.pumpAndSettle();

      expect(database.values['language_code'], 'en');
      expect(database.values['country_code'], 'US');
    });

    testWidgets('tapping cancel in language dialog closes it without changing language', (
      tester,
    ) async {
      await pumpView(tester);

      await tester.ensureVisible(
        find.byKey(const ValueKey('qa.profile.preferences.language_selector')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('qa.profile.preferences.language_selector')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(database.values['language_code'], isNull);
      // 'हिंदी' only appeared in the dialog.
      expect(find.text('हिंदी'), findsNothing);
    });
  });
}
