import 'package:flutter/material.dart';

import 'package:ghar360/core/design/app_design_components.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/app_design_tokens.dart';
import 'package:ghar360/core/utils/app_spacing.dart';

class AppDesignTheme {
  AppDesignTheme._();

  static const Duration defaultTransitionDuration = AppDurations.normal;
  static const Curve defaultTransitionCurve = AppCurves.standard;

  static ThemeData light() => _theme(Brightness.light);
  static ThemeData dark() => _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final p = AppPalette(isDark: brightness == Brightness.dark);
    final colorScheme = ColorScheme(
      brightness: brightness,
      // Material paints chosen states with primary (cursor, focused label, sliders,
      // checkboxes, radios, pickers), so primary is the teal accent. Gold is set
      // on the action buttons only; on white it is 1.8:1, too faint for a control.
      primary: p.accent,
      onPrimary: p.isDark ? AppDesignTokens.ink900 : AppDesignTokens.paper,
      secondary: p.accent,
      onSecondary: p.isDark ? AppDesignTokens.ink900 : AppDesignTokens.paper,
      surface: p.surface,
      onSurface: p.textPrimary,
      onSurfaceVariant: p.textSecondary,
      surfaceContainerHighest: p.raised,
      error: p.error,
      onError: p.isDark ? AppDesignTokens.ink900 : AppDesignTokens.paper,
      outline: p.fieldBorder,
      outlineVariant: p.border,
      shadow: p.shadowOn(p.background),
      surfaceTint: Colors.transparent,
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: kBodyFont,
      fontFamilyFallback: kFontFallback,
      brightness: brightness,
      scaffoldBackgroundColor: p.background,
      canvasColor: p.background,
      colorScheme: colorScheme,
      splashFactory: NoSplash.splashFactory,
      textTheme: AppDesignComponents.textTheme(brightness),
      appBarTheme: AppDesignComponents.appBarTheme(brightness),
      elevatedButtonTheme: AppDesignComponents.elevatedButtonTheme(brightness),
      filledButtonTheme: AppDesignComponents.filledButtonTheme(brightness),
      outlinedButtonTheme: AppDesignComponents.outlinedButtonTheme(brightness),
      textButtonTheme: AppDesignComponents.textButtonTheme(brightness),
      inputDecorationTheme: AppDesignComponents.inputDecorationTheme(brightness),
      cardTheme: AppDesignComponents.cardTheme(brightness),
      listTileTheme: AppDesignComponents.listTileTheme(brightness),
      expansionTileTheme: AppDesignComponents.expansionTileTheme(brightness),
      pageTransitionsTheme: AppDesignComponents.pageTransitionsTheme,
      switchTheme: AppDesignComponents.switchTheme(brightness),
      dialogTheme: AppDesignComponents.dialogTheme(brightness),
      bottomSheetTheme: AppDesignComponents.bottomSheetTheme(brightness),
      progressIndicatorTheme: AppDesignComponents.progressTheme(brightness),
      dividerTheme: DividerThemeData(color: p.divider, thickness: 1, space: 1),
      // Tabs are marked by the indicator under the chosen label, not a full-width rule.
      tabBarTheme: TabBarThemeData(dividerHeight: 0, indicatorColor: p.accent),
    );
  }
}
