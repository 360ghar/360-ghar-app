// test/helpers/fake_webview_platform.dart
//
// A minimal, in-process fake for `webview_flutter`'s platform interface so
// widget tests can exercise the success path of [TourWebView] (and any other
// WebView-backed widget) without a real native WebView engine.
//
// The fake records the navigation-delegate callbacks wired up by the widget
// under test so tests can invoke them directly and assert on the resulting
// [NavigationDecision] / loading / error state transitions.

import 'package:flutter/material.dart';

import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

/// Captures the most recently created fake navigation delegate so tests can
/// fire its callbacks.
FakePlatformNavigationDelegate? lastNavigationDelegate;

/// Captures the most recently created fake web view controller so tests can
/// assert on load calls.
FakePlatformWebViewController? lastWebViewController;

/// Installs the fake [WebViewPlatform] for the duration of a test. Call in
/// `setUp` (after `TestWidgetsFlutterBinding.ensureInitialized()`).
void installFakeWebViewPlatform() {
  WebViewPlatform.instance = FakeWebViewPlatform();
  lastNavigationDelegate = null;
  lastWebViewController = null;
}

/// Clears captured fakes. Call in `tearDown`.
void uninstallFakeWebViewPlatform() {
  // Reset to null is disallowed by the platform interface; each test
  // re-installs a fresh fake in setUp so stale state never leaks.
  lastNavigationDelegate = null;
  lastWebViewController = null;
}

/// A no-op [WebViewPlatform] that creates fake platform objects for tests.
class FakeWebViewPlatform extends WebViewPlatform {
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    final controller = FakePlatformWebViewController(params);
    lastWebViewController = controller;
    return controller;
  }

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(PlatformWebViewWidgetCreationParams params) {
    return FakePlatformWebViewWidget(params);
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) {
    final delegate = FakePlatformNavigationDelegate(params);
    lastNavigationDelegate = delegate;
    return delegate;
  }
}

/// Fake [PlatformWebViewController] that records load/run calls.
class FakePlatformWebViewController extends PlatformWebViewController {
  FakePlatformWebViewController(super.params) : super.implementation();

  int loadHtmlStringCalls = 0;
  int loadRequestCalls = 0;
  int runJavaScriptCalls = 0;
  String? lastLoadedHtml;
  Uri? lastLoadedUri;
  final List<String> runJavaScriptScripts = <String>[];
  final Map<String, void Function(JavaScriptMessage)> javaScriptChannels =
      <String, void Function(JavaScriptMessage)>{};

  @override
  Future<void> loadHtmlString(String html, {String? baseUrl}) async {
    loadHtmlStringCalls++;
    lastLoadedHtml = html;
  }

  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    loadRequestCalls++;
    lastLoadedUri = params.uri;
  }

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setBackgroundColor(Color color) async {}

  @override
  Future<void> setPlatformNavigationDelegate(PlatformNavigationDelegate handler) async {}

  @override
  Future<void> runJavaScript(String javaScript) async {
    runJavaScriptCalls++;
    runJavaScriptScripts.add(javaScript);
  }

  @override
  Future<void> addJavaScriptChannel(JavaScriptChannelParams javaScriptChannelParams) async {
    javaScriptChannels[javaScriptChannelParams.name] = javaScriptChannelParams.onMessageReceived;
  }

  @override
  Future<void> removeJavaScriptChannel(String javaScriptChannelName) async {
    javaScriptChannels.remove(javaScriptChannelName);
  }

  @override
  Future<void> setOnPlatformPermissionRequest(
    void Function(PlatformWebViewPermissionRequest request)? callback,
  ) async {}

  @override
  Future<void> reload() async {}

  @override
  Future<bool> canGoBack() async => false;

  @override
  Future<bool> canGoForward() async => false;

  /// Simulates a JS channel post from the WebView into Flutter.
  void simulateJavaScriptMessage(String channel, String message) {
    final handler = javaScriptChannels[channel];
    if (handler == null) {
      throw StateError('No JavaScript channel registered for "$channel"');
    }
    handler(JavaScriptMessage(message: message));
  }
}

/// Fake [PlatformWebViewWidget] that renders a simple placeholder widget.
class FakePlatformWebViewWidget extends PlatformWebViewWidget {
  FakePlatformWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand(child: ColoredBox(color: Color(0xFF123456)));
  }
}

/// Fake [PlatformNavigationDelegate] that captures callbacks for tests.
class FakePlatformNavigationDelegate extends PlatformNavigationDelegate {
  FakePlatformNavigationDelegate(super.params) : super.implementation();

  NavigationRequestCallback? navigationRequestCallback;
  PageEventCallback? pageStartedCallback;
  PageEventCallback? pageFinishedCallback;
  WebResourceErrorCallback? webResourceErrorCallback;

  @override
  Future<void> setOnNavigationRequest(NavigationRequestCallback onNavigationRequest) async {
    navigationRequestCallback = onNavigationRequest;
  }

  @override
  Future<void> setOnPageStarted(PageEventCallback onPageStarted) async {
    pageStartedCallback = onPageStarted;
  }

  @override
  Future<void> setOnPageFinished(PageEventCallback onPageFinished) async {
    pageFinishedCallback = onPageFinished;
  }

  @override
  Future<void> setOnProgress(ProgressCallback onProgress) async {}

  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback onWebResourceError) async {
    webResourceErrorCallback = onWebResourceError;
  }

  @override
  Future<void> setOnHttpError(HttpResponseErrorCallback onHttpError) async {}

  @override
  Future<void> setOnUrlChange(UrlChangeCallback onUrlChange) async {}

  @override
  Future<void> setOnHttpAuthRequest(HttpAuthRequestCallback onHttpAuthRequest) async {}
}

/// A trivial [WebResourceError] used to fire the error callback in tests.
class FakeWebResourceError implements WebResourceError {
  FakeWebResourceError({this.description = 'fake error', this.errorCode = 1});

  @override
  final String description;

  @override
  final int errorCode;

  String? get domain => 'fake';

  @override
  bool? get isForMainFrame => true;

  @override
  WebResourceErrorType? get errorType => null;

  @override
  String? get url => null;
}
