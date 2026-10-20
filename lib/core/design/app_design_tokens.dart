import 'package:flutter/material.dart';

/// Fixed colour tokens. Screens use [AppPalette] through `context.design`;
/// see `docs/design-system.md` for the contrast of every text pair.
///
/// Three roles, three hues: marigold is the one action, peacock teal marks
/// what is chosen or tappable (icons, links, selected tabs), brick is the
/// saved heart. Everything else is neem ink on white card stock over the
/// onboarding sky, or paper at night under a deep teal sky.
class AppDesignTokens {
  AppDesignTokens._();

  // Marigold card stock. gold500 is the action colour.
  static const Color gold50 = Color(0xFFFFF7DB);
  static const Color gold100 = Color(0xFFFFEDB3);
  static const Color gold200 = Color(0xFFFFDF80);
  static const Color gold300 = Color(0xFFFFD04D);
  static const Color gold400 = Color(0xFFFFC934);
  static const Color gold500 = Color(0xFFF5B400);
  static const Color gold600 = Color(0xFFD69A00);
  static const Color gold700 = Color(0xFF9A6D00);
  static const Color gold800 = Color(0xFF7A5600);
  static const Color gold900 = Color(0xFF4A3400);

  // Paper by day: white sheets on the mint-haze sky, neem ink (a green-black,
  // never brown).
  static const Color paper = Color(0xFFFFFFFF);
  static const Color sky = Color(0xFFDDEFE9);
  static const Color ink900 = Color(0xFF182320);
  static const Color ink700 = Color(0xFF34423E);
  static const Color ink600 = Color(0xFF4B5955);
  static const Color ink500 = Color(0xFF5C6A66);
  static const Color ink400 = Color(0xFF73837F);
  static const Color ink200 = Color(0xFFDCE4E1);

  // Peacock teal: the chosen, the tappable. Mint is its tonal slip.
  static const Color teal700 = Color(0xFF0C6A61);
  static const Color teal300 = Color(0xFF5CC4B6);
  static const Color mint50 = Color(0xFFE6F2EE);

  // Brick: the saved heart.
  static const Color brick600 = Color(0xFFB03E22);
  static const Color brick300 = Color(0xFFF08A64);

  // Paper at night: green-black sheets under the night sky, cool light ink.
  static const Color night900 = Color(0xFF0F2826);
  static const Color night800 = Color(0xFF1C2F2B);
  static const Color night700 = Color(0xFF22372F);
  static const Color night600 = Color(0xFF2B3B37);
  static const Color nightSlip = Color(0xFF24423B);
  static const Color nightBorder = Color(0xFF7A8D87);
  static const Color nightText = Color(0xFFEDF3F0);
  static const Color nightText2 = Color(0xFFB6C5C0);
  static const Color nightText3 = Color(0xFF8FA29C);

  // Status. Day values pass AA on paper and mint; night values on night700.
  static const Color leaf = Color(0xFF1D7443);
  static const Color chili = Color(0xFFB42318);
  static const Color warn = Color(0xFF8A5A00);
  static const Color leafNight = Color(0xFF6FCF97);
  static const Color chiliNight = Color(0xFFFF8A7A);
  static const Color warnNight = Color(0xFFFFC934);

  // Shadow bases: a deep green by day, near-black at night.
  static const Color shadowDay = Color(0xFF15201D);
  static const Color shadowNight = Color(0xFF030605);
}
