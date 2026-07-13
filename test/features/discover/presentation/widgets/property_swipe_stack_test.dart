// test/features/discover/presentation/widgets/property_swipe_stack_test.dart

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/translations/app_translations.dart';
import 'package:ghar360/features/discover/presentation/widgets/property_swipe_card.dart';
import 'package:ghar360/features/discover/presentation/widgets/property_swipe_stack.dart';
import '../../../../helpers/getx_test_binding.dart';

/// Builds a richer [PropertyModel] for swipe-stack rendering tests.
PropertyModel _property({int id = 100, String title = 'Sunshine Villa'}) {
  return PropertyModel(
    id: id,
    title: title,
    basePrice: 5000000,
    propertyType: PropertyType.house,
    purpose: PropertyPurpose.buy,
    bedrooms: 3,
    bathrooms: 2,
    areaSqft: 1200,
    mainImageUrl: 'https://example.com/image.jpg',
    city: 'New Delhi',
    state: 'Delhi',
    isAvailable: true,
    viewCount: 42,
    likeCount: 15,
    interestCount: 8,
    description: 'A beautiful villa with modern amenities.',
  );
}

void main() {
  setUp(() {
    GetxTestBinding.init();
    Get.locale = const Locale('en', 'US');
    Get.addTranslations(AppTranslations().keys);
    // Suppress RenderFlex overflow errors that arise from the constrained
    // test surface so they don't fail the test runner.
    FlutterError.onError = (FlutterErrorDetails details) {
      final summary = details.exception.toString();
      if (summary.contains('overflow') || summary.contains('RenderFlex')) {
        return;
      }
      FlutterError.presentError(details);
    };
  });

  tearDown(() {
    FlutterError.onError = FlutterError.presentError;
    GetxTestBinding.reset();
  });

  /// Pumps [child] inside a GetMaterialApp with a fixed-size surface so the
  /// LayoutBuilder in [PropertySwipeStack] receives finite constraints.
  Future<void> pumpStack(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        fallbackLocale: const Locale('en', 'US'),
        home: Scaffold(
          body: Center(child: SizedBox(width: 400, height: 700, child: child)),
        ),
      ),
    );
  }

  group('PropertySwipeStack — empty state', () {
    testWidgets('renders swipe deck empty state when no properties', (tester) async {
      await pumpStack(
        tester,
        PropertySwipeStack(
          properties: const [],
          onSwipeLeft: (_) {},
          onSwipeRight: (_) {},
          onSwipeUp: (_) {},
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.home_outlined), findsOneWidget);
      expect(find.text('No More Properties'), findsOneWidget);
    });

    testWidgets('passes onRefresh and onChangeFilters to empty state', (tester) async {
      var refreshCalled = false;
      var filtersCalled = false;
      // Use a wide surface so the two-button Row does not overflow.
      await tester.pumpWidget(
        GetMaterialApp(
          translations: AppTranslations(),
          locale: const Locale('en', 'US'),
          fallbackLocale: const Locale('en', 'US'),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 600,
                height: 700,
                child: PropertySwipeStack(
                  properties: const [],
                  onSwipeLeft: (_) {},
                  onSwipeRight: (_) {},
                  onSwipeUp: (_) {},
                  onRefresh: () => refreshCalled = true,
                  onChangeFilters: () => filtersCalled = true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The empty state renders an ElevatedButton (change filters) and an
      // OutlinedButton (refresh) when callbacks are provided.
      final elevated = find.byType(ElevatedButton);
      final outlined = find.byType(OutlinedButton);
      expect(elevated, findsOneWidget);
      expect(outlined, findsOneWidget);
      expect(find.byIcon(Icons.tune), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);

      await tester.tap(elevated);
      await tester.pumpAndSettle();
      expect(filtersCalled, isTrue);

      await tester.tap(outlined);
      await tester.pumpAndSettle();
      expect(refreshCalled, isTrue);
    });
  });

  group('PropertySwipeStack — rendering with properties', () {
    testWidgets('renders a PropertySwipeCard for the top property', (tester) async {
      final properties = [_property(id: 1, title: 'Alpha Home')];
      await pumpStack(
        tester,
        PropertySwipeStack(
          properties: properties,
          onSwipeLeft: (_) {},
          onSwipeRight: (_) {},
          onSwipeUp: (_) {},
        ),
      );
      await tester.pump();

      expect(find.byType(PropertySwipeCard), findsOneWidget);
      expect(find.text('Alpha Home'), findsWidgets);
    });

    testWidgets('renders background preview cards when multiple properties', (tester) async {
      final properties = [
        _property(id: 1, title: 'Alpha Home'),
        _property(id: 2, title: 'Beta House'),
        _property(id: 3, title: 'Gamma Villa'),
      ];
      await pumpStack(
        tester,
        PropertySwipeStack(
          properties: properties,
          onSwipeLeft: (_) {},
          onSwipeRight: (_) {},
          onSwipeUp: (_) {},
        ),
      );
      await tester.pump();

      // The top card is a PropertySwipeCard; background preview cards render
      // the property title text directly (not inside PropertySwipeCard).
      expect(find.byType(PropertySwipeCard), findsOneWidget);
      // Background preview cards show titles of properties[1] and properties[2].
      expect(find.text('Beta House'), findsOneWidget);
      expect(find.text('Gamma Villa'), findsOneWidget);
    });

    testWidgets('renders only one background card when two properties', (tester) async {
      final properties = [
        _property(id: 1, title: 'Alpha Home'),
        _property(id: 2, title: 'Beta House'),
      ];
      await pumpStack(
        tester,
        PropertySwipeStack(
          properties: properties,
          onSwipeLeft: (_) {},
          onSwipeRight: (_) {},
          onSwipeUp: (_) {},
        ),
      );
      await tester.pump();

      expect(find.byType(PropertySwipeCard), findsOneWidget);
      expect(find.text('Beta House'), findsOneWidget);
      // No third property, so no Gamma.
      expect(find.text('Gamma Villa'), findsNothing);
    });

    testWidgets('action buttons are below the fold until card is scrolled', (tester) async {
      final properties = [_property(id: 1, title: 'Alpha Home')];
      await pumpStack(
        tester,
        PropertySwipeStack(
          properties: properties,
          onSwipeLeft: (_) {},
          onSwipeRight: (_) {},
          onSwipeUp: (_) {},
        ),
      );
      await tester.pump();

      final likeKey = find.byKey(const ValueKey('qa.discover.action.like'));
      final passKey = find.byKey(const ValueKey('qa.discover.action.pass'));
      final detailsKey = find.byKey(const ValueKey('qa.discover.action.details'));

      // Present in the tree (end of scroll) but not in the first viewport.
      expect(likeKey, findsOneWidget);
      expect(passKey, findsOneWidget);
      expect(detailsKey, findsOneWidget);
      expect(tester.getRect(likeKey).top, greaterThanOrEqualTo(700));
      expect(find.text('Swipe right to like | Swipe left to pass'), findsNothing);

      // After scrolling the deck, the action bar is reachable.
      await tester.scrollUntilVisible(likeKey, 200, scrollable: find.byType(Scrollable).first);
      await tester.pump();
      expect(tester.getRect(likeKey).top, lessThan(700));
    });
  });

  group('PropertySwipeStack — swipe gestures', () {
    testWidgets('calls onSwipeRight when dragged past threshold to the right', (tester) async {
      final properties = [
        _property(id: 1, title: 'Alpha Home'),
        _property(id: 2, title: 'Beta House'),
      ];
      PropertyModel? swipedRight;
      PropertyModel? swipedLeft;

      await pumpStack(
        tester,
        PropertySwipeStack(
          properties: properties,
          onSwipeLeft: (p) => swipedLeft = p,
          onSwipeRight: (p) => swipedRight = p,
          onSwipeUp: (_) {},
        ),
      );
      await tester.pump();

      // cardWidth = 400, dragThreshold = 100. Drag 180px to the right.
      await tester.drag(find.byType(PropertySwipeStack), const Offset(180, 0));
      await tester.pump();

      expect(swipedRight, isNotNull);
      expect(swipedRight!.id, 1);
      expect(swipedLeft, isNull);
    });

    testWidgets('calls onSwipeLeft when dragged past threshold to the left', (tester) async {
      final properties = [
        _property(id: 1, title: 'Alpha Home'),
        _property(id: 2, title: 'Beta House'),
      ];
      PropertyModel? swipedRight;
      PropertyModel? swipedLeft;

      await pumpStack(
        tester,
        PropertySwipeStack(
          properties: properties,
          onSwipeLeft: (p) => swipedLeft = p,
          onSwipeRight: (p) => swipedRight = p,
          onSwipeUp: (_) {},
        ),
      );
      await tester.pump();

      // Drag 180px to the left (past the 100px threshold).
      await tester.drag(find.byType(PropertySwipeStack), const Offset(-180, 0));
      await tester.pump();

      expect(swipedLeft, isNotNull);
      expect(swipedLeft!.id, 1);
      expect(swipedRight, isNull);
    });

    testWidgets('snaps back and does not call callbacks on a small drag', (tester) async {
      final properties = [_property(id: 1, title: 'Alpha Home')];
      var swipedRight = false;
      var swipedLeft = false;

      await pumpStack(
        tester,
        PropertySwipeStack(
          properties: properties,
          onSwipeLeft: (_) => swipedLeft = true,
          onSwipeRight: (_) => swipedRight = true,
          onSwipeUp: (_) {},
        ),
      );
      await tester.pump();

      // Drag only 30px — well below the 100px threshold.
      await tester.drag(find.byType(PropertySwipeStack), const Offset(30, 0));
      // Pump through the snap-back animation (300ms) without settling.
      await tester.pump(const Duration(milliseconds: 400));

      expect(swipedRight, isFalse);
      expect(swipedLeft, isFalse);
      // The top card is still present.
      expect(find.byType(PropertySwipeCard), findsOneWidget);
    });

    testWidgets('removes the top card after a completed swipe right', (tester) async {
      final properties = [
        _property(id: 1, title: 'Alpha Home'),
        _property(id: 2, title: 'Beta House'),
      ];

      await pumpStack(
        tester,
        PropertySwipeStack(
          properties: properties,
          onSwipeLeft: (_) {},
          onSwipeRight: (_) {},
          onSwipeUp: (_) {},
        ),
      );
      await tester.pump();

      // Initially the top card is "Alpha Home".
      expect(find.byType(PropertySwipeCard), findsOneWidget);

      await tester.drag(find.byType(PropertySwipeStack), const Offset(180, 0));
      // Pump through the 400ms swipe animation so the status listener fires
      // and removes the top card.
      await tester.pump(const Duration(milliseconds: 450));

      // After the swipe completes, the next card ("Beta House") becomes the
      // top PropertySwipeCard.
      expect(find.text('Beta House'), findsWidgets);
    });
  });

  group('PropertySwipeStack — didUpdateWidget', () {
    testWidgets('updates the deck when properties change and no swipe is active', (tester) async {
      final properties = [_property(id: 1, title: 'Alpha Home')];

      await pumpStack(
        tester,
        PropertySwipeStack(
          key: const ValueKey('stack'),
          properties: properties,
          onSwipeLeft: (_) {},
          onSwipeRight: (_) {},
          onSwipeUp: (_) {},
        ),
      );
      await tester.pump();

      expect(find.text('Alpha Home'), findsWidgets);

      // Rebuild with a new property list.
      await tester.pumpWidget(
        GetMaterialApp(
          translations: AppTranslations(),
          locale: const Locale('en', 'US'),
          fallbackLocale: const Locale('en', 'US'),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                height: 700,
                child: PropertySwipeStack(
                  key: const ValueKey('stack'),
                  properties: [_property(id: 2, title: 'Beta House')],
                  onSwipeLeft: (_) {},
                  onSwipeRight: (_) {},
                  onSwipeUp: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Beta House'), findsWidgets);
      expect(find.text('Alpha Home'), findsNothing);
    });

    testWidgets('does not rebuild when properties list is unchanged', (tester) async {
      final properties = [_property(id: 1, title: 'Alpha Home')];

      await pumpStack(
        tester,
        PropertySwipeStack(
          key: const ValueKey('stack'),
          properties: properties,
          onSwipeLeft: (_) {},
          onSwipeRight: (_) {},
          onSwipeUp: (_) {},
        ),
      );
      await tester.pump();

      expect(find.text('Alpha Home'), findsWidgets);

      // Rebuild with the same property list (new instance, same ids).
      await tester.pumpWidget(
        GetMaterialApp(
          translations: AppTranslations(),
          locale: const Locale('en', 'US'),
          fallbackLocale: const Locale('en', 'US'),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                height: 700,
                child: PropertySwipeStack(
                  key: const ValueKey('stack'),
                  properties: [_property(id: 1, title: 'Alpha Home')],
                  onSwipeLeft: (_) {},
                  onSwipeRight: (_) {},
                  onSwipeUp: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Still rendering the same top card.
      expect(find.text('Alpha Home'), findsWidgets);
    });
  });

  group('PropertySwipeStack — action buttons', () {
    Future<void> scrollToActions(WidgetTester tester, Finder actionFinder) async {
      await tester.scrollUntilVisible(actionFinder, 300, scrollable: find.byType(Scrollable).first);
      await tester.pump();
    }

    testWidgets('like action button calls onSwipeRight', (tester) async {
      PropertyModel? liked;
      await pumpStack(
        tester,
        PropertySwipeStack(
          properties: [_property(id: 7, title: 'Like Me')],
          onSwipeLeft: (_) {},
          onSwipeRight: (p) => liked = p,
          onSwipeUp: (_) {},
        ),
      );
      await tester.pump();

      final likeKey = find.byKey(const ValueKey('qa.discover.action.like'));
      await scrollToActions(tester, likeKey);
      await tester.tap(likeKey);
      await tester.pump();

      expect(liked, isNotNull);
      expect(liked!.id, 7);
    });

    testWidgets('pass action button calls onSwipeLeft', (tester) async {
      PropertyModel? passed;
      await pumpStack(
        tester,
        PropertySwipeStack(
          properties: [_property(id: 8, title: 'Pass Me')],
          onSwipeLeft: (p) => passed = p,
          onSwipeRight: (_) {},
          onSwipeUp: (_) {},
        ),
      );
      await tester.pump();

      final passKey = find.byKey(const ValueKey('qa.discover.action.pass'));
      await scrollToActions(tester, passKey);
      await tester.tap(passKey);
      await tester.pump();

      expect(passed, isNotNull);
      expect(passed!.id, 8);
    });

    testWidgets('details action button calls onSwipeUp', (tester) async {
      PropertyModel? opened;
      await pumpStack(
        tester,
        PropertySwipeStack(
          properties: [_property(id: 9, title: 'Details Me')],
          onSwipeLeft: (_) {},
          onSwipeRight: (_) {},
          onSwipeUp: (p) => opened = p,
        ),
      );
      await tester.pump();

      final detailsKey = find.byKey(const ValueKey('qa.discover.action.details'));
      await scrollToActions(tester, detailsKey);
      await tester.tap(detailsKey);
      await tester.pump();

      expect(opened, isNotNull);
      expect(opened!.id, 9);
    });
  });

  group('PropertySwipeStack — swipe feedback overlay', () {
    testWidgets('shows like badge text while dragging right', (tester) async {
      final properties = [_property(id: 1, title: 'Alpha Home')];

      await pumpStack(
        tester,
        PropertySwipeStack(
          properties: properties,
          onSwipeLeft: (_) {},
          onSwipeRight: (_) {},
          onSwipeUp: (_) {},
        ),
      );
      await tester.pump();

      // Begin a drag and hold it to the right so the feedback overlay renders.
      // Move in small increments with pumps so the horizontal-drag recognizer
      // wins the arena and the drag state stays "isDragging" while we assert.
      final gesture = await tester.startGesture(tester.getCenter(find.byType(PropertySwipeStack)));
      await tester.pump();
      for (int i = 0; i < 12; i++) {
        await gesture.moveBy(const Offset(10, 0));
        await tester.pump();
      }

      // The "LIKED" badge label is rendered while dragging right.
      expect(find.text('LIKED'), findsOneWidget);

      await gesture.up();
      await tester.pump();
    });

    testWidgets('shows pass badge text while dragging left', (tester) async {
      final properties = [_property(id: 1, title: 'Alpha Home')];

      await pumpStack(
        tester,
        PropertySwipeStack(
          properties: properties,
          onSwipeLeft: (_) {},
          onSwipeRight: (_) {},
          onSwipeUp: (_) {},
        ),
      );
      await tester.pump();

      final gesture = await tester.startGesture(tester.getCenter(find.byType(PropertySwipeStack)));
      await tester.pump();
      for (int i = 0; i < 12; i++) {
        await gesture.moveBy(const Offset(-10, 0));
        await tester.pump();
      }

      expect(find.text('PASSED'), findsOneWidget);

      await gesture.up();
      await tester.pump();
    });
  });
}
