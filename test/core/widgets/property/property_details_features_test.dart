import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/translations/app_translations.dart';
import 'package:ghar360/core/widgets/property/property_details_features.dart';

import '../../../helpers/getx_test_binding.dart';

void main() {
  setUp(() => GetxTestBinding.init());
  tearDown(() => GetxTestBinding.reset());

  Future<void> pumpWidget(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        fallbackLocale: const Locale('en', 'US'),
        home: Scaffold(body: Center(child: child)),
      ),
    );
  }

  PropertyModel _propertyWithAllFeatures() {
    return PropertyModel(
      id: 1,
      title: 'Test Property',
      basePrice: 5000000,
      isAvailable: true,
      viewCount: 0,
      likeCount: 0,
      interestCount: 0,
      bedrooms: 3,
      bathrooms: 2,
      areaSqft: 1200,
      balconies: 1,
      parkingSpaces: 2,
      floorNumber: 3,
      totalFloors: 10,
    );
  }

  testWidgets('renders feature icons and labels for a fully-featured property',
      (tester) async {
    await pumpWidget(
      tester,
      PropertyDetailsFeatures(property: _propertyWithAllFeatures()),
    );

    expect(find.byType(PropertyDetailsFeatures), findsOneWidget);

    // Primary row icons.
    expect(find.byIcon(Icons.bed), findsOneWidget);
    expect(find.byIcon(Icons.bathtub_outlined), findsOneWidget);
    expect(find.byIcon(Icons.square_foot), findsOneWidget);

    // Primary row values.
    expect(find.text('3'), findsOneWidget);
    // '2' appears for both bathrooms and parkingSpaces, so use findsWidgets.
    expect(find.text('2'), findsWidgets);
    expect(find.text('1200'), findsOneWidget);

    // Labels.
    expect(find.text('Bedrooms'), findsOneWidget);
    expect(find.text('Bathrooms'), findsOneWidget);
    expect(find.text('Sq Ft'), findsOneWidget);

    // Secondary row icons (only rendered when balconies/parking/floor present).
    expect(find.byIcon(Icons.balcony), findsOneWidget);
    expect(find.byIcon(Icons.local_parking), findsOneWidget);
    expect(find.byIcon(Icons.layers), findsOneWidget);

    // Floor value "3/10".
    expect(find.text('3/10'), findsOneWidget);
    expect(find.text('Floor'), findsOneWidget);
    expect(find.text('Balconies'), findsOneWidget);
    expect(find.text('Parking'), findsOneWidget);

    // A Divider separates the two rows.
    expect(find.byType(Divider), findsOneWidget);
  });

  testWidgets('renders only primary row when no secondary features', (tester) async {
    final property = PropertyModel(
      id: 2,
      title: 'Minimal Property',
      basePrice: 3000000,
      isAvailable: true,
      viewCount: 0,
      likeCount: 0,
      interestCount: 0,
      bedrooms: 2,
      bathrooms: 1,
      areaSqft: 800,
    );

    await pumpWidget(tester, PropertyDetailsFeatures(property: property));

    // Primary row present.
    expect(find.byIcon(Icons.bed), findsOneWidget);
    expect(find.byIcon(Icons.bathtub_outlined), findsOneWidget);
    expect(find.byIcon(Icons.square_foot), findsOneWidget);

    // Secondary row absent — no Divider.
    expect(find.byIcon(Icons.balcony), findsNothing);
    expect(find.byIcon(Icons.local_parking), findsNothing);
    expect(find.byIcon(Icons.layers), findsNothing);
    expect(find.byType(Divider), findsNothing);
  });

  testWidgets('handles empty features gracefully', (tester) async {
    final property = PropertyModel(
      id: 3,
      title: 'Empty Property',
      basePrice: 1000000,
      isAvailable: true,
      viewCount: 0,
      likeCount: 0,
      interestCount: 0,
    );

    await pumpWidget(tester, PropertyDetailsFeatures(property: property));

    // The container is still rendered.
    expect(find.byType(PropertyDetailsFeatures), findsOneWidget);
    // No feature icons at all.
    expect(find.byIcon(Icons.bed), findsNothing);
    expect(find.byIcon(Icons.bathtub_outlined), findsNothing);
    expect(find.byIcon(Icons.square_foot), findsNothing);
    expect(find.byType(Divider), findsNothing);
  });

  testWidgets('renders partial primary features', (tester) async {
    final property = PropertyModel(
      id: 4,
      title: 'Partial Property',
      basePrice: 2000000,
      isAvailable: true,
      viewCount: 0,
      likeCount: 0,
      interestCount: 0,
      bedrooms: 4,
    );

    await pumpWidget(tester, PropertyDetailsFeatures(property: property));

    // Only bedrooms icon/value present.
    expect(find.byIcon(Icons.bed), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('Bedrooms'), findsOneWidget);

    // Bathrooms and area absent.
    expect(find.byIcon(Icons.bathtub_outlined), findsNothing);
    expect(find.byIcon(Icons.square_foot), findsNothing);
  });
}
