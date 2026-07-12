import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/controllers/location_controller.dart';
import 'package:ghar360/core/controllers/page_state_service.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/translations/app_translations.dart';
import 'package:ghar360/core/widgets/common/unified_top_bar.dart';

import '../../../helpers/getx_test_binding.dart';
import '../../../helpers/mocks.dart';

/// A minimal fake [PageStateService] that exposes reactive page states and
/// the search/refresh helpers used by [UnifiedTopBar], without booting the
/// full persistence + data-loader stack.
class _FakePageStateService extends GetxServiceMock implements PageStateService {
  _FakePageStateService({PageType? initialPage}) {
    currentPageType.value = initialPage ?? PageType.discover;
  }

  @override
  final Rx<PageStateModel> exploreState = PageStateModel.initial(
    PageType.explore,
  ).copyWith(filters: const UnifiedFilterModel(purpose: 'buy')).obs;

  @override
  final Rx<PageStateModel> discoverState = PageStateModel.initial(
    PageType.discover,
  ).copyWith(filters: const UnifiedFilterModel(purpose: 'buy')).obs;

  @override
  final Rx<PageStateModel> likesState = PageStateModel.initial(
    PageType.likes,
  ).copyWith(filters: const UnifiedFilterModel(purpose: 'buy')).obs;

  @override
  final Rx<PageType> currentPageType = PageType.discover.obs;

  final RxBool _exploreRefreshing = false.obs;
  final RxBool _discoverRefreshing = false.obs;
  final RxBool _likesRefreshing = false.obs;

  @override
  PageStateModel getStateForPage(PageType pageType) {
    switch (pageType) {
      case PageType.explore:
        return exploreState.value;
      case PageType.discover:
        return discoverState.value;
      case PageType.likes:
        return likesState.value;
    }
  }

  @override
  void updatePageState(PageType pageType, PageStateModel newState) {
    switch (pageType) {
      case PageType.explore:
        exploreState.value = newState;
        break;
      case PageType.discover:
        discoverState.value = newState;
        break;
      case PageType.likes:
        likesState.value = newState;
        break;
    }
  }

  @override
  bool isSearchVisible(PageType pageType) {
    final state = getStateForPage(pageType);
    return state.getAdditionalData<bool>('searchVisible') ?? false;
  }

  @override
  void setSearchVisible(PageType pageType, bool visible) {
    final state = getStateForPage(pageType);
    updatePageState(pageType, state.updateAdditionalData('searchVisible', visible));
  }

  @override
  void toggleSearch(PageType pageType) {
    setSearchVisible(pageType, !isSearchVisible(pageType));
  }

  @override
  bool isPageRefreshing(PageType pageType) {
    switch (pageType) {
      case PageType.explore:
        return _exploreRefreshing.value;
      case PageType.discover:
        return _discoverRefreshing.value;
      case PageType.likes:
        return _likesRefreshing.value;
    }
  }

  @override
  void notifyPageRefreshing(PageType pageType, bool isRefreshing) {
    switch (pageType) {
      case PageType.explore:
        _exploreRefreshing.value = isRefreshing;
        break;
      case PageType.discover:
        _discoverRefreshing.value = isRefreshing;
        break;
      case PageType.likes:
        _likesRefreshing.value = isRefreshing;
        break;
    }
  }

  @override
  TextEditingController getOrCreateSearchController(PageType pageType, {String? seedText}) {
    return TextEditingController(text: seedText);
  }
}

void main() {
  late _FakePageStateService pageStateService;
  late MockLocationController locationController;

  setUp(() {
    GetxTestBinding.init();
    pageStateService = _FakePageStateService();
    locationController = MockLocationController();
    GetxTestBinding.bind()
      ..register<PageStateService>(pageStateService)
      ..register<LocationController>(locationController);
  });
  tearDown(() => GetxTestBinding.reset());

  Future<void> pumpWidget(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        fallbackLocale: const Locale('en', 'US'),
        home: Scaffold(appBar: child as PreferredSizeWidget, body: const SizedBox()),
      ),
    );
  }

  testWidgets('renders an AppBar with location selector and filter button', (tester) async {
    await pumpWidget(
      tester,
      UnifiedTopBar(pageType: PageType.discover, title: 'Test'),
    );

    expect(find.byType(UnifiedTopBar), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
    // Location selector is always present in the title row.
    expect(find.byIcon(Icons.location_on), findsOneWidget);
    // Filter button (tune icon) is always present.
    expect(find.byIcon(Icons.tune), findsOneWidget);
  });

  testWidgets('shows search toggle for explore page', (tester) async {
    await pumpWidget(
      tester,
      UnifiedTopBar(pageType: PageType.explore, title: 'Explore'),
    );

    // Explore supports search → search toggle icon is rendered.
    expect(find.byIcon(Icons.search), findsOneWidget);
  });

  testWidgets('does not show search toggle for discover page', (tester) async {
    await pumpWidget(
      tester,
      UnifiedTopBar(pageType: PageType.discover, title: 'Discover'),
    );

    // Discover does not support search → no search toggle icon.
    expect(find.byIcon(Icons.search), findsNothing);
    expect(find.byIcon(Icons.search_off), findsNothing);
  });

  testWidgets('tapping search toggle makes the search bar visible', (tester) async {
    await pumpWidget(
      tester,
      UnifiedTopBar(pageType: PageType.explore, title: 'Explore'),
    );

    // Initially no search input field.
    expect(find.byType(TextField), findsNothing);

    // Tap the search toggle.
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    // Now the search TextField is visible.
    expect(find.byType(TextField), findsOneWidget);
    expect(pageStateService.isSearchVisible(PageType.explore), isTrue);
  });

  testWidgets('shows refresh indicator when page is refreshing', (tester) async {
    await pumpWidget(
      tester,
      UnifiedTopBar(pageType: PageType.discover, title: 'Discover'),
    );

    // No progress indicator initially.
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // Mark the page as refreshing.
    pageStateService.notifyPageRefreshing(PageType.discover, true);
    await tester.pump();

    // Now a small CircularProgressIndicator is shown.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows filter badge count when active filters > 0', (tester) async {
    // Seed explore state with an active filter (purpose counts as active).
    pageStateService.exploreState.value = pageStateService.exploreState.value.copyWith(
      filters: const UnifiedFilterModel(purpose: 'buy', propertyType: ['house']),
    );

    await pumpWidget(
      tester,
      UnifiedTopBar(pageType: PageType.explore, title: 'Explore'),
    );

    // The filter badge text shows the count.
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('preferredSize is kToolbarHeight when search not visible', (tester) async {
    final topBar = UnifiedTopBar(pageType: PageType.discover, title: 'Discover');
    expect(topBar.preferredSize.height, kToolbarHeight);
  });

  testWidgets('preferredSize includes search bar height when search visible', (tester) async {
    pageStateService.setSearchVisible(PageType.explore, true);
    final topBar = UnifiedTopBar(pageType: PageType.explore, title: 'Explore');
    expect(topBar.preferredSize.height, kToolbarHeight + 52);
  });
}
