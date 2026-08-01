import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/design/app_design_components.dart';
import 'package:ghar360/core/design/app_design_tokens.dart';
import 'package:ghar360/core/utils/app_spacing.dart';
import '../../helpers/google_fonts_test_helper.dart';

void main() {
  // textTheme/appBarTheme use GoogleFonts; configure the binding and disable
  // runtime fetching. GoogleFonts-using builders are wrapped in a guarded zone
  // (see helper) so fire-and-forget font-load errors don't fail these tests.
  configureGoogleFontsForTests();

  group('AppDesignComponents.textTheme', () {
    test('light theme uses neutral900/neutral500 text colors', () {
      final theme = withFontLoadingErrorsIgnored(
        () => AppDesignComponents.textTheme(Brightness.light),
      );

      expect(theme.bodyLarge!.color, AppDesignTokens.neutral900);
      expect(theme.bodyLarge!.fontSize, 16);
      expect(theme.bodyLarge!.height, 1.6);

      expect(theme.bodyMedium!.color, AppDesignTokens.neutral500);
      expect(theme.bodyMedium!.fontSize, 14);
      expect(theme.bodyMedium!.height, 1.55);

      expect(theme.bodySmall!.color, AppDesignTokens.neutral500);
      expect(theme.bodySmall!.fontSize, 12);
      expect(theme.bodySmall!.height, 1.45);
    });

    test('dark theme uses darkText* colors', () {
      final theme = withFontLoadingErrorsIgnored(
        () => AppDesignComponents.textTheme(Brightness.dark),
      );

      expect(theme.bodyLarge!.color, AppDesignTokens.darkTextPrimary);
      expect(theme.bodyLarge!.fontSize, 16);
      expect(theme.bodyLarge!.height, 1.6);

      expect(theme.bodyMedium!.color, AppDesignTokens.darkTextSecondary);
      expect(theme.bodyMedium!.fontSize, 14);
      expect(theme.bodyMedium!.height, 1.55);

      expect(theme.bodySmall!.color, AppDesignTokens.darkTextTertiary);
      expect(theme.bodySmall!.fontSize, 12);
      expect(theme.bodySmall!.height, 1.45);
    });

    test('labels use primary color and bold weight in both modes', () {
      final light = withFontLoadingErrorsIgnored(
        () => AppDesignComponents.textTheme(Brightness.light),
      );
      final dark = withFontLoadingErrorsIgnored(
        () => AppDesignComponents.textTheme(Brightness.dark),
      );

      for (final theme in [light, dark]) {
        final primary = theme == light
            ? AppDesignTokens.neutral900
            : AppDesignTokens.darkTextPrimary;

        expect(theme.labelLarge!.color, primary);
        expect(theme.labelLarge!.fontSize, 14);
        expect(theme.labelLarge!.fontWeight, FontWeight.w700);

        expect(theme.labelMedium!.color, primary);
        expect(theme.labelMedium!.fontSize, 12);
        expect(theme.labelMedium!.fontWeight, FontWeight.w700);

        expect(theme.labelSmall!.color, primary);
        expect(theme.labelSmall!.fontSize, 11);
        expect(theme.labelSmall!.fontWeight, FontWeight.w700);
      }
    });

    test('titles use primary color, bold weight, and correct sizes', () {
      final light = withFontLoadingErrorsIgnored(
        () => AppDesignComponents.textTheme(Brightness.light),
      );

      expect(light.titleLarge!.color, AppDesignTokens.neutral900);
      expect(light.titleLarge!.fontSize, 20);
      expect(light.titleLarge!.fontWeight, FontWeight.w700);
      expect(light.titleLarge!.height, 1.25);

      expect(light.titleMedium!.fontSize, 16);
      expect(light.titleMedium!.fontWeight, FontWeight.w700);

      expect(light.titleSmall!.fontSize, 14);
      expect(light.titleSmall!.fontWeight, FontWeight.w700);
    });

    test('display/headline styles use Sora with correct sizes and weights', () {
      final theme = withFontLoadingErrorsIgnored(
        () => AppDesignComponents.textTheme(Brightness.light),
      );

      expect(theme.displayLarge!.fontSize, 34);
      expect(theme.displayLarge!.fontWeight, FontWeight.w700);
      expect(theme.displayLarge!.height, 1.1);
      expect(theme.displayLarge!.letterSpacing, -0.7);

      expect(theme.displayMedium!.fontSize, 28);
      expect(theme.displayMedium!.letterSpacing, -0.45);

      expect(theme.displaySmall!.fontSize, 24);
      expect(theme.displaySmall!.letterSpacing, -0.3);

      expect(theme.headlineLarge!.fontSize, 22);
      expect(theme.headlineMedium!.fontSize, 20);
      expect(theme.headlineSmall!.fontSize, 18);
      for (final style in [theme.headlineLarge!, theme.headlineMedium!, theme.headlineSmall!]) {
        expect(style.fontWeight, FontWeight.w700);
        expect(style.height, 1.2);
      }
    });
  });

  group('AppDesignComponents.appBarTheme', () {
    test('light uses white background and neutral900 foreground', () {
      final theme = withFontLoadingErrorsIgnored(
        () => AppDesignComponents.appBarTheme(Brightness.light),
      );

      expect(theme.backgroundColor, AppDesignTokens.neutralWhite);
      expect(theme.foregroundColor, AppDesignTokens.neutral900);
      expect(theme.elevation, 0);
      expect(theme.scrolledUnderElevation, 0);
      expect(theme.centerTitle, isTrue);
      expect(theme.iconTheme!.color, AppDesignTokens.neutral900);
      expect(theme.titleTextStyle!.color, AppDesignTokens.neutral900);
      expect(theme.titleTextStyle!.fontSize, 20);
      expect(theme.titleTextStyle!.fontWeight, FontWeight.w600);
    });

    test('dark uses darkSurface background and darkTextPrimary foreground', () {
      final theme = withFontLoadingErrorsIgnored(
        () => AppDesignComponents.appBarTheme(Brightness.dark),
      );

      expect(theme.backgroundColor, AppDesignTokens.darkSurface);
      expect(theme.foregroundColor, AppDesignTokens.darkTextPrimary);
      expect(theme.elevation, 0);
      expect(theme.centerTitle, isTrue);
      expect(theme.iconTheme!.color, AppDesignTokens.darkTextPrimary);
      expect(theme.titleTextStyle!.color, AppDesignTokens.darkTextPrimary);
      expect(theme.titleTextStyle!.fontSize, 20);
      expect(theme.titleTextStyle!.fontWeight, FontWeight.w600);
    });
  });

  group('AppDesignComponents.elevatedButtonTheme', () {
    test('uses brand gold background and neutral900 text in both modes', () {
      final light = AppDesignComponents.elevatedButtonTheme(Brightness.light);
      final dark = AppDesignComponents.elevatedButtonTheme(Brightness.dark);

      for (final theme in [light, dark]) {
        final style = theme.style!;
        expect(style.elevation?.resolve({}), 0);
        expect(style.backgroundColor?.resolve({}), AppDesignTokens.brandGold);
        expect(style.foregroundColor?.resolve({}), AppDesignTokens.neutral900);
        expect(style.minimumSize?.resolve({}), const Size(0, 56));
        expect(
          style.padding?.resolve({}),
          const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        );
      }
    });
  });

  group('AppDesignComponents.filledButtonTheme', () {
    test('uses brand gold background and neutral900 text in both modes', () {
      final light = AppDesignComponents.filledButtonTheme(Brightness.light);
      final dark = AppDesignComponents.filledButtonTheme(Brightness.dark);

      for (final theme in [light, dark]) {
        final style = theme.style!;
        expect(style.elevation?.resolve({}), 0);
        expect(style.backgroundColor?.resolve({}), AppDesignTokens.brandGold);
        expect(style.foregroundColor?.resolve({}), AppDesignTokens.neutral900);
        expect(style.minimumSize?.resolve({}), const Size(0, 56));
        expect(
          style.padding?.resolve({}),
          const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        );
      }
    });
  });

  group('AppDesignComponents.outlinedButtonTheme', () {
    test('light uses neutral900 foreground with brand gold border', () {
      final theme = AppDesignComponents.outlinedButtonTheme(Brightness.light);
      final style = theme.style!;

      expect(style.foregroundColor?.resolve({}), AppDesignTokens.neutral900);
      expect(
        style.side?.resolve({}),
        const BorderSide(color: AppDesignTokens.brandGoldDark, width: 1.4),
      );
      expect(style.minimumSize?.resolve({}), const Size(0, 50));
      expect(style.padding?.resolve({}), const EdgeInsets.symmetric(horizontal: 20, vertical: 12));
    });

    test('dark uses darkTextPrimary foreground with brand gold border', () {
      final theme = AppDesignComponents.outlinedButtonTheme(Brightness.dark);
      final style = theme.style!;

      expect(style.foregroundColor?.resolve({}), AppDesignTokens.darkTextPrimary);
      expect(
        style.side?.resolve({}),
        const BorderSide(color: AppDesignTokens.brandGoldLight, width: 1.4),
      );
      expect(style.minimumSize?.resolve({}), const Size(0, 50));
    });
  });

  group('AppDesignComponents.textButtonTheme', () {
    test('uses brand gold foreground in both modes', () {
      final light = AppDesignComponents.textButtonTheme(Brightness.light);
      final dark = AppDesignComponents.textButtonTheme(Brightness.dark);

      for (final theme in [light, dark]) {
        final style = theme.style!;
        expect(style.foregroundColor?.resolve({}), AppDesignTokens.brandGold);
      }
    });
  });

  group('AppDesignComponents.cardTheme', () {
    test('light uses white color and light shadow', () {
      final theme = AppDesignComponents.cardTheme(Brightness.light);

      expect(theme.elevation, 0);
      expect(theme.color, AppDesignTokens.neutralWhite);
      expect(theme.shadowColor, AppDesignTokens.lightShadow);
    });

    test('dark uses darkSurface color and dark shadow', () {
      final theme = AppDesignComponents.cardTheme(Brightness.dark);

      expect(theme.elevation, 0);
      expect(theme.color, AppDesignTokens.darkSurface);
      expect(theme.shadowColor, AppDesignTokens.darkShadow);
    });
  });

  group('AppDesignComponents.inputDecorationTheme', () {
    test('light uses white fill and neutral500 hint', () {
      final theme = AppDesignComponents.inputDecorationTheme(Brightness.light);

      expect(theme.filled, isTrue);
      expect(theme.fillColor, AppDesignTokens.neutralWhite);
      expect(theme.hintStyle!.color, AppDesignTokens.neutral500);
      expect(theme.contentPadding, const EdgeInsets.symmetric(horizontal: 16, vertical: 14));

      // enabled border uses neutral300
      final enabledBorder = theme.enabledBorder! as OutlineInputBorder;
      expect(enabledBorder.borderRadius, BorderRadius.circular(AppBorderRadius.lg));
      expect(
        enabledBorder.borderSide,
        const BorderSide(color: AppDesignTokens.neutral300, width: 1),
      );

      // focused border uses brand gold width 2
      final focusedBorder = theme.focusedBorder! as OutlineInputBorder;
      expect(
        focusedBorder.borderSide,
        const BorderSide(color: AppDesignTokens.brandGold, width: 2),
      );

      // error border uses error color
      final errorBorder = theme.errorBorder! as OutlineInputBorder;
      expect(errorBorder.borderSide, const BorderSide(color: AppDesignTokens.error));

      final focusedErrorBorder = theme.focusedErrorBorder! as OutlineInputBorder;
      expect(
        focusedErrorBorder.borderSide,
        const BorderSide(color: AppDesignTokens.error, width: 2),
      );
    });

    test('dark uses darkSurfaceAlt fill and darkTextTertiary hint', () {
      final theme = AppDesignComponents.inputDecorationTheme(Brightness.dark);

      expect(theme.filled, isTrue);
      expect(theme.fillColor, AppDesignTokens.darkSurfaceAlt);
      expect(theme.hintStyle!.color, AppDesignTokens.darkTextTertiary);
    });
  });

  group('AppDesignComponents.switchTheme', () {
    test('light thumb is brand gold when selected, neutral300 otherwise', () {
      final theme = AppDesignComponents.switchTheme(Brightness.light);

      expect(theme.thumbColor!.resolve({WidgetState.selected}), AppDesignTokens.brandGold);
      expect(theme.thumbColor!.resolve({}), AppDesignTokens.neutral300);
    });

    test('dark thumb is brand gold when selected, darkTextTertiary otherwise', () {
      final theme = AppDesignComponents.switchTheme(Brightness.dark);

      expect(theme.thumbColor!.resolve({WidgetState.selected}), AppDesignTokens.brandGold);
      expect(theme.thumbColor!.resolve({}), AppDesignTokens.darkTextTertiary);
    });

    test('light track is brand gold tinted when selected', () {
      final theme = AppDesignComponents.switchTheme(Brightness.light);

      expect(
        theme.trackColor!.resolve({WidgetState.selected}),
        AppDesignTokens.brandGold.withValues(alpha: 0.32),
      );
      expect(theme.trackColor!.resolve({}), AppDesignTokens.neutral300.withValues(alpha: 0.5));
    });

    test('dark track is brand gold tinted when selected', () {
      final theme = AppDesignComponents.switchTheme(Brightness.dark);

      expect(
        theme.trackColor!.resolve({WidgetState.selected}),
        AppDesignTokens.brandGold.withValues(alpha: 0.32),
      );
      expect(
        theme.trackColor!.resolve({}),
        AppDesignTokens.darkTextTertiary.withValues(alpha: 0.24),
      );
    });
  });
}
