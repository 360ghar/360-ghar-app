@TestOn('mac-os')
library;

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/design/app_design_theme.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/features/splash/presentation/views/splash_view.dart';
import 'package:ghar360/features/splash/presentation/widgets/gurugram_diorama.dart';
import '../helpers/load_app_fonts.dart';
import '../helpers/provider_test_app.dart';
import '../helpers/settings_test_database.dart';

const _variants = [
  (name: '390_en_1x', size: Size(390, 844), locale: Locale('en', 'US'), scale: 1.0),
  (name: '320_hi_2x', size: Size(320, 844), locale: Locale('hi', 'IN'), scale: 2.0),
];

void main() {
  setUpAll(loadAppFonts);

  for (final dark in [false, true]) {
    for (final variant in _variants) {
      for (final page in [0.0, 0.5, 1.0, 2.0]) {
        final name =
            'onboarding_p${page.toString().replaceAll('.', '_')}_${dark ? 'dark' : 'light'}_${variant.name}';
        testWidgets(name, (tester) async {
          tester.view.physicalSize = variant.size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpProviderApp(
            const SplashView(),
            overrides: [
              appDatabaseProvider.overrideWithValue(SettingsTestDatabase()),
              gyroscopeProvider.overrideWithValue(const Stream.empty()),
            ],
            locale: variant.locale,
            textScale: variant.scale,
            theme: dark ? AppDesignTheme.dark() : AppDesignTheme.light(),
          );
          await tester.pumpAndSettle();
          final pages = tester.widget<PageView>(find.byType(PageView)).controller!;
          final width = pages.position.viewportDimension;
          TestGesture? held;
          if (page == page.roundToDouble()) {
            pages.jumpTo(width * page);
            // A whole page settles and plays its ambient moment to rest.
            await tester.pumpAndSettle();
          } else {
            // Hold the swipe half way, so the next layers are mid-fold.
            held = await tester.startGesture(Offset(width * 0.8, 300));
            for (var i = 0; i < 10; i++) {
              await held.moveBy(Offset(-width * page / 10, 0));
              await tester.pump(const Duration(milliseconds: 16));
            }
          }
          await expectLater(
            find.byKey(const ValueKey('qa.splash.screen')),
            matchesGoldenFile('goldens/$name.png'),
          );
          await held?.up();
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
