import 'dart:async';

import 'package:ghar360/core/controllers/location_controller.dart';
import 'package:ghar360/core/controllers/page_state_service.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/data/ports/properties_port.dart';
import 'package:ghar360/core/data/ports/swipes_port.dart';
import 'package:ghar360/core/firebase/analytics_service.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/core/utils/error_mapper.dart';

/// Handles all data loading, pagination, and debounced refresh logic
/// for [PageStateService].
class PageDataLoader {
  final PageStateService _pageState;
  final PropertiesPort _propertiesRepo;
  final SwipesPort _swipesRepo;
  final LocationController _locationController;
  final Set<PageType> _activeLoads = <PageType>{};
  static const Duration _staleLoadingGuardWindow = Duration(seconds: 20);

  /// When a likes load is already in flight and the user switches liked/passed
  /// (or otherwise force-refreshes), [loadPageData] would early-return and
  /// leave the new segment empty. Queue one follow-up load instead.
  bool _pendingLikesReload = false;

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

      if (state.isLoading || state.isRefreshing || _activeLoads.contains(pageType)) {
        // Segment switch / force refresh while likes is already fetching: do
        // not drop the request — reload once the in-flight call finishes.
        // Only queue when a real in-flight load owns `_activeLoads`; orphaned
        // isLoading flags alone would never call `_finishActiveLoad`.
        if (pageType == PageType.likes && forceRefresh && _activeLoads.contains(pageType)) {
          _pendingLikesReload = true;
          DebugLogger.debug('💖 Queued likes reload while an in-flight likes fetch is active');
        }
        return;
      }

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
                  _finishActiveLoad(pageType);
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
        _finishActiveLoad(pageType);
      }
    }
  }

  void _finishActiveLoad(PageType pageType) {
    _activeLoads.remove(pageType);
    _pageState.notifyPageRefreshing(pageType, false);
    if (pageType != PageType.likes || !_pendingLikesReload) return;

    _pendingLikesReload = false;
    DebugLogger.debug('💖 Running queued likes reload after prior fetch completed');
    // Defer so we never re-enter loadPageData from inside finally/whenComplete.
    scheduleMicrotask(() {
      loadPageData(PageType.likes, forceRefresh: true);
    });
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
        final isLikedSegment = _pageState.currentLikesSegment == 'liked';
        final response = await _swipesRepo.getSwipeHistoryProperties(
          filters: state.filters.copyWith(searchQuery: state.searchQuery),
          latitude: loc.latitude,
          longitude: loc.longitude,
          cursor: cursor,
          limit: 50,
          isLiked: isLikedSegment,
        );
        // Re-read after await: concurrent remove/move/segment switch must not
        // re-append removed rows or clobber the newly selected segment.
        final latest = _pageState.getStateForPage(pageType);
        final stillOnSegment = (_pageState.currentLikesSegment == 'liked') == isLikedSegment;
        if (!stillOnSegment) {
          _pageState.updatePageState(pageType, latest.copyWith(isLoadingMore: false));
          return;
        }

        // Absorb optimistic maps for this page (clear confirmed, skip opposite)
        // then append only ids not already visible.
        final pageMerged = _pageState.mergeLikesServerResults(
          response.items,
          isLikedSegment: isLikedSegment,
        );
        final existingIds = latest.properties.map((p) => p.id).toSet();
        final toAppend = pageMerged.where((p) => !existingIds.contains(p.id)).toList();
        final newProperties = [...latest.properties, ...toAppend];
        _pageState.updatePageState(
          pageType,
          latest.copyWith(
            properties: newProperties,
            nextCursor: response.nextCursor,
            hasMore: response.hasMorePages,
            isLoadingMore: false,
          ),
        );
        _pageState.syncLikesSegmentCacheFromVisible(
          hasMore: response.hasMorePages,
          nextCursor: response.nextCursor,
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
          // Never cache discover pages — swipes must not reappear from stale cache.
          useCache: pageType != PageType.discover,
        );

        final pageItems = pageType == PageType.discover
            ? _pageState.filterOutSessionSwiped(response.items)
            : response.items;
        // Re-read after await so concurrent swipes aren't re-appended.
        final latest = _pageState.getStateForPage(pageType);
        final newProperties = [
          ...latest.properties,
          ...pageItems.where((p) => !latest.properties.any((e) => e.id == p.id)),
        ];
        _pageState.updatePageState(
          pageType,
          latest.copyWith(
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
      // Capture segment at request start via the shared getter so checks stay
      // aligned with [PageStateService.applyLikesSegmentFetchResult].
      final isLikedSegment = _pageState.currentLikesSegment == 'liked';
      final resp = await _swipesRepo.getSwipeHistoryProperties(
        filters: state.filters.copyWith(searchQuery: state.searchQuery),
        latitude: loc.latitude,
        longitude: loc.longitude,
        cursor: null,
        limit: 50,
        isLiked: isLikedSegment,
      );

      // Apply to the segment that was requested. If the user switched
      // liked/passed mid-flight, only that segment's cache is updated — the
      // visible list for the new segment is left alone.
      _pageState.applyLikesSegmentFetchResult(
        isLikedSegment: isLikedSegment,
        serverItems: resp.items,
        hasMore: resp.hasMorePages,
        nextCursor: resp.nextCursor,
      );
      // Keep selected location / error flags consistent when still on likes.
      final latest = _pageState.getStateForPage(pageType);
      final stillOnRequested = (_pageState.currentLikesSegment == 'liked') == isLikedSegment;
      if (stillOnRequested) {
        _pageState.updatePageState(
          pageType,
          latest.copyWith(
            selectedLocation: loc,
            isLoading: false,
            isRefreshing: false,
            error: null,
          ),
        );
      } else if (latest.isLoading || latest.isRefreshing) {
        // A newer load for the other segment owns loading flags.
      } else {
        // Stale segment finished after the user switched. Loading flags are
        // already false (resetData on segment switch). Queue a reload for the
        // *current* segment if the visible list is still empty and no follow-up
        // load was already requested via forceRefresh.
        _pageState.updatePageState(
          pageType,
          latest.copyWith(isLoading: false, isRefreshing: false, error: null),
        );
        if (latest.properties.isEmpty && !_pendingLikesReload) {
          _pendingLikesReload = true;
          DebugLogger.debug(
            '💖 Stale likes segment apply left empty list; queuing reload for '
            '${_pageState.currentLikesSegment}',
          );
        }
      }
      return;
    }

    // Explore/Discover
    final epochAtStart = pageType == PageType.discover ? _pageState.discoverMutationEpoch : 0;
    final resp = await _propertiesRepo.searchProperties(
      filters: state.filters.copyWith(searchQuery: state.searchQuery),
      latitude: loc.latitude,
      longitude: loc.longitude,
      radiusKm: (state.filters.radiusKm ?? 10.0).clamp(5.0, 50.0),
      cursor: null,
      limit: pageType == PageType.discover ? 20 : 50,
      excludeSwiped: pageType == PageType.discover,
      // Discover must not use HTTP cache — a stale page would re-show swiped cards.
      useCache: pageType != PageType.discover,
    );
    DebugLogger.debug(
      '📡 [DATA_LOADER] Received ${resp.items.length} properties for '
      '${pageType.name} (hasMore=${resp.hasMorePages}, '
      'nextCursor=${resp.nextCursor != null})',
    );

    // Re-read after await: swipes during the request already removed ids from
    // the local deck; also drop any session-swiped cards the API still returns.
    // If undo reinserted a card while the request was in flight, preserve it.
    final latest = _pageState.getStateForPage(pageType);
    final items = pageType == PageType.discover
        ? _pageState.mergeDiscoverRefreshResults(
            serverItems: resp.items,
            localItems: latest.properties,
            epochAtRequestStart: epochAtStart,
          )
        : resp.items;

    _pageState.updatePageState(
      pageType,
      latest.copyWith(
        properties: items,
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
