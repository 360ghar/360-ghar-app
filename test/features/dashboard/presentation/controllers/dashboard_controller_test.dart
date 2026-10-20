// StatefulShellRoute now owns tab selection and each branch's navigation stack.

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/widgets/navigation/bottom_nav_bar.dart';
import '../../../../helpers/dashboard_shell_app.dart';

void main() {
  for (var index = 0; index < shellPaths.length; index++) {
    testWidgets('direct ${shellPaths[index]} route selects branch $index', (tester) async {
      usePhoneView(tester);
      final router = shellRouter(initial: shellPaths[index]);
      addTearDown(router.dispose);
      await tester.pumpWidget(shellApp(router));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CustomBottomNavigationBar>(find.byType(CustomBottomNavigationBar))
            .currentIndex,
        index,
      );
      expect(router.state.uri.path, shellPaths[index]);
    });
    testWidgets('${shellPaths[index]} selection switches to correct route', (tester) async {
      usePhoneView(tester);
      final router = shellRouter();
      addTearDown(router.dispose);
      await tester.pumpWidget(shellApp(router));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('qa.dashboard.nav.${shellIds[index]}')));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, shellPaths[index]);
      expect(
        tester
            .widget<CustomBottomNavigationBar>(find.byType(CustomBottomNavigationBar))
            .currentIndex,
        index,
      );
    });
  }
  testWidgets('same-tab selection preserves branch history and Back pops only that branch', (
    tester,
  ) async {
    usePhoneView(tester);
    final router = shellRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(shellApp(router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open detail'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/discover/detail');
    await tester.tap(find.byKey(const ValueKey('qa.dashboard.nav.explore_properties')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open detail'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/explore/detail');
    await tester.tap(find.byKey(const ValueKey('qa.dashboard.nav.discover')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/discover/detail');
    await tester.tap(find.byKey(const ValueKey('qa.dashboard.nav.discover')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/discover/detail');
    router.pop();
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/discover');
    await tester.tap(find.byKey(const ValueKey('qa.dashboard.nav.explore_properties')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/explore/detail');
  });
}
