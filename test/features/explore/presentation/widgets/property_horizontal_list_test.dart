import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/widgets/common/animated_tap_wrapper.dart';
import 'package:ghar360/features/explore/presentation/widgets/property_horizontal_list.dart';
import 'package:ghar360/features/properties/application/property_queries.dart';
import '../../../../helpers/explore_test_harness.dart';
import '../../../../helpers/knife_finders.dart';
import '../../../../helpers/provider_test_app.dart';

void main() {
  late ExploreTestHarness harness;
  setUp(() => harness = ExploreTestHarness());
  tearDown(() => harness.dispose());
  Future<void> pump(
    WidgetTester tester, {
    double scale = 1,
    ValueChanged<PropertyModel>? onOpen,
    int? openId,
  }) async {
    await tester.pumpProviderApp(
      UncontrolledProviderScope(
        container: harness.container,
        child: Scaffold(
          body: PropertyHorizontalList(onOpen: onOpen, openId: openId),
        ),
      ),
      textScale: scale,
    );
    await tester.pump();
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  void seed(List<int> ids, {String? cursor}) => harness.query.seed(
    PropertyPageState(
      phase: PropertyLoadPhase.content,
      items: ids.map(exploreProperty).toList(),
      nextCursor: cursor,
    ),
  );
  testWidgets('horizontal mode renders one card per visible property', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    seed([1, 2, 3]);
    await pump(tester);
    for (final id in [1, 2, 3]) {
      expect(find.text('Property $id'), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
    await dispose(tester);
  });
  testWidgets('empty strip shows no-properties message', (tester) async {
    await pump(tester);
    expect(find.text('No homes in this area'), findsOneWidget);
    await dispose(tester);
  });
  testWidgets('favorite action updates authoritative swipe state', (tester) async {
    seed([1]);
    await pump(tester);
    await tester.tap(findKnife(KnifeIcon.heart));
    await tester.pump();
    expect(harness.history.entries[1]?.isLiked, isTrue);
    expect(findKnife(KnifeIcon.heartSolid), findsOneWidget);
    await dispose(tester);
  });
  testWidgets('large text keeps cards inside the strip', (tester) async {
    seed([1, 2]);
    await pump(tester, scale: 2);
    expect(find.text('Property 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await dispose(tester);
  });
  testWidgets('with a pane, a tap opens the home there and highlights it on the map', (
    tester,
  ) async {
    seed([1, 2]);
    PropertyModel? opened;
    await pump(tester, onOpen: (property) => opened = property);
    await tester.tap(find.text('Property 2'));
    await tester.pump();
    expect(opened?.id, 2);
    expect(harness.state.selectedId, 2);
    await dispose(tester);
  });
  testWidgets('a like or a highlight rebuilds only the cards it touches', (tester) async {
    seed([1, 2, 3]);
    await pump(tester);
    var builds = 0;
    final prior = debugOnRebuildDirtyWidget;
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      if (element.widget is PropertyHorizontalList) builds++;
      prior?.call(element, builtOnce);
    };
    addTearDown(() => debugOnRebuildDirtyWidget = prior);
    harness.controller.highlightPropertyFromCard(exploreProperty(2));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('qa.property.card.2')),
        matching: find.byType(AnimatedFavoriteIcon),
      ),
    );
    await tester.pump();
    expect(harness.history.entries[2]?.isLiked, isTrue);
    expect(builds, 0);
    debugOnRebuildDirtyWidget = prior;
    await dispose(tester);
  });
  testWidgets('selecting a map property scrolls to its corresponding card', (tester) async {
    seed(List.generate(8, (index) => index + 1));
    await pump(tester);
    harness.controller.selectProperty(exploreProperty(8));
    await tester.pumpAndSettle();
    expect(find.text('Property 8'), findsOneWidget);
    await dispose(tester);
  });
  testWidgets('short page requests next cursor and normal scrolling highlights card', (
    tester,
  ) async {
    seed([1], cursor: 'next');
    await pump(tester);
    expect(harness.query.loadMoreCalls, greaterThan(0));
    seed(List.generate(8, (index) => index + 1));
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(-400, 0));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 100));
    expect(harness.state.selectedId, isNotNull);
    await dispose(tester);
  });
}
