import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/core/translations/app_translations.dart';
import 'package:ghar360/features/explore/presentation/widgets/explore_property_card.dart';
import '../../../../helpers/getx_test_binding.dart';

PropertyModel _richProperty({int id = 100, bool liked = false}) {
  return PropertyModel(
    id: id,
    title: 'Penthouse $id',
    basePrice: 5000000,
    propertyType: PropertyType.penthouse,
    purpose: PropertyPurpose.buy,
    bedrooms: 3,
    bathrooms: 2,
    areaSqft: 1200,
    mainImageUrl: 'https://example.com/image.jpg',
    city: 'Mumbai',
    state: 'Maharashtra',
    isAvailable: true,
    viewCount: 10,
    likeCount: 5,
    interestCount: 2,
    liked: liked,
  );
}

void main() {
  setUp(() => GetxTestBinding.init());
  tearDown(() => GetxTestBinding.reset());

  Future<void> pumpWidget(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        fallbackLocale: const Locale('en', 'US'),
        initialRoute: '/',
        getPages: [
          GetPage(
            name: '/',
            page: () => Scaffold(
              body: Center(child: SizedBox(width: 400, height: 240, child: child)),
            ),
          ),
          GetPage(
            name: AppRoutes.propertyDetails,
            page: () => const Scaffold(body: Text('Property Details')),
          ),
        ],
      ),
    );
  }

  testWidgets('renders property title and formatted price', (tester) async {
    await pumpWidget(
      tester,
      ExplorePropertyCard(property: _richProperty(), isFavourite: false, onFavouriteToggle: () {}),
    );

    expect(find.textContaining('Penthouse'), findsOneWidget);
    // 5000000 -> ₹50.0 L
    expect(find.text('₹50.0 L'), findsOneWidget);
  });

  testWidgets('renders property type badge translated and uppercased', (tester) async {
    await pumpWidget(
      tester,
      ExplorePropertyCard(property: _richProperty(), isFavourite: false, onFavouriteToggle: () {}),
    );

    expect(find.text('PENTHOUSE'), findsOneWidget);
  });

  testWidgets('renders bedroom/bathroom and area specs', (tester) async {
    await pumpWidget(
      tester,
      ExplorePropertyCard(property: _richProperty(), isFavourite: false, onFavouriteToggle: () {}),
    );

    expect(find.text('3BHK, 2 Bath'), findsOneWidget);
    expect(find.text('1200 sq ft'), findsOneWidget);
  });

  testWidgets('shows filled favorite icon when isFavourite is true', (tester) async {
    await pumpWidget(
      tester,
      ExplorePropertyCard(property: _richProperty(), isFavourite: true, onFavouriteToggle: () {}),
    );

    expect(find.byIcon(Icons.favorite), findsOneWidget);
  });

  testWidgets('shows outlined favorite icon when isFavourite is false', (tester) async {
    await pumpWidget(
      tester,
      ExplorePropertyCard(property: _richProperty(), isFavourite: false, onFavouriteToggle: () {}),
    );

    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
  });

  testWidgets('calls onFavouriteToggle when favorite button tapped', (tester) async {
    var toggled = 0;
    await pumpWidget(
      tester,
      ExplorePropertyCard(
        property: _richProperty(),
        isFavourite: false,
        onFavouriteToggle: () => toggled++,
      ),
    );

    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pump();

    expect(toggled, 1);
  });

  testWidgets('navigates to property details on card tap', (tester) async {
    final property = _richProperty();
    await pumpWidget(
      tester,
      ExplorePropertyCard(property: property, isFavourite: false, onFavouriteToggle: () {}),
    );

    // Tap the card body (not the favorite icon).
    await tester.tap(find.textContaining('Penthouse'));
    await tester.pumpAndSettle();

    // GetX navigation to the propertyDetails route should have occurred.
    expect(Get.currentRoute, '/property-details');
  });
}
