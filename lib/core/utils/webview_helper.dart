import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';

class WebViewHelper {
  static bool _isInitialized = false;

  static bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Initialize WebView platform if not already done
  static void ensureInitialized() {
    if (_isInitialized) return;

    try {
      if (kIsWeb) {
        // For web, we need to register the web platform
        // This is handled automatically by webview_flutter_web when imported
        DebugLogger.success('WebView platform initialized for web');
      } else {
        // For mobile platforms (iOS/Android), initialization is automatic
        DebugLogger.success('WebView platform initialized for mobile');
      }
      _isInitialized = true;
    } catch (e) {
      DebugLogger.warning('WebView platform initialization failed: ${e.runtimeType}');
    }
  }

  /// Returns a [WebViewController] configured with platform specific defaults
  /// (hybrid composition on Android) so gesture handling works consistently.
  static WebViewController createBaseController({
    void Function(WebViewPermissionRequest request)? onPermissionRequest,
  }) {
    ensureInitialized();

    final PlatformWebViewControllerCreationParams params = _isAndroid
        ? AndroidWebViewControllerCreationParams()
        : const PlatformWebViewControllerCreationParams();

    final controller = WebViewController.fromPlatformCreationParams(
      params,
      onPermissionRequest: onPermissionRequest,
    );

    if (_isAndroid) {
      unawaited(
        AndroidWebViewController.enableDebugging(kDebugMode).catchError((Object error) {
          DebugLogger.warning('WebView debug setting failed: ${error.runtimeType}');
        }),
      );
    }

    return controller;
  }

  /// Builds a gesture recognizer set that eagerly hands pointer events to the
  /// underlying WebView (useful when nested in scrollable parents).
  static Set<Factory<OneSequenceGestureRecognizer>> createInteractiveGestureRecognizers() {
    return {Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer())};
  }

  /// Create a WebView controller with proper error handling
  static WebViewController createController({
    required String url,
    Function(String)? onPageStarted,
    Function(String)? onPageFinished,
    Function(WebResourceError)? onWebResourceError,
  }) {
    final controller = createBaseController();

    try {
      controller
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: onPageStarted,
            onPageFinished: onPageFinished,
            onWebResourceError:
                onWebResourceError ??
                (WebResourceError error) {
                  DebugLogger.warning('WebView resource failed: ${error.errorCode}');
                },
          ),
        )
        ..loadRequest(Uri.parse(url));

      return controller;
    } catch (e) {
      DebugLogger.error('Error creating WebView controller: ${e.runtimeType}');
      rethrow;
    }
  }

  /// Create a safe WebView widget with error handling
  static Widget createSafeWebView({
    required BuildContext context,
    required String url,
    double? width,
    double? height,
    Function(String)? onPageStarted,
    Function(String)? onPageFinished,
    Widget? errorWidget,
  }) {
    try {
      ensureInitialized();

      final controller = createController(
        url: url,
        onPageStarted: onPageStarted,
        onPageFinished: onPageFinished,
        onWebResourceError: (error) {
          DebugLogger.warning('WebView resource failed: ${error.errorCode}');
        },
      );

      return SizedBox(
        width: width,
        height: height,
        child: WebViewWidget(
          controller: controller,
          gestureRecognizers: createInteractiveGestureRecognizers(),
        ),
      );
    } catch (e) {
      DebugLogger.error('Error creating safe WebView: ${e.runtimeType}');
      return errorWidget ?? _buildErrorWidget(context, width, height, url);
    }
  }

  /// Build error widget when WebView fails
  static Widget _buildErrorWidget(BuildContext context, double? width, double? height, String url) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PaperIcon(KnifeIcon.alert, size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            context.l10n.text('tour_unavailable_title'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.text('tour_unavailable_body'),
            style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          if (kIsWeb)
            TextButton(
              onPressed: () async {
                final uri = Uri.tryParse(url);
                if (uri == null || !['http', 'https'].contains(uri.scheme)) return;
                try {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } catch (error, stack) {
                  DebugLogger.warning('Could not open tour', error.runtimeType, stack);
                }
              },
              child: Text(context.l10n.text('open_in_new_tab')),
            ),
        ],
      ),
    );
  }

  /// Check if WebView is supported on current platform
  static bool get isSupported {
    ensureInitialized();
    return _isInitialized;
  }
}
