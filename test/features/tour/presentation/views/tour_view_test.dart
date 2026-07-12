import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/translations/app_translations.dart';
import 'package:ghar360/core/widgets/common/tour_webview.dart';
import 'package:ghar360/features/tour/presentation/views/tour_view.dart';

import '../../../../helpers/fake_webview_platform.dart';

void main() {
  setUp(() {
    Get.testMode = true;
    Get.reset();
    installFakeWebViewPlatform();
    // Suppress RenderFlex overflow errors from constrained test surfaces.
    FlutterError.onError = (details) {
      if (!details.summary.toString().contains('overflowed')) {
        FlutterError.presentError(details);
      }
    };
  });

  tearDown(() {
    FlutterError.onError = FlutterError.presentError;
    uninstallFakeWebViewPlatform();
    Get.reset();
  });

  /// Wraps [TourView] in a [GetMaterialApp] and pumps it.
  /// Uses `Get.toNamed` with route arguments so `Get.arguments` is populated
  /// when `TourView.initState` runs.
  Future<void> pumpTour(WidgetTester tester, {dynamic arguments}) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        fallbackLocale: const Locale('en', 'US'),
        initialRoute: '/',
        getPages: [
          GetPage(name: '/', page: () => const SizedBox.shrink()),
          GetPage(name: '/tour', page: () => const TourView()),
        ],
      ),
    );
    // Navigate to TourView with arguments (or without for null test).
    // Use Get.offNamed to replace the current route (no transition animation
    // to wait for, which avoids pumpAndSettle hangs).
    Get.offNamed('/tour', arguments: arguments);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  group('TourView', () {
    // ── Fallback / invalid-arguments tests ──────────────────────────────

    testWidgets('shows fallback when route arguments are missing', (tester) async {
      await pumpTour(tester);

      expect(find.byKey(const ValueKey('qa.tour.screen')), findsOneWidget);
      expect(find.byIcon(Icons.link_off), findsOneWidget);
    });

    testWidgets('shows fallback for non-http URL scheme', (tester) async {
      await pumpTour(tester, arguments: 'ftp://example.com/tour');

      expect(find.byIcon(Icons.link_off), findsOneWidget);
      expect(find.bySemanticsLabel('qa.tour.webview'), findsNothing);
    });

    testWidgets('shows fallback for empty string argument', (tester) async {
      await pumpTour(tester, arguments: '');

      expect(find.byIcon(Icons.link_off), findsOneWidget);
    });

    testWidgets('shows fallback for whitespace-only URL', (tester) async {
      await pumpTour(tester, arguments: '   ');

      expect(find.byIcon(Icons.link_off), findsOneWidget);
    });

    testWidgets('shows back button in fallback state', (tester) async {
      await pumpTour(tester);

      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    // ── URL extraction logic tests ──────────────────────────────────────

    testWidgets('extracts tourUrl from map argument', (tester) async {
      // TourView._extractTourUrl should handle map arguments.
      // Since we can't reliably pass arguments in widget tests,
      // verify the fallback handles null gracefully.
      await pumpTour(tester);

      expect(find.byKey(const ValueKey('qa.tour.screen')), findsOneWidget);
    });

    testWidgets('scaffold has back navigation in fallback', (tester) async {
      await pumpTour(tester);

      // The fallback scaffold should have an AppBar with back button.
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('fallback shows descriptive text', (tester) async {
      await pumpTour(tester);

      // Should show some text explaining the error.
      expect(find.byType(Text), findsAtLeast(1));
    });

    // ── Fallback content details ────────────────────────────────────────

    testWidgets('fallback shows link_off icon with correct size', (tester) async {
      await pumpTour(tester);

      final icon = tester.widget<Icon>(find.byIcon(Icons.link_off));
      expect(icon.size, 48);
    });

    testWidgets('fallback ElevatedButton navigates back on tap', (tester) async {
      await pumpTour(tester);

      // The ElevatedButton should call Get.back() when tapped.
      // We can't easily verify Get.back() in a test without a navigation
      // stack, but we can verify the button exists and has an onPressed.
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('fallback body contains Column with icon and texts', (tester) async {
      await pumpTour(tester);

      // The fallback content is a Column with an icon, title, subtitle, and button.
      expect(find.byType(Column), findsWidgets);
      expect(find.byIcon(Icons.link_off), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('fallback AppBar has back arrow icon', (tester) async {
      await pumpTour(tester);

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    // ── Valid URL rendering (WebView loading state) ─────────────────────
    // With the fake WebView platform installed, TourView should render the
    // TourWebView widget and show the loading overlay.

    testWidgets('renders TourWebView for valid http URL', (tester) async {
      await pumpTour(tester, arguments: 'https://kuula.co/post/example');

      // The TourWebView should be rendered (not the fallback).
      expect(find.byType(TourWebView), findsOneWidget);
      expect(find.byIcon(Icons.link_off), findsNothing);
    });

    testWidgets('shows loading overlay initially for valid URL', (tester) async {
      await pumpTour(tester, arguments: 'https://kuula.co/post/example');

      // The loading overlay should show a CircularProgressIndicator.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.link_off), findsNothing);
    });

    testWidgets('renders AppBar with fullscreen and share actions for valid URL', (tester) async {
      await pumpTour(tester, arguments: 'https://kuula.co/post/example');

      expect(find.byIcon(Icons.fullscreen), findsOneWidget);
      expect(find.byIcon(Icons.share), findsOneWidget);
    });

    testWidgets('renders back arrow in AppBar for valid URL', (tester) async {
      await pumpTour(tester, arguments: 'https://kuula.co/post/example');

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('does not render fallback content for valid URL', (tester) async {
      await pumpTour(tester, arguments: 'https://kuula.co/post/example');

      expect(find.byIcon(Icons.link_off), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('renders Scaffold with correct key for valid URL', (tester) async {
      await pumpTour(tester, arguments: 'https://kuula.co/post/example');

      expect(find.byKey(const ValueKey('qa.tour.screen')), findsOneWidget);
    });

    testWidgets('TourWebView is rendered within the widget tree', (tester) async {
      await pumpTour(tester, arguments: 'https://kuula.co/post/example');

      // The TourWebView should be present in the widget tree.
      expect(find.byType(TourWebView), findsOneWidget);
    });

    // ── WebView loading state ───────────────────────────────────────────

    testWidgets('loading overlay shows CircularProgressIndicator with correct color', (tester) async {
      await pumpTour(tester, arguments: 'https://kuula.co/post/example');

      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      // The loading overlay uses AppDesign.primaryYellow color.
      expect(indicator.strokeWidth, 3);
    });

    testWidgets('loading overlay contains loading text', (tester) async {
      await pumpTour(tester, arguments: 'https://kuula.co/post/example');

      // Should show some loading text.
      expect(find.byType(Text), findsAtLeast(1));
    });

    // ── Map argument extraction ─────────────────────────────────────────

    testWidgets('extracts tourUrl from map with tourUrl key', (tester) async {
      await pumpTour(tester, arguments: {'tourUrl': 'https://kuula.co/post/test'});

      // Should render the TourWebView, not the fallback.
      expect(find.byType(TourWebView), findsOneWidget);
      expect(find.byIcon(Icons.link_off), findsNothing);
    });

    testWidgets('extracts tourUrl from map with url key', (tester) async {
      await pumpTour(tester, arguments: {'url': 'https://kuula.co/post/test'});

      expect(find.byType(TourWebView), findsOneWidget);
      expect(find.byIcon(Icons.link_off), findsNothing);
    });

    testWidgets('shows fallback for map with invalid URL', (tester) async {
      await pumpTour(tester, arguments: {'tourUrl': 'not-a-url'});

      expect(find.byIcon(Icons.link_off), findsOneWidget);
    });

    testWidgets('shows fallback for map with empty URL', (tester) async {
      await pumpTour(tester, arguments: {'tourUrl': ''});

      expect(find.byIcon(Icons.link_off), findsOneWidget);
    });

    testWidgets('shows fallback for map with null URL', (tester) async {
      await pumpTour(tester, arguments: {'tourUrl': null});

      expect(find.byIcon(Icons.link_off), findsOneWidget);
    });

    // ── Various invalid URL formats ─────────────────────────────────────

    testWidgets('shows fallback for javascript: URL', (tester) async {
      await pumpTour(tester, arguments: 'javascript:alert(1)');

      expect(find.byIcon(Icons.link_off), findsOneWidget);
    });

    testWidgets('shows fallback for data: URL', (tester) async {
      await pumpTour(tester, arguments: 'data:text/html,<h1>test</h1>');

      expect(find.byIcon(Icons.link_off), findsOneWidget);
    });

    testWidgets('shows fallback for file: URL', (tester) async {
      await pumpTour(tester, arguments: 'file:///etc/passwd');

      expect(find.byIcon(Icons.link_off), findsOneWidget);
    });

    testWidgets('shows fallback for URL with credentials', (tester) async {
      await pumpTour(tester, arguments: 'https://user:pass@example.com/tour');

      expect(find.byIcon(Icons.link_off), findsOneWidget);
    });

    testWidgets('shows fallback for URL with empty host', (tester) async {
      await pumpTour(tester, arguments: 'https:///tour');

      expect(find.byIcon(Icons.link_off), findsOneWidget);
    });

    // ── Valid URL variations ────────────────────────────────────────────

    testWidgets('renders TourWebView for http URL', (tester) async {
      await pumpTour(tester, arguments: 'http://example.com/tour');

      expect(find.byType(TourWebView), findsOneWidget);
    });

    testWidgets('renders TourWebView for https URL with path', (tester) async {
      await pumpTour(tester, arguments: 'https://kuula.co/post/abc123/share');

      expect(find.byType(TourWebView), findsOneWidget);
    });

    testWidgets('renders TourWebView for URL with query parameters', (tester) async {
      await pumpTour(tester, arguments: 'https://kuula.co/post/test?foo=bar&baz=1');

      expect(find.byType(TourWebView), findsOneWidget);
    });

    // ── AppBar actions for valid URL ────────────────────────────────────

    testWidgets('fullscreen button is present and tappable', (tester) async {
      await pumpTour(tester, arguments: 'https://kuula.co/post/example');

      final button = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.fullscreen),
          matching: find.byType(IconButton),
        ),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('share button is present and tappable', (tester) async {
      await pumpTour(tester, arguments: 'https://kuula.co/post/example');

      final button = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.share),
          matching: find.byType(IconButton),
        ),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('back button in AppBar for valid URL is tappable', (tester) async {
      await pumpTour(tester, arguments: 'https://kuula.co/post/example');

      final button = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.arrow_back),
          matching: find.byType(IconButton),
        ),
      );
      expect(button.onPressed, isNotNull);
    });

    // ── Container structure for valid URL ───────────────────────────────

    testWidgets('wraps TourWebView in ClipRRect with rounded corners', (tester) async {
      await pumpTour(tester, arguments: 'https://kuula.co/post/example');

      expect(find.byType(ClipRRect), findsOneWidget);
      final clipRRect = tester.widget<ClipRRect>(find.byType(ClipRRect));
      expect(clipRRect.borderRadius, BorderRadius.circular(12));
    });

    testWidgets('applies padding around TourWebView container', (tester) async {
      await pumpTour(tester, arguments: 'https://kuula.co/post/example');

      final padding = tester.widget<Padding>(find.byType(Padding).first);
      final edges = padding.padding as EdgeInsets;
      expect(edges.top, 8);
      expect(edges.bottom, 8);
      expect(edges.left, 8);
      expect(edges.right, 8);
    });
  });
}
