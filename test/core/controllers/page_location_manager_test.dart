// PageLocationManager's observable behavior now crosses focused provider and
// platform boundaries. Platform/geocode cases are in location_source_test;
// stream cancellation and UI recovery are in location_providers_test.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/features/location/application/location_backend_sync.dart';
import 'package:ghar360/features/location/application/location_source.dart';
import 'package:ghar360/features/properties/application/property_location.dart';
import '../../helpers/location_test_harness.dart';
import '../../helpers/property_query_test_support.dart' show PropertyQueryHarness, QueryScope;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PropertyQueryHarness store;
  late ProviderContainer container;
  late LocationTestDevice device;
  final synced = <LocationData>[];
  PropertyLocation controller(PageType page) =>
      container.read(propertyLocationProvider(page).notifier);
  PropertyLocationState state(PageType page) => container.read(propertyLocationProvider(page));
  Future<void> hydrate(PageType page) async {
    controller(page).setVisible(false);
    await controller(page).ensureLocation();
  }

  ProviderContainer owner() => ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(store.database),
      storageScopeProvider.overrideWith(QueryScope.new),
      deviceLocationSourceProvider.overrideWithValue(device),
      locationBackendSyncProvider.overrideWithValue(
        LocationBackendSync(
          send: (location) async {
            synced.add(location);
          },
        ),
      ),
    ],
  );
  setUp(() async {
    store = await PropertyQueryHarness.create();
    device = LocationTestDevice();
    synced.clear();
    container = owner();
  });
  tearDown(() async {
    container.dispose();
    await device.stream.close();
    await store.close();
  });

  test('manual location persists for one page and hydration does not ask for GPS', () async {
    await hydrate(PageType.explore);
    expect(await controller(PageType.explore).select(delhi), isTrue);
    await hydrate(PageType.likes);
    expect(state(PageType.likes).location, isNull);
    container.dispose();
    container = owner();
    await hydrate(PageType.explore);
    expect(state(PageType.explore).location?.toJson(), delhi.toJson());
    expect(state(PageType.explore).source, LocationSource.manual);
    expect(device.currentCalls, 0);
    expect(synced, isEmpty);
  });

  test('all page locations remain independent through SQLite hydration', () async {
    for (final page in PageType.values) {
      await hydrate(page);
      await controller(
        page,
      ).select(LocationData(name: page.name, latitude: 20 + page.index.toDouble(), longitude: 70));
    }
    container.dispose();
    container = owner();
    for (final page in PageType.values) {
      await hydrate(page);
      expect(state(page).location?.name, page.name);
    }
  });

  test('account transition hides old location and returning account restores its draft', () async {
    await hydrate(PageType.explore);
    await controller(PageType.explore).select(delhi);
    final scope = container.read(storageScopeProvider.notifier) as QueryScope;
    scope.change('b');
    await hydrate(PageType.explore);
    expect(state(PageType.explore).location, isNull);
    await controller(PageType.explore).select(mumbai);
    scope.change('a');
    await hydrate(PageType.explore);
    expect(state(PageType.explore).location?.toJson(), delhi.toJson());
  });

  test('GPS source syncs profile while manual and IP selections remain local', () async {
    await hydrate(PageType.discover);
    await controller(PageType.discover).select(delhi, source: LocationSource.manual);
    await controller(PageType.discover).select(mumbai, source: LocationSource.ip);
    expect(synced, isEmpty);
    device.response = () async => const LocationResolution(delhi, LocationSource.gps);
    await controller(PageType.discover).useCurrent();
    expect(state(PageType.discover).source, LocationSource.gps);
    expect(synced.single.toJson(), delhi.toJson());
  });

  test('invalid coordinates cannot replace or overwrite a valid saved location', () async {
    await hydrate(PageType.explore);
    await controller(PageType.explore).select(delhi);
    for (final invalid in [
      const LocationData(name: 'Invalid', latitude: 91, longitude: 70),
      const LocationData(name: 'Invalid', latitude: 20, longitude: 181),
      const LocationData(name: 'Invalid', latitude: double.nan, longitude: 70),
    ]) {
      expect(await controller(PageType.explore).select(invalid), isFalse);
      expect(state(PageType.explore).location?.toJson(), delhi.toJson());
    }
    container.dispose();
    container = owner();
    await hydrate(PageType.explore);
    expect(state(PageType.explore).location?.toJson(), delhi.toJson());
  });
}
