import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:ghar360/core/bootstrap/provider_policy.dart';
import 'package:ghar360/core/controllers/localization_controller.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/map/map_controller.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/explore/presentation/controllers/explore_property_markers.dart';
import 'package:ghar360/features/location/application/location_source.dart';
import 'package:ghar360/features/properties/application/property_filters.dart';
import 'package:ghar360/features/properties/application/property_location.dart';
import 'package:ghar360/features/properties/application/property_queries.dart';
import 'package:ghar360/features/properties/application/swipe_history.dart';

export 'package:ghar360/features/explore/presentation/controllers/explore_property_markers.dart'
    show PropertyMarker;

enum ExploreState { initial, loading, loaded, empty, error, loadingMore }

class ExploreMapState {
  const ExploreMapState({
    this.center = const LatLng(28.6139, 77.2090),
    this.zoom = 12,
    this.selectedId,
    this.collapsed = false,
    this.cameraRevision = 0,
    this.fitBounds = false,
    this.cameraUpdate = const AsyncData(null),
  });
  final LatLng center;
  final double zoom;
  final int? selectedId;
  final bool collapsed;
  final int cameraRevision;
  final bool fitBounds;
  final AsyncValue<void> cameraUpdate;
  ExploreMapState copyWith({
    LatLng? center,
    double? zoom,
    Object? selectedId = _unset,
    bool? collapsed,
    int? cameraRevision,
    bool? fitBounds,
    AsyncValue<void>? cameraUpdate,
  }) => ExploreMapState(
    center: center ?? this.center,
    zoom: zoom ?? this.zoom,
    selectedId: identical(selectedId, _unset) ? this.selectedId : selectedId as int?,
    collapsed: collapsed ?? this.collapsed,
    cameraRevision: cameraRevision ?? this.cameraRevision,
    fitBounds: fitBounds ?? this.fitBounds,
    cameraUpdate: cameraUpdate ?? this.cameraUpdate,
  );
}

const _unset = Object();
final exploreProvider = NotifierProvider<ExploreController, ExploreMapState>(
  ExploreController.new,
  retry: noProviderRetry,
);
final exploreMarkersProvider = Provider<List<PropertyMarker>>((ref) {
  final items = ref.watch(
    propertyQueryProvider(PropertyFeed.explore).select((state) => state.items),
  );
  final selected = ref.watch(exploreProvider.select((state) => state.selectedId));
  final languageCode = ref.watch(localizationProvider.select((state) => state.locale.languageCode));
  return const ExplorePropertyMarkers().build(
    properties: items,
    selectedPropertyId: selected,
    languageCode: languageCode,
  );
}, retry: noProviderRetry);

/// Map position and selection only. The MapLibre resource belongs to ExploreMap;
/// property pages, filters, location, and likes each have their own provider.
class ExploreController extends Notifier<ExploreMapState> {
  Timer? _mapMoveDebouncer;
  int _generation = 0;
  bool _visible = true;
  @override
  ExploreMapState build() {
    ref.watch(storageScopeProvider);
    final location = ref.read(propertyLocationProvider(PageType.explore)).location;
    ref.listen(propertyLocationProvider(PageType.explore).select((state) => state.location), (
      _,
      next,
    ) {
      if (next == null) return;
      _cancelCameraSearch();
      final center = LatLng(next.latitude, next.longitude);
      if (distanceMeters(state.center, center) < 10) {
        if (state.cameraUpdate.isLoading) {
          state = state.copyWith(cameraUpdate: const AsyncData(null));
        }
        return;
      }
      state = state.copyWith(
        center: center,
        cameraRevision: state.cameraRevision + 1,
        fitBounds: false,
        cameraUpdate: const AsyncData(null),
      );
    });
    ref.listen(propertyQueryProvider(PropertyFeed.explore), (_, next) {
      if (next.phase != PropertyLoadPhase.content && next.phase != PropertyLoadPhase.empty) return;
      if (state.selectedId != null &&
          !next.items.any((property) => property.id == state.selectedId)) {
        clearSelection();
      }
    });
    ref.onDispose(_cancelCameraSearch);
    return ExploreMapState(
      center: location == null
          ? const LatLng(28.6139, 77.2090)
          : LatLng(location.latitude, location.longitude),
    );
  }

  List<PropertyModel> get properties => ref.read(propertyQueryProvider(PropertyFeed.explore)).items;
  LatLng get currentCenter => state.center;
  double get currentZoom => state.zoom;
  double get currentRadius =>
      (ref.read(propertyFiltersProvider).forPage(PageType.explore).radiusKm ?? 10)
          .clamp(5, 50)
          .toDouble();
  PropertyModel? get selectedProperty {
    for (final property in properties) {
      if (property.id == state.selectedId) return property;
    }
    return null;
  }

  bool get isListCollapsed => state.collapsed;
  PropertyPageState get _page => ref.read(propertyQueryProvider(PropertyFeed.explore));
  ExploreState get viewState {
    if (_page.isLoading && properties.isEmpty) return ExploreState.loading;
    if (_page.showFullError) return ExploreState.error;
    if (_page.isLoadingMore) return ExploreState.loadingMore;
    if (_page.phase == PropertyLoadPhase.idle) return ExploreState.initial;
    return properties.isEmpty ? ExploreState.empty : ExploreState.loaded;
  }

  AppException? get error => _page.error;
  bool get isLoading => _page.isLoading;
  bool get isLoadingMore => _page.isLoadingMore;
  bool get hasMore => _page.hasMore;
  bool get hasProperties => properties.isNotEmpty;
  List<PropertyModel> get propertiesWithLocation => properties
      .where(
        (p) =>
            p.latitude != null &&
            p.longitude != null &&
            p.latitude!.isFinite &&
            p.longitude!.isFinite &&
            p.latitude!.abs() <= 90 &&
            p.longitude!.abs() <= 180,
      )
      .toList();

  void _cancelCameraSearch() {
    ++_generation;
    _mapMoveDebouncer?.cancel();
  }

  void setVisible(bool visible) {
    _visible = visible;
    if (!visible) {
      _cancelCameraSearch();
      final generation = _generation;
      Future.microtask(() {
        if (ref.mounted && generation == _generation && state.cameraUpdate.isLoading) {
          state = state.copyWith(cameraUpdate: const AsyncData(null));
        }
      });
    }
  }

  void onCameraIdle(LatLng center, double zoom, {bool programmatic = false}) {
    if (!_visible ||
        !center.latitude.isFinite ||
        !center.longitude.isFinite ||
        !zoom.isFinite ||
        center.latitude.abs() > 90 ||
        center.longitude.abs() > 180) {
      return;
    }
    final changed = distanceMeters(state.center, center) > 100 || (state.zoom - zoom).abs() > 0.1;
    state = state.copyWith(center: center, zoom: zoom.clamp(kDefaultMinZoom, kDefaultMaxZoom));
    if (!changed || programmatic) return;
    _cancelCameraSearch();
    final generation = _generation;
    _mapMoveDebouncer = Timer(
      const Duration(milliseconds: 600),
      () => unawaited(_searchCamera(center, generation)),
    );
  }

  Future<void> retryCameraSearch() => _searchCamera(state.center, ++_generation);
  Future<void> _searchCamera(LatLng center, int generation) async {
    if (!ref.mounted || !_visible || generation != _generation) return;
    state = state.copyWith(cameraUpdate: const AsyncLoading());
    try {
      final name = await ref
          .read(deviceLocationSourceProvider)
          .address(center.latitude, center.longitude);
      if (!ref.mounted || !_visible || generation != _generation) return;
      await ref
          .read(propertyLocationProvider(PageType.explore).notifier)
          .select(LocationData(name: name, latitude: center.latitude, longitude: center.longitude));
      if (ref.mounted && generation == _generation) {
        state = state.copyWith(cameraUpdate: const AsyncData(null));
      }
    } catch (error, stack) {
      if (ref.mounted && generation == _generation) {
        state = state.copyWith(cameraUpdate: AsyncError(error, stack));
      }
    }
  }

  bool isPropertyLiked(PropertyModel property) =>
      ref.read(swipeHistoryProvider).entries[property.id]?.isLiked ?? property.liked;
  Future<bool> toggleLike(PropertyModel property) =>
      ref.read(swipeHistoryProvider.notifier).record(property, !isPropertyLiked(property));
  void selectProperty(PropertyModel property) =>
      state = state.copyWith(selectedId: property.id, collapsed: false);
  void highlightPropertyFromCard(PropertyModel property) =>
      state = state.copyWith(selectedId: property.id);
  void clearSelection() => state = state.copyWith(selectedId: null);
  void toggleListCollapsed() => state = state.copyWith(collapsed: !state.collapsed);
  void expandList() => state = state.copyWith(collapsed: false);
  void collapseList() => state = state.copyWith(collapsed: true);
  void zoomIn() => _zoom(1);
  void zoomOut() => _zoom(-1);
  void _zoom(double delta) => state = state.copyWith(
    zoom: (state.zoom + delta).clamp(kDefaultMinZoom, kDefaultMaxZoom),
    cameraRevision: state.cameraRevision + 1,
    fitBounds: false,
  );
  Future<void> recenterToCurrentLocation() =>
      ref.read(propertyLocationProvider(PageType.explore).notifier).useCurrent();
  void fitBoundsToProperties() {
    if (propertiesWithLocation.isEmpty) return;
    state = state.copyWith(cameraRevision: state.cameraRevision + 1, fitBounds: true);
  }

  Future<void> refreshProperties() =>
      ref.read(propertyQueryProvider(PropertyFeed.explore).notifier).load(refresh: true);
  Future<void> retryLoading() => refreshProperties();
  Future<void> loadMoreProperties() =>
      ref.read(propertyQueryProvider(PropertyFeed.explore).notifier).loadMore();
  Future<bool> quickFilterByType(PropertyType type) => ref
      .read(propertyFiltersProvider.notifier)
      .update(
        PageType.explore,
        ref
            .read(propertyFiltersProvider)
            .forPage(PageType.explore)
            .copyWith(propertyType: [type.wire]),
      );
  Future<bool> quickFilterByPurpose(PropertyPurpose purpose) => ref
      .read(propertyFiltersProvider.notifier)
      .update(
        PageType.explore,
        ref.read(propertyFiltersProvider).forPage(PageType.explore).copyWith(purpose: purpose.wire),
      );
  Future<bool> updateSearchQuery(String query) =>
      ref.read(propertyFiltersProvider.notifier).search(PageType.explore, query);
  Future<bool> clearSearch() => updateSearchQuery('');
}
