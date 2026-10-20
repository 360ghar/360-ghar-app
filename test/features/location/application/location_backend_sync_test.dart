import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/features/location/application/location_backend_sync.dart';

void main() {
  const near = LocationData(name: 'Delhi', latitude: 28.6, longitude: 77.2);
  const far = LocationData(name: 'Mumbai', latitude: 19.1, longitude: 72.9);
  test('authenticated sync is coalesced and throttled by time and distance', () async {
    var now = DateTime(2026);
    final calls = <LocationData>[];
    final gate = Completer<void>();
    final sync = LocationBackendSync(
      send: (location) async {
        calls.add(location);
        if (calls.length == 1) await gate.future;
      },
      now: () => now,
    );
    final first = sync.sync(near);
    await sync.sync(near);
    expect(calls, hasLength(1));
    gate.complete();
    await first;
    await sync.sync(near);
    expect(calls, hasLength(1));
    await sync.sync(far);
    expect(calls, hasLength(2));
    now = now.add(const Duration(minutes: 2));
    await sync.sync(far);
    expect(calls, hasLength(3));
    sync.dispose();
    await sync.sync(near);
    expect(calls, hasLength(3));
  });
  test('guest has no backend dependency; failure stays separate from local selection', () async {
    await LocationBackendSync(send: null).sync(near);
    var attempts = 0;
    final sync = LocationBackendSync(
      send: (_) async {
        attempts++;
        throw Exception('backend');
      },
    );
    await sync.sync(near);
    await sync.sync(near);
    expect(attempts, 2);
  });
}
