import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:ghar360/core/translations/app_translations.dart';
import 'package:ghar360/features/discover/presentation/widgets/embedded_swipe_360_tour.dart';
import '../../../../helpers/getx_test_binding.dart';

void main() {
  setUp(() => GetxTestBinding.init());
  tearDown(() => GetxTestBinding.reset());

  Future<void> pumpWidget(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        fallbackLocale: const Locale('en', 'US'),
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('shows tour-unavailable error state for an invalid URL', (tester) async {
    // An empty/non-http URL is rejected by TourUrl.validate, so TourWebView
    // renders its error fallback without touching the WebView platform plugin.
    await pumpWidget(tester, const SizedBox(height: 400, child: EmbeddedSwipe360Tour(tourUrl: '')));
    await tester.pump();

    expect(find.text('360° Tour Unavailable'), findsOneWidget);
    expect(find.text('Virtual tour could not be loaded'), findsOneWidget);
  });

  testWidgets('shows tour-unavailable error state for a non-http scheme', (tester) async {
    await pumpWidget(
      tester,
      const SizedBox(height: 400, child: EmbeddedSwipe360Tour(tourUrl: 'javascript:alert(1)')),
    );
    await tester.pump();

    expect(find.text('360° Tour Unavailable'), findsOneWidget);
  });

  testWidgets('renders an error fallback (not a blank box) for ftp scheme', (tester) async {
    await pumpWidget(
      tester,
      const SizedBox(height: 400, child: EmbeddedSwipe360Tour(tourUrl: 'ftp://example.com/tour')),
    );
    await tester.pump();

    expect(find.byIcon(Icons.public_off), findsOneWidget);
  });
}
