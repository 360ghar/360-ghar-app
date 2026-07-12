// test/core/controllers/theme_controller_test.dart
//
// Unit tests for [ThemeController]. Covers:
// - Initial theme mode (system default)
// - setThemeMode changes value
// - toggleTheme cycles through modes
// - setTheme convenience method
// - Persistence to storage
// - currentThemeName and isSystemMode getters
// - syncWithPreferences

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'package:ghar360/core/controllers/theme_controller.dart';
import '../../helpers/getx_test_binding.dart';

void main() {
  // Mock path_provider platform channel so GetStorage can initialise in tests.
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return '.';
        }
        return null;
      },
    );
  });

  setUp(() async {
    GetxTestBinding.init();
    await GetStorage.init();
    GetStorage().erase();
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  ThemeController createController() {
    final c = ThemeController();
    Get.put<ThemeController>(c);
    return c;
  }

  // -------------------------------------------------------------------------
  // Initial state
  // -------------------------------------------------------------------------
  group('initial state', () {
    test('defaults to system theme mode when no storage value exists', () {
      final c = createController();

      expect(c.currentThemeMode, AppThemeMode.system);
    });

    test('isSystemMode is true by default', () {
      final c = createController();

      expect(c.isSystemMode, isTrue);
    });

    test('currentThemeName returns "System" by default', () {
      final c = createController();

      expect(c.currentThemeName, 'System');
    });

    test('themeMode getter returns ThemeMode.system by default', () {
      final c = createController();

      expect(c.themeMode, ThemeMode.system);
    });

    test('isDarkMode is false by default (system defaults to light in test)', () {
      final c = createController();

      // In test environment, platformBrightness defaults to light
      expect(c.isDarkMode.value, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // setThemeMode
  // -------------------------------------------------------------------------
  group('setThemeMode', () {
    test('changes to light mode', () {
      final c = createController();

      c.setThemeMode(AppThemeMode.light);

      expect(c.currentThemeMode, AppThemeMode.light);
      expect(c.isDarkMode.value, isFalse);
      expect(c.isSystemMode, isFalse);
      expect(c.currentThemeName, 'Light');
      expect(c.themeMode, ThemeMode.light);
    });

    test('changes to dark mode', () {
      final c = createController();

      c.setThemeMode(AppThemeMode.dark);

      expect(c.currentThemeMode, AppThemeMode.dark);
      expect(c.isDarkMode.value, isTrue);
      expect(c.isSystemMode, isFalse);
      expect(c.currentThemeName, 'Dark');
      expect(c.themeMode, ThemeMode.dark);
    });

    test('changes back to system mode', () {
      final c = createController();
      c.setThemeMode(AppThemeMode.dark);

      c.setThemeMode(AppThemeMode.system);

      expect(c.currentThemeMode, AppThemeMode.system);
      expect(c.isSystemMode, isTrue);
      expect(c.currentThemeName, 'System');
      expect(c.themeMode, ThemeMode.system);
    });

    test('persists dark mode to storage', () {
      final c = createController();

      c.setThemeMode(AppThemeMode.dark);

      final stored = GetStorage().read('themeMode');
      expect(stored, 'dark');
    });

    test('persists light mode to storage', () {
      final c = createController();

      c.setThemeMode(AppThemeMode.light);

      final stored = GetStorage().read('themeMode');
      expect(stored, 'light');
    });

    test('persists system mode to storage', () {
      final c = createController();

      c.setThemeMode(AppThemeMode.system);

      final stored = GetStorage().read('themeMode');
      expect(stored, 'system');
    });
  });

  // -------------------------------------------------------------------------
  // toggleTheme
  // -------------------------------------------------------------------------
  group('toggleTheme', () {
    test('cycles from light to dark', () {
      final c = createController();
      c.setThemeMode(AppThemeMode.light);

      c.toggleTheme();

      expect(c.currentThemeMode, AppThemeMode.dark);
    });

    test('cycles from dark to system', () {
      final c = createController();
      c.setThemeMode(AppThemeMode.dark);

      c.toggleTheme();

      expect(c.currentThemeMode, AppThemeMode.system);
    });

    test('cycles from system to light', () {
      final c = createController();
      c.setThemeMode(AppThemeMode.system);

      c.toggleTheme();

      expect(c.currentThemeMode, AppThemeMode.light);
    });

    test('full cycle returns to original mode', () {
      final c = createController();
      c.setThemeMode(AppThemeMode.light);

      c.toggleTheme(); // light → dark
      c.toggleTheme(); // dark → system
      c.toggleTheme(); // system → light

      expect(c.currentThemeMode, AppThemeMode.light);
    });
  });

  // -------------------------------------------------------------------------
  // setTheme convenience method
  // -------------------------------------------------------------------------
  group('setTheme', () {
    test('setTheme(true) sets dark mode', () {
      final c = createController();

      c.setTheme(true);

      expect(c.currentThemeMode, AppThemeMode.dark);
      expect(c.isDarkMode.value, isTrue);
    });

    test('setTheme(false) sets light mode', () {
      final c = createController();
      c.setThemeMode(AppThemeMode.dark);

      c.setTheme(false);

      expect(c.currentThemeMode, AppThemeMode.light);
      expect(c.isDarkMode.value, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // syncWithPreferences
  // -------------------------------------------------------------------------
  group('syncWithPreferences', () {
    test('syncs to dark when preference says dark', () {
      final c = createController();
      c.setThemeMode(AppThemeMode.light);

      c.syncWithPreferences(true);

      expect(c.currentThemeMode, AppThemeMode.dark);
    });

    test('syncs to light when preference says not dark', () {
      final c = createController();
      c.setThemeMode(AppThemeMode.dark);

      c.syncWithPreferences(false);

      expect(c.currentThemeMode, AppThemeMode.light);
    });

    test('does nothing when preference matches current mode', () {
      final c = createController();
      c.setThemeMode(AppThemeMode.dark);

      c.syncWithPreferences(true);

      expect(c.currentThemeMode, AppThemeMode.dark);
    });
  });

  // -------------------------------------------------------------------------
  // Storage persistence across instances
  // -------------------------------------------------------------------------
  group('storage persistence across instances', () {
    test('new controller reads persisted theme from storage', () async {
      // First controller sets dark
      final c1 = createController();
      c1.setThemeMode(AppThemeMode.dark);

      // Dispose and recreate (simulating app restart)
      GetxTestBinding.reset();
      GetxTestBinding.init();
      await GetStorage.init();

      final c2 = ThemeController();
      Get.put<ThemeController>(c2);

      expect(c2.currentThemeMode, AppThemeMode.dark);
      expect(c2.isDarkMode.value, isTrue);
    });

    test('new controller defaults to system when storage has invalid value', () async {
      // Write an invalid value to storage
      GetStorage().write('themeMode', 'invalid_mode');

      final c = ThemeController();
      Get.put<ThemeController>(c);

      // Should fall back to system
      expect(c.currentThemeMode, AppThemeMode.system);
    });

    test('migrates legacy int themeMode index to enum name', () async {
      GetStorage().write('themeMode', AppThemeMode.dark.index);

      final c = ThemeController();
      Get.put<ThemeController>(c);

      expect(c.currentThemeMode, AppThemeMode.dark);
      expect(GetStorage().read('themeMode'), 'dark');
    });

    test('parseStoredThemeMode accepts string names and int indexes', () {
      expect(ThemeController.parseStoredThemeMode('light'), AppThemeMode.light);
      expect(ThemeController.parseStoredThemeMode('dark'), AppThemeMode.dark);
      expect(ThemeController.parseStoredThemeMode('system'), AppThemeMode.system);
      expect(ThemeController.parseStoredThemeMode(0), AppThemeMode.light);
      expect(ThemeController.parseStoredThemeMode(1), AppThemeMode.dark);
      expect(ThemeController.parseStoredThemeMode(2), AppThemeMode.system);
      expect(ThemeController.parseStoredThemeMode(99), AppThemeMode.system);
      expect(ThemeController.parseStoredThemeMode('nope'), AppThemeMode.system);
      expect(ThemeController.parseStoredThemeMode(null), AppThemeMode.system);
    });
  });
}
