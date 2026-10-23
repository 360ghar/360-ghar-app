@TestOn('mac-os')
library;

// The sign-in sheet on the Duo (right inset 84) and on an iPad: the title, copy
// and buttons are centered on the sheet, with the same margin on both sides.

import 'package:flutter/material.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/design/app_design_theme.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/widgets/common/sign_in_gate.dart';
import '../helpers/layout_variants.dart';
import '../helpers/load_app_fonts.dart';

class _Scope extends Fake implements StorageScope {
  @override
  String? get accountId => null;
}

class _Guest extends StorageScopeNotifier {
  @override
  StorageScope build() => _Scope();
}

void main() {
  setUpAll(loadAppFonts);

  for (final v in layoutVariants.where((v) => v.name != '375x667_split_third')) {
    testWidgets('sign_in_sheet_light_${v.name}', (tester) async {
      tester.view.physicalSize = v.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [storageScopeProvider.overrideWith(_Guest.new)],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppDesignTheme.light(),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) => MediaQuery(
              data: withInset(MediaQuery.of(context), v.padding),
              child: RepaintBoundary(key: const ValueKey('visual.screen'), child: child),
            ),
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => Center(
                  child: TextButton(
                    onPressed: () => requireAccount(context, ref, returnTo: '/'),
                    child: const Text('Act'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Act'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const ValueKey('visual.screen')),
        matchesGoldenFile('goldens/sign_in_sheet_light_${v.name}.png'),
      );
    });
  }
}
