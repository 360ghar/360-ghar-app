import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';

/// Device preferences. Purpose and property type are shared across feeds;
/// price, size, amenities and search belong to the selected feed.
class PropertyFiltersState {
  PropertyFiltersState(Map<PageType, UnifiedFilterModel> pages, {this.save = const AsyncData(null)})
    : pages = Map.unmodifiable({
        for (final entry in pages.entries)
          entry.key: entry.value.copyWith(
            propertyType: entry.value.propertyType == null
                ? null
                : List.unmodifiable(entry.value.propertyType!),
            amenities: entry.value.amenities == null
                ? null
                : List.unmodifiable(entry.value.amenities!),
            features: entry.value.features == null
                ? null
                : List.unmodifiable(entry.value.features!),
            propertyIds: entry.value.propertyIds == null
                ? null
                : List.unmodifiable(entry.value.propertyIds!),
          ),
      });
  final Map<PageType, UnifiedFilterModel> pages;
  final AsyncValue<void> save;
  UnifiedFilterModel forPage(PageType page) => pages[page]!;
}

final propertyFiltersProvider = NotifierProvider<PropertyFilters, PropertyFiltersState>(
  PropertyFilters.new,
);

class PropertyFilters extends Notifier<PropertyFiltersState> {
  Future<void> _writes = Future.value();
  int _revision = 0;

  @override
  PropertyFiltersState build() {
    final database = ref.watch(appDatabaseProvider);
    final saved = database.readPreference<Map>('property_filters_v1');
    final globalPurpose = database.readPreference<String>('global_purpose');
    final globalTypes = database.readPreference<List>('global_property_types')?.whereType<String>();
    final pages = <PageType, UnifiedFilterModel>{};
    for (final page in PageType.values) {
      final legacy = database.readPreference<Map>('${page.name}_state');
      final raw = saved?[page.name] ?? legacy?['filters'];
      var filters = UnifiedFilterModel.initial();
      if (raw is Map) {
        try {
          filters = UnifiedFilterModel.fromJson(Map<String, dynamic>.from(raw));
        } on Object {
          // A corrupt entry does not prevent another page's preferences loading.
        }
      }
      final legacySearch =
          page != PageType.discover && saved?[page.name] == null && legacy?['searchQuery'] is String
          ? legacy!['searchQuery'] as String
          : null;
      pages[page] = filters.copyWith(
        searchQuery: filters.searchQuery ?? legacySearch,
        purpose:
            UnifiedFilterModel.normalizePurposeToken(globalPurpose) ?? filters.purpose ?? 'buy',
        propertyType: globalTypes == null
            ? UnifiedFilterModel.normalizePropertyTypes(filters.propertyType)
            : UnifiedFilterModel.normalizePropertyTypes(globalTypes),
      );
    }
    return PropertyFiltersState(pages);
  }

  Future<bool> update(PageType page, UnifiedFilterModel filters) {
    final previous = state.forPage(page);
    final purpose = UnifiedFilterModel.normalizePurposeToken(filters.purpose) ?? 'buy';
    final types = UnifiedFilterModel.normalizePropertyTypes(filters.propertyType);
    final purposeChanged = purpose != previous.purpose;
    final typesChanged = types.join(',') != (previous.propertyType ?? const []).join(',');
    final pages = Map<PageType, UnifiedFilterModel>.of(state.pages);
    pages[page] = filters.copyWith(purpose: purpose, propertyType: types);
    for (final other in PageType.values) {
      if (other == page) continue;
      pages[other] = pages[other]!.copyWith(
        purpose: purposeChanged ? purpose : null,
        propertyType: typesChanged ? types : null,
      );
    }
    state = PropertyFiltersState(pages, save: const AsyncLoading());
    return _persist();
  }

  Future<bool> search(PageType page, String text) {
    if (page == PageType.discover) return Future.value(true);
    return update(page, state.forPage(page).copyWith(searchQuery: text));
  }

  Future<bool> reset(PageType page) => update(page, UnifiedFilterModel.initial());

  Future<bool> resetAll() {
    state = PropertyFiltersState({
      for (final page in PageType.values) page: UnifiedFilterModel.initial(),
    }, save: const AsyncLoading());
    return _persist();
  }

  Future<bool> retrySave() {
    state = PropertyFiltersState(state.pages, save: const AsyncLoading());
    return _persist();
  }

  Future<bool> _persist() {
    final database = ref.read(appDatabaseProvider);
    final snapshot = state.pages;
    final revision = ++_revision;
    final result = Completer<bool>();
    _writes = _writes.then((_) async {
      try {
        await database.writePreferences({
          'property_filters_v1': {
            for (final entry in snapshot.entries) entry.key.name: entry.value.toJson(),
          },
          'global_purpose': snapshot[PageType.discover]!.purpose,
          'global_property_types': snapshot[PageType.discover]!.propertyType,
        });
        if (ref.mounted && revision == _revision) state = PropertyFiltersState(snapshot);
        result.complete(true);
      } catch (error, stack) {
        if (ref.mounted && revision == _revision) {
          state = PropertyFiltersState(snapshot, save: AsyncError(error, stack));
        }
        result.complete(false);
      }
    });
    return result.future;
  }
}
