import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:ghar360/core/controllers/page_state_service.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/translations/app_translations.dart';
import 'package:ghar360/core/widgets/common/property_filter_widget.dart';
import '../../../helpers/getx_test_binding.dart';
import '../../../helpers/mocks.dart';

class _FakePageStateService extends GetxServiceMock implements PageStateService {
  @override
  final Rx<PageStateModel> discoverState = PageStateModel.initial(
    PageType.discover,
  ).copyWith(filters: const UnifiedFilterModel(purpose: 'buy')).obs;

  @override
  final Rx<PageStateModel> exploreState = PageStateModel.initial(
    PageType.explore,
  ).copyWith(filters: const UnifiedFilterModel(purpose: 'buy')).obs;

  @override
  final Rx<PageStateModel> likesState = PageStateModel.initial(
    PageType.likes,
  ).copyWith(filters: const UnifiedFilterModel(purpose: 'buy')).obs;

  @override
  final Rx<PageType> currentPageType = PageType.discover.obs;

  PageType? lastUpdatedPage;

  @override
  PageStateModel getStateForPage(PageType pageType) {
    switch (pageType) {
      case PageType.discover:
        return discoverState.value;
      case PageType.explore:
        return exploreState.value;
      case PageType.likes:
        return likesState.value;
    }
  }

  @override
  void updatePageFilters(PageType pageType, UnifiedFilterModel filters) {
    lastUpdatedPage = pageType;
    final state = getStateForPage(pageType).copyWith(filters: filters);
    switch (pageType) {
      case PageType.discover:
        discoverState.value = state;
        break;
      case PageType.explore:
        exploreState.value = state;
        break;
      case PageType.likes:
        likesState.value = state;
        break;
    }
  }
}

void main() {
  late _FakePageStateService pageStateService;

  setUp(() {
    GetxTestBinding.init();
    pageStateService = _FakePageStateService();
    GetxTestBinding.bind().register<PageStateService>(pageStateService);
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  testWidgets('applies filters to the page that opened the sheet, not the active tab', (
    tester,
  ) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        fallbackLocale: const Locale('en', 'US'),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showPropertyFilterBottomSheet(context, pageType: 'explore'),
              child: const Text('Open filters'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open filters'));
    await tester.pumpAndSettle();

    expect(find.text('Filter Properties'), findsOneWidget);

    await tester.tap(find.text('Rent').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Apply Filters'));
    await tester.pumpAndSettle();

    expect(pageStateService.lastUpdatedPage, PageType.explore);
    expect(pageStateService.exploreState.value.filters.purpose, 'rent');
    expect(pageStateService.discoverState.value.filters.purpose, 'buy');

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}
