import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/utils/app_toast.dart';
import 'provider_test_app.dart';

/// A real overlay host owns toast entries and timers for each test.
Future<void> pumpToastHost(WidgetTester tester) async {
  await tester.pumpProviderApp(const Scaffold(body: SizedBox.expand()));
  await tester.pump();
}

Future<void> settleToasts(WidgetTester tester) async {
  AppToast.dismiss();
  await tester.pumpAndSettle();
}
