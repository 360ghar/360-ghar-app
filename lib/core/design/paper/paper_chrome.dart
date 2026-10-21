import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:ghar360/core/design/paper/paper_cut.dart';

/// How far a sheet sits above the surface below it.
enum PaperElevation { flat, low, mid, high }

/// Short shadows from one light at the top left: a contact line and one drop
/// with negative spread, tinted by the surface below. Never a wide bloom.
List<BoxShadow> paperShadows(PaperElevation elevation, Color tint) {
  if (elevation == PaperElevation.flat) return const [];
  final contact = BoxShadow(
    color: tint.withValues(alpha: 0.06),
    offset: const Offset(0.5, 1),
    blurRadius: 1,
  );
  final (offset, blur, spread, alpha) = switch (elevation) {
    PaperElevation.low => (const Offset(1.5, 3), 6.0, -3.0, 0.14),
    PaperElevation.mid => (const Offset(3, 6), 14.0, -6.0, 0.16),
    _ => (const Offset(4, 10), 20.0, -8.0, 0.18),
  };
  return [
    contact,
    BoxShadow(
      color: tint.withValues(alpha: alpha),
      offset: offset,
      blurRadius: blur,
      spreadRadius: spread,
    ),
  ];
}

/// A sheet outline cut by hand from [seed]. It paints its own [shadows]
/// outside the shape, so a Material, dialog or sheet needs no clip.
///
/// Every cut point sits at most [amp] pixels inside the rect: pad content by
/// more than [amp] and nothing is cut.
class CutBorder extends OutlinedBorder {
  const CutBorder({required this.seed, this.amp = 2, this.shadows = const [], super.side});

  final String seed;
  final double amp;
  final List<BoxShadow> shadows;

  CutEdge get _edge => cutPolygon(seed, amp: amp);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _edge.toPath(rect);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _edge.toPath(rect.deflate(side.strokeInset));

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (shadows.isNotEmpty) {
      final outer = getOuterPath(rect);
      canvas.save();
      // Shadows land only outside the sheet, so a translucent fill stays clean.
      canvas.clipPath(
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(rect.inflate(64))
          ..addPath(outer, Offset.zero),
      );
      for (final shadow in shadows) {
        canvas.drawPath(
          getOuterPath(rect.shift(shadow.offset).inflate(shadow.spreadRadius)),
          shadow.toPaint(),
        );
      }
      canvas.restore();
    }
    if (side.style != BorderStyle.none) {
      canvas.drawPath(getOuterPath(rect), side.toPaint());
    }
  }

  @override
  CutBorder copyWith({BorderSide? side, String? seed, double? amp, List<BoxShadow>? shadows}) =>
      CutBorder(
        seed: seed ?? this.seed,
        amp: amp ?? this.amp,
        shadows: shadows ?? this.shadows,
        side: side ?? this.side,
      );

  @override
  ShapeBorder scale(double t) => CutBorder(
    seed: seed,
    amp: amp * t,
    shadows: [for (final shadow in shadows) shadow.scale(t)],
    side: side.scale(t),
  );

  @override
  bool operator ==(Object other) =>
      other.runtimeType == runtimeType &&
      other is CutBorder &&
      other.seed == seed &&
      other.amp == amp &&
      other.side == side &&
      listEquals(other.shadows, shadows);

  @override
  int get hashCode => Object.hash(seed, amp, side, Object.hashAll(shadows));
}

/// A receipt: a sheet with a hand-cut top and sides like [CutBorder] and a
/// torn zigzag bottom edge. Teeth are about [tooth] wide; they hang up to
/// [depth] pixels into the bottom of the rect. It paints its own [shadows]
/// outside the shape, like [CutBorder].
///
/// Pad content by more than [amp] on the top and sides and by more than
/// [depth] at the bottom, so nothing is cut.
class ReceiptBorder extends CutBorder {
  const ReceiptBorder({
    required super.seed,
    super.amp,
    super.shadows,
    super.side,
    this.tooth = 8,
    this.depth = 5,
  });

  final double tooth;
  final double depth;

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    // The cut sheet ends where the teeth begin; the teeth run right to left.
    final body = Rect.fromLTRB(rect.left, rect.top, rect.right, rect.bottom - depth);
    final sheet = cutPolygon(seed, amp: amp).points;
    final firstBottom = sheet.indexWhere((p) => p.yPercent == 100);
    Offset at(CutPoint p) => Offset(
      body.left + body.width * p.xPercent / 100 + p.xPx,
      body.top + body.height * p.yPercent / 100 + p.yPx,
    );
    final teeth = zigzagPoints(seed, rect.width, tooth: tooth, depth: depth).reversed;
    final points = [
      for (final p in sheet.take(firstBottom)) at(p),
      for (final t in teeth) Offset(rect.left + t.dx, body.bottom + t.dy),
      for (final p in sheet.skip(firstBottom).where((p) => p.yPercent < 100)) at(p),
    ];
    return Path()..addPolygon(points, true);
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect.deflate(side.strokeInset));

  @override
  ReceiptBorder copyWith({
    BorderSide? side,
    String? seed,
    double? amp,
    List<BoxShadow>? shadows,
    double? tooth,
    double? depth,
  }) => ReceiptBorder(
    seed: seed ?? this.seed,
    amp: amp ?? this.amp,
    shadows: shadows ?? this.shadows,
    side: side ?? this.side,
    tooth: tooth ?? this.tooth,
    depth: depth ?? this.depth,
  );

  @override
  ShapeBorder scale(double t) => ReceiptBorder(
    seed: seed,
    amp: amp * t,
    shadows: [for (final shadow in shadows) shadow.scale(t)],
    side: side.scale(t),
    tooth: tooth * t,
    depth: depth * t,
  );

  @override
  bool operator ==(Object other) =>
      other is ReceiptBorder && other.tooth == tooth && other.depth == depth && super == other;

  @override
  int get hashCode => Object.hash(super.hashCode, tooth, depth);
}
