import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/utils/storage_keys.dart';
import 'package:ghar360/features/tools/presentation/controllers/document_checklist_controller.dart';
import '../../../../helpers/tool_test_database.dart';

void main() {
  late ProviderContainer container;
  late ToolTestDatabase database;
  setUp(() {
    database = ToolTestDatabase();
    container = ProviderContainer(overrides: [appDatabaseProvider.overrideWithValue(database)]);
    container.listen(documentChecklistProvider, (_, _) {});
  });
  tearDown(() => container.dispose());
  DocumentChecklistController createController() =>
      container.read(documentChecklistProvider.notifier);
  DocumentChecklistState readState() => container.read(documentChecklistProvider);

  group('DocumentChecklistController', () {
    // ── Initial state ────────────────────────────────────────────────────

    test('initializes with 5 categories and 15 total documents', () async {
      expect(readState().categories.length, 5);
      expect(readState().totalItems, 15);
      expect(readState().checkedItems, 0);
      expect(readState().progress, 0);
    });

    test('all documents are unchecked by default', () async {
      for (final category in readState().categories) {
        for (final item in category.items) {
          expect(item.isChecked, isFalse, reason: 'Item ${item.id} should start unchecked');
        }
      }
    });

    // ── toggleItem ───────────────────────────────────────────────────────

    test('toggleItem checks an unchecked item and updates counts', () async {
      final controller = createController();

      await controller.toggleItem('title_deed');

      expect(readState().checkedItems, 1);
      final item = readState().categories
          .expand((c) => c.items)
          .firstWhere((i) => i.id == 'title_deed');
      expect(item.isChecked, isTrue);
    });

    test('toggleItem unchecks a checked item', () async {
      final controller = createController();

      await controller.toggleItem('title_deed');
      expect(readState().checkedItems, 1);

      await controller.toggleItem('title_deed');
      expect(readState().checkedItems, 0);
      final item = readState().categories
          .expand((c) => c.items)
          .firstWhere((i) => i.id == 'title_deed');
      expect(item.isChecked, isFalse);
    });

    // ── progress ─────────────────────────────────────────────────────────

    test('progress reflects checked items proportion', () async {
      final controller = createController();

      expect(readState().progress, 0);

      await controller.toggleItem('title_deed');
      await controller.toggleItem('sale_deed');
      await controller.toggleItem('encumbrance');

      expect(readState().progress, closeTo(3 / 15, 0.001));
      expect(readState().progress, closeTo(0.2, 0.001));
    });

    // ── resetAll ─────────────────────────────────────────────────────────

    test('resetAll unchecks all items and resets counts', () async {
      final controller = createController();

      await controller.toggleItem('title_deed');
      await controller.toggleItem('sale_deed');
      await controller.toggleItem('encumbrance');
      await controller.toggleItem('rera');
      expect(readState().checkedItems, 4);

      await controller.resetAll();

      expect(readState().checkedItems, 0);
      expect(readState().progress, 0);
      for (final category in readState().categories) {
        for (final item in category.items) {
          expect(item.isChecked, isFalse, reason: 'Item ${item.id} should be unchecked');
        }
      }
    });

    // ── toggleItem with non-existent id ───────────────────────────────────

    test('toggleItem with non-existent id does nothing', () async {
      final controller = createController();

      await controller.toggleItem('non_existent_id');

      expect(readState().checkedItems, 0);
      expect(readState().totalItems, 15);
    });

    // ── toggleItem across categories ──────────────────────────────────────

    test('toggleItem works for items in different categories', () async {
      final controller = createController();

      // Items from different categories
      await controller.toggleItem('title_deed'); // category 0
      await controller.toggleItem('encumbrance'); // category 1
      await controller.toggleItem('society_noc'); // category 2
      await controller.toggleItem('property_tax'); // category 3
      await controller.toggleItem('possession_letter'); // category 4

      expect(readState().checkedItems, 5);
      expect(readState().progress, closeTo(5 / 15, 0.001));
    });

    // ── progress with all items checked ───────────────────────────────────

    test('progress is 1.0 when all items are checked', () async {
      final controller = createController();

      // Check all 15 items
      final allIds = readState().categories.expand((c) => c.items).map((i) => i.id).toList();
      for (final id in allIds) {
        await controller.toggleItem(id);
      }

      expect(readState().checkedItems, 15);
      expect(readState().totalItems, 15);
      expect(readState().progress, 1.0);
    });

    // ── progress with half items checked ──────────────────────────────────

    test('progress is approximately 0.5 when half items checked', () async {
      final controller = createController();

      // Check 7 items (close to half of 15)
      final allIds = readState().categories
          .expand((c) => c.items)
          .map((i) => i.id)
          .take(7)
          .toList();
      for (final id in allIds) {
        await controller.toggleItem(id);
      }

      expect(readState().checkedItems, 7);
      expect(readState().progress, closeTo(7 / 15, 0.001));
    });

    // ── category structure ────────────────────────────────────────────────

    test('each category has exactly 3 items', () async {
      for (final category in readState().categories) {
        expect(
          category.items.length,
          3,
          reason: 'Category ${category.titleKey} should have 3 items',
        );
      }
    });

    test('all item ids are unique', () async {
      final allIds = readState().categories.expand((c) => c.items).map((i) => i.id).toList();
      expect(allIds.toSet().length, allIds.length, reason: 'All item ids should be unique');
    });

    test('all category titleKeys are unique', () async {
      final titleKeys = readState().categories.map((c) => c.titleKey).toList();
      expect(
        titleKeys.toSet().length,
        titleKeys.length,
        reason: 'All category titleKeys should be unique',
      );
    });

    // ── toggleItem toggles back and forth ─────────────────────────────────

    test('toggleItem can toggle same item multiple times', () async {
      final controller = createController();

      await controller.toggleItem('khata');
      expect(readState().checkedItems, 1);

      await controller.toggleItem('khata');
      expect(readState().checkedItems, 0);

      await controller.toggleItem('khata');
      expect(readState().checkedItems, 1);

      await controller.toggleItem('khata');
      expect(readState().checkedItems, 0);
    });

    // ── resetAll when nothing is checked ──────────────────────────────────

    test('resetAll when nothing is checked is a no-op', () async {
      final controller = createController();

      await controller.resetAll();

      expect(readState().checkedItems, 0);
      expect(readState().progress, 0);
    });

    // ── totalItems stays constant ─────────────────────────────────────────

    test('totalItems stays constant regardless of toggles', () async {
      final controller = createController();
      final initialTotal = readState().totalItems;

      await controller.toggleItem('title_deed');
      await controller.toggleItem('sale_deed');
      await controller.toggleItem('encumbrance');
      await controller.resetAll();
      await controller.toggleItem('rera');

      expect(readState().totalItems, initialTotal);
    });

    // ── all items have non-empty titleKey and descriptionKey ───────────────

    test('all items have non-empty titleKey and descriptionKey', () async {
      for (final category in readState().categories) {
        for (final item in category.items) {
          expect(item.titleKey, isNotEmpty, reason: 'Item ${item.id} has empty titleKey');
          expect(
            item.descriptionKey,
            isNotEmpty,
            reason: 'Item ${item.id} has empty descriptionKey',
          );
        }
      }
    });

    // ── progress after resetAll and re-check ──────────────────────────────

    test('progress updates correctly after resetAll and re-check', () async {
      final controller = createController();

      await controller.toggleItem('title_deed');
      await controller.toggleItem('sale_deed');
      expect(readState().progress, closeTo(2 / 15, 0.001));

      await controller.resetAll();
      expect(readState().progress, 0);

      await controller.toggleItem('mutation');
      expect(readState().progress, closeTo(1 / 15, 0.001));
    });
    test('failed writes retain selection and expose retry state', () async {
      final controller = createController();
      database.failWrites = true;
      await controller.toggleItem('title_deed');
      expect(readState().checkedIds, {'title_deed'});
      expect(readState().saveStatus, ChecklistSaveStatus.failed);
      expect(database.preferences, isEmpty);
      database.failWrites = false;
      await controller.retrySave();
      expect(readState().saveStatus, ChecklistSaveStatus.saved);
      expect((database.preferences[StorageKeys.documentChecklist] as Map)['title_deed'], isTrue);
    });

    test('queued snapshots preserve rapid toggles and reset ordering', () async {
      final gate = Completer<void>();
      database.beforeWrite = () => gate.future;
      final controller = createController();
      final first = controller.toggleItem('title_deed');
      final second = controller.toggleItem('sale_deed');
      final reset = controller.resetAll();
      expect(readState().saveStatus, ChecklistSaveStatus.saving);
      expect(readState().checkedItems, 0);
      expect(database.preferences, isEmpty);
      gate.complete();
      await Future.wait([first, second, reset]);
      expect(readState().saveStatus, ChecklistSaveStatus.saved);
      final saved = database.preferences[StorageKeys.documentChecklist] as Map;
      expect(saved.values.every((value) => value == false), isTrue);
      expect(database.writes.length, 3);
    });

    test('saved checklist is loaded through the database dependency', () {
      database.preferences[StorageKeys.documentChecklist] = <String, dynamic>{
        'title_deed': true,
        'sale_deed': false,
        'rera': 'bad',
        'unknown': true,
      };
      container.invalidate(documentChecklistProvider);
      expect(readState().checkedIds, {'title_deed'});
      expect(() => readState().checkedIds.add('khata'), throwsUnsupportedError);
    });

    test('disposal during a write does not publish state afterward', () async {
      final gate = Completer<void>();
      database.beforeWrite = () => gate.future;
      final saving = createController().toggleItem('title_deed');
      container.dispose();
      gate.complete();
      await saving;
      expect((database.preferences[StorageKeys.documentChecklist] as Map)['title_deed'], isTrue);
      container = ProviderContainer();
    });
    test('failed initial reads cannot overwrite existing checklist data', () async {
      database.preferences[StorageKeys.documentChecklist] = <String, dynamic>{'title_deed': true};
      database.failReads = true;
      container.invalidate(documentChecklistProvider);
      expect(readState().saveStatus, ChecklistSaveStatus.loadFailed);
      final controller = createController();
      await controller.toggleItem('khata');
      await controller.resetAll();
      expect(database.writes, isEmpty);
      database.failReads = false;
      controller.retryLoad();
      expect(readState().checkedIds, {'title_deed'});
      expect(readState().saveStatus, ChecklistSaveStatus.saved);
    });
  });
}
