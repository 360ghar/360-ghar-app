// test/features/tools/presentation/views/area_converter_view_test.dart

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:ghar360/features/tools/presentation/controllers/area_converter_controller.dart';
import 'package:ghar360/features/tools/presentation/views/area_converter_view.dart';
import '../../../../helpers/getx_test_binding.dart';
import '../../../../helpers/pump_app.dart';

void main() {
  setUp(() {
    GetxTestBinding.init();
    Get.put<AreaConverterController>(AreaConverterController());
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  group('AreaConverterView', () {
    testWidgets('renders screen with title and input field', (tester) async {
      await tester.pumpApp(const AreaConverterView());
      await tester.pump();

      expect(find.byKey(const ValueKey('qa.tools.area_converter.screen')), findsOneWidget);
      expect(find.byKey(const ValueKey('qa.tools.area_converter.input')), findsOneWidget);
      // Six unit choice chips are rendered.
      expect(find.byType(ChoiceChip), findsNWidgets(AreaUnit.values.length));
    });

    testWidgets('entering a value shows conversions card', (tester) async {
      await tester.pumpApp(const AreaConverterView());
      await tester.pump();

      await tester.enterText(find.byKey(const ValueKey('qa.tools.area_converter.input')), '100');
      await tester.pump();

      // Conversions card header is shown once conversions exist.
      expect(find.text('conversions'.tr), findsOneWidget);
    });

    testWidgets('shows no conversions card when input is empty', (tester) async {
      await tester.pumpApp(const AreaConverterView());
      await tester.pump();

      expect(find.text('conversions'.tr), findsNothing);
    });

    testWidgets('tapping a unit chip changes the selected unit', (tester) async {
      await tester.pumpApp(const AreaConverterView());
      await tester.pump();

      // Enter a value first so conversions are visible.
      await tester.enterText(find.byKey(const ValueKey('qa.tools.area_converter.input')), '1');
      await tester.pump();

      // Tap the "Acres" chip.
      await tester.tap(find.widgetWithText(ChoiceChip, 'Acres'));
      await tester.pump();

      final controller = Get.find<AreaConverterController>();
      expect(controller.selectedUnit.value, AreaUnit.acres);
    });

    testWidgets('refresh button clears input and conversions', (tester) async {
      await tester.pumpApp(const AreaConverterView());
      await tester.pump();

      await tester.enterText(find.byKey(const ValueKey('qa.tools.area_converter.input')), '100');
      await tester.pump();
      expect(find.text('conversions'.tr), findsOneWidget);

      // Tap the refresh action button.
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();

      expect(find.text('conversions'.tr), findsNothing);
      final controller = Get.find<AreaConverterController>();
      expect(controller.inputController.text, isEmpty);
      expect(controller.conversions, isEmpty);
    });

    testWidgets('back button pops back to previous route', (tester) async {
      await tester.pumpApp(
        Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Get.to(() => const AreaConverterView()),
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

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // After back, the original home text is visible again.
      expect(find.text('open_converter'), findsOneWidget);
    });

    testWidgets('_formatNumber formats millions (M) branch', (tester) async {
      await tester.pumpApp(const AreaConverterView());
      await tester.pump();

      // Select acres, enter 100 -> sq ft = 4,356,000 -> "4.36M"
      await tester.tap(find.widgetWithText(ChoiceChip, 'Acres'));
      await tester.pump();

      await tester.enterText(find.byKey(const ValueKey('qa.tools.area_converter.input')), '100');
      await tester.pump();

      expect(find.text('4.36M'), findsOneWidget);
    });

    testWidgets('_formatNumber formats thousands (K) branch', (tester) async {
      await tester.pumpApp(const AreaConverterView());
      await tester.pump();

      // Select acres, enter 1 -> sq ft = 43,560 -> "43.56K"
      await tester.tap(find.widgetWithText(ChoiceChip, 'Acres'));
      await tester.pump();

      await tester.enterText(find.byKey(const ValueKey('qa.tools.area_converter.input')), '1');
      await tester.pump();

      expect(find.text('43.56K'), findsOneWidget);
    });

    testWidgets('_formatNumber formats >=1 branch', (tester) async {
      await tester.pumpApp(const AreaConverterView());
      await tester.pump();

      // 100 sq ft -> sq m = 9.29 -> "9.29"
      await tester.enterText(find.byKey(const ValueKey('qa.tools.area_converter.input')), '100');
      await tester.pump();

      expect(find.text('9.29'), findsOneWidget);
    });

    testWidgets('_formatNumber formats <1 branch', (tester) async {
      await tester.pumpApp(const AreaConverterView());
      await tester.pump();

      // 1 sq ft -> acres = 0.0000229 -> "0.0000"
      await tester.enterText(find.byKey(const ValueKey('qa.tools.area_converter.input')), '1');
      await tester.pump();

      expect(find.text('0.0000'), findsWidgets);
    });
  });
}
