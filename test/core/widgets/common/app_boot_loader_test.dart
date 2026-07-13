import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:ghar360/core/translations/app_translations.dart';
import 'package:ghar360/core/widgets/common/app_boot_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.testMode = true;
    Get.reset();
  });

  tearDown(Get.reset);

  Widget wrap(Widget child) {
    return GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('en', 'US'),
      fallbackLocale: const Locale('en', 'US'),
      home: child,
    );
  }

  testWidgets('renders logo asset and progress indicator', (tester) async {
    await tester.pumpWidget(wrap(const AppBootLoader(message: 'Starting...')));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Starting...'), findsOneWidget);
    expect(find.image(const AssetImage(AppBootLoader.logoAsset)), findsOneWidget);
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
