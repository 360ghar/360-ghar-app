import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/widgets/common/offline_banner.dart';
import '../../../helpers/provider_test_app.dart';

void main() {
  testWidgets('shows while offline and keeps the app state across changes', (tester) async {
    final links = StreamController<bool>();
    addTearDown(links.close);
    await tester.pumpProviderApp(
      const OfflineBanner(
        child: Scaffold(body: TextField(key: ValueKey('field'))),
      ),
      overrides: [isOnlineProvider.overrideWith((ref) => links.stream)],
    );
    await tester.enterText(find.byKey(const ValueKey('field')), 'Sector 57');
    expect(find.byKey(const ValueKey('qa.offline.banner')), findsNothing);

    links.add(false);
    await tester.pump();
    expect(find.byKey(const ValueKey('qa.offline.banner')), findsOneWidget);
    expect(find.text('You are offline. Saved results stay on screen.'), findsOneWidget);
    expect(find.text('Sector 57'), findsOneWidget);

    links.add(true);
    await tester.pump();
    expect(find.byKey(const ValueKey('qa.offline.banner')), findsNothing);
    expect(find.text('Sector 57'), findsOneWidget);
  });

  testWidgets('Hindi banner fits 320 px at 2x text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpProviderApp(
      const OfflineBanner(child: Scaffold()),
      locale: const Locale('hi', 'IN'),
      textScale: 2,
      overrides: [isOnlineProvider.overrideWith((ref) => Stream.value(false))],
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('qa.offline.banner')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
