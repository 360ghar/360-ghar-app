import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/features/tools/presentation/controllers/document_checklist_controller.dart';
import 'package:ghar360/features/tools/presentation/views/document_checklist_view.dart';
import '../../../../helpers/knife_finders.dart';
import '../../../../helpers/provider_test_app.dart';
import '../../../../helpers/tool_test_database.dart';

void main() {
  late ProviderContainer container;
  late ToolTestDatabase database;
  setUp(() => database = ToolTestDatabase());
  DocumentChecklistController getController() => container.read(documentChecklistProvider.notifier);
  DocumentChecklistState readState() => container.read(documentChecklistProvider);
  Future<void> pumpView(WidgetTester tester) async {
    await tester.pumpProviderApp(
      const DocumentChecklistView(),
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    container = ProviderScope.containerOf(tester.element(find.byType(DocumentChecklistView)));
    await tester.pump();
  }

  group('DocumentChecklistView', () {
    testWidgets('renders scaffold with correct key and app bar title', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await pumpView(tester);

        expect(find.byKey(const ValueKey('qa.tools.document_checklist.screen')), findsOneWidget);
        expect(find.bySemanticsIdentifier('qa.tools.document_checklist.screen'), findsOneWidget);
        expect(find.bySemanticsLabel(RegExp(r'qa\.tools')), findsNothing);
        expect(find.text('Document Checklist'), findsOneWidget);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('renders back and refresh icons in app bar', (tester) async {
      await pumpView(tester);

      expect(find.byTooltip('Back'), findsOneWidget);
      expect(findKnife(KnifeIcon.retry), findsOneWidget);
    });

    testWidgets('renders progress section with progress label', (tester) async {
      await pumpView(tester);

      expect(find.text('Progress'), findsOneWidget);
    });

    testWidgets('renders a still progress bar that announces its value', (tester) async {
      await pumpView(tester);

      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(
        tester.getSemantics(find.byKey(const ValueKey('qa.tools.document_checklist.progress'))),
        matchesSemantics(label: 'Progress', value: '0/15'),
      );
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
      expect(readState().checkedItems, 1);
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
      expect(readState().checkedItems, 0);
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
        getController().toggleItem(id);
      }
      await tester.pumpAndSettle();

      expect(readState().progress, 1.0);
      expect(readState().checkedItems, 15);
      expect(find.text('15/15'), findsOneWidget);
    });

    testWidgets('checked items show a ticked checkbox', (tester) async {
      await pumpView(tester);

      bool ticked() => tester.widgetList<Checkbox>(find.byType(Checkbox)).first.value!;
      expect(ticked(), isFalse);

      // Tap to check first item
      await tester.tap(find.text('Title Deed'));
      await tester.pumpAndSettle();

      expect(ticked(), isTrue);
      expect(
        tester.getSemantics(find.bySemanticsIdentifier('qa.tools.document_checklist.title_deed')),
        matchesSemantics(
          label: 'Title Deed',
          hint: 'Proof of property ownership',
          hasCheckedState: true,
          isChecked: true,
          hasTapAction: true,
        ),
      );
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
      expect(readState().checkedItems, 1);
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
      expect(readState().checkedItems, 0);
    });

    testWidgets('back button is wired to Navigator.maybePop', (tester) async {
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
      expect(readState().progress, closeTo(0.2, 0.01));
    });

    testWidgets('renders document descriptions', (tester) async {
      await pumpView(tester);

      // Check that some descriptions are rendered
      expect(find.text('Proof of property ownership'), findsOneWidget);
    });

    testWidgets('renders one flat scroll list: no cards, no dividers', (tester) async {
      await pumpView(tester);

      expect(find.byType(CustomScrollView), findsOneWidget);
      // Dense lists stay flat: spacing and type separate the rows.
      expect(find.byType(Card), findsNothing);
      expect(find.byType(Divider), findsNothing);
      expect(find.byType(Checkbox), findsAtLeast(3));
    });

    testWidgets('toggleItem method toggles item by id', (tester) async {
      await pumpView(tester);

      getController().toggleItem('title_deed');
      await tester.pumpAndSettle();

      expect(readState().checkedItems, 1);
      expect(find.text('1/15'), findsOneWidget);
    });

    testWidgets('resetAll method clears all items', (tester) async {
      await pumpView(tester);

      getController().toggleItem('title_deed');
      getController().toggleItem('sale_deed');
      await tester.pumpAndSettle();
      expect(readState().checkedItems, 2);

      getController().resetAll();
      await tester.pumpAndSettle();

      expect(readState().checkedItems, 0);
      expect(find.text('0/15'), findsOneWidget);
    });
    testWidgets('failed save retains the checked item and exposes retry', (tester) async {
      database.failWrites = true;
      await pumpView(tester);
      await tester.tap(find.text('Title Deed'));
      await tester.pumpAndSettle();
      expect(readState().checkedItems, 1);
      expect(
        find.text('Changes could not be saved. Retry to keep your selection.'),
        findsOneWidget,
      );
      database.failWrites = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(readState().saveStatus, ChecklistSaveStatus.saved);
      expect(find.text('Changes could not be saved. Retry to keep your selection.'), findsNothing);
    });
  });
}
