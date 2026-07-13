import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'package:ghar360/core/controllers/theme_controller.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/app_design_theme.dart';
import 'package:ghar360/core/design/app_design_tokens.dart';
import '../../helpers/getx_test_binding.dart';
import '../../helpers/google_fonts_test_helper.dart';

void main() {
  // AppDesign.lightTheme/darkTheme and AppDesignTheme use GoogleFonts; configure
  // the binding and disable runtime fetching. Theme construction is wrapped in
  // a guarded zone (see helper) so fire-and-forget font-load errors don't fail
  // these tests.
  configureGoogleFontsForTests();

  // Mock the path_provider platform channel so GetStorage (used by
  // ThemeController) can initialise in the GetX-backed getter tests below.
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      pathProviderChannel,
      (MethodCall call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          return '.';
        }
        return null;
      },
    );
  });

  group('AppPalette (light)', () {
    final palette = const AppPalette(isDark: false);

    test('background and surface colors', () {
      expect(palette.background, AppDesignTokens.neutral50);
      expect(palette.surface, AppDesignTokens.neutralWhite);
      expect(palette.cardBackground, AppDesignTokens.neutralWhite);
    });

    test('text colors', () {
      expect(palette.textPrimary, AppDesignTokens.neutral900);
      expect(palette.textSecondary, AppDesignTokens.neutral500);
      expect(palette.textTertiary, AppDesignTokens.neutral500);
    });

    test('border, divider, inputBackground', () {
      expect(palette.border, AppDesignTokens.neutral300);
      expect(palette.divider, AppDesignTokens.neutral300.withValues(alpha: 0.7));
      expect(palette.inputBackground, AppDesignTokens.neutral50);
    });

    test('shadow', () {
      expect(palette.shadow, AppDesignTokens.lightShadow);
    });

    test('appBar and navigation', () {
      expect(palette.appBarBackground, AppDesignTokens.neutralWhite);
      expect(palette.appBarText, AppDesignTokens.neutral900);
      expect(palette.appBarIcon, AppDesignTokens.neutral900);
      expect(palette.navigationBackground, AppDesignTokens.neutralWhite);
      expect(palette.navigationUnselected, AppDesignTokens.neutral500);
    });

    test('button colors', () {
      expect(palette.buttonPrimary, AppDesignTokens.brandGold);
      expect(palette.buttonPrimaryText, AppDesignTokens.neutral900);
      expect(palette.buttonSecondaryBackground, AppDesignTokens.neutral50);
      expect(palette.buttonSecondaryText, AppDesignTokens.neutral900);
    });

    test('status and accent colors', () {
      expect(palette.success, AppDesignTokens.success);
      expect(palette.warning, AppDesignTokens.warning);
      expect(palette.error, AppDesignTokens.error);
      expect(palette.accentBlue, AppDesignTokens.accentBlue);
      expect(palette.accentOrange, AppDesignTokens.accentOrange);
      expect(palette.accentGreen, AppDesignTokens.accentGreen);
    });

    test('favorite colors', () {
      expect(palette.favoriteActive, AppDesignTokens.error);
      expect(palette.favoriteInactive, AppDesignTokens.neutral500);
    });
  });

  group('AppPalette (dark)', () {
    final palette = const AppPalette(isDark: true);

    test('background and surface colors', () {
      expect(palette.background, AppDesignTokens.neutral900);
      expect(palette.surface, AppDesignTokens.darkSurface);
      expect(palette.cardBackground, AppDesignTokens.darkSurface);
    });

    test('text colors', () {
      expect(palette.textPrimary, AppDesignTokens.darkTextPrimary);
      expect(palette.textSecondary, AppDesignTokens.darkTextSecondary);
      expect(palette.textTertiary, AppDesignTokens.darkTextTertiary);
    });

    test('border, divider, inputBackground', () {
      expect(palette.border, AppDesignTokens.darkBorder);
      expect(palette.divider, AppDesignTokens.darkBorder.withValues(alpha: 0.9));
      expect(palette.inputBackground, AppDesignTokens.darkSurfaceAlt);
    });

    test('shadow', () {
      expect(palette.shadow, AppDesignTokens.darkShadow);
    });

    test('appBar and navigation', () {
      expect(palette.appBarBackground, AppDesignTokens.darkSurface);
      expect(palette.appBarText, AppDesignTokens.darkTextPrimary);
      expect(palette.appBarIcon, AppDesignTokens.darkTextPrimary);
      expect(palette.navigationBackground, AppDesignTokens.darkSurface);
      expect(palette.navigationUnselected, AppDesignTokens.darkTextSecondary);
    });

    test('button colors', () {
      expect(palette.buttonPrimary, AppDesignTokens.brandGold);
      expect(palette.buttonPrimaryText, AppDesignTokens.neutral900);
      expect(palette.buttonSecondaryBackground, AppDesignTokens.darkSurfaceAlt);
      expect(palette.buttonSecondaryText, AppDesignTokens.darkTextPrimary);
    });

    test('favorite colors', () {
      expect(palette.favoriteActive, AppDesignTokens.error);
      expect(palette.favoriteInactive, AppDesignTokens.darkTextTertiary);
    });
  });

  group('AppDesign static color aliases', () {
    test('brand aliases map to tokens', () {
      expect(AppDesign.primaryYellow, AppDesignTokens.brandGold);
      expect(AppDesign.primaryYellowDark, AppDesignTokens.brandGoldDark);
      expect(AppDesign.primaryYellowLight, AppDesignTokens.brandGoldLight);
      expect(AppDesign.accentOrange, AppDesignTokens.accentOrange);
      expect(AppDesign.accentBlue, AppDesignTokens.accentBlue);
      expect(AppDesign.accentGreen, AppDesignTokens.accentGreen);
      expect(AppDesign.editorialWarm, AppDesignTokens.editorialWarm);
      expect(AppDesign.editorialInk, AppDesignTokens.editorialInk);
      expect(AppDesign.warmCream, AppDesignTokens.warmCream);
    });

    test('light aliases map to tokens', () {
      expect(AppDesign.backgroundWhite, AppDesignTokens.neutralWhite);
      expect(AppDesign.backgroundGray, AppDesignTokens.neutral50);
      expect(AppDesign.textDark, AppDesignTokens.neutral900);
      expect(AppDesign.textGray, AppDesignTokens.neutral500);
      expect(AppDesign.textLight, AppDesignTokens.neutral300);
      expect(AppDesign.cardShadow, AppDesignTokens.lightShadow);
    });

    test('dark aliases map to tokens', () {
      expect(AppDesign.darkBackground, AppDesignTokens.neutral900);
      expect(AppDesign.darkSurface, AppDesignTokens.darkSurface);
      expect(AppDesign.darkCard, AppDesignTokens.darkSurfaceAlt);
      expect(AppDesign.darkTextPrimary, AppDesignTokens.darkTextPrimary);
      expect(AppDesign.darkTextSecondary, AppDesignTokens.darkTextSecondary);
      expect(AppDesign.darkTextTertiary, AppDesignTokens.darkTextTertiary);
      expect(AppDesign.darkBorder, AppDesignTokens.darkBorder);
      expect(AppDesign.darkShadow, AppDesignTokens.darkShadow);
    });

    test('status aliases map to tokens', () {
      expect(AppDesign.successGreen, AppDesignTokens.success);
      expect(AppDesign.warningAmber, AppDesignTokens.warning);
      expect(AppDesign.errorRed, AppDesignTokens.error);
    });

    test('overlay and convenience colors', () {
      expect(AppDesign.overlayLight, const Color(0xFFFFFFFF));
      expect(AppDesign.overlayDark, const Color(0xFF000000));
      expect(AppDesign.transparent, Colors.transparent);
      expect(AppDesign.primaryColor, AppDesign.primaryYellow);
    });

    test('motion aliases match AppDesignTheme', () {
      expect(AppDesign.defaultTransitionDuration, AppDesignTheme.defaultTransitionDuration);
      expect(AppDesign.defaultTransitionCurve, AppDesignTheme.defaultTransitionCurve);
    });

    test('theme getters return light/dark ThemeData', () {
      final light = withFontLoadingErrorsIgnored(() => AppDesign.lightTheme);
      final dark = withFontLoadingErrorsIgnored(() => AppDesign.darkTheme);
      expect(light.brightness, Brightness.light);
      expect(dark.brightness, Brightness.dark);
    });
  });

  group('AppDesign.getCardShadow', () {
    test('returns a list with a single BoxShadow using shadowColor', () {
      final shadows = AppDesign.getCardShadow();
      expect(shadows, isA<List<BoxShadow>>());
      expect(shadows, hasLength(1));
      expect(shadows.first.blurRadius, 14);
      expect(shadows.first.spreadRadius, 0);
      expect(shadows.first.offset, const Offset(0, 6));
    });
  });

  group('AppDesign.getTextColorForBackground', () {
    test('returns dark text for light backgrounds', () {
      // White background is luminous (>0.5) -> dark text
      expect(AppDesign.getTextColorForBackground(Colors.white), AppDesign.textDark);
    });

    test('returns light text for dark backgrounds', () {
      // Black background is dim (<=0.5) -> light text
      expect(AppDesign.getTextColorForBackground(Colors.black), AppDesign.darkTextPrimary);
    });
  });

  group('AppDesign.getContrastColor', () {
    test('returns neutral900 for light colors', () {
      expect(AppDesign.getContrastColor(Colors.white), AppDesignTokens.neutral900);
      expect(AppDesign.getContrastColor(Colors.yellow), AppDesignTokens.neutral900);
    });

    test('returns neutralWhite for dark colors', () {
      expect(AppDesign.getContrastColor(Colors.black), AppDesignTokens.neutralWhite);
      expect(AppDesign.getContrastColor(Colors.blue), AppDesignTokens.neutralWhite);
    });
  });

  group('AppDesign GetX-backed getters', () {
    setUp(() async {
      GetxTestBinding.init();
      await GetStorage.init();
      GetStorage().erase();
    });
    tearDown(GetxTestBinding.reset);

    /// Builds and registers a real [ThemeController] pinned to [dark] mode.
    ThemeController registerThemeController(bool dark) {
      final controller = ThemeController();
      Get.put<ThemeController>(controller);
      controller.setThemeMode(dark ? AppThemeMode.dark : AppThemeMode.light);
      return controller;
    }

    test('resolve light palette when ThemeController.isDarkMode is false', () {
      registerThemeController(false);

      expect(AppDesign.background, AppDesignTokens.neutral50);
      expect(AppDesign.surface, AppDesignTokens.neutralWhite);
      expect(AppDesign.cardBackground, AppDesignTokens.neutralWhite);
      expect(AppDesign.textPrimary, AppDesignTokens.neutral900);
      expect(AppDesign.textSecondary, AppDesignTokens.neutral500);
      expect(AppDesign.textTertiary, AppDesignTokens.neutral500);
      expect(AppDesign.border, AppDesignTokens.neutral300);
      expect(AppDesign.inputBackground, AppDesignTokens.neutral50);
      expect(AppDesign.shadowColor, AppDesignTokens.lightShadow);
      expect(AppDesign.appBarBackground, AppDesignTokens.neutralWhite);
      expect(AppDesign.scaffoldBackground, AppDesignTokens.neutral50);
      expect(AppDesign.navigationBackground, AppDesignTokens.neutralWhite);
      expect(AppDesign.navigationSelected, AppDesignTokens.brandGold);
      expect(AppDesign.navigationUnselected, AppDesignTokens.neutral500);
      expect(AppDesign.buttonBackground, AppDesignTokens.brandGold);
      expect(AppDesign.buttonText, AppDesignTokens.neutral900);
      expect(AppDesign.buttonSecondaryBackground, AppDesignTokens.neutral50);
      expect(AppDesign.buttonSecondaryText, AppDesignTokens.neutral900);
      expect(AppDesign.iconColor, AppDesignTokens.neutral900);
      expect(AppDesign.placeholderText, AppDesignTokens.neutral500);
      expect(AppDesign.disabledColor, AppDesignTokens.neutral500);
      expect(AppDesign.propertyCardBackground, AppDesignTokens.neutralWhite);
      expect(AppDesign.propertyCardPrice, AppDesignTokens.brandGold);
      expect(AppDesign.filterBackground, AppDesignTokens.neutral50);
      expect(AppDesign.searchBackground, AppDesignTokens.neutral50);
      expect(AppDesign.searchHint, AppDesignTokens.neutral500);
      expect(AppDesign.switchInactive, AppDesignTokens.neutral500);
      expect(AppDesign.tabUnselected, AppDesignTokens.neutral500);
      expect(AppDesign.favoriteActive, AppDesignTokens.error);
      expect(AppDesign.favoriteInactive, AppDesignTokens.neutral500);
    });

    test('resolve dark palette when ThemeController.isDarkMode is true', () {
      registerThemeController(true);

      expect(AppDesign.background, AppDesignTokens.neutral900);
      expect(AppDesign.surface, AppDesignTokens.darkSurface);
      expect(AppDesign.cardBackground, AppDesignTokens.darkSurface);
      expect(AppDesign.textPrimary, AppDesignTokens.darkTextPrimary);
      expect(AppDesign.textSecondary, AppDesignTokens.darkTextSecondary);
      expect(AppDesign.textTertiary, AppDesignTokens.darkTextTertiary);
      expect(AppDesign.border, AppDesignTokens.darkBorder);
      expect(AppDesign.inputBackground, AppDesignTokens.darkSurfaceAlt);
      expect(AppDesign.shadowColor, AppDesignTokens.darkShadow);
      expect(AppDesign.appBarBackground, AppDesignTokens.darkSurface);
      expect(AppDesign.scaffoldBackground, AppDesignTokens.neutral900);
      expect(AppDesign.navigationBackground, AppDesignTokens.darkSurface);
      expect(AppDesign.navigationUnselected, AppDesignTokens.darkTextSecondary);
      expect(AppDesign.buttonSecondaryBackground, AppDesignTokens.darkSurfaceAlt);
      expect(AppDesign.buttonSecondaryText, AppDesignTokens.darkTextPrimary);
      expect(AppDesign.iconColor, AppDesignTokens.darkTextPrimary);
      expect(AppDesign.placeholderText, AppDesignTokens.darkTextTertiary);
      expect(AppDesign.disabledColor, AppDesignTokens.darkTextTertiary);
      expect(AppDesign.propertyCardBackground, AppDesignTokens.darkSurface);
      expect(AppDesign.filterBackground, AppDesignTokens.darkSurfaceAlt);
      expect(AppDesign.searchBackground, AppDesignTokens.darkSurfaceAlt);
      expect(AppDesign.searchHint, AppDesignTokens.darkTextTertiary);
      expect(AppDesign.switchInactive, AppDesignTokens.darkTextTertiary);
      expect(AppDesign.tabUnselected, AppDesignTokens.darkTextSecondary);
      expect(AppDesign.favoriteInactive, AppDesignTokens.darkTextTertiary);
    });

    test('always-on brand aliases are brightness-independent', () {
      registerThemeController(false);
      expect(AppDesign.navigationSelected, AppDesignTokens.brandGold);
      expect(AppDesign.tabSelected, AppDesignTokens.brandGold);
      expect(AppDesign.tabIndicator, AppDesignTokens.brandGold);
      expect(AppDesign.loadingIndicator, AppDesignTokens.brandGold);
      expect(AppDesign.propertyCardPrice, AppDesignTokens.brandGold);
      expect(AppDesign.switchActive, AppDesignTokens.brandGold);
      expect(AppDesign.switchTrackActive, AppDesignTokens.brandGold.withValues(alpha: 0.3));
    });
  });
}
