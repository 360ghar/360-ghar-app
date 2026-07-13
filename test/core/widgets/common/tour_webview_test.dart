import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/translations/app_translations.dart';
import 'package:ghar360/core/widgets/common/tour_webview.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../helpers/fake_webview_platform.dart';
import '../../../helpers/getx_test_binding.dart';

void main() {
  setUp(() {
    GetxTestBinding.init();
    installFakeWebViewPlatform();
  });
  tearDown(() {
    uninstallFakeWebViewPlatform();
    GetxTestBinding.reset();
  });

  // Suppress RenderFlex overflow errors from the loading/error column layouts.
  FlutterError.onError = (FlutterErrorDetails details) {
    if (!details.summary.toString().contains('overflowed')) {
      FlutterError.presentError(details);
    }
  };

  Future<void> pumpWidget(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        fallbackLocale: const Locale('en', 'US'),
        home: Scaffold(body: SizedBox(width: 400, height: 600, child: child)),
      ),
    );
  }

  group('invalid URL fallback', () {
    testWidgets('shows error fallback for an invalid (non-http) URL', (tester) async {
      await pumpWidget(tester, const TourWebView(tourUrl: 'not-a-url'));

      expect(find.byIcon(Icons.public_off), findsOneWidget);
      expect(find.text('360° Tour Unavailable'), findsOneWidget);
      expect(find.text('Virtual tour could not be loaded'), findsOneWidget);
    });

    testWidgets('shows error fallback for an empty URL', (tester) async {
      await pumpWidget(tester, const TourWebView(tourUrl: ''));

      expect(find.byIcon(Icons.public_off), findsOneWidget);
      expect(find.text('360° Tour Unavailable'), findsOneWidget);
    });

    testWidgets('shows error fallback for a javascript: URL', (tester) async {
      await pumpWidget(tester, const TourWebView(tourUrl: 'javascript:alert(1)'));

      expect(find.byIcon(Icons.public_off), findsOneWidget);
      expect(find.text('360° Tour Unavailable'), findsOneWidget);
    });

    testWidgets('returns SizedBox.shrink when showDefaultError is false and URL invalid', (
      tester,
    ) async {
      await pumpWidget(tester, const TourWebView(tourUrl: '', showDefaultError: false));

      expect(find.byIcon(Icons.public_off), findsNothing);
      expect(find.text('360° Tour Unavailable'), findsNothing);
    });

    testWidgets('calls onErrorChanged with true for an invalid URL', (tester) async {
      bool? errorState;
      await pumpWidget(
        tester,
        TourWebView(tourUrl: 'invalid', onErrorChanged: (hasError) => errorState = hasError),
      );

      expect(errorState, isTrue);
    });

    testWidgets('calls onLoadingChanged with false for an invalid URL', (tester) async {
      bool? loadingState;
      await pumpWidget(
        tester,
        TourWebView(tourUrl: 'invalid', onLoadingChanged: (isLoading) => loadingState = isLoading),
      );

      expect(loadingState, isFalse);
    });
  });

  group('valid URL success path', () {
    testWidgets('renders the WebView widget and loading overlay for a Kuula URL', (tester) async {
      await pumpWidget(tester, const TourWebView(tourUrl: 'https://kuula.co/share/test'));

      // The WebView placeholder is rendered.
      expect(find.byType(WebViewWidget), findsOneWidget);
      // Loading overlay is shown initially (default showDefaultLoading = true).
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading 360° Tour...'), findsOneWidget);
      // Loaded via HTML embed (Kuula is on the embed allowlist).
      expect(lastWebViewController?.loadHtmlStringCalls, 1);
      expect(lastWebViewController?.loadRequestCalls, 0);
      expect(lastWebViewController?.lastLoadedHtml, isNotNull);
    });

    testWidgets('uses loadRequest for a non-embed http(s) URL', (tester) async {
      await pumpWidget(tester, const TourWebView(tourUrl: 'https://example.com/tour'));

      expect(find.byType(WebViewWidget), findsOneWidget);
      expect(lastWebViewController?.loadRequestCalls, 1);
      expect(lastWebViewController?.loadHtmlStringCalls, 0);
      expect(lastWebViewController?.lastLoadedUri?.toString(), 'https://example.com/tour');
    });

    testWidgets('hides loading overlay when showDefaultLoading is false', (tester) async {
      await pumpWidget(
        tester,
        const TourWebView(tourUrl: 'https://kuula.co/share/test', showDefaultLoading: false),
      );

      expect(find.byType(WebViewWidget), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('onPageStarted sets loading true and onPageFinished sets loading false', (
      tester,
    ) async {
      final loadingStates = <bool>[];
      await pumpWidget(
        tester,
        TourWebView(
          tourUrl: 'https://kuula.co/share/test',
          onLoadingChanged: (isLoading) => loadingStates.add(isLoading),
        ),
      );

      // Initial state is loading.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Fire onPageStarted — still loading.
      lastNavigationDelegate?.pageStartedCallback?.call('https://kuula.co/share/test');
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Fire onPageFinished — loading cleared, overlay removed.
      lastNavigationDelegate?.pageFinishedCallback?.call('https://kuula.co/share/test');
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(loadingStates, contains(false));
    });

    testWidgets('onWebResourceError sets error state and hides loading', (tester) async {
      bool? errorState;
      await pumpWidget(
        tester,
        TourWebView(
          tourUrl: 'https://kuula.co/share/test',
          onErrorChanged: (hasError) => errorState = hasError,
        ),
      );

      expect(find.byType(WebViewWidget), findsOneWidget);

      // Fire the web resource error callback.
      lastNavigationDelegate?.webResourceErrorCallback?.call(
        FakeWebResourceError(description: 'network down'),
      );
      await tester.pump();

      // Error state rendered instead of the WebView.
      expect(find.byIcon(Icons.public_off), findsOneWidget);
      expect(find.text('360° Tour Unavailable'), findsOneWidget);
      expect(find.byType(WebViewWidget), findsNothing);
      expect(errorState, isTrue);
    });

    testWidgets('onNavigationRequest allows http(s) navigation', (tester) async {
      await pumpWidget(tester, const TourWebView(tourUrl: 'https://kuula.co/share/test'));

      final decision = await lastNavigationDelegate?.navigationRequestCallback?.call(
        const NavigationRequest(url: 'https://kuula.co/share/test', isMainFrame: true),
      );

      expect(decision, NavigationDecision.navigate);
    });

    testWidgets('onNavigationRequest blocks non-http navigation', (tester) async {
      await pumpWidget(tester, const TourWebView(tourUrl: 'https://kuula.co/share/test'));

      final decision = await lastNavigationDelegate?.navigationRequestCallback?.call(
        const NavigationRequest(url: 'tel:+1234', isMainFrame: true),
      );

      expect(decision, NavigationDecision.prevent);
    });

    testWidgets('onNavigationRequest allows about:blank bootstrap', (tester) async {
      await pumpWidget(tester, const TourWebView(tourUrl: 'https://kuula.co/share/test'));

      final decision = await lastNavigationDelegate?.navigationRequestCallback?.call(
        const NavigationRequest(url: 'about:blank', isMainFrame: true),
      );

      expect(decision, NavigationDecision.navigate);
    });

    testWidgets('applyPageChromeStyles runs JS on page finish', (tester) async {
      await pumpWidget(
        tester,
        const TourWebView(
          tourUrl: 'https://kuula.co/share/test',
          applyPageChromeStyles: true,
          bodyBackgroundCss: '#aabbcc',
        ),
      );

      final initialRunJsCalls = lastWebViewController?.runJavaScriptCalls ?? 0;

      lastNavigationDelegate?.pageFinishedCallback?.call('https://kuula.co/share/test');
      await tester.pump();

      // applyPageChromeStyles injects an inline JS string to style the body.
      expect(lastWebViewController?.runJavaScriptCalls ?? 0, greaterThan(initialRunJsCalls));
    });
  });

  group('didUpdateWidget', () {
    testWidgets('re-initializes when tourUrl changes', (tester) async {
      await pumpWidget(tester, const TourWebView(tourUrl: 'https://kuula.co/share/first'));
      expect(lastWebViewController?.loadHtmlStringCalls, 1);

      // Rebuild with a different URL.
      await pumpWidget(tester, const TourWebView(tourUrl: 'https://kuula.co/share/second'));

      // A new controller was created and loadHtmlString called again.
      expect(lastWebViewController?.loadHtmlStringCalls, 1);
      expect(lastWebViewController?.lastLoadedHtml, contains('second'));
    });

    testWidgets('re-initializes when bodyBackgroundCss changes', (tester) async {
      await pumpWidget(
        tester,
        const TourWebView(tourUrl: 'https://kuula.co/share/test', bodyBackgroundCss: '#ffffff'),
      );
      final firstController = lastWebViewController;

      await pumpWidget(
        tester,
        const TourWebView(tourUrl: 'https://kuula.co/share/test', bodyBackgroundCss: '#000000'),
      );

      // A new controller is created because bodyBackgroundCss changed.
      expect(lastWebViewController, isNot(same(firstController)));
    });

    testWidgets('does NOT re-initialize when neither URL nor background changes', (tester) async {
      await pumpWidget(tester, const TourWebView(tourUrl: 'https://kuula.co/share/test'));
      final firstController = lastWebViewController;
      final firstLoadCalls = firstController?.loadHtmlStringCalls ?? 0;

      // Rebuild with identical props.
      await pumpWidget(tester, const TourWebView(tourUrl: 'https://kuula.co/share/test'));

      expect(lastWebViewController, same(firstController));
      expect(lastWebViewController?.loadHtmlStringCalls, firstLoadCalls);
    });
  });
}
