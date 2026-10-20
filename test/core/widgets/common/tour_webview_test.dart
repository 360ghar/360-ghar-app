import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/widgets/common/tour_webview.dart';
import '../../../helpers/fake_webview_platform.dart';
import '../../../helpers/knife_finders.dart';
import '../../../helpers/provider_test_app.dart';

/// Mirrors the JS channel name [TourWebView] registers for the iframe
/// load/error handshake.
const String _signalChannel = 'GharTourLoadSignal';

/// Mirrors the load-watchdog duration in [TourWebView].
const Duration _loadTimeout = Duration(seconds: 20);

/// Mirrors the (much shorter) ready-probe deadline in [TourWebView].
const Duration _handshakeDeadline = Duration(seconds: 5);

void main() {
  setUp(() {
    installFakeWebViewPlatform();
  });
  tearDown(() {
    uninstallFakeWebViewPlatform();
  });

  Future<void> pumpWidget(WidgetTester tester, Widget child) async {
    await tester.pumpProviderApp(Scaffold(body: SizedBox(width: 400, height: 600, child: child)));
  }

  group('invalid URL fallback', () {
    testWidgets('shows error fallback for an invalid (non-http) URL', (tester) async {
      await pumpWidget(tester, const TourWebView(tourUrl: 'not-a-url'));

      expect(findKnife(KnifeIcon.alert), findsOneWidget);
      expect(find.text('360° Tour Unavailable'), findsOneWidget);
      expect(find.text('Virtual tour could not be loaded'), findsOneWidget);
    });

    testWidgets('shows error fallback for an empty URL', (tester) async {
      await pumpWidget(tester, const TourWebView(tourUrl: ''));

      expect(findKnife(KnifeIcon.alert), findsOneWidget);
      expect(find.text('360° Tour Unavailable'), findsOneWidget);
    });

    testWidgets('shows error fallback for a javascript: URL', (tester) async {
      await pumpWidget(tester, const TourWebView(tourUrl: 'javascript:alert(1)'));

      expect(findKnife(KnifeIcon.alert), findsOneWidget);
      expect(find.text('360° Tour Unavailable'), findsOneWidget);
    });

    testWidgets('returns SizedBox.shrink when showDefaultError is false and URL invalid', (
      tester,
    ) async {
      await pumpWidget(tester, const TourWebView(tourUrl: '', showDefaultError: false));

      expect(findKnife(KnifeIcon.alert), findsNothing);
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

    // Direct-URL path: there is no wrapper and no iframe, so onPageFinished is
    // the only completion signal. The embed path is covered under
    // 'iframe load handshake'.
    testWidgets('onPageStarted sets loading true and onPageFinished sets loading false', (
      tester,
    ) async {
      final loadingStates = <bool>[];
      await pumpWidget(
        tester,
        TourWebView(
          tourUrl: 'https://example.com/tour',
          onLoadingChanged: (isLoading) => loadingStates.add(isLoading),
        ),
      );

      // Initial state is loading.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Fire onPageStarted — still loading.
      lastNavigationDelegate?.pageStartedCallback?.call('https://example.com/tour');
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Fire onPageFinished — loading cleared, overlay removed.
      lastNavigationDelegate?.pageFinishedCallback?.call('https://example.com/tour');
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
      expect(findKnife(KnifeIcon.alert), findsOneWidget);
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

    testWidgets('bodyBackgroundCss change restyles in place, keeping the controller', (
      tester,
    ) async {
      await pumpWidget(
        tester,
        const TourWebView(
          tourUrl: 'https://kuula.co/share/test',
          bodyBackgroundCss: '#ffffff',
          applyPageChromeStyles: true,
        ),
      );
      final firstController = lastWebViewController;
      final loadsBefore = firstController?.loadHtmlStringCalls ?? 0;
      final jsBefore = firstController?.runJavaScriptCalls ?? 0;

      await pumpWidget(
        tester,
        const TourWebView(
          tourUrl: 'https://kuula.co/share/test',
          bodyBackgroundCss: '#000000',
          applyPageChromeStyles: true,
        ),
      );

      // Same native WebView, no reload (the tour keeps its camera position);
      // only the body chrome is re-applied via JS.
      expect(lastWebViewController, same(firstController));
      expect(lastWebViewController?.loadHtmlStringCalls, loadsBefore);
      expect(lastWebViewController?.runJavaScriptCalls ?? 0, greaterThan(jsBefore));
      expect(lastWebViewController?.runJavaScriptScripts.last, contains('#000000'));
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

  group('sub-resource errors', () {
    testWidgets('a sub-frame error does NOT tear down a rendered tour', (tester) async {
      bool? errorState;
      await pumpWidget(
        tester,
        TourWebView(
          tourUrl: 'https://kuula.co/share/test',
          onErrorChanged: (hasError) => errorState = hasError,
        ),
      );

      // An analytics beacon / font 404 inside the page.
      lastNavigationDelegate?.webResourceErrorCallback?.call(_FrameScopedError(false));
      await tester.pump();

      expect(find.byType(WebViewWidget), findsOneWidget);
      expect(findKnife(KnifeIcon.alert), findsNothing);
      expect(errorState, isNull);
    });

    testWidgets('a main-frame error DOES show the error state', (tester) async {
      await pumpWidget(tester, const TourWebView(tourUrl: 'https://kuula.co/share/test'));

      lastNavigationDelegate?.webResourceErrorCallback?.call(_FrameScopedError(true));
      await tester.pump();

      expect(findKnife(KnifeIcon.alert), findsOneWidget);
      expect(find.byType(WebViewWidget), findsNothing);
    });

    testWidgets('a null isForMainFrame is treated as a main-frame error', (tester) async {
      await pumpWidget(tester, const TourWebView(tourUrl: 'https://kuula.co/share/test'));

      lastNavigationDelegate?.webResourceErrorCallback?.call(_FrameScopedError(null));
      await tester.pump();

      expect(findKnife(KnifeIcon.alert), findsOneWidget);
    });
  });

  group('load timeout', () {
    testWidgets('shows the error state when the page never finishes loading', (tester) async {
      bool? errorState;
      await pumpWidget(
        tester,
        TourWebView(
          tourUrl: 'https://example.com/tour',
          onErrorChanged: (hasError) => errorState = hasError,
        ),
      );

      lastNavigationDelegate?.pageStartedCallback?.call('https://example.com/tour');
      await tester.pump();
      expect(findKnife(KnifeIcon.alert), findsNothing);

      await tester.pump(_loadTimeout + const Duration(seconds: 1));

      expect(findKnife(KnifeIcon.alert), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(errorState, isTrue);
    });

    testWidgets('direct-URL path: onPageFinished cancels the timeout', (tester) async {
      await pumpWidget(tester, const TourWebView(tourUrl: 'https://example.com/tour'));

      lastNavigationDelegate?.pageFinishedCallback?.call('https://example.com/tour');
      await tester.pump();

      await tester.pump(_loadTimeout + const Duration(seconds: 1));

      expect(findKnife(KnifeIcon.alert), findsNothing);
      expect(find.byType(WebViewWidget), findsOneWidget);
    });

    // Relies on flutter_test's own "A Timer is still pending even after the
    // widget tree was disposed" check: never pump past the timeout here, or
    // the timer would fire and clear itself, hiding a missing cancel.
    testWidgets('the timeout timer is cancelled on dispose', (tester) async {
      await pumpWidget(tester, const TourWebView(tourUrl: 'https://kuula.co/share/test'));

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });

  group('iframe load handshake', () {
    testWidgets('embed wrapper HTML wires the iframe load/error reporters', (tester) async {
      await pumpWidget(tester, const TourWebView(tourUrl: 'https://kuula.co/share/test'));

      final html = lastWebViewController?.lastLoadedHtml;
      expect(html, contains('onload="$_signalChannel.postMessage(\'loaded\')"'));
      expect(html, contains('onerror="$_signalChannel.postMessage(\'failed\')"'));
    });

    testWidgets('a wrapper that finishes without an iframe signal still times out', (tester) async {
      await pumpWidget(tester, const TourWebView(tourUrl: 'https://kuula.co/share/test'));

      // The document parsed, so the channel is proven live.
      lastWebViewController?.simulateJavaScriptMessage(_signalChannel, 'ready');

      // The wrapper is a tiny local document: it always finishes, even when the
      // embedded tour is dead. That must NOT cancel the watchdog.
      lastNavigationDelegate?.pageFinishedCallback?.call('about:blank');
      await tester.pump();
      expect(findKnife(KnifeIcon.alert), findsNothing);

      await tester.pump(_loadTimeout + const Duration(seconds: 1));

      expect(findKnife(KnifeIcon.alert), findsOneWidget);
    });

    testWidgets('an iframe onload signal renders the tour and cancels the watchdog', (
      tester,
    ) async {
      bool? errorState;
      await pumpWidget(
        tester,
        TourWebView(
          tourUrl: 'https://kuula.co/share/test',
          onErrorChanged: (hasError) => errorState = hasError,
        ),
      );

      lastWebViewController?.simulateJavaScriptMessage(_signalChannel, 'loaded');
      await tester.pump();

      expect(find.byType(WebViewWidget), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Watchdog cancelled: no error even long past the timeout.
      await tester.pump(_loadTimeout + const Duration(seconds: 1));
      expect(findKnife(KnifeIcon.alert), findsNothing);
      expect(errorState, isNull);
    });

    testWidgets('an iframe onerror signal shows the error state immediately', (tester) async {
      await pumpWidget(tester, const TourWebView(tourUrl: 'https://kuula.co/share/test'));

      lastWebViewController?.simulateJavaScriptMessage(_signalChannel, 'failed');
      await tester.pump();

      expect(findKnife(KnifeIcon.alert), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('a sub-resource error does not disturb an iframe that loaded', (tester) async {
      await pumpWidget(tester, const TourWebView(tourUrl: 'https://kuula.co/share/test'));

      lastWebViewController?.simulateJavaScriptMessage(_signalChannel, 'loaded');
      lastNavigationDelegate?.webResourceErrorCallback?.call(_FrameScopedError(false));
      await tester.pump();

      expect(find.byType(WebViewWidget), findsOneWidget);
      expect(findKnife(KnifeIcon.alert), findsNothing);
    });

    testWidgets('embed wrapper HTML posts a ready probe as the document parses', (tester) async {
      await pumpWidget(tester, const TourWebView(tourUrl: 'https://kuula.co/share/test'));

      expect(
        lastWebViewController?.lastLoadedHtml,
        contains("$_signalChannel.postMessage('ready')"),
      );
    });

    testWidgets('ready without loaded within the timeout shows the error state', (tester) async {
      await pumpWidget(tester, const TourWebView(tourUrl: 'https://kuula.co/share/test'));

      lastWebViewController?.simulateJavaScriptMessage(_signalChannel, 'ready');
      await tester.pump(_loadTimeout + const Duration(seconds: 1));

      // Channel demonstrably works, so a missing 'loaded' means a dead iframe.
      expect(findKnife(KnifeIcon.alert), findsOneWidget);
    });

    testWidgets('a late loaded signal after the watchdog error restores the tour', (tester) async {
      bool? errorState;
      await pumpWidget(
        tester,
        TourWebView(
          tourUrl: 'https://kuula.co/share/test',
          onErrorChanged: (hasError) => errorState = hasError,
        ),
      );

      // Channel is live but the iframe is still loading when the 20s watchdog
      // fires — the tour then sits on the error screen.
      lastWebViewController?.simulateJavaScriptMessage(_signalChannel, 'ready');
      await tester.pump(_loadTimeout + const Duration(seconds: 1));
      expect(findKnife(KnifeIcon.alert), findsOneWidget);
      expect(errorState, isTrue);

      // The tour finally loads; the late 'loaded' signal must clear the error
      // the watchdog set instead of leaving the user stuck on the error screen.
      lastWebViewController?.simulateJavaScriptMessage(_signalChannel, 'loaded');
      await tester.pump();

      expect(findKnife(KnifeIcon.alert), findsNothing);
      expect(find.byType(WebViewWidget), findsOneWidget);
      expect(errorState, isFalse);
    });

    testWidgets('no ready clears the spinner at the SHORT deadline, not the 20s watchdog', (
      tester,
    ) async {
      bool? errorState;
      await pumpWidget(
        tester,
        TourWebView(
          tourUrl: 'https://kuula.co/share/test',
          onErrorChanged: (hasError) => errorState = hasError,
        ),
      );

      // Just before the handshake deadline the spinner is still up.
      await tester.pump(_handshakeDeadline - const Duration(milliseconds: 100));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Crossing it clears the spinner — long before the 20s watchdog.
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(findKnife(KnifeIcon.alert), findsNothing);
      expect(find.byType(WebViewWidget), findsOneWidget);

      // And the watchdog was stood down, so no late false error either.
      await tester.pump(_loadTimeout + const Duration(seconds: 1));
      expect(findKnife(KnifeIcon.alert), findsNothing);
      expect(errorState, isNull);
    });

    testWidgets('a late ready after the deadline does not resurrect the error path', (
      tester,
    ) async {
      await pumpWidget(tester, const TourWebView(tourUrl: 'https://kuula.co/share/test'));

      await tester.pump(_handshakeDeadline + const Duration(seconds: 1));
      lastWebViewController?.simulateJavaScriptMessage(_signalChannel, 'ready');
      await tester.pump(_loadTimeout + const Duration(seconds: 1));

      expect(findKnife(KnifeIcon.alert), findsNothing);
      expect(find.byType(WebViewWidget), findsOneWidget);
    });

    testWidgets('an explicit failed signal still errors even after the deadline', (tester) async {
      await pumpWidget(tester, const TourWebView(tourUrl: 'https://kuula.co/share/test'));

      await tester.pump(_handshakeDeadline + const Duration(seconds: 1));
      lastWebViewController?.simulateJavaScriptMessage(_signalChannel, 'failed');
      await tester.pump();

      // Absence of a signal proves nothing, but an explicit failure is trusted.
      expect(findKnife(KnifeIcon.alert), findsOneWidget);
    });

    // Never pumps past the timeout: a leaked timer must surface as pending.
    testWidgets('ready then loaded renders and leaves no pending timer at dispose', (tester) async {
      await pumpWidget(tester, const TourWebView(tourUrl: 'https://kuula.co/share/test'));

      lastWebViewController?.simulateJavaScriptMessage(_signalChannel, 'ready');
      lastWebViewController?.simulateJavaScriptMessage(_signalChannel, 'loaded');
      await tester.pump();

      expect(find.byType(WebViewWidget), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('the direct-URL path registers no channel and has no handshake deadline', (
      tester,
    ) async {
      await pumpWidget(tester, const TourWebView(tourUrl: 'https://example.com/tour'));

      expect(lastWebViewController?.javaScriptChannels.containsKey(_signalChannel), isFalse);

      // No handshake deadline here: the spinner survives it and only the 20s
      // watchdog applies.
      await tester.pump(_handshakeDeadline + const Duration(seconds: 1));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(findKnife(KnifeIcon.alert), findsNothing);

      await tester.pump(_loadTimeout);
      expect(findKnife(KnifeIcon.alert), findsOneWidget);
    });
  });

  group('retry', () {
    testWidgets('error state offers a retry that reloads the tour', (tester) async {
      await pumpWidget(tester, const TourWebView(tourUrl: 'https://kuula.co/share/test'));
      lastNavigationDelegate?.webResourceErrorCallback?.call(_FrameScopedError(true));
      await tester.pump();

      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(find.byType(WebViewWidget), findsOneWidget);
      expect(findKnife(KnifeIcon.alert), findsNothing);
      expect(lastWebViewController?.loadHtmlStringCalls, 1);
    });

    testWidgets('no retry is offered when the URL itself is invalid', (tester) async {
      await pumpWidget(tester, const TourWebView(tourUrl: 'not-a-url'));

      expect(findKnife(KnifeIcon.alert), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });
  });
  testWidgets('old native callbacks cannot finish a replacement URL', (tester) async {
    await pumpWidget(tester, const TourWebView(tourUrl: 'https://example.com/old'));
    final oldDelegate = lastNavigationDelegate!;
    final oldController = lastWebViewController!;
    await pumpWidget(tester, const TourWebView(tourUrl: 'https://example.com/new'));
    expect(oldController.runJavaScriptScripts, contains('window.stop();'));
    oldDelegate.pageFinishedCallback?.call('https://example.com/old');
    oldDelegate.webResourceErrorCallback?.call(_FrameScopedError(true));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('360° Tour Unavailable'), findsNothing);
    lastNavigationDelegate!.pageFinishedCallback?.call('https://example.com/new');
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
  testWidgets('background pauses media and removal stops loading without late effects', (
    tester,
  ) async {
    await pumpWidget(tester, const TourWebView(tourUrl: 'https://example.com/tour'));
    final controller = lastWebViewController!;
    final delegate = lastNavigationDelegate!;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(controller.runJavaScriptScripts.any((script) => script.contains('media.pause()')), true);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(controller.runJavaScriptScripts, contains('window.stop();'));
    delegate.pageFinishedCallback?.call('https://example.com/tour');
    await tester.pump(const Duration(seconds: 30));
    expect(tester.takeException(), isNull);
  });
  testWidgets('asynchronous native configuration failure shows inline retry', (tester) async {
    WebViewPlatform.instance = FakeWebViewPlatform(
      configurationError: StateError('private configuration detail'),
    );
    await pumpWidget(tester, const TourWebView(tourUrl: 'https://example.com/tour'));
    await tester.pump();
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('private configuration'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
  testWidgets('small embedded error respects large text without overflow', (tester) async {
    await tester.pumpProviderApp(
      const Scaffold(
        body: SizedBox(width: 280, height: 120, child: TourWebView(tourUrl: 'invalid')),
      ),
      textScale: 2,
    );
    expect(find.text('360° Tour Unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

/// A [WebResourceError] whose main-frame flag the test controls.
class _FrameScopedError implements WebResourceError {
  _FrameScopedError(this.isForMainFrame);

  @override
  final bool? isForMainFrame;

  @override
  String get description => 'boom';

  @override
  int get errorCode => 1;

  @override
  WebResourceErrorType? get errorType => null;

  @override
  String? get url => null;
}
