import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/core/utils/webview_helper.dart';
import 'package:ghar360/features/assistant/data/assistant_repository.dart';
import 'package:ghar360/features/assistant/data/models/chat_message_model.dart';
import 'package:ghar360/features/assistant/presentation/controllers/assistant_controller.dart';
import 'package:shimmer/shimmer.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Wrapper HTML that acts as an MCP host for widget iframes.
///
/// The widget bridge (`bridge.ts`) requires `window.parent !== window` to
/// detect MCP Apps mode and start the initialization handshake. Loading widget
/// HTML directly into a Flutter WebView makes it the top-level page, so the
/// bridge detects `HOST = 'standalone'` and never registers its message
/// listener.
///
/// This wrapper creates an `<iframe>`, loads the widget inside it, and
/// responds to the MCP `ui/initialize` handshake. Flutter injects data via
/// `runJavaScript()` calling the wrapper's global functions.
const String _wrapperHtml = '''
<!DOCTYPE html><html><head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
<style>*{margin:0;padding:0}html,body,iframe{width:100%;height:100%;border:none;overflow:hidden;background:transparent}</style>
</head><body>
<iframe id="w" sandbox="allow-scripts"></iframe>
<script>
var w=document.getElementById('w'),ready=false,theme='light',pendingResult=null;
var MAX_ACTION_LEN=500;

function postToWidget(msg){
  try{w.contentWindow.postMessage(msg,location.origin||'*');}catch(x){}
}

window.addEventListener('message',function(e){
  if(e.source!==w.contentWindow)return;
  // srcdoc iframes report a null/opaque origin in some WebViews; still require source match.
  var d=e.data;
  if(!d||d.jsonrpc!=='2.0')return;
  if(d.method==='ui/initialize'&&d.id!=null){
    postToWidget({jsonrpc:'2.0',id:d.id,result:{
      protocolVersion:'2026-01-26',
      serverInfo:{name:'ghar360-app',version:'1.0.0'},
      hostContext:{theme:theme}
    }});
    ready=true;
    if(pendingResult){postToWidget(pendingResult);pendingResult=null;}
    return;
  }
  if(d.method==='ui/message'&&d.id!=null){
    var text='';
    try{text=d.params.content[0].text;}catch(x){}
    if(typeof text==='string'&&text.length>0&&text.length<=MAX_ACTION_LEN){
      WidgetAction.postMessage(text);
    }
    postToWidget({jsonrpc:'2.0',id:d.id,result:{success:true}});
    return;
  }
});

window.loadWidget=function(html){
  if(typeof html!=='string')return;
  w.srcdoc=html;
};

window.injectToolResult=function(data){
  var msg={jsonrpc:'2.0',method:'ui/notifications/tool-result',
    params:{structuredContent:data,_meta:null}};
  if(ready){postToWidget(msg);}
  else{pendingResult=msg;}
};

window.setTheme=function(t){
  if(t!=='dark'&&t!=='light')return;
  theme=t;
  if(ready){postToWidget({jsonrpc:'2.0',
    method:'ui/notifications/host-context-changed',params:{theme:t}});}
};
</script></body></html>
''';

/// Renders an interactive HTML widget inline in the chat using WebView.
///
/// Loads a wrapper page that hosts the widget in an iframe, providing the
/// real `window.parent` relationship the MCP Apps protocol requires.
class ChatWidgetBubble extends StatefulWidget {
  final ChatMessageModel message;

  const ChatWidgetBubble({super.key, required this.message});

  @override
  State<ChatWidgetBubble> createState() => _ChatWidgetBubbleState();
}

class _ChatWidgetBubbleState extends State<ChatWidgetBubble> with AutomaticKeepAliveClientMixin {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewHelper.createBaseController();
    _controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => _onWrapperLoaded(),
          onWebResourceError: (error) {
            DebugLogger.warning('Widget WebView error: ${error.description}');
            if (mounted) setState(() => _hasError = true);
          },
        ),
      );
    // Bridge widget button actions back to the chat (length-capped).
    _controller.addJavaScriptChannel(
      'WidgetAction',
      onMessageReceived: (message) {
        final text = message.message.trim();
        if (text.isEmpty || text.length > 500) return;
        if (!Get.isRegistered<AssistantController>()) return;
        Get.find<AssistantController>().sendMessage(text);
      },
    );
    // Load the wrapper page (not the widget directly)
    _controller.loadHtmlString(_wrapperHtml);
  }

  /// Called when the wrapper HTML has finished loading.
  /// Fetches the widget HTML and injects it + data into the iframe.
  Future<void> _onWrapperLoaded() async {
    if (!mounted) return;

    final widgetName = widget.message.widgetName;
    if (widgetName == null || !AssistantRepository.isValidWidgetName(widgetName)) {
      DebugLogger.warning('ChatWidgetBubble rejected widget name: $widgetName');
      setState(() => _hasError = true);
      return;
    }

    try {
      final repository = Get.find<AssistantRepository>();
      final html = await repository.getWidgetHtml(widgetName);
      if (!mounted) return;
      if (html == null) {
        setState(() => _hasError = true);
        return;
      }

      // Set theme first so the wrapper knows the theme before handshake
      final isDark = Theme.of(context).brightness == Brightness.dark;
      await _controller.runJavaScript("setTheme('${isDark ? 'dark' : 'light'}');");
      if (!mounted) return;

      // Load widget HTML into the iframe
      await _controller.runJavaScript('loadWidget(${jsonEncode(html)});');
      if (!mounted) return;

      // Inject structured data (wrapper buffers until handshake completes)
      final data = widget.message.widgetData;
      if (data != null) {
        await _controller.runJavaScript('injectToolResult(${jsonEncode(data)});');
      }
      if (!mounted) return;

      setState(() => _isLoading = false);
    } catch (e) {
      DebugLogger.error('Failed to load widget', e);
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final palette = context.design;

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 400,
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.border.withValues(alpha: 0.5)),
          ),
          child: _buildContent(palette),
        ),
      ),
    );
  }

  Widget _buildContent(AppPalette palette) {
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.widgets_outlined, size: 36, color: palette.textTertiary),
            const SizedBox(height: 8),
            Text(
              'assistant_widget_unavailable'.tr,
              style: TextStyle(fontSize: 13, color: palette.textSecondary),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        WebViewWidget(
          controller: _controller,
          gestureRecognizers: WebViewHelper.createInteractiveGestureRecognizers(),
        ),
        if (_isLoading) _buildLoadingOverlay(palette),
      ],
    );
  }

  Widget _buildLoadingOverlay(AppPalette palette) {
    return Positioned.fill(
      child: Container(
        color: palette.surface,
        child: Center(
          child: Shimmer.fromColors(
            baseColor: palette.textTertiary,
            highlightColor: palette.textSecondary,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.widgets_outlined, size: 36, color: palette.textTertiary),
                const SizedBox(height: 8),
                Text(
                  'assistant_loading_widget'.tr,
                  style: TextStyle(fontSize: 13, color: palette.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
