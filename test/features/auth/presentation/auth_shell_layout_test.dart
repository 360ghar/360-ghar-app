import 'package:flutter/material.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/design/app_design_theme.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/features/auth/presentation/views/phone_entry_view.dart';
import '../../../helpers/auth_form_harness.dart';

Future<AuthFormHarness> _pump(WidgetTester tester, Size size, {double keyboard = 0}) async {
  final h = AuthFormHarness();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: h.container,
      child: MaterialApp(
        theme: AppDesignTheme.light(),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const PhoneEntryView(),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  return h;
}

Future<void> _close(WidgetTester tester, AuthFormHarness h) async {
  await tester.pumpWidget(const SizedBox());
  h.close();
  await tester.pump(const Duration(minutes: 2));
}

void main() {
  Finder titleBox() => find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.identifier == 'qa.auth.shell.title',
  );

  testWidgets('a tall iPad window centers the form, a phone keeps it at the top', (tester) async {
    var h = await _pump(tester, const Size(820, 1180));
    final tablet = tester.getTopLeft(titleBox()).dy;
    await _close(tester, h);
    h = await _pump(tester, const Size(390, 844));
    final phone = tester.getTopLeft(titleBox()).dy;
    await _close(tester, h);
    // Phone: just under the skyline band. Tablet: well below it.
    expect(phone, lessThan(300));
    expect(tablet, greaterThan(300));
  });

  testWidgets('iPad landscape with the keyboard up: Continue scrolls into view', (tester) async {
    final h = await _pump(tester, const Size(1180, 820), keyboard: 420);
    final continueButton = find.byKey(const ValueKey('qa.auth.phone_entry.continue'));
    await tester.ensureVisible(continueButton);
    await tester.pump();
    final rect = tester.getRect(continueButton);
    expect(rect.bottom, lessThanOrEqualTo(820 - 420));
    expect(rect.top, greaterThanOrEqualTo(0));
    await _close(tester, h);
  });

  testWidgets('a right safe-area inset keeps the form clear of the edge', (tester) async {
    final h = AuthFormHarness();
    tester.view.physicalSize = const Size(466, 678);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: h.container,
        child: MaterialApp(
          theme: AppDesignTheme.light(),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(padding: const EdgeInsets.only(right: 84)),
            child: child!,
          ),
          home: const PhoneEntryView(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final field = tester.getRect(
      find.byKey(const ValueKey('qa.auth.phone_entry.identifier_input')),
    );
    expect(field.right, lessThanOrEqualTo(466 - 84));
    await _close(tester, h);
  });
}
