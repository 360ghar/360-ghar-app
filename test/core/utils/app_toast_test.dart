import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/design/app_design_theme.dart';
import 'package:ghar360/core/utils/app_toast.dart';

void main() {
  Future<void> host(WidgetTester tester, {bool accessible = false}) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(accessibleNavigation: accessible),
          child: AppToastHost(child: child!),
        ),
        home: const Scaffold(body: Text('Content stays visible')),
      ),
    );
  }

  testWidgets('top toast shows without GetX and expires after its duration', (tester) async {
    await host(tester);
    AppToast.success('Saved', 'Your changes were saved.');
    await tester.pump();
    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('Content stays visible'), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(const ValueKey('qa.toast'))).dy, lessThan(100));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Saved'), findsNothing);
  });

  testWidgets('replacement does not inherit the previous toast timer', (tester) async {
    await host(tester);
    AppToast.error('First');
    await tester.pump(const Duration(seconds: 2));
    AppToast.info('Second');
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Second'), findsOneWidget);
    expect(find.text('First'), findsNothing);
    AppToast.dismiss();
    await tester.pump();
    expect(find.text('Second'), findsNothing);
  });

  testWidgets('disposing the host cancels resources and safely detaches notifications', (
    tester,
  ) async {
    await host(tester);
    AppToast.warning('Check your connection');
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    AppToast.error('No mounted host');
    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('actions remain available for accessible navigation', (tester) async {
    await host(tester, accessible: true);
    var retried = false;
    AppToast.custom(
      title: 'Could not save',
      message: 'Try again.',
      tone: ToastTone.warning,
      mainButton: TextButton(onPressed: () => retried = true, child: const Text('Retry')),
    );
    await tester.pump(const Duration(seconds: 10));
    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
    AppToast.dismiss();
    await tester.pump();
  });

  for (final dark in [false, true]) {
    testWidgets('toast text passes AA on the paper sheet (${dark ? 'dark' : 'light'})', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? AppDesignTheme.dark() : AppDesignTheme.light(),
          builder: (context, child) => AppToastHost(child: child!),
          home: const Scaffold(body: SizedBox()),
        ),
      );
      for (final show in [AppToast.success, AppToast.error, AppToast.warning, AppToast.info]) {
        show('Status', 'Message');
        await tester.pump();
        final background = tester.widget<Material>(find.byKey(const ValueKey('qa.toast'))).color!;
        for (final label in ['Status', 'Message']) {
          final text = tester.widget<Text>(find.text(label));
          final color =
              text.style?.color ??
              DefaultTextStyle.of(tester.element(find.text(label))).style.color!;
          final values = [background.computeLuminance(), color.computeLuminance()]..sort();
          expect((values.last + 0.05) / (values.first + 0.05), greaterThanOrEqualTo(4.5));
        }
      }
      AppToast.dismiss();
      await tester.pump();
    });
  }
}
