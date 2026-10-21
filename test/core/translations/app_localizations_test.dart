import 'package:flutter/material.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/translations/app_messages.dart';

void main() {
  test('English and Hindi retain complete key parity', () {
    expect(appMessages['en_US']!.keys.toSet(), appMessages['hi_IN']!.keys.toSet());
  });

  test('supports both catalog parameter forms without recursive substitution', () {
    const english = AppLocalizations(Locale('en', 'US'));
    expect(english.text('bedrooms_short', params: {'count': '3'}), '3 BHK');
    expect(english.text('page_of', params: {'current': '1', 'total': '4'}), 'Page 1 of 4');
    expect(
      english.text('page_of', params: {'current': '{total}', 'total': '4'}),
      'Page {total} of 4',
    );
  });

  test('resolves Hindi by language and safely falls back for unknown locales', () {
    expect(const AppLocalizations(Locale('hi')).text('retry'), appMessages['hi_IN']!['retry']);
    expect(const AppLocalizations(Locale('xx')).text('retry'), 'Retry');
    expect(const AppLocalizations(Locale('en')).text('unknown_test_key'), 'unknown_test_key');
    expect(AppLocalizations.delegate.isSupported(const Locale('hi')), isTrue);
    expect(AppLocalizations.delegate.isSupported(const Locale('xx')), isFalse);
  });

  testWidgets('Flutter locale changes rebuild the localized consumer', (tester) async {
    Widget app(Locale locale) => MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Builder(builder: (context) => Text(context.l10n.text('retry'))),
    );
    await tester.pumpWidget(app(const Locale('en', 'US')));
    expect(find.text('Retry'), findsOneWidget);
    await tester.pumpWidget(app(const Locale('hi', 'IN')));
    await tester.pump();
    expect(find.text(appMessages['hi_IN']!['retry']!), findsOneWidget);
  });
}
