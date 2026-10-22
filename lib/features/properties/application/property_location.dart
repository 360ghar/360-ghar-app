import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/bootstrap/provider_policy.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/features/location/application/location_backend_sync.dart';
import 'package:ghar360/features/location/application/location_source.dart';

class PropertyLocationState {
  const PropertyLocationState({
    this.location,
    this.source = LocationSource.initial,
    this.load = const AsyncData(null),
    this.save = const AsyncData(null),
  });
  final LocationData? location;
  final LocationSource source;
  final AsyncValue<void> load;
  final AsyncValue<void> save;
}

final propertyLocationProvider =
    NotifierProvider.family<PropertyLocation, PropertyLocationState, PageType>(
      PropertyLocation.new,
      retry: noProviderRetry,
    );

class PropertyLocation extends Notifier<PropertyLocationState> {
  PropertyLocation(this.page);
  final PageType page;
  int _generation = 0;
  int _positionGeneration = 0;
  int _loadGeneration = 0;
  Future<void> _writes = Future.value();
  Future<void> _hydration = Future.value();
  StreamSubscription<Object?>? _positions;
  bool _visible = false;
  bool _visibilityKnown = false;
  bool _readFailed = false;

  @override
  PropertyLocationState build() {
    ref.watch(storageScopeProvider);
    final database = ref.watch(appDatabaseProvider);
    final legacy = database.readPreference<Map>('${page.name}_state');
    final saved = legacy?['selectedLocation'] is Map
        ? LocationData.tryFromJson(Map<String, dynamic>.from(legacy!['selectedLocation'] as Map))
        : null;
    ref.onDispose(() {
      ++_generation;
      ++_positionGeneration;
      ++_loadGeneration;
      unawaited(_positions?.cancel());
      _positions = null;
    });
    final generation = ++_generation;
    _readFailed = false;
    // Defer publication until the provider's initial state exists.
    _hydration = Future.microtask(() => _restore(expectedGeneration: generation));
    return PropertyLocationState(
      location: saved,
      source: saved == null ? LocationSource.initial : LocationSource.hydrate,
    );
  }

  Future<void> _restore({int? expectedGeneration}) async {
    if (!ref.mounted || (expectedGeneration != null && expectedGeneration != _generation)) return;
    final generation = _generation;
    final database = ref.read(appDatabaseProvider);
    final scope = ref.read(storageScopeProvider);
    try {
      final value = await database.readDraft(scope: scope, key: 'location:${page.name}');
      if (!ref.mounted || generation != _generation) return;
      _readFailed = false;
      final location = LocationData.tryFromJson(
        value?['location'] is Map ? Map<String, dynamic>.from(value!['location'] as Map) : null,
      );
      state = PropertyLocationState(
        location: location ?? state.location,
        source: location == null
            ? state.source
            : LocationSource.tryParse(
                value?['source'] is String ? value!['source'] as String : null,
              ),
      );
      _updatePositionSubscription();
    } catch (error, stack) {
      if (!ref.mounted || generation != _generation) return;
      _readFailed = true;
      state = PropertyLocationState(
        location: state.location,
        source: state.source,
        save: AsyncError(error, stack),
      );
    }
  }

  Future<void> ensureLocation() async {
    await _hydration;
    if (!ref.mounted || (_visibilityKnown && !_visible)) return;
    if (_readFailed || state.location != null || state.load.isLoading) return;
    // An automatic load never shows the OS prompt; the location explainer
    // or an explicit "use my location" does.
    await useCurrent(forceRefresh: false, prompt: false);
    // Nothing resolved (prompt skipped or denied, services off, no GPS fix, IP
    // lookup failed): start in Gurugram, where the homes are. An explicit
    // "use my location" keeps its own error instead.
    if (ref.mounted && state.location == null && !state.load.isLoading) {
      await select(ServiceArea.center, source: LocationSource.fallback);
    }
  }

  Future<void> useCurrent({bool forceRefresh = true, bool prompt = true}) async {
    if (state.load.isLoading) return;
    final generation = ++_generation;
    final loadGeneration = ++_loadGeneration;
    final previous = state;
    state = PropertyLocationState(
      location: previous.location,
      source: previous.source,
      load: const AsyncLoading(),
      save: previous.save,
    );
    try {
      final resolution = await ref
          .read(deviceLocationSourceProvider)
          .current(forceRefresh: forceRefresh, prompt: prompt);
      if (!ref.mounted || generation != _generation || loadGeneration != _loadGeneration) return;
      await select(resolution.location, source: resolution.source);
    } catch (error, stack) {
      if (!ref.mounted || generation != _generation || loadGeneration != _loadGeneration) return;
      state = PropertyLocationState(
        location: previous.location,
        source: previous.source,
        load: AsyncError(error, stack),
        save: previous.save,
      );
    }
  }

  Future<bool> select(LocationData location, {LocationSource source = LocationSource.manual}) {
    if (!location.latitude.isFinite ||
        !location.longitude.isFinite ||
        location.latitude.abs() > 90 ||
        location.longitude.abs() > 180) {
      return Future.value(false);
    }
    ++_generation;
    _readFailed = false;
    state = PropertyLocationState(location: location, source: source, save: const AsyncLoading());
    _updatePositionSubscription();
    if (source == LocationSource.gps) {
      unawaited(ref.read(locationBackendSyncProvider).sync(location));
    }
    return _persist();
  }

  Future<bool> retrySave() async {
    if (_readFailed) {
      await _restore();
      return !_readFailed;
    }
    return _persist();
  }

  Future<bool> _persist() {
    final database = ref.read(appDatabaseProvider);
    final scope = ref.read(storageScopeProvider);
    final snapshot = state;
    final generation = _generation;
    final result = Completer<bool>();
    _writes = _writes.then((_) async {
      try {
        await database.writeDraft(
          scope: scope,
          key: 'location:${page.name}',
          value: {'location': snapshot.location?.toJson(), 'source': snapshot.source.stored},
        );
        if (ref.mounted && generation == _generation) {
          state = PropertyLocationState(
            location: snapshot.location,
            source: snapshot.source,
            load: state.load,
          );
        }
        result.complete(ref.mounted && generation == _generation);
      } catch (error, stack) {
        if (ref.mounted && generation == _generation) {
          state = PropertyLocationState(
            location: snapshot.location,
            source: snapshot.source,
            load: state.load,
            save: AsyncError(error, stack),
          );
        }
        result.complete(false);
      }
    });
    return result.future;
  }

  /// The visible page owns GPS updates. Inactive pages reject pending geocodes
  /// and GPS results; choosing a manual area cancels the GPS subscription.
  void setVisible(bool visible) {
    _visibilityKnown = true;
    _visible = visible;
    if (!visible) {
      final generation = ++_loadGeneration;
      Future.microtask(() {
        if (ref.mounted && generation == _loadGeneration && state.load.isLoading) {
          state = PropertyLocationState(
            location: state.location,
            source: state.source,
            save: state.save,
          );
        }
      });
    }
    _updatePositionSubscription();
  }

  void _updatePositionSubscription() {
    if (!_visible || state.source != LocationSource.gps) {
      ++_positionGeneration;
      unawaited(_positions?.cancel());
      _positions = null;
      return;
    }
    if (_positions != null) return;
    final source = ref.read(deviceLocationSourceProvider);
    try {
      _positions = source.positions().listen(
        (position) async {
          final generation = _generation;
          final positionGeneration = ++_positionGeneration;
          try {
            final location = await source.locationFor(position);
            if (!ref.mounted ||
                !_visible ||
                generation != _generation ||
                positionGeneration != _positionGeneration ||
                state.source != LocationSource.gps) {
              return;
            }
            await select(location, source: LocationSource.gps);
          } catch (error, stack) {
            if (ref.mounted &&
                _visible &&
                generation == _generation &&
                positionGeneration == _positionGeneration) {
              _streamError(error, stack);
            }
          }
        },
        onError: (Object error, StackTrace stack) {
          if (ref.mounted && _visible) _streamError(error, stack);
        },
      );
    } catch (error, stack) {
      _streamError(error, stack);
    }
  }

  void _streamError(Object error, StackTrace stack) {
    state = PropertyLocationState(
      location: state.location,
      source: state.source,
      load: AsyncError(error, stack),
      save: state.save,
    );
  }
}
