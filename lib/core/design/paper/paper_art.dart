import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'package:ghar360/core/design/paper/paper_cut.dart';

/// Card stock tones used by paper art. [AppPalette.tone] gives each a colour
/// for the day and the night theme.
enum PaperTone {
  bg,
  sun,
  sky,
  cloud,
  far,
  mid,
  main,
  deep,
  near,
  kerb,
  accent,
  highlight,
  pin,
  home,
  lit,
  grass,
  tree,
  sign,
  pavement,
  shop,
  bloom,
  trunk,
  auto,
  cow,
  concrete,
}

/// One sheet of card stock: flat fill, one short shadow on the layer behind.
class PaperLayerData {
  const PaperLayerData({
    required this.id,
    required this.tone,
    required this.depth,
    required this.shadow,
    required this.cut,
    required this.solid,
    this.lit = const [],
    this.counted = false,
  });

  final String id;
  final PaperTone tone;

  /// Parallax weight: 0 stays fixed, 1 moves most.
  final double depth;

  /// Opacity of the shadow this layer casts; 0 casts none.
  final double shadow;

  /// Even-odd paths: cut-outs such as windows are holes.
  final List<String> cut;

  /// Non-zero paths: overlapping solids such as trees.
  final List<String> solid;

  /// Indexes into [cut] whose holes are windows, lit at night.
  final List<int> lit;

  /// Whether a runtime count lights these windows one by one (see
  /// [paintPaperLayer]), so the scene can show data.
  final bool counted;
}

/// A scene: layers far to near in a [width] x [height] box.
class PaperArtData {
  const PaperArtData({
    required this.width,
    required this.height,
    required this.shadow,
    required this.layers,
    this.frame,
  });

  final double width;
  final double height;

  /// Shadow offset and blur (dx, dy, sigma) in scene units. The light is top left.
  final (double, double, double) shadow;
  final List<PaperLayerData> layers;

  /// Hand-cut outline of the scene card. Null means the scene has no card.
  final String? frame;

  Size get size => Size(width, height);
}

/// Colours for one theme. [lit] fills the window holes that a layer lists in
/// [PaperLayerData.lit]; null (the day theme) keeps them open.
class PaperInks {
  const PaperInks({required this.tone, required this.shadow, this.lit});

  final Color Function(PaperTone) tone;

  /// Shadow colour at full opacity; each layer scales it by its own opacity.
  final Color shadow;
  final Color? lit;
}

final _paths = Expando<({List<Path> cut, List<Path> solid})>();

({List<Path> cut, List<Path> solid}) _layerPaths(PaperLayerData layer) => _paths[layer] ??= (
  cut: [for (final d in layer.cut) parsePaperPath(d)],
  solid: [for (final d in layer.solid) parsePaperPath(d, fillType: PathFillType.nonZero)],
);

/// The area [layer] covers in scene units, including its shadow.
Rect paperLayerBounds(PaperLayerData layer, (double, double, double) shadow) {
  final paths = _layerPaths(layer);
  var bounds = Rect.zero;
  for (final path in [...paths.cut, ...paths.solid]) {
    final b = path.getBounds();
    bounds = bounds.isEmpty ? b : bounds.expandToInclude(b);
  }
  final (dx, dy, sigma) = shadow;
  return Rect.fromLTRB(
    bounds.left,
    bounds.top,
    bounds.right + dx + sigma * 3,
    bounds.bottom + dy + sigma * 3,
  );
}

final _windows = Expando<List<Path>>();

/// The window holes of [layer]'s [PaperLayerData.lit] paths, in path order:
/// every contour after the first (the outline) of each lit path.
List<Path> _windowHoles(PaperLayerData layer) => _windows[layer] ??= [
  for (final index in layer.lit)
    for (final (i, contour) in _layerPaths(layer).cut[index].computeMetrics().indexed)
      if (i > 0) contour.extractPath(0, contour.length)..close(),
];

/// The number of window holes [litCount] can light in [layer].
int paperWindowCount(PaperLayerData layer) => _windowHoles(layer).length;

/// Draws [layer] in scene units: its shadow (the union of all its paths,
/// offset down and right and blurred), night windows, then the fills.
///
/// With [litCount], a [PaperLayerData.counted] layer lights exactly its
/// first [litCount] window holes, by day and by night, so a scene can show
/// data (one lit window per saved home). Every other lit window glows at
/// night and none by day.
void paintPaperLayer(
  Canvas canvas,
  PaperLayerData layer,
  PaperInks inks,
  (double, double, double) shadow, {
  int? litCount,
}) {
  final paths = _layerPaths(layer);
  if (layer.shadow > 0) {
    final (dx, dy, sigma) = shadow;
    // One group per layer, so overlapping solids do not darken twice.
    canvas.saveLayer(
      null,
      Paint()
        ..colorFilter = ColorFilter.mode(
          inks.shadow.withValues(alpha: inks.shadow.a * layer.shadow),
          BlendMode.srcIn,
        )
        ..imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
    );
    canvas.translate(dx, dy);
    final mask = Paint();
    for (final path in [...paths.cut, ...paths.solid]) {
      canvas.drawPath(path, mask);
    }
    canvas.restore();
  }
  final lit = inks.lit;
  if (litCount != null && layer.counted) {
    final gold = inks.lit ?? inks.tone(PaperTone.lit);
    final glass = Paint()
      ..color = layer.tone == PaperTone.far ? gold.withValues(alpha: 0.55) : gold;
    for (final window in _windowHoles(layer).take(litCount)) {
      canvas.drawPath(window, glass);
    }
  } else if (lit != null && layer.lit.isNotEmpty) {
    // Window rects wind like their outline, so a non-zero fill closes the holes.
    // Far layers glow less, so the near city reads nearer.
    final glass = Paint()..color = layer.tone == PaperTone.far ? lit.withValues(alpha: 0.55) : lit;
    for (final index in layer.lit) {
      canvas.drawPath(Path.from(paths.cut[index])..fillType = PathFillType.nonZero, glass);
    }
  }
  final fill = Paint()..color = inks.tone(layer.tone);
  for (final path in [...paths.cut, ...paths.solid]) {
    canvas.drawPath(path, fill);
  }
}

/// Paints a whole scene fitted into [size]. [cover] crops like CSS `slice`
/// anchored at the bottom, so the street stays in view; otherwise the scene
/// is contained and centred. With [keepTop], a cover crop never cuts above
/// that scene row: a wide, short strip loses the bottom instead of the sky. With [frameShadow], a framed scene lies on the
/// page as a cut slip: one light from the top left, a tight drop and a contact
/// line, never a halo. [litCount] goes to [paintPaperLayer].
void paintPaperArt(
  Canvas canvas,
  Size size,
  PaperArtData art,
  PaperInks inks, {
  bool cover = false,
  double? keepTop,
  Color? grain,
  Color? frameShadow,
  int? litCount,
}) {
  final scale = cover
      ? (size.width / art.width > size.height / art.height
            ? size.width / art.width
            : size.height / art.height)
      : (size.width / art.width < size.height / art.height
            ? size.width / art.width
            : size.height / art.height);
  final dx = (size.width - art.width * scale) / 2;
  var dy = cover ? size.height - art.height * scale : (size.height - art.height * scale) / 2;
  if (cover && keepTop != null && dy < -keepTop * scale) dy = -keepTop * scale;
  canvas.save();
  canvas.translate(dx, dy);
  canvas.scale(scale);
  final frame = art.frame;
  if (frame != null) {
    final outline = parsePaperPath(frame, fillType: PathFillType.nonZero);
    if (frameShadow != null) {
      for (final (offset, sigma, alpha) in const [
        (Offset(1.5, 3), 2.5, 0.16),
        (Offset(0.5, 1), 0.6, 0.08),
      ]) {
        canvas.drawPath(
          outline.shift(offset / scale),
          Paint()
            ..color = frameShadow.withValues(alpha: alpha)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma / scale),
        );
      }
    }
    canvas.clipPath(outline);
    canvas.drawPath(outline, Paint()..color = inks.tone(PaperTone.bg));
    if (grain != null) paintPaperGrain(canvas, outline.getBounds(), grain, scale: 1 / scale);
  }
  for (final layer in art.layers) {
    paintPaperLayer(canvas, layer, inks, art.shadow, litCount: litCount);
  }
  canvas.restore();
}

ui.Image? _grainTile;

/// A 160 x 160 tile of seeded film grain, built once. It is drawn in the
/// canvas's own pixels, with no anti-aliasing, so goldens stay exact.
// ponytail: one tile for the app lifetime (about 100 KB); it is never disposed.
ui.Image get paperGrainTile => _grainTile ??= () {
  const side = 160;
  final rand = paperRng('grain');
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final levels = List.generate(4, (_) => <double>[]);
  for (var i = 0; i < 5200; i++) {
    final x = (rand() * side).floorToDouble() + 0.5;
    final y = (rand() * side).floorToDouble() + 0.5;
    levels[(rand() * 4).floor()].addAll([x, y]);
  }
  for (var level = 0; level < 4; level++) {
    canvas.drawRawPoints(
      ui.PointMode.points,
      Float32List.fromList(levels[level]),
      Paint()
        ..color = Color.fromRGBO(0, 0, 0, (level + 1) / 4)
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.square
        ..isAntiAlias = false,
    );
  }
  final picture = recorder.endRecording();
  final image = picture.toImageSync(side, side);
  picture.dispose();
  return image;
}();

/// Fills [rect] with grain in [color]. Use on backgrounds only, under content.
/// [scale] converts canvas units to tile pixels when the canvas is scaled.
void paintPaperGrain(Canvas canvas, Rect rect, Color color, {double scale = 1}) {
  canvas.drawRect(
    rect,
    Paint()
      ..shader = ImageShader(
        paperGrainTile,
        TileMode.repeated,
        TileMode.repeated,
        Float64List.fromList([scale, 0, 0, 0, 0, scale, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]),
        filterQuality: FilterQuality.none,
      )
      ..colorFilter = ColorFilter.mode(color, BlendMode.srcIn),
  );
}
