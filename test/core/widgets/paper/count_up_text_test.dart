import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/widgets/paper/count_up_text.dart';

Widget _app(num value, {bool still = false}) => MaterialApp(
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: still),
      child: Center(child: CountUpText(value, format: (v) => '₹${v.round()}')),
    ),
  ),
);

void main() {
  testWidgets('the first frame shows the final value', (tester) async {
    await tester.pumpWidget(_app(43400));
    expect(find.text('₹43400'), findsOneWidget);
    expect(find.bySemanticsLabel('₹43400'), findsOneWidget);
  });

  testWidgets('a new value counts up from the previous one', (tester) async {
    await tester.pumpWidget(_app(100));
    await tester.pumpWidget(_app(200));
    await tester.pump(const Duration(milliseconds: 200));
    final shown = int.parse(tester.widget<Text>(find.byType(Text)).data!.substring(1));
    expect(shown, inExclusiveRange(100, 200));
    expect(find.bySemanticsLabel('₹200'), findsOneWidget, reason: 'readers hear the final value');
    await tester.pumpAndSettle();
    expect(find.text('₹200'), findsOneWidget);
  });

  testWidgets('with reduced motion the value changes at once', (tester) async {
    await tester.pumpWidget(_app(100, still: true));
    await tester.pumpWidget(_app(250, still: true));
    expect(find.text('₹250'), findsOneWidget);
  });
}
