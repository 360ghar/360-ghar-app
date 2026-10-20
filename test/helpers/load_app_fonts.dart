import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_test/flutter_test.dart';

/// Golden tests use the same local font bytes as the app, including Hindi.
Future<void> loadAppFonts() async {
  for (final entry in const {
    'Manrope': ['assets/fonts/manrope/Manrope[wght].ttf'],
    'Erode': [
      'assets/fonts/erode/Erode-Regular.ttf',
      'assets/fonts/erode/Erode-Medium.ttf',
      'assets/fonts/erode/Erode-Semibold.ttf',
      'assets/fonts/erode/Erode-Bold.ttf',
    ],
    'Noto Sans Devanagari': ['assets/fonts/notosansdevanagari/NotoSansDevanagari[wdth,wght].ttf'],
    'Noto Serif Devanagari': [
      'assets/fonts/notoserifdevanagari/NotoSerifDevanagari[wdth,wght].ttf',
    ],
    'MaterialIcons': ['fonts/MaterialIcons-Regular.otf'],
  }.entries) {
    final loader = FontLoader(entry.key);
    for (final path in entry.value) {
      loader.addFont(rootBundle.load(path));
    }
    await loader.load();
  }
}

/// File I/O, decode and image-stream microtasks cross real/fake async zones.
/// Advance each zone until all displayed photos arrive; a missing frame fails.
Future<void> settleFixturePhotos(WidgetTester tester) async {
  final expected = tester.widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage)).length;
  // Count photo images only: baked paper scenes also paint RawImages.
  bool decoded() =>
      tester
          .widgetList<RawImage>(
            find.descendant(of: find.byType(CachedNetworkImage), matching: find.byType(RawImage)),
          )
          .where((image) => image.image != null)
          .length >=
      expected;
  for (var attempt = 0; attempt < 30 && !decoded(); attempt++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(
    decoded(),
    isTrue,
    reason: 'All fixture photos must decode before snapshot or measurement.',
  );
  await tester.pump(const Duration(milliseconds: 200));
}
