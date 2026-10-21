import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';

void main() {
  testWidgets('a forced minimum box centres the mark instead of stretching it', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            child: const PaperIcon(KnifeIcon.search),
          ),
        ),
      ),
    );
    final paint = find.descendant(of: find.byType(PaperIcon), matching: find.byType(CustomPaint));
    expect(tester.getSize(find.byType(PaperIcon)), const Size(44, 44));
    expect(tester.getSize(paint), const Size(24, 24));
    expect(tester.getCenter(paint), tester.getCenter(find.byType(PaperIcon)));
  });

  testWidgets('size and colour come from IconTheme when not given', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: IconTheme(
          data: IconThemeData(size: 18, color: Color(0xFF9A6D00)),
          child: Center(child: PaperIcon(KnifeIcon.home, semanticLabel: 'Home')),
        ),
      ),
    );
    expect(tester.getSize(find.byType(PaperIcon)), const Size(18, 18));
    expect(find.bySemanticsLabel('Home'), findsOneWidget);
  });
}
