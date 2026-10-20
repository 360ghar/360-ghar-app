import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/controllers/offline_queue_service.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/data/models/unified_property_response.dart';
import 'package:ghar360/core/data/ports/properties_port.dart';
import 'package:ghar360/core/data/ports/swipes_port.dart';
import 'package:ghar360/core/network/cache_policy.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/features/properties/application/property_filters.dart';
import 'package:ghar360/features/properties/application/property_location.dart';
import 'package:ghar360/features/properties/data/datasources/properties_remote_datasource.dart';
import 'package:ghar360/features/properties/data/properties_repository.dart';
import 'package:ghar360/features/swipes/data/swipes_repository.dart';

enum PropertyFeed {
  discover(PageType.discover),
  explore(PageType.explore),
  liked(PageType.likes),
  passed(PageType.likes);

  const PropertyFeed(this.page);
  final PageType page;
  bool get isHistory => this == liked || this == passed;
  int get pageSize => this == discover ? 20 : 50;
}

enum PropertyLoadPhase { idle, loading, content, empty, refreshing, paginating, failure }

/// One request phase prevents simultaneous refresh and pagination. Screen,
/// pagination and storage failures have distinct recovery actions.
class PropertyPageState {
  PropertyPageState({
    this.phase = PropertyLoadPhase.idle,
    List<PropertyModel> items = const [],
    this.nextCursor,
    this.error,
    this.paginationError,
    this.storageError,
    this.updatedAt,
    this.stale = false,
    this.inputIdentity,
  }) : items = List.unmodifiable(items);
  final PropertyLoadPhase phase;
  final List<PropertyModel> items;
  final String? nextCursor;
  final AppException? error;
  final AppException? paginationError;
  final Object? storageError;
  final DateTime? updatedAt;
  final bool stale;
  final String? inputIdentity;
  bool get hasMore => nextCursor != null && nextCursor!.isNotEmpty;
  bool get isLoading => phase == PropertyLoadPhase.loading;
  bool get isRefreshing => phase == PropertyLoadPhase.refreshing;
  bool get isLoadingMore => phase == PropertyLoadPhase.paginating;
  bool get busy => isLoading || isRefreshing || isLoadingMore;
  bool get hasContent => items.isNotEmpty;
  bool get showFullError => error != null && !hasContent;
  PropertyPageState copyWith({
    PropertyLoadPhase? phase,
    List<PropertyModel>? items,
    Object? nextCursor = _unset,
    Object? error = _unset,
    Object? paginationError = _unset,
    Object? storageError = _unset,
    DateTime? updatedAt,
    bool? stale,
    String? inputIdentity,
  }) => PropertyPageState(
    phase: phase ?? this.phase,
    items: items ?? this.items,
    nextCursor: identical(nextCursor, _unset) ? this.nextCursor : nextCursor as String?,
    error: identical(error, _unset) ? this.error : error as AppException?,
    paginationError: identical(paginationError, _unset)
        ? this.paginationError
        : paginationError as AppException?,
    storageError: identical(storageError, _unset) ? this.storageError : storageError,
    updatedAt: updatedAt ?? this.updatedAt,
    stale: stale ?? this.stale,
    inputIdentity: inputIdentity ?? this.inputIdentity,
  );
}

const _unset = Object();

final propertiesRepositoryProvider = Provider<PropertiesPort>((ref) {
  final client = ref.watch(apiClientProvider);
  return PropertiesRepository(
    remoteDatasource: PropertiesRemoteDatasource(client),
    apiClient: client,
  );
});

/// Composes the transport and durable queue; tests can override the port.
final swipesRepositoryProvider = Provider<SwipesPort>(
  (ref) => SwipesRepository(
    apiClient: ref.watch(apiClientProvider),
    offlineQueue: ref.watch(offlineQueueServiceProvider),
  ),
);

/// Opaque server-filter input identity. It deliberately omits feed membership,
/// paging and exclusion flags so a server-proven matching listing can move
/// between history feeds without reimplementing search rules in the client.
final propertyQueryInputProvider = Provider.family<String?, PropertyFeed>((ref, feed) {
  ref.watch(storageScopeProvider);
  final filters = ref.watch(propertyFiltersProvider).forPage(feed.page);
  final location = ref.watch(propertyLocationProvider(feed.page)).location;
  if (location == null) return null;
  return jsonEncode({
    'filters': PropertyQuery._canonical(filters.toApiQueryParams()),
    'latitude': location.latitude,
    'longitude': location.longitude,
  });
});

final propertyQueryProvider =
    NotifierProvider.family<PropertyQuery, PropertyPageState, PropertyFeed>(PropertyQuery.new);

class PropertyQuery extends Notifier<PropertyPageState> {
  PropertyQuery(this.feed);
  final PropertyFeed feed;
  int _generation = 0;
  Timer? _debounce;
  Set<String> _consumedCursors = {};
  String? _queryKey;
  bool _disposed = false;

  @override
  PropertyPageState build() {
    ref.watch(storageScopeProvider);
    _disposed = false;
    ref.listen(propertyFiltersProvider.select((value) => _filterKey(value.forPage(feed.page))), (
      previous,
      next,
    ) {
      if (previous != next) _inputsChanged(debounce: true);
    });
    ref.listen(propertyLocationProvider(feed.page).select((value) => value.location), (
      previous,
      next,
    ) {
      if (previous?.latitude != next?.latitude || previous?.longitude != next?.longitude) {
        _inputsChanged();
      }
    });
    ref.onDispose(() {
      _disposed = true;
      _generation++;
      _debounce?.cancel();
    });
    final generation = ++_generation;
    scheduleMicrotask(() async {
      if (!_current(generation)) return;
      await ref.read(propertyLocationProvider(feed.page).notifier).ensureLocation();
      if (_current(generation)) await load();
    });
    return PropertyPageState();
  }

  bool _current(int generation) => !_disposed && ref.mounted && generation == _generation;
  String _filterKey(UnifiedFilterModel filters) =>
      jsonEncode(_canonical(filters.toApiQueryParams()));
  static Object? _canonical(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return {for (final key in keys) key: _canonical(value[key])};
    }
    if (value is List) return value.map(_canonical).toList();
    return value;
  }

  /// Every input that changes the result, the radius included: it is not in the filter query
  /// map, because the datasource sends it as `radius`.
  String _key(UnifiedFilterModel filters, LocationData location) => jsonEncode({
    'feed': feed.name,
    'filters': _canonical(filters.toApiQueryParams()),
    'latitude': location.latitude,
    'longitude': location.longitude,
    'radiusKm': UnifiedFilterModel.apiRadiusKm(filters.radiusKm ?? 10),
    'limit': feed.pageSize,
    'excludeSwiped': feed == PropertyFeed.discover,
  });

  void _inputsChanged({bool debounce = false}) {
    ++_generation;
    _debounce?.cancel();
    _queryKey = null;
    _consumedCursors = {};
    state = PropertyPageState();
    if (debounce) {
      _debounce = Timer(const Duration(milliseconds: 350), () => unawaited(load()));
    } else {
      scheduleMicrotask(() {
        if (!_disposed && ref.mounted) unawaited(load());
      });
    }
  }

  Future<void> load({bool refresh = false}) async {
    if (_disposed || !ref.mounted) return;
    if (state.busy && !refresh) return;
    _debounce?.cancel();
    final location = ref.read(propertyLocationProvider(feed.page)).location;
    if (location == null) {
      final problem = ref.read(propertyLocationProvider(feed.page)).load.error;
      state = state.copyWith(
        phase: problem == null ? PropertyLoadPhase.idle : PropertyLoadPhase.failure,
        error: problem == null ? null : _failure(problem),
      );
      return;
    }
    final filters = ref.read(propertyFiltersProvider).forPage(feed.page);
    final key = _key(filters, location);
    final inputIdentity = ref.read(propertyQueryInputProvider(feed));
    final generation = ++_generation;
    final database = ref.read(appDatabaseProvider);
    final scope = ref.read(storageScopeProvider);
    _consumedCursors = {};
    if (_queryKey != key) state = PropertyPageState();
    _queryKey = key;
    state = state.copyWith(
      phase: state.hasContent ? PropertyLoadPhase.refreshing : PropertyLoadPhase.loading,
      error: null,
      paginationError: null,
      inputIdentity: inputIdentity,
    );
    if (!refresh && !state.hasContent && feed != PropertyFeed.discover) {
      try {
        final cache = await database.readCache(scope: scope, key: 'properties:$key');
        if (!_current(generation)) return;
        if (cache?.value is Map) {
          final cached = UnifiedPropertyResponse.fromJson(
            Map<String, dynamic>.from(cache!.value as Map),
          );
          state = PropertyPageState(
            phase: PropertyLoadPhase.refreshing,
            items: _deduplicate(cached.items),
            nextCursor: cached.hasMorePages ? cached.nextCursor : null,
            updatedAt: cache.createdAt,
            stale: cache.isStaleAt(DateTime.now()),
            inputIdentity: inputIdentity,
          );
        }
      } catch (error, stack) {
        if (!_current(generation)) return;
        DebugLogger.warning('Property cache read failed', error.runtimeType, stack);
        state = state.copyWith(storageError: error);
      }
    }
    try {
      final result = await _fetch(filters, location, null);
      if (!_current(generation)) return;
      final items = _deduplicate(result.items);
      state = PropertyPageState(
        phase: items.isEmpty ? PropertyLoadPhase.empty : PropertyLoadPhase.content,
        items: items,
        nextCursor: result.hasMorePages ? result.nextCursor : null,
        updatedAt: DateTime.now(),
        storageError: state.storageError,
        inputIdentity: inputIdentity,
      );
      await _persist(database, scope, key, generation, noStore: isNoStoreResponse(result));
    } catch (error, stack) {
      if (!_current(generation)) return;
      DebugLogger.warning('Property feed request failed', error.runtimeType, stack);
      state = state.copyWith(
        phase: state.hasContent ? PropertyLoadPhase.content : PropertyLoadPhase.failure,
        error: _failure(error),
        stale: state.hasContent,
      );
    }
  }

  Future<void> loadMore({bool retry = false}) async {
    if (_disposed ||
        !ref.mounted ||
        state.busy ||
        !state.hasMore ||
        (state.paginationError != null && !retry)) {
      return;
    }
    final cursor = state.nextCursor!;
    if (_consumedCursors.contains(cursor)) {
      state = state.copyWith(nextCursor: null);
      return;
    }
    final location = ref.read(propertyLocationProvider(feed.page)).location;
    if (location == null) return;
    final filters = ref.read(propertyFiltersProvider).forPage(feed.page);
    final generation = _generation;
    final database = ref.read(appDatabaseProvider);
    final scope = ref.read(storageScopeProvider);
    state = state.copyWith(phase: PropertyLoadPhase.paginating, paginationError: null);
    try {
      final result = await _fetch(filters, location, cursor);
      if (!_current(generation)) return;
      _consumedCursors.add(cursor);
      final next = result.hasMorePages && !_consumedCursors.contains(result.nextCursor)
          ? result.nextCursor
          : null;
      final items = _deduplicate([...state.items, ...result.items]);
      state = state.copyWith(
        phase: items.isEmpty ? PropertyLoadPhase.empty : PropertyLoadPhase.content,
        items: items,
        nextCursor: next,
        paginationError: null,
      );
      await _persist(database, scope, _queryKey!, generation, noStore: isNoStoreResponse(result));
    } catch (error, stack) {
      if (!_current(generation)) return;
      DebugLogger.warning('Property next page failed', error.runtimeType, stack);
      state = state.copyWith(
        phase: state.hasContent ? PropertyLoadPhase.content : PropertyLoadPhase.empty,
        paginationError: _failure(error),
      );
    }
  }

  Future<UnifiedPropertyResponse> _fetch(
    UnifiedFilterModel filters,
    LocationData location,
    String? cursor,
  ) {
    if (feed.isHistory) {
      return ref
          .read(swipesRepositoryProvider)
          .getSwipeHistoryProperties(
            filters: filters,
            latitude: location.latitude,
            longitude: location.longitude,
            cursor: cursor,
            limit: feed.pageSize,
            isLiked: feed == PropertyFeed.liked,
          );
    }
    return ref
        .read(propertiesRepositoryProvider)
        .searchProperties(
          filters: filters,
          latitude: location.latitude,
          longitude: location.longitude,
          radiusKm: filters.radiusKm ?? 10,
          cursor: cursor,
          limit: feed.pageSize,
          excludeSwiped: feed == PropertyFeed.discover,
          useCache: feed != PropertyFeed.discover,
        );
  }

  /// Writes the feed to the scoped cache. A response the server marked `no-store` is not
  /// written, and a copy stored earlier is deleted. A stored listing has no phone number.
  Future<void> _persist(
    AppDatabase database,
    StorageScope scope,
    String key,
    int generation, {
    bool noStore = false,
  }) async {
    if (feed == PropertyFeed.discover) return;
    final snapshot = state;
    final now = DateTime.now();
    try {
      if (noStore) {
        await database.removeCache(scope: scope, key: 'properties:$key');
        return;
      }
      // Bound each feed snapshot as well as the database-wide 20 MiB budget.
      final items = snapshot.items.take(200).toList();
      await database.writeCache(
        scope: scope,
        key: 'properties:$key',
        value: {
          ...UnifiedPropertyResponse(
            items: const [],
            limit: feed.pageSize,
            nextCursor: items.length == snapshot.items.length ? snapshot.nextCursor : null,
            hasMore: items.length == snapshot.items.length && snapshot.hasMore,
          ).toJson(),
          'items': [for (final item in items) item.toStorableJson()],
        },
        freshUntil: now.add(const Duration(minutes: 5)),
        expiresAt: now.add(const Duration(hours: 24)),
      );
      if (_current(generation) && state.storageError != null) {
        state = state.copyWith(storageError: null);
      }
    } catch (error, stack) {
      if (!_current(generation)) return;
      DebugLogger.warning('Property cache write failed', error.runtimeType, stack);
      state = state.copyWith(storageError: error);
    }
  }

  static List<PropertyModel> _deduplicate(List<PropertyModel> items) {
    final seen = <int>{};
    return items.where((item) => seen.add(item.id)).toList();
  }

  static AppException _failure(Object error) =>
      error is AppException ? error : ServerException('Request failed', code: 'UNKNOWN');
}
