import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/widgets/common/app_boot_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrap(Widget child) {
    return MaterialApp(
      localizationsDelegates: const [AppLocalizations.delegate],
      locale: const Locale('en', 'US'),
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );
  }

  testWidgets('renders logo asset and progress indicator', (tester) async {
    await tester.pumpWidget(wrap(const AppBootLoader(message: 'Starting...')));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Starting...'), findsOneWidget);
    expect(find.image(const AssetImage(AppBootLoader.logoAsset)), findsOneWidget);
  });

  testWidgets('dark theme uses the light mark on the night page tone', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        localizationsDelegates: const [AppLocalizations.delegate],
        locale: const Locale('en', 'US'),
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AppBootLoader(),
      ),
    );
    expect(find.image(const AssetImage(AppBootLoader.logoAssetDark)), findsOneWidget);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, const AppPalette(isDark: true).background);
  });

  testWidgets('shows retry after slow threshold', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      wrap(
        AppBootLoader(
          message: 'Loading...',
          slowThreshold: const Duration(milliseconds: 50),
          onRetry: () => retried = true,
        ),
      ),
    );

    expect(find.byKey(const ValueKey('qa.boot.retry')), findsNothing);

    // CircularProgressIndicator animates forever — use pump, not pumpAndSettle.
    await tester.pump(const Duration(milliseconds: 60));

    expect(find.byKey(const ValueKey('qa.boot.retry')), findsOneWidget);
    expect(find.textContaining('taking longer'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('qa.boot.retry')));
    await tester.pump();
    expect(retried, isTrue);
  });
}
