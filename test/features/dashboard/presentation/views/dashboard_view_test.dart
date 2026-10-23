import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/widgets/navigation/bottom_nav_bar.dart';
import '../../../../helpers/dashboard_shell_app.dart';

void main() {
  testWidgets('renders five primary destinations with Discover initially selected', (tester) async {
    usePhoneView(tester);
    final router = shellRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(shellApp(router));
    await tester.pumpAndSettle();
    expect(
      tester.widget<CustomBottomNavigationBar>(find.byType(CustomBottomNavigationBar)).currentIndex,
      0,
    );
    for (final id in shellIds) {
      expect(find.byKey(ValueKey('qa.dashboard.nav.$id')), findsOneWidget);
    }
    expect(find.text('Assistant'), findsNothing);
    expect(find.byType(PaperNavigationRail), findsNothing);
  });
  testWidgets('from 600 px the destinations move to a rail with the same IDs', (tester) async {
    tester.view.physicalSize = const Size(834, 1112);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = shellRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(shellApp(router));
    await tester.pumpAndSettle();
    expect(find.byType(PaperNavigationRail), findsOneWidget);
    expect(find.byType(CustomBottomNavigationBar), findsNothing);
    await tester.tap(find.byKey(const ValueKey('qa.dashboard.nav.visits')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/visits');
    final selected = tester.getSemantics(find.byKey(const ValueKey('qa.dashboard.nav.visits')));
    expect(selected.flagsCollection.isSelected, Tristate.isTrue);
  });
  testWidgets('crossing 600 px keeps branch state (fold, split resize)', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(599, 900);
    final built = <String>{};
    final disposed = <String>{};
    final router = shellRouter(built: built, disposed: disposed);
    addTearDown(router.dispose);
    await tester.pumpWidget(shellApp(router));
    await tester.pumpAndSettle();
    expect(find.byType(CustomBottomNavigationBar), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('/discover.input')), 'kept');
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    final offset = tester.state<ScrollableState>(find.byType(Scrollable).first).position.pixels;
    for (final width in [601.0, 599.0]) {
      tester.view.physicalSize = Size(width, 900);
      await tester.pumpAndSettle();
      expect(find.byType(PaperNavigationRail).evaluate().isNotEmpty, width >= 600);
      expect(built, {'/discover'}, reason: 'no branch rebuilt at $width');
      expect(disposed, isEmpty, reason: 'no branch disposed at $width');
      expect(
        tester.widget<TextField>(find.byKey(const ValueKey('/discover.input'))).controller!.text,
        'kept',
      );
      expect(tester.state<ScrollableState>(find.byType(Scrollable).first).position.pixels, offset);
    }
  });
  testWidgets('switching tabs retains local form and scroll state', (tester) async {
    usePhoneView(tester);
    final router = shellRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(shellApp(router));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('/discover.input')), 'retained query');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final list = find.byType(ListView);
    await tester.drag(list, const Offset(0, -650));
    await tester.pumpAndSettle();
    final scroll = tester
        .state<ScrollableState>(find.descendant(of: list, matching: find.byType(Scrollable)).first)
        .position
        .pixels;
    await tester.tap(find.byKey(const ValueKey('qa.dashboard.nav.visits')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('qa.dashboard.nav.discover')));
    await tester.pumpAndSettle();
    final restored = tester
        .state<ScrollableState>(
          find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first,
        )
        .position
        .pixels;
    expect(restored, closeTo(scroll, .1));
    await tester.drag(find.byType(ListView), const Offset(0, 1000));
    await tester.pumpAndSettle();
    expect(find.text('retained query'), findsOneWidget);
  });
  testWidgets('Assistant opens above the shell and Back returns to the same tab', (tester) async {
    usePhoneView(tester);
    final router = shellRouter(initial: '/profile');
    addTearDown(router.dispose);
    await tester.pumpWidget(shellApp(router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Assistant'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/assistant');
    expect(find.text('Assistant page'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/profile');
  });
  for (final dark in [false, true]) {
    testWidgets(
      'five navigation targets fit narrow Hindi large text in ${dark ? 'dark' : 'light'}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final router = shellRouter();
        addTearDown(router.dispose);
        await tester.pumpWidget(
          shellApp(router, dark: dark, scale: 2, locale: const Locale('hi', 'IN')),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (final id in shellIds) {
          final target = find.byKey(ValueKey('qa.dashboard.nav.$id'));
          expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
          await tester.tap(target);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
  group('guest', () {
    for (final id in ['saved', 'visits', 'profile']) {
      testWidgets('tapping $id shows the sign-in sheet and the tab does not change', (
        tester,
      ) async {
        usePhoneView(tester);
        final router = shellRouter();
        addTearDown(router.dispose);
        await tester.pumpWidget(shellApp(router, guest: true));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey('qa.dashboard.nav.$id')));
        await tester.pumpAndSettle();
        expect(find.text('Sign in to continue'), findsOneWidget);
        expect(router.state.uri.path, '/discover');
        await tester.tap(find.byKey(const ValueKey('qa.sign_in_gate.not_now')));
        await tester.pumpAndSettle();
        expect(router.state.uri.path, '/discover');
      });
    }
    testWidgets('Explore stays open to a guest', (tester) async {
      usePhoneView(tester);
      final router = shellRouter();
      addTearDown(router.dispose);
      await tester.pumpWidget(shellApp(router, guest: true));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('qa.dashboard.nav.explore_properties')));
      await tester.pumpAndSettle();
      expect(find.text('Sign in to continue'), findsNothing);
      expect(router.state.uri.path, '/explore');
    });
  });
}
