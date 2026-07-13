// test/features/tools/presentation/views/carpet_area_view_test.dart

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:ghar360/features/tools/presentation/controllers/carpet_area_controller.dart';
import 'package:ghar360/features/tools/presentation/views/carpet_area_view.dart';
import '../../../../helpers/getx_test_binding.dart';
import '../../../../helpers/pump_app.dart';

void main() {
  late CarpetAreaController controller;

  setUp(() {
    GetxTestBinding.init();
    controller = CarpetAreaController();
    Get.put<CarpetAreaController>(controller);
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  Future<void> pumpView(WidgetTester tester) async {
    await tester.pumpApp(const CarpetAreaView());
    await tester.pump();
  }

  Future<void> tapCalculate(WidgetTester tester) async {
    final button = find.byKey(const ValueKey('qa.tools.carpet_area.calculate'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  group('CarpetAreaView', () {
    testWidgets('renders scaffold with correct key and app bar title', (tester) async {
      await pumpView(tester);

      expect(find.byKey(const ValueKey('qa.tools.carpet_area.screen')), findsOneWidget);
      expect(find.text('Carpet vs Built-up'), findsOneWidget);
    });

    testWidgets('renders back and refresh icons in app bar', (tester) async {
      await pumpView(tester);

      expect(find.byTooltip('Back'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('renders info container with info icon', (tester) async {
      await pumpView(tester);

      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('renders super built-up area label and input field', (tester) async {
      await pumpView(tester);

      expect(find.text('Super Built-up Area'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('renders loading percentage label and slider', (tester) async {
      await pumpView(tester);

      expect(find.text('Loading Percentage'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('renders slider range labels 15% and 40%', (tester) async {
      await pumpView(tester);

      expect(find.text('15%'), findsOneWidget);
      expect(find.text('40%'), findsOneWidget);
    });

    testWidgets('renders calculate button', (tester) async {
      await pumpView(tester);

      expect(find.byKey(const ValueKey('qa.tools.carpet_area.calculate')), findsOneWidget);
      expect(find.text('Calculate'), findsOneWidget);
    });

    testWidgets('does not show results before calculation', (tester) async {
      await pumpView(tester);

      expect(find.text('Area Breakdown'), findsNothing);
    });

    testWidgets('shows validation error when calculating with empty field', (tester) async {
      await pumpView(tester);

      await tapCalculate(tester);

      expect(controller.validationError.value, isNotEmpty);
      expect(controller.hasCalculated.value, isFalse);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('calculates carpet area and shows results', (tester) async {
      await pumpView(tester);

      controller.superBuiltUpController.text = '1000';
      await tester.pump();

      await tapCalculate(tester);

      expect(controller.hasCalculated.value, isTrue);
      expect(controller.carpetArea.value, greaterThan(0));
      expect(controller.builtUpArea.value, greaterThan(0));
      expect(find.text('Area Breakdown'), findsOneWidget);
    });

    testWidgets('shows carpet area, built-up area and super built-up cards in results', (
      tester,
    ) async {
      await pumpView(tester);

      controller.superBuiltUpController.text = '1000';
      await tester.pump();

      await tapCalculate(tester);

      expect(find.text('Carpet Area'), findsOneWidget);
      expect(find.text('Built-up Area'), findsOneWidget);
      expect(find.text('Super Built-up'), findsOneWidget);
    });

    testWidgets('shows usable area percentage in results', (tester) async {
      await pumpView(tester);

      controller.superBuiltUpController.text = '1000';
      await tester.pump();

      await tapCalculate(tester);

      expect(find.text('Usable Area'), findsOneWidget);
      expect(find.byIcon(Icons.pie_chart), findsOneWidget);
    });

    testWidgets('loading percentage slider updates controller value', (tester) async {
      await pumpView(tester);

      final initialValue = controller.loadingPercentage.value;
      final slider = find.byType(Slider);
      await tester.ensureVisible(slider);
      await tester.pumpAndSettle();

      await tester.drag(slider, const Offset(100, 0));
      await tester.pumpAndSettle();

      expect(controller.loadingPercentage.value, isNot(equals(initialValue)));
    });

    testWidgets('changing slider recalculates if already calculated', (tester) async {
      await pumpView(tester);

      controller.superBuiltUpController.text = '1000';
      await tester.pump();

      await tapCalculate(tester);
      final initialCarpet = controller.carpetArea.value;

      // Change loading percentage via slider
      final slider = find.byType(Slider);
      await tester.ensureVisible(slider);
      await tester.pumpAndSettle();
      await tester.drag(slider, const Offset(100, 0));
      await tester.pumpAndSettle();

      // Carpet area should have changed due to recalculation
      expect(controller.carpetArea.value, isNot(equals(initialCarpet)));
    });

    testWidgets('refresh button clears all fields and results', (tester) async {
      await pumpView(tester);

      controller.superBuiltUpController.text = '1000';
      await tester.pump();

      await tapCalculate(tester);
      expect(controller.hasCalculated.value, isTrue);

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      expect(controller.hasCalculated.value, isFalse);
      expect(controller.superBuiltUpController.text, isEmpty);
      expect(controller.loadingPercentage.value, 25.0);
      expect(controller.carpetArea.value, 0);
      expect(controller.builtUpArea.value, 0);
    });

    testWidgets('back button is wired to Get.back', (tester) async {
      await pumpView(tester);

      final backButton = find.byTooltip('Back');
      expect(backButton, findsOneWidget);

      await tester.tap(backButton);
      await tester.pump();
    });

    testWidgets('entering text in field updates controller', (tester) async {
      await pumpView(tester);

      final field = find.byType(TextField);
      await tester.ensureVisible(field);
      await tester.pumpAndSettle();
      await tester.enterText(field, '1200');

      expect(controller.superBuiltUpController.text, '1200');
    });

    testWidgets('shows current loading percentage value in text', (tester) async {
      await pumpView(tester);

      // Default loading percentage is 25
      expect(find.text('25%'), findsOneWidget);
    });

    testWidgets('shows sq ft suffix in area input field', (tester) async {
      await pumpView(tester);

      expect(find.text('Sq Ft'), findsAtLeast(1));
    });

    testWidgets('calculates with different loading percentage', (tester) async {
      await pumpView(tester);

      controller.superBuiltUpController.text = '1000';
      controller.loadingPercentage.value = 30;
      await tester.pump();

      await tapCalculate(tester);

      expect(controller.hasCalculated.value, isTrue);
      // With 30% loading, built-up = 1000 / 1.3 ≈ 769
      expect(controller.builtUpArea.value, closeTo(769.23, 1));
    });
  });
}
