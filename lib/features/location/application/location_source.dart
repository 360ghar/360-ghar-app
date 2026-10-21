import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ghar360/core/bootstrap/provider_policy.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:http/http.dart' as http;

final deviceLocationSourceProvider = Provider<DeviceLocationSource>((ref) {
  final source = DeviceLocationSource(http.Client());
  ref.onDispose(source.dispose);
  return source;
}, retry: noProviderRetry);

class LocationResolution {
  const LocationResolution(this.location, this.source);
  final LocationData location;
  final LocationSource source;
}

/// Owns the external location boundaries. Permission errors remain typed so
/// the picker can offer manual selection and the correct settings action.
class DeviceLocationSource {
  DeviceLocationSource(
    this._client, {
    GeolocatorPlatform? gps,
    Future<List<Placemark>> Function(double, double)? reverseGeocode,
    DateTime Function()? now,
  }) : _gps = gps ?? GeolocatorPlatform.instance,
       _reverseGeocode = reverseGeocode ?? Geocoding().placemarkFromCoordinates,
       _now = now ?? DateTime.now;
  final GeolocatorPlatform _gps;
  final Future<List<Placemark>> Function(double, double) _reverseGeocode;
  final DateTime Function() _now;
  final http.Client _client;
  final _inFlight = <(bool, bool, bool), Future<LocationResolution>>{};

  /// Keyed by whether the read may show the OS prompt, so a tap on "Allow"
  /// never joins a silent read that skipped it.
  final _gpsInFlight = <bool, Future<LocationResolution>>{};
  Position? _lastPosition;
  Position? _lastAddressPosition;
  DateTime? _lastAddressAt;
  String? _lastAddress;
  final Map<String, (DateTime, String)> _addresses = {};
  bool _disposed = false;

  /// The device location. With [prompt] false an undecided permission is not
  /// asked for; the read falls back to the IP location instead.
  Future<LocationResolution> current({
    bool allowIpFallback = true,
    bool forceRefresh = false,
    bool prompt = true,
  }) {
    final key = (allowIpFallback, forceRefresh, prompt);
    final inFlight = _inFlight[key];
    if (inFlight != null) return inFlight;
    final future = _current(
      allowIpFallback: allowIpFallback,
      forceRefresh: forceRefresh,
      prompt: prompt,
    );
    _inFlight[key] = future;
    return future.whenComplete(() {
      if (identical(_inFlight[key], future)) _inFlight.remove(key);
    });
  }

  Future<LocationResolution> _gpsLocation(bool forceRefresh, bool prompt) {
    final inFlight = _gpsInFlight[prompt];
    if (inFlight != null) return inFlight;
    final future = _readGps(forceRefresh: forceRefresh, prompt: prompt);
    _gpsInFlight[prompt] = future;
    return future.whenComplete(() {
      if (identical(_gpsInFlight[prompt], future)) _gpsInFlight.remove(prompt);
    });
  }

  /// True when the user has not yet been asked for location permission.
  Future<bool> permissionUndetermined() async {
    try {
      return await _gps.checkPermission() == LocationPermission.denied;
    } on Object {
      return false;
    }
  }

  Future<LocationResolution> _current({
    required bool allowIpFallback,
    required bool forceRefresh,
    required bool prompt,
  }) async {
    try {
      return await _gpsLocation(forceRefresh, prompt);
    } catch (error) {
      if (_disposed) throw NetworkException('Cancelled', code: 'CANCELLED');
      if (allowIpFallback) {
        final approximate = await ipLocation();
        if (approximate != null) return LocationResolution(approximate, LocationSource.ip);
      }
      if (error is AppException) rethrow;
      throw LocationException('Location unavailable', code: 'LOCATION_UNAVAILABLE');
    }
  }

  Future<LocationResolution> _readGps({required bool forceRefresh, required bool prompt}) async {
    try {
      if (!await _gps.isLocationServiceEnabled()) {
        throw LocationException('Location service disabled', code: 'LOCATION_DISABLED');
      }
      var permission = await _gps.checkPermission();
      if (permission == LocationPermission.denied) {
        if (!prompt) {
          throw LocationException('Location permission not asked yet', code: 'LOCATION_NOT_ASKED');
        }
        permission = await _gps.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        throw LocationException('Location permission blocked', code: 'LOCATION_DENIED_FOREVER');
      }
      if (permission != LocationPermission.always && permission != LocationPermission.whileInUse) {
        throw LocationException('Location permission denied', code: 'LOCATION_DENIED');
      }
      Position? last = _lastPosition;
      try {
        last ??= await _gps.getLastKnownPosition();
      } on Object {
        /* GPS can still resolve. */
      }
      if (!forceRefresh &&
          last != null &&
          _now().difference(last.timestamp) <= const Duration(minutes: 2)) {
        return LocationResolution(await locationFor(last), LocationSource.gps);
      }
      Position? current;
      for (final attempt in const [
        (LocationAccuracy.high, Duration(seconds: 8)),
        (LocationAccuracy.medium, Duration(seconds: 5)),
        (LocationAccuracy.low, Duration(seconds: 3)),
      ]) {
        if (_disposed) throw NetworkException('Cancelled', code: 'CANCELLED');
        try {
          current = await _gps
              .getCurrentPosition(
                locationSettings: LocationSettings(accuracy: attempt.$1, timeLimit: attempt.$2),
              )
              .timeout(attempt.$2);
          break;
        } on TimeoutException {
          continue;
        } on Object {
          break;
        }
      }
      if (current != null) {
        _lastPosition = current;
        return LocationResolution(await locationFor(current), LocationSource.gps);
      }
      if (last != null && _now().difference(last.timestamp) <= const Duration(minutes: 10)) {
        return LocationResolution(await locationFor(last), LocationSource.gps);
      }
      throw LocationException('Location timed out', code: 'LOCATION_TIMEOUT');
    } on AppException {
      rethrow;
    } on Object {
      throw LocationException('Location unavailable', code: 'LOCATION_UNAVAILABLE');
    }
  }

  Future<LocationData> locationFor(Position position) async {
    if (!position.latitude.isFinite ||
        !position.longitude.isFinite ||
        position.latitude.abs() > 90 ||
        position.longitude.abs() > 180) {
      throw LocationException('Invalid device coordinates', code: 'LOCATION_UNAVAILABLE');
    }
    if (_disposed) throw NetworkException('Cancelled', code: 'CANCELLED');
    final previous = _lastAddressPosition;
    final reuse =
        previous != null &&
        _lastAddressAt != null &&
        _lastAddress != null &&
        _now().difference(_lastAddressAt!) < const Duration(minutes: 2) &&
        Geolocator.distanceBetween(
              previous.latitude,
              previous.longitude,
              position.latitude,
              position.longitude,
            ) <
            100;
    final name = reuse ? _lastAddress! : await address(position.latitude, position.longitude);
    if (_disposed) throw NetworkException('Cancelled', code: 'CANCELLED');
    if (!reuse) {
      _lastAddress = name;
      _lastAddressPosition = position;
      _lastAddressAt = _now();
    }
    return LocationData(name: name, latitude: position.latitude, longitude: position.longitude);
  }

  Future<String> address(double latitude, double longitude) async {
    final key = '${latitude.toStringAsFixed(3)}:${longitude.toStringAsFixed(3)}';
    final cached = _addresses[key];
    if (cached != null && _now().difference(cached.$1) < const Duration(minutes: 2)) {
      return cached.$2;
    }
    try {
      final places = await _reverseGeocode(latitude, longitude).timeout(const Duration(seconds: 5));
      if (places.isNotEmpty) {
        final place = places.first;
        final parts = [
          place.subLocality,
          place.locality,
          place.administrativeArea,
        ].whereType<String>().where((part) => part.trim().isNotEmpty).toSet().toList();
        if ((place.locality ?? '').trim().isEmpty && (place.subLocality ?? '').trim().isEmpty) {
          parts.clear();
          if ((place.street ?? '').trim().isNotEmpty) {
            parts.add(place.street!);
          } else {
            parts.addAll(
              [
                place.name,
                place.administrativeArea,
              ].whereType<String>().where((part) => part.trim().isNotEmpty),
            );
          }
        }
        if (parts.isNotEmpty) {
          final name = parts.take(2).join(', ');
          if (_addresses.length >= 128) _addresses.remove(_addresses.keys.first);
          _addresses[key] = (_now(), name);
          return name;
        }
      }
    } on Object {
      // Coordinates are still usable when reverse geocoding is unavailable.
    }
    return '${latitude.toStringAsFixed(3)}, ${longitude.toStringAsFixed(3)}';
  }

  Future<LocationData?> ipLocation() async {
    try {
      final response = await _client
          .get(Uri.parse('https://ipapi.co/json/'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final latitude = double.tryParse('${data['latitude']}');
      final longitude = double.tryParse('${data['longitude']}');
      if (latitude == null ||
          longitude == null ||
          !latitude.isFinite ||
          !longitude.isFinite ||
          latitude.abs() > 90 ||
          longitude.abs() > 180) {
        return null;
      }
      return LocationData(
        name: [data['city'], data['region']].whereType<String>().toSet().join(', '),
        latitude: latitude,
        longitude: longitude,
      );
    } on Object {
      return null;
    }
  }

  Stream<Position> positions() => _gps.getPositionStream(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 300),
  );
  Future<bool> openAppSettings() => _gps.openAppSettings();
  Future<bool> openLocationSettings() => _gps.openLocationSettings();
  void dispose() {
    _disposed = true;
    _client.close();
  }
}
