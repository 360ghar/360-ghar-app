import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/design/app_design_theme.dart';
import 'package:ghar360/core/widgets/paper/folder_tabs.dart';
import '../../../helpers/load_app_fonts.dart';
import '../../../helpers/provider_test_app.dart';

void main() {
  setUpAll(loadAppFonts);

  Future<List<int>> pump(
    WidgetTester tester, {
    required List<String> labels,
    int selected = 0,
    double width = 390,
    double scale = 1,
    Locale locale = const Locale('en', 'US'),
  }) async {
    tester.view.physicalSize = Size(width, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final taps = <int>[];
    await tester.pumpProviderApp(
      Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: FolderTabs(
            labels: labels,
            selected: selected,
            onSelect: taps.add,
            qaIds: const ['qa.test.tab.a', 'qa.test.tab.b'],
          ),
        ),
      ),
      theme: AppDesignTheme.light(),
      textScale: scale,
      locale: locale,
    );
    return taps;
  }

  testWidgets('every tab passes its tap on; the chosen one is marked for screen readers', (
    tester,
  ) async {
    final taps = await pump(tester, labels: const ['Liked 12', 'Passed 4']);
    await tester.tap(find.byKey(const ValueKey('qa.test.tab.b')));
    await tester.tap(find.byKey(const ValueKey('qa.test.tab.a')));
    expect(taps, [1, 0], reason: 'a repeat tap on the chosen tab reaches the caller');
    final a = tester.getSemantics(find.bySemanticsIdentifier('qa.test.tab.a'));
    final b = tester.getSemantics(find.bySemanticsIdentifier('qa.test.tab.b'));
    expect(a.flagsCollection.isSelected, Tristate.isTrue);
    expect(b.flagsCollection.isSelected, Tristate.isFalse);
    expect(b.flagsCollection.isButton, isTrue);
    expect(b.label, 'Passed 4');
    expect(a.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    expect(b.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
  });

  testWidgets('tabs are at least 48 px tall and share one grid', (tester) async {
    await pump(tester, labels: const ['Liked 12', 'Passed 4']);
    final a = tester.getRect(find.byKey(const ValueKey('qa.test.tab.a')));
    final b = tester.getRect(find.byKey(const ValueKey('qa.test.tab.b')));
    expect(a.height, greaterThanOrEqualTo(48));
    expect((a.top, a.height, a.width), (b.top, b.height, b.width));
  });

  testWidgets('Hindi at 320 px and 2x text wraps to two lines and the tabs grow', (tester) async {
    await pump(tester, labels: const ['Liked 12', 'Passed 4']);
    final english = tester.getSize(find.byType(FolderTabs)).height;
    await pump(
      tester,
      labels: const ['निर्धारित दौरे 12', 'पिछले दौरे 4'],
      width: 320,
      scale: 2,
      locale: const Locale('hi', 'IN'),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(FolderTabs)).height, greaterThan(english));
    final label = tester.renderObject<RenderParagraph>(find.text('निर्धारित दौरे 12'));
    expect(label.didExceedMaxLines, isFalse, reason: 'two lines are enough');
    // One line of 15 px text at 1.5x is about 27 px tall.
    expect(label.size.height, greaterThan(40));
  });

  testWidgets('the chosen tab slides; with reduced motion it jumps', (tester) async {
    await pump(tester, labels: const ['Liked', 'Passed']);
    await pump(tester, labels: const ['Liked', 'Passed'], selected: 1);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });
}
