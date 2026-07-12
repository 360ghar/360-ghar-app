import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/core/translations/app_translations.dart';
import 'package:ghar360/features/likes/presentation/widgets/likes_property_card.dart';

import '../../../../helpers/getx_test_binding.dart';

PropertyModel _richProperty({int id = 100}) {
  return PropertyModel(
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
}

PropertyModel _rentalProperty({int id = 200}) {
  return PropertyModel(
    id: id,
    title: 'Cozy Studio',
    basePrice: 15000,
    propertyType: PropertyType.studio,
    purpose: PropertyPurpose.rent,
    monthlyRent: 15000,
    mainImageUrl: 'https://example.com/studio.jpg',
    city: 'Mumbai',
    isAvailable: true,
    viewCount: 5,
    likeCount: 2,
    interestCount: 1,
  );
}

void main() {
  setUp(() => GetxTestBinding.init());
  tearDown(() => GetxTestBinding.reset());

  Future<void> pumpCard(
    WidgetTester tester,
    Widget child, {
    bool withRoutes = false,
  }) async {
    if (withRoutes) {
      await tester.pumpWidget(
        GetMaterialApp(
          translations: AppTranslations(),
          locale: const Locale('en', 'US'),
          fallbackLocale: const Locale('en', 'US'),
          initialRoute: '/',
          getPages: [
            GetPage(
              name: '/',
              page: () => Scaffold(body: Center(child: SizedBox(width: 400, height: 300, child: child))),
            ),
            GetPage(
              name: AppRoutes.propertyDetails,
              page: () => const Scaffold(body: Text('Property Details')),
            ),
          ],
        ),
      );
    } else {
      await tester.pumpWidget(
        GetMaterialApp(
          translations: AppTranslations(),
          locale: const Locale('en', 'US'),
          fallbackLocale: const Locale('en', 'US'),
          home: Scaffold(body: Center(child: SizedBox(width: 400, height: 300, child: child))),
        ),
      );
    }
  }

  testWidgets('renders property title and formatted price', (tester) async {
    await pumpCard(
      tester,
      LikesPropertyCard(
        property: _richProperty(),
        isFavourite: false,
        onFavouriteToggle: () {},
      ),
    );

    expect(find.text('Sunshine Villa'), findsOneWidget);
    // 5000000 -> ₹50.0 L
    expect(find.text('₹50.0 L'), findsOneWidget);
  });

  testWidgets('renders property type badge translated and uppercased', (tester) async {
    await pumpCard(
      tester,
      LikesPropertyCard(
        property: _richProperty(),
        isFavourite: false,
        onFavouriteToggle: () {},
      ),
    );

    expect(find.text('HOUSE'), findsOneWidget);
  });

  testWidgets('renders bedroom/bathroom and area specs', (tester) async {
    await pumpCard(
      tester,
      LikesPropertyCard(
        property: _richProperty(),
        isFavourite: false,
        onFavouriteToggle: () {},
      ),
    );

    expect(find.text('3BHK, 2 Bath'), findsOneWidget);
    expect(find.text('1200 sq ft'), findsOneWidget);
  });

  testWidgets('renders address display', (tester) async {
    await pumpCard(
      tester,
      LikesPropertyCard(
        property: _richProperty(),
        isFavourite: false,
        onFavouriteToggle: () {},
      ),
    );

    expect(find.text('New Delhi'), findsOneWidget);
  });

  testWidgets('shows filled favorite icon when isFavourite is true', (tester) async {
    await pumpCard(
      tester,
      LikesPropertyCard(
        property: _richProperty(),
        isFavourite: true,
        onFavouriteToggle: () {},
      ),
    );

    expect(find.byIcon(Icons.favorite), findsOneWidget);
  });

  testWidgets('shows outlined favorite icon when isFavourite is false', (tester) async {
    await pumpCard(
      tester,
      LikesPropertyCard(
        property: _richProperty(),
        isFavourite: false,
        onFavouriteToggle: () {},
      ),
    );

    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
  });

  testWidgets('calls onFavouriteToggle when favorite button tapped', (tester) async {
    var toggled = 0;
    await pumpCard(
      tester,
      LikesPropertyCard(
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
    await pumpCard(
      tester,
      LikesPropertyCard(
        property: property,
        isFavourite: false,
        onFavouriteToggle: () {},
      ),
      withRoutes: true,
    );

    await tester.tap(find.text('Sunshine Villa'));
    await tester.pumpAndSettle();

    expect(Get.currentRoute, AppRoutes.propertyDetails);
  });

  testWidgets('renders rental property with monthly rent price', (tester) async {
    await pumpCard(
      tester,
      LikesPropertyCard(
        property: _rentalProperty(),
        isFavourite: false,
        onFavouriteToggle: () {},
      ),
    );

    expect(find.text('Cozy Studio'), findsOneWidget);
    // monthlyRent=15000, purpose=rent -> effectivePrice=15000 -> ₹15000
    expect(find.text('₹15000'), findsOneWidget);
  });

  testWidgets('renders studio type badge uppercased', (tester) async {
    await pumpCard(
      tester,
      LikesPropertyCard(
        property: _rentalProperty(),
        isFavourite: false,
        onFavouriteToggle: () {},
      ),
    );

    expect(find.text('STUDIO'), findsOneWidget);
  });

  testWidgets('hides bedroom/bathroom specs when not set', (tester) async {
    final property = PropertyModel(
      id: 300,
      title: 'Plot Only',
      basePrice: 2000000,
      propertyType: PropertyType.plot,
      purpose: PropertyPurpose.buy,
      mainImageUrl: 'https://example.com/plot.jpg',
      city: 'Pune',
      isAvailable: true,
      viewCount: 0,
      likeCount: 0,
      interestCount: 0,
    );
    await pumpCard(
      tester,
      LikesPropertyCard(
        property: property,
        isFavourite: false,
        onFavouriteToggle: () {},
      ),
    );

    expect(find.byIcon(Icons.bed_outlined), findsNothing);
    expect(find.byIcon(Icons.square_foot), findsNothing);
  });
}
