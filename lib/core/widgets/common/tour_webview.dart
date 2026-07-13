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
  WebViewController? _controller;
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
    if (oldWidget.tourUrl != widget.tourUrl ||
        oldWidget.bodyBackgroundCss != widget.bodyBackgroundCss) {
      setState(_initialize);
    }
  }

  void _setLoading(bool value) {
    if (!mounted) return;
    setState(() => _isLoading = value);
    widget.onLoadingChanged?.call(value);
  }

  void _setError(bool value) {
    if (!mounted) return;
    setState(() => _hasError = value);
    widget.onErrorChanged?.call(value);
  }

  void _initialize() {
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
              _setLoading(false);
              if (kReleaseMode) {
                _controller?.runJavaScript(TourUrl.consoleSilencerJs);
              }
              if (widget.applyPageChromeStyles) {
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
            },
            onWebResourceError: (error) {
              DebugLogger.warning('TourWebView error: ${error.description}');
              _setLoading(false);
              _setError(true);
            },
          ),
        );

      _controller = controller;
      _hasError = false;
      _isLoading = true;

      if (TourUrl.isKuula(validated) || TourUrl.isAllowedEmbedHost(validated)) {
        final html = TourUrl.buildIframeEmbedHtml(
          tourUrl: validated,
          bodyBackground: widget.bodyBackgroundCss,
          silenceConsole: kReleaseMode,
        );
        controller.loadHtmlString(html);
      } else {
        controller.loadRequest(Uri.parse(validated));
      }
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
