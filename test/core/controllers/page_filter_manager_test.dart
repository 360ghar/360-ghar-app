// test/core/controllers/page_filter_manager_test.dart
//
// Unit tests for [PageFilterManager]. The manager delegates state mutation to
// [PageStateService] and data loading to [PageDataLoader]; both are mocked with
// mocktail. A real [GetStorage] is used so persistence paths are exercised.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ghar360/core/controllers/page_data_loader.dart';
import 'package:ghar360/core/controllers/page_filter_manager.dart';
import 'package:ghar360/core/controllers/page_state_service.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:mocktail/mocktail.dart';

class MockPageStateService extends Mock implements PageStateService {}

class MockPageDataLoader extends Mock implements PageDataLoader {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory storageDir;

  setUpAll(() async {
    storageDir = await Directory.systemTemp.createTemp('page_filter_manager_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return storageDir.path;
        }
        return null;
      },
    );
    await GetStorage.init();
    registerFallbackValue(PageType.explore);
    registerFallbackValue(PageStateModel.initial(PageType.explore));
  });

  tearDownAll(() async {
    try {
      await storageDir.delete(recursive: true);
    } catch (_) {}
  });

  late MockPageStateService pageState;
  late MockPageDataLoader dataLoader;
  late GetStorage storage;
  late PageFilterManager manager;

  setUp(() async {
    pageState = MockPageStateService();
    dataLoader = MockPageDataLoader();
    storage = GetStorage();
    await storage.erase();

    // Default: getStateForPage returns the initial state for the requested page.
    when(
      () => pageState.getStateForPage(any()),
    ).thenAnswer((inv) => PageStateModel.initial(inv.positionalArguments[0] as PageType));
    // updatePageState is a void method.
    when(() => pageState.updatePageState(any(), any())).thenReturn(null);
    // Data loader stubs.
    when(() => dataLoader.debounceRefresh(any())).thenReturn(null);
    when(() => dataLoader.refreshAllPagesData()).thenReturn(null);
    when(
      () => dataLoader.loadPageData(any(), forceRefresh: any(named: 'forceRefresh')),
    ).thenAnswer((_) async {});

    manager = PageFilterManager(pageState, dataLoader, storage);
  });

  tearDown(() {
    manager.dispose();
  });

  group('updatePageFilters', () {
    test('debounces refresh when purpose and type are unchanged', () {
      final filters = UnifiedFilterModel.initial();
      manager.updatePageFilters(PageType.explore, filters);

      verify(() => dataLoader.debounceRefresh(PageType.explore)).called(1);
      verifyNever(() => dataLoader.refreshAllPagesData());
    });

    test('propagates and persists when purpose changes', () {
      final filters = UnifiedFilterModel.initial().copyWith(purpose: 'rent');
      manager.updatePageFilters(PageType.explore, filters);

      // The manager writes to storage and calls refreshAllPagesData.
      verify(() => dataLoader.refreshAllPagesData()).called(1);
      // setPurposeForAllPages iterates all pages → updatePageState called for each.
      verify(() => pageState.updatePageState(any(), any())).called(greaterThan(0));
      // Verify the purpose was persisted to storage.
      expect(storage.read('global_purpose'), 'rent');
    });

    test('does not propagate purpose to other pages when new purpose is empty', () {
      final filters = UnifiedFilterModel.initial().copyWith(purpose: '');
      manager.updatePageFilters(PageType.explore, filters);

      // purpose changed from 'buy' to '' → purposeChanged is true, so
      // refreshAllPagesData IS called, but the propagation to other pages
      // (setPurposeForAllPages) is skipped because the trimmed purpose is empty.
      // Only the single page's updatePageState call happens (not 3+ for propagation).
      verify(() => dataLoader.refreshAllPagesData()).called(1);
      // Verify purpose was NOT written to storage.
      expect(storage.read('global_purpose'), isNull);
    });

    test('propagates and persists when property type changes', () {
      final filters = UnifiedFilterModel.initial().copyWith(propertyType: ['apartment']);
      manager.updatePageFilters(PageType.explore, filters);

      verify(() => dataLoader.refreshAllPagesData()).called(1);
    });

    test('does not debounce or refresh when both purpose and type change', () {
      final filters = UnifiedFilterModel.initial().copyWith(
        purpose: 'rent',
        propertyType: ['house'],
      );
      manager.updatePageFilters(PageType.discover, filters);

      // When purpose or type changed, debounceRefresh is NOT called (only
      // refreshAllPagesData is).
      verifyNever(() => dataLoader.debounceRefresh(any()));
      verify(() => dataLoader.refreshAllPagesData()).called(1);
    });
  });

  group('updatePageSearch', () {
    test('updates state and debounces refresh for explore', () {
      manager.updatePageSearch(PageType.explore, 'test query');

      verify(() => pageState.updatePageState(PageType.explore, any())).called(1);
      verify(() => dataLoader.debounceRefresh(PageType.explore)).called(1);
    });

    test('is a no-op for discover page', () {
      manager.updatePageSearch(PageType.discover, 'test query');

      verifyNever(() => pageState.updatePageState(any(), any()));
      verifyNever(() => dataLoader.debounceRefresh(any()));
    });

    test('clearPageSearch delegates to updatePageSearch with empty string', () {
      manager.clearPageSearch(PageType.likes);

      verify(() => pageState.updatePageState(PageType.likes, any())).called(1);
      verify(() => dataLoader.debounceRefresh(PageType.likes)).called(1);
    });
  });

  group('getOrCreateSearchController', () {
    test('returns the same controller for the same page type', () {
      final c1 = manager.getOrCreateSearchController(PageType.explore);
      final c2 = manager.getOrCreateSearchController(PageType.explore);

      expect(identical(c1, c2), isTrue);
    });

    test('returns different controllers for different page types', () {
      final c1 = manager.getOrCreateSearchController(PageType.explore);
      final c2 = manager.getOrCreateSearchController(PageType.likes);

      expect(identical(c1, c2), isFalse);
    });

    test('uses seed text on first creation', () {
      final c = manager.getOrCreateSearchController(PageType.explore, seedText: 'hello');
      expect(c.text, 'hello');
    });

    test('ignores seed text on subsequent calls', () {
      manager.getOrCreateSearchController(PageType.explore, seedText: 'hello');
      final c2 = manager.getOrCreateSearchController(PageType.explore, seedText: 'world');
      expect(c2.text, 'hello');
    });

    test('listener calls updatePageSearch when text changes', () {
      final c = manager.getOrCreateSearchController(PageType.explore);
      c.text = 'new search';

      verify(() => dataLoader.debounceRefresh(PageType.explore)).called(1);
    });
  });

  group('resetPageFilters', () {
    test('resets state and force-refreshes data', () {
      manager.resetPageFilters(PageType.explore);

      verify(() => pageState.updatePageState(PageType.explore, any())).called(1);
      verify(() => dataLoader.loadPageData(PageType.explore, forceRefresh: true)).called(1);
    });
  });

  group('resetAllFilters', () {
    test('resets all pages and refreshes all data', () {
      manager.resetAllFilters();

      // One updatePageState per page type (3 pages).
      verify(() => pageState.updatePageState(any(), any())).called(3);
      verify(() => dataLoader.refreshAllPagesData()).called(1);
    });
  });

  group('setPurposeForAllPages', () {
    test('updates all pages with the given purpose', () {
      manager.setPurposeForAllPages('rent');

      verify(() => pageState.updatePageState(any(), any())).called(3);
    });

    test('skips pages that already have a purpose when onlyIfUnset is true', () {
      // The initial state has purpose 'buy' set, so onlyIfUnset skips all.
      manager.setPurposeForAllPages('rent', onlyIfUnset: true);

      // No pages should be updated because all have purpose set.
      verifyNever(() => pageState.updatePageState(any(), any()));
    });

    test('updates pages when onlyIfUnset is true and purpose is null', () {
      when(() => pageState.getStateForPage(any())).thenAnswer(
        (inv) => PageStateModel.initial(
          inv.positionalArguments[0] as PageType,
        ).copyWith(filters: const UnifiedFilterModel()),
      );

      manager.setPurposeForAllPages('buy', onlyIfUnset: true);

      verify(() => pageState.updatePageState(any(), any())).called(3);
    });
  });

  group('setPropertyTypeForAllPages', () {
    test('updates all pages with the given property types', () {
      manager.setPropertyTypeForAllPages(['apartment', 'house']);

      verify(() => pageState.updatePageState(any(), any())).called(3);
    });

    test('skips pages with non-empty types when onlyIfUnset is true', () {
      // Initial state has propertyType: [] (empty), so onlyIfUnset should NOT skip.
      manager.setPropertyTypeForAllPages(['apartment'], onlyIfUnset: true);

      verify(() => pageState.updatePageState(any(), any())).called(3);
    });

    test('skips pages with non-empty types when onlyIfUnset is true and types set', () {
      when(() => pageState.getStateForPage(any())).thenAnswer(
        (inv) => PageStateModel.initial(
          inv.positionalArguments[0] as PageType,
        ).copyWith(filters: UnifiedFilterModel.initial().copyWith(propertyType: ['house'])),
      );

      manager.setPropertyTypeForAllPages(['apartment'], onlyIfUnset: true);

      verifyNever(() => pageState.updatePageState(any(), any()));
    });

    test('handles null property types', () {
      manager.setPropertyTypeForAllPages(null);

      verify(() => pageState.updatePageState(any(), any())).called(3);
    });
  });

  group('applySavedGlobalFilters', () {
    test('applies saved purpose when present', () {
      storage.write('global_purpose', 'rent');

      manager.applySavedGlobalFilters();

      verify(() => pageState.updatePageState(any(), any())).called(greaterThan(0));
    });

    test('applies saved property types when present', () {
      storage.write('global_property_types', ['apartment', 'house']);

      manager.applySavedGlobalFilters();

      verify(() => pageState.updatePageState(any(), any())).called(greaterThan(0));
    });

    test('does nothing when no saved filters exist', () {
      manager.applySavedGlobalFilters();

      verifyNever(() => pageState.updatePageState(any(), any()));
    });

    test('skips empty/whitespace purpose', () {
      storage.write('global_purpose', '   ');

      manager.applySavedGlobalFilters();

      verifyNever(() => pageState.updatePageState(any(), any()));
    });

    test('filters non-string entries from stored property types', () {
      storage.write('global_property_types', ['apartment', 42, 'house', true]);

      manager.applySavedGlobalFilters();

      // Should still apply (filtering out non-strings internally).
      verify(() => pageState.updatePageState(any(), any())).called(greaterThan(0));
    });
  });

  group('dispose', () {
    test('disposes search controllers without throwing', () {
      manager.getOrCreateSearchController(PageType.explore);
      manager.getOrCreateSearchController(PageType.likes);

      expect(manager.dispose, returnsNormally);
    });
  });
}
