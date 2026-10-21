import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/design/app_design_tokens.dart';
import 'package:ghar360/core/design/paper/paper_chrome.dart';
import 'package:ghar360/features/explore/presentation/widgets/property_marker_chip.dart';
import '../../../../helpers/provider_test_app.dart';

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
  Future<void> pumpWidget(WidgetTester tester, Widget child) async {
    await tester.pumpProviderApp(Scaffold(body: Center(child: child)));
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

  testWidgets('selected marker is a gold slip with ink text; nothing pulses', (tester) async {
    await pumpWidget(
      tester,
      PropertyMarkerChip(property: _property(), isSelected: true, onTap: () {}, label: '₹50L'),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final slip = tester.widget<DecoratedBox>(
      find.descendant(of: find.byType(PropertyMarkerChip), matching: find.byType(DecoratedBox)),
    );
    final decoration = slip.decoration as ShapeDecoration;
    expect(decoration.color, AppDesignTokens.gold500);
    expect(decoration.shape, isA<CutBorder>());
    expect(tester.widget<Text>(find.text('₹50L')).style?.color, AppDesignTokens.ink900);
    expect(tester.hasRunningAnimations, isFalse);
    expect(
      find.descendant(of: find.byType(PropertyMarkerChip), matching: find.byType(AnimatedBuilder)),
      findsNothing,
    );
  });

  testWidgets('unselected marker is a paper slip', (tester) async {
    await pumpWidget(
      tester,
      PropertyMarkerChip(property: _property(), isSelected: false, onTap: () {}, label: '₹50L'),
    );
    final slip = tester.widget<DecoratedBox>(
      find.descendant(of: find.byType(PropertyMarkerChip), matching: find.byType(DecoratedBox)),
    );
    expect((slip.decoration as ShapeDecoration).color, AppDesignTokens.paper);
  });
  testWidgets('reduced motion stops selected-marker animation with a 48px target', (tester) async {
    await pumpWidget(
      tester,
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: PropertyMarkerChip(
          property: _property(),
          isSelected: true,
          onTap: () {},
          label: '₹50 लाख',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
    expect(tester.getSize(find.byType(GestureDetector).first).height, greaterThanOrEqualTo(48));
  });
}
