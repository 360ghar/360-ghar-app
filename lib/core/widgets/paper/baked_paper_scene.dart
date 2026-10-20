import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/paper_art.dart';

/// Scene images are baked at most at this pixel ratio (memory knob).
const kPaperSceneMaxRasterDpr = 2.0;

/// One baked group of layers: its image, where the image sits in the widget,
/// and the scene placement it was baked with.
class BakedPaperLayer {
  const BakedPaperLayer({
    required this.layers,
    required this.rect,
    required this.image,
    required this.origin,
    required this.scale,
  });

  final List<PaperLayerData> layers;
  final Rect rect;
  final ui.Image image;

  /// Where scene point (0, 0) sits in the widget.
  final Offset origin;

  /// Pixels per scene unit.
  final double scale;

  /// The first layer of the group; it names the group.
  PaperLayerData get layer => layers.first;

  /// Scene row [y] in widget pixels.
  double sceneY(double y) => origin.dy + y * scale;
}

/// Where a baked group is drawn in a widget of [size]. Null hides it.
typedef BakedPaperTransform = Matrix4? Function(BakedPaperLayer layer, Size size);

/// A paper scene painted once into one image per layer group and moved with
/// transforms: scrolling, swiping or tilting only recomposites, nothing
/// repaints. It bakes again when the size, pixel ratio, theme, art or
/// [litCount] changes, and releases the old images.
class BakedPaperScene extends StatefulWidget {
  const BakedPaperScene({
    super.key,
    required this.art,
    this.groups,
    this.transform,
    this.repaint,
    this.fit = BoxFit.cover,
    this.window,
    this.keepTop,
    this.focusX = 0.5,
    this.litCount,
    this.bleed = 72,
    this.layerKeyPrefix = 'paper.layer.',
  });

  final PaperArtData art;

  /// Layers that move together, baked into one image each, far to near.
  /// Null bakes each layer of [art] alone.
  final List<List<PaperLayerData>>? groups;

  /// Places each group; null draws it where it was baked.
  final BakedPaperTransform? transform;

  /// Repaints (recomposites) the groups when it notifies.
  final Listenable? repaint;

  /// How [window] fits the box: [BoxFit.cover] fills it and crops,
  /// [BoxFit.contain] shows all of it, [BoxFit.fitHeight] shows its full
  /// height (layers that run past the art edges fill a wide box). Cropped
  /// scenes are anchored at the bottom, so the street stays in view.
  final BoxFit fit;

  /// The part of [art] to fit, in scene units. Null is the whole art.
  final Rect? window;

  /// Never crop above this scene row: a wide box loses the ground instead
  /// of the sky.
  final double? keepTop;

  /// Where a window wider than the box sits: 0 keeps its left edge, 1 its
  /// right edge, 0.5 the middle (like CSS `object-position`).
  final double focusX;

  /// Lights the first N windows of the layers that list window paths
  /// (see [paintPaperLayer]).
  final int? litCount;

  /// How far past the box a group is baked, so parallax never shows an edge.
  final double bleed;

  /// Key prefix of each group's [RepaintBoundary], followed by its first
  /// layer id.
  final String layerKeyPrefix;

  @override
  State<BakedPaperScene> createState() => _BakedPaperSceneState();
}

class _BakedPaperSceneState extends State<BakedPaperScene> {
  Object? _bakedFor;
  List<BakedPaperLayer> _baked = const [];

  void _bake(Size size, double dpr, AppPalette design) {
    final art = widget.art;
    final box = widget.window ?? Offset.zero & art.size;
    final scale = switch (widget.fit) {
      BoxFit.contain => math.min(size.width / box.width, size.height / box.height),
      BoxFit.fitHeight => size.height / box.height,
      BoxFit.fitWidth => size.width / box.width,
      _ => math.max(size.width / box.width, size.height / box.height),
    };
    var dy = widget.fit == BoxFit.contain
        ? (size.height - box.height * scale) / 2
        : size.height - box.height * scale;
    if (widget.keepTop case final keepTop?) dy = math.max(dy, -(keepTop - box.top) * scale);
    final origin = Offset(
      (size.width - box.width * scale) * widget.focusX - box.left * scale,
      dy - box.top * scale,
    );
    final view = (Offset.zero & size).inflate(widget.bleed);
    final old = _baked;
    _baked = [
      for (final group
          in widget.groups ??
              [
                for (final layer in art.layers) [layer],
              ])
        ?_bakeGroup(group, scale, origin, view, dpr, design),
    ];
    // The old images may still be on screen this frame.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      for (final b in old) {
        b.image.dispose();
      }
    });
  }

  BakedPaperLayer? _bakeGroup(
    List<PaperLayerData> group,
    double scale,
    Offset origin,
    Rect view,
    double dpr,
    AppPalette design,
  ) {
    final art = widget.art;
    var scene = paperLayerBounds(group.first, art.shadow);
    for (final layer in group.skip(1)) {
      scene = scene.expandToInclude(paperLayerBounds(layer, art.shadow));
    }
    final onScreen = Rect.fromLTRB(
      origin.dx + scene.left * scale,
      origin.dy + scene.top * scale,
      origin.dx + scene.right * scale,
      origin.dy + scene.bottom * scale,
    ).intersect(view);
    if (onScreen.width <= 0 || onScreen.height <= 0) return null;
    final rect = Rect.fromLTRB(
      onScreen.left.floorToDouble(),
      onScreen.top.floorToDouble(),
      onScreen.right.ceilToDouble(),
      onScreen.bottom.ceilToDouble(),
    );
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..scale(dpr)
      ..translate(origin.dx - rect.left, origin.dy - rect.top)
      ..scale(scale);
    for (final layer in group) {
      paintPaperLayer(canvas, layer, design.inks, art.shadow, litCount: widget.litCount);
    }
    final picture = recorder.endRecording();
    final image = picture.toImageSync((rect.width * dpr).ceil(), (rect.height * dpr).ceil());
    picture.dispose();
    return BakedPaperLayer(layers: group, rect: rect, image: image, origin: origin, scale: scale);
  }

  @override
  void dispose() {
    for (final b in _baked) {
      b.image.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final dpr = math.min(MediaQuery.devicePixelRatioOf(context), kPaperSceneMaxRasterDpr);
    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final w = widget;
          final key = (
            size,
            dpr,
            design.isDark,
            w.art,
            w.groups,
            w.litCount,
            w.fit,
            w.window,
            w.keepTop,
            w.focusX,
            w.bleed,
          );
          if (key != _bakedFor && size.width > 0 && size.height > 0) {
            _bakedFor = key;
            _bake(size, dpr, design);
          }
          return RepaintBoundary(
            child: Flow(
              clipBehavior: Clip.hardEdge,
              delegate: _BakedFlow(baked: _baked, transform: w.transform, repaint: w.repaint),
              children: [
                for (final b in _baked)
                  RepaintBoundary(
                    key: ValueKey('${w.layerKeyPrefix}${b.layer.id}'),
                    child: RawImage(image: b.image, width: b.rect.width, height: b.rect.height),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BakedFlow extends FlowDelegate {
  _BakedFlow({required this.baked, required this.transform, super.repaint});

  final List<BakedPaperLayer> baked;
  final BakedPaperTransform? transform;

  @override
  BoxConstraints getConstraintsForChild(int i, BoxConstraints constraints) =>
      BoxConstraints.tight(baked[i].rect.size);

  @override
  void paintChildren(FlowPaintingContext context) {
    for (var i = 0; i < baked.length; i++) {
      final b = baked[i];
      final m = transform == null
          ? Matrix4.translationValues(b.rect.left, b.rect.top, 0)
          : transform!(b, context.size);
      if (m != null) context.paintChild(i, transform: m);
    }
  }

  @override
  bool shouldRepaint(_BakedFlow old) => !identical(old.baked, baked) || old.transform != transform;
}
