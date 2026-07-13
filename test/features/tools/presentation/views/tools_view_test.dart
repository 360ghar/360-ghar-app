// test/features/tools/presentation/views/tools_view_test.dart

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:ghar360/core/translations/app_translations.dart';
import 'package:ghar360/features/tools/presentation/controllers/tools_controller.dart';
import 'package:ghar360/features/tools/presentation/views/tools_view.dart';
import 'package:ghar360/features/tools/presentation/widgets/tool_card.dart';
import '../../../../helpers/getx_test_binding.dart';

/// Pumps [home] inside a GetMaterialApp that also registers named routes for
/// the tool destinations so `Get.toNamed` resolves during tests.
Future<void> _pumpWithRoutes(WidgetTester tester, Widget home) async {
  await tester.pumpWidget(
    GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('en', 'US'),
      fallbackLocale: const Locale('en', 'US'),
      home: home,
      routes: {
        '/tools/area-converter': (_) => const Scaffold(body: Text('area_converter_route')),
        '/tools/loan-eligibility': (_) => const Scaffold(body: Text('loan_route')),
        '/tools/emi-calculator': (_) => const Scaffold(body: Text('emi_route')),
        '/tools/carpet-area': (_) => const Scaffold(body: Text('carpet_route')),
        '/tools/document-checklist': (_) => const Scaffold(body: Text('doc_route')),
        '/tools/capital-gains': (_) => const Scaffold(body: Text('capital_route')),
      },
    ),
  );
}

void main() {
  setUp(() {
    GetxTestBinding.init();
    Get.put<ToolsController>(ToolsController());
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  group('ToolsView', () {
    testWidgets('renders screen with title and subtitle', (tester) async {
      await _pumpWithRoutes(tester, const ToolsView());
      await tester.pump();

      expect(find.byKey(const ValueKey('qa.tools.screen')), findsOneWidget);
      expect(find.text('tools_calculators'.tr), findsOneWidget);
      expect(find.text('tools_subtitle'.tr), findsOneWidget);
    });

    testWidgets('renders six tool cards', (tester) async {
      // Use a tall surface so the GridView builds all six cards.
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpWithRoutes(tester, const ToolsView());
      await tester.pumpAndSettle();

      expect(find.byType(ToolCard), findsNWidgets(6));
    });

    testWidgets('renders all tool titles', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpWithRoutes(tester, const ToolsView());
      await tester.pumpAndSettle();

      expect(find.text('area_converter'.tr), findsOneWidget);
      expect(find.text('loan_eligibility'.tr), findsOneWidget);
      expect(find.text('emi_calculator'.tr), findsOneWidget);
      expect(find.text('carpet_area_calculator'.tr), findsOneWidget);
      expect(find.text('document_checklist'.tr), findsOneWidget);
      expect(find.text('capital_gains'.tr), findsOneWidget);
    });

    testWidgets('tapping area converter card navigates to its route', (tester) async {
      await _pumpWithRoutes(tester, const ToolsView());
      await tester.pumpAndSettle();

      await tester.tap(find.text('area_converter'.tr));
      await tester.pumpAndSettle();

      expect(find.text('area_converter_route'), findsOneWidget);
    });

    testWidgets('tapping EMI calculator card navigates to its route', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpWithRoutes(tester, const ToolsView());
      await tester.pumpAndSettle();

      await tester.tap(find.text('emi_calculator'.tr));
      await tester.pumpAndSettle();

      expect(find.text('emi_route'), findsOneWidget);
    });

    testWidgets('back button pops back to previous route', (tester) async {
      await _pumpWithRoutes(
        tester,
        Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Get.to(() => const ToolsView()),
              child: const Text('open_tools'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('open_tools'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('qa.tools.screen')), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('open_tools'), findsOneWidget);
    });
  });
}
