import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/design/app_design_theme.dart';
import 'package:ghar360/core/widgets/paper/folder_tabs.dart';
import 'package:ghar360/core/widgets/paper/paper_scroll_page.dart';
import 'package:ghar360/core/widgets/paper/scene_header_sliver.dart';
import '../../../helpers/load_app_fonts.dart';
import '../../../helpers/provider_test_app.dart';

Future<ScrollController> _pump(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double scale = 1,
  Locale locale = const Locale('en', 'US'),
  String title = 'Saved',
  bool still = false,
  PaperSceneSpec? scene,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 47);
  addTearDown(tester.view.reset);
  final controller = ScrollController();
  addTearDown(controller.dispose);
  await tester.pumpProviderApp(
    Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: still),
        child: Scaffold(
          body: PaperScrollPage(
            controller: controller,
            header: SceneHeaderSliver(
              title: title,
              qaId: 'qa.test.title',
              scene: scene ?? PaperSceneSpec.saved(litCount: 3),
              actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.search))],
              tabs: FolderTabs(
                labels: const ['Liked 12', 'Passed 4'],
                selected: 0,
                onSelect: (_) {},
              ),
            ),
            slivers: [
              SliverList.list(
                children: [
                  for (var i = 0; i < 40; i++) SizedBox(height: 56, child: Text('row $i')),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
    theme: AppDesignTheme.light(),
    textScale: scale,
    locale: locale,
  );
  return controller;
}

Finder get _titleText =>
    find.descendant(of: find.bySemanticsIdentifier('qa.test.title'), matching: find.byType(Text));

void main() {
  setUpAll(loadAppFonts);

  testWidgets('the title is visible, inside the header, at max and min extent', (tester) async {
    final controller = await _pump(tester);
    final header = find.byType(SceneHeaderSliver);
    final expanded = tester.getRect(_titleText);
    expect(
      expanded.top,
      greaterThanOrEqualTo(47 + 56),
      reason: 'expanded: in the band, under the bar',
    );

    controller.jumpTo(600);
    await tester.pump();
    final compact = tester.getRect(_titleText);
    final min = tester.getRect(find.descendant(of: header, matching: find.byType(Stack)).first);
    expect(compact.top, greaterThanOrEqualTo(47));
    expect(compact.bottom, lessThanOrEqualTo(47 + SceneHeaderSliver.bar));
    expect(min.contains(compact.center), isTrue);
    expect(compact.height, lessThan(expanded.height), reason: 'the compact title is smaller');
    final semantics = tester.getSemantics(find.bySemanticsIdentifier('qa.test.title'));
    expect(semantics.flagsCollection.isHeader, isTrue);
  });

  testWidgets('extents: band at most 148 on a phone; smaller at 320 px and 2x text', (
    tester,
  ) async {
    await _pump(tester);
    final context = tester.element(find.byType(SceneHeaderSliver));
    final scene = PaperSceneSpec.saved();
    final tabs = FolderTabs(labels: const ['Liked 12', 'Passed 4'], selected: 0, onSelect: (_) {});
    final phone = SceneHeaderSliver.extentsFor(
      context,
      width: 390,
      scene: scene,
      title: 'Saved',
      tabs: tabs,
    );
    expect(phone.band, 148);
    expect(phone.max - phone.min, 148);
    expect(phone.min, 47 + 56 + phone.bottom);

    await _pump(
      tester,
      size: const Size(320, 700),
      scale: 2,
      locale: const Locale('hi', 'IN'),
      title: 'सहेजे गए',
    );
    final small = SceneHeaderSliver.extentsFor(
      tester.element(find.byType(SceneHeaderSliver)),
      width: 320,
      scene: scene,
      title: 'सहेजे गए',
      tabs: tabs,
    );
    expect(small.band, lessThan(phone.band));
    expect(small.bottom, greaterThan(phone.bottom), reason: 'the tabs grow with the text');
    // The list keeps most of the screen even when expanded.
    expect(small.max, lessThan(700 * 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the scene band bakes a scene for every spec without errors', (tester) async {
    for (final scene in [
      PaperSceneSpec.visits(),
      PaperSceneSpec.profile(),
      PaperSceneSpec.assistant(),
      PaperSceneSpec.skyline(),
    ]) {
      await _pump(tester, scene: scene);
      expect(find.byType(RawImage), findsWidgets);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('reduced motion: the scene layers do not move while collapsing', (tester) async {
    final controller = await _pump(tester, still: true);
    Offset sceneTopLeft() => tester.getTopLeft(find.byType(RawImage).last);
    final before = sceneTopLeft();
    controller.jumpTo(40);
    await tester.pump();
    expect(sceneTopLeft(), before);
  });
}
