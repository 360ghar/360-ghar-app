// The navigation strip and rail in both themes, at 390 px with the Discover tab chosen.

import 'package:flutter/material.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/design/app_design_theme.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/widgets/navigation/bottom_nav_bar.dart';
import '../helpers/load_app_fonts.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final dark in [false, true]) {
    for (final rail in [false, true]) {
      final name = 'navigation_${rail ? 'rail' : 'bar'}_${dark ? 'dark' : 'light'}';
      testWidgets(name, (tester) async {
        tester.view.physicalSize = rail ? const Size(260, 460) : const Size(390, 120);
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
