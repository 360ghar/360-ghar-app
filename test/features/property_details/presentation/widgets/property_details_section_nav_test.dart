import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/design/app_design_theme.dart';
import 'package:ghar360/features/property_details/presentation/widgets/property_details_section_nav.dart';
import '../../../../helpers/load_app_fonts.dart';
import '../../../../helpers/provider_test_app.dart';

void main() {
  setUpAll(loadAppFonts);

  Future<void> pumpAt(WidgetTester tester, double width, {double textScale = 1}) async {
    await tester.binding.setSurfaceSize(Size(width, 200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpProviderApp(
      Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: PropertyDetailsSectionNav(
            active: PropertyDetailsSection.overview,
            onSelect: (_) {},
          ),
        ),
      ),
      theme: AppDesignTheme.light(),
      textScale: textScale,
    );
  }

  testWidgets('all four English tabs fit a 390 px phone without a sliced tab', (tester) async {
    await pumpAt(tester, 390);
    expect(find.byType(SingleChildScrollView), findsNothing);
    for (final id in ['overview', 'media', 'specs', 'location']) {
      final rect = tester.getRect(find.byKey(ValueKey('qa.property_details.section.$id')));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(390));
    }
  });

  testWidgets('a narrow screen with large text scrolls the strip instead of cutting labels', (
    tester,
  ) async {
    await pumpAt(tester, 320, textScale: 2);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });
}
