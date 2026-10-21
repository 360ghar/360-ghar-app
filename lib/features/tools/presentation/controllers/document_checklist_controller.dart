import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/bootstrap/provider_policy.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/core/utils/storage_keys.dart';

class DocumentItem {
  const DocumentItem({
    required this.id,
    required this.titleKey,
    required this.descriptionKey,
    this.isChecked = false,
  });
  final String id;
  final String titleKey;
  final String descriptionKey;
  final bool isChecked;
}

class DocumentCategory {
  const DocumentCategory({required this.titleKey, required this.items});
  final String titleKey;
  final List<DocumentItem> items;
}

const _documentCategories = [
  DocumentCategory(
    titleKey: 'doc_category_title',
    items: [
      DocumentItem(
        id: 'title_deed',
        titleKey: 'doc_title_deed',
        descriptionKey: 'doc_title_deed_desc',
      ),
      DocumentItem(
        id: 'sale_deed',
        titleKey: 'doc_sale_deed',
        descriptionKey: 'doc_sale_deed_desc',
      ),
      DocumentItem(
        id: 'mother_deed',
        titleKey: 'doc_mother_deed',
        descriptionKey: 'doc_mother_deed_desc',
      ),
    ],
  ),
  DocumentCategory(
    titleKey: 'doc_category_legal',
    items: [
      DocumentItem(
        id: 'encumbrance',
        titleKey: 'doc_encumbrance',
        descriptionKey: 'doc_encumbrance_desc',
      ),
      DocumentItem(id: 'khata', titleKey: 'doc_khata', descriptionKey: 'doc_khata_desc'),
      DocumentItem(id: 'mutation', titleKey: 'doc_mutation', descriptionKey: 'doc_mutation_desc'),
    ],
  ),
  DocumentCategory(
    titleKey: 'doc_category_noc',
    items: [
      DocumentItem(
        id: 'society_noc',
        titleKey: 'doc_society_noc',
        descriptionKey: 'doc_society_noc_desc',
      ),
      DocumentItem(id: 'bank_noc', titleKey: 'doc_bank_noc', descriptionKey: 'doc_bank_noc_desc'),
      DocumentItem(id: 'rera', titleKey: 'doc_rera', descriptionKey: 'doc_rera_desc'),
    ],
  ),
  DocumentCategory(
    titleKey: 'doc_category_financial',
    items: [
      DocumentItem(
        id: 'property_tax',
        titleKey: 'doc_property_tax',
        descriptionKey: 'doc_property_tax_desc',
      ),
      DocumentItem(
        id: 'utility_bills',
        titleKey: 'doc_utility_bills',
        descriptionKey: 'doc_utility_bills_desc',
      ),
      DocumentItem(
        id: 'maintenance_dues',
        titleKey: 'doc_maintenance_dues',
        descriptionKey: 'doc_maintenance_dues_desc',
      ),
    ],
  ),
  DocumentCategory(
    titleKey: 'doc_category_possession',
    items: [
      DocumentItem(
        id: 'possession_letter',
        titleKey: 'doc_possession_letter',
        descriptionKey: 'doc_possession_letter_desc',
      ),
      DocumentItem(
        id: 'occupancy_cert',
        titleKey: 'doc_occupancy_cert',
        descriptionKey: 'doc_occupancy_cert_desc',
      ),
      DocumentItem(
        id: 'completion_cert',
        titleKey: 'doc_completion_cert',
        descriptionKey: 'doc_completion_cert_desc',
      ),
    ],
  ),
];
final _knownIds = _documentCategories
    .expand((category) => category.items)
    .map((item) => item.id)
    .toSet();

enum ChecklistSaveStatus { saved, saving, failed, loadFailed }

class DocumentChecklistState {
  DocumentChecklistState({
    Set<String> checkedIds = const {},
    this.saveStatus = ChecklistSaveStatus.saved,
  }) : checkedIds = Set.unmodifiable(checkedIds);
  final Set<String> checkedIds;
  final ChecklistSaveStatus saveStatus;
  int get totalItems => _knownIds.length;
  int get checkedItems => checkedIds.length;
  double get progress => checkedItems / totalItems;
  List<DocumentCategory> get categories => List.unmodifiable(
    _documentCategories.map(
      (category) => DocumentCategory(
        titleKey: category.titleKey,
        items: List.unmodifiable(
          category.items.map(
            (item) => DocumentItem(
              id: item.id,
              titleKey: item.titleKey,
              descriptionKey: item.descriptionKey,
              isChecked: checkedIds.contains(item.id),
            ),
          ),
        ),
      ),
    ),
  );
}

final documentChecklistProvider =
    NotifierProvider.autoDispose<DocumentChecklistController, DocumentChecklistState>(
      DocumentChecklistController.new,
      retry: noProviderRetry,
    );

class DocumentChecklistController extends Notifier<DocumentChecklistState> {
  late AppDatabase _database;
  Future<void> _writes = Future<void>.value();
  int _writeVersion = 0;

  @override
  DocumentChecklistState build() {
    _database = ref.watch(appDatabaseProvider);
    try {
      final saved =
          _database.readPreference<Map<String, dynamic>>(StorageKeys.documentChecklist) ?? {};
      return DocumentChecklistState(
        checkedIds: {
          for (final id in _knownIds)
            if (saved[id] == true) id,
        },
      );
    } catch (_) {
      return DocumentChecklistState(saveStatus: ChecklistSaveStatus.loadFailed);
    }
  }

  Future<void> toggleItem(String id) async {
    if (state.saveStatus == ChecklistSaveStatus.loadFailed || !_knownIds.contains(id)) return;
    final next = {...state.checkedIds};
    if (!next.remove(id)) next.add(id);
    await _save(next);
  }

  Future<void> resetAll() async {
    if (state.saveStatus != ChecklistSaveStatus.loadFailed) await _save({});
  }

  void retryLoad() => ref.invalidateSelf();
  Future<void> retrySave() => _save(state.checkedIds);

  Future<void> _save(Set<String> checked) async {
    final version = ++_writeVersion;
    state = DocumentChecklistState(checkedIds: checked, saveStatus: ChecklistSaveStatus.saving);
    final values = {for (final id in _knownIds) id: checked.contains(id)};
    final write = _writes.then(
      (_) => _database.writePreference(StorageKeys.documentChecklist, values),
    );
    // Serialize writes. A failed earlier write must not stop a later full snapshot.
    _writes = write.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    try {
      await write;
      if (ref.mounted && version == _writeVersion) {
        state = DocumentChecklistState(checkedIds: checked);
      }
    } catch (_) {
      if (ref.mounted && version == _writeVersion) {
        state = DocumentChecklistState(checkedIds: checked, saveStatus: ChecklistSaveStatus.failed);
      }
    }
  }
}
