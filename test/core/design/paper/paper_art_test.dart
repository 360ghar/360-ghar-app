import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/paper_art.dart';

/// Records where the scene is placed and what it fills; every other canvas
/// call is a no-op.
class _PlacementCanvas implements Canvas {
  final translations = <Offset>[];
  final fills = <(Rect, Color)>[];
  @override
  void translate(double dx, double dy) => translations.add(Offset(dx, dy));
  @override
  void drawPath(Path path, Paint paint) => fills.add((path.getBounds(), paint.color));
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  const art = PaperArtData(width: 1600, height: 640, shadow: (3, 4, 1.6), layers: []);
  final inks = const AppPalette(isDark: false).inks;

  double top(Size size, {double? keepTop}) {
    final canvas = _PlacementCanvas();
    paintPaperArt(canvas, size, art, inks, cover: true, keepTop: keepTop);
    return canvas.translations.first.dy;
  }

  test('cover anchors the scene at its base', () {
    // 1280 px wide: scale 0.8, so 312 px of the 512 px scene are cut from the top.
    expect(top(const Size(1280, 200)), closeTo(-312, 0.01));
  });

  test('keepTop stops a wide cover crop from cutting the sky', () {
    expect(top(const Size(1280, 200), keepTop: 125), closeTo(-100, 0.01));
    // A phone strip already shows row 125, so nothing moves.
    expect(top(const Size(390, 200), keepTop: 125), top(const Size(390, 200)));
  });

  group('litCount', () {
    // A wall with three window holes; the first path is the lit one.
    const facade = PaperLayerData(
      id: 'facade',
      tone: PaperTone.mid,
      depth: 0,
      shadow: 0,
      cut: [
        'M0 0L60 0 60 20 0 20ZM5 5L15 5 15 15 5 15ZM25 5L35 5 35 15 25 15ZM45 5L55 5 55 15 45 15Z',
      ],
      solid: [],
      lit: [0],
      counted: true,
    );

    List<(Rect, Color)> litFills(AppPalette palette, {int? litCount}) {
      final canvas = _PlacementCanvas();
      paintPaperLayer(canvas, facade, palette.inks, (0, 0, 0), litCount: litCount);
      final gold = (palette.inks.lit ?? palette.tone(PaperTone.lit)).toARGB32();
      return [
        for (final fill in canvas.fills)
          if (fill.$2.toARGB32() == gold) fill,
      ];
    }

    test('counts the holes after the outline', () {
      expect(paperWindowCount(facade), 3);
    });

    test('lights exactly the first N windows, by day and by night', () {
      for (final palette in const [AppPalette(isDark: false), AppPalette(isDark: true)]) {
        final lit = litFills(palette, litCount: 2);
        expect(lit.map((f) => f.$1), [
          const Rect.fromLTRB(5, 5, 15, 15),
          const Rect.fromLTRB(25, 5, 35, 15),
        ]);
        expect(litFills(palette, litCount: 0), isEmpty);
        expect(litFills(palette, litCount: 99), hasLength(3), reason: 'capped at the windows');
      }
    });

    test('a layer that is not counted keeps its night windows', () {
      const towers = PaperLayerData(
        id: 'towers',
        tone: PaperTone.far,
        depth: 0,
        shadow: 0,
        cut: ['M0 0L60 0 60 20 0 20ZM5 5L15 5 15 15 5 15Z'],
        solid: [],
        lit: [0],
      );
      final canvas = _PlacementCanvas();
      const night = AppPalette(isDark: true);
      paintPaperLayer(canvas, towers, night.inks, (0, 0, 0), litCount: 0);
      expect(canvas.fills.first.$1, const Rect.fromLTRB(0, 0, 60, 20), reason: 'all windows lit');
    });

    test('without litCount: dark windows by day, all lit at night', () {
      expect(litFills(const AppPalette(isDark: false)), isEmpty);
      final night = litFills(const AppPalette(isDark: true));
      expect(night, hasLength(1));
      expect(night.single.$1, const Rect.fromLTRB(0, 0, 60, 20));
    });
  });
}
