import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/design/app_design_theme.dart';
import 'package:ghar360/core/design/app_design_tokens.dart';
import 'package:ghar360/core/utils/app_spacing.dart';
import '../../helpers/google_fonts_test_helper.dart';

void main() {
  // GoogleFonts (used by AppDesignComponents.textTheme) resolves fonts via the
  // asset bundle, which requires the test binding to be initialised before any
  // theme is constructed. Themes are built inside a guarded zone (see helper)
  // so the fire-and-forget font-loading errors don't fail these tests.
  configureGoogleFontsForTests();

  group('AppDesignTheme.light', () {
    late final ThemeData theme;
    setUpAll(() {
      theme = withFontLoadingErrorsIgnored(AppDesignTheme.light);
    });

    test('has light brightness', () {
      expect(theme.brightness, Brightness.light);
    });

    test('primary color is brand gold', () {
      expect(theme.colorScheme.primary, AppDesignTokens.brandGold);
    });

    test('scaffold background is neutral50', () {
      expect(theme.scaffoldBackgroundColor, AppDesignTokens.neutral50);
    });

    test('color scheme is configured correctly', () {
      expect(theme.colorScheme.primary, AppDesignTokens.brandGold);
      expect(theme.colorScheme.onPrimary, AppDesignTokens.neutral900);
      expect(theme.colorScheme.secondary, AppDesignTokens.accentOrange);
      expect(theme.colorScheme.onSecondary, AppDesignTokens.neutralWhite);
      expect(theme.colorScheme.surface, AppDesignTokens.neutralWhite);
      expect(theme.colorScheme.onSurface, AppDesignTokens.neutral900);
      expect(theme.colorScheme.error, AppDesignTokens.error);
      expect(theme.colorScheme.onError, AppDesignTokens.neutralWhite);
      expect(theme.colorScheme.outline, AppDesignTokens.neutral300);
    });

    test('uses Material 3', () {
      expect(theme.useMaterial3, isTrue);
    });

    test('divider theme uses neutral300 with thickness 1', () {
      expect(theme.dividerTheme.color, AppDesignTokens.neutral300);
      expect(theme.dividerTheme.thickness, 1);
    });
  });

  group('AppDesignTheme.dark', () {
    late final ThemeData theme;
    setUpAll(() {
      theme = withFontLoadingErrorsIgnored(AppDesignTheme.dark);
    });

    test('has dark brightness', () {
      expect(theme.brightness, Brightness.dark);
    });

    test('primary color is brand gold', () {
      expect(theme.colorScheme.primary, AppDesignTokens.brandGold);
    });

    test('scaffold background is neutral900', () {
      expect(theme.scaffoldBackgroundColor, AppDesignTokens.neutral900);
    });

    test('color scheme is configured correctly', () {
      expect(theme.colorScheme.primary, AppDesignTokens.brandGold);
      expect(theme.colorScheme.onPrimary, AppDesignTokens.neutral900);
      expect(theme.colorScheme.secondary, AppDesignTokens.accentOrange);
      expect(theme.colorScheme.onSecondary, AppDesignTokens.darkTextPrimary);
      expect(theme.colorScheme.surface, AppDesignTokens.darkSurface);
      expect(theme.colorScheme.onSurface, AppDesignTokens.darkTextPrimary);
      expect(theme.colorScheme.error, AppDesignTokens.error);
      expect(theme.colorScheme.onError, AppDesignTokens.darkTextPrimary);
      expect(theme.colorScheme.outline, AppDesignTokens.darkTextTertiary);
    });

    test('uses Material 3', () {
      expect(theme.useMaterial3, isTrue);
    });

    test('divider theme uses darkBorder with thickness 1', () {
      expect(theme.dividerTheme.color, AppDesignTokens.darkBorder);
      expect(theme.dividerTheme.thickness, 1);
    });
  });

  group('AppDesignTheme motion constants', () {
    test('defaultTransitionDuration is AppDurations.normal', () {
      expect(AppDesignTheme.defaultTransitionDuration, AppDurations.normal);
      expect(AppDesignTheme.defaultTransitionDuration, const Duration(milliseconds: 300));
    });

    test('defaultTransitionCurve is AppCurves.standard', () {
      expect(AppDesignTheme.defaultTransitionCurve, AppCurves.standard);
      expect(AppDesignTheme.defaultTransitionCurve, Curves.easeOutCubic);
    });
  });
}
