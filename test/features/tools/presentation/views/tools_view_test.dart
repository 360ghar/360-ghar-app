import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/features/tools/presentation/views/area_converter_view.dart';
import 'package:ghar360/features/tools/presentation/views/emi_calculator_view.dart';
import 'package:ghar360/features/tools/presentation/views/tools_view.dart';
import 'package:ghar360/features/tools/presentation/widgets/tool_card.dart';
import '../../../../helpers/knife_finders.dart';
import '../../../../helpers/provider_test_app.dart';

void main() {
  group('ToolsView', () {
    testWidgets('renders screen with title and subtitle', (tester) async {
      await tester.pumpProviderApp(const ToolsView());
      await tester.pump();

      expect(find.byKey(const ValueKey('qa.tools.screen')), findsOneWidget);
      expect(
        find.text(const AppLocalizations(Locale('en', 'US')).text('tools_calculators')),
        findsOneWidget,
      );
      expect(
        find.text(const AppLocalizations(Locale('en', 'US')).text('tools_subtitle')),
        findsOneWidget,
      );
    });

    testWidgets('renders six tool cards', (tester) async {
      // Use a tall surface so the GridView builds all six cards.
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpProviderApp(const ToolsView());
      await tester.pumpAndSettle();

      expect(find.byType(ToolCard), findsNWidgets(6));
    });

    testWidgets('renders all tool titles', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpProviderApp(const ToolsView());
      await tester.pumpAndSettle();

      expect(
        find.text(const AppLocalizations(Locale('en', 'US')).text('area_converter')),
        findsOneWidget,
      );
      expect(
        find.text(const AppLocalizations(Locale('en', 'US')).text('loan_eligibility')),
        findsOneWidget,
      );
      expect(
        find.text(const AppLocalizations(Locale('en', 'US')).text('emi_calculator')),
        findsOneWidget,
      );
      expect(
        find.text(const AppLocalizations(Locale('en', 'US')).text('carpet_area_calculator')),
        findsOneWidget,
      );
      expect(
        find.text(const AppLocalizations(Locale('en', 'US')).text('document_checklist')),
        findsOneWidget,
      );
      expect(
        find.text(const AppLocalizations(Locale('en', 'US')).text('capital_gains')),
        findsOneWidget,
      );
    });

    testWidgets('tapping area converter card navigates to its route', (tester) async {
      await tester.pumpProviderApp(const ToolsView());
      await tester.pumpAndSettle();

      await tester.tap(
        find.text(const AppLocalizations(Locale('en', 'US')).text('area_converter')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AreaConverterView), findsOneWidget);
    });

    testWidgets('tapping EMI calculator card navigates to its route', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpProviderApp(const ToolsView());
      await tester.pumpAndSettle();

      await tester.tap(
        find.text(const AppLocalizations(Locale('en', 'US')).text('emi_calculator')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EmiCalculatorView), findsOneWidget);
    });

    testWidgets('back button pops back to previous route', (tester) async {
      await tester.pumpProviderApp(
        Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute<void>(builder: (_) => const ToolsView())),
                child: const Text('open_tools'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('open_tools'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('qa.tools.screen')), findsOneWidget);

      await tester.tap(findKnife(KnifeIcon.arrowLeft));
      await tester.pumpAndSettle();

      expect(find.text('open_tools'), findsOneWidget);
    });
  });
}
