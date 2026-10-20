import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/design/app_design_components.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/app_design_theme.dart';
import 'package:ghar360/core/design/app_design_tokens.dart';
import 'package:ghar360/core/design/paper/paper_art.dart';
import 'package:ghar360/core/design/paper/paper_chrome.dart';
import 'package:ghar360/core/design/paper_page_transition.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
}

void main() {
  for (final isDark in [false, true]) {
    final p = AppPalette(isDark: isDark);
    final theme = isDark ? 'night' : 'day';

    test('$theme text pairs pass WCAG AA on the page, the sheet, fields and tabs', () {
      for (final surface in [p.background, p.surface, p.raised, p.tabBehind]) {
        for (final text in [
          p.textPrimary,
          p.textSecondary,
          p.textTertiary,
          p.error,
          p.success,
          p.warning,
          p.accent,
        ]) {
          expect(_contrast(text, surface), greaterThanOrEqualTo(4.5), reason: '$text on $surface');
        }
        expect(_contrast(p.fieldBorder, surface), greaterThanOrEqualTo(3));
      }
      // Text on the mint and amber slips stays ink; teal links and the caution icon stay legible.
      for (final slip in [p.slip, p.notice]) {
        for (final text in [p.textPrimary, p.textSecondary, p.accent]) {
          expect(_contrast(text, slip), greaterThanOrEqualTo(4.5), reason: '$text on $slip');
        }
        expect(_contrast(p.warning, slip), greaterThanOrEqualTo(3), reason: 'caution icon');
      }
      // The saved heart stands out from the page.
      expect(_contrast(p.favoriteActive, p.background), greaterThanOrEqualTo(3));
      expect(_contrast(p.buttonPrimaryText, p.buttonPrimary), greaterThanOrEqualTo(4.5));
    });

    test('$theme pages sit on the sky and content on card-stock sheets', () {
      expect(p.background, p.tone(PaperTone.sky), reason: 'a scene header meets the page');
      expect(p.appBarBackground, p.background);
      expect(p.navigationBackground, p.surface);
      expect(p.surface, isNot(p.background));
      expect(p.inputBackground, p.raised);
      // A sheet reads against the page; an unselected tab sits between the two.
      final page = p.background.computeLuminance();
      final sheet = p.surface.computeLuminance();
      final tab = p.tabBehind.computeLuminance();
      expect(tab, inExclusiveRange(page < sheet ? page : sheet, page < sheet ? sheet : page));
      if (isDark) {
        expect(p.sheetLip.computeLuminance(), greaterThan(sheet), reason: 'the lip catches light');
      }
    });

    test('$theme gives every paper tone a colour', () {
      for (final tone in PaperTone.values) {
        expect(p.tone(tone), isA<Color>());
      }
      expect(p.inks.lit == null, !isDark, reason: 'windows light only at night');
    });

    test('$theme shadows take a darker tint of the surface below', () {
      final tint = p.shadowOn(p.surface);
      expect(tint.computeLuminance(), lessThan(p.surface.computeLuminance()));
      expect(p.cardShadow, paperShadows(PaperElevation.low, p.shadowOn(p.background)));
    });
  }

  testWidgets('context.design follows the theme brightness', (tester) async {
    late AppPalette light, dark;
    await tester.pumpWidget(
      Theme(
        data: AppDesignTheme.light(),
        child: Builder(builder: (c) => (light = c.design, const SizedBox()).$2),
      ),
    );
    await tester.pumpWidget(
      Theme(
        data: AppDesignTheme.dark(),
        child: Builder(builder: (c) => (dark = c.design, const SizedBox()).$2),
      ),
    );
    expect(light.isDark, isFalse);
    expect(dark.isDark, isTrue);
  });

  for (final theme in [AppDesignTheme.light(), AppDesignTheme.dark()]) {
    final name = theme.brightness.name;

    test('$name type: Erode display with serif Devanagari, Manrope body with sans Devanagari', () {
      final text = theme.textTheme;
      for (final style in [
        text.displayLarge,
        text.headlineMedium,
        theme.appBarTheme.titleTextStyle,
      ]) {
        expect(style!.fontFamily, kDisplayFont);
        expect(style.fontFamilyFallback, kDisplayFallback);
      }
      expect(text.bodyMedium!.fontFamily, kBodyFont);
      expect(text.bodyMedium!.fontFamilyFallback, kFontFallback);
      expect(text.displayLarge!.letterSpacing ?? 0, greaterThanOrEqualTo(0));
    });

    test('$name chosen states use teal: cursor, focus label, sliders, checks', () {
      final scheme = theme.colorScheme;
      final page = scheme.surface;
      expect(scheme.primary, isNot(AppDesignTokens.gold500));
      // Non-text contrast for a control is 3:1; the selected-day label on it is 4.5:1.
      expect(_contrast(scheme.primary, page), greaterThanOrEqualTo(3));
      expect(_contrast(scheme.onPrimary, scheme.primary), greaterThanOrEqualTo(4.5));
    });

    test('$name buttons: flat gold primary, tonal secondary without outline', () {
      final primary = theme.filledButtonTheme.style!;
      expect(primary.elevation!.resolve({}), 0);
      expect(primary.backgroundColor!.resolve({}), AppDesignTokens.gold500);
      expect(primary.backgroundColor!.resolve({WidgetState.pressed}), AppDesignTokens.gold600);
      expect(primary.foregroundColor!.resolve({}), AppDesignTokens.ink900);
      expect(
        theme.elevatedButtonTheme.style!.backgroundColor!.resolve({}),
        AppDesignTokens.gold500,
      );
      final secondary = theme.outlinedButtonTheme.style!;
      expect(secondary.side!.resolve({}), BorderSide.none);
      expect(secondary.backgroundColor!.resolve({}), isNot(AppDesignTokens.gold500));
    });

    test('$name dialogs and sheets are hand-cut', () {
      expect(theme.dialogTheme.shape, isA<CutBorder>());
      expect(theme.bottomSheetTheme.shape, isA<CutBorder>());
      expect(theme.dialogTheme.elevation, 0);
      expect(theme.splashFactory, NoSplash.splashFactory);
    });

    test('$name button labels keep the Devanagari fallback', () {
      for (final style in [
        theme.filledButtonTheme.style!,
        theme.elevatedButtonTheme.style!,
        theme.outlinedButtonTheme.style!,
        theme.textButtonTheme.style!,
      ]) {
        expect(style.textStyle!.resolve({})!.fontFamilyFallback, kFontFallback);
      }
    });

    test('$name bars sit on the page; rows and expanding rows draw no rules', () {
      final p = AppPalette(isDark: theme.brightness == Brightness.dark);
      expect(theme.scaffoldBackgroundColor, p.background);
      expect(theme.appBarTheme.backgroundColor, p.background);
      expect(theme.appBarTheme.scrolledUnderElevation, 0);
      expect(theme.appBarTheme.surfaceTintColor, Colors.transparent);
      expect(theme.inputDecorationTheme.fillColor, p.raised);
      expect(
        (theme.inputDecorationTheme.enabledBorder! as OutlineInputBorder).borderSide.color,
        p.fieldBorder,
      );
      expect(theme.listTileTheme.iconColor, p.accent);
      expect(theme.listTileTheme.titleTextStyle!.fontFamilyFallback, kFontFallback);
      expect(theme.expansionTileTheme.shape, const Border());
      expect(theme.expansionTileTheme.collapsedShape, const Border());
      expect(theme.expansionTileTheme.iconColor, p.accent);
    });

    test('$name page transitions: Cupertino on Apple platforms, the paper slide elsewhere', () {
      final builders = theme.pageTransitionsTheme.builders;
      for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
        expect(builders[platform], isA<CupertinoPageTransitionsBuilder>());
      }
      for (final platform in [
        TargetPlatform.android,
        TargetPlatform.fuchsia,
        TargetPlatform.linux,
        TargetPlatform.windows,
      ]) {
        expect(builders[platform], isA<PaperSlideTransitionsBuilder>());
      }
    });

    test('$name focus ring passes 3:1 on the field', () {
      final input = theme.inputDecorationTheme;
      final focus = (input.focusedBorder! as OutlineInputBorder).borderSide.color;
      expect(_contrast(focus, input.fillColor!), greaterThanOrEqualTo(3));
    });
  }

  group('paper slide', () {
    Future<void> push(WidgetTester tester, {bool still = false}) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          theme: AppDesignTheme.light().copyWith(platform: TargetPlatform.android),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: still),
            child: child!,
          ),
          home: const Scaffold(body: Text('old')),
        ),
      );
      navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('new'))),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
    }

    testWidgets('the new page slides over the old one; nothing fades', (tester) async {
      await push(tester);
      final incoming = tester.getTopLeft(find.text('new')).dx;
      expect(incoming, inExclusiveRange(0, 800));
      // The old page shifts toward the leading edge, at most a quarter.
      expect(tester.getTopLeft(find.text('old')).dx, inInclusiveRange(-200, 0));
      expect(find.byType(FadeTransition), findsNothing);
      // One short shadow, turned to the leading edge.
      final shadow =
          tester
                  .widget<DecoratedBox>(
                    find.ancestor(of: find.text('new'), matching: find.byType(DecoratedBox)).last,
                  )
                  .decoration
              as BoxDecoration;
      final p = const AppPalette(isDark: false);
      final paper = paperShadows(PaperElevation.mid, p.shadowOn(p.background));
      expect(shadow.boxShadow!.length, paper.length);
      for (final (index, cast) in shadow.boxShadow!.indexed) {
        expect(cast.offset, Offset(-paper[index].offset.dy, paper[index].offset.dy));
        expect(cast.spreadRadius, paper[index].spreadRadius);
        expect(cast.blurRadius, paper[index].blurRadius);
      }
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('new')).dx, 0);
    });

    testWidgets('reduced motion changes the page in one frame', (tester) async {
      await push(tester, still: true);
      expect(tester.getTopLeft(find.text('new')).dx, 0);
    });
  });

  test('contrast helpers pick readable ink', () {
    expect(AppDesign.getContrastColor(AppDesignTokens.gold500), AppDesignTokens.ink900);
    expect(AppDesign.getContrastColor(AppDesignTokens.night900), AppDesignTokens.paper);
    expect(AppDesign.getTextColorForBackground(AppDesignTokens.paper), AppDesign.textDark);
    expect(AppDesign.lightTheme.brightness, Brightness.light);
    expect(AppDesign.darkTheme.brightness, Brightness.dark);
  });
}
