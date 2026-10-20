import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:shimmer/shimmer.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/app_design_theme.dart';
import 'package:ghar360/core/widgets/common/loading_states.dart';
import '../../../helpers/provider_test_app.dart';

Future<void> _pump(WidgetTester tester, Widget child, {bool still = false, bool dark = false}) =>
    tester.pumpProviderApp(
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: still),
          child: Scaffold(body: child),
        ),
      ),
      theme: dark ? AppDesignTheme.dark() : AppDesignTheme.light(),
    );

double _opacity(WidgetTester tester) => tester
    .widget<Opacity>(find.descendant(of: find.byType(Skeleton), matching: find.byType(Opacity)))
    .opacity;

void main() {
  final skeletons = {
    'swipe card': LoadingStates.swipeCardSkeleton,
    'grid': () => LoadingStates.responsiveGridSkeleton(crossAxisCount: 3, itemCount: 3),
    'details': LoadingStates.propertyDetailsSkeleton,
    'visits': LoadingStates.visitsSkeleton,
    'profile': LoadingStates.profileSkeleton,
    'conversations': LoadingStates.conversationListSkeleton,
    'saved rows': LoadingStates.propertyRowsSkeleton,
    'document': LoadingStates.documentSkeleton,
  };

  for (final entry in skeletons.entries) {
    testWidgets('${entry.key} skeleton waits 150 ms, then shows once', (tester) async {
      await _pump(tester, entry.value());
      expect(_opacity(tester), 0);
      await tester.pump(const Duration(milliseconds: 149));
      expect(_opacity(tester), 0);
      await tester.pump(const Duration(milliseconds: 2));
      expect(_opacity(tester), 1);
      expect(find.bySemanticsLabel('Loading...'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('reduced motion stops the sheen', (tester) async {
    await _pump(tester, LoadingStates.visitsSkeleton(), still: true);
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.widget<Shimmer>(find.byType(Shimmer)).enabled, isFalse);
    expect(
      tester
          .widget<TickerMode>(
            find.descendant(of: find.byType(Skeleton), matching: find.byType(TickerMode)),
          )
          .enabled,
      isFalse,
    );
  });

  for (final dark in [false, true]) {
    testWidgets(
      '${dark ? 'night' : 'day'} blocks: sky on a white sheet, or a light step at night',
      (tester) async {
        await _pump(tester, LoadingStates.visitsSkeleton(), dark: dark);
        await tester.pump(const Duration(milliseconds: 200));
        final p = AppPalette(isDark: dark);
        final gradient = tester.widget<Shimmer>(find.byType(Shimmer)).gradient as LinearGradient;
        final base = gradient.colors.first;
        expect(base, dark ? isNot(p.surface) : p.background);
        expect(base.computeLuminance(), lessThan(1));
        if (dark) expect(base.computeLuminance(), greaterThan(p.surface.computeLuminance()));
        // The sheen is lighter than the block.
        expect(gradient.colors[2].computeLuminance(), greaterThan(base.computeLuminance()));
        // The blocks sit on a sheet of their own, so they read on the sky page.
        final sheet = tester.widget<ColoredBox>(
          find.descendant(of: find.byType(SkeletonSheet), matching: find.byType(ColoredBox)),
        );
        expect(sheet.color, p.surface);
      },
    );
  }

  testWidgets('the deck skeleton shows its sheets and blocks together after the gate', (
    tester,
  ) async {
    await _pump(tester, SizedBox(height: 640, child: LoadingStates.swipeCardSkeleton()));
    expect(_opacity(tester), 0);
    await tester.pump(const Duration(milliseconds: 160));
    expect(_opacity(tester), 1);
    // The top card, two deck edges and two buttons are cut paper sheets.
    final sheets = tester
        .widgetList<DecoratedBox>(
          find.descendant(of: find.byType(Skeleton), matching: find.byType(DecoratedBox)),
        )
        .map((box) => box.decoration)
        .whereType<ShapeDecoration>()
        .where((decoration) => decoration.color == const AppPalette(isDark: false).surface);
    expect(sheets, hasLength(5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('dark skeletons render', (tester) async {
    await _pump(tester, LoadingStates.profileSkeleton(), dark: true);
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('map overlay is a thin bar with a live label', (tester) async {
    await _pump(tester, const Builder(builder: LoadingStates.mapLoadingOverlay));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('Loading properties...'), findsOneWidget);
  });

  testWidgets('button spinner takes the label colour', (tester) async {
    await _pump(
      tester,
      DefaultTextStyle(
        style: const TextStyle(color: Colors.green),
        child: LoadingStates.buttonSpinner(),
      ),
    );
    final spinner = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(spinner.color, Colors.green);
    expect(tester.getSize(find.byType(CircularProgressIndicator)), const Size(18, 18));
  });
}
