import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/paper_cut.dart';
import 'package:ghar360/core/widgets/paper/sheet_sliver.dart';

/// Index tabs cut into the top edge of the sheet. The chosen tab is the
/// sheet's own card stock, so it merges into the sheet; the others stand
/// behind it in a slightly darker stock. The chosen shape slides to a new tab
/// (250 ms; it jumps with reduced motion). Labels wrap to two lines when
/// they must, and the tabs grow; every tab is at least 48 px tall.
///
/// The widget includes the sheet's hand-cut lip under the tabs, so it can sit
/// at the bottom of a [SceneHeaderSliver] or on its own above a sheet.
class FolderTabs extends StatelessWidget {
  const FolderTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelect,
    this.qaIds = const [],
    this.seed = 'tabs',
  }) : assert(labels.length > 1);

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  /// Keys and Semantics identifiers of the tabs, by index.
  final List<String> qaIds;

  /// Seed of the hand-cut edges.
  final String seed;

  static const _gutter = 16.0;
  static const _slant = 10.0;
  static const _labelInset = _slant + 8;
  static const _minBody = 44.0;

  /// Labels grow with the text scale up to this factor, like the nav labels.
  static const maxLabelScale = 1.5;

  static TextStyle _style(BuildContext context) =>
      Theme.of(context).textTheme.labelLarge!.copyWith(fontWeight: FontWeight.w800);

  /// The height of the tabs plus the lip for [labels] at [width], with the
  /// current text scale.
  static double heightFor(BuildContext context, List<String> labels, double width) =>
      _bodyHeight(context, labels, width) + kPaperLip;

  static double _bodyHeight(BuildContext context, List<String> labels, double width) {
    final tab = (width - 2 * _gutter) / labels.length;
    var tallest = 0.0;
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: _style(context)),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: maxLabelScale),
        textAlign: TextAlign.center,
        maxLines: 2,
        ellipsis: '…',
      )..layout(maxWidth: math.max(1, tab - 2 * _labelInset));
      tallest = math.max(tallest, painter.height);
      painter.dispose();
    }
    return math.max(_minBody, tallest + 20).ceilToDouble();
  }

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final text = _style(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final body = _bodyHeight(context, labels, width);
        return SizedBox(
          height: body + kPaperLip,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: selected.toDouble()),
            duration: reduce ? Duration.zero : const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            builder: (context, at, child) => CustomPaint(
              painter: _TabsPainter(
                count: labels.length,
                at: at,
                body: body,
                seed: seed,
                sheet: design.surface,
                behind: design.tabBehind,
                edge: design.sheetLip,
              ),
              child: child,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: _gutter),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < labels.length; i++)
                    Expanded(child: _tab(context, i, text, design, body)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _tab(BuildContext context, int i, TextStyle text, AppPalette design, double body) {
    final chosen = i == selected;
    final id = i < qaIds.length ? qaIds[i] : null;
    return Semantics(
      identifier: id,
      button: true,
      selected: chosen,
      label: labels[i],
      excludeSemantics: true,
      // A repeat tap on the chosen tab is passed on too: the details section
      // nav uses it to scroll back to the start of the section.
      onTap: () => onSelect(i),
      child: GestureDetector(
        key: id == null ? null : ValueKey(id),
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelect(i),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(_labelInset, 4, _labelInset, kPaperLip * 0.5),
          child: Center(
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: maxLabelScale,
              child: Text(
                labels[i],
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: text.copyWith(
                  color: chosen ? design.textPrimary : design.textSecondary,
                  fontWeight: chosen ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabsPainter extends CustomPainter {
  const _TabsPainter({
    required this.count,
    required this.at,
    required this.body,
    required this.seed,
    required this.sheet,
    required this.behind,
    required this.edge,
  });

  final int count;

  /// The chosen tab's position, fractional while it slides.
  final double at;
  final double body;
  final String seed;
  final Color sheet;
  final Color behind;
  final Color edge;

  /// One index tab whose slot starts at [left]: slanted sides, a hand-cut top,
  /// and a foot that runs down behind the lip.
  Path _tab(double left, double width, double bottom, int index) {
    final rand = paperRng('$seed-tab-$index');
    final top = 2.0;
    final path = Path()
      ..moveTo(left, bottom)
      ..lineTo(left + FolderTabs._slant, top + rand() * 1.4);
    for (final f in const [0.25, 0.5, 0.75]) {
      path.lineTo(
        left + FolderTabs._slant + (width - 2 * FolderTabs._slant) * f,
        top + rand() * 1.4,
      );
    }
    return path
      ..lineTo(left + width - FolderTabs._slant, top + rand() * 1.4)
      ..lineTo(left + width, bottom)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final width = (size.width - 2 * FolderTabs._gutter) / count;
    const rise = Offset(0, -1.5);
    final edgePaint = Paint()..color = edge;
    // The tabs behind the sheet.
    for (var i = 0; i < count; i++) {
      final tab = _tab(FolderTabs._gutter + i * width, width, size.height, i);
      canvas.drawPath(tab.shift(rise), edgePaint);
      canvas.drawPath(tab, Paint()..color = behind);
    }
    // The sheet's lip runs over their feet.
    canvas.save();
    canvas.translate(0, body);
    paintPaperLip(canvas, Size(size.width, size.height - body), seed, sheet: sheet, edge: edge);
    canvas.restore();
    // The chosen tab is the sheet itself: no edge where it meets the lip.
    final chosen = _tab(
      FolderTabs._gutter + at * width,
      width,
      size.height,
      at.round().clamp(0, count - 1),
    );
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, body));
    canvas.drawPath(chosen.shift(rise), edgePaint);
    canvas.restore();
    canvas.drawPath(chosen, Paint()..color = sheet);
  }

  @override
  bool shouldRepaint(_TabsPainter old) =>
      old.at != at ||
      old.count != count ||
      old.body != body ||
      old.seed != seed ||
      old.sheet != sheet ||
      old.behind != behind ||
      old.edge != edge;
}
