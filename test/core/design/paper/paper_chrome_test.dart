import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/design/paper/paper_chrome.dart';
import 'package:ghar360/core/design/paper/paper_scene_data.dart';

void main() {
  test('shadows are short, fall down and right, and never bloom', () {
    expect(paperShadows(PaperElevation.flat, Colors.black), isEmpty);
    for (final elevation in [PaperElevation.low, PaperElevation.mid, PaperElevation.high]) {
      for (final shadow in paperShadows(elevation, Colors.black)) {
        expect(shadow.offset.dx, greaterThan(0));
        expect(shadow.offset.dy, greaterThan(0));
        expect(shadow.blurRadius, lessThanOrEqualTo(20));
        expect(shadow.color.a, lessThanOrEqualTo(0.18));
      }
      expect(paperShadows(elevation, Colors.black).last.spreadRadius, lessThan(0));
    }
  });

  test('CutBorder cuts at most amp pixels into its rect', () {
    const border = CutBorder(seed: 'dialog', amp: 3);
    const rect = Rect.fromLTWH(10, 10, 300, 200);
    final bounds = border.getOuterPath(rect).getBounds();
    expect(rect.inflate(0.01).contains(bounds.topLeft), isTrue);
    expect(rect.inflate(0.01).contains(bounds.bottomRight), isTrue);
    expect(bounds.width, greaterThan(rect.width - 6.01));
    expect(border.getInnerPath(rect).getBounds().width, lessThanOrEqualTo(bounds.width));
  });

  test('CutBorder value semantics, copy and scale', () {
    final shadows = paperShadows(PaperElevation.mid, Colors.black);
    final a = CutBorder(seed: 's', shadows: shadows);
    expect(a, CutBorder(seed: 's', shadows: shadows));
    expect(a.hashCode, CutBorder(seed: 's', shadows: shadows).hashCode);
    expect(a, isNot(const CutBorder(seed: 't')));
    expect(a.copyWith(amp: 4).amp, 4);
    final half = a.scale(0.5) as CutBorder;
    expect(half.amp, 1);
    expect(half.shadows.last.blurRadius, shadows.last.blurRadius / 2);
  });

  testWidgets('CutBorder paints its shadow outside the sheet', (tester) async {
    await tester.pumpWidget(
      Center(
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: Colors.white,
            shape: CutBorder(
              seed: 'paint',
              side: const BorderSide(),
              shadows: paperShadows(PaperElevation.high, Colors.black),
            ),
          ),
          child: const SizedBox(width: 100, height: 60),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  test('ReceiptBorder: cut top and sides, a torn bottom inside the rect', () {
    const border = ReceiptBorder(seed: 'emi', amp: 2, depth: 5);
    const rect = Rect.fromLTWH(10, 10, 300, 200);
    final path = border.getOuterPath(rect);
    final bounds = path.getBounds();
    expect(rect.inflate(0.01).contains(bounds.topLeft), isTrue);
    expect(rect.inflate(0.01).contains(bounds.bottomRight), isTrue);
    expect(bounds.bottom, greaterThan(rect.bottom - 1.2), reason: 'tips reach the bottom');
    // Teeth: along a row just above the bottom, paper and gaps alternate.
    var changes = 0;
    var inside = path.contains(Offset(rect.left + 0.5, rect.bottom - 1));
    for (var x = rect.left + 0.5; x < rect.right; x += 0.5) {
      final now = path.contains(Offset(x, rect.bottom - 1));
      if (now != inside) changes++;
      inside = now;
    }
    expect(changes, greaterThan(300 / 8));
    // Everything clear of the cut and the teeth is paper.
    expect(path.contains(Offset(rect.left + 3, rect.top + 3)), isTrue);
    expect(path.contains(Offset(rect.right - 3, rect.bottom - 5.5)), isTrue);
    // Same seed, same tear.
    expect(border.getOuterPath(rect).getBounds(), bounds);
  });

  test('ReceiptBorder value semantics, copy and scale', () {
    const a = ReceiptBorder(seed: 'r');
    expect(a, const ReceiptBorder(seed: 'r'));
    expect(a.hashCode, const ReceiptBorder(seed: 'r').hashCode);
    expect(a, isNot(const CutBorder(seed: 'r')));
    expect(const CutBorder(seed: 'r'), isNot(a));
    expect(a.copyWith(depth: 7).depth, 7);
    final half = a.scale(0.5) as ReceiptBorder;
    expect((half.tooth, half.depth, half.amp), (4, 2.5, 1));
  });

  testWidgets('ReceiptBorder paints its shadow outside the sheet', (tester) async {
    await tester.pumpWidget(
      Center(
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: Colors.white,
            shape: ReceiptBorder(
              seed: 'paint',
              shadows: paperShadows(PaperElevation.low, Colors.black),
            ),
          ),
          child: const SizedBox(width: 160, height: 90),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  test('every icon and every scene path parses', () {
    for (final icon in KnifeIcon.values) {
      final bounds = icon.path.getBounds();
      expect(const Rect.fromLTWH(0, 0, 24, 24).inflate(0.5).contains(bounds.center), isTrue);
    }
    for (final art in [
      gurugramArt,
      ...paperScenes.values,
      ...paperHeaders.values,
      ...paperVignettes.values,
    ]) {
      for (final layer in art.layers) {
        for (final index in layer.lit) {
          expect(index, lessThan(layer.cut.length));
        }
      }
    }
  });
}
