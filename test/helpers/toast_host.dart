import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/translations/app_translations.dart';

/// Pumps a GetMaterialApp host so `AppToast` (which no-ops without an overlay
/// context) can actually render.
Future<void> pumpToastHost(WidgetTester tester) async {
  Get.testMode = true;
  await tester.pumpWidget(
    GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('en', 'US'),
      fallbackLocale: const Locale('en', 'US'),
      home: const Scaffold(body: SizedBox.expand()),
    ),
  );
  await tester.pump();
}

/// Drains the snackbar animations so the Overlay disposes without an active
/// ticker (otherwise the test fails on a pending timer).
Future<void> settleToasts(WidgetTester tester) async {
  Get.closeAllSnackbars();
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
