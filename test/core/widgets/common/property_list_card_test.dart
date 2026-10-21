import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/app_design_theme.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/design/paper/paper_chrome.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/core/widgets/common/property_list_card.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/knife_finders.dart';
import '../../../helpers/provider_test_app.dart';

PropertyModel _house({int id = 100}) => PropertyModel(
  id: id,
  title: 'Sunshine Villa',
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
);

const _studio = PropertyModel(
  id: 200,
  title: 'Cozy Studio',
  basePrice: 15000,
  propertyType: PropertyType.studio,
  purpose: PropertyPurpose.rent,
  monthlyRent: 15000,
  city: 'Mumbai',
  isAvailable: true,
  viewCount: 5,
  likeCount: 2,
  interestCount: 1,
);

void main() {
  late GoRouter router;
  Future<void> pump(
    WidgetTester tester,
    Widget card, {
    double width = 400,
    Size size = const Size(800, 600),
    bool dark = false,
    Locale locale = const Locale('en', 'US'),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(width: width, child: card),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.propertyDetails,
          builder: (_, _) => const Scaffold(body: Text('Property Details')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpProviderApp(
      Router.withConfig(config: router),
      theme: dark ? AppDesignTheme.dark() : AppDesignTheme.light(),
      locale: locale,
      textScale: scale,
    );
  }

  PropertyListCard card({
    PropertyModel? property,
    bool row = false,
    bool favourite = false,
    bool selected = false,
    bool updating = false,
    VoidCallback? onToggle,
    VoidCallback? onTap,
  }) => PropertyListCard(
    property: property ?? _house(),
    row: row,
    isFavourite: favourite,
    selected: selected,
    isUpdating: updating,
    onFavouriteToggle: onToggle ?? () {},
    onTap: onTap,
  );

  testWidgets('price in the display face, title, facts as text and the place', (tester) async {
    await pump(tester, card());
    final price = tester.widget<Text>(find.text('₹50 L'));
    final theme = Theme.of(tester.element(find.text('₹50 L')));
    expect(price.style, theme.textTheme.headlineSmall);
    expect(find.text('Sunshine Villa'), findsOneWidget);
    expect(find.text('House · 3 BHK · 2 Bath · 1,200 sq ft'), findsOneWidget);
    expect(find.text('New Delhi'), findsOneWidget);
  });

  testWidgets('has no chip, border, shadow or icon row for facts', (tester) async {
    for (final row in [false, true]) {
      await pump(tester, card(row: row, selected: true));
      expect(find.text('HOUSE'), findsNothing);
      expect(findKnife(KnifeIcon.bed), findsNothing);
      expect(findKnife(KnifeIcon.area), findsNothing);
      final boxes = tester.widgetList<DecoratedBox>(
        find.descendant(of: find.byType(PropertyListCard), matching: find.byType(DecoratedBox)),
      );
      for (final box in boxes) {
        final decoration = box.decoration;
        if (decoration is BoxDecoration) {
          expect(decoration.boxShadow, isNull);
          expect(decoration.border, isNull);
        }
        if (decoration is ShapeDecoration && decoration.shape is CutBorder) {
          expect((decoration.shape as CutBorder).shadows, isEmpty);
        }
      }
    }
  });

  testWidgets('rent shows the per-month suffix with the price', (tester) async {
    await pump(tester, card(property: _studio));
    expect(find.text('₹15,000 /mo'), findsOneWidget);
    expect(find.text('Studio'), findsOneWidget);
  });

  testWidgets('the heart is bare ink on the label in both shapes; saved is brick', (tester) async {
    const day = AppPalette(isDark: false);
    for (final row in [false, true]) {
      await pump(tester, card(row: row));
      final heart = tester.widget<PaperIcon>(findKnife(KnifeIcon.heart));
      expect(heart.color, day.favoriteInactive);
      expect(heart.shadows, isNull);
      await pump(tester, card(row: row, favourite: true));
      expect(tester.widget<PaperIcon>(findKnife(KnifeIcon.heartSolid)).color, day.favoriteActive);
    }
  });

  testWidgets('the photo is a hand-cut print that flies to the details gallery', (tester) async {
    for (final row in [false, true]) {
      await pump(tester, card(row: row));
      final hero = tester.widget<Hero>(find.byType(Hero));
      expect(hero.tag, propertyPhotoHeroTag(100));
      expect(hero.tag, 'property-photo-100');
      final clip = tester.widget<ClipPath>(
        find.descendant(of: find.byType(Hero), matching: find.byType(ClipPath)),
      );
      expect((clip.clipper! as ShapeBorderClipper).shape, isA<CutBorder>());
    }
    // The row print is 104 x 88.
    expect(tester.getSize(find.byType(Hero)), const Size(104, 88));
  });

  testWidgets('the tile label lies over the foot of the photo', (tester) async {
    await pump(tester, SizedBox(height: 240, child: card()));
    final photo = tester.getRect(find.byType(Hero));
    final price = tester.getRect(find.text('₹50 L'));
    // The label's cut edge covers the photo's last 18 px; the words sit below
    // the photo, clear of the cut.
    expect(price.top, greaterThanOrEqualTo(photo.bottom));
    final edge = find.descendant(
      of: find.byType(PropertyListCard),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint && widget.painter.runtimeType.toString() == '_LabelEdgePainter',
      ),
    );
    expect(
      tester.getRect(edge),
      Rect.fromLTRB(photo.left, photo.bottom - 18, photo.right, photo.bottom),
    );
  });

  testWidgets('heart toggles without opening the home; saved heart is solid', (tester) async {
    var toggled = 0;
    await pump(tester, card(row: true, onToggle: () => toggled++));
    await tester.tap(findKnife(KnifeIcon.heart));
    await tester.pumpAndSettle();
    expect(toggled, 1);
    expect(router.state.uri.path, '/');
    await pump(tester, card(favourite: true));
    expect(findKnife(KnifeIcon.heartSolid), findsOneWidget);
  });

  testWidgets('a pending like shows a spinner in place of the heart', (tester) async {
    await pump(tester, card(updating: true));
    expect(findKnife(KnifeIcon.heart), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('tap pushes the numeric details route with the summary', (tester) async {
    final property = _house();
    await pump(tester, card(property: property));
    await tester.tap(find.text('Sunshine Villa'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, AppRoutes.propertyDetails);
    expect(router.state.uri.queryParameters['id'], '100');
    expect(router.state.extra, same(property));
  });

  testWidgets('a selected tile turns its label into a mint slip', (tester) async {
    await pump(tester, card(selected: true));
    final slip = tester
        .widgetList<DecoratedBox>(
          find.descendant(of: find.byType(PropertyListCard), matching: find.byType(DecoratedBox)),
        )
        .map((box) => box.decoration)
        .whereType<ShapeDecoration>()
        .where((decoration) => decoration.color == const AppPalette(isDark: false).slip);
    expect(slip, hasLength(1));
    expect(
      tester.getSemantics(find.byType(PropertyListCard)),
      isSemantics(isSelected: true, isButton: true),
    );
  });

  testWidgets('onTap replaces navigation and selected lays a slip under the row', (tester) async {
    var opened = 0;
    await pump(tester, card(row: true, selected: true, onTap: () => opened++));
    await tester.tap(find.text('Sunshine Villa'));
    await tester.pumpAndSettle();
    expect(opened, 1);
    expect(router.state.uri.path, '/');
    final slip = tester
        .widgetList<DecoratedBox>(
          find.descendant(of: find.byType(PropertyListCard), matching: find.byType(DecoratedBox)),
        )
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .where((decoration) => decoration.color == const AppPalette(isDark: false).slip);
    expect(slip, isNotEmpty);
  });

  testWidgets('a home without rooms lists only its type', (tester) async {
    const plot = PropertyModel(
      id: 300,
      title: 'Plot Only',
      basePrice: 2000000,
      propertyType: PropertyType.plot,
      purpose: PropertyPurpose.buy,
      city: 'Pune',
      isAvailable: true,
      viewCount: 0,
      likeCount: 0,
      interestCount: 0,
    );
    await pump(tester, card(property: plot));
    expect(find.text('Plot'), findsOneWidget);
  });

  for (final row in [true, false]) {
    testWidgets('${row ? 'row' : 'tile'} at 288px Hindi 2x dark has no overflow', (tester) async {
      await pump(
        tester,
        card(row: row),
        width: 288,
        size: const Size(320, 800),
        dark: true,
        locale: const Locale('hi', 'IN'),
        scale: 2,
      );
      expect(find.text('Sunshine Villa'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
