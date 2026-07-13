// test/features/profile/presentation/views/preferences_view_test.dart
//
// Widget tests for [PreferencesView]. Covers rendering of preference sections
// (property, display, language), switch toggles, theme and language dialogs,
// and the save button.

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:ghar360/core/controllers/theme_controller.dart';
import 'package:ghar360/features/profile/presentation/controllers/preferences_controller.dart';
import 'package:ghar360/features/profile/presentation/views/preferences_view.dart';
import '../../../../helpers/getx_test_binding.dart';
import '../../../../helpers/mocks.dart';
import '../../../../helpers/pump_app.dart';

// ---------------------------------------------------------------------------
// Stub controller
// ---------------------------------------------------------------------------

class _StubPreferencesController extends GetxServiceMock implements PreferencesController {
  @override
  final RxBool pushNotifications = true.obs;

  @override
  final RxBool emailNotifications = true.obs;

  @override
  final RxBool similarProperties = true.obs;

  @override
  final Rx<AppThemeMode> themeMode = AppThemeMode.system.obs;

  /// Observable backing [getCurrentLanguage] so the Obx wrapper in the view
  /// detects an observable read (the real controller reads a reactive locale).
  final RxString currentLanguageName = 'English'.obs;

  bool saveCalled = false;
  String? changedLangCode;
  String? changedCountryCode;
  AppThemeMode? updatedTheme;

  @override
  void savePreferences() {
    saveCalled = true;
  }

  @override
  void updateTheme(AppThemeMode mode) {
    updatedTheme = mode;
    themeMode.value = mode;
  }

  @override
  void updateThemeFromBoolean(bool isDark) {
    updateTheme(isDark ? AppThemeMode.dark : AppThemeMode.light);
  }

  @override
  void changeLanguage(String languageCode, String countryCode) {
    changedLangCode = languageCode;
    changedCountryCode = countryCode;
    // Update the observable so the view rebuilds.
    currentLanguageName.value = languageCode == 'hi' ? 'हिंदी' : 'English';
  }

  @override
  String getCurrentLanguage() => currentLanguageName.value;

  @override
  bool get isPushNotificationsEnabled => pushNotifications.value;

  @override
  bool get isEmailNotificationsEnabled => emailNotifications.value;

  @override
  bool get isSimilarPropertiesEnabled => similarProperties.value;

  @override
  AppThemeMode get currentThemeMode => themeMode.value;

  @override
  String get currentThemeNameKey {
    switch (themeMode.value) {
      case AppThemeMode.light:
        return 'light_mode';
      case AppThemeMode.dark:
        return 'dark_mode';
      case AppThemeMode.system:
        return 'system_mode';
    }
  }

  @override
  String get currentThemeName => currentThemeNameKey;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _StubPreferencesController controller;

  setUp(() {
    GetxTestBinding.init();
    controller = _StubPreferencesController();
    Get.put<PreferencesController>(controller);
  });

  tearDown(() => GetxTestBinding.reset());

  Future<void> pumpView(WidgetTester tester) async {
    await tester.pumpApp(const PreferencesView());
    await tester.pump();
  }

  group('PreferencesView rendering', () {
    testWidgets('renders the preferences screen with app bar title', (tester) async {
      await pumpView(tester);

      expect(find.byType(PreferencesView), findsOneWidget);
      expect(find.text('My Preferences'), findsOneWidget);
    });

    testWidgets('renders property preferences section with three switches', (tester) async {
      await pumpView(tester);

      expect(find.text('Property Preferences'), findsOneWidget);
      expect(find.text('Push Notifications'), findsOneWidget);
      expect(find.text('Email Notifications'), findsOneWidget);
      expect(find.text('Similar Properties'), findsOneWidget);
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

    testWidgets('renders save preferences button with correct key', (tester) async {
      await pumpView(tester);

      await tester.ensureVisible(find.byKey(const ValueKey('qa.profile.preferences.save')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('qa.profile.preferences.save')), findsOneWidget);
      expect(find.text('Save Preferences'), findsOneWidget);
    });
  });

  group('PreferencesView switch toggles', () {
    testWidgets('toggling push notifications switch updates the value', (tester) async {
      await pumpView(tester);

      final switches = find.byType(Switch);
      expect(switches, findsNWidgets(3));

      expect(controller.pushNotifications.value, isTrue);
      await tester.tap(switches.at(0));
      await tester.pump();

      expect(controller.pushNotifications.value, isFalse);
    });

    testWidgets('toggling email notifications switch updates the value', (tester) async {
      await pumpView(tester);

      final switches = find.byType(Switch);

      expect(controller.emailNotifications.value, isTrue);
      await tester.tap(switches.at(1));
      await tester.pump();

      expect(controller.emailNotifications.value, isFalse);
    });

    testWidgets('toggling similar properties switch updates the value', (tester) async {
      await pumpView(tester);

      final switches = find.byType(Switch);

      expect(controller.similarProperties.value, isTrue);
      await tester.tap(switches.at(2));
      await tester.pump();

      expect(controller.similarProperties.value, isFalse);
    });
  });

  group('PreferencesView theme selector', () {
    testWidgets('tapping theme selector opens theme dialog', (tester) async {
      await pumpView(tester);

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

      await tester.tap(find.byKey(const ValueKey('qa.profile.preferences.theme_selector')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dark Mode'));
      await tester.pumpAndSettle();

      expect(controller.updatedTheme, AppThemeMode.dark);
      // Dialog should be dismissed — 'Light Mode' only appeared in the dialog.
      expect(find.text('Light Mode'), findsNothing);
    });

    testWidgets('selecting light mode calls updateTheme and closes dialog', (tester) async {
      await pumpView(tester);

      await tester.tap(find.byKey(const ValueKey('qa.profile.preferences.theme_selector')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Light Mode'));
      await tester.pumpAndSettle();

      expect(controller.updatedTheme, AppThemeMode.light);
    });

    testWidgets('selecting system mode calls updateTheme and closes dialog', (tester) async {
      // Start from a non-system mode.
      controller.themeMode.value = AppThemeMode.dark;
      await pumpView(tester);

      await tester.tap(find.byKey(const ValueKey('qa.profile.preferences.theme_selector')));
      await tester.pumpAndSettle();

      // 'System Mode' appears twice (selector shows 'Dark Mode' now, dialog has all 3).
      // Actually with dark mode, selector shows 'Dark Mode', so 'System Mode' is only in dialog.
      await tester.tap(find.text('System Mode'));
      await tester.pumpAndSettle();

      expect(controller.updatedTheme, AppThemeMode.system);
    });

    testWidgets('tapping cancel in theme dialog closes it without changing theme', (tester) async {
      await pumpView(tester);

      await tester.tap(find.byKey(const ValueKey('qa.profile.preferences.theme_selector')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(controller.updatedTheme, isNull);
      // 'Light Mode' only appeared in the dialog.
      expect(find.text('Light Mode'), findsNothing);
    });
  });

  group('PreferencesView language selector', () {
    testWidgets('tapping language selector opens language dialog', (tester) async {
      await pumpView(tester);

      await tester.tap(find.byKey(const ValueKey('qa.profile.preferences.language_selector')));
      await tester.pumpAndSettle();

      expect(find.text('Select Language'), findsWidgets);
      // 'English' appears in both the selector and the dialog.
      expect(find.text('English'), findsNWidgets(2));
      expect(find.text('हिंदी'), findsOneWidget);
    });

    testWidgets('selecting Hindi calls changeLanguage and closes dialog', (tester) async {
      await pumpView(tester);

      await tester.tap(find.byKey(const ValueKey('qa.profile.preferences.language_selector')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('हिंदी'));
      await tester.pumpAndSettle();

      expect(controller.changedLangCode, 'hi');
      expect(controller.changedCountryCode, 'IN');
    });

    testWidgets('selecting English calls changeLanguage and closes dialog', (tester) async {
      await pumpView(tester);

      await tester.tap(find.byKey(const ValueKey('qa.profile.preferences.language_selector')));
      await tester.pumpAndSettle();

      // 'English' appears twice (selector + dialog); tap the last one (dialog).
      await tester.tap(find.text('English').last);
      await tester.pumpAndSettle();

      expect(controller.changedLangCode, 'en');
      expect(controller.changedCountryCode, 'US');
    });

    testWidgets('tapping cancel in language dialog closes it without changing language', (
      tester,
    ) async {
      await pumpView(tester);

      await tester.tap(find.byKey(const ValueKey('qa.profile.preferences.language_selector')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(controller.changedLangCode, isNull);
      // 'हिंदी' only appeared in the dialog.
      expect(find.text('हिंदी'), findsNothing);
    });
  });

  group('PreferencesView save button', () {
    testWidgets('tapping save preferences calls savePreferences', (tester) async {
      await pumpView(tester);

      await tester.ensureVisible(find.byKey(const ValueKey('qa.profile.preferences.save')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('qa.profile.preferences.save')));
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      expect(controller.saveCalled, isTrue);
    });
  });
}
