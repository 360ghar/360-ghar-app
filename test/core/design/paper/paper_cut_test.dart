import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/design/paper/paper_cut.dart';

/// Rebuilds the CSS `polygon()` string that `cut.ts` returns.
String _css(CutEdge edge) {
  String axis(double percent, double px) {
    if (percent == 0) return '${jsNum(px)}px';
    if (percent == 100) return 'calc(100% - ${jsNum(-px)}px)';
    return '${jsNum(percent)}%';
  }

  return 'polygon(${edge.points.map((p) => '${axis(p.xPercent, p.xPx)} ${axis(p.yPercent, p.yPx)}').join(', ')})';
}

void main() {
  final fixtures =
      jsonDecode(File('test/fixtures/paper_fixtures.json').readAsStringSync())
          as Map<String, dynamic>;

  test('rng matches mulberry32 from cut.ts', () {
    for (final entry in fixtures['rng'] as List) {
      final rand = paperRng((entry as Map)['seed'] as Object);
      expect([for (var i = 0; i < 6; i++) rand()], entry['values']);
    }
  });

  test('hash matches FNV-1a over UTF-16 code units', () {
    for (final entry in fixtures['hash'] as List) {
      expect(paperHash((entry as Map)['input'] as String), entry['value']);
    }
  });

  test('cutPolygon matches the CSS polygon from cut.ts', () {
    for (final entry in fixtures['cutPolygon'] as List) {
      final options = (entry as Map)['options'] as Map;
      final edge = cutPolygon(
        entry['seed'] as Object,
        amp: (options['amp'] as num?)?.toDouble() ?? 2,
        across: options['across'] as int? ?? 9,
        down: options['down'] as int? ?? 5,
      );
      expect(_css(edge), entry['css']);
    }
  });

  test('cutBandPath matches cut.ts', () {
    for (final entry in fixtures['cutBandPath'] as List) {
      final band = entry as Map;
      expect(
        cutBandPath(
          band['seed'] as Object,
          width: (band['width'] as num).toDouble(),
          height: (band['height'] as num).toDouble(),
          segments: band['segments'] as int,
        ),
        band['d'],
      );
    }
  });

  test('rooflineBandPath matches cut.ts and stays inside its box', () {
    for (final entry in fixtures['rooflineBandPath'] as List) {
      final band = entry as Map;
      final width = (band['width'] as num).toDouble();
      final height = (band['height'] as num).toDouble();
      final d = rooflineBandPath(band['seed'] as Object, width: width, height: height);
      expect(d, band['d']);
      final bounds = parsePaperPath(d, fillType: PathFillType.nonZero).getBounds();
      expect(Rect.fromLTWH(0, 0, width, height).inflate(0.01).contains(bounds.topLeft), isTrue);
      expect(bounds.right, closeTo(width, 0.01));
      expect(bounds.bottom, height);
    }
  });

  test('zigzagEdge matches cut.ts; teeth hang at most depth below the line', () {
    for (final entry in fixtures['zigzagEdge'] as List) {
      final zig = entry as Map;
      final seed = zig['seed'] as Object;
      final width = (zig['width'] as num).toDouble();
      final tooth = (zig['tooth'] as num).toDouble();
      final depth = (zig['depth'] as num).toDouble();
      expect(zigzagEdge(seed, width, tooth: tooth, depth: depth), zig['d']);
      final points = zigzagPoints(seed, width, tooth: tooth, depth: depth);
      expect(points.first, Offset.zero);
      expect(points.last, Offset(width, 0));
      expect(points.every((p) => p.dy >= 0 && p.dy <= depth), isTrue);
    }
  });

  test('jsRound rounds halves up like Math.round', () {
    expect(jsRound(2.5), 3);
    expect(jsRound(-2.5), -2);
    expect(jsRound(0.49999999999999994), 0);
    expect(jsRound(-0.4), 0);
  });

  test('cut edge keeps pixel offsets while the sheet scales', () {
    final edge = cutPolygon('sheet', amp: 3);
    for (final rect in [
      const Rect.fromLTWH(0, 0, 100, 50),
      const Rect.fromLTWH(10, 20, 400, 300),
    ]) {
      final bounds = edge.toPath(rect).getBounds();
      expect(rect.contains(bounds.topLeft), isTrue);
      expect(bounds.left - rect.left, lessThanOrEqualTo(3));
      expect(rect.right - bounds.right, lessThanOrEqualTo(3));
      expect(rect.bottom - bounds.bottom, lessThanOrEqualTo(3));
    }
  });

  group('parsePaperPath', () {
    test('reads absolute and relative commands with implicit lines', () {
      final path = parsePaperPath('M0 0L10 0 10 10 0 10Zm2 2l6 0 0 6-6 0z');
      expect(path.getBounds(), const Rect.fromLTRB(0, 0, 10, 10));
      // The inner square is a hole under even-odd.
      expect(path.contains(const Offset(5, 5)), isFalse);
      expect(path.contains(const Offset(1, 1)), isTrue);
    });

    test('reads compact numbers', () {
      final path = parsePaperPath('M1.5.5l2-.5.5 2z');
      expect(path.getBounds().left, 1.5);
      expect(path.getBounds().top, 0);
    });

    test('rejects curves', () {
      expect(() => parsePaperPath('M0 0C1 1 2 2 3 3'), throwsFormatException);
      expect(() => parsePaperPath('L1 1'), throwsFormatException);
    });
  });

  test('rooflineBandPath with a non-positive height returns at once', () {
    expect(rooflineBandPath('seed', height: 0), isNotEmpty);
    expect(rooflineBandPath('seed', height: -4), isNotEmpty);
  });
}
