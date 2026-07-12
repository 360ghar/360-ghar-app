import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/translations/app_translations.dart';
import 'package:ghar360/features/property_details/presentation/widgets/property_details_info_sections.dart';

import '../../../../helpers/google_fonts_test_helper.dart';
import '../../../../helpers/getx_test_binding.dart';

PropertyModel _buyProperty() {
  return PropertyModel(
    id: 1,
    title: 'Sunshine Villa',
    basePrice: 5000000,
    propertyType: PropertyType.house,
    purpose: PropertyPurpose.buy,
    pricePerSqft: 4000,
    maintenanceCharges: 2000,
    bedrooms: 3,
    bathrooms: 2,
    areaSqft: 1200,
    ageOfProperty: 5,
    builderName: 'ABC Builders',
    isAvailable: true,
    viewCount: 0,
    likeCount: 0,
    interestCount: 0,
  );
}

PropertyModel _rentProperty() {
  return PropertyModel(
    id: 2,
    title: 'Cozy Apartment',
    basePrice: 30000,
    propertyType: PropertyType.apartment,
    purpose: PropertyPurpose.rent,
    monthlyRent: 30000,
    securityDeposit: 60000,
    maintenanceCharges: 1500,
    isAvailable: true,
    viewCount: 0,
    likeCount: 0,
    interestCount: 0,
  );
}

PropertyModel _shortStayProperty() {
  return PropertyModel(
    id: 3,
    title: 'Holiday Home',
    basePrice: 2000,
    propertyType: PropertyType.villa,
    purpose: PropertyPurpose.shortStay,
    dailyRate: 2000,
    securityDeposit: 5000,
    isAvailable: true,
    viewCount: 0,
    likeCount: 0,
    interestCount: 0,
  );
}

PropertyModel _pgProperty() {
  return PropertyModel(
    id: 4,
    title: 'PG for Girls',
    basePrice: 8000,
    propertyType: PropertyType.pg,
    purpose: PropertyPurpose.rent,
    monthlyRent: 8000,
    listingPreferences: const ListingPreferences(
      genderPreference: ListingGenderPreference.female,
      sharingType: ListingSharingType.sharedRoom,
    ),
    isAvailable: true,
    viewCount: 0,
    likeCount: 0,
    interestCount: 0,
  );
}

void main() {
  configureGoogleFontsForTests();

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

  group('PropertyDetailsInfoSection', () {
    testWidgets('renders property information header and type/purpose rows', (tester) async {
      await pumpWidget(tester, PropertyDetailsInfoSection(property: _buyProperty()));

      expect(find.text('Property Information'), findsOneWidget);
      expect(find.text('Property Type'), findsOneWidget);
      expect(find.text('House'), findsOneWidget);
      expect(find.text('Purpose'), findsOneWidget);
      expect(find.text('Buy'), findsOneWidget);
    });

    testWidgets('renders age row when ageOfProperty is set', (tester) async {
      await pumpWidget(tester, PropertyDetailsInfoSection(property: _buyProperty()));

      expect(find.text('Age'), findsOneWidget);
      expect(find.text('5 years old'), findsOneWidget);
    });

    testWidgets('renders gender preference and room type for PG property', (tester) async {
      await pumpWidget(tester, PropertyDetailsInfoSection(property: _pgProperty()));

      expect(find.text('Gender Preference'), findsOneWidget);
      expect(find.text('Female only'), findsOneWidget);
      expect(find.text('Room Type'), findsOneWidget);
      expect(find.text('Shared room'), findsOneWidget);
    });

    testWidgets('hides age row when ageOfProperty is null', (tester) async {
      final property = PropertyModel(
        id: 5,
        title: 'No Age',
        basePrice: 1000000,
        propertyType: PropertyType.house,
        purpose: PropertyPurpose.buy,
        isAvailable: true,
        viewCount: 0,
        likeCount: 0,
        interestCount: 0,
      );
      await pumpWidget(tester, PropertyDetailsInfoSection(property: property));

      expect(find.text('Age'), findsNothing);
    });
  });

  group('PropertyDetailsPricingSection', () {
    testWidgets('renders sale price and price per sqft for buy property', (tester) async {
      await pumpWidget(tester, PropertyDetailsPricingSection(property: _buyProperty()));

      expect(find.text('Pricing Details'), findsOneWidget);
      expect(find.text('Sale Price'), findsOneWidget);
      expect(find.text('₹5000000'), findsOneWidget);
      expect(find.text('Price per sq ft'), findsOneWidget);
      expect(find.text('₹4000'), findsOneWidget);
      expect(find.text('Maintenance'), findsOneWidget);
      expect(find.text('₹2000'), findsOneWidget);
    });

    testWidgets('renders monthly rent, security deposit, and maintenance for rent property', (
      tester,
    ) async {
      await pumpWidget(tester, PropertyDetailsPricingSection(property: _rentProperty()));

      expect(find.text('Monthly Rent'), findsOneWidget);
      expect(find.text('₹30000'), findsOneWidget);
      expect(find.text('Security Deposit'), findsOneWidget);
      expect(find.text('₹60000'), findsOneWidget);
      expect(find.text('Maintenance'), findsOneWidget);
      expect(find.text('₹1500'), findsOneWidget);
    });

    testWidgets('renders daily rate and security deposit for short stay property', (tester) async {
      await pumpWidget(tester, PropertyDetailsPricingSection(property: _shortStayProperty()));

      expect(find.text('Daily Rate'), findsOneWidget);
      expect(find.text('₹2000'), findsOneWidget);
      expect(find.text('Security Deposit'), findsOneWidget);
      expect(find.text('₹5000'), findsOneWidget);
    });

    testWidgets('uses basePrice as monthly rent when monthlyRent is null', (tester) async {
      final property = PropertyModel(
        id: 6,
        title: 'Rent Fallback',
        basePrice: 25000,
        propertyType: PropertyType.apartment,
        purpose: PropertyPurpose.rent,
        isAvailable: true,
        viewCount: 0,
        likeCount: 0,
        interestCount: 0,
      );
      await pumpWidget(tester, PropertyDetailsPricingSection(property: property));

      expect(find.text('Monthly Rent'), findsOneWidget);
      expect(find.text('₹25000'), findsOneWidget);
    });

    testWidgets('uses basePrice as daily rate when dailyRate is null', (tester) async {
      final property = PropertyModel(
        id: 7,
        title: 'Short Stay Fallback',
        basePrice: 3000,
        propertyType: PropertyType.villa,
        purpose: PropertyPurpose.shortStay,
        isAvailable: true,
        viewCount: 0,
        likeCount: 0,
        interestCount: 0,
      );
      await pumpWidget(tester, PropertyDetailsPricingSection(property: property));

      expect(find.text('Daily Rate'), findsOneWidget);
      expect(find.text('₹3000'), findsOneWidget);
    });
  });

  group('PropertyDetailsContactSection', () {
    testWidgets('renders builder information header and builder name', (tester) async {
      await pumpWidget(tester, PropertyDetailsContactSection(property: _buyProperty()));

      expect(find.text('Builder Information'), findsOneWidget);
      expect(find.text('Builder'), findsOneWidget);
      expect(find.text('ABC Builders'), findsOneWidget);
    });

    testWidgets('hides builder name row when builderName is null', (tester) async {
      final property = PropertyModel(
        id: 8,
        title: 'No Builder',
        basePrice: 1000000,
        propertyType: PropertyType.house,
        purpose: PropertyPurpose.buy,
        isAvailable: true,
        viewCount: 0,
        likeCount: 0,
        interestCount: 0,
      );
      await pumpWidget(tester, PropertyDetailsContactSection(property: property));

      expect(find.text('Builder Information'), findsOneWidget);
      expect(find.text('Builder'), findsNothing);
    });
  });

  group('buildInfoRow', () {
    testWidgets('renders label and value', (tester) async {
      await pumpWidget(
        tester,
        Material(
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: buildInfoRow('Label', 'Value'),
          ),
        ),
      );

      expect(find.text('Label'), findsOneWidget);
      expect(find.text('Value'), findsOneWidget);
    });
  });
}
