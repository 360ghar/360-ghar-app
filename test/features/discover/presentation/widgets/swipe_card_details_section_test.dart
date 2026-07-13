import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/translations/app_translations.dart';
import 'package:ghar360/features/discover/presentation/widgets/swipe_card_details_section.dart';
import '../../../../helpers/getx_test_binding.dart';

PropertyModel _richProperty({int id = 100, String? virtualTourUrl, String? description}) {
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
    virtualTourUrl: virtualTourUrl,
    features: const ['Garden', 'Garage'],
    amenities: const [
      PropertyAmenity(id: 1, title: 'Swimming Pool'),
      PropertyAmenity(id: 2, title: 'Gym'),
    ],
    isAvailable: true,
    viewCount: 42,
    likeCount: 15,
    interestCount: 8,
    description: description ?? 'A beautiful villa with modern amenities.',
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
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
  }

  testWidgets('renders description section with property description', (tester) async {
    await pumpWidget(tester, SwipeCardDetailsSection(property: _richProperty()));

    expect(find.text('Description'), findsOneWidget);
    expect(find.text('A beautiful villa with modern amenities.'), findsOneWidget);
  });

  testWidgets('shows no-description placeholder when description is empty', (tester) async {
    final property = const PropertyModel(
      id: 1,
      title: 'No Desc',
      basePrice: 100,
      isAvailable: true,
      viewCount: 0,
      likeCount: 0,
      interestCount: 0,
    );
    await pumpWidget(tester, SwipeCardDetailsSection(property: property));

    expect(find.text('No description available'), findsOneWidget);
  });

  testWidgets('shows read more for long description and expands on tap', (tester) async {
    final longDesc = List.filled(20, 'Spacious living with natural light.').join(' ');
    await pumpWidget(
      tester,
      SwipeCardDetailsSection(property: _richProperty(description: longDesc)),
    );

    final readMore = find.text('Read more');
    expect(readMore, findsOneWidget);
    await tester.ensureVisible(readMore);
    await tester.pump();
    await tester.tap(readMore);
    await tester.pump();
    expect(find.text('Read less'), findsOneWidget);
  });

  testWidgets('renders highlights chips for features', (tester) async {
    await pumpWidget(tester, SwipeCardDetailsSection(property: _richProperty()));

    expect(find.text('Highlights'), findsOneWidget);
    expect(find.text('Garden'), findsOneWidget);
    expect(find.text('Garage'), findsOneWidget);
  });

  testWidgets('renders amenities chips', (tester) async {
    await pumpWidget(tester, SwipeCardDetailsSection(property: _richProperty()));

    expect(find.text('Amenities'), findsOneWidget);
    expect(find.text('Swimming Pool'), findsOneWidget);
    expect(find.text('Gym'), findsOneWidget);
  });

  testWidgets('renders property details card with type and purpose', (tester) async {
    await pumpWidget(tester, SwipeCardDetailsSection(property: _richProperty()));

    expect(find.text('Property Details'), findsOneWidget);
    expect(find.text('House'), findsWidgets);
    expect(find.text('Buy'), findsWidgets);
    expect(find.text('3'), findsWidgets);
  });

  testWidgets('does not render location section when property has no location', (tester) async {
    await pumpWidget(tester, SwipeCardDetailsSection(property: _richProperty()));

    // No "Get Directions" button because latitude/longitude are null.
    expect(find.text('Get Directions'), findsNothing);
  });

  testWidgets('never shows swipe instructions banner', (tester) async {
    await pumpWidget(tester, SwipeCardDetailsSection(property: _richProperty()));

    expect(find.text('Swipe right to like | Swipe left to pass'), findsNothing);
  });

  testWidgets('renders virtual tour section heading when tour URL is set', (tester) async {
    await pumpWidget(
      tester,
      SwipeCardDetailsSection(
        property: _richProperty(virtualTourUrl: 'https://kuula.co/share/abc'),
      ),
    );

    expect(find.text('360° Virtual Tour'), findsOneWidget);
    expect(find.text('Fullscreen Mode'), findsOneWidget);
  });

  testWidgets('hides virtual tour section when no tour URL', (tester) async {
    await pumpWidget(tester, SwipeCardDetailsSection(property: _richProperty()));

    expect(find.text('360° Virtual Tour'), findsNothing);
  });
}
