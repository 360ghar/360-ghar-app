import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:ghar360/core/translations/app_translations.dart';
import 'package:ghar360/core/widgets/common/animated_tap_wrapper.dart';
import '../../../helpers/getx_test_binding.dart';

void main() {
  setUp(() => GetxTestBinding.init());
  tearDown(() => GetxTestBinding.reset());

  Future<void> pumpWidget(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        fallbackLocale: const Locale('en', 'US'),
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

  testWidgets('applies a scale transform via AnimatedBuilder', (tester) async {
    await pumpWidget(tester, AnimatedTapWrapper(onTap: () {}, child: const Text('Tap Me')));

    // The wrapper uses an AnimatedBuilder + Transform.scale.
    expect(
      find.descendant(of: find.byType(AnimatedTapWrapper), matching: find.byType(AnimatedBuilder)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byType(AnimatedTapWrapper), matching: find.byType(Transform)),
      findsOneWidget,
    );
  });

  testWidgets('animates scale on tap down/up', (tester) async {
    await pumpWidget(
      tester,
      AnimatedTapWrapper(
        onTap: () {},
        scaleDown: 0.9,
        child: const SizedBox(width: 100, height: 100),
      ),
    );

    final transformBefore = tester.widget<Transform>(
      find.descendant(of: find.byType(AnimatedTapWrapper), matching: find.byType(Transform)),
    );
    // At rest the scale is 1.0.
    expect(transformBefore.transform.getMaxScaleOnAxis(), closeTo(1.0, 0.01));

    // Simulate tap down to trigger the forward animation.
    final gesture = await tester.startGesture(tester.getCenter(find.byType(AnimatedTapWrapper)));
    await tester.pump(const Duration(milliseconds: 100));

    final transformDuring = tester.widget<Transform>(
      find.descendant(of: find.byType(AnimatedTapWrapper), matching: find.byType(Transform)),
    );
    // While pressed the scale moves toward scaleDown (0.9).
    expect(transformDuring.transform.getMaxScaleOnAxis(), lessThanOrEqualTo(1.0));

    // Release to reverse the animation.
    await gesture.up();
    await tester.pumpAndSettle();

    final transformAfter = tester.widget<Transform>(
      find.descendant(of: find.byType(AnimatedTapWrapper), matching: find.byType(Transform)),
    );
    expect(transformAfter.transform.getMaxScaleOnAxis(), closeTo(1.0, 0.01));
  });

  testWidgets('does not attach tap handlers when onTap is null', (tester) async {
    await pumpWidget(tester, const AnimatedTapWrapper(child: Text('No Tap')));

    // Tapping should not throw and the child is still rendered.
    await tester.tap(find.byType(AnimatedTapWrapper));
    await tester.pumpAndSettle();

    expect(find.text('No Tap'), findsOneWidget);
  });

  group('AnimatedIconButton', () {
    testWidgets('renders the icon and responds to tap', (tester) async {
      var pressed = false;
      await pumpWidget(
        tester,
        AnimatedIconButton(icon: Icons.favorite, onPressed: () => pressed = true),
      );

      expect(find.byIcon(Icons.favorite), findsOneWidget);

      await tester.tap(find.byType(AnimatedIconButton));
      await tester.pumpAndSettle();

      expect(pressed, isTrue);
    });
  });

  group('AnimatedFavoriteIcon', () {
    testWidgets('renders favorite icon when isFavorite is true', (tester) async {
      await pumpWidget(tester, AnimatedFavoriteIcon(isFavorite: true, onToggle: () {}));

      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });

    testWidgets('renders border icon when isFavorite is false', (tester) async {
      await pumpWidget(tester, AnimatedFavoriteIcon(isFavorite: false, onToggle: () {}));

      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
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
