import 'package:flutter/widgets.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/utils/responsive.dart';

void main() {
  group('windowSizeClassForWidth', () {
    test('maps boundary widths to the expected class', () {
      expect(windowSizeClassForWidth(0), WindowSizeClass.compact);
      expect(windowSizeClassForWidth(399), WindowSizeClass.compact);
      expect(windowSizeClassForWidth(599), WindowSizeClass.compact);
      expect(windowSizeClassForWidth(600), WindowSizeClass.medium);
      expect(windowSizeClassForWidth(700), WindowSizeClass.medium);
      expect(windowSizeClassForWidth(839), WindowSizeClass.medium);
      expect(windowSizeClassForWidth(840), WindowSizeClass.expanded);
      expect(windowSizeClassForWidth(1100), WindowSizeClass.expanded);
      expect(windowSizeClassForWidth(1199), WindowSizeClass.expanded);
      expect(windowSizeClassForWidth(1200), WindowSizeClass.large);
      expect(windowSizeClassForWidth(1920), WindowSizeClass.large);
    });
  });

  group('responsiveValueForClass fallback walk', () {
    test('returns the exact band when defined', () {
      expect(
        responsiveValueForClass<int>(
          WindowSizeClass.expanded,
          compact: 1,
          medium: 2,
          expanded: 3,
          large: 4,
          fallback: 0,
        ),
        3,
      );
    });

    test('walks down to nearest smaller band', () {
      // large not defined -> expanded
      expect(
        responsiveValueForClass<int>(
          WindowSizeClass.large,
          compact: 1,
          medium: 2,
          expanded: 3,
          fallback: 0,
        ),
        3,
      );
      // large + expanded not defined -> medium
      expect(
        responsiveValueForClass<int>(WindowSizeClass.large, compact: 1, medium: 2, fallback: 0),
        2,
      );
      // nothing but compact defined -> compact
      expect(responsiveValueForClass<int>(WindowSizeClass.expanded, compact: 1, fallback: 0), 1);
    });

    test('uses fallback when nothing matches', () {
      expect(responsiveValueForClass<int>(WindowSizeClass.compact, fallback: 42), 42);
      // A higher class with no defined bands also falls through to fallback.
      expect(responsiveValueForClass<int>(WindowSizeClass.large, fallback: 7), 7);
    });

    test('does not borrow from a larger band', () {
      // compact has nothing; medium+large defined. Compact must NOT use medium.
      expect(
        responsiveValueForClass<int>(WindowSizeClass.compact, medium: 2, large: 4, fallback: 9),
        9,
      );
    });
  });

  group('ResponsiveContext extension', () {
    testWidgets('exposes windowSizeClass and contentMaxWidth', (tester) async {
      // Pin the test viewport so the assertions don't drift if the default
      // surface size changes between Flutter versions / CI environments.
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      double? reportedClass;
      double? maxWidth;

      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xFFFFFFFF),
          builder: (context, child) {
            reportedClass = context.windowSizeClass.index.toDouble();
            maxWidth = context.contentMaxWidth;
            return const SizedBox();
          },
        ),
      );

      // 800 logical px wide => medium.
      expect(reportedClass, WindowSizeClass.medium.index);
      expect(maxWidth, kContentMaxWidths[WindowSizeClass.medium]);
    });
  });
}
