import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/design/app_design_theme.dart';
import 'package:ghar360/core/design/paper/paper_scene_data.dart';
import 'package:ghar360/core/widgets/paper/baked_paper_scene.dart';

List<ui.Image> _images(WidgetTester tester) => [
  for (final raw in tester.widgetList<RawImage>(find.byType(RawImage))) raw.image!,
];

Future<void> _pump(WidgetTester tester, {int? litCount, Size size = const Size(390, 160)}) =>
    tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.light(),
        home: Center(
          child: SizedBox.fromSize(
            size: size,
            child: BakedPaperScene(
              art: paperHeaders['saved']!,
              fit: BoxFit.fitHeight,
              litCount: litCount,
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('bakes once; a new litCount or size bakes again and frees the old images', (
    tester,
  ) async {
    await _pump(tester, litCount: 2);
    final first = _images(tester);
    expect(first, isNotEmpty);
    await _pump(tester, litCount: 2);
    expect(_images(tester), first, reason: 'same inputs reuse the images');

    await _pump(tester, litCount: 5);
    await tester.pump();
    final second = _images(tester);
    expect(second.toSet().intersection(first.toSet()), isEmpty);
    expect(first.every((image) => image.debugDisposed), isTrue);

    await _pump(tester, litCount: 5, size: const Size(320, 120));
    await tester.pump();
    expect(second.every((image) => image.debugDisposed), isTrue);

    final last = _images(tester);
    await tester.pumpWidget(const SizedBox());
    expect(last.every((image) => image.debugDisposed), isTrue);
  });

  testWidgets('the transform places each group; null hides it', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 390,
          height: 160,
          child: BakedPaperScene(
            art: paperHeaders['visits']!,
            fit: BoxFit.fitHeight,
            layerKeyPrefix: 't.',
            transform: (b, size) {
              calls++;
              return b.layer.id == 'sun'
                  ? null
                  : Matrix4.translationValues(b.rect.left, b.rect.top, 0);
            },
          ),
        ),
      ),
    );
    expect(calls, greaterThan(0));
    expect(find.byKey(const ValueKey('t.sun')), findsOneWidget, reason: 'baked, but not painted');
    expect(tester.takeException(), isNull);
  });
}
