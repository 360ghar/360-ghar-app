import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/paper_cut.dart';

/// Depth of the hand-cut top edge of a sheet (the lip).
const kPaperLip = 12.0;

/// Paints the hand-cut top edge of a full-width sheet in a box [kPaperLip]
/// tall (or taller: the sheet fills the rest below the edge). The edge shows
/// in [edge] 1.5 px proud, so the card's thickness reads; no blur, no rule.
void paintPaperLip(
  Canvas canvas,
  Size size,
  String seed, {
  required Color sheet,
  required Color edge,
}) {
  final band = parsePaperPath(
    cutBandPath(
      seed,
      width: size.width,
      height: kPaperLip,
      segments: math.max(8, (size.width / 28).round()),
    ),
    fillType: PathFillType.nonZero,
  )..addRect(Rect.fromLTWH(0, kPaperLip - 0.5, size.width, size.height - kPaperLip + 0.5));
  canvas.drawPath(band.shift(const Offset(0, -1.5)), Paint()..color = edge);
  canvas.drawPath(band, Paint()..color = sheet);
}

/// The top edge of the white sheet: a band [kPaperLip] tall whose hand-cut
/// edge lets the page show through above it.
class PaperLip extends StatelessWidget {
  const PaperLip({super.key, required this.seed});

  final String seed;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    return SizedBox(
      height: kPaperLip,
      width: double.infinity,
      child: CustomPaint(painter: _LipPainter(seed, design.surface, design.sheetLip)),
    );
  }
}

class _LipPainter extends CustomPainter {
  const _LipPainter(this.seed, this.sheet, this.edge);

  final String seed;
  final Color sheet;
  final Color edge;

  @override
  void paint(Canvas canvas, Size size) =>
      paintPaperLip(canvas, size, seed, sheet: sheet, edge: edge);

  @override
  bool shouldRepaint(_LipPainter old) => old.seed != seed || old.sheet != sheet || old.edge != edge;
}

/// The white card-stock body under a [SceneHeaderSliver] lip: [slivers] on
/// one sheet-coloured surface, so the sheet reads as one piece of paper.
class SheetSliver extends StatelessWidget {
  const SheetSliver({super.key, required this.slivers, this.padding = EdgeInsets.zero});

  final List<Widget> slivers;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => DecoratedSliver(
    decoration: BoxDecoration(color: context.design.surface),
    sliver: SliverPadding(
      padding: padding,
      sliver: SliverMainAxisGroup(slivers: slivers),
    ),
  );
}

/// A sheet as a box, for panes that do not scroll as one list: a hand-cut
/// lip on top, then [child] on the sheet colour.
class PaperSheetBody extends StatelessWidget {
  const PaperSheetBody({super.key, required this.seed, required this.child});

  final String seed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    return CustomPaint(
      painter: _LipPainter(seed, design.surface, design.sheetLip),
      child: Padding(
        padding: const EdgeInsets.only(top: kPaperLip),
        child: child,
      ),
    );
  }
}
