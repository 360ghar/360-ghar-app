import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/design/app_design_theme.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/features/location/application/location_source.dart';
import 'package:ghar360/features/location/presentation/widgets/location_explainer.dart';
import 'package:ghar360/features/properties/application/property_location.dart';
import '../../../../helpers/location_test_harness.dart';
import '../../../../helpers/property_query_test_support.dart';
import '../../../../helpers/provider_test_app.dart';
import '../../../../helpers/settings_test_database.dart';

class _RecordingLocation extends QueryLocation {
  _RecordingLocation() : super(PageType.discover);
  final prompts = <bool>[];
  @override
  Future<void> useCurrent({bool forceRefresh = true, bool prompt = true}) async =>
      prompts.add(prompt);
}

void main() {
  late SettingsTestDatabase database;
  late LocationTestDevice device;
  late _RecordingLocation location;
  setUp(() {
    database = SettingsTestDatabase();
    device = LocationTestDevice()..undetermined = true;
    location = _RecordingLocation();
  });

  Future<void> pump(WidgetTester tester, {Locale locale = const Locale('en', 'US')}) async {
    await tester.pumpProviderApp(
      const LocationExplainerGate(child: Scaffold(body: Text('Discover'))),
      locale: locale,
      theme: AppDesignTheme.light(),
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        storageScopeProvider.overrideWith(QueryScope.new),
        deviceLocationSourceProvider.overrideWithValue(device),
        propertyLocationProvider(PageType.discover).overrideWith(() => location),
      ],
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Allow records the choice, then asks the OS once', (tester) async {
    await pump(tester);
    expect(find.text('See homes near you'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('qa.location.explainer.allow')));
    await tester.pumpAndSettle();
    expect(location.prompts, [true]);
    expect(database.values['location_explainer_seen'], isTrue);
    expect(find.text('See homes near you'), findsNothing);
  });

  testWidgets('Not now records the choice and never asks', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('qa.location.explainer.skip')));
    await tester.pumpAndSettle();
    expect(location.prompts, isEmpty);
    expect(database.values['location_explainer_seen'], isTrue);
  });

  testWidgets('seen once, or already decided: nothing is shown', (tester) async {
    database.values['location_explainer_seen'] = true;
    await pump(tester);
    expect(find.text('See homes near you'), findsNothing);
    database.values.clear();
    device.undetermined = false;
    await pump(tester);
    expect(find.text('See homes near you'), findsNothing);
  });

  testWidgets('Hindi explainer fits 320 px at 2x text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpProviderApp(
      const Scaffold(body: LocationExplainerSheet()),
      locale: const Locale('hi', 'IN'),
      textScale: 2,
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('qa.location.explainer.allow')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
