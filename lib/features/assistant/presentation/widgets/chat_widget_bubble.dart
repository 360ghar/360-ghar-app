import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/app_spacing.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/core/utils/webview_helper.dart';
import 'package:ghar360/core/widgets/common/error_states.dart';
import 'package:ghar360/core/widgets/common/loading_states.dart';
import 'package:ghar360/features/assistant/data/assistant_repository.dart';
import 'package:ghar360/features/assistant/data/models/chat_message_model.dart';
import 'package:ghar360/features/assistant/presentation/controllers/assistant_controller.dart';

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

// targetOrigin MUST be '*'. The iframe is sandboxed without allow-same-origin,
// so its document has an opaque origin that no concrete targetOrigin can ever
// match — any other value silently drops every host->widget frame. Safe here:
// the iframe content is injected locally by us, never fetched cross-origin, and
// the inbound listener below still verifies e.source.
function postToWidget(msg){
  try{w.contentWindow.postMessage(msg,'*');}
  catch(x){console.warn('[360Ghar] postToWidget failed',x);}
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
  // The app has no tool route for widgets. Answer a request at once with a JSON-RPC error, so
  // the widget shows its error state now instead of waiting for its 30 s timeout.
  if(d.method==='tools/call'&&d.id!=null){
    postToWidget({jsonrpc:'2.0',id:d.id,error:{code:-32601,
      message:'This action is not available in the app. Ask the assistant instead.'}});
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
  // Any other request that expects an answer gets a method-not-found error, never silence.
  if(d.id!=null&&d.method){
    postToWidget({jsonrpc:'2.0',id:d.id,error:{code:-32601,message:'Method not found'}});
  }
});

window.loadWidget=function(html){
  if(typeof html!=='string')return;
  // The new document has not run bridge.ts yet, so it has not handshaked.
  // Without this reset a reload would post the tool result into a dead
  // document and buffer nothing, leaving the widget stuck on its fallback.
  ready=false;pendingResult=null;
  w.srcdoc=html;
};

window.isReady=function(){return ready;};

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
class ChatWidgetBubble extends ConsumerStatefulWidget {
  final ChatMessageModel message;
  final ValueChanged<String>? onAction;

  const ChatWidgetBubble({super.key, required this.message, this.onAction});

  @override
  ConsumerState<ChatWidgetBubble> createState() => _ChatWidgetBubbleState();
}

class _ChatWidgetBubbleState extends ConsumerState<ChatWidgetBubble> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;
  bool _wrapperInitialized = false;
  Timer? _handshakeTimer;

  int _generation = 0;
  bool _active = true;
  String? _theme;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = TickerMode.valuesOf(context).enabled;
    final theme = Theme.of(context).brightness == Brightness.dark ? 'dark' : 'light';
    if (active && _wrapperInitialized && _theme != theme) {
      unawaited(_controller.runJavaScript("setTheme('$theme');").catchError((Object _) {}));
    }
    _theme = theme;
    if (_active == active) return;
    _active = active;
    ++_generation;
    _handshakeTimer?.cancel();
    if (active) {
      _retry();
    } else {
      unawaited(_controller.runJavaScript("loadWidget('');").catchError((Object _) {}));
    }
  }

  void _retry() {
    ++_generation;
    _handshakeTimer?.cancel();
    setState(() {
      _hasError = false;
      _isLoading = true;
      _wrapperInitialized = false;
    });
    _armLoadTimeout();
    unawaited(_controller.loadHtmlString(_wrapperHtml));
  }

  bool _current(int generation) => mounted && _active && !_hasError && generation == _generation;

  @override
  void dispose() {
    ++_generation;
    _handshakeTimer?.cancel();
    super.dispose();
  }

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
            DebugLogger.warning('Assistant widget WebView failed.');
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
        if (mounted && _active && !_hasError) widget.onAction?.call(text);
      },
    );
    // Load the wrapper page (not the widget directly)
    _armLoadTimeout();
    _controller.loadHtmlString(_wrapperHtml);
  }

  void _armLoadTimeout() {
    final generation = _generation;
    _handshakeTimer?.cancel();
    _handshakeTimer = Timer(const Duration(seconds: 15), () {
      if (_current(generation) && _isLoading) setState(() => _hasError = true);
    });
  }

  /// Called when the wrapper HTML has finished loading.
  /// Fetches the widget HTML and injects it + data into the iframe.
  Future<void> _onWrapperLoaded() async {
    if (!mounted || !_active) return;
    final generation = _generation;
    // onPageFinished can fire more than once; injecting twice would post the
    // tool result into a document that has not handshaked yet.
    if (_wrapperInitialized) return;
    _wrapperInitialized = true;

    final widgetName = widget.message.widgetName;
    if (widgetName == null || !AssistantRepository.isValidWidgetName(widgetName)) {
      DebugLogger.warning('Assistant widget name rejected.');
      setState(() => _hasError = true);
      return;
    }

    try {
      final repository = ref.read(assistantRepositoryProvider);
      final html = await repository.getWidgetHtml(widgetName).timeout(const Duration(seconds: 15));
      if (!_current(generation)) return;
      if (html == null) {
        setState(() => _hasError = true);
        return;
      }

      // Set theme first so the wrapper knows the theme before handshake
      if (!mounted) return;
      final isDark = Theme.of(context).brightness == Brightness.dark;
      await _controller.runJavaScript("setTheme('${isDark ? 'dark' : 'light'}');");
      if (!_current(generation)) return;

      // Load widget HTML into the iframe
      await _controller.runJavaScript('loadWidget(${jsonEncode(html)});');
      if (!_current(generation)) return;

      // Inject structured data (wrapper buffers until handshake completes)
      final data = widget.message.widgetData;
      if (data != null) {
        await _controller.runJavaScript('injectToolResult(${jsonEncode(data)});');
      }
      if (!_current(generation)) return;

      setState(() => _isLoading = false);
      _scheduleHandshakeCheck();
    } catch (e) {
      DebugLogger.warning('Assistant widget failed.', e.runtimeType);
      if (_current(generation)) setState(() => _hasError = true);
    }
  }

  /// The widget renders its own "loading" fallback until the bridge handshake
  /// completes and the tool result lands. If that never happens it would sit
  /// there forever, so fall back to the error state instead.
  void _scheduleHandshakeCheck({int attempt = 1}) {
    final generation = _generation;
    // Generous, and retried once: a cold mid-range device parsing a ~150KB
    // srcdoc bundle can legitimately take several seconds, and flipping a
    // healthy widget to the error state would be worse than a slow render.
    _handshakeTimer?.cancel();
    _handshakeTimer = Timer(Duration(seconds: attempt == 1 ? 6 : 8), () async {
      if (!_current(generation)) return;
      try {
        final ready = await _controller.runJavaScriptReturningResult('isReady()');
        if (!_current(generation)) return;
        // JS booleans serialize as bool | 'true' | 1 depending on the platform
        // WebView; accept all three rather than normalising per-platform.
        if (ready == true || ready == 'true' || ready == 1) return;
        if (attempt == 1) {
          _scheduleHandshakeCheck(attempt: 2);
          return;
        }
        DebugLogger.warning('Assistant widget handshake timed out.');
      } catch (e) {
        DebugLogger.warning('Assistant widget handshake failed.', e.runtimeType);
      }
      if (_current(generation)) setState(() => _hasError = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.design;

    // A failed widget shrinks to one line; the reply text above still answers.
    if (_hasError) {
      return Padding(
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
        child: ErrorStates.inlineError(
          message: context.l10n.text('assistant_widget_unavailable'),
          onRetry: _retry,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
        child: Container(
          height: 400,
          color: palette.surface,
          child: Stack(
            children: [
              WebViewWidget(
                controller: _controller,
                gestureRecognizers: WebViewHelper.createInteractiveGestureRecognizers(),
              ),
              if (_isLoading) _buildLoadingOverlay(palette),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay(AppPalette palette) {
    return Positioned.fill(
      child: ColoredBox(
        color: palette.surface,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LoadingStates.buttonSpinner(size: 22, color: palette.accent),
              const SizedBox(height: 10),
              Text(
                context.l10n.text('assistant_loading_widget'),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: palette.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
