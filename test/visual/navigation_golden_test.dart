@TestOn('mac-os')
library;

// The navigation strip and rail in both themes, at 390 px with the Discover tab chosen.

import 'package:flutter/material.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/design/app_design_theme.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/widgets/navigation/bottom_nav_bar.dart';
import '../helpers/layout_variants.dart';
import '../helpers/load_app_fonts.dart';

void main() {
  setUpAll(loadAppFonts);

  final cases = [
    for (final dark in [false, true])
      for (final rail in [false, true])
        (
          name: 'navigation_${rail ? 'rail' : 'bar'}_${dark ? 'dark' : 'light'}',
          dark: dark,
          rail: rail,
          size: rail ? const Size(260, 460) : const Size(390, 120),
          padding: EdgeInsets.zero,
        ),
    // The strip on a Duo outer display and a Split View third. Windows from 600
    // px show the rail, whose left edge is not touched by the Duo's right inset.
    for (final v in layoutVariants)
      if (v.size.width < 600)
        (
          name: 'navigation_bar_light_${v.name}',
          dark: false,
          rail: false,
          size: Size(v.size.width, 120),
          padding: v.padding,
        ),
  ];
  for (final c in cases) {
    {
      final (:name, :dark, :rail, :size, :padding) = c;
      testWidgets(name, (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final theme = dark ? AppDesignTheme.dark() : AppDesignTheme.light();
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) =>
                MediaQuery(data: withInset(MediaQuery.of(context), padding), child: child!),
            home: RepaintBoundary(
              key: const ValueKey('visual.nav'),
              child: Scaffold(
                body: rail
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          PaperNavigationRail(currentIndex: 1, onTap: (_) {}),
                          const Expanded(child: SizedBox()),
                        ],
                      )
                    : const SizedBox(),
                bottomNavigationBar: rail
                    ? null
                    : CustomBottomNavigationBar(currentIndex: 0, onTap: (_) {}),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(const ValueKey('visual.nav')),
          matchesGoldenFile('goldens/$name.png'),
        );
      });
    }
  }
}
