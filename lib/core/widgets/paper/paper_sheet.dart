import 'package:flutter/widgets.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/paper_chrome.dart';

/// A hand-cut sheet of card stock with a short shadow on the surface below.
/// The child is never clipped: [padding] keeps it clear of the cut.
class PaperSheet extends StatelessWidget {
  const PaperSheet({
    super.key,
    required this.seed,
    required this.child,
    this.elevation = PaperElevation.mid,
    this.color,
    this.padding = const EdgeInsets.all(16),
    this.amp = 2,
  });

  final String seed;
  final Widget child;
  final PaperElevation elevation;

  /// Sheet colour; the theme surface when null.
  final Color? color;
  final EdgeInsets padding;

  /// Deepest cut in pixels. Every side of [padding] must be larger.
  final double amp;

  @override
  Widget build(BuildContext context) {
    assert(
      [padding.left, padding.top, padding.right, padding.bottom].every((side) => side > amp),
      'PaperSheet padding must clear the cut on every side.',
    );
    final design = context.design;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: color ?? design.surface,
        shape: CutBorder(
          seed: seed,
          amp: amp,
          shadows: paperShadows(elevation, design.shadowOn(design.background)),
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
