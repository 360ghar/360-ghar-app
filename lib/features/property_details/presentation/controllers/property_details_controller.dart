import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/network/cache_policy.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/properties/application/property_queries.dart';

enum PropertyDetailPhase { loading, content, refreshing, failed }

class PropertyDetailsState {
  const PropertyDetailsState({
    this.property,
    this.phase = PropertyDetailPhase.loading,
    this.failure,
    this.stale = false,
  });
  final PropertyModel? property;
  final PropertyDetailPhase phase;
  final AppException? failure;
  final bool stale;
  bool get busy => phase == PropertyDetailPhase.loading || phase == PropertyDetailPhase.refreshing;
}

final propertyDetailsProvider = NotifierProvider.autoDispose
    .family<PropertyDetailsController, PropertyDetailsState, int>(PropertyDetailsController.new);

/// Identity is the property ID. A summary may seed the view while this provider
/// always requests authoritative detail for the current account lease.
class PropertyDetailsController extends Notifier<PropertyDetailsState> {
  PropertyDetailsController(this.propertyId);
  final int propertyId;
  int _generation = 0;
  bool _inFlight = false;
  @override
  PropertyDetailsState build() {
    final scope = ref.watch(storageScopeProvider);
    ref.watch(propertiesRepositoryProvider);
    final generation = ++_generation;
    _inFlight = false;
    ref.onDispose(() => _generation++);
    if (propertyId <= 0) {
      return PropertyDetailsState(
        phase: PropertyDetailPhase.failed,
        failure: ValidationException('Invalid property ID.', code: 'INVALID_PROPERTY_ID'),
      );
    }
    Future.microtask(() => _restoreAndLoad(generation, scope));
    return const PropertyDetailsState();
  }

  bool _active(int generation) => ref.mounted && generation == _generation;
  Future<void> _restoreAndLoad(int generation, StorageScope scope) async {
    if (!_active(generation)) return;
    try {
      final cache = await ref
          .read(appDatabaseProvider)
          .readCache(scope: scope, key: 'property:$propertyId');
      if (!_active(generation)) return;
      if (cache?.value is Map) {
        final property = PropertyModel.fromJson(Map<String, dynamic>.from(cache!.value! as Map));
        if (property.id == propertyId) {
          state = PropertyDetailsState(
            property: property,
            phase: PropertyDetailPhase.content,
            stale: true,
          );
        }
      }
    } catch (_) {
      /* Optional cache corruption still permits a server retry. */
    }
    if (_active(generation)) await refresh();
  }

  Future<void> refresh() async {
    if (_inFlight || propertyId <= 0) return;
    _inFlight = true;
    final generation = _generation;
    final scope = ref.read(storageScopeProvider);
    final database = ref.read(appDatabaseProvider);
    final repository = ref.read(propertiesRepositoryProvider);
    state = PropertyDetailsState(
      property: state.property,
      stale: state.stale,
      phase: state.property == null ? PropertyDetailPhase.loading : PropertyDetailPhase.refreshing,
    );
    try {
      final property = await repository.getPropertyDetail(propertyId);
      if (!_active(generation)) return;
      if (property.id != propertyId) {
        throw ApiException('Property response did not match request.', code: 'MALFORMED_RESPONSE');
      }
      state = PropertyDetailsState(property: property, phase: PropertyDetailPhase.content);
      try {
        if (isNoStoreResponse(property)) {
          // The server forbids storing this response: keep nothing, drop an older copy.
          await database.removeCache(scope: scope, key: 'property:$propertyId');
        } else {
          final now = DateTime.now();
          await database.writeCache(
            scope: scope,
            key: 'property:$propertyId',
            // A stored copy never holds a phone number.
            value: property.toStorableJson(),
            freshUntil: now.add(const Duration(minutes: 5)),
            expiresAt: now.add(const Duration(days: 7)),
          );
        }
      } catch (_) {
        /* Fresh detail remains available if disk storage fails. */
      }
    } catch (error) {
      if (_active(generation)) {
        final failure = error is AppException
            ? error
            : ApiException('Invalid property response.', code: 'MALFORMED_RESPONSE');
        // A missing/deleted listing must not keep exposing a stale booking CTA.
        final property = failure is NotFoundException ? null : state.property;
        state = PropertyDetailsState(
          property: property,
          phase: property == null ? PropertyDetailPhase.failed : PropertyDetailPhase.content,
          stale: property != null,
          failure: failure,
        );
        if (failure is NotFoundException) {
          try {
            await database.removeCache(scope: scope, key: 'property:$propertyId');
          } catch (_) {
            // Visible state is still authoritative if disk cleanup fails.
          }
        }
      }
    } finally {
      if (_active(generation)) _inFlight = false;
    }
  }
}
