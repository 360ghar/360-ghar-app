import 'package:flutter/material.dart';
import 'package:ghar360/core/widgets/common/tour_webview.dart';

/// Embeds a 360° virtual tour WebView for the swipe card.
///
/// Thin wrapper over the shared [TourWebView] so discover keeps a stable API.
class EmbeddedSwipe360Tour extends StatelessWidget {
  final String tourUrl;

  const EmbeddedSwipe360Tour({super.key, required this.tourUrl});

  @override
  Widget build(BuildContext context) {
    return TourWebView(tourUrl: tourUrl);
  }
}
