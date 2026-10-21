// test/features/tools/presentation/views/carpet_area_view_test.dart

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/features/tools/presentation/controllers/carpet_area_controller.dart';
import 'package:ghar360/features/tools/presentation/views/carpet_area_view.dart';
import '../../../../helpers/knife_finders.dart';
import '../../../../helpers/provider_test_app.dart';

void main() {
  late ProviderContainer container;
  CarpetAreaController getController() => container.read(carpetAreaProvider.notifier);
  CarpetAreaState readState() => container.read(carpetAreaProvider);

  Future<void> pumpView(WidgetTester tester) async {
    await tester.pumpProviderApp(const CarpetAreaView());
    container = ProviderScope.containerOf(tester.element(find.byType(CarpetAreaView)));
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
      final semantics = tester.ensureSemantics();
      try {
        await pumpView(tester);

        expect(find.byKey(const ValueKey('qa.tools.carpet_area.screen')), findsOneWidget);
        expect(find.bySemanticsIdentifier('qa.tools.carpet_area.screen'), findsOneWidget);
        expect(find.bySemanticsLabel(RegExp(r'qa\.tools')), findsNothing);
        expect(find.text('Carpet vs Built-up'), findsOneWidget);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('renders back and refresh icons in app bar', (tester) async {
      await pumpView(tester);

      expect(find.byTooltip('Back'), findsOneWidget);
      expect(findKnife(KnifeIcon.retry), findsOneWidget);
    });

    testWidgets('renders info container with info icon', (tester) async {
      await pumpView(tester);

      expect(findKnife(KnifeIcon.info), findsOneWidget);
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

      expect((readState().validationKey ?? ''), isNotEmpty);
      expect(readState().hasCalculated, isFalse);
      expect(findKnife(KnifeIcon.alert), findsOneWidget);
    });

    testWidgets('calculates carpet area and shows results', (tester) async {
      await pumpView(tester);

      tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text = '1000';
      await tester.pump();

      await tapCalculate(tester);

      expect(readState().hasCalculated, isTrue);
      expect(readState().carpetArea, greaterThan(0));
      expect(readState().builtUpArea, greaterThan(0));
      expect(find.text('Area Breakdown'), findsOneWidget);
    });

    testWidgets('shows carpet area, built-up area and super built-up cards in results', (
      tester,
    ) async {
      await pumpView(tester);

      tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text = '1000';
      await tester.pump();

      await tapCalculate(tester);

      expect(find.text('Carpet Area'), findsOneWidget);
      expect(find.text('Built-up Area'), findsOneWidget);
      expect(find.text('Super Built-up'), findsOneWidget);
    });

    testWidgets('shows usable area percentage in results', (tester) async {
      await pumpView(tester);

      tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text = '1000';
      await tester.pump();

      await tapCalculate(tester);

      expect(find.text('Usable Area'), findsOneWidget);
      // The share is the headline number, with no icon tile beside it.
      expect(find.byKey(const ValueKey('qa.tools.carpet_area.usable')), findsOneWidget);
      expect(findKnife(KnifeIcon.area), findsNothing);
    });

    testWidgets('loading percentage slider updates controller value', (tester) async {
      await pumpView(tester);

      final initialValue = readState().loadingPercentage;
      final slider = find.byType(Slider);
      await tester.ensureVisible(slider);
      await tester.pumpAndSettle();

      await tester.drag(slider, const Offset(100, 0));
      await tester.pumpAndSettle();

      expect(readState().loadingPercentage, isNot(equals(initialValue)));
    });

    testWidgets('changing slider recalculates if already calculated', (tester) async {
      await pumpView(tester);

      tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text = '1000';
      await tester.pump();

      await tapCalculate(tester);
      final initialCarpet = readState().carpetArea;

      // Change loading percentage via slider
      final slider = find.byType(Slider);
      await tester.ensureVisible(slider);
      await tester.pumpAndSettle();
      await tester.drag(slider, const Offset(100, 0));
      await tester.pumpAndSettle();

      // Carpet area should have changed due to recalculation
      expect(readState().carpetArea, isNot(equals(initialCarpet)));
    });

    testWidgets('refresh button clears all fields and results', (tester) async {
      await pumpView(tester);

      tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text = '1000';
      await tester.pump();

      await tapCalculate(tester);
      expect(readState().hasCalculated, isTrue);

      await tester.tap(findKnife(KnifeIcon.retry));
      await tester.pumpAndSettle();

      expect(readState().hasCalculated, isFalse);
      expect(tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text, isEmpty);
      expect(readState().loadingPercentage, 25.0);
      expect(readState().carpetArea, 0);
      expect(readState().builtUpArea, 0);
    });

    testWidgets('back button is wired to Navigator.maybePop', (tester) async {
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

      expect(tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text, '1200');
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

      tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text = '1000';
      getController().onLoadingChanged(30);
      await tester.pump();

      await tapCalculate(tester);

      expect(readState().hasCalculated, isTrue);
      // With 30% loading, built-up = 1000 / 1.3 ≈ 769
      expect(readState().builtUpArea, closeTo(769.23, 1));
    });
  });
}
