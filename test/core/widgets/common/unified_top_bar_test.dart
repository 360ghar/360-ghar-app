import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/core/widgets/common/property_filter_widget.dart';
import 'package:ghar360/core/widgets/common/unified_top_bar.dart';
import 'package:ghar360/features/properties/application/property_filters.dart';
import 'package:ghar360/features/properties/application/property_queries.dart';
import '../../../helpers/explore_test_harness.dart';
import '../../../helpers/knife_finders.dart';
import '../../../helpers/provider_test_app.dart';

void main() {
  late ExploreTestHarness harness;
  setUp(() => harness = ExploreTestHarness());
  tearDown(() => harness.dispose());
  Future<void> pump(
    WidgetTester tester,
    UnifiedTopBar bar, {
    Locale locale = const Locale('en', 'US'),
    double scale = 1,
  }) async {
    await tester.pumpProviderApp(
      UncontrolledProviderScope(
        container: harness.container,
        child: Scaffold(appBar: bar, body: const SizedBox()),
      ),
      locale: locale,
      textScale: scale,
    );
    await tester.pump();
  }

  testWidgets('renders labelled location selector and filter button', (tester) async {
    var taps = 0;
    await pump(
      tester,
      UnifiedTopBar(pageType: PageType.discover, title: 'Discover', onFilterTap: () => taps++),
    );
    expect(find.byType(AppBar), findsOneWidget);
    expect(findKnife(KnifeIcon.pin), findsOneWidget);
    expect(findKnife(KnifeIcon.filter), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('qa.topbar.filter.discover')));
    expect(taps, 1);
  });
  testWidgets('Explore and Likes expose search directly; Discover omits it', (tester) async {
    for (final page in PageType.values) {
      await pump(tester, UnifiedTopBar(pageType: page, title: page.name));
      expect(find.byType(TextField), page == PageType.discover ? findsNothing : findsOneWidget);
    }
  });
  testWidgets('showSearch false removes input and uses custom bottom size', (tester) async {
    const bar = UnifiedTopBar(
      pageType: PageType.explore,
      title: 'Explore',
      showSearch: false,
      bottom: PreferredSize(preferredSize: Size.fromHeight(32), child: Text('Status')),
    );
    await pump(tester, bar);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Status'), findsOneWidget);
    expect(bar.preferredSize.height, kToolbarHeight + 32);
    // Explore's search is a slip over the map, not part of its bar.
    expect(const ExploreTopBar().preferredSize.height, kToolbarHeight);
    expect(const DiscoverTopBar().preferredSize.height, kToolbarHeight);
    await pump(tester, const ExploreTopBar());
    expect(find.byType(TextField), findsNothing);
    expect(find.byKey(const ValueKey('qa.topbar.filter.explore')), findsOneWidget);
  });
  testWidgets('retained refresh indicator observes only the current feed', (tester) async {
    await pump(tester, const ExploreTopBar());
    expect(find.byType(CircularProgressIndicator), findsNothing);
    harness.query.seed(
      PropertyPageState(phase: PropertyLoadPhase.refreshing, items: [exploreProperty(1)]),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    harness.query.seed(
      PropertyPageState(phase: PropertyLoadPhase.content, items: [exploreProperty(1)]),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
  testWidgets('active filter badge reflects provider state', (tester) async {
    await harness.container
        .read(propertyFiltersProvider.notifier)
        .update(
          PageType.explore,
          const UnifiedFilterModel(purpose: 'buy', propertyType: ['house']),
        );
    await pump(tester, const ExploreTopBar());
    expect(find.text('1'), findsOneWidget);
    expect(find.byTooltip('Filters (1)'), findsOneWidget);
  });
  testWidgets('search edits, submit and clear keep callbacks and page persistence', (tester) async {
    final changes = <String>[];
    var clears = 0;
    await pump(
      tester,
      UnifiedTopBar(
        pageType: PageType.likes,
        title: 'Likes',
        onSearchChanged: changes.add,
        onSearchClear: () => clears++,
      ),
    );
    await tester.enterText(find.byType(TextField), 'Gurugram');
    await tester.pump();
    expect(
      harness.container.read(propertyFiltersProvider).forPage(PageType.likes).searchQuery,
      'Gurugram',
    );
    expect(
      harness.container.read(propertyFiltersProvider).forPage(PageType.explore).searchQuery,
      isNull,
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus, isFalse);
    await tester.tap(find.byTooltip('Clear'));
    await tester.pump();
    expect(changes, ['Gurugram', '']);
    expect(clears, 1);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '');
  });
  testWidgets('mounted input reflects restored state and page switch without text leak', (
    tester,
  ) async {
    final filters = harness.container.read(propertyFiltersProvider.notifier);
    await filters.search(PageType.explore, 'Delhi');
    await filters.search(PageType.likes, 'Mumbai');
    await pump(tester, const UnifiedTopBar(pageType: PageType.explore, title: 'Explore'));
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Delhi');
    await filters.search(PageType.explore, 'Pune');
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Pune');
    await pump(tester, const UnifiedTopBar(pageType: PageType.likes, title: 'Likes'));
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Mumbai');
  });
  testWidgets('failed search persistence retains input with visible retry', (tester) async {
    harness.database.writeError = StorageFailure('disk full');
    await pump(tester, const UnifiedTopBar(pageType: PageType.explore, title: 'Explore'));
    await tester.enterText(find.byType(TextField), 'Delhi');
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Delhi');
    final retry = find.byKey(const ValueKey('qa.topbar.filters.retry'));
    expect(retry, findsOneWidget);
    harness.database.writeError = null;
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(retry, findsNothing);
    final stored = harness.database.preferences['property_filters_v1'] as Map;
    expect(stored['explore']['search_query'], 'Delhi');
  });
  testWidgets('Hindi 2x 320px keyboard and save error retain usable filter and search', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    harness.database.writeError = StorageFailure('disk full');
    await tester.pumpProviderApp(
      UncontrolledProviderScope(
        container: harness.container,
        child: Builder(
          builder: (context) => Scaffold(
            appBar: UnifiedTopBar(
              pageType: PageType.explore,
              title: 'Explore',
              onFilterTap: () => showPropertyFilterBottomSheet(context, pageType: PageType.explore),
            ),
            body: const SizedBox(),
          ),
        ),
      ),
      locale: const Locale('hi', 'IN'),
      textScale: 2,
    );
    await tester.enterText(find.byType(TextField), 'दिल्ली');
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    expect(find.byKey(const ValueKey('qa.topbar.filters.retry')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('qa.topbar.filter.explore')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus, isFalse);
    expect(find.byKey(const ValueKey('qa.filters.apply')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
