import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/design/app_design_theme.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/features/tools/presentation/views/area_converter_view.dart';
import 'package:ghar360/features/tools/presentation/views/capital_gains_view.dart';
import 'package:ghar360/features/tools/presentation/views/carpet_area_view.dart';
import 'package:ghar360/features/tools/presentation/views/document_checklist_view.dart';
import 'package:ghar360/features/tools/presentation/views/emi_calculator_view.dart';
import 'package:ghar360/features/tools/presentation/views/loan_eligibility_view.dart';
import 'package:ghar360/features/tools/presentation/views/tools_view.dart';
import '../../../../helpers/provider_test_app.dart';
import '../../../../helpers/tool_test_database.dart';

/// Each screen with its inputs filled and its result shown, so the widest
/// layout (the result block) is measured too. Empty inputs stay as they are.
final _screens = <String, (Widget, Map<int, String>, String?, String?)>{
  'tools menu': (const ToolsView(), {}, null, null),
  'EMI': (
    const EmiCalculatorView(),
    {0: '98765432', 1: '8.5', 2: '30'},
    'qa.tools.emi.calculate',
    'qa.tools.emi.monthly',
  ),
  'loan eligibility': (
    const LoanEligibilityView(),
    {0: '250000', 1: '32', 2: '15000'},
    'qa.tools.loan_eligibility.calculate',
    'qa.tools.loan_eligibility.max_loan',
  ),
  'carpet area': (
    const CarpetAreaView(),
    {0: '1850'},
    'qa.tools.carpet_area.calculate',
    'qa.tools.carpet_area.usable',
  ),
  'capital gains': (
    const CapitalGainsView(),
    {0: '5000000', 1: '400000', 2: '98000000'},
    'qa.tools.capital_gains.calculate',
    'qa.tools.capital_gains.term',
  ),
  'area converter': (const AreaConverterView(), {0: '123456789'}, null, null),
  'document checklist': (const DocumentChecklistView(), {}, null, null),
};

void main() {
  for (final MapEntry(key: name, value: (view, inputs, calculate, result)) in _screens.entries) {
    for (final dark in [true, false]) {
      testWidgets('$name fits 320 px, Hindi, 2x text, ${dark ? 'dark' : 'light'}', (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpProviderApp(
          view,
          locale: const Locale('hi', 'IN'),
          textScale: 2,
          theme: dark ? AppDesignTheme.dark() : AppDesignTheme.light(),
          overrides: [appDatabaseProvider.overrideWithValue(ToolTestDatabase())],
        );
        await tester.pump();
        expect(tester.takeException(), isNull);

        for (final MapEntry(key: index, value: text) in inputs.entries) {
          final field = find.byType(TextField).at(index);
          await tester.ensureVisible(field);
          await tester.enterText(field, text);
          // Focus scrolls the field into view; let that finish before the tap.
          await tester.pumpAndSettle();
        }
        if (calculate != null) {
          final button = find.byKey(ValueKey(calculate));
          await tester.ensureVisible(button);
          await tester.pumpAndSettle();
          await tester.tap(button);
          await tester.pump();
        }
        expect(tester.takeException(), isNull);
        if (result != null) expect(find.byKey(ValueKey(result)), findsOneWidget);

        // Scroll to the end so every row, down to the last result, is laid out.
        final scrollable = find.byType(Scrollable).first;
        await tester.fling(scrollable, const Offset(0, -4000), 3000);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
