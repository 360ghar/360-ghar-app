import 'package:flutter/material.dart';

import 'package:ghar360/core/design/app_design_theme.dart';
import 'package:ghar360/core/design/app_design_tokens.dart';
import 'package:ghar360/core/design/paper/paper_art.dart';
import 'package:ghar360/core/design/paper/paper_chrome.dart';

typedef _T = AppDesignTokens;

/// Theme colours. Every screen sits on one page tone, the onboarding sky
/// ([background]); content sits on white card-stock sheets ([surface]).
/// At night the same: a deep teal sky with green-black sheets.
class AppPalette {
  const AppPalette({required this.isDark});

  final bool isDark;

  /// The page: the sky of the onboarding scenes, equal to `tone(PaperTone.sky)`
  /// so a scene header meets the page without a seam.
  Color get background => isDark ? _T.night900 : _T.sky;

  /// A card-stock sheet on the page: lists, cards, the navigation strip.
  Color get surface => isDark ? _T.night800 : _T.paper;

  /// A field or a pressed row on a sheet. White by day; a step above the
  /// sheet at night.
  Color get raised => isDark ? _T.night700 : _T.paper;
  Color get cardBackground => surface;

  /// The top edge of a sheet: at night a 1 px lighter lip of the sheet's own
  /// colour, where the light catches the cut; by day the decorative border.
  Color get sheetLip => isDark ? const Color(0xFF2E403C) : border;

  /// An unselected folder tab: the sheet mixed toward the page, so it reads
  /// as card stock behind the selected tab. Secondary text on it passes AA.
  Color get tabBehind => Color.lerp(surface, background, 0.5)!;

  Color get textPrimary => isDark ? _T.nightText : _T.ink900;
  Color get textSecondary => isDark ? _T.nightText2 : _T.ink600;
  Color get textTertiary => isDark ? _T.nightText3 : _T.ink500;

  /// Decorative edges. Field borders use [fieldBorder], which passes 3:1.
  Color get border => isDark ? _T.night600 : _T.ink200;
  Color get fieldBorder => isDark ? _T.nightBorder : _T.ink400;
  Color get divider => border;
  Color get inputBackground => raised;

  /// A mint slip under a selected row, tab or chip, or a quiet button.
  /// Text on it stays ink.
  Color get slip => isDark ? _T.nightSlip : _T.mint50;

  /// Peacock teal for what is chosen or tappable: icons, links, the selected
  /// tab. Never a large fill; the one filled action is marigold.
  Color get accent => isDark ? _T.teal300 : _T.teal700;

  /// A quiet amber slip under a caution note (a failed refresh over kept
  /// content). Text on it stays ink.
  Color get notice => isDark ? const Color(0xFF2A2616) : const Color(0xFFFFF4D1);

  /// Shadow colour for BoxShadows. Prefer [paperShadows] with [shadowOn].
  Color get shadow => shadowOn(background).withValues(alpha: 0.16);

  /// The top of every screen sits on the sky.
  Color get appBarBackground => background;
  Color get appBarText => textPrimary;
  Color get appBarIcon => textPrimary;

  Color get navigationBackground => surface;
  Color get navigationUnselected => textSecondary;

  Color get buttonPrimary => _T.gold500;
  Color get buttonPrimaryText => _T.ink900;
  Color get buttonSecondaryBackground => raised;
  Color get buttonSecondaryText => textPrimary;

  Color get success => isDark ? _T.leafNight : _T.leaf;
  Color get warning => isDark ? _T.warnNight : _T.warn;
  Color get error => isDark ? _T.chiliNight : _T.chili;

  /// The saved heart.
  Color get favoriteActive => isDark ? _T.brick300 : _T.brick600;
  Color get favoriteInactive => textTertiary;
  List<BoxShadow> get cardShadow => paperShadows(PaperElevation.low, shadowOn(background));

  /// The tint a sheet's shadow takes from the surface below it.
  Color shadowOn(Color below) =>
      Color.lerp(below, isDark ? _T.shadowNight : _T.shadowDay, isDark ? 0.85 : 0.9)!;

  /// Grain colour for paper backgrounds.
  Color get grain => isDark ? const Color(0x0FE6F2EE) : const Color(0x0B15201D);

  Color tone(PaperTone tone) => (isDark ? _nightTones : _dayTones)[tone]!;

  PaperInks get inks => PaperInks(
    tone: tone,
    shadow: isDark ? _T.shadowNight : _T.shadowDay,
    lit: isDark ? _T.gold500 : null,
  );
}

// Paper-art card stock. By day: a mint haze sky, hazy teal towers, sandstone
// blocks, terracotta and brick, neem greens, marigold, sindoor for the pin.
// At night the same papers under a deep teal sky, with gold windows.
const _dayTones = {
  PaperTone.bg: Color(0xFFDDEFE9),
  PaperTone.sun: _T.gold500,
  PaperTone.sky: Color(0xFFDDEFE9),
  PaperTone.cloud: _T.paper,
  PaperTone.far: Color(0xFFA9D0C6),
  PaperTone.mid: Color(0xFFF1C48D),
  PaperTone.main: Color(0xFFE27A4E),
  PaperTone.deep: Color(0xFF26302D),
  PaperTone.near: Color(0xFF2F6B55),
  PaperTone.kerb: Color(0xFF3A413E),
  PaperTone.accent: _T.gold500,
  PaperTone.highlight: _T.paper,
  PaperTone.pin: Color(0xFFD6452C),
  PaperTone.home: _T.paper,
  PaperTone.lit: Color(0xFFFFD24D),
  PaperTone.grass: Color(0xFF8CC279),
  PaperTone.tree: Color(0xFF3E8A5F),
  PaperTone.sign: Color(0xFF1F7A70),
  PaperTone.pavement: Color(0xFFD9CDB8),
  PaperTone.shop: Color(0xFFC9623A),
  PaperTone.bloom: Color(0xFFE4572E),
  PaperTone.trunk: Color(0xFF6B4631),
  PaperTone.auto: Color(0xFF2F8F4E),
  PaperTone.cow: Color(0xFFF4EFE6),
  PaperTone.concrete: Color(0xFFD5DBD7),
};

const _nightTones = {
  PaperTone.bg: Color(0xFF0F2826),
  PaperTone.sun: Color(0xFFF2E6C4),
  PaperTone.sky: Color(0xFF0F2826),
  PaperTone.cloud: Color(0xFF1D3A37),
  PaperTone.far: Color(0xFF1A3935),
  PaperTone.mid: Color(0xFF4E3B2C),
  PaperTone.main: Color(0xFF6B3A26),
  PaperTone.deep: Color(0xFF070A09),
  PaperTone.near: Color(0xFF0E2520),
  PaperTone.kerb: Color(0xFF080B0A),
  PaperTone.accent: Color(0xFFE0A200),
  PaperTone.highlight: Color(0xFFE8E1CC),
  PaperTone.pin: Color(0xFFE4573C),
  PaperTone.home: Color(0xFF2B3431),
  PaperTone.lit: _T.gold400,
  PaperTone.grass: Color(0xFF1F4A33),
  PaperTone.tree: Color(0xFF153A2B),
  PaperTone.sign: Color(0xFF1F5A53),
  PaperTone.pavement: Color(0xFF2E2A22),
  PaperTone.shop: Color(0xFF5A2E1E),
  PaperTone.bloom: Color(0xFF7A2A1A),
  PaperTone.trunk: Color(0xFF2A1B12),
  PaperTone.auto: Color(0xFF1E5A35),
  PaperTone.cow: Color(0xFFBFB8A8),
  PaperTone.concrete: Color(0xFF2A3431),
};

extension AppDesignContext on BuildContext {
  AppPalette get design => Theme.of(this).brightness == Brightness.dark
      ? const AppPalette(isDark: true)
      : const AppPalette(isDark: false);
}

class AppDesign {
  AppDesign._();

  static const Color primaryYellow = _T.gold500;
  static const Color primaryYellowDark = _T.gold600;
  static const Color textDark = _T.ink900;
  static const Color darkTextPrimary = _T.nightText;

  /// Text and scrims over photographs.
  static const Color overlayLight = Color(0xFFFFFFFF);
  static const Color overlayDark = Color(0xFF000000);

  static const Color transparent = Colors.transparent;

  static const Duration defaultTransitionDuration = AppDesignTheme.defaultTransitionDuration;
  static const Curve defaultTransitionCurve = AppDesignTheme.defaultTransitionCurve;

  static ThemeData get lightTheme => AppDesignTheme.light();
  static ThemeData get darkTheme => AppDesignTheme.dark();

  static Color getTextColorForBackground(Color backgroundColor) =>
      backgroundColor.computeLuminance() > 0.5 ? textDark : darkTextPrimary;

  static Color getContrastColor(Color color) =>
      color.computeLuminance() > 0.5 ? _T.ink900 : _T.paper;
}
