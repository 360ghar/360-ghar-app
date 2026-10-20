import 'package:flutter/material.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/bootstrap/provider_policy.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/app_toast.dart';
import 'package:ghar360/core/utils/image_cache_service.dart';
import 'image_test_cache.dart';

extension ProviderTestApp on WidgetTester {
  Future<void> pumpProviderApp(
    Widget child, {
    Locale locale = const Locale('en', 'US'),
    ThemeData? theme,
    double textScale = 1,
    List<Override> overrides = const [],
  }) => pumpWidget(
    ProviderScope(
      retry: noProviderRetry,
      overrides: [
        if (!overrides.any((override) => override.origin == imageCacheServiceProvider))
          imageCacheServiceProvider.overrideWithValue(ImageTestCache().service),
        ...overrides,
      ],
      child: MaterialApp(
        theme: theme,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: AppToastHost(child: child!),
        ),
        home: child,
      ),
    ),
  );
}
