import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/data/models/property_image_model.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/design/app_design_theme.dart';
import 'package:ghar360/features/property_details/presentation/widgets/property_details_info_sections.dart';
import '../../../../helpers/load_app_fonts.dart';
import '../../../../helpers/provider_test_app.dart';

void main() {
  setUpAll(loadAppFonts);

  PropertyModel stay({double? nightly, double? daily}) => PropertyModel(
    id: 1,
    title: 'Stay',
    basePrice: 7777777,
    purpose: PropertyPurpose.shortStay,
    nightlyRate: nightly,
    dailyRate: daily,
    images: const <PropertyImageModel>[],
    isAvailable: true,
    viewCount: 0,
    likeCount: 0,
    interestCount: 0,
  );

  Future<void> pump(WidgetTester tester, PropertyModel p) => tester.pumpProviderApp(
    Scaffold(body: PropertyDetailsPricingSection(property: p)),
    theme: AppDesignTheme.light(),
  );

  testWidgets('short stay shows the nightly rate, never base_price', (tester) async {
    await pump(tester, stay(nightly: 4500));
    expect(find.textContaining('4,500'), findsOneWidget);
    expect(find.textContaining('77,77,777'), findsNothing);
  });

  testWidgets('short stay without a rate shows no price row', (tester) async {
    await pump(tester, stay());
    expect(find.textContaining('77,77,777'), findsNothing);
    expect(find.text('Daily Rate'), findsNothing);
  });
}
