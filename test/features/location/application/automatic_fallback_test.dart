import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/features/location/application/location_backend_sync.dart';
import 'package:ghar360/features/location/application/location_source.dart';
import 'package:ghar360/features/properties/application/property_location.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../../helpers/fake_location_platform.dart';
import '../../../helpers/location_test_harness.dart';

/// The silent automatic read: whatever stops it, the page starts in Gurugram.
void main() {
  Future<PropertyLocationState> automatic(
    FakeGeolocatorPlatform gps, {
    http.Response? ip,
    LocationData? saved,
  }) async {
    final database = LocationTestDatabase();
    if (saved != null) {
      database.drafts['test:a:location:discover'] = {
        'location': saved.toJson(),
        'source': 'manual',
      };
    }
    final device = DeviceLocationSource(
      MockClient((_) async => ip ?? http.Response('', 503)),
      gps: gps,
      reverseGeocode: (_, _) async => [],
    );
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        storageScopeProvider.overrideWith(() => LocationScopeNotifier(database)),
        deviceLocationSourceProvider.overrideWithValue(device),
        locationBackendSyncProvider.overrideWithValue(LocationBackendSync(send: null)),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(propertyLocationProvider(PageType.discover).notifier);
    await notifier.ensureLocation();
    return container.read(propertyLocationProvider(PageType.discover));
  }

  void expectGurugram(PropertyLocationState state) {
    expect(state.source, LocationSource.fallback);
    expect(state.location?.name, 'Gurugram');
    expect(state.load.hasError, isFalse);
  }

  test('prompt skipped (permission not asked) and the IP lookup fails', () async {
    expectGurugram(await automatic(FakeGeolocatorPlatform(permission: LocationPermission.denied)));
  });
  test('permission denied for good', () async {
    expectGurugram(
      await automatic(FakeGeolocatorPlatform(permission: LocationPermission.deniedForever)),
    );
  });
  test('location services off and the IP lookup is rate limited (429)', () async {
    expectGurugram(
      await automatic(
        FakeGeolocatorPlatform(serviceEnabled: false),
        ip: http.Response('{"error":true}', 429),
      ),
    );
  });
  test('services off, IP lookup works but is outside the area', () async {
    expectGurugram(
      await automatic(
        FakeGeolocatorPlatform(serviceEnabled: false),
        ip: http.Response('{"latitude":37.33,"longitude":-122.0,"city":"Cupertino"}', 200),
      ),
    );
  });
  test('GPS fix times out', () async {
    expectGurugram(await automatic(FakeGeolocatorPlatform(throwOnCurrentPosition: true)));
  });
  test('an in-area GPS fix is kept', () async {
    final state = await automatic(
      FakeGeolocatorPlatform(currentPosition: testPosition(latitude: 28.5, longitude: 77.1)),
    );
    expect(state.source, LocationSource.gps);
  });
  test('a saved manual pick is never replaced', () async {
    const noida = LocationData(name: 'Noida', latitude: 28.5355, longitude: 77.391);
    final state = await automatic(
      FakeGeolocatorPlatform(permission: LocationPermission.denied),
      saved: noida,
    );
    expect(state.source, LocationSource.manual);
    expect(state.location?.name, 'Noida');
  });
}
