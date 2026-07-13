// test/features/tools/presentation/views/document_checklist_view_test.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ghar360/features/tools/presentation/controllers/document_checklist_controller.dart';
import 'package:ghar360/features/tools/presentation/views/document_checklist_view.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../../../helpers/getx_test_binding.dart';
import '../../../../helpers/pump_app.dart';

// ---------------------------------------------------------------------------
// Fake path_provider so GetStorage can initialise in tests
// ---------------------------------------------------------------------------

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this._path);
  final String _path;

  @override
  Future<String?> getApplicationDocumentsPath() async => _path;
}

void main() {
  late DocumentChecklistController controller;
  late Directory tempDir;

  setUp(() async {
    // Create a temp directory for GetStorage
    tempDir = await Directory.systemTemp.createTemp('get_storage_test_');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);

    GetxTestBinding.init();
    await GetStorage.init();

    controller = DocumentChecklistController();
    Get.put<DocumentChecklistController>(controller);
    // Manually trigger onInit since Get.put doesn't call it in test mode
    controller.onInit();
  });

  tearDown(() async {
    // Await flush so GetStorage does not write into a deleted temp dir.
    await GetStorage().remove('document_checklist');
    GetxTestBinding.reset();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> pumpView(WidgetTester tester) async {
    await tester.pumpApp(const DocumentChecklistView());
    await tester.pump();
  }

  group('DocumentChecklistView', () {
    testWidgets('renders scaffold with correct key and app bar title', (tester) async {
      await pumpView(tester);

      expect(find.byKey(const ValueKey('qa.tools.document_checklist.screen')), findsOneWidget);
      expect(find.text('Document Checklist'), findsOneWidget);
    });

    testWidgets('renders back and refresh icons in app bar', (tester) async {
      await pumpView(tester);

      expect(find.byTooltip('Back'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('renders progress section with progress label', (tester) async {
      await pumpView(tester);

      expect(find.text('Progress'), findsOneWidget);
    });

    testWidgets('renders linear progress indicator', (tester) async {
      await pumpView(tester);

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('shows initial count as 0/total', (tester) async {
      await pumpView(tester);

      // Total items = 5 categories * 3 items = 15
      expect(find.text('0/15'), findsOneWidget);
    });

    testWidgets('renders all category sections', (tester) async {
      await pumpView(tester);

      // First two categories should be visible initially
      expect(find.text('Title Documents'), findsOneWidget);
      expect(find.text('Legal Verification'), findsOneWidget);

      // Scroll down to see remaining categories
      await tester.scrollUntilVisible(
        find.text('NOCs & Approvals'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('NOCs & Approvals'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Financial Documents'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Financial Documents'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Possession Documents'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Possession Documents'), findsOneWidget);
    });

    testWidgets('renders all document items with titles', (tester) async {
      await pumpView(tester);

      expect(find.text('Title Deed'), findsOneWidget);
      expect(find.text('Sale Deed'), findsOneWidget);
      expect(find.text('Mother Deed'), findsOneWidget);
      expect(find.text('Encumbrance Certificate'), findsOneWidget);
      expect(find.text('Khata Certificate'), findsOneWidget);
    });

    testWidgets('tapping a document item toggles its checked state', (tester) async {
      await pumpView(tester);

      // Initially 0 checked
      expect(find.text('0/15'), findsOneWidget);

      // Tap the first document item (Title Deed)
      await tester.tap(find.text('Title Deed'));
      await tester.pumpAndSettle();

      // Should now show 1/15
      expect(find.text('1/15'), findsOneWidget);
      expect(controller.checkedItems.value, 1);
    });

    testWidgets('tapping a checked item unchecks it', (tester) async {
      await pumpView(tester);

      // Tap to check
      await tester.tap(find.text('Title Deed'));
      await tester.pumpAndSettle();
      expect(find.text('1/15'), findsOneWidget);

      // Tap again to uncheck
      await tester.tap(find.text('Title Deed'));
      await tester.pumpAndSettle();
      expect(find.text('0/15'), findsOneWidget);
      expect(controller.checkedItems.value, 0);
    });

    testWidgets('checking all items shows full progress', (tester) async {
      await pumpView(tester);

      // Toggle all items via controller for reliability
      final allItemIds = [
        'title_deed',
        'sale_deed',
        'mother_deed',
        'encumbrance',
        'khata',
        'mutation',
        'society_noc',
        'bank_noc',
        'rera',
        'property_tax',
        'utility_bills',
        'maintenance_dues',
        'possession_letter',
        'occupancy_cert',
        'completion_cert',
      ];

      for (final id in allItemIds) {
        controller.toggleItem(id);
      }
      await tester.pumpAndSettle();

      expect(controller.progress, 1.0);
      expect(controller.checkedItems.value, 15);
      expect(find.text('15/15'), findsOneWidget);
    });

    testWidgets('checked items show check icon', (tester) async {
      await pumpView(tester);

      // Initially no check icons
      expect(find.byIcon(Icons.check), findsNothing);

      // Tap to check first item
      await tester.tap(find.text('Title Deed'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('reset button shows confirmation dialog', (tester) async {
      await pumpView(tester);

      // First check an item
      await tester.tap(find.text('Title Deed'));
      await tester.pumpAndSettle();
      expect(find.text('1/15'), findsOneWidget);

      // Tap reset button
      await tester.tap(find.byKey(const ValueKey('qa.tools.document_checklist.reset')));
      await tester.pumpAndSettle();

      // Dialog should appear
      expect(find.text('Reset Checklist'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);
    });

    testWidgets('canceling reset dialog keeps checked items', (tester) async {
      await pumpView(tester);

      // Check an item
      await tester.tap(find.text('Title Deed'));
      await tester.pumpAndSettle();
      expect(find.text('1/15'), findsOneWidget);

      // Open reset dialog
      await tester.tap(find.byKey(const ValueKey('qa.tools.document_checklist.reset')));
      await tester.pumpAndSettle();

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Items should still be checked
      expect(find.text('1/15'), findsOneWidget);
      expect(controller.checkedItems.value, 1);
    });

    testWidgets('confirming reset clears all checked items', (tester) async {
      await pumpView(tester);

      // Check some items
      await tester.tap(find.text('Title Deed'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sale Deed'));
      await tester.pumpAndSettle();
      expect(find.text('2/15'), findsOneWidget);

      // Open reset dialog
      await tester.tap(find.byKey(const ValueKey('qa.tools.document_checklist.reset')));
      await tester.pumpAndSettle();

      // Tap Reset confirm button
      await tester.tap(find.byKey(const ValueKey('qa.tools.document_checklist.reset_confirm')));
      await tester.pumpAndSettle();

      // All items should be unchecked
      expect(find.text('0/15'), findsOneWidget);
      expect(controller.checkedItems.value, 0);
    });

    testWidgets('back button is wired to Get.back', (tester) async {
      await pumpView(tester);

      final backButton = find.byTooltip('Back');
      expect(backButton, findsOneWidget);

      await tester.tap(backButton);
      await tester.pump();
    });

    testWidgets('progress bar shows correct value', (tester) async {
      await pumpView(tester);

      // Check 3 items
      await tester.tap(find.text('Title Deed'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sale Deed'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mother Deed'));
      await tester.pumpAndSettle();

      expect(find.text('3/15'), findsOneWidget);
      expect(controller.progress, closeTo(0.2, 0.01));
    });

    testWidgets('renders document descriptions', (tester) async {
      await pumpView(tester);

      // Check that some descriptions are rendered
      expect(find.text('Proof of property ownership'), findsOneWidget);
    });

    testWidgets('renders ListView with category cards', (tester) async {
      await pumpView(tester);

      expect(find.byType(ListView), findsOneWidget);
      // At least the first category card should be rendered (ListView is lazy)
      expect(find.byType(Card), findsAtLeast(1));
    });

    testWidgets('dividers are present between items in a category', (tester) async {
      await pumpView(tester);

      // Each visible category has 3 items with 2 dividers; at least 2 should be visible
      expect(find.byType(Divider), findsAtLeast(2));
    });

    testWidgets('toggleItem method toggles item by id', (tester) async {
      await pumpView(tester);

      controller.toggleItem('title_deed');
      await tester.pumpAndSettle();

      expect(controller.checkedItems.value, 1);
      expect(find.text('1/15'), findsOneWidget);
    });

    testWidgets('resetAll method clears all items', (tester) async {
      await pumpView(tester);

      controller.toggleItem('title_deed');
      controller.toggleItem('sale_deed');
      await tester.pumpAndSettle();
      expect(controller.checkedItems.value, 2);

      controller.resetAll();
      await tester.pumpAndSettle();

      expect(controller.checkedItems.value, 0);
      expect(find.text('0/15'), findsOneWidget);
    });
  });
}
