import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/presentation/property_labels.dart';
import '../../helpers/provider_test_app.dart';

PropertyModel _home({
  double? area,
  int? floor,
  int? total,
  int? age,
  double? km,
  List<String>? features,
}) => PropertyModel(
  id: 1,
  title: 'Home',
  basePrice: 8500000,
  purpose: PropertyPurpose.buy,
  areaSqft: area,
  floorNumber: floor,
  totalFloors: total,
  ageOfProperty: age,
  distanceKm: km,
  features: features,
  isAvailable: true,
  viewCount: 0,
  likeCount: 0,
  interestCount: 0,
);

void main() {
  Future<List<String>> labels(WidgetTester tester, Locale locale, PropertyModel home) async {
    late List<String> out;
    await tester.pumpProviderApp(
      Builder(
        builder: (context) {
          out = [
            home.localizedPrice(context),
            home.localizedArea(context),
            home.localizedFloor(context),
            home.localizedAge(context),
            home.localizedDistance(context),
          ];
          return const SizedBox();
        },
      ),
      locale: locale,
    );
    return out;
  }

  testWidgets('English labels, Indian grouping, no stray zeros', (tester) async {
    expect(
      await labels(
        tester,
        const Locale('en', 'US'),
        _home(area: 1450, floor: 4, total: 12, age: 5, km: 4.8),
      ),
      ['₹85 L', '1,450 sq ft', 'Floor 4/12', '5 years old', '4.8 km away'],
    );
    expect(await labels(tester, const Locale('en', 'US'), _home(floor: 3, age: 0, km: 0.3)), [
      '₹85 L',
      '',
      'Floor 3',
      'New construction',
      '300 m away',
    ]);
    expect((await labels(tester, const Locale('en', 'US'), _home(age: 1)))[3], '1 year old');
    expect(await labels(tester, const Locale('en', 'US'), _home()), ['₹85 L', '', '', '', '']);
  });

  testWidgets('the price follows the purpose and is empty when the backend sent none', (
    tester,
  ) async {
    PropertyModel listing(PropertyPurpose purpose, {double? rent, double? night}) => PropertyModel(
      id: 1,
      title: 'Home',
      basePrice: 8500000,
      purpose: purpose,
      monthlyRent: rent,
      nightlyRate: night,
      isAvailable: true,
      viewCount: 0,
      likeCount: 0,
      interestCount: 0,
    );
    const en = Locale('en', 'US');
    expect((await labels(tester, en, listing(PropertyPurpose.rent, rent: 45000)))[0], '₹45,000');
    expect(
      (await labels(tester, en, listing(PropertyPurpose.shortStay, night: 3500)))[0],
      '₹3,500',
    );
    // No fallback to base_price: a rent listing with no monthly_rent shows no price.
    expect((await labels(tester, en, listing(PropertyPurpose.rent)))[0], isEmpty);
    expect((await labels(tester, en, listing(PropertyPurpose.shortStay)))[0], isEmpty);
  });

  testWidgets('Hindi labels carry Hindi units', (tester) async {
    expect(
      await labels(
        tester,
        const Locale('hi', 'IN'),
        _home(area: 1450, floor: 4, total: 12, age: 5, km: 4.8),
      ),
      ['₹85 लाख', '1,450 वर्ग फीट', 'मंज़िल 4/12', '5 साल पुराना', '4.8 कि.मी. दूर'],
    );
  });

  testWidgets('highlights keep known feature keys as labels and drop internal metadata', (
    tester,
  ) async {
    Future<List<String>> highlights(Locale locale, List<String>? features) async {
      late List<String> out;
      await tester.pumpProviderApp(
        Builder(
          builder: (context) {
            out = _home(features: features).localizedHighlights(context);
            return const SizedBox();
          },
        ),
        locale: locale,
      );
      return out;
    }

    // The exact array prod sends for property 182.
    const prod = [
      'amenities',
      'facing',
      'listing_bucket',
      'rera_registered',
      'slug',
      'society_name',
      'vastu_compliant',
    ];
    const en = Locale('en', 'US');
    expect(await highlights(en, prod), ['RERA registered', 'Vastu compliant']);
    expect(await highlights(en, ['gym', 'Power Backup', 'slug', 'pool']), [
      'Gym',
      'Power backup',
      'Swimming pool',
    ]);
    expect(await highlights(en, ['amenities', 'facing', 'slug', 'society_name']), isEmpty);
    expect(await highlights(en, const []), isEmpty);
    expect(await highlights(en, null), isEmpty);
    expect(await highlights(const Locale('hi', 'IN'), ['pool', 'slug']), ['स्विमिंग पूल']);
  });
}
