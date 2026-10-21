import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/app_design_tokens.dart';
import 'package:ghar360/core/design/paper/paper_chrome.dart';
import 'package:ghar360/core/design/paper_page_transition.dart';
import 'package:ghar360/core/utils/app_spacing.dart';

/// The display face: Erode (ITF, Fontshare free licence), a warm serif for
/// headings, prices and big numbers; Hindi in it falls back to Noto Serif
/// Devanagari, which matches its stroke and serifs. Body text is Manrope with
/// Noto Sans Devanagari.
const kDisplayFont = 'Erode';
const kDisplayFallback = ['Noto Serif Devanagari'];
const kBodyFont = 'Manrope';
const kFontFallback = ['Noto Sans Devanagari'];

class AppDesignComponents {
  AppDesignComponents._();

  static AppPalette _palette(Brightness brightness) =>
      AppPalette(isDark: brightness == Brightness.dark);

  static TextStyle _display(Color color, double size, {FontWeight weight = FontWeight.w600}) =>
      TextStyle(
        fontFamily: kDisplayFont,
        fontFamilyFallback: kDisplayFallback,
        color: color,
        fontSize: size,
        fontWeight: weight,
        // Tall enough for Devanagari matras above and below; no negative tracking.
        height: 1.25,
      );

  static TextTheme textTheme(Brightness brightness) {
    final p = _palette(brightness);
    final base = brightness == Brightness.dark
        ? ThemeData.dark().textTheme
        : ThemeData.light().textTheme;
    final text = base
        .copyWith(
          bodyLarge: TextStyle(color: p.textPrimary, fontSize: 16, height: 1.55),
          bodyMedium: TextStyle(color: p.textSecondary, fontSize: 14, height: 1.5),
          bodySmall: TextStyle(color: p.textTertiary, fontSize: 12, height: 1.45),
          labelLarge: TextStyle(
            color: p.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
          labelMedium: TextStyle(
            color: p.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
          labelSmall: TextStyle(
            color: p.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
          titleLarge: TextStyle(
            color: p.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
          titleMedium: TextStyle(
            color: p.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
          titleSmall: TextStyle(
            color: p.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        )
        .apply(fontFamily: kBodyFont, fontFamilyFallback: kFontFallback);

    return text.copyWith(
      displayLarge: _display(p.textPrimary, 36),
      displayMedium: _display(p.textPrimary, 31),
      displaySmall: _display(p.textPrimary, 27),
      headlineLarge: _display(p.textPrimary, 25),
      headlineMedium: _display(p.textPrimary, 22),
      headlineSmall: _display(p.textPrimary, 19),
    );
  }

  static AppBarTheme appBarTheme(Brightness brightness) {
    final p = _palette(brightness);
    // The top of every screen sits on the sky; a list scrolling under it
    // never tints or lifts the bar.
    return AppBarTheme(
      backgroundColor: p.appBarBackground,
      foregroundColor: p.textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: p.textPrimary),
      titleTextStyle: _display(p.textPrimary, 20),
    );
  }

  static const _buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppBorderRadius.button)),
  );

  /// The one primary action: a flat marigold sheet. Hover and press change the
  /// colour only; the button never moves.
  static ButtonStyle _primary(Brightness brightness) => ButtonStyle(
    elevation: const WidgetStatePropertyAll(0),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return brightness == Brightness.dark ? AppDesignTokens.night600 : AppDesignTokens.ink200;
      }
      if (states.contains(WidgetState.pressed)) return AppDesignTokens.gold600;
      if (states.contains(WidgetState.hovered)) return AppDesignTokens.gold400;
      return AppDesignTokens.gold500;
    }),
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled)
          ? (brightness == Brightness.dark ? AppDesignTokens.nightText3 : AppDesignTokens.ink500)
          : AppDesignTokens.ink900,
    ),
    overlayColor: WidgetStateProperty.resolveWith(
      // Keep a visible keyboard focus cue; every other state stays flat.
      (states) => states.contains(WidgetState.focused)
          ? AppDesignTokens.ink900.withValues(alpha: 0.14)
          : Colors.transparent,
    ),
    minimumSize: const WidgetStatePropertyAll(Size(0, 52)),
    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 22, vertical: 14)),
    shape: const WidgetStatePropertyAll(_buttonShape),
    textStyle: const WidgetStatePropertyAll(
      TextStyle(
        fontFamily: kBodyFont,
        fontFamilyFallback: kFontFallback,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  static ElevatedButtonThemeData elevatedButtonTheme(Brightness brightness) =>
      ElevatedButtonThemeData(style: _primary(brightness));

  static FilledButtonThemeData filledButtonTheme(Brightness brightness) =>
      FilledButtonThemeData(style: _primary(brightness));

  /// A second action is a pale slip with ink text, not an outline.
  static OutlinedButtonThemeData outlinedButtonTheme(Brightness brightness) {
    final p = _palette(brightness);
    return OutlinedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.pressed) || states.contains(WidgetState.hovered)
              ? (p.isDark ? AppDesignTokens.night600 : const Color(0xFFD3E8E1))
              : p.slip,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled) ? p.textTertiary : p.textPrimary,
        ),
        overlayColor: WidgetStateProperty.resolveWith(
          // Keep a visible keyboard focus cue; every other state stays flat.
          (states) => states.contains(WidgetState.focused)
              ? p.textPrimary.withValues(alpha: 0.14)
              : Colors.transparent,
        ),
        side: const WidgetStatePropertyAll(BorderSide.none),
        minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 18, vertical: 12)),
        shape: const WidgetStatePropertyAll(_buttonShape),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(
            fontFamily: kBodyFont,
            fontFamilyFallback: kFontFallback,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  static TextButtonThemeData textButtonTheme(Brightness brightness) {
    final p = _palette(brightness);
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.textPrimary,
        minimumSize: const Size(48, 44),
        textStyle: const TextStyle(
          fontFamily: kBodyFont,
          fontFamilyFallback: kFontFallback,
          fontWeight: FontWeight.w700,
        ),
        shape: _buttonShape,
      ),
    );
  }

  static CardThemeData cardTheme(Brightness brightness) {
    final p = _palette(brightness);
    return CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.card),
        side: BorderSide(color: p.border),
      ),
    );
  }

  static InputDecorationTheme inputDecorationTheme(Brightness brightness) {
    final p = _palette(brightness);
    OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppBorderRadius.input),
      borderSide: BorderSide(color: color, width: width),
    );
    return InputDecorationTheme(
      filled: true,
      fillColor: p.inputBackground,
      hintStyle: TextStyle(color: p.textTertiary),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: border(p.fieldBorder),
      enabledBorder: border(p.fieldBorder),
      // Focus passes 3:1 against the field: peacock teal in both themes.
      focusedBorder: border(p.accent, 2),
      errorBorder: border(p.error),
      focusedErrorBorder: border(p.error, 2),
      errorStyle: TextStyle(color: p.error, fontSize: 12.5, height: 1.3),
    );
  }

  /// Rows on a white sheet: a bare teal icon, a bold title, a quiet subtitle.
  static ListTileThemeData listTileTheme(Brightness brightness) {
    final p = _palette(brightness);
    return ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      minVerticalPadding: 10,
      iconColor: p.accent,
      textColor: p.textPrimary,
      titleTextStyle: TextStyle(
        fontFamily: kBodyFont,
        fontFamilyFallback: kFontFallback,
        color: p.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.3,
      ),
      subtitleTextStyle: TextStyle(
        fontFamily: kBodyFont,
        fontFamilyFallback: kFontFallback,
        color: p.textSecondary,
        fontSize: 14,
        height: 1.4,
      ),
    );
  }

  /// An expanding row (FAQ) on a sheet: no rule above or below it, open or
  /// closed; the chevron is teal.
  static ExpansionTileThemeData expansionTileTheme(Brightness brightness) {
    final p = _palette(brightness);
    return ExpansionTileThemeData(
      backgroundColor: Colors.transparent,
      collapsedBackgroundColor: Colors.transparent,
      iconColor: p.accent,
      collapsedIconColor: p.accent,
      textColor: p.textPrimary,
      collapsedTextColor: p.textPrimary,
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      expandedAlignment: AlignmentDirectional.centerStart,
      shape: const Border(),
      collapsedShape: const Border(),
    );
  }

  /// iOS and macOS keep the Cupertino slide and its back swipe. Everywhere
  /// else (Android, web on non-Apple devices, desktop) the paper slide. On
  /// the web, Flutter reads the platform from the browser.
  static const pageTransitionsTheme = PageTransitionsTheme(
    builders: {
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.android: PaperSlideTransitionsBuilder(),
      TargetPlatform.fuchsia: PaperSlideTransitionsBuilder(),
      TargetPlatform.linux: PaperSlideTransitionsBuilder(),
      TargetPlatform.windows: PaperSlideTransitionsBuilder(),
    },
  );

  static SwitchThemeData switchTheme(Brightness brightness) {
    final p = _palette(brightness);
    return SwitchThemeData(
      // On is teal: a chosen state, not an action.
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? (p.isDark ? AppDesignTokens.night900 : AppDesignTokens.paper)
            : p.fieldBorder,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? p.accent : p.raised,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? p.accent : p.fieldBorder,
      ),
    );
  }

  /// Dialogs and bottom sheets are hand-cut sheets with a short shadow.
  static DialogThemeData dialogTheme(Brightness brightness) {
    final p = _palette(brightness);
    return DialogThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: CutBorder(
        seed: 'dialog',
        shadows: paperShadows(PaperElevation.high, p.shadowOn(p.background)),
      ),
      titleTextStyle: _display(p.textPrimary, 21),
      contentTextStyle: TextStyle(
        fontFamily: kBodyFont,
        fontFamilyFallback: kFontFallback,
        color: p.textSecondary,
        fontSize: 15,
        height: 1.5,
      ),
    );
  }

  static BottomSheetThemeData bottomSheetTheme(Brightness brightness) {
    final p = _palette(brightness);
    return BottomSheetThemeData(
      backgroundColor: p.surface,
      modalBackgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      modalElevation: 0,
      showDragHandle: false,
      shape: CutBorder(
        seed: 'sheet',
        amp: 3,
        shadows: paperShadows(PaperElevation.high, p.shadowOn(p.background)),
      ),
    );
  }

  static ProgressIndicatorThemeData progressTheme(Brightness brightness) {
    final p = _palette(brightness);
    return ProgressIndicatorThemeData(
      color: p.accent,
      linearTrackColor: p.slip,
      circularTrackColor: Colors.transparent,
    );
  }
}
