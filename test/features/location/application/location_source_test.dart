import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/location/application/location_source.dart';
import '../../../helpers/fake_location_platform.dart';

class _PermissionFailure extends FakeGeolocatorPlatform {
  @override
  Future<LocationPermission> checkPermission() async => throw Exception('permission failed');
}

class _SettingsFailure extends FakeGeolocatorPlatform {
  @override
  Future<bool> openAppSettings() async => throw Exception('settings failed');
  @override
  Future<bool> openLocationSettings() async => throw Exception('settings failed');
}

class _HangingGps extends FakeGeolocatorPlatform {
  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) {
    getCurrentPositionCallCount++;
    return Completer<Position>().future;
  }
}

void main() {
  DeviceLocationSource source({
    FakeGeolocatorPlatform? gps,
    Future<List<Placemark>> Function(double, double)? geocode,
    Future<http.Response> Function(http.Request)? request,
    DateTime Function()? now,
  }) {
    final value = DeviceLocationSource(
      MockClient(request ?? (_) async => http.Response('', 503)),
      gps: gps ?? FakeGeolocatorPlatform(),
      reverseGeocode: geocode ?? (_, _) async => [],
      now: now,
    );
    addTearDown(value.dispose);
    return value;
  }

  test('GPS returns coordinates and explicit source', () async {
    final gps = FakeGeolocatorPlatform(
      currentPosition: testPosition(latitude: 19.1, longitude: 72.9),
    );
    final result = await source(gps: gps).current(allowIpFallback: false);
    expect(result.source, LocationSource.gps);
    expect(result.location.latitude, 19.1);
    expect(result.location.longitude, 72.9);
    expect(result.location.name, '19.100, 72.900');
    expect(gps.getCurrentPositionCallCount, 1);
  });
  for (final entry in [
    (LocationPermission.denied, 'LOCATION_DENIED'),
    (LocationPermission.deniedForever, 'LOCATION_DENIED_FOREVER'),
  ]) {
    test('permission ${entry.$1} remains a typed recovery state', () async {
      final gps = FakeGeolocatorPlatform(permission: entry.$1, requestedPermission: entry.$1);
      await expectLater(
        source(gps: gps).current(allowIpFallback: false),
        throwsA(isA<LocationException>().having((error) => error.code, 'code', entry.$2)),
      );
      expect(gps.getCurrentPositionCallCount, 0);
    });
  }
  test('disabled services are typed and skip GPS', () async {
    final gps = FakeGeolocatorPlatform(serviceEnabled: false);
    await expectLater(
      source(gps: gps).current(allowIpFallback: false),
      throwsA(isA<LocationException>().having((error) => error.code, 'code', 'LOCATION_DISABLED')),
    );
    expect(gps.getCurrentPositionCallCount, 0);
  });
  test('concurrent requests share one permission prompt and GPS request', () async {
    final gps = FakeGeolocatorPlatform(
      permission: LocationPermission.denied,
      requestedPermission: LocationPermission.whileInUse,
    );
    final device = source(gps: gps);
    final result = await Future.wait([device.current(), device.current()]);
    expect(result[0].location.latitude, result[1].location.latitude);
    expect(gps.requestPermissionCallCount, 1);
    expect(gps.getCurrentPositionCallCount, 1);
  });
  test('a silent read never asks; an explicit read after it still asks', () async {
    final gps = FakeGeolocatorPlatform(
      permission: LocationPermission.denied,
      requestedPermission: LocationPermission.whileInUse,
    );
    final device = source(gps: gps);
    expect(await device.permissionUndetermined(), isTrue);
    await expectLater(
      device.current(allowIpFallback: false, prompt: false),
      throwsA(isA<LocationException>().having((e) => e.code, 'code', 'LOCATION_NOT_ASKED')),
    );
    expect(gps.requestPermissionCallCount, 0);
    await device.current(allowIpFallback: false);
    expect(gps.requestPermissionCallCount, 1);
  });
  test('service/permission/platform exceptions have no raw user message', () async {
    for (final gps in [
      FakeGeolocatorPlatform(throwOnServiceCheck: true),
      _PermissionFailure(),
      FakeGeolocatorPlatform(throwOnCurrentPosition: true),
    ]) {
      await expectLater(
        source(gps: gps).current(allowIpFallback: false),
        throwsA(isA<LocationException>()),
      );
    }
  });
  test('fresh last-known position avoids GPS and force refresh bypasses it', () async {
    final gps = FakeGeolocatorPlatform(
      lastKnownPosition: testPosition(latitude: 25),
      currentPosition: testPosition(latitude: 26),
    );
    final device = source(gps: gps);
    expect((await device.current(allowIpFallback: false)).location.latitude, 25);
    expect(gps.getCurrentPositionCallCount, 0);
    expect(
      (await device.current(allowIpFallback: false, forceRefresh: true)).location.latitude,
      26,
    );
    expect(gps.getCurrentPositionCallCount, 1);
    expect((await device.current(allowIpFallback: false)).location.latitude, 26);
    expect(gps.getCurrentPositionCallCount, 1);
  });
  test('last-known failure still permits fresh GPS', () async {
    final gps = FakeGeolocatorPlatform(throwOnLastKnown: true);
    expect((await source(gps: gps).current(allowIpFallback: false)).source, LocationSource.gps);
    expect(gps.getCurrentPositionCallCount, 1);
  });
  test('current GPS failure retains usable last-known position, rejects old cache', () async {
    final gps = FakeGeolocatorPlatform(
      lastKnownPosition: testPosition(
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
      throwOnCurrentPosition: true,
    );
    expect((await source(gps: gps).current(allowIpFallback: false)).source, LocationSource.gps);
    final stale = FakeGeolocatorPlatform(
      lastKnownPosition: testPosition(
        timestamp: DateTime.now().subtract(const Duration(minutes: 11)),
      ),
      throwOnCurrentPosition: true,
    );
    await expectLater(
      source(gps: stale).current(allowIpFallback: false),
      throwsA(isA<LocationException>()),
    );
  });
  test('GPS accuracy fallback reaches low after two timeouts', () async {
    final gps = FakeGeolocatorPlatform(timeoutFirstNCurrentPositionCalls: 2);
    expect((await source(gps: gps).current(allowIpFallback: false)).source, LocationSource.gps);
    expect(gps.getCurrentPositionCallCount, 3);
  });
  testWidgets('GPS plugin hang is bounded to 8 + 5 + 3 seconds', (tester) async {
    final gps = _HangingGps();
    final device = source(gps: gps);
    Object? error;
    device
        .current(allowIpFallback: false)
        .then<void>(
          (_) {},
          onError: (Object value) {
            error = value;
          },
        );
    await tester.pump();
    await tester.pump(const Duration(seconds: 8));
    expect(gps.getCurrentPositionCallCount, 2);
    await tester.pump(const Duration(seconds: 5));
    expect(gps.getCurrentPositionCallCount, 3);
    await tester.pump(const Duration(seconds: 3));
    expect(error, isA<LocationException>());
  });
  for (final payload in [
    {'latitude': 28.6, 'longitude': 77.2, 'city': 'Delhi', 'region': 'NCR'},
    {'latitude': '28.6', 'longitude': '77.2', 'city': 'Delhi'},
  ]) {
    test('IP resolves numeric/string coordinates and available city names $payload', () async {
      final result = await source(
        gps: FakeGeolocatorPlatform(serviceEnabled: false),
        request: (_) async => http.Response(jsonEncode(payload), 200),
      ).current();
      expect(result.source, LocationSource.ip);
      expect(result.location.latitude, 28.6);
      expect(result.location.longitude, 77.2);
      expect(result.location.name, contains('Delhi'));
    });
  }
  for (final response in [
    http.Response('', 503),
    http.Response('{}', 200),
    http.Response('{bad', 200),
    http.Response('{"latitude":"NaN","longitude":77}', 200),
    http.Response('{"latitude":95,"longitude":77}', 200),
  ]) {
    test('invalid IP response ${response.body} is not a location', () async {
      expect(await source(request: (_) async => response).ipLocation(), isNull);
    });
  }
  test('IP timeout and missing GPS produce a typed failure', () async {
    final device = source(
      gps: FakeGeolocatorPlatform(serviceEnabled: false),
      request: (_) async => throw TimeoutException('request'),
    );
    expect(await device.ipLocation(), isNull);
    await expectLater(device.current(), throwsA(isA<LocationException>()));
  });
  for (final entry in <(Placemark, String)>[
    (
      const Placemark(subLocality: 'Area', locality: 'City', administrativeArea: 'State'),
      'Area, City',
    ),
    (const Placemark(locality: 'City', administrativeArea: 'State'), 'City, State'),
    (const Placemark(locality: 'City'), 'City'),
    (const Placemark(street: 'Street'), 'Street'),
    (const Placemark(name: 'Name', administrativeArea: 'State'), 'Name, State'),
    (const Placemark(), '28.000, 77.000'),
  ]) {
    test('reverse geocode formats ${entry.$2}', () async {
      expect(await source(geocode: (_, _) async => [entry.$1]).address(28, 77), entry.$2);
    });
  }
  test('empty and failed geocoding preserve usable coordinates', () async {
    expect(await source(geocode: (_, _) async => []).address(28, 77), '28.000, 77.000');
    expect(
      await source(geocode: (_, _) async => throw Exception('failed')).address(28, 77),
      '28.000, 77.000',
    );
  });
  test('geocoding is throttled for nearby movement and refreshes after two minutes', () async {
    var now = DateTime(2026);
    var calls = 0;
    final device = source(
      now: () => now,
      geocode: (_, _) async {
        calls++;
        return [const Placemark(locality: 'City')];
      },
    );
    await device.locationFor(testPosition());
    await device.locationFor(testPosition(latitude: 28.614));
    expect(calls, 1);
    now = now.add(const Duration(minutes: 2));
    await device.locationFor(testPosition());
    expect(calls, 2);
    await device.locationFor(testPosition(latitude: 29));
    expect(calls, 3);
  });
  test('positions and settings use the injected platform and dispose safely', () async {
    final gps = FakeGeolocatorPlatform();
    final device = source(gps: gps);
    final positions = <Position>[];
    final subscription = device.positions().listen(positions.add);
    gps.emitPosition(testPosition(latitude: 25));
    await Future<void>.value();
    expect(positions.single.latitude, 25);
    expect(await device.openAppSettings(), isTrue);
    expect(await device.openLocationSettings(), isTrue);
    await subscription.cancel();
    await gps.positionStreamController!.close();
    device.dispose();
    await expectLater(device.current(), throwsA(isA<NetworkException>()));
  });
  test('settings failures remain available for UI recovery', () async {
    final device = source(gps: _SettingsFailure());
    await expectLater(device.openAppSettings(), throwsException);
    await expectLater(device.openLocationSettings(), throwsException);
    final denied = source(gps: FakeGeolocatorPlatform(openSettingsSucceeds: false));
    expect(await denied.openAppSettings(), isFalse);
    expect(await denied.openLocationSettings(), isFalse);
  });
}
