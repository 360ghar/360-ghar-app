import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/core/utils/tour_url.dart';
import 'package:ghar360/core/utils/webview_helper.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Canonical 360° tour WebView used by full-screen tour, swipe embeds, and cards.
///
/// Validates [tourUrl] with [TourUrl], loads Kuula via a single HTML embed
/// template, and blocks non-http(s) navigations.
class TourWebView extends StatefulWidget {
  final String tourUrl;
  final Color? backgroundColor;
  final String bodyBackgroundCss;
  final bool applyPageChromeStyles;
  final bool showDefaultLoading;
  final bool showDefaultError;
  final ValueChanged<bool>? onLoadingChanged;
  final ValueChanged<bool>? onErrorChanged;

  const TourWebView({
    super.key,
    required this.tourUrl,
    this.backgroundColor,
    this.bodyBackgroundCss = '#f0f0f0',
    this.applyPageChromeStyles = false,
    this.showDefaultLoading = true,
    this.showDefaultError = true,
    this.onLoadingChanged,
    this.onErrorChanged,
  });

  @override
  State<TourWebView> createState() => _TourWebViewState();
}

class _TourWebViewState extends State<TourWebView> {
  /// A load that neither finishes nor errors within this window is treated as
  /// failed, so a hung connection cannot spin forever. Generous on purpose:
  /// it has to tolerate a slow network fetching the actual tour.
  static const Duration _loadTimeout = Duration(seconds: 20);

  /// Deadline for the embed's ready probe, which only has to prove the JS
  /// channel works. The probe is same-document and local, so the only real
  /// variance is native WebView creation plus JS-engine warmup on a cold,
  /// low-end device. Erring long is nearly free (a slightly later spinner
  /// clear); erring short silently disables dead-embed detection.
  static const Duration _handshakeDeadline = Duration(seconds: 5);

  /// JS channel the embed shell posts its iframe load outcome to.
  static const String _loadSignalChannel = 'GharTourLoadSignal';

  WebViewController? _controller;
  Timer? _loadTimeoutTimer;
  Timer? _handshakeTimer;

  /// True on the [TourUrl.buildIframeEmbedHtml] path, where completion is
  /// reported by the iframe rather than by the (always-finishing) wrapper.
  bool _usesEmbedWrapper = false;
  bool _isLoading = true;
  bool _hasError = false;
  String? _validatedUrl;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(TourWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tourUrl != widget.tourUrl) {
      setState(_initialize);
    } else if (oldWidget.bodyBackgroundCss != widget.bodyBackgroundCss) {
      // Restyle in place: re-initializing would reload the tour and throw away
      // the user's camera position just because the theme flipped.
      _applyPageChrome();
    }
  }

  @override
  void dispose() {
    _loadTimeoutTimer?.cancel();
    _handshakeTimer?.cancel();
    super.dispose();
  }

  void _startLoadTimeout() {
    _loadTimeoutTimer?.cancel();
    _loadTimeoutTimer = Timer(_loadTimeout, () {
      // On the embed path the handshake deadline stands this watchdog down
      // when the channel is dead, so reaching here means the channel was live.
      DebugLogger.warning(
        _usesEmbedWrapper
            ? 'TourWebView load timed out after ${_loadTimeout.inSeconds}s with a LIVE channel: '
                  'the embedded iframe never loaded, showing the error state'
            : 'TourWebView load timed out after ${_loadTimeout.inSeconds}s: '
                  'the page never finished loading, showing the error state',
      );
      _setLoading(false);
      _setError(true);
    });
  }

  /// Embed path only: gives the ready probe a short window to prove the JS
  /// channel works before we stop drawing conclusions from its silence.
  void _startHandshakeDeadline() {
    _handshakeTimer?.cancel();
    _handshakeTimer = Timer(_handshakeDeadline, () {
      // No probe arrived, so the channel is unavailable here and a missing
      // 'loaded' proves nothing about the tour. Show whatever rendered and
      // stand the watchdog down: flipping a page the user is already looking
      // at into "Tour unavailable" 15s later is the failure we are avoiding.
      DebugLogger.warning(
        'TourWebView saw NO channel handshake within ${_handshakeDeadline.inSeconds}s: '
        'assuming the JS channel is unavailable, keeping the rendered page',
      );
      _loadTimeoutTimer?.cancel();
      _setLoading(false);
    });
  }

  void _onLoadSignal(JavaScriptMessage message) {
    // Any message proves the channel works. A probe arriving *after* the
    // deadline changes nothing: the watchdog is already stood down and the
    // spinner cleared, so silence can no longer be turned into an error.
    // An explicit 'failed' is still trusted, whenever it lands.
    _handshakeTimer?.cancel();
    if (message.message == TourUrl.embedReadyMessage) return;
    _loadTimeoutTimer?.cancel();
    if (message.message == TourUrl.embedFailedMessage) {
      DebugLogger.warning('TourWebView embed reported a failed iframe load');
      _setLoading(false);
      _setError(true);
      return;
    }
    _setLoading(false);
  }

  void _applyPageChrome() {
    if (!widget.applyPageChromeStyles) return;
    final bodyBg = TourUrl.sanitizeCssColor(widget.bodyBackgroundCss);
    _controller?.runJavaScript('''
      document.body.style.margin = '0';
      document.body.style.padding = '0';
      document.body.style.background = '$bodyBg';
      var iframes = document.getElementsByTagName('iframe');
      for (var i = 0; i < iframes.length; i++) {
        iframes[i].style.width = '100%';
        iframes[i].style.height = '100vh';
        iframes[i].style.border = 'none';
      }
    ''');
  }

  void _setLoading(bool value) {
    if (!mounted) return;
    if (_isLoading == value) return;
    setState(() => _isLoading = value);
    widget.onLoadingChanged?.call(value);
  }

  void _setError(bool value) {
    if (!mounted) return;
    if (_hasError == value) return;
    setState(() => _hasError = value);
    widget.onErrorChanged?.call(value);
  }

  void _initialize() {
    _loadTimeoutTimer?.cancel();
    _handshakeTimer?.cancel();
    _usesEmbedWrapper = false;
    final validated = TourUrl.validate(widget.tourUrl);
    _validatedUrl = validated;
    if (validated == null) {
      DebugLogger.warning('TourWebView rejected invalid tour URL: ${widget.tourUrl}');
      _controller = null;
      _isLoading = false;
      _hasError = true;
      widget.onLoadingChanged?.call(false);
      widget.onErrorChanged?.call(true);
      return;
    }

    try {
      final useEmbed = TourUrl.isKuula(validated) || TourUrl.isAllowedEmbedHost(validated);
      _usesEmbedWrapper = useEmbed;
      WebViewHelper.ensureInitialized();
      final bg = widget.backgroundColor ?? const Color(0x00000000);
      final controller = WebViewHelper.createBaseController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(bg)
        ..setNavigationDelegate(
          NavigationDelegate(
            onNavigationRequest: (request) {
              if (TourUrl.isAllowedNavigation(request.url, allowedOriginUrl: _validatedUrl)) {
                return NavigationDecision.navigate;
              }
              DebugLogger.warning('TourWebView blocked navigation: ${request.url}');
              return NavigationDecision.prevent;
            },
            onPageStarted: (_) {
              _setLoading(true);
              if (kReleaseMode) {
                _controller?.runJavaScript(TourUrl.consoleSilencerJs);
              }
            },
            onPageFinished: (_) {
              // On the embed path this is only the wrapper document finishing;
              // it says nothing about the iframe, so the watchdog and the
              // spinner both stay until the iframe reports in.
              if (!_usesEmbedWrapper) {
                _loadTimeoutTimer?.cancel();
                _setLoading(false);
              }
              if (kReleaseMode) {
                _controller?.runJavaScript(TourUrl.consoleSilencerJs);
              }
              _applyPageChrome();
            },
            onWebResourceError: (error) {
              // A failed sub-resource (analytics beacon, font, the embedded
              // iframe) must not replace an already-rendered tour with an
              // error screen. A null flag is ambiguous, so it counts as
              // main-frame and still errors out. A genuinely dead embed is
              // caught by the iframe handshake / watchdog instead, so nothing
              // here needs to guess from error.url.
              if (error.isForMainFrame == false) {
                DebugLogger.warning('TourWebView sub-resource error: ${error.description}');
                return;
              }
              DebugLogger.warning('TourWebView error: ${error.description}');
              _loadTimeoutTimer?.cancel();
              _setLoading(false);
              _setError(true);
            },
          ),
        );

      if (useEmbed) {
        controller.addJavaScriptChannel(_loadSignalChannel, onMessageReceived: _onLoadSignal);
      }

      _controller = controller;
      _hasError = false;
      _isLoading = true;

      if (useEmbed) {
        final html = TourUrl.buildIframeEmbedHtml(
          tourUrl: validated,
          bodyBackground: widget.bodyBackgroundCss,
          silenceConsole: kReleaseMode,
          loadSignalChannel: _loadSignalChannel,
        );
        controller.loadHtmlString(html);
      } else {
        controller.loadRequest(Uri.parse(validated));
      }
      _startLoadTimeout();
      if (useEmbed) _startHandshakeDeadline();
    } catch (e, st) {
      DebugLogger.error('TourWebView failed to initialize', e, st);
      _controller = null;
      _isLoading = false;
      _hasError = true;
      widget.onLoadingChanged?.call(false);
      widget.onErrorChanged?.call(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError || _controller == null || _validatedUrl == null) {
      if (!widget.showDefaultError) return const SizedBox.shrink();
      return _buildErrorState(context);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        WebViewWidget(
          controller: _controller!,
          gestureRecognizers: WebViewHelper.createInteractiveGestureRecognizers(),
        ),
        if (_isLoading && widget.showDefaultLoading) _buildLoadingState(context),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.public_off, size: 48, color: colorScheme.onSurface.withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            Text(
              'tour_unavailable_title'.tr,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'tour_unavailable_body'.tr,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            // Only offer a retry for a load failure; an unusable URL will
            // fail validation again no matter how often it is tapped.
            if (_validatedUrl != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => setState(_initialize),
                icon: const Icon(Icons.refresh),
                label: Text('retry'.tr),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.85),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppDesign.primaryYellow, strokeWidth: 2),
            const SizedBox(height: 8),
            Text(
              'loading_virtual_tour'.tr,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
