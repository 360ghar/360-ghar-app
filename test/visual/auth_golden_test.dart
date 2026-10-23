@TestOn('mac-os')
library;

import 'package:flutter/material.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/design/app_design_theme.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/features/auth/presentation/views/login_view.dart';
import 'package:ghar360/features/auth/presentation/views/phone_entry_view.dart';
import '../helpers/auth_form_harness.dart';
import '../helpers/layout_variants.dart';
import '../helpers/load_app_fonts.dart';

const _variants = [
  (
    name: '390_en_1x',
    size: Size(390, 844),
    locale: Locale('en', 'US'),
    scale: 1.0,
    padding: EdgeInsets.zero,
  ),
  (
    name: '320_hi_2x',
    size: Size(320, 844),
    locale: Locale('hi', 'IN'),
    scale: 2.0,
    padding: EdgeInsets.zero,
  ),
];

// Wide and Duo windows: light only.
final _layout = [
  for (final v in layoutVariants)
    (name: v.name, size: v.size, locale: const Locale('en', 'US'), scale: 1.0, padding: v.padding),
];

void main() {
  setUpAll(loadAppFonts);

  final screens = {
    'auth_phone_entry': () => const PhoneEntryView(),
    'auth_otp': () => LoginView(args: flowArgs(otp: true)),
  };

  for (final screen in screens.entries) {
    for (final dark in [false, true]) {
      for (final variant in [..._variants, if (!dark) ..._layout]) {
        final name = '${screen.key}_${dark ? 'dark' : 'light'}_${variant.name}';
        testWidgets(name, (tester) async {
          final h = AuthFormHarness();
          tester.view.physicalSize = variant.size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: h.container,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: dark ? AppDesignTheme.dark() : AppDesignTheme.light(),
                locale: variant.locale,
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                builder: (context, child) => MediaQuery(
                  data: withInset(
                    MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(variant.scale),
                      disableAnimations: true,
                    ),
                    variant.padding,
                  ),
                  child: child!,
                ),
                home: screen.value(),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 300));
          await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          h.close();
          await tester.pump(const Duration(minutes: 2));
        });
      }
    }
  }
}
