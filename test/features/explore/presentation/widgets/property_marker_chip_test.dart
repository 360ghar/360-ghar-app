import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/translations/app_translations.dart';
import 'package:ghar360/features/explore/presentation/widgets/property_marker_chip.dart';
import '../../../../helpers/getx_test_binding.dart';

PropertyModel _property({int id = 100, String title = 'Test Property'}) {
  return PropertyModel(
    id: id,
    title: title,
    basePrice: 5000000,
    isAvailable: true,
    viewCount: 0,
    likeCount: 0,
    interestCount: 0,
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
        home: Scaffold(body: Center(child: child)),
      ),
    );
  }

  testWidgets('renders the provided label text', (tester) async {
    await pumpWidget(
      tester,
      PropertyMarkerChip(property: _property(), isSelected: false, onTap: () {}, label: '₹50L'),
    );

    expect(find.text('₹50L'), findsOneWidget);
  });

  testWidgets('calls onTap when chip is tapped', (tester) async {
    var taps = 0;
    await pumpWidget(
      tester,
      PropertyMarkerChip(
        property: _property(),
        isSelected: false,
        onTap: () => taps++,
        label: '₹50L',
      ),
    );

    await tester.tap(find.text('₹50L'));
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('exposes a semantic label using the property title', (tester) async {
    await pumpWidget(
      tester,
      PropertyMarkerChip(
        property: _property(title: 'Sea View'),
        isSelected: false,
        onTap: () {},
        label: '₹50L',
      ),
    );

    final semantics = tester.getSemantics(find.byType(GestureDetector).first);
    expect(semantics.label, contains('Sea View'));
  });

  testWidgets('uses generic semantic label when title is empty', (tester) async {
    await pumpWidget(
      tester,
      PropertyMarkerChip(
        property: _property(title: ''),
        isSelected: false,
        onTap: () {},
        label: '₹50L',
      ),
    );

    final semantics = tester.getSemantics(find.byType(GestureDetector).first);
    expect(semantics.label, contains('Property price marker'));
  });

  testWidgets('selected chip animates the pulse circle', (tester) async {
    await pumpWidget(
      tester,
      PropertyMarkerChip(property: _property(), isSelected: true, onTap: () {}, label: '₹50L'),
    );

    // The pulse animation runs via an AnimatedBuilder; advance the clock so the
    // controller produces a non-zero progress.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The pulse CustomPaint only exists when selected.
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('unselected chip does not render the pulse painter', (tester) async {
    await pumpWidget(
      tester,
      PropertyMarkerChip(property: _property(), isSelected: false, onTap: () {}, label: '₹50L'),
    );

    // No AnimatedBuilder-driven pulse circle for unselected chips.
    final animatedBuilders = tester.widgetList<AnimatedBuilder>(
      find.descendant(of: find.byType(PropertyMarkerChip), matching: find.byType(AnimatedBuilder)),
    );
    expect(animatedBuilders, isEmpty);
  });
}
