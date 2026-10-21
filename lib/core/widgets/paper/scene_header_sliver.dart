import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/design/paper/paper_art.dart';
import 'package:ghar360/core/design/paper/paper_scene_data.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/widgets/paper/baked_paper_scene.dart';
import 'package:ghar360/core/widgets/paper/folder_tabs.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';
import 'package:ghar360/core/widgets/paper/sheet_sliver.dart';

/// The scene a [SceneHeaderSliver] shows in its band: which art, which rows,
/// and which part of a scene wider than the screen.
class PaperSceneSpec {
  const PaperSceneSpec({
    required this.art,
    required this.ground,
    this.top = 0,
    this.focusX = 0.5,
    this.litCount,
    this.band = 148,
  });

  /// The society facade of Saved: one window lights per saved home (capped at
  /// the window count).
  factory PaperSceneSpec.saved({int litCount = 0}) =>
      PaperSceneSpec(art: paperHeaders['saved']!, ground: 214, focusX: 0.5, litCount: litCount);

  /// The society gate of Visits, with its guard booth.
  factory PaperSceneSpec.visits() =>
      PaperSceneSpec(art: paperHeaders['visits']!, ground: 214, focusX: 0.6);

  /// The onboarding home, its window lit, with the city behind it.
  factory PaperSceneSpec.profile() =>
      PaperSceneSpec(art: paperHeaders['profile']!, ground: 214, focusX: 0.55);

  /// The onboarding kite over the towers and the sector blocks.
  factory PaperSceneSpec.assistant() =>
      PaperSceneSpec(art: paperHeaders['assistant']!, ground: 214, focusX: 0.64);

  /// A slim far skyline for sub-pages, calculators, tools, the tour and 404.
  factory PaperSceneSpec.skyline() =>
      PaperSceneSpec(art: paperHeaders['skyline']!, ground: 214, focusX: 0.3, band: 96);

  final PaperArtData art;

  /// The scene row set on the bottom of the band, just above the sheet.
  final double ground;

  /// The scene row at the top of the band.
  final double top;

  /// Where the art sits when it is wider or narrower than the screen: 0 its
  /// left edge, 1 its right. Header scenes run their far city and ground past
  /// the art edges, so a wide screen shows more city, never an empty edge.
  final double focusX;

  /// Lights this many windows of the scene's counted layer.
  final int? litCount;

  /// The scene band's height on a phone, before small screens and large
  /// text shrink it. At most 148.
  final double band;

  static final _groups = Expando<List<List<PaperLayerData>>>();

  /// Runs of layers at one depth move as one sheet, so each run is baked into
  /// one image.
  List<List<PaperLayerData>> get groups => _groups[art] ??= () {
    final runs = <List<PaperLayerData>>[];
    for (final layer in art.layers) {
      if (runs.isNotEmpty && runs.last.first.depth == layer.depth) {
        runs.last.add(layer);
      } else {
        runs.add([layer]);
      }
    }
    return runs;
  }();
}

/// The header of a list screen, pinned: the page sky with grain, a paper
/// scene in a band that the sheet rises over as the list scrolls (deeper
/// layers move less), the title in Erode moving from the band into the
/// compact bar, the [actions] on the right, and at the bottom the sheet's
/// hand-cut lip, with [tabs] raised from it.
///
/// Use it as the first sliver of a [PaperScrollPage].
class SceneHeaderSliver extends StatelessWidget {
  const SceneHeaderSliver({
    super.key,
    required this.title,
    required this.scene,
    this.actions = const [],
    this.leading,
    this.tabs,
    this.qaId,
    this.seed,
  });

  final String title;
  final PaperSceneSpec scene;
  final List<Widget> actions;

  /// Shown before the title in the bar. Null shows a back button when the
  /// route can pop.
  final Widget? leading;

  /// Folder tabs raised from the sheet's lip.
  final FolderTabs? tabs;

  /// Semantics identifier of the title.
  final String? qaId;

  /// Seed of the lip's hand-cut edge; defaults to [title].
  final String? seed;

  /// Height of the compact bar under the status bar.
  static const bar = 56.0;

  static TextStyle _expandedStyle(BuildContext context) =>
      Theme.of(context).textTheme.displaySmall!;

  static TextStyle _compactStyle(BuildContext context) =>
      Theme.of(context).textTheme.headlineMedium!;

  /// Titles grow with the text scale up to this factor.
  static const maxTitleScale = 1.3;

  /// The extents for a header [width] wide, and the compact title's height.
  static ({
    double min,
    double max,
    double band,
    double bottom,
    double bar,
    double titleLine,
    double reserve,
  })
  extentsFor(
    BuildContext context, {
    required double width,
    required PaperSceneSpec scene,
    required String title,
    FolderTabs? tabs,
  }) {
    final media = MediaQuery.of(context);
    final scaler = media.textScaler.clamp(maxScaleFactor: maxTitleScale);
    (double, int) measure(TextStyle style, {int lines = 1, double maxWidth = double.infinity}) {
      final painter = TextPainter(
        text: TextSpan(text: title, style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
        maxLines: lines,
        ellipsis: '…',
      )..layout(maxWidth: maxWidth);
      final result = (painter.height, painter.computeLineMetrics().length);
      painter.dispose();
      return result;
    }

    double lineHeight(TextStyle style) => measure(style).$1;

    final titleLine = lineHeight(_compactStyle(context));
    final bar = math.max(SceneHeaderSliver.bar, titleLine + 16);
    final bottom = tabs == null ? kPaperLip : FolderTabs.heightFor(context, tabs.labels, width);
    var band = math.min(148.0, scene.band);
    if (width < 360) band *= 0.82;
    if (media.textScaler.scale(10) / 10 > 1.3) band *= 0.78;
    final (titleHeight, titleLines) = measure(
      _expandedStyle(context),
      lines: 2,
      maxWidth: _expandedTitleWidth(width),
    );
    // A wrapped title, a narrow screen or large text would put the title over
    // the towers. Then the title gets its own strip of sky above the scene,
    // and the band grows so the scene keeps a readable height.
    final crowded = titleLines > 1 || width < 360 || media.textScaler.scale(10) / 10 > 1.15;
    final reserve = crowded ? (titleHeight + 12).roundToDouble() : 0.0;
    band = crowded
        ? math.max(band, reserve + math.min(_minScene, scene.band * 0.6)).roundToDouble()
        : math.min(148.0, math.max(band, titleHeight + 20)).roundToDouble();
    final min = media.padding.top + bar + bottom;
    return (
      min: min,
      max: min + band,
      band: band,
      bottom: bottom,
      bar: bar,
      titleLine: titleLine,
      reserve: reserve,
    );
  }

  static double _expandedTitleWidth(double width) => (width - 32) * 0.62;

  /// The least scene height kept under a title that has its own strip of sky
  /// (at most 60% of the scene's own band, so a slim strip stays slim).
  static const _minScene = 72.0;

  static final _extents =
      <
        Object,
        ({
          double min,
          double max,
          double band,
          double bottom,
          double bar,
          double titleLine,
          double reserve,
        })
      >{};

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.crossAxisExtent;
        // The builder runs on every scroll frame; the text is measured once.
        final media = MediaQuery.of(context);
        final memo = (
          width,
          title,
          tabs?.labels.join('\u0000'),
          media.textScaler,
          media.padding.top,
          scene.band,
          Theme.of(context).textTheme,
          Directionality.of(context),
        );
        final e =
            _extents.remove(memo) ??
            extentsFor(context, width: width, scene: scene, title: title, tabs: tabs);
        _extents[memo] = e;
        if (_extents.length > 8) _extents.remove(_extents.keys.first);
        final canPop = ModalRoute.of(context)?.impliesAppBarDismissal ?? false;
        final lead =
            leading ??
            (canPop
                ? IconButton(
                    key: const ValueKey('qa.header.back'),
                    tooltip: context.l10n.text('back'),
                    onPressed: () => Navigator.maybePop(context),
                    icon: const PaperIcon(KnifeIcon.arrowLeft, size: 22),
                  )
                : null);
        return SliverPersistentHeader(
          pinned: true,
          delegate: _SceneHeaderDelegate(
            title: title,
            scene: scene,
            actions: actions,
            leading: lead,
            tabs: tabs,
            qaId: qaId,
            seed: seed ?? title,
            width: width,
            top: MediaQuery.paddingOf(context).top,
            bar: e.bar,
            titleLine: e.titleLine,
            band: e.band,
            reserve: e.reserve,
            bottom: e.bottom,
            minHeight: e.min,
            maxHeight: e.max,
            reduce: MediaQuery.disableAnimationsOf(context),
          ),
        );
      },
    );
  }
}

class _SceneHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _SceneHeaderDelegate({
    required this.title,
    required this.scene,
    required this.actions,
    required this.leading,
    required this.tabs,
    required this.qaId,
    required this.seed,
    required this.width,
    required this.top,
    required this.bar,
    required this.titleLine,
    required this.band,
    required this.reserve,
    required this.bottom,
    required this.minHeight,
    required this.maxHeight,
    required this.reduce,
  });

  final String title;
  final PaperSceneSpec scene;
  final List<Widget> actions;
  final Widget? leading;
  final FolderTabs? tabs;
  final String? qaId;
  final String seed;
  final double width;
  final double top;
  final double bar;
  final double titleLine;
  final double band;

  /// Sky kept clear above the scene for the expanded title (0 when the title
  /// fits beside the towers).
  final double reserve;
  final double bottom;
  final double minHeight;
  final double maxHeight;
  final bool reduce;

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  /// The part of the scene that fills the band and runs on under the sheet:
  /// [PaperSceneSpec.ground] on the band's bottom edge.
  Rect _window() {
    final scale = (band - reserve) / (scene.ground - scene.top);
    return Rect.fromLTWH(0, scene.top, scene.art.width, (band - reserve + bottom) / scale);
  }

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final design = context.design;
    final shrink = shrinkOffset.clamp(0.0, band);
    final t = band == 0 ? 1.0 : shrink / band;
    final expanded = SceneHeaderSliver._expandedStyle(context);
    final compact = SceneHeaderSliver._compactStyle(context);
    final style = TextStyle.lerp(expanded, compact, t)!.copyWith(color: design.textPrimary);
    final leadWidth = leading == null ? 0.0 : 48.0;
    final compactLeft = leading == null ? 16.0 : 4 + leadWidth + 4;
    final compactWidth = math.max(48.0, width - compactLeft - 8 - 48.0 * actions.length - 4);
    final titleLeft = lerpDouble(16, compactLeft, t)!;
    final titleWidth = lerpDouble(SceneHeaderSliver._expandedTitleWidth(width), compactWidth, t)!;
    final titleTop = lerpDouble(top + bar + 6, top + (bar - titleLine) / 2, t)!;
    final window = _window();
    return SizedBox.expand(
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _SkyPainter(design.background, design.grain)),
          ),
          // The scene runs on under the tabs' gaps while expanded; collapsing,
          // the sheet covers it and nothing of it shows in the compact bar.
          Positioned(
            top: top + bar + reserve,
            left: 0,
            right: 0,
            height: math.max(0.0, band - reserve - shrink + bottom * (1 - t)),
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.topCenter,
                minHeight: band - reserve + bottom,
                maxHeight: band - reserve + bottom,
                child: BakedPaperScene(
                  art: scene.art,
                  groups: scene.groups,
                  fit: BoxFit.fitHeight,
                  window: window,
                  focusX: scene.focusX,
                  litCount: scene.litCount,
                  transform: (b, size) {
                    // Deeper layers rise less as the sheet comes up over them.
                    final rise = reduce ? 0.0 : shrink * 0.25 * b.layer.depth;
                    return Matrix4.translationValues(b.rect.left, b.rect.top - rise, 0);
                  },
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: bottom,
            child: tabs ?? PaperLip(seed: seed),
          ),
          if (leading case final leading?)
            Positioned(
              top: top,
              left: 4,
              height: bar,
              child: Center(child: leading),
            ),
          Positioned(
            top: titleTop,
            left: titleLeft,
            width: titleWidth,
            child: Semantics(
              header: true,
              identifier: qaId,
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: SceneHeaderSliver.maxTitleScale,
                child: Text(
                  title,
                  maxLines: t > 0.5 ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
              ),
            ),
          ),
          if (actions.isNotEmpty)
            Positioned(
              top: top,
              right: 4,
              height: bar,
              child: Row(mainAxisSize: MainAxisSize.min, children: actions),
            ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_SceneHeaderDelegate old) =>
      old.title != title ||
      old.scene != scene ||
      old.actions != actions ||
      old.leading != leading ||
      old.tabs != tabs ||
      old.qaId != qaId ||
      old.seed != seed ||
      old.width != width ||
      old.top != top ||
      old.bar != bar ||
      old.titleLine != titleLine ||
      old.band != band ||
      old.reserve != reserve ||
      old.bottom != bottom ||
      old.reduce != reduce;
}

class _SkyPainter extends CustomPainter {
  const _SkyPainter(this.sky, this.grain);

  final Color sky;
  final Color grain;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = sky);
    paintPaperGrain(canvas, Offset.zero & size, grain);
  }

  @override
  bool shouldRepaint(_SkyPainter old) => old.sky != sky || old.grain != grain;
}
