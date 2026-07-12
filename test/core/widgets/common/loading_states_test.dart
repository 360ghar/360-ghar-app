import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/translations/app_translations.dart';
import 'package:ghar360/core/widgets/common/loading_states.dart';
import 'package:shimmer/shimmer.dart';

import '../../../helpers/getx_test_binding.dart';

void main() {
  setUp(() {
    GetxTestBinding.init();
    Get.locale = const Locale('en', 'US');
    Get.addTranslations(AppTranslations().keys);
  });
  tearDown(() => GetxTestBinding.reset());

  Future<void> pumpWidget(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        fallbackLocale: const Locale('en', 'US'),
        home: Scaffold(body: child),
      ),
    );
    // Allow GetX translations to initialize.
    await tester.pump();
  }

  testWidgets('propertyCardSkeleton renders Card with Shimmer', (tester) async {
    await pumpWidget(tester, LoadingStates.propertyCardSkeleton());

    expect(find.byType(Card), findsOneWidget);
    expect(find.byType(Shimmer), findsOneWidget);
    // Multiple Containers are used as skeleton blocks.
    expect(find.byType(Container), findsWidgets);
  });

  testWidgets('propertyListSkeleton renders a ListView with card skeletons',
      (tester) async {
    await pumpWidget(
      tester,
      LoadingStates.propertyListSkeleton(itemCount: 3),
    );

    expect(find.byType(ListView), findsOneWidget);
    // ListView is lazy — at least one Card is rendered (visible ones only).
    expect(find.byType(Card), findsWidgets);
    expect(find.byType(Shimmer), findsWidgets);
  });

  testWidgets('propertyGridSkeleton renders a GridView with Shimmer',
      (tester) async {
    await pumpWidget(
      tester,
      LoadingStates.propertyGridSkeleton(itemCount: 4),
    );

    expect(find.byType(GridView), findsOneWidget);
    expect(find.byType(Shimmer), findsWidgets);
    expect(find.byType(Card), findsWidgets);
  });

  testWidgets('responsiveGridSkeleton renders a GridView with Shimmer',
      (tester) async {
    await pumpWidget(
      tester,
      LoadingStates.responsiveGridSkeleton(itemCount: 2),
    );

    expect(find.byType(GridView), findsOneWidget);
    expect(find.byType(Shimmer), findsWidgets);
  });

  testWidgets('propertyDetailsSkeleton renders a ListView with Shimmer',
      (tester) async {
    await pumpWidget(tester, LoadingStates.propertyDetailsSkeleton());

    expect(find.byType(Shimmer), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
  });

  testWidgets('swipeCardSkeleton renders a Shimmer container', (tester) async {
    await pumpWidget(tester, LoadingStates.swipeCardSkeleton());

    expect(find.byType(Shimmer), findsOneWidget);
    expect(find.byType(Container), findsWidgets);
  });

  testWidgets('mapLoadingOverlay renders a progress indicator and text',
      (tester) async {
    await pumpWidget(
      tester,
      Builder(builder: (context) => LoadingStates.mapLoadingOverlay(context)),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading properties...'), findsOneWidget);
  });

  testWidgets('progressiveLoadingIndicator renders a linear progress and text',
      (tester) async {
    await pumpWidget(
      tester,
      Builder(
        builder: (context) =>
            LoadingStates.progressiveLoadingIndicator(current: 2, total: 5),
      ),
    );

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    // The translation uses {current}/{total} placeholders but GetX trParams
    // replaces @key, so the raw translation text is shown.
    expect(find.textContaining('Loading page'), findsOneWidget);
  });

  testWidgets('pullToRefreshIndicator renders a progress indicator',
      (tester) async {
    await pumpWidget(
      tester,
      Builder(builder: (context) => LoadingStates.pullToRefreshIndicator(context)),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('loadMoreIndicator renders a progress indicator', (tester) async {
    await pumpWidget(tester, LoadingStates.loadMoreIndicator());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('inlineLoading renders a sized progress indicator', (tester) async {
    await pumpWidget(tester, LoadingStates.inlineLoading(size: 20));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('textSkeleton renders a Shimmer with a Container', (tester) async {
    await pumpWidget(tester, LoadingStates.textSkeleton(width: 120));

    expect(find.byType(Shimmer), findsOneWidget);
    expect(find.byType(Container), findsOneWidget);
  });

  testWidgets('fullScreenLoading renders a progress indicator and optional message',
      (tester) async {
    await pumpWidget(
      tester,
      LoadingStates.fullScreenLoading(message: 'Please wait'),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Please wait'), findsOneWidget);
  });

  testWidgets('searchLoading renders a progress indicator and text', (tester) async {
    await pumpWidget(tester, LoadingStates.searchLoading());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Searching properties...'), findsOneWidget);
  });

  testWidgets('locationLoading renders a progress indicator and text', (tester) async {
    await pumpWidget(tester, LoadingStates.locationLoading());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Getting your location...'), findsOneWidget);
  });
}
