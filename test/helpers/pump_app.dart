import 'package:flutter/material.dart';

import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'provider_test_app.dart';

/// Shared Flutter shell with real localization and isolated provider ownership.
extension PumpApp on WidgetTester {
  Future<void> pumpApp(
    Widget widget, {
    ThemeData? theme,
    Locale? locale,
    List<Override> overrides = const [],
  }) => pumpProviderApp(
    widget,
    theme: theme ?? ThemeData.light(),
    locale: locale ?? const Locale('en', 'US'),
    overrides: overrides,
  );

  Future<void> pumpAndSettleApp(
    Widget widget, {
    ThemeData? theme,
    Locale? locale,
    List<Override> overrides = const [],
  }) async {
    await pumpApp(widget, theme: theme, locale: locale, overrides: overrides);
    await pumpAndSettle();
  }
}
