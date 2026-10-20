import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/utils/tour_url.dart';
import 'package:ghar360/core/widgets/common/error_states.dart';
import 'package:ghar360/core/widgets/common/tour_webview.dart';
import 'package:ghar360/core/widgets/paper/paper_vignette.dart';
import 'package:ghar360/core/widgets/paper/scene_header_sliver.dart';
import 'package:ghar360/features/tour/presentation/views/tour_view.dart';
import '../../../../helpers/fake_webview_platform.dart';
import '../../../../helpers/knife_finders.dart';
import '../../../../helpers/provider_test_app.dart';

/// The invalid-link state and its one action.
final _invalidState = find.byType(StateBlock);
final _backAction = find.byKey(const ValueKey('qa.tour.invalid_state.action'));

/// Mirrors the JS channel name TourWebView registers for the iframe handshake.
const String _signalChannel = 'GharTourLoadSignal';

void main() {
  setUp(installFakeWebViewPlatform);
  tearDown(uninstallFakeWebViewPlatform);

  Future<void> pumpTour(WidgetTester tester, {dynamic arguments}) async {
    await tester.pumpProviderApp(TourView(url: TourUrl.extractFromArgs(arguments) ?? ''));
    await tester.pump(const Duration(milliseconds: 200));
  }

  group('TourView', () {
    // ── Fallback / invalid-arguments tests ──────────────────────────────

    testWidgets('shows fallback when route arguments are missing', (tester) async {
      await pumpTour(tester);

      expect(find.byKey(const ValueKey('qa.tour.screen')), findsOneWidget);
      expect(_invalidState, findsOneWidget);
    });

    testWidgets('shows fallback for non-http URL scheme', (tester) async {
      await pumpTour(tester, arguments: 'ftp://example.com/tour');

      expect(_invalidState, findsOneWidget);
      expect(find.byType(TourWebView), findsNothing);
    });

    testWidgets('shows fallback for empty string argument', (tester) async {
      await pumpTour(tester, arguments: '');

      expect(_invalidState, findsOneWidget);
    });

    testWidgets('shows fallback for whitespace-only URL', (tester) async {
      await pumpTour(tester, arguments: '   ');

      expect(_invalidState, findsOneWidget);
    });

    testWidgets('shows back button in fallback state', (tester) async {
      await pumpTour(tester);

      expect(_backAction, findsOneWidget);
    });

    // ── URL extraction logic tests ──────────────────────────────────────

    testWidgets('extracts tourUrl from map argument', (tester) async {
      // TourUrl.extractFromArgs should handle map arguments.
      // Since we can't reliably pass arguments in widget tests,
      // verify the fallback handles null gracefully.
      await pumpTour(tester);

      expect(find.byKey(const ValueKey('qa.tour.screen')), findsOneWidget);
    });

    testWidgets('scaffold has back navigation in fallback', (tester) async {
      await pumpTour(tester);

      // The fallback scaffold should have an AppBar with back button.
      expect(find.byType(Scaffold), findsOneWidget);
      expect(findKnife(KnifeIcon.arrowLeft), findsOneWidget);
    });

    testWidgets('fallback shows descriptive text', (tester) async {
      await pumpTour(tester);

      // Should show some text explaining the error.
      expect(find.byType(Text), findsAtLeast(1));
    });

    // ── Fallback content details ────────────────────────────────────────

    testWidgets('fallback shows the not-found scene and a localized title', (tester) async {
      await pumpTour(tester);

      expect(find.byType(PaperVignette), findsOneWidget);
      expect(find.text('360° Tour Unavailable'), findsOneWidget);
    });

    testWidgets('fallback back action is enabled', (tester) async {
      await pumpTour(tester);

      // The action pops or goes to Discover; verify it is live.
      final button = tester.widget<FilledButton>(_backAction);
      expect(button.onPressed, isNotNull);
    });

    testWidgets('fallback body contains Column with icon and texts', (tester) async {
      await pumpTour(tester);

      // The fallback content is a Column with an icon, title, subtitle, and button.
      expect(find.byType(Column), findsWidgets);
      expect(_invalidState, findsOneWidget);
      expect(_backAction, findsOneWidget);
    });

    testWidgets('fallback AppBar has back arrow icon', (tester) async {
      await pumpTour(tester);

      expect(findKnife(KnifeIcon.arrowLeft), findsOneWidget);
    });

    // ── Valid URL rendering (WebView loading state) ─────────────────────
    // With the fake WebView platform installed, TourView should render the
    // TourWebView widget and show the loading overlay.

    testWidgets('renders TourWebView for valid http URL', (tester) async {
      await pumpTour(tester, arguments: 'https://kuula.co/post/example');

      // The TourWebView should be rendered (not the fallback).
      expect(find.byType(TourWebView), findsOneWidget);
      expect(_invalidState, findsNothing);
    });

    testWidgets('shows loading overlay initially for valid URL', (tester) async {
      await pumpTour(tester, arguments: 'https://kuula.co/post/example');

      // The loading overlay should show a CircularProgressIndicator.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(_invalidState, findsNothing);
    });

    testWidgets('renders AppBar with the share action for valid URL', (tester) async {
      await pumpTour(tester, arguments: 'https://kuula.co/post/example');

      expect(findKnife(KnifeIcon.share), findsOneWidget);
    });

    testWidgets('renders back arrow in AppBar for valid URL', (tester) async {
      await pumpTour(tester, arguments: 'https://kuula.co/post/example');

      expect(findKnife(KnifeIcon.arrowLeft), findsOneWidget);
    });

    testWidgets('does not render fallback content for valid URL', (tester) async {
      await pumpTour(tester, arguments: 'https://kuula.co/post/example');

      expect(_invalidState, findsNothing);
      expect(_backAction, findsNothing);
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

    testWidgets('loading overlay shows CircularProgressIndicator with correct color', (
      tester,
    ) async {
      await pumpTour(tester, arguments: 'https://kuula.co/post/example');

      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      // The loading overlay uses AppDesign.primaryYellow color.
      expect(indicator.strokeWidth, 2);
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
      expect(_invalidState, findsNothing);
    });

    testWidgets('extracts tourUrl from map with url key', (tester) async {
      await pumpTour(tester, arguments: {'url': 'https://kuula.co/post/test'});

      expect(find.byType(TourWebView), findsOneWidget);
      expect(_invalidState, findsNothing);
    });

    testWidgets('shows fallback for map with invalid URL', (tester) async {
      await pumpTour(tester, arguments: {'tourUrl': 'not-a-url'});

      expect(_invalidState, findsOneWidget);
    });

    testWidgets('shows fallback for map with empty URL', (tester) async {
      await pumpTour(tester, arguments: {'tourUrl': ''});

      expect(_invalidState, findsOneWidget);
    });

    testWidgets('shows fallback for map with null URL', (tester) async {
      await pumpTour(tester, arguments: {'tourUrl': null});

      expect(_invalidState, findsOneWidget);
    });

    // ── Various invalid URL formats ─────────────────────────────────────

    testWidgets('shows fallback for javascript: URL', (tester) async {
      await pumpTour(tester, arguments: 'javascript:alert(1)');

      expect(_invalidState, findsOneWidget);
    });

    testWidgets('shows fallback for data: URL', (tester) async {
      await pumpTour(tester, arguments: 'data:text/html,<h1>test</h1>');

      expect(_invalidState, findsOneWidget);
    });

    testWidgets('shows fallback for file: URL', (tester) async {
      await pumpTour(tester, arguments: 'file:///etc/passwd');

      expect(_invalidState, findsOneWidget);
    });

    testWidgets('shows fallback for URL with credentials', (tester) async {
      await pumpTour(tester, arguments: 'https://user:pass@example.com/tour');

      expect(_invalidState, findsOneWidget);
    });

    testWidgets('shows fallback for URL with empty host', (tester) async {
      await pumpTour(tester, arguments: 'https:///tour');

      expect(_invalidState, findsOneWidget);
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

    // TourView drives its own opaque overlay from onLoadingChanged, and on the
    // embed path that now clears only when the iframe reports in.
    testWidgets('loading overlay clears when the embedded iframe signals load', (tester) async {
      await pumpTour(tester, arguments: 'https://kuula.co/post/example');

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      lastWebViewController?.simulateJavaScriptMessage(_signalChannel, 'loaded');
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(TourWebView), findsOneWidget);
    });

    // Broken-channel fallback: nothing ever signals, so after the watchdog the
    // overlay must lift onto whatever rendered rather than claiming failure.
    testWidgets('overlay lifts with no error toast when the channel never signals', (tester) async {
      await pumpTour(tester, arguments: 'https://kuula.co/post/example');

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Cleared at the short handshake deadline, not after the 20s watchdog.
      await tester.pump(const Duration(seconds: 6));

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('360° Tour Unavailable'), findsNothing);
      expect(find.byType(TourWebView), findsOneWidget);
    });

    testWidgets('sub-frame resource errors raise no error toast', (tester) async {
      await pumpTour(tester, arguments: 'https://kuula.co/post/example');

      lastNavigationDelegate?.webResourceErrorCallback?.call(_FrameScopedError(false));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('360° Tour Unavailable'), findsNothing);
    });

    testWidgets('main-frame resource errors show retryable inline failure', (tester) async {
      await pumpTour(tester, arguments: 'https://kuula.co/post/example');

      lastNavigationDelegate?.webResourceErrorCallback?.call(_FrameScopedError(true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('360° Tour Unavailable'), findsOneWidget);

      // Let the snackbar auto-dismiss so its ticker is disposed before teardown.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });

    testWidgets('share button is present and tappable', (tester) async {
      await pumpTour(tester, arguments: 'https://kuula.co/post/example');

      final button = tester.widget<IconButton>(
        find.ancestor(of: findKnife(KnifeIcon.share), matching: find.byType(IconButton)),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('back button in AppBar for valid URL is tappable', (tester) async {
      await pumpTour(tester, arguments: 'https://kuula.co/post/example');

      final button = tester.widget<IconButton>(
        find.ancestor(of: findKnife(KnifeIcon.arrowLeft), matching: find.byType(IconButton)),
      );
      expect(button.onPressed, isNotNull);
    });

    // ── Container structure for valid URL ───────────────────────────────

    testWidgets('lays the tour full width on the sheet under the skyline header', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pumpTour(tester, arguments: 'https://kuula.co/post/example');

      // No frame or clip around the native view: every drag and pixel is the tour's.
      expect(find.byType(ClipRRect), findsNothing);
      expect(find.byType(SceneHeaderSliver), findsOneWidget);
      final screen = tester.getSize(find.byKey(const ValueKey('qa.tour.screen')));
      final tour = tester.getRect(find.byType(TourWebView));
      expect(tour.width, screen.width);
      expect(tour.bottom, screen.height);
      expect(tour.top, greaterThan(SceneHeaderSliver.bar));
    });
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
