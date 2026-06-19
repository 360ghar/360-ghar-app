import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/utils/app_toast.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/core/utils/webview_helper.dart';
import 'package:ghar360/core/widgets/common/max_content_width.dart';
import 'package:webview_flutter/webview_flutter.dart';

class TourView extends StatefulWidget {
  const TourView({super.key});

  @override
  State<TourView> createState() => _TourViewState();
}

class _TourViewState extends State<TourView> {
  WebViewController? controller;
  bool isLoading = true;
  String? _tourUrl;

  @override
  void initState() {
    super.initState();
    _tourUrl = _extractTourUrl(Get.arguments);
    if (_tourUrl == null) {
      isLoading = false;
      DebugLogger.warning('TourView received invalid route arguments: ${Get.arguments}');
      return;
    }

    final tourUrl = _tourUrl!;
    // Respect the app theme for the WebView background so the tour doesn't
    // show a jarring black backdrop in light mode (Improvement 8).
    final isDark = Get.theme.brightness == Brightness.dark;
    final bodyBackground = isDark ? '#000' : '#fff';
    final webviewBackgroundColor = isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    const consoleSilencer = '''
      if (window && window.console) {
        window.console.log = function() {};
        window.console.warn = function() {};
        window.console.error = function() {};
        window.console.info = function() {};
        window.console.debug = function() {};
      }
    ''';

    controller = WebViewHelper.createBaseController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(webviewBackgroundColor)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (!mounted) return;
            setState(() {
              isLoading = true;
            });
            controller?.runJavaScript(consoleSilencer);
          },
          onPageFinished: (String url) {
            if (!mounted) return;
            setState(() {
              isLoading = false;
            });
            controller?.runJavaScript(consoleSilencer);
            controller?.runJavaScript('''
              document.body.style.margin = '0';
              document.body.style.padding = '0';
              document.body.style.background = '$bodyBackground';
              var iframes = document.getElementsByTagName('iframe');
              for (var i = 0; i < iframes.length; i++) {
                iframes[i].style.width = '100%';
                iframes[i].style.height = '100vh';
                iframes[i].style.border = 'none';
              }
            ''');
          },
          onWebResourceError: (WebResourceError error) {
            if (!mounted) return;
            setState(() {
              isLoading = false;
            });
            AppToast.error('error_loading_tour'.tr, 'check_internet_connection'.tr);
          },
        ),
      );

    if (tourUrl.contains('kuula.co')) {
      final htmlContent =
          '''
        <!DOCTYPE html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <style>
            body { margin: 0; padding: 0; background: $bodyBackground; }
            iframe { width: 100vw; height: 100vh; border: none; }
          </style>
          <script type="text/javascript">
            $consoleSilencer
          </script>
        </head>
        <body>
          <iframe class="ku-embed" frameborder="0"
                  allow="xr-spatial-tracking; gyroscope; accelerometer"
                  allowfullscreen scrolling="no"
                  src="$tourUrl">
          </iframe>
        </body>
        </html>
      ''';
      controller?.loadHtmlString(htmlContent);
    } else {
      controller?.loadRequest(Uri.parse(tourUrl));
    }
  }

  @override
  void dispose() {
    // Release the WebViewController reference so it can be garbage-collected.
    // webview_flutter 4.x does not expose a public dispose() on
    // WebViewController; the underlying platform WebView is torn down when
    // the WebViewWidget leaves the tree (its StatefulWidget disposes).
    // Clearing the field avoids retaining a dangling controller across
    // repeated tour navigations, which previously accumulated WebView
    // instances in memory.
    controller = null;
    super.dispose();
  }

  String? _extractTourUrl(dynamic args) {
    String? candidate;
    if (args is String) {
      candidate = args;
    } else if (args is Map) {
      candidate = args['tourUrl']?.toString() ?? args['url']?.toString();
    }

    if (candidate == null || candidate.trim().isEmpty) return null;
    final uri = Uri.tryParse(candidate.trim());
    if (uri == null) return null;
    if (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }
    return candidate.trim();
  }

  Widget _buildInvalidTourContent() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.link_off, size: 48, color: AppDesign.textSecondary),
            const SizedBox(height: 12),
            Text(
              'unable_to_open_link'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppDesign.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'check_internet_connection'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppDesign.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: () => Get.back(), child: Text('back'.tr)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_tourUrl == null) {
      return Scaffold(
        key: const ValueKey('qa.tour.screen'),
        backgroundColor: AppDesign.scaffoldBackground,
        appBar: AppBar(
          backgroundColor: AppDesign.appBarBackground,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppDesign.appBarIcon),
            onPressed: () => Get.back(),
          ),
          title: Text(
            'virtual_tour_title'.tr,
            style: TextStyle(color: AppDesign.appBarText, fontWeight: FontWeight.bold),
          ),
        ),
        body: Semantics(label: 'qa.tour.invalid_state', child: _buildInvalidTourContent()),
      );
    }

    return Scaffold(
      key: const ValueKey('qa.tour.screen'),
      backgroundColor: AppDesign.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppDesign.appBarBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppDesign.appBarIcon),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'virtual_tour_title'.tr,
          style: TextStyle(color: AppDesign.appBarText, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.fullscreen, color: AppDesign.appBarIcon),
            onPressed: () {
              AppToast.info('fullscreen_mode'.tr, 'rotate_device_better_experience'.tr);
            },
          ),
          IconButton(
            icon: Icon(Icons.share, color: AppDesign.appBarIcon),
            onPressed: () {
              AppToast.info('share_tour'.tr, 'tour_link_copied'.tr);
            },
          ),
        ],
      ),
      body: Container(
        color: AppDesign.scaffoldBackground,
        child: Stack(
          children: [
            // WebView with enhanced iframe support. On tablet/desktop widths the
            // tour is capped + centered so the 360° viewport stays usable
            // rather than stretching absurdly wide; on compact it is full-bleed
            // (MaxContentWidth is a no-op there).
            MaxContentWidth(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: AppDesign.getCardShadow(),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Semantics(
                      label: 'qa.tour.webview',
                      identifier: 'qa.tour.webview',
                      child: WebViewWidget(
                        controller: controller!,
                        gestureRecognizers: WebViewHelper.createInteractiveGestureRecognizers(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Loading indicator
            if (isLoading)
              Container(
                color: AppDesign.scaffoldBackground,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(
                        color: AppDesign.primaryYellow,
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'loading_virtual_tour'.tr,
                        style: TextStyle(
                          fontSize: 16,
                          color: AppDesign.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
