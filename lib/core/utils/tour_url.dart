import 'dart:convert';

/// Shared validation and embedding helpers for 360° tour URLs.
///
/// All tour surfaces (full-screen [TourView], swipe embeds, property cards)
/// must go through this type so scheme checks and HTML escaping cannot diverge.
class TourUrl {
  TourUrl._();

  /// Host suffixes allowed for iframe embeds (Kuula and common CDNs).
  /// Direct [loadRequest] is still limited to http(s) via [validate].
  static const Set<String> embedHostAllowlist = {'kuula.co', 'cdn.kuula.co'};

  /// Extracts a candidate tour URL from GetX route [args] (String or Map).
  static String? extractFromArgs(dynamic args) {
    String? candidate;
    if (args is String) {
      candidate = args;
    } else if (args is Map) {
      candidate = args['tourUrl']?.toString() ?? args['url']?.toString();
    }
    return validate(candidate);
  }

  /// Returns a trimmed http(s) URL, or null if the value is unsafe/invalid.
  static String? validate(String? raw) {
    if (raw == null) return null;
    final candidate = raw.trim();
    if (candidate.isEmpty) return null;

    final uri = Uri.tryParse(candidate);
    if (uri == null) return null;
    if (!uri.hasScheme) return null;

    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return null;

    // Reject credentials-in-URL and empty hosts.
    if (uri.host.isEmpty) return null;
    if (uri.userInfo.isNotEmpty) return null;

    return candidate;
  }

  /// Whether [url] may be loaded or navigated to inside a tour WebView.
  ///
  /// Allows WebView bootstrap URLs used by [loadHtmlString] (`about:blank`,
  /// `about:srcdoc`), hosts on [embedHostAllowlist] / Kuula, and (when
  /// [allowedOriginUrl] is set) the same full origin as the initially validated tour.
  /// Rejects arbitrary third-party https redirects, `javascript:`, `data:`,
  /// `file:`, and credentialed URLs.
  static bool isAllowedNavigation(String url, {String? allowedOriginUrl}) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return false;
    final lower = trimmed.toLowerCase();
    // Required for loadHtmlString / iframe srcdoc bootstrap; not user content.
    if (lower == 'about:blank' || lower.startsWith('about:srcdoc')) {
      return true;
    }

    final validated = validate(trimmed);
    if (validated == null) return false;

    // Primary embed providers (Kuula CDN, etc.).
    if (isAllowedEmbedHost(validated)) return true;

    final origin = allowedOriginUrl;
    if (origin != null && origin.isNotEmpty) {
      final originValidated = validate(origin);
      if (originValidated == null) return false;
      final originUri = Uri.tryParse(originValidated);
      final navUri = Uri.tryParse(validated);
      if (originUri == null || navUri == null) return false;
      final originPort = originUri.hasPort ? originUri.port : _defaultPort(originUri.scheme);
      final navPort = navUri.hasPort ? navUri.port : _defaultPort(navUri.scheme);
      if (originUri.scheme.toLowerCase() == navUri.scheme.toLowerCase() &&
          originUri.host.toLowerCase() == navUri.host.toLowerCase() &&
          originPort == navPort) {
        return true;
      }
    }

    return false;
  }

  static int _defaultPort(String scheme) => scheme.toLowerCase() == 'https' ? 443 : 80;

  /// Restricts CSS/JS color interpolation to safe hex tokens.
  static String sanitizeCssColor(String color, {String fallback = '#f0f0f0'}) {
    final trimmed = color.trim();
    if (RegExp(r'^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').hasMatch(trimmed)) {
      return trimmed;
    }
    return fallback;
  }

  static bool isKuula(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    return host == 'kuula.co' || host.endsWith('.kuula.co');
  }

  /// True when the host is on the embed allowlist (exact or subdomain).
  static bool isAllowedEmbedHost(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    for (final allowed in embedHostAllowlist) {
      if (host == allowed || host.endsWith('.$allowed')) return true;
    }
    // Kuula is the primary embed provider; keep subdomain match.
    if (isKuula(url)) return true;
    return false;
  }

  /// HTML-attribute-safe encoding for embedding a URL in `src="..."`.
  static String htmlAttributeEscape(String url) => htmlEscape.convert(url);

  /// Posted as the embed document parses, before the iframe does anything.
  /// Its arrival proves the JS channel itself works on this device.
  static const String embedReadyMessage = 'ready';

  /// Message posted by the embed shell once the iframe has loaded.
  static const String embedLoadedMessage = 'loaded';

  /// Message posted by the embed shell when the iframe fails to load.
  static const String embedFailedMessage = 'failed';

  /// The channel name is interpolated into an HTML attribute and an inline
  /// script, so only a bare JS identifier is accepted; anything else is
  /// dropped entirely rather than emitted raw.
  static String? _safeChannelName(String? channelName) {
    if (channelName == null) return null;
    return RegExp(r'^[A-Za-z_$][A-Za-z0-9_$]*$').hasMatch(channelName) ? channelName : null;
  }

  /// Builds the Kuula-style iframe shell used by all embed surfaces.
  ///
  /// When [loadSignalChannel] is set, the document posts [embedReadyMessage] as
  /// it parses and the iframe reports its load outcome to the same JS channel.
  /// The wrapper document itself always finishes loading, so the iframe signal
  /// is the only thing that distinguishes a live tour from a dead embed — and
  /// the ready probe is the only thing that distinguishes a dead embed from a
  /// channel that does not work on this device.
  static String buildIframeEmbedHtml({
    required String tourUrl,
    String bodyBackground = '#f0f0f0',
    bool silenceConsole = false,
    String? loadSignalChannel,
  }) {
    final sanitizedUrl = htmlAttributeEscape(tourUrl);
    final safeBg = sanitizeCssColor(bodyBackground);
    final consoleSilencer = silenceConsole ? _consoleSilencer : '';
    final channel = _safeChannelName(loadSignalChannel);
    final loadSignal = channel == null
        ? ''
        : '\n          onload="$channel.postMessage(\'$embedLoadedMessage\')"'
              '\n          onerror="$channel.postMessage(\'$embedFailedMessage\')"';
    final readyProbe = channel == null
        ? ''
        : "\n    try { $channel.postMessage('$embedReadyMessage'); } catch (e) {}";
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body { margin: 0; padding: 0; background: $safeBg; overflow: hidden; }
    iframe { width: 100vw; height: 100vh; border: none; display: block; }
  </style>
  <script type="text/javascript">
    $consoleSilencer$readyProbe
  </script>
</head>
<body>
  <iframe class="ku-embed"
          frameborder="0"
          allow="xr-spatial-tracking; gyroscope; accelerometer"
          allowfullscreen
          scrolling="no"$loadSignal
          src="$sanitizedUrl">
  </iframe>
</body>
</html>
''';
  }

  static const String _consoleSilencer = '''
if (window && window.console) {
  window.console.log = function() {};
  window.console.warn = function() {};
  window.console.error = function() {};
  window.console.info = function() {};
  window.console.debug = function() {};
}
''';

  /// JS snippet used after page load to silence console noise in release.
  static String get consoleSilencerJs => _consoleSilencer;
}
