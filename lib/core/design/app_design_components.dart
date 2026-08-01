import 'package:flutter/material.dart';
import 'package:ghar360/core/design/app_design_tokens.dart';
import 'package:ghar360/core/utils/app_spacing.dart';
import 'package:google_fonts/google_fonts.dart';

class AppDesignComponents {
  AppDesignComponents._();

  static TextTheme textTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final Color primary = isDark ? AppDesignTokens.darkTextPrimary : AppDesignTokens.neutral900;
    final Color secondary = isDark ? AppDesignTokens.darkTextSecondary : AppDesignTokens.neutral500;
    final Color tertiary = isDark ? AppDesignTokens.darkTextTertiary : AppDesignTokens.neutral500;

    final base = isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme;

    final text = GoogleFonts.manropeTextTheme(base).copyWith(
      bodyLarge: TextStyle(color: primary, fontSize: 16, height: 1.6),
      bodyMedium: TextStyle(color: secondary, fontSize: 14, height: 1.55),
      bodySmall: TextStyle(color: tertiary, fontSize: 12, height: 1.45),
      labelLarge: TextStyle(color: primary, fontSize: 14, fontWeight: FontWeight.w700, height: 1.2),
      labelMedium: TextStyle(
        color: primary,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
      labelSmall: TextStyle(color: primary, fontSize: 11, fontWeight: FontWeight.w700, height: 1.2),
      titleLarge: TextStyle(
        color: primary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
      titleMedium: TextStyle(
        color: primary,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
      titleSmall: TextStyle(
        color: primary,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
    );

    return text.copyWith(
      displayLarge: GoogleFonts.sora(
        color: primary,
        fontSize: 34,
        fontWeight: FontWeight.w700,
        height: 1.1,
        letterSpacing: -0.7,
      ),
      displayMedium: GoogleFonts.sora(
        color: primary,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.14,
        letterSpacing: -0.45,
      ),
      displaySmall: GoogleFonts.sora(
        color: primary,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.18,
        letterSpacing: -0.3,
      ),
      headlineLarge: GoogleFonts.sora(
        color: primary,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
      headlineMedium: GoogleFonts.sora(
        color: primary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
      headlineSmall: GoogleFonts.sora(
        color: primary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
    );
  }

  static AppBarTheme appBarTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final Color bg = isDark ? AppDesignTokens.darkSurface : AppDesignTokens.neutralWhite;
    final Color fg = isDark ? AppDesignTokens.darkTextPrimary : AppDesignTokens.neutral900;

    return AppBarTheme(
      backgroundColor: bg,
      foregroundColor: fg,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: fg),
      titleTextStyle: GoogleFonts.sora(color: fg, fontSize: 20, fontWeight: FontWeight.w600),
    );
  }

  static ElevatedButtonThemeData elevatedButtonTheme(Brightness brightness) {
    final Color textColor = AppDesignTokens.neutral900;
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: AppDesignTokens.brandGold,
        foregroundColor: textColor,
        disabledBackgroundColor: AppDesignTokens.brandGold.withValues(alpha: 0.55),
        minimumSize: const Size(0, 56),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorderRadius.lg)),
      ),
    );
  }

  static FilledButtonThemeData filledButtonTheme(Brightness brightness) {
    final Color textColor = AppDesignTokens.neutral900;
    return FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0,
        backgroundColor: AppDesignTokens.brandGold,
        foregroundColor: textColor,
        minimumSize: const Size(0, 56),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorderRadius.lg)),
      ),
    );
  }

  static OutlinedButtonThemeData outlinedButtonTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final Color fg = isDark ? AppDesignTokens.darkTextPrimary : AppDesignTokens.neutral900;
    final Color border = isDark ? AppDesignTokens.brandGoldLight : AppDesignTokens.brandGoldDark;

    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: fg,
        side: BorderSide(color: border, width: 1.4),
        minimumSize: const Size(0, 50),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorderRadius.button)),
      ),
    );
  }

  static TextButtonThemeData textButtonTheme(Brightness brightness) {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppDesignTokens.brandGold,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorderRadius.button)),
      ),
    );
  }

  static CardThemeData cardTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    return CardThemeData(
      elevation: 0,
      color: isDark ? AppDesignTokens.darkSurface : AppDesignTokens.neutralWhite,
      shadowColor: isDark ? AppDesignTokens.darkShadow : AppDesignTokens.lightShadow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorderRadius.card)),
    );
  }

  static InputDecorationTheme inputDecorationTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final Color fill = isDark ? AppDesignTokens.darkSurfaceAlt : AppDesignTokens.neutralWhite;
    final Color border = AppDesignTokens.neutral300;
    final Color hint = isDark ? AppDesignTokens.darkTextTertiary : AppDesignTokens.neutral500;

    return InputDecorationTheme(
      filled: true,
      fillColor: fill,
      hintStyle: TextStyle(color: hint),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        borderSide: BorderSide(color: border, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        borderSide: BorderSide(color: border, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        borderSide: const BorderSide(color: AppDesignTokens.brandGold, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        borderSide: const BorderSide(color: AppDesignTokens.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        borderSide: const BorderSide(color: AppDesignTokens.error, width: 2),
      ),
    );
  }

  static SwitchThemeData switchTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    return SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppDesignTokens.brandGold;
        }
        return isDark ? AppDesignTokens.darkTextTertiary : AppDesignTokens.neutral300;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppDesignTokens.brandGold.withValues(alpha: 0.32);
        }
        return isDark
            ? AppDesignTokens.darkTextTertiary.withValues(alpha: 0.24)
            : AppDesignTokens.neutral300.withValues(alpha: 0.5);
      }),
    );
  }
}
