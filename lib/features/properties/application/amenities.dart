import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/bootstrap/provider_policy.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/network/api_paths.dart';
import 'package:ghar360/core/network/response_parser.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';

/// `GET /api/v1/amenities`: every active amenity, sorted by title. Public; the
/// backend caches it for 24 hours. The route is a `CursorPage` of at most 100 rows, so this
/// follows `next_cursor` until `has_more` is false. Filters send the titles back as
/// `amenities=` and the backend matches them without case.
final amenitiesFetchProvider = Provider<Future<List<PropertyAmenity>> Function()>((ref) {
  final client = ref.watch(apiClientProvider);
  return () async {
    final amenities = <PropertyAmenity>[];
    final seen = <String>{};
    String? cursor;
    do {
      final response = await client.get(
        ApiPaths.amenities,
        queryParams: {'limit': '100', 'cursor': ?cursor},
        useCache: false,
        requireAuth: false,
      );
      try {
        final page = ResponseParser.cursorPage(response.body, PropertyAmenity.fromJson);
        amenities.addAll(page.items);
        cursor = page.hasMorePages && seen.add(page.nextCursor!) ? page.nextCursor : null;
      } catch (_) {
        throw ApiException('Amenities could not be read.', code: 'MALFORMED_RESPONSE');
      }
    } while (cursor != null);
    return List.unmodifiable(amenities);
  };
});

class AmenitiesState {
  const AmenitiesState({this.items, this.loading = false, this.error});

  /// Null until the cache or the server answers.
  final List<PropertyAmenity>? items;
  final bool loading;
  final AppException? error;
}

final amenitiesProvider = NotifierProvider<Amenities, AmenitiesState>(
  Amenities.new,
  retry: noProviderRetry,
);

/// Stale-while-revalidate: the cached list shows at once, a stale one is
/// refreshed in the background, and a failed refresh keeps the cached list.
class Amenities extends Notifier<AmenitiesState> {
  static const cacheKey = 'amenities:v1';
  int _generation = 0;
  bool _inFlight = false;

  @override
  AmenitiesState build() {
    final scope = ref.watch(storageScopeProvider);
    final generation = ++_generation;
    _inFlight = false;
    ref.onDispose(() => _generation++);
    Future.microtask(() => _restore(generation, scope));
    return const AmenitiesState(loading: true);
  }

  bool _active(int generation) => ref.mounted && generation == _generation;

  Future<void> _restore(int generation, StorageScope scope) async {
    if (!_active(generation)) return;
    CachedEntry? cached;
    List<PropertyAmenity>? items;
    try {
      cached = await ref.read(appDatabaseProvider).readCache(scope: scope, key: cacheKey);
      items = List.unmodifiable([
        for (final item in cached!.value! as List)
          PropertyAmenity.fromJson(Map<String, dynamic>.from(item as Map)),
      ]);
    } catch (_) {
      // No usable cache: the server request below decides what shows.
    }
    if (!_active(generation)) return;
    if (items != null) {
      state = AmenitiesState(items: items);
      if (!cached!.isStaleAt(DateTime.now())) return;
    }
    await _fetch(generation, scope);
  }

  Future<void> retry() => _fetch(_generation, ref.read(storageScopeProvider));

  Future<void> _fetch(int generation, StorageScope scope) async {
    if (_inFlight || !_active(generation)) return;
    _inFlight = true;
    state = AmenitiesState(items: state.items, loading: true);
    try {
      final items = await ref.read(amenitiesFetchProvider)();
      if (!_active(generation)) return;
      state = AmenitiesState(items: items);
      try {
        final now = DateTime.now();
        await ref
            .read(appDatabaseProvider)
            .writeCache(
              scope: scope,
              key: cacheKey,
              value: [for (final item in items) item.toJson()],
              freshUntil: now.add(const Duration(days: 1)),
              expiresAt: now.add(const Duration(days: 30)),
            );
      } catch (_) {
        // The list on screen stays usable when the disk write fails.
      }
    } catch (error) {
      if (!_active(generation)) return;
      state = AmenitiesState(
        items: state.items,
        error: error is AppException
            ? error
            : ApiException('Amenities could not load.', code: 'AMENITIES_UNAVAILABLE'),
      );
    } finally {
      if (_active(generation)) _inFlight = false;
    }
  }
}
