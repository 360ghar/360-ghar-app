import 'dart:ui';

/// Seeded hand-cut edges, ported from the website's `cut.ts` (vendored in
/// `tool/paper/cut.ts`). The same seed gives the same edge on every rebuild
/// and on every platform: all arithmetic is 32-bit and exact on the Dart VM
/// and on the web. `test/fixtures/paper_fixtures.json` pins the output to the
/// TypeScript original.

/// 32-bit integer multiply (`Math.imul`), built from 16-bit halves so no
/// intermediate value leaves the exact range of a double on the web.
int _imul(int a, int b) {
  final aHi = (a >>> 16) & 0xffff;
  final aLo = a & 0xffff;
  final bHi = (b >>> 16) & 0xffff;
  final bLo = b & 0xffff;
  return (aLo * bLo + (((aHi * bLo + aLo * bHi) & 0xffff) << 16)) & 0xffffffff;
}

/// FNV-1a over UTF-16 code units, as an unsigned 32-bit value.
int paperHash(String input) {
  var h = 2166136261;
  for (final unit in input.codeUnits) {
    h = _imul(h ^ unit, 16777619);
  }
  return h;
}

/// mulberry32: returns a function that yields doubles in [0, 1).
double Function() paperRng(Object seed) {
  var a = (seed is int ? seed : paperHash(seed.toString())) & 0xffffffff;
  return () {
    a = (a + 0x6d2b79f5) & 0xffffffff;
    var t = _imul(a ^ (a >>> 15), 1 | a);
    t = ((t + _imul(t ^ (t >>> 7), 61 | t)) & 0xffffffff) ^ t;
    return ((t ^ (t >>> 14)) & 0xffffffff) / 4294967296;
  };
}

/// JavaScript `Math.round`: halves round toward positive infinity.
double jsRound(double x) {
  final floor = x.floorToDouble();
  return x - floor >= 0.5 ? floor + 1 : floor;
}

double _r2(double n) => jsRound(n * 100) / 100;

/// Formats a number the way JavaScript prints it for these values.
String jsNum(double v) => v == v.truncateToDouble() ? v.toInt().toString() : v.toString();

/// One corner or edge point: `x = left + xPercent% of width + xPx`.
typedef CutPoint = ({double xPercent, double xPx, double yPercent, double yPx});

/// A hand-cut sheet outline. Points move with the size of the sheet, but the
/// wobble stays the same number of pixels, like a sheet cut with scissors.
class CutEdge {
  const CutEdge(this.points);
  final List<CutPoint> points;

  Path toPath(Rect rect) {
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final x = rect.left + rect.width * p.xPercent / 100 + p.xPx;
      final y = rect.top + rect.height * p.yPercent / 100 + p.yPx;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    return path..close();
  }
}

/// Every point moves inward by at most [amp] pixels, so content padded by more
/// than [amp] is never cut.
CutEdge cutPolygon(Object seed, {double amp = 2, int across = 9, int down = 5}) {
  final rand = paperRng(seed);
  double off() => _r2(rand() * amp);
  // Spread points unevenly along an edge, as a hand cut would.
  List<double> stops(int n) => [
    for (var i = 1; i < n; i++) _r2(i * 100 / n + (rand() - 0.5) * (100 / n) * 0.6),
  ];
  CutPoint p(double xPercent, double xPx, double yPercent, double yPx) =>
      (xPercent: xPercent, xPx: xPx, yPercent: yPercent, yPx: yPx);
  // Record fields evaluate left to right, like the template strings in cut.ts.
  final points = <CutPoint>[p(0, off(), 0, off())];
  for (final s in stops(across)) {
    points.add(p(s, 0, 0, off()));
  }
  points.add(p(100, -off(), 0, off()));
  for (final s in stops(down)) {
    points.add(p(100, -off(), s, 0));
  }
  points.add(p(100, -off(), 100, -off()));
  for (final s in stops(across).reversed) {
    points.add(p(s, 0, 100, -off()));
  }
  points.add(p(0, off(), 100, -off()));
  for (final s in stops(down).reversed) {
    points.add(p(0, off(), s, 0));
  }
  return CutEdge(List.unmodifiable(points));
}

/// A cut top edge for a full-width band, as SVG path data in a
/// [width] x [height] box. The band is filled below the edge.
String cutBandPath(Object seed, {double width = 1440, double height = 24, int segments = 36}) {
  final rand = paperRng(seed);
  final step = width / segments;
  final d = StringBuffer('M0 ${jsNum(height)}');
  for (var i = 0; i <= segments; i++) {
    final jitter = i > 0 && i < segments ? (rand() - 0.5) * step * 0.5 : 0.0;
    final x = _r2(i * step + jitter < width ? i * step + jitter : width);
    final y = _r2(height * 0.25 + rand() * height * 0.55);
    d.write(' L${jsNum(x)} ${jsNum(y)}');
  }
  d.write(' L${jsNum(width)} ${jsNum(height)} Z');
  return d.toString();
}

/// A low Gurugram roofline for the top edge of a full-width strip, as SVG path
/// data in a [width] x [height] box, filled below the roofline: flat roofs at
/// varied heights, water tanks, stair rooms, parapet steps and narrow gaps.
/// Port of `rooflineBandPath` in `tool/paper/cut.ts`.
String rooflineBandPath(Object seed, {double width = 390, double height = 18}) {
  final rand = paperRng(seed);
  final h = height;
  final d = StringBuffer('M0 ${jsNum(height)}');
  void at(double x, double y) => d.write(' L${jsNum(_r2(x < width ? x : width))} ${jsNum(_r2(y))}');
  var x = 0.0;
  while (x < width) {
    final next = x + h * (1.4 + rand() * 1.9);
    final end = next < width ? next : width;
    var y = h * (0.32 + rand() * 0.48);
    final kind = rand();
    final lead = rand();
    final room = end - x;
    at(x, y);
    if (kind < 0.42 && room > h * 1.3) {
      // A water tank on a short stand; the top corners are cut off.
      final tw = h * 0.42;
      final tx = x + h * 0.25 + lead * (room - tw - h * 0.5);
      final stand = y - h * 0.08;
      final top = stand - h * 0.22;
      final c = h * 0.06;
      at(tx + tw * 0.25, y);
      at(tx + tw * 0.25, stand);
      at(tx, stand);
      at(tx, top + c);
      at(tx + c, top);
      at(tx + tw - c, top);
      at(tx + tw, top + c);
      at(tx + tw, stand);
      at(tx + tw * 0.75, stand);
      at(tx + tw * 0.75, y);
    } else if (kind < 0.62 && room > h * 1.6) {
      // A stair room with a slab that overhangs it a little.
      final sw = h * 0.62;
      final sx = x + h * 0.2 + lead * (room - sw - h * 0.4);
      final top = y - h * 0.26;
      final lip = h * 0.06;
      at(sx, y);
      at(sx, top + lip);
      at(sx - lip, top + lip);
      at(sx - lip, top);
      at(sx + sw + lip, top);
      at(sx + sw + lip, top + lip);
      at(sx + sw, top + lip);
      at(sx + sw, y);
    } else if (kind < 0.82) {
      // A parapet step: the far end of the roof stands a little higher.
      final px = x + room * (0.55 + lead * 0.25);
      at(px, y);
      y -= h * 0.12;
      at(px, y);
    }
    at(end, y);
    if (end < width && rand() < 0.28) {
      // A narrow gap between two blocks.
      final gap = h * (0.08 + rand() * 0.1);
      at(end, h * 0.86);
      at(end + gap, h * 0.86);
      x = end + gap;
    } else {
      x = end;
    }
  }
  d.write(' L${jsNum(width)} ${jsNum(height)} Z');
  return d.toString();
}

/// The torn bottom edge of a receipt from x = 0 to [width]: teeth about
/// [tooth] wide and [depth] deep. Valleys sit near y = 0, tips near y = depth,
/// and both ends on y = 0. Port of `zigzagEdge` in `tool/paper/cut.ts`.
List<Offset> zigzagPoints(Object seed, double width, {double tooth = 8, double depth = 5}) {
  final rand = paperRng(seed);
  final rounded = jsRound(width / tooth).toInt();
  final n = rounded > 2 ? rounded : 2;
  final step = width / n;
  final points = <Offset>[Offset.zero];
  for (var i = 0; i < n; i++) {
    final tip = _r2(i * step + step * (0.5 + (rand() - 0.5) * 0.3));
    points.add(Offset(tip, _r2(depth * (0.78 + rand() * 0.22))));
    points.add(
      i + 1 < n ? Offset(_r2((i + 1) * step), _r2(rand() * depth * 0.18)) : Offset(width, 0),
    );
  }
  return points;
}

/// [zigzagPoints] as open SVG path data, as `zigzagEdge` in `cut.ts` returns it.
String zigzagEdge(Object seed, double width, {double tooth = 8, double depth = 5}) {
  final points = zigzagPoints(seed, width, tooth: tooth, depth: depth);
  return [
    for (var i = 0; i < points.length; i++)
      '${i == 0 ? 'M' : 'L'}${jsNum(points[i].dx)} ${jsNum(points[i].dy)}',
  ].join(' ');
}

final _pathToken = RegExp(r'[MmLlZz]|-?(?:\d+\.?\d*|\.\d+)');

/// Parses SVG path data made only of move, line and close commands (absolute
/// or relative). Anything else throws a [FormatException].
Path parsePaperPath(String d, {PathFillType fillType = PathFillType.evenOdd}) {
  final path = Path()..fillType = fillType;
  var command = '';
  var x = 0.0, y = 0.0, startX = 0.0, startY = 0.0;
  final tokens = _pathToken.allMatches(d).map((m) => m[0]!).toList();
  if ((tokens.isNotEmpty && tokens.first != 'M' && tokens.first != 'm') ||
      tokens.join().length != d.replaceAll(RegExp(r'[\s,]'), '').length) {
    throw FormatException('Unsupported path data', d);
  }
  for (var i = 0; i < tokens.length;) {
    final token = tokens[i];
    if ('MmLl'.contains(token)) {
      command = token;
      i++;
      continue;
    }
    if (token == 'Z' || token == 'z') {
      path.close();
      x = startX;
      y = startY;
      i++;
      continue;
    }
    if (command.isEmpty || i + 1 >= tokens.length) throw FormatException('Bad path data', d);
    final a = double.parse(token);
    final b = double.parse(tokens[i + 1]);
    i += 2;
    final relative = command == 'm' || command == 'l';
    x = relative ? x + a : a;
    y = relative ? y + b : b;
    if (command == 'M' || command == 'm') {
      path.moveTo(x, y);
      startX = x;
      startY = y;
      // Further pairs after a move are lines of the same kind.
      command = command == 'M' ? 'L' : 'l';
    } else {
      path.lineTo(x, y);
    }
  }
  return path;
}
