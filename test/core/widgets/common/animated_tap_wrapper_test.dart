import 'package:flutter/material.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/widgets/common/animated_tap_wrapper.dart';
import '../../../helpers/knife_finders.dart';

void main() {
  Future<void> pumpWidget(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        locale: const Locale('en', 'US'),
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: Center(child: child)),
      ),
    );
  }

  testWidgets('renders the provided child', (tester) async {
    await pumpWidget(tester, AnimatedTapWrapper(onTap: () {}, child: const Text('Tap Me')));

    expect(find.byType(AnimatedTapWrapper), findsOneWidget);
    expect(find.text('Tap Me'), findsOneWidget);
  });

  testWidgets('responds to tap by calling onTap', (tester) async {
    var tapCalled = false;
    await pumpWidget(
      tester,
      AnimatedTapWrapper(onTap: () => tapCalled = true, child: const Text('Tap Me')),
    );

    await tester.tap(find.byType(AnimatedTapWrapper));
    await tester.pumpAndSettle();

    expect(tapCalled, isTrue);
  });

  testWidgets('dims while pressed and never scales', (tester) async {
    await pumpWidget(
      tester,
      AnimatedTapWrapper(onTap: () {}, child: const SizedBox(width: 100, height: 100)),
    );
    double opacity() => tester
        .widget<AnimatedOpacity>(
          find.descendant(
            of: find.byType(AnimatedTapWrapper),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .opacity;
    expect(opacity(), 1);
    expect(
      find.descendant(of: find.byType(AnimatedTapWrapper), matching: find.byType(Transform)),
      findsNothing,
    );
    final gesture = await tester.startGesture(tester.getCenter(find.byType(AnimatedTapWrapper)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(opacity(), lessThan(1));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(opacity(), 1);
  });

  testWidgets('does not attach tap handlers when onTap is null', (tester) async {
    await pumpWidget(tester, const AnimatedTapWrapper(child: Text('No Tap')));

    // Tapping should not throw and the child is still rendered.
    await tester.tap(find.byType(AnimatedTapWrapper));
    await tester.pumpAndSettle();

    expect(find.text('No Tap'), findsOneWidget);
  });

  group('AnimatedFavoriteIcon', () {
    testWidgets('renders favorite icon when isFavorite is true', (tester) async {
      await pumpWidget(tester, AnimatedFavoriteIcon(isFavorite: true, onToggle: () {}));

      expect(findKnife(KnifeIcon.heartSolid), findsOneWidget);
    });

    testWidgets('renders border icon when isFavorite is false', (tester) async {
      await pumpWidget(tester, AnimatedFavoriteIcon(isFavorite: false, onToggle: () {}));

      expect(findKnife(KnifeIcon.heart), findsOneWidget);
    });

    testWidgets('changes the mark only: no bounce or burst animation', (tester) async {
      var favourite = false;
      await pumpWidget(
        tester,
        StatefulBuilder(
          builder: (context, setState) => AnimatedFavoriteIcon(
            isFavorite: favourite,
            onToggle: () => setState(() => favourite = !favourite),
          ),
        ),
      );
      await tester.tap(find.byType(AnimatedFavoriteIcon));
      await tester.pump();
      expect(findKnife(KnifeIcon.heartSolid), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.getSize(find.byType(AnimatedFavoriteIcon)).height, greaterThanOrEqualTo(48));
    });

    testWidgets('calls onToggle when tapped', (tester) async {
      var toggled = false;
      await pumpWidget(
        tester,
        AnimatedFavoriteIcon(isFavorite: false, onToggle: () => toggled = true),
      );

      await tester.tap(find.byType(AnimatedFavoriteIcon));
      await tester.pumpAndSettle();

      expect(toggled, isTrue);
    });
  });
}
