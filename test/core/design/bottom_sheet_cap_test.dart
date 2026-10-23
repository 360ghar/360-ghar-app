import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/design/app_design_theme.dart';

void main() {
  testWidgets('a modal sheet is at most 560 wide on a 1032 wide window', (tester) async {
    tester.view.physicalSize = const Size(1032, 1376);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.light(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              builder: (_) =>
                  const SizedBox(key: ValueKey('sheet.body'), width: double.infinity, height: 200),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final box = tester.getRect(find.byKey(const ValueKey('sheet.body')));
    expect(box.width, 560);
    expect(box.center.dx, 516, reason: 'the sheet is centred');
  });

  testWidgets('a modal sheet still fills a 390 wide phone', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.light(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              builder: (_) =>
                  const SizedBox(key: ValueKey('sheet.body'), width: double.infinity, height: 200),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(const ValueKey('sheet.body'))).width, 390);
  });
}
