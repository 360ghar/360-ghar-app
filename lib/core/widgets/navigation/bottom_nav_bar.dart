import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/design/paper/paper_art.dart';
import 'package:ghar360/core/design/paper/paper_cut.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/widgets/common/symmetric_safe_area.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';

/// Width from which the shell shows a rail on the left instead of the strip.
const kRailBreakpoint = 600.0;

/// The five shell destinations: icon, selected icon, label key, QA id.
const _destinations = [
  (KnifeIcon.home, KnifeIcon.home, 'discover', 'discover'),
  (KnifeIcon.map, KnifeIcon.map, 'explore', 'explore_properties'),
  (KnifeIcon.heart, KnifeIcon.heartSolid, 'saved', 'saved'),
  (KnifeIcon.calendar, KnifeIcon.calendar, 'visits', 'visits'),
  (KnifeIcon.user, KnifeIcon.user, 'profile', 'profile'),
];

/// Room above the roofline for the tower over the active item.
const _rise = 12.0;

/// Depth of the roofline band.
const _roof = 22.0;

/// Where the items start below the strip's top: under the lowest roof.
const _itemsTop = 26.0;

/// The tower box: [kNavTowerWidth] wide plus a little room for its edge.
const kNavTowerWidth = 28.0;
const _towerPad = 2.0;
const _towerDepth = _rise + _roof;

const _slide = Duration(milliseconds: 250);

/// The bottom navigation: a strip of card stock whose top edge is a low
/// Gurugram roofline (flat roofs, water tanks, stair rooms). One taller tower
/// with a rooftop tank and one window stands over the current tab and slides
/// to a new one; the current tab also shows a teal icon and a bold label.
/// The page shows through the gaps between the roofs.
class CustomBottomNavigationBar extends StatelessWidget {
  const CustomBottomNavigationBar({super.key, required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final extra = (MediaQuery.textScalerOf(context).scale(12) - 12).clamp(0, 12).toDouble();
    final reduce = MediaQuery.disableAnimationsOf(context);
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // The strip is centered and sits below the Duo's pill: only the inset both sides share.
          final inset = symmetricSideInset(context, sharedOnly: true);
          final item = (constraints.maxWidth - 2 * inset) / _destinations.length;
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _RooflinePainter(
                    seed: 'nav',
                    vertical: false,
                    sheet: design.surface,
                    edge: design.sheetLip,
                  ),
                ),
              ),
              AnimatedPositioned(
                key: const ValueKey('qa.dashboard.nav.tower'),
                duration: reduce ? Duration.zero : _slide,
                curve: Curves.easeOutCubic,
                left: inset + item * (currentIndex + 0.5) - kNavTowerWidth / 2 - _towerPad,
                top: 0,
                width: kNavTowerWidth + 2 * _towerPad,
                height: _towerDepth,
                child: _Tower(vertical: false, design: design),
              ),
              SymmetricSafeArea(
                top: false,
                sharedOnly: true,
                child: Padding(
                  padding: const EdgeInsets.only(top: _itemsTop),
                  child: SizedBox(
                    height: 56 + extra,
                    child: Row(
                      children: [
                        for (var i = 0; i < _destinations.length; i++)
                          Expanded(
                            child: _NavItem(index: i, selected: i == currentIndex, onTap: onTap),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The same destinations as a rail on the left, for widths from
/// [kRailBreakpoint]. Its right edge is the roofline turned on its side, and
/// the tower points at the current item.
class PaperNavigationRail extends StatelessWidget {
  const PaperNavigationRail({super.key, required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _itemHeight = 76.0;
  static const _top = 16.0;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final width = math.max(84.0, MediaQuery.textScalerOf(context).scale(84));
    final reduce = MediaQuery.disableAnimationsOf(context);
    final safeTop = MediaQuery.paddingOf(context).top;
    return RepaintBoundary(
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _RooflinePainter(
                seed: 'rail',
                vertical: true,
                sheet: design.surface,
                edge: design.sheetLip,
              ),
            ),
          ),
          AnimatedPositioned(
            key: const ValueKey('qa.dashboard.nav.tower'),
            duration: reduce ? Duration.zero : _slide,
            curve: Curves.easeOutCubic,
            top:
                safeTop +
                _top +
                _itemHeight * (currentIndex + 0.5) -
                kNavTowerWidth / 2 -
                _towerPad,
            right: 0,
            width: _towerDepth,
            height: kNavTowerWidth + 2 * _towerPad,
            child: _Tower(vertical: true, design: design),
          ),
          SafeArea(
            right: false,
            child: Padding(
              padding: const EdgeInsets.only(right: _itemsTop, top: _top),
              child: SizedBox(
                width: width.clamp(84, 140),
                child: Column(
                  children: [
                    for (var i = 0; i < _destinations.length; i++)
                      SizedBox(
                        height: _itemHeight,
                        child: _NavItem(index: i, selected: i == currentIndex, onTap: onTap),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The strip with its roofline edge. A rail is the same strip turned on its
/// side, the roofs facing right.
class _RooflinePainter extends CustomPainter {
  const _RooflinePainter({
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
    final length = vertical ? size.height : size.width;
    final depth = vertical ? size.width : size.height;
    canvas.save();
    if (vertical) {
      canvas.translate(size.width, 0);
      canvas.rotate(math.pi / 2);
    }
    final roofs = parsePaperPath(
      rooflineBandPath(seed, width: length, height: _roof),
      fillType: PathFillType.nonZero,
    );
    final band = roofs.shift(const Offset(0, _rise))
      ..addRect(Rect.fromLTWH(0, _rise + _roof - 0.5, length, depth - _rise - _roof + 0.5));
    canvas.drawPath(band.shift(const Offset(0, -1.5)), Paint()..color = edge);
    canvas.drawPath(band, Paint()..color = sheet);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RooflinePainter old) =>
      old.seed != seed || old.vertical != vertical || old.sheet != sheet || old.edge != edge;
}

/// The tower over the current item: a tall block with a rooftop tank and one
/// window. By day the window is cut through, so the page shows; at night it
/// is lit gold.
class _Tower extends StatelessWidget {
  const _Tower({required this.vertical, required this.design});

  final bool vertical;
  final AppPalette design;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _TowerPainter(
      vertical: vertical,
      sheet: design.surface,
      edge: design.sheetLip,
      lit: design.isDark ? design.tone(PaperTone.lit) : null,
    ),
  );
}

class _TowerPainter extends CustomPainter {
  const _TowerPainter({required this.vertical, required this.sheet, required this.edge, this.lit});

  final bool vertical;
  final Color sheet;
  final Color edge;
  final Color? lit;

  static const _x = _towerPad;
  static const _w = kNavTowerWidth;

  /// The window, above the roofline, so the page shows through it.
  static const _window = Rect.fromLTWH(_x + _w / 2 - 3, 7.5, 6, 7);

  static final _shape = Path.combine(
    PathOperation.difference,
    Path()
      // The tank on its stand, then the tower body down into the strip.
      ..addPolygon(const [
        Offset(_x + 7, 2.6),
        Offset(_x + 7, 0.6),
        Offset(_x + 7.6, 0),
        Offset(_x + 20.4, 0),
        Offset(_x + 21, 0.6),
        Offset(_x + 21, 2.6),
        Offset(_x + 19, 2.6),
        Offset(_x + 19, 3.4),
        Offset(_x + 9, 3.4),
        Offset(_x + 9, 2.6),
      ], true)
      ..addRect(const Rect.fromLTWH(_x, 3.2, _w, _towerDepth - 3.2)),
    Path()..addRect(_window),
  );

  @override
  void paint(Canvas canvas, Size size) {
    if (vertical) {
      canvas.translate(size.width, 0);
      canvas.rotate(math.pi / 2);
    }
    canvas.drawPath(_shape.shift(const Offset(0, -1.5)), Paint()..color = edge);
    canvas.drawPath(_shape, Paint()..color = sheet);
    if (lit case final lit?) canvas.drawRect(_window, Paint()..color = lit);
  }

  @override
  bool shouldRepaint(_TowerPainter old) =>
      old.vertical != vertical || old.sheet != sheet || old.edge != edge || old.lit != lit;
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.index, required this.selected, required this.onTap});

  final int index;
  final bool selected;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, selectedIcon, labelKey, id) = _destinations[index];
    final design = context.design;
    final label = context.l10n.text(labelKey);
    return Semantics(
      identifier: 'qa.dashboard.nav.$id',
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('qa.dashboard.nav.$id'),
        onTap: selected ? null : () => onTap(index),
        hoverColor: design.slip,
        focusColor: design.slip,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PaperIcon(
              selected ? selectedIcon : icon,
              size: 24,
              color: selected ? design.accent : design.textSecondary,
            ),
            const SizedBox(height: 4),
            MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.5,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: selected ? design.textPrimary : design.textSecondary,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
