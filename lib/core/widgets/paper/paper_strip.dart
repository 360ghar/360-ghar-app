import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/paper_cut.dart';

/// A strip of card stock with a hand-cut leading edge: the top of a bottom
/// bar, or the right side of a rail when [vertical]. The edge shows in the
/// edge tone 1.5 px proud, so the card's thickness reads; no blur, no rule.
///
/// Pad the [child] by [cut] on the cut side.
class PaperStrip extends StatelessWidget {
  const PaperStrip({super.key, required this.seed, this.vertical = false, required this.child});

  /// Depth of the hand-cut edge.
  static const double cut = 10;

  final String seed;
  final bool vertical;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    return RepaintBoundary(
      child: CustomPaint(
        painter: _StripPainter(
          seed: seed,
          vertical: vertical,
          sheet: design.surface,
          edge: design.border,
        ),
        child: child,
      ),
    );
  }
}

class _StripPainter extends CustomPainter {
  const _StripPainter({
    required this.seed,
    required this.vertical,
    required this.sheet,
    required this.edge,
  });

  final String seed;
  final bool vertical;
  final Color sheet;
  final Color edge;

  @override
  void paint(Canvas canvas, Size size) {
    // Draw a horizontal strip; a rail is the same strip turned on its side.
    final length = vertical ? size.height : size.width;
    final depth = vertical ? size.width : size.height;
    canvas.save();
    if (vertical) {
      canvas.translate(size.width, 0);
      canvas.rotate(math.pi / 2);
    }
    final band = parsePaperPath(
      cutBandPath(
        seed,
        width: length,
        height: PaperStrip.cut,
        segments: math.max(6, (length / 32).round()),
      ),
      fillType: PathFillType.nonZero,
    )..addRect(Rect.fromLTWH(0, PaperStrip.cut - 0.5, length, depth - PaperStrip.cut + 0.5));
    canvas.drawPath(band.shift(const Offset(0, -1.5)), Paint()..color = edge);
    canvas.drawPath(band, Paint()..color = sheet);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StripPainter old) =>
      old.seed != seed || old.vertical != vertical || old.sheet != sheet || old.edge != edge;
}
