import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/design/app_design_theme.dart';
import 'package:ghar360/core/widgets/navigation/bottom_nav_bar.dart';
import '../../../helpers/provider_test_app.dart';

const _tower = ValueKey('qa.dashboard.nav.tower');
const _ids = ['discover', 'explore_properties', 'saved', 'visits', 'profile'];

void main() {
  Future<void> pumpBar(
    WidgetTester tester,
    int index, {
    bool still = false,
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpProviderApp(
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: still),
          child: Scaffold(
            body: const SizedBox(),
            bottomNavigationBar: CustomBottomNavigationBar(currentIndex: index, onTap: (_) {}),
          ),
        ),
      ),
      theme: AppDesignTheme.light(),
      textScale: scale,
    );
  }

  double itemCentre(WidgetTester tester, int i) =>
      tester.getCenter(find.byKey(ValueKey('qa.dashboard.nav.${_ids[i]}'))).dx;

  testWidgets('the tower stands over the active item and slides to a new one', (tester) async {
    await pumpBar(tester, 0);
    expect(tester.getCenter(find.byKey(_tower)).dx, closeTo(itemCentre(tester, 0), 0.01));
    expect(tester.getSize(find.byKey(_tower)).width, kNavTowerWidth + 4);

    await pumpBar(tester, 3);
    await tester.pump(const Duration(milliseconds: 100));
    final moving = tester.getCenter(find.byKey(_tower)).dx;
    expect(moving, greaterThan(itemCentre(tester, 0)));
    expect(moving, lessThan(itemCentre(tester, 3)), reason: 'it slides, it does not jump');
    await tester.pumpAndSettle();
    expect(tester.getCenter(find.byKey(_tower)).dx, closeTo(itemCentre(tester, 3), 0.01));
  });

  testWidgets('a right-only inset (the Duo pill) leaves the strip centered, tower on its item', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(466, 678);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpProviderApp(
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(padding: const EdgeInsets.only(right: 84)),
          child: Scaffold(
            body: const SizedBox(),
            bottomNavigationBar: CustomBottomNavigationBar(currentIndex: 2, onTap: (_) {}),
          ),
        ),
      ),
      theme: AppDesignTheme.light(),
    );
    final first = tester.getRect(find.byKey(ValueKey('qa.dashboard.nav.${_ids.first}')));
    final last = tester.getRect(find.byKey(ValueKey('qa.dashboard.nav.${_ids.last}')));
    expect(first.left, closeTo(466 - last.right, 0.01), reason: 'same margin on both sides');
    expect(first.left, closeTo(0, 0.01), reason: 'the pill is at the top: full width');
    expect(tester.getCenter(find.byKey(_tower)).dx, closeTo(itemCentre(tester, 2), 0.01));
  });

  testWidgets('with reduced motion the tower jumps', (tester) async {
    await pumpBar(tester, 1, still: true);
    await pumpBar(tester, 4, still: true);
    await tester.pump();
    expect(tester.getCenter(find.byKey(_tower)).dx, closeTo(itemCentre(tester, 4), 0.01));
  });

  testWidgets('the tower sits above the items and the items stay 48 px tall at 2x text', (
    tester,
  ) async {
    await pumpBar(tester, 2, scale: 2);
    final tower = tester.getRect(find.byKey(_tower));
    for (final id in _ids) {
      final item = tester.getRect(find.byKey(ValueKey('qa.dashboard.nav.$id')));
      expect(item.height, greaterThanOrEqualTo(48));
      expect(item.top, greaterThanOrEqualTo(tower.top + 20), reason: 'items start under the roofs');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('the rail tower points at the active item', (tester) async {
    tester.view.physicalSize = const Size(700, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpProviderApp(
      Scaffold(
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PaperNavigationRail(currentIndex: 2, onTap: (_) {}),
            const Expanded(child: SizedBox()),
          ],
        ),
      ),
      theme: AppDesignTheme.dark(),
    );
    final item = tester.getCenter(find.byKey(const ValueKey('qa.dashboard.nav.saved')));
    final tower = tester.getRect(find.byKey(_tower));
    expect(tower.center.dy, closeTo(item.dy, 0.01));
    expect(tower.right, tester.getRect(find.byType(PaperNavigationRail)).right);
  });
}
