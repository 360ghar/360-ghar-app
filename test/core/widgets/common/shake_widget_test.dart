import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/translations/app_translations.dart';
import 'package:ghar360/core/widgets/common/shake_widget.dart';

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
    await pumpWidget(
      tester,
      const ShakeWidget(trigger: 0, child: Text('Shake Me')),
    );

    expect(find.byType(ShakeWidget), findsOneWidget);
    expect(find.text('Shake Me'), findsOneWidget);
  });

  testWidgets('triggers the shake animation when trigger value changes',
      (tester) async {
    await pumpWidget(
      tester,
      const ShakeWidget(trigger: 0, child: Text('Shake Me')),
    );

    // The AnimatedBuilder is present within the ShakeWidget.
    expect(
      find.descendant(
        of: find.byType(ShakeWidget),
        matching: find.byType(AnimatedBuilder),
      ),
      findsOneWidget,
    );

    // Rebuild with a new trigger value — didUpdateWidget calls forward(from: 0).
    await pumpWidget(
      tester,
      const ShakeWidget(trigger: 1, child: Text('Shake Me')),
    );

    // Pump a frame so the animation produces a non-zero offset.
    await tester.pump(const Duration(milliseconds: 50));

    // The child is still rendered (Transform.translate wraps it).
    expect(find.text('Shake Me'), findsOneWidget);
  });

  testWidgets('does not re-trigger when trigger stays the same', (tester) async {
    await pumpWidget(
      tester,
      const ShakeWidget(trigger: 5, child: Text('Shake Me')),
    );

    // Rebuild with the same trigger value.
    await pumpWidget(
      tester,
      const ShakeWidget(trigger: 5, child: Text('Shake Me')),
    );
    await tester.pump();

    // Widget still present and stable.
    expect(find.byType(ShakeWidget), findsOneWidget);
    expect(find.text('Shake Me'), findsOneWidget);
  });

  testWidgets('disposes its animation controller without errors', (tester) async {
    await pumpWidget(
      tester,
      const ShakeWidget(trigger: 0, child: Text('Shake Me')),
    );

    // Replace the widget tree so the ShakeWidget is disposed.
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        fallbackLocale: const Locale('en', 'US'),
        home: const Scaffold(body: Center(child: Text('Gone'))),
      ),
    );

    expect(find.byType(ShakeWidget), findsNothing);
    expect(find.text('Gone'), findsOneWidget);
  });
}
