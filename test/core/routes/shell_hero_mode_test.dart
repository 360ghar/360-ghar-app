import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ghar360/core/routes/app_pages.dart';

/// Two tabs show the same home under one hero tag, and a details route above
/// the shell uses the tag too, as the Explore strip, Saved and the details
/// gallery do.
GoRouter _router(ShellNavigationContainerBuilder container) {
  Widget tab(String name) => Scaffold(
    body: Column(
      children: [
        Text(name),
        const Hero(tag: 'property-photo-7', child: SizedBox.square(dimension: 40)),
      ],
    ),
  );
  return GoRouter(
    initialLocation: '/a',
    routes: [
      StatefulShellRoute(
        navigatorContainerBuilder: container,
        builder: (_, _, shell) => shell,
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/a', builder: (_, _) => tab('A'))],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/b', builder: (_, _) => tab('B'))],
          ),
        ],
      ),
      GoRoute(
        path: '/details',
        builder: (_, _) => const Scaffold(
          body: Hero(tag: 'property-photo-7', child: SizedBox.square(dimension: 200)),
        ),
      ),
    ],
  );
}

bool _heroMode(WidgetTester tester, Finder finder) => tester
    .widget<HeroMode>(
      find.ancestor(of: finder, matching: find.byType(HeroMode, skipOffstage: false)).first,
    )
    .enabled;

Future<void> _visitBothTabsAndOpenDetails(WidgetTester tester, GoRouter router) async {
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  router.go('/b');
  await tester.pumpAndSettle();
  router.go('/a');
  await tester.pumpAndSettle();
  // Both branches are now mounted, and each shows the tag.
  expect(find.byType(Hero, skipOffstage: false), findsNWidgets(2));
  router.push('/details');
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('a hero tag shared by two tabs flies from the open tab only', (tester) async {
    final router = _router(heroSafeBranchContainer);
    addTearDown(router.dispose);
    await _visitBothTabsAndOpenDetails(tester, router);
    expect(tester.takeException(), isNull);
    // Mid-flight the open tab's photo is in the overlay.
    expect(find.byType(Hero), findsWidgets);
    await tester.pumpAndSettle();
    router.pop();
    await tester.pumpAndSettle();
    router.go('/b');
    await tester.pumpAndSettle();
    router.push('/details');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(router.state.uri.path, '/details');
  });

  testWidgets('the container keeps inactive tabs mounted, offstage and without tickers', (
    tester,
  ) async {
    final router = _router(heroSafeBranchContainer);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.go('/b');
    await tester.pumpAndSettle();
    final a = find.text('A', skipOffstage: false);
    expect(a, findsOneWidget);
    final offstage = tester.widgetList<Offstage>(
      find.ancestor(of: a, matching: find.byType(Offstage, skipOffstage: false)),
    );
    expect(offstage.any((widget) => widget.offstage), isTrue);
    expect(TickerMode.valuesOf(tester.element(a)).enabled, isFalse);
    expect(_heroMode(tester, a), isFalse);
    final b = find.text('B');
    expect(TickerMode.valuesOf(tester.element(b)).enabled, isTrue);
    expect(_heroMode(tester, b), isTrue);
  });

  testWidgets('without HeroMode the shared tag clashes (why the container exists)', (tester) async {
    final router = _router(
      (context, shell, children) => IndexedStack(
        index: shell.currentIndex,
        children: [
          for (final (index, child) in children.indexed)
            Offstage(offstage: index != shell.currentIndex, child: child),
        ],
      ),
    );
    addTearDown(router.dispose);
    await _visitBothTabsAndOpenDetails(tester, router);
    expect(tester.takeException().toString(), contains('multiple heroes that share the same tag'));
  });
}
