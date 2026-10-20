import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/paper_chrome.dart';
import 'package:ghar360/core/widgets/paper/scene_header_sliver.dart';
import 'package:ghar360/core/widgets/paper/sheet_sliver.dart';

/// The side gutter that keeps content at most [maxWidth] wide and centred in
/// [width], and never closer than [min] to an edge.
double paperGutter(double width, double maxWidth, {double min = 20}) =>
    math.max(min, (width - maxWidth) / 2);

/// A hand-cut strip of card stock filled by width: profile completion,
/// checklist progress, a principal/interest split. The fill is the same cut
/// strip revealed from the start edge, so its ends never change shape. A new
/// [value] slides the fill from the previous one; the first frame shows
/// [value], and with reduced motion it jumps.
///
/// Decorative: the caller says the value in words.
class CutStrip extends StatelessWidget {
  const CutStrip({
    super.key,
    required this.value,
    required this.seed,
    required this.color,
    this.track,
    this.height = 10,
  });

  /// The filled share, 0 to 1.
  final double value;
  final String seed;
  final Color color;

  /// The unfilled strip; the mint slip when null.
  final Color? track;
  final double height;

  @override
  Widget build(BuildContext context) {
    final shape = CutBorder(seed: seed, amp: 1.2);
    final trackColor = track ?? context.design.slip;
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            Widget strip(Color color) => SizedBox(
              width: constraints.maxWidth,
              height: height,
              child: DecoratedBox(
                decoration: ShapeDecoration(color: color, shape: shape),
              ),
            );
            return TweenAnimationBuilder<double>(
              tween: Tween(end: value.clamp(0.0, 1.0)),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 450),
              curve: Curves.easeOutCubic,
              builder: (context, shown, _) => Stack(
                children: [
                  strip(trackColor),
                  ClipRect(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      widthFactor: shown,
                      child: strip(color),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The hand-cut bottom edge of a sheet that ends on the sky: the sheet's lip
/// turned over, in the sheet colour only (no proud edge line, which would
/// read as a rule when the foot lies over more paper). Place it right under
/// the sheet's last content, or pinned under a header bar.
class SheetFoot extends StatelessWidget {
  const SheetFoot({super.key, required this.seed});

  final String seed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: kPaperLip,
    width: double.infinity,
    child: CustomPaint(painter: _FootPainter(seed, context.design.surface)),
  );
}

class _FootPainter extends CustomPainter {
  const _FootPainter(this.seed, this.sheet);

  final String seed;
  final Color sheet;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..translate(0, size.height)
      ..scale(1, -1);
    paintPaperLip(canvas, size, seed, sheet: sheet, edge: sheet);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FootPainter old) => old.seed != seed || old.sheet != sheet;
}

/// A scroll view of sheets on the sky under a [SceneHeaderSliver]. A cut
/// band rides on the foot of the header, so where the sky scrolls under the
/// bar the sheet's edge still reads hand-cut, never a straight line. Over a
/// sheet the band is white on white and does not show; it covers the first
/// [kPaperLip] pixels under the header, so pad the first sheet's content by more.
class SkySheetsScrollView extends StatefulWidget {
  const SkySheetsScrollView({
    super.key,
    required this.header,
    required this.seed,
    required this.slivers,
  });

  final SceneHeaderSliver header;
  final String seed;

  /// The slivers after the header.
  final List<Widget> slivers;

  @override
  State<SkySheetsScrollView> createState() => _SkySheetsScrollViewState();
}

class _SkySheetsScrollViewState extends State<SkySheetsScrollView> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final header = widget.header;
      final extents = SceneHeaderSliver.extentsFor(
        context,
        width: constraints.maxWidth,
        scene: header.scene,
        title: header.title,
        tabs: header.tabs,
      );
      return Stack(
        children: [
          CustomScrollView(controller: _controller, slivers: [header, ...widget.slivers]),
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => Positioned(
              top: math.max(
                extents.min,
                extents.max - (_controller.hasClients ? _controller.offset : 0),
              ),
              left: 0,
              right: 0,
              child: IgnorePointer(child: SheetFoot(seed: widget.seed)),
            ),
          ),
        ],
      );
    },
  );
}
