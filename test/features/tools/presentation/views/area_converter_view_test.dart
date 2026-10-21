// test/features/tools/presentation/views/area_converter_view_test.dart

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/features/tools/presentation/controllers/area_converter_controller.dart';
import 'package:ghar360/features/tools/presentation/views/area_converter_view.dart';
import '../../../../helpers/knife_finders.dart';
import '../../../../helpers/provider_test_app.dart';

void main() {
  group('AreaConverterView', () {
    testWidgets('renders screen with title and input field', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpProviderApp(const AreaConverterView());
        await tester.pump();

        expect(find.byKey(const ValueKey('qa.tools.area_converter.screen')), findsOneWidget);
        expect(find.bySemanticsIdentifier('qa.tools.area_converter.screen'), findsOneWidget);
        expect(find.bySemanticsLabel(RegExp(r'qa\.tools')), findsNothing);
        expect(find.byKey(const ValueKey('qa.tools.area_converter.input')), findsOneWidget);
        // Six unit choice chips are rendered.
        expect(find.byType(ChoiceChip), findsNWidgets(AreaUnit.values.length));
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('entering a value shows conversions card', (tester) async {
      await tester.pumpProviderApp(const AreaConverterView());
      await tester.pump();

      await tester.enterText(find.byKey(const ValueKey('qa.tools.area_converter.input')), '100');
      await tester.pump();

      // Conversions card header is shown once conversions exist.
      expect(find.text('Conversions'), findsOneWidget);
    });

    testWidgets('shows no conversions card when input is empty', (tester) async {
      await tester.pumpProviderApp(const AreaConverterView());
      await tester.pump();

      expect(find.text('Conversions'), findsNothing);
    });

    testWidgets('tapping a unit chip changes the selected unit', (tester) async {
      await tester.pumpProviderApp(const AreaConverterView());
      await tester.pump();

      // Enter a value first so conversions are visible.
      await tester.enterText(find.byKey(const ValueKey('qa.tools.area_converter.input')), '1');
      await tester.pump();

      // Tap the "Acres" chip.
      await tester.tap(find.widgetWithText(ChoiceChip, 'Acres'));
      await tester.pump();

      final state = ProviderScope.containerOf(
        tester.element(find.byType(AreaConverterView)),
      ).read(areaConverterProvider);
      expect(state.selectedUnit, AreaUnit.acres);
    });

    testWidgets('refresh button clears input and conversions', (tester) async {
      await tester.pumpProviderApp(const AreaConverterView());
      await tester.pump();

      await tester.enterText(find.byKey(const ValueKey('qa.tools.area_converter.input')), '100');
      await tester.pump();
      expect(find.text('Conversions'), findsOneWidget);

      // Tap the refresh action button.
      await tester.tap(findKnife(KnifeIcon.retry));
      await tester.pump();

      expect(find.text('Conversions'), findsNothing);
      final state = ProviderScope.containerOf(
        tester.element(find.byType(AreaConverterView)),
      ).read(areaConverterProvider);
      expect(state.input, isEmpty);
      expect(state.conversions, isEmpty);
    });

    testWidgets('back button pops back to previous route', (tester) async {
      await tester.pumpProviderApp(
        Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(
                tester.element(find.text('open_converter')),
              ).push(MaterialPageRoute<void>(builder: (_) => const AreaConverterView())),
              child: const Text('open_converter'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('open_converter'));
      await tester.pumpAndSettle();

      // AreaConverterView is now on top.
      expect(find.byKey(const ValueKey('qa.tools.area_converter.screen')), findsOneWidget);

      await tester.tap(findKnife(KnifeIcon.arrowLeft));
      await tester.pumpAndSettle();

      // After back, the original home text is visible again.
      expect(find.text('open_converter'), findsOneWidget);
    });

    testWidgets('invalid input stays visible with a field error', (tester) async {
      await tester.pumpProviderApp(const AreaConverterView());
      await tester.enterText(find.byType(TextField), '-5');
      await tester.pump();
      expect(find.text('Enter a valid area greater than zero.'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '-5');
    });

    testWidgets('Hindi with large text fits a narrow phone', (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpProviderApp(
        const AreaConverterView(),
        locale: const Locale('hi', 'IN'),
        textScale: 2,
      );
      await tester.enterText(find.byType(TextField), '100');
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('_formatNumber formats millions (M) branch', (tester) async {
      await tester.pumpProviderApp(const AreaConverterView());
      await tester.pump();

      // Select acres, enter 100 -> sq ft = 4,356,000 -> "4.36M"
      await tester.tap(find.widgetWithText(ChoiceChip, 'Acres'));
      await tester.pump();

      await tester.enterText(find.byKey(const ValueKey('qa.tools.area_converter.input')), '100');
      await tester.pump();

      expect(find.text('4.36M'), findsOneWidget);
    });

    testWidgets('_formatNumber formats thousands (K) branch', (tester) async {
      await tester.pumpProviderApp(const AreaConverterView());
      await tester.pump();

      // Select acres, enter 1 -> sq ft = 43,560 -> "43.56K"
      await tester.tap(find.widgetWithText(ChoiceChip, 'Acres'));
      await tester.pump();

      await tester.enterText(find.byKey(const ValueKey('qa.tools.area_converter.input')), '1');
      await tester.pump();

      expect(find.text('43.56K'), findsOneWidget);
    });

    testWidgets('_formatNumber formats >=1 branch', (tester) async {
      await tester.pumpProviderApp(const AreaConverterView());
      await tester.pump();

      // 100 sq ft -> sq m = 9.29 -> "9.29"
      await tester.enterText(find.byKey(const ValueKey('qa.tools.area_converter.input')), '100');
      await tester.pump();

      expect(find.text('9.29'), findsOneWidget);
    });

    testWidgets('_formatNumber formats <1 branch', (tester) async {
      await tester.pumpProviderApp(const AreaConverterView());
      await tester.pump();

      // 1 sq ft -> acres = 0.0000229 -> "0.0000"
      await tester.enterText(find.byKey(const ValueKey('qa.tools.area_converter.input')), '1');
      await tester.pump();

      expect(find.text('0.0000'), findsWidgets);
    });
  });
}
