import 'dart:async';

import 'package:ghar360/core/controllers/location_controller.dart';
import 'package:ghar360/core/controllers/page_state_service.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/firebase/analytics_service.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/core/utils/error_mapper.dart';
import 'package:ghar360/features/properties/data/properties_repository.dart';
import 'package:ghar360/features/swipes/data/swipes_repository.dart';

/// Handles all data loading, pagination, and debounced refresh logic
/// for [PageStateService].
class PageDataLoader {
  final PageStateService _pageState;
  final PropertiesRepository _propertiesRepo;
  final SwipesRepository _swipesRepo;
  final LocationController _locationController;
  final Set<PageType> _activeLoads = <PageType>{};
  static const Duration _staleLoadingGuardWindow = Duration(seconds: 20);

  // Debounce timers (per page)
  Timer? _exploreDebouncer;
  Timer? _discoverDebouncer;
  Timer? _likesDebouncer;

  // Analytics: fire first_property_loaded only once per session
  bool _firstPropertyLoadedFired = false;
  DateTime? _firstLoadStartedAt;

  PageDataLoader(this._pageState, this._propertiesRepo, this._swipesRepo, this._locationController);

  void dispose() {
    _exploreDebouncer?.cancel();
    _discoverDebouncer?.cancel();
    _likesDebouncer?.cancel();
  }

  Future<void> loadPageData(
    PageType pageType, {
    bool forceRefresh = false,
    bool backgroundRefresh = false,
  }) async {
    bool activeLoadRegistered = false;
    bool launchedBackgroundLoad = false;
    try {
      var state = _pageState.getStateForPage(pageType);

      if (_shouldHealStaleLoadingState(pageType, state)) {
        DebugLogger.warning(
          '🩹 Healed stale loading state for ${pageType.name}; forcing a fresh load.',
        );
        state = state.copyWith(
          isLoading: false,
          isLoadingMore: false,
          isRefreshing: false,
          error: null,
        );
        _pageState.updatePageState(pageType, state);
      }

      if (state.isLoading || state.isRefreshing || _activeLoads.contains(pageType)) return;

      final hasCached = state.properties.isNotEmpty;
      final isStale = state.isDataStale;

      // If there's no cached data at all, do a foreground load
      if (!hasCached) {
        _activeLoads.add(pageType);
        activeLoadRegistered = true;
        _pageState.updatePageState(pageType, state.copyWith(isLoading: true, error: null));
        await _fetchAndUpdatePage(pageType);
      } else {
        // We have cached data: return immediately and revalidate in
        // background when asked or stale
        if (forceRefresh || backgroundRefresh || isStale) {
          _activeLoads.add(pageType);
          activeLoadRegistered = true;
          launchedBackgroundLoad = true;
          _pageState.notifyPageRefreshing(pageType, true);
          _pageState.updatePageState(pageType, state.copyWith(isRefreshing: true, error: null));
          unawaited(
            _fetchAndUpdatePage(pageType)
                .catchError((e, stackTrace) {
                  DebugLogger.error('❌ Background refresh failed for ${pageType.name}', e);
                  final current = _pageState.getStateForPage(pageType);
                  _pageState.updatePageState(
                    pageType,
                    current.copyWith(
                      isRefreshing: false,
                      error: ErrorMapper.mapApiError(e, stackTrace),
                    ),
                  );
                })
                .whenComplete(() {
                  _activeLoads.remove(pageType);
                  _pageState.notifyPageRefreshing(pageType, false);
                }),
          );
        } else {
          // Fresh enough; nothing to do
          return;
        }
      }

      final updatedCount = _pageState.getStateForPage(pageType).properties.length;
      DebugLogger.success('✅ Loaded $updatedCount properties for ${pageType.name}');
    } catch (e, stackTrace) {
      DebugLogger.error('❌ Failed to load ${pageType.name} data', e, stackTrace);
      final state = _pageState.getStateForPage(pageType);
      _pageState.updatePageState(
        pageType,
        state.copyWith(
          isLoading: false,
          isRefreshing: false,
          error: ErrorMapper.mapApiError(e, stackTrace),
        ),
      );
    } finally {
      if (activeLoadRegistered && !launchedBackgroundLoad) {
        _activeLoads.remove(pageType);
        _pageState.notifyPageRefreshing(pageType, false);
      }
    }
  }

  bool _shouldHealStaleLoadingState(PageType pageType, PageStateModel state) {
    if (_activeLoads.contains(pageType)) return false;

    final hasLoadingFlag = state.isLoading || state.isRefreshing || state.isLoadingMore;
    if (!hasLoadingFlag) return false;
    if (state.properties.isNotEmpty) return false;

    final lastFetched = state.lastFetched;
    if (lastFetched == null) {
      return true;
    }

    return DateTime.now().difference(lastFetched) > _staleLoadingGuardWindow;
  }

  Future<void> loadMorePageData(PageType pageType) async {
    try {
      final state = _pageState.getStateForPage(pageType);
      if (state.isLoading || state.isLoadingMore || !state.hasMore) return;

      _pageState.updatePageState(pageType, state.copyWith(isLoadingMore: true));

      final loc = state.selectedLocation;
      if (loc == null) {
        DebugLogger.warning(
          '⚠️ No location set for ${pageType.name} while loading more. '
          'Skipping.',
        );
        _pageState.updatePageState(pageType, state.copyWith(isLoadingMore: false));
        return;
      }

      // Cursor must be present to load the next page; if it's missing the
      // backend has signalled the terminal page and there's nothing to fetch.
      final cursor = state.nextCursor;
      if (cursor == null || cursor.isEmpty) {
        DebugLogger.warning(
          '⚠️ No next cursor for ${pageType.name} while loading more. '
          'Marking page terminal.',
        );
        _pageState.updatePageState(pageType, state.copyWith(isLoadingMore: false, hasMore: false));
        return;
      }

      if (pageType == PageType.likes) {
        final isLikedSegment =
            (state.getAdditionalData<String>('currentSegment') ?? 'liked') == 'liked';
        final response = await _swipesRepo.getSwipeHistoryProperties(
          filters: state.filters.copyWith(searchQuery: state.searchQuery),
          latitude: loc.latitude,
          longitude: loc.longitude,
          cursor: cursor,
          limit: 50,
          isLiked: isLikedSegment,
        );
        final newProperties = [...state.properties, ...response.items];
        _pageState.updatePageState(
          pageType,
          state.copyWith(
            properties: newProperties,
            nextCursor: response.nextCursor,
            hasMore: response.hasMorePages,
            isLoadingMore: false,
          ),
        );
      } else {
        final response = await _propertiesRepo.searchProperties(
          filters: state.filters.copyWith(searchQuery: state.searchQuery),
          latitude: loc.latitude,
          longitude: loc.longitude,
          radiusKm: (state.filters.radiusKm ?? 10.0).clamp(5.0, 50.0),
          cursor: cursor,
          limit: pageType == PageType.discover ? 20 : 50,
          excludeSwiped: pageType == PageType.discover,
          useCache: true,
        );

        final newProperties = [...state.properties, ...response.items];
        _pageState.updatePageState(
          pageType,
          state.copyWith(
            properties: newProperties,
            nextCursor: response.nextCursor,
            hasMore: response.hasMorePages,
            isLoadingMore: false,
          ),
        );
      }

      final totalCount = _pageState.getStateForPage(pageType).properties.length;
      DebugLogger.success('✅ Loaded more properties for ${pageType.name} (total: $totalCount)');
    } catch (e) {
      DebugLogger.error('❌ Failed to load more ${pageType.name} data: $e');
      final state = _pageState.getStateForPage(pageType);
      _pageState.updatePageState(pageType, state.copyWith(isLoadingMore: false));
    }
  }

  // Alias for controllers
  Future<void> loadMoreData(PageType pageType) => loadMorePageData(pageType);

  void debounceRefresh(PageType pageType) {
    switch (pageType) {
      case PageType.explore:
        _exploreDebouncer?.cancel();
        _exploreDebouncer = Timer(const Duration(milliseconds: 500), () {
          loadPageData(PageType.explore, forceRefresh: true);
        });
        break;
      case PageType.discover:
        _discoverDebouncer?.cancel();
        _discoverDebouncer = Timer(const Duration(milliseconds: 500), () {
          loadPageData(PageType.discover, forceRefresh: true);
        });
        break;
      case PageType.likes:
        _likesDebouncer?.cancel();
        _likesDebouncer = Timer(const Duration(milliseconds: 500), () {
          loadPageData(PageType.likes, forceRefresh: true);
        });
        break;
    }
  }

  void refreshAllPagesData() {
    loadPageData(PageType.explore, forceRefresh: true);
    loadPageData(PageType.discover, forceRefresh: true);
    loadPageData(PageType.likes, forceRefresh: true);
  }

  // Internal: fetch first page of data and update state (cursor reset to null).
  Future<void> _fetchAndUpdatePage(PageType pageType) async {
    // Track latency for first property load analytics
    if (!_firstPropertyLoadedFired) {
      _firstLoadStartedAt ??= DateTime.now();
    }
    final state = _pageState.getStateForPage(pageType);
    LocationData? loc = state.selectedLocation;
    loc ??= await _locationController.getInitialLocation();

    DebugLogger.debug(
      '📡 [DATA_LOADER] _fetchAndUpdatePage ${pageType.name} '
      'loc=${loc.latitude},${loc.longitude} '
      'filters=${state.filters.activeFilterCount}',
    );

    if (pageType == PageType.likes) {
      final isLikedSegment =
          (state.getAdditionalData<String>('currentSegment') ?? 'liked') == 'liked';
      final resp = await _swipesRepo.getSwipeHistoryProperties(
        filters: state.filters.copyWith(searchQuery: state.searchQuery),
        latitude: loc.latitude,
        longitude: loc.longitude,
        cursor: null,
        limit: 50,
        isLiked: isLikedSegment,
      );

      _pageState.updatePageState(
        pageType,
        state.copyWith(
          properties: resp.items,
          selectedLocation: loc,
          nextCursor: resp.nextCursor,
          hasMore: resp.hasMorePages,
          isLoading: false,
          isRefreshing: false,
          lastFetched: DateTime.now(),
          error: null,
        ),
      );
      return;
    }

    // Explore/Discover
    final resp = await _propertiesRepo.searchProperties(
      filters: state.filters.copyWith(searchQuery: state.searchQuery),
      latitude: loc.latitude,
      longitude: loc.longitude,
      radiusKm: (state.filters.radiusKm ?? 10.0).clamp(5.0, 50.0),
      cursor: null,
      limit: pageType == PageType.discover ? 20 : 50,
      excludeSwiped: pageType == PageType.discover,
      useCache: true,
    );
    DebugLogger.debug(
      '📡 [DATA_LOADER] Received ${resp.items.length} properties for '
      '${pageType.name} (hasMore=${resp.hasMorePages}, '
      'nextCursor=${resp.nextCursor != null})',
    );
    _pageState.updatePageState(
      pageType,
      state.copyWith(
        properties: resp.items,
        selectedLocation: loc,
        nextCursor: resp.nextCursor,
        hasMore: resp.hasMorePages,
        isLoading: false,
        isRefreshing: false,
        lastFetched: DateTime.now(),
        error: null,
      ),
    );

    // Fire first_property_loaded analytics once per session
    if (!_firstPropertyLoadedFired && resp.items.isNotEmpty && _firstLoadStartedAt != null) {
      _firstPropertyLoadedFired = true;
      final latency = DateTime.now().difference(_firstLoadStartedAt!);
      AnalyticsService.firstPropertyLoaded(latencyMs: latency.inMilliseconds);
    }
  }
}
