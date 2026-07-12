import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/translations/app_translations.dart';
import 'package:ghar360/features/discover/presentation/widgets/property_swipe_card.dart';
import '../../../../helpers/getx_test_binding.dart';

/// Builds a richer [PropertyModel] for swipe-card rendering tests.
PropertyModel _richProperty({int id = 100, String? virtualTourUrl}) {
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
    virtualTourUrl: virtualTourUrl,
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
  setUp(() => GetxTestBinding.init());
  tearDown(() => GetxTestBinding.reset());

  /// Card is chrome-only (no internal scroll); production hosts it in a
  /// scroll view. Mirror that so content can exceed the viewport.
  Future<void> pumpWidget(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        fallbackLocale: const Locale('en', 'US'),
        home: Scaffold(
          body: SingleChildScrollView(child: child),
        ),
      ),
    );
  }

  testWidgets('renders hero and details sections for a property', (tester) async {
    final property = _richProperty();
    await pumpWidget(tester, PropertySwipeCard(property: property));

    // Title is rendered by the hero section.
    expect(find.text('Sunshine Villa'), findsOneWidget);
    // Description heading from the details section.
    expect(find.text('Description'), findsOneWidget);
  });

  testWidgets('does not embed swipe instructions on the card', (tester) async {
    final property = _richProperty();
    await pumpWidget(tester, PropertySwipeCard(property: property));

    expect(find.text('Swipe right to like | Swipe left to pass'), findsNothing);
  });

  testWidgets('fires onTap via view details CTA', (tester) async {
    var taps = 0;
    await pumpWidget(tester, PropertySwipeCard(property: _richProperty(), onTap: () => taps++));

    await tester.tap(find.text('View details'));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('shows lazy 360 tour CTA when virtualTourUrl is set', (tester) async {
    final property = _richProperty(virtualTourUrl: 'https://kuula.co/share/abc');

    await pumpWidget(tester, PropertySwipeCard(property: property));

    expect(find.text('360° Virtual Tour'), findsOneWidget);
    expect(find.text('Tap to load virtual tour'), findsOneWidget);
  });

  testWidgets('does not place action buttons inside the card', (tester) async {
    await pumpWidget(tester, PropertySwipeCard(property: _richProperty()));

    expect(find.byKey(const ValueKey('qa.discover.action.like')), findsNothing);
    expect(find.byKey(const ValueKey('qa.discover.action.pass')), findsNothing);
    expect(find.byKey(const ValueKey('qa.discover.action.details')), findsNothing);
  });
}
