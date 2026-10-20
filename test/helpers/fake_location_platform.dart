import 'dart:async';

import 'package:geolocator/geolocator.dart';

class FakeGeolocatorPlatform extends GeolocatorPlatform {
  FakeGeolocatorPlatform({
    this.serviceEnabled = true,
    this.permission = LocationPermission.always,
    this.requestedPermission = LocationPermission.always,
    this.lastKnownPosition,
    this.currentPosition,
    this.currentPositionDelay = Duration.zero,
    this.throwOnCurrentPosition = false,
    this.throwOnLastKnown = false,
    this.openSettingsSucceeds = true,
    this.throwOnServiceCheck = false,
    this.timeoutFirstNCurrentPositionCalls = 0,
    this.throwOnPositionStream = false,
  });

  bool serviceEnabled;
  LocationPermission permission;
  LocationPermission requestedPermission;
  Position? lastKnownPosition;
  Position? currentPosition;
  Duration currentPositionDelay;
  bool throwOnCurrentPosition;
  bool throwOnLastKnown;
  bool openSettingsSucceeds;
  bool throwOnServiceCheck;
  int timeoutFirstNCurrentPositionCalls;
  bool throwOnPositionStream;

  int getCurrentPositionCallCount = 0;
  int requestPermissionCallCount = 0;
  StreamController<Position>? positionStreamController;

  @override
  Future<bool> isLocationServiceEnabled() async {
    if (throwOnServiceCheck) throw Exception('service check failed');
    return serviceEnabled;
  }

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    requestPermissionCallCount++;
    return requestedPermission;
  }

  @override
  Future<Position?> getLastKnownPosition({bool forceLocationManager = false}) async {
    if (throwOnLastKnown) throw Exception('last known failed');
    return lastKnownPosition;
  }

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async {
    getCurrentPositionCallCount++;
    if (throwOnCurrentPosition) throw Exception('gps failed');
    // Simulate GPS hang so LocationController's .timeout() paths fire.
    if (timeoutFirstNCurrentPositionCalls > 0 &&
        getCurrentPositionCallCount <= timeoutFirstNCurrentPositionCalls) {
      throw TimeoutException('GPS timeout');
    }
    if (currentPositionDelay > Duration.zero) {
      await Future.delayed(currentPositionDelay);
    }
    return currentPosition ??
        Position(
          latitude: 28.6139,
          longitude: 77.2090,
          timestamp: DateTime.now(),
          accuracy: 10,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
  }

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    if (throwOnPositionStream) {
      throw Exception('stream failed');
    }
    positionStreamController ??= StreamController<Position>.broadcast();
    return positionStreamController!.stream;
  }

  void emitPosition(Position position) {
    positionStreamController?.add(position);
  }

  void emitStreamError(Object error) {
    positionStreamController?.addError(error);
  }

  @override
  Future<bool> openAppSettings() async => openSettingsSucceeds;

  @override
  Future<bool> openLocationSettings() async => openSettingsSucceeds;

  // distanceBetween falls back to the real Haversine implementation in the
  // superclass, which is pure Dart and works in tests.
}

/// Builds a [Position] with sensible test defaults.
Position testPosition({
  double latitude = 28.6139,
  double longitude = 77.2090,
  DateTime? timestamp,
}) {
  return Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: timestamp ?? DateTime.now(),
    accuracy: 10,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}
