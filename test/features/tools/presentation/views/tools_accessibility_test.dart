import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/features/tools/presentation/views/capital_gains_view.dart';
import 'package:ghar360/features/tools/presentation/views/carpet_area_view.dart';
import 'package:ghar360/features/tools/presentation/views/emi_calculator_view.dart';
import 'package:ghar360/features/tools/presentation/views/loan_eligibility_view.dart';
import 'package:ghar360/features/tools/presentation/views/tools_view.dart';
import '../../../../helpers/provider_test_app.dart';

void main() {
  for (final view in <Widget>[
    const ToolsView(),
    const EmiCalculatorView(),
    const LoanEligibilityView(),
    const CarpetAreaView(),
    const CapitalGainsView(),
  ]) {
    for (final brightness in Brightness.values) {
      testWidgets('${view.runtimeType} at narrow width and large text in $brightness', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpProviderApp(view, textScale: 2, theme: ThemeData(brightness: brightness));
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('validation remains beside the input and retains entered values', (tester) async {
    await tester.pumpProviderApp(const EmiCalculatorView());
    await tester.enterText(find.byType(TextField).at(0), '1000000');
    await tester.enterText(find.byType(TextField).at(1), '0');
    await tester.enterText(find.byType(TextField).at(2), '20');
    final button = find.byKey(const ValueKey('qa.tools.emi.calculate'));
    await tester.ensureVisible(button);
    // The pinned header changes height as the page scrolls; settle first.
    await tester.pump();
    await tester.tap(button);
    await tester.pumpAndSettle();
    final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields[0].controller!.text, '1000000');
    expect(fields[1].controller!.text, '0');
    expect(fields[1].decoration!.errorText, 'Please enter valid amounts to calculate');
    expect(fields[2].controller!.text, '20');
  });
}
