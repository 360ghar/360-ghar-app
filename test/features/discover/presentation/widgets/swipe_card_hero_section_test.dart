import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:ghar360/core/data/models/property_image_model.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/translations/app_translations.dart';
import 'package:ghar360/features/discover/presentation/widgets/swipe_card_hero_section.dart';
import '../../../../helpers/getx_test_binding.dart';

PropertyModel _richProperty({
  int id = 100,
  String purpose = 'buy',
  double basePrice = 5000000,
  String? virtualTourUrl,
  List<PropertyImageModel>? images,
}) {
  return PropertyModel(
    id: id,
    title: 'Sunshine Villa',
    basePrice: basePrice,
    propertyType: PropertyType.house,
    purpose: purpose == 'rent'
        ? PropertyPurpose.rent
        : purpose == 'short_stay'
        ? PropertyPurpose.shortStay
        : PropertyPurpose.buy,
    bedrooms: 3,
    bathrooms: 2,
    areaSqft: 1200,
    mainImageUrl: 'https://example.com/image.jpg',
    images: images,
    virtualTourUrl: virtualTourUrl,
    city: 'New Delhi',
    state: 'Delhi',
    isAvailable: true,
    viewCount: 42,
    likeCount: 15,
    interestCount: 8,
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
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('renders property title and location', (tester) async {
    await pumpWidget(tester, SwipeCardHeroSection(property: _richProperty()));

    expect(find.text('Sunshine Villa'), findsOneWidget);
    // shortAddressDisplay derives from city/state.
    expect(find.textContaining('Delhi'), findsWidgets);
  });

  testWidgets('renders property type badge translated', (tester) async {
    await pumpWidget(tester, SwipeCardHeroSection(property: _richProperty()));

    expect(find.text('House'), findsOneWidget);
  });

  testWidgets('renders view details CTA', (tester) async {
    await pumpWidget(tester, SwipeCardHeroSection(property: _richProperty()));

    expect(find.text('View details'), findsOneWidget);
  });

  testWidgets('invokes onViewDetails when CTA is tapped', (tester) async {
    var tapped = false;
    await pumpWidget(
      tester,
      SwipeCardHeroSection(property: _richProperty(), onViewDetails: () => tapped = true),
    );

    await tester.tap(find.text('View details'));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('shows photo count and media badge for multi-image gallery', (tester) async {
    final images = [
      const PropertyImageModel(
        id: 1,
        propertyId: 100,
        imageUrl: 'https://example.com/a.jpg',
        isMain: true,
        category: 'gallery',
      ),
      const PropertyImageModel(
        id: 2,
        propertyId: 100,
        imageUrl: 'https://example.com/b.jpg',
        category: 'gallery',
      ),
      const PropertyImageModel(
        id: 3,
        propertyId: 100,
        imageUrl: 'https://example.com/c.jpg',
        category: 'gallery',
      ),
    ];
    await pumpWidget(tester, SwipeCardHeroSection(property: _richProperty(images: images)));

    expect(find.text('1/3'), findsOneWidget);
    expect(find.text('3'), findsOneWidget); // photo count media badge
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
  });

  testWidgets('shows 360 media badge when virtual tour is present', (tester) async {
    await pumpWidget(
      tester,
      SwipeCardHeroSection(property: _richProperty(virtualTourUrl: 'https://kuula.co/share/abc')),
    );

    expect(find.text('360°'), findsOneWidget);
  });

  testWidgets('shows per-month suffix for rent purpose', (tester) async {
    await pumpWidget(
      tester,
      SwipeCardHeroSection(property: _richProperty(purpose: 'rent', basePrice: 25000)),
    );

    // The suffix lives inside a RichText TextSpan, so inspect the rendered
    // RichText widgets for the per-month marker.
    final richTexts = tester.widgetList<RichText>(find.byType(RichText));
    final hasSuffix = richTexts.any((r) => r.text.toPlainText().contains(' /mo'));
    expect(hasSuffix, isTrue);
  });

  testWidgets('shows per-day suffix for short-stay purpose', (tester) async {
    await pumpWidget(
      tester,
      SwipeCardHeroSection(property: _richProperty(purpose: 'short_stay', basePrice: 1500)),
    );

    final richTexts = tester.widgetList<RichText>(find.byType(RichText));
    final hasSuffix = richTexts.any((r) => r.text.toPlainText().contains(' /day'));
    expect(hasSuffix, isTrue);
  });

  testWidgets('renders bedroom and bathroom spec pills', (tester) async {
    await pumpWidget(tester, SwipeCardHeroSection(property: _richProperty()));

    expect(find.text('3 BHK'), findsOneWidget);
    expect(find.text('2 Bath'), findsOneWidget);
  });

  testWidgets('renders share icon button', (tester) async {
    await pumpWidget(tester, SwipeCardHeroSection(property: _richProperty()));

    expect(find.byIcon(Icons.share), findsOneWidget);
  });
}
