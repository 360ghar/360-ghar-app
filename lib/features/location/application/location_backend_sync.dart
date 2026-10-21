import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'package:ghar360/core/bootstrap/provider_policy.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/providers/auth_providers.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/utils/debug_logger.dart';

final locationBackendSyncProvider = Provider<LocationBackendSync>((ref) {
  final scope = ref.watch(storageScopeProvider);
  final sync = LocationBackendSync(
    send: scope.accountId == null
        ? null
        : (location) async {
            if (!ref.mounted || !identical(ref.read(storageScopeProvider), scope)) return;
            await ref
                .read(profileRepositoryProvider)
                .updateUserLocation(latitude: location.latitude, longitude: location.longitude);
          },
  );
  ref.onDispose(sync.dispose);
  return sync;
}, retry: noProviderRetry);

/// Best-effort backend metadata. It must never block local/manual selection.
class LocationBackendSync {
  LocationBackendSync({required this._send, DateTime Function()? now}) : _now = now ?? DateTime.now;
  final Future<void> Function(LocationData)? _send;
  final DateTime Function() _now;
  LocationData? _last;
  DateTime? _lastAt;
  bool _busy = false;
  bool _disposed = false;
  LocationData? _pending;
  Future<void> sync(LocationData location) async {
    if (_send == null || _disposed) return;
    if (_busy) {
      // Keep only the newest fix; it is sent after the call in flight.
      _pending = location;
      return;
    }
    if (_last != null &&
        _lastAt != null &&
        _now().difference(_lastAt!) < const Duration(minutes: 2) &&
        Geolocator.distanceBetween(
              _last!.latitude,
              _last!.longitude,
              location.latitude,
              location.longitude,
            ) <
            250) {
      return;
    }
    _busy = true;
    try {
      await _send(location);
      if (!_disposed) {
        _last = location;
        _lastAt = _now();
      }
    } catch (error, stack) {
      DebugLogger.warning('Location profile sync failed.', error.runtimeType, stack);
    } finally {
      _busy = false;
    }
    final next = _pending;
    _pending = null;
    if (next != null && !_disposed) await sync(next);
  }

  void dispose() => _disposed = true;
}
