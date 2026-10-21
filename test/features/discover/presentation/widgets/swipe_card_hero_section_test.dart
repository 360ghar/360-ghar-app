import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/data/models/property_image_model.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/image_cache_service.dart';
import 'package:ghar360/core/widgets/common/property_list_card.dart';
import 'package:ghar360/features/discover/presentation/widgets/swipe_card_hero_section.dart';
import '../../../../helpers/image_test_cache.dart';
import '../../../../helpers/knife_finders.dart';

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
    // The price a listing shows comes from the field of its purpose.
    monthlyRent: purpose == 'rent' ? basePrice : null,
    nightlyRate: purpose == 'short_stay' ? basePrice : null,
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

final _images = ImageTestCache();

void main() {
  Future<void> pumpWidget(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        builder: (context, child) => ProviderScope(
          overrides: [imageCacheServiceProvider.overrideWithValue(_images.service)],
          child: child!,
        ),
        locale: const Locale('en', 'US'),
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
        isMainImage: true,
        category: ImageCategory.interior,
      ),
      const PropertyImageModel(
        id: 2,
        propertyId: 100,
        imageUrl: 'https://example.com/b.jpg',
        category: ImageCategory.interior,
      ),
      const PropertyImageModel(
        id: 3,
        propertyId: 100,
        imageUrl: 'https://example.com/c.jpg',
        category: ImageCategory.interior,
      ),
    ];
    await pumpWidget(tester, SwipeCardHeroSection(property: _richProperty(images: images)));

    expect(find.text('1/3'), findsOneWidget);
    expect(find.text('3'), findsOneWidget); // photo count media badge
    expect(findKnife(KnifeIcon.chevronRight), findsOneWidget);
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

  testWidgets('a rent listing with no monthly rent shows no price and no suffix', (tester) async {
    final property = const PropertyModel(
      id: 100,
      title: 'Sunshine Villa',
      basePrice: 5000000,
      propertyType: PropertyType.house,
      purpose: PropertyPurpose.rent,
      isAvailable: true,
      viewCount: 0,
      likeCount: 0,
      interestCount: 0,
    );
    await pumpWidget(tester, SwipeCardHeroSection(property: property));

    final richTexts = tester.widgetList<RichText>(find.byType(RichText));
    expect(richTexts.any((r) => r.text.toPlainText().contains(' /mo')), isFalse);
    expect(find.textContaining('50,00,000'), findsNothing);
  });

  testWidgets('renders bedroom and bathroom spec pills', (tester) async {
    await pumpWidget(tester, SwipeCardHeroSection(property: _richProperty()));

    expect(find.text('3 BHK'), findsOneWidget);
    expect(find.text('2 Bath'), findsOneWidget);
  });

  testWidgets('renders share icon button', (tester) async {
    await pumpWidget(tester, SwipeCardHeroSection(property: _richProperty()));

    expect(findKnife(KnifeIcon.share), findsOneWidget);
  });

  testWidgets('the photo carries the details hero tag and the words sit on the label', (
    tester,
  ) async {
    final property = _richProperty();
    await pumpWidget(tester, SwipeCardHeroSection(property: property));

    final hero = find.byWidgetPredicate(
      (widget) => widget is Hero && widget.tag == propertyPhotoHeroTag(property.id),
    );
    expect(hero, findsOneWidget);
    // Price, name and numbers are below the photo, not over it.
    final photo = tester.getRect(hero);
    expect(tester.getRect(find.text('3 BHK')).top, greaterThan(photo.bottom - 1));
    expect(find.text('House'), findsOneWidget);
    expect(find.descendant(of: hero, matching: find.text('House')), findsNothing);
  });
}
