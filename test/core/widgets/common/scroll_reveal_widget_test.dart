import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:ghar360/core/translations/app_translations.dart';
import 'package:ghar360/core/widgets/common/scroll_reveal_widget.dart';
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
    await pumpWidget(tester, const ScrollRevealWidget(child: Text('Reveal Me')));

    expect(find.byType(ScrollRevealWidget), findsOneWidget);
    expect(find.text('Reveal Me'), findsOneWidget);
  });

  testWidgets('animates on first build with index 0 (no delay)', (tester) async {
    await pumpWidget(tester, const ScrollRevealWidget(index: 0, child: Text('Reveal Me')));

    // The FadeTransition and SlideTransition are present within the widget.
    expect(
      find.descendant(of: find.byType(ScrollRevealWidget), matching: find.byType(FadeTransition)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byType(ScrollRevealWidget), matching: find.byType(SlideTransition)),
      findsOneWidget,
    );

    // Let the forward animation run to completion.
    await tester.pumpAndSettle();

    // Child is still rendered.
    expect(find.text('Reveal Me'), findsOneWidget);
  });

  testWidgets('respects index for stagger delay', (tester) async {
    await pumpWidget(
      tester,
      const ScrollRevealWidget(
        index: 3,
        staggerDelay: Duration(milliseconds: 80),
        child: Text('Staggered'),
      ),
    );

    // Initially the animation has not started because of the delayed forward.
    expect(find.byType(ScrollRevealWidget), findsOneWidget);

    // Pump just past the stagger delay (3 * 80ms = 240ms) plus a frame.
    await tester.pump(const Duration(milliseconds: 250));

    // The widget is still present; the delayed forward should now be scheduled.
    expect(find.text('Staggered'), findsOneWidget);

    // Settle to complete the animation.
    await tester.pumpAndSettle();
    expect(find.text('Staggered'), findsOneWidget);
  });

  testWidgets('disposes its animation controller without errors', (tester) async {
    await pumpWidget(tester, const ScrollRevealWidget(child: Text('Reveal Me')));
    await tester.pumpAndSettle();

    // Replace the widget tree so the ScrollRevealWidget is disposed.
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        fallbackLocale: const Locale('en', 'US'),
        home: const Scaffold(body: Center(child: Text('Gone'))),
      ),
    );

    expect(find.byType(ScrollRevealWidget), findsNothing);
    expect(find.text('Gone'), findsOneWidget);
  });
}
