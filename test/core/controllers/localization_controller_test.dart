// test/core/controllers/localization_controller_test.dart
//
// Unit tests for [LocalizationController]. Covers:
// - Initial locale (en_US when no saved preference and no device locale)
// - supportedLocales static list
// - languageNames map
// - changeLanguage updates locale, persists to storage, and updates flags
// - getCurrentLanguageName returns correct display name
// - isEnglish / isHindi flags
// - _normalizeToSupported indirectly via onInit with saved preferences
// - Persistence across controller instances
//
// These tests use [testWidgets] with a minimal [GetMaterialApp] host because
// [LocalizationController] calls [Get.updateLocale], which requires an active
// GetX navigation/app context to perform the widget-tree reassemble.

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ghar360/core/controllers/localization_controller.dart';

import '../../helpers/getx_test_binding.dart';

void main() {
  // Mock path_provider platform channel so GetStorage can initialise in tests.
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() {
    Get.testMode = true;
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

  /// Pumps a minimal [GetMaterialApp] so [Get.updateLocale] has a valid
  /// navigation context, then runs [body] with a freshly-created controller.
  Future<void> withController(
    WidgetTester tester,
    Future<void> Function(LocalizationController) body, {
    Locale? initialLocale,
  }) async {
    await tester.pumpWidget(
      GetMaterialApp(
        locale: initialLocale,
        supportedLocales: LocalizationController.supportedLocales,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    // Create and register the controller AFTER the widget tree is settled so
    // that onInit → _loadLocale → Get.updateLocale can safely reassemble.
    // runAsync is used because Get.updateLocale → performReassemble →
    // scheduleWarmUpFrame asserts outside the test framework's fake async zone.
    LocalizationController? controller;
    await tester.runAsync(() async {
      controller = LocalizationController();
      Get.put<LocalizationController>(controller!);
      // Allow the unawaited Get.updateLocale (from onInit/_loadLocale) to
      // complete its reassemble without tripping the test scheduler assertion.
      await Future.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    await body(controller!);
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
  }

  group('LocalizationController', () {
    // ── Static members (no widget host needed) ────────────────────────

    test('supportedLocales contains en_US and hi_IN', () {
      expect(LocalizationController.supportedLocales.length, 2);
      expect(
        LocalizationController.supportedLocales,
        contains(const Locale('en', 'US')),
      );
      expect(
        LocalizationController.supportedLocales,
        contains(const Locale('hi', 'IN')),
      );
    });

    // ── Initial state ─────────────────────────────────────────────────

    testWidgets('initial locale is en_US when no saved preference', (tester) async {
      await withController(tester, (c) async {
        expect(c.currentLocale, const Locale('en', 'US'));
      });
    });

    testWidgets('isEnglish is true initially', (tester) async {
      await withController(tester, (c) async {
        expect(c.isEnglish, isTrue);
      });
    });

    testWidgets('isHindi is false initially', (tester) async {
      await withController(tester, (c) async {
        expect(c.isHindi, isFalse);
      });
    });

    testWidgets('getCurrentLanguageName returns English initially', (tester) async {
      await withController(tester, (c) async {
        expect(c.getCurrentLanguageName(), 'English');
      });
    });

    // ── languageNames ─────────────────────────────────────────────────

    testWidgets('languageNames maps en_US to English', (tester) async {
      await withController(tester, (c) async {
        expect(c.languageNames['en_US'], 'English');
      });
    });

    testWidgets('languageNames maps hi_IN to Hindi', (tester) async {
      await withController(tester, (c) async {
        expect(c.languageNames['hi_IN'], 'हिंदी');
      });
    });

    // ── changeLanguage ────────────────────────────────────────────────

    testWidgets('changeLanguage to Hindi updates currentLocale', (tester) async {
      await withController(tester, (c) async {
        await tester.runAsync(() async {
          c.changeLanguage('hi', 'IN');
        });
        expect(c.currentLocale, const Locale('hi', 'IN'));
      });
    });

    testWidgets('changeLanguage to Hindi sets isHindi true and isEnglish false', (tester) async {
      await withController(tester, (c) async {
        await tester.runAsync(() async {
          c.changeLanguage('hi', 'IN');
        });
        expect(c.isHindi, isTrue);
        expect(c.isEnglish, isFalse);
      });
    });

    testWidgets('changeLanguage to Hindi updates getCurrentLanguageName', (tester) async {
      await withController(tester, (c) async {
        await tester.runAsync(() async {
          c.changeLanguage('hi', 'IN');
        });
        expect(c.getCurrentLanguageName(), 'हिंदी');
      });
    });

    testWidgets('changeLanguage persists language_code and country_code to storage', (tester) async {
      await withController(tester, (c) async {
        await tester.runAsync(() async {
          c.changeLanguage('hi', 'IN');
        });
        expect(GetStorage().read('language_code'), 'hi');
        expect(GetStorage().read('country_code'), 'IN');
      });
    });

    testWidgets('changeLanguage back to English restores flags and name', (tester) async {
      await withController(tester, (c) async {
        await tester.runAsync(() async {
          c.changeLanguage('hi', 'IN');
        });
        await tester.runAsync(() async {
          c.changeLanguage('en', 'US');
        });

        expect(c.currentLocale, const Locale('en', 'US'));
        expect(c.isEnglish, isTrue);
        expect(c.isHindi, isFalse);
        expect(c.getCurrentLanguageName(), 'English');
      });
    });

    // ── _loadLocale (indirect via onInit with saved preference) ───────

    testWidgets('onInit loads saved Hindi preference from storage', (tester) async {
      await GetStorage().write('language_code', 'hi');
      await GetStorage().write('country_code', 'IN');

      await withController(tester, (c) async {
        expect(c.currentLocale, const Locale('hi', 'IN'));
        expect(c.isHindi, isTrue);
        expect(c.getCurrentLanguageName(), 'हिंदी');
      });
    });

    testWidgets('onInit loads saved English preference from storage', (tester) async {
      await GetStorage().write('language_code', 'en');
      await GetStorage().write('country_code', 'US');

      await withController(tester, (c) async {
        expect(c.currentLocale, const Locale('en', 'US'));
        expect(c.isEnglish, isTrue);
      });
    });

    testWidgets('onInit normalizes to en_US when only language_code is saved', (tester) async {
      // Only language_code present (country_code missing) → falls to the
      // device-locale normalization branch, which defaults to en_US.
      await GetStorage().write('language_code', 'hi');

      await withController(tester, (c) async {
        // Without both codes, the saved-preference branch is skipped and the
        // device locale is normalized. In tests Get.deviceLocale is null → en_US.
        expect(c.currentLocale, const Locale('en', 'US'));
      });
    });

    // ── getCurrentLanguageName fallback ───────────────────────────────

    testWidgets('getCurrentLanguageName returns English for unknown locale key', (tester) async {
      await withController(tester, (c) async {
        // Switch to a locale that has no entry in languageNames.
        await tester.runAsync(() async {
          c.changeLanguage('fr', 'FR');
        });
        expect(c.getCurrentLanguageName(), 'English');
      });
    });
  });
}
