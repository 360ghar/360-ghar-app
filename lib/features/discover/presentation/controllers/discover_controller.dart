import 'dart:async';

import 'package:get/get.dart';

import 'package:ghar360/core/controllers/page_state_service.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/firebase/analytics_service.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/utils/app_toast.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/core/utils/error_mapper.dart';
import 'package:ghar360/features/dashboard/presentation/controllers/dashboard_controller.dart';

// Controllers should never talk to repositories directly

enum DiscoverState { initial, loading, loaded, empty, error, prefetching }

class DiscoverController extends GetxController {
  final PageStateService _pageStateService = Get.find<PageStateService>();

  // Reactive state
  final Rx<DiscoverState> state = DiscoverState.initial.obs;
  final Rxn<AppException> error = Rxn<AppException>();

  // currentIndex — kept for view API compatibility. Always 0 in practice
  // because swiped items are removed from the deck by PageStateService.
  final RxInt currentIndex = 0.obs;

  static const int _prefetchThreshold = 3;

  // Swipe tracking (owned exclusively by this controller)
  final RxInt totalSwipesInSession = 0.obs;
  final RxInt likesInSession = 0.obs;
  final RxInt passesInSession = 0.obs;

  // Loading states
  final RxBool isPrefetching = false.obs;

  // Workers
  Worker? _pageActivationWorker;
  Worker? _stateSyncWorker;

  // ── Deck: single source of truth from PageStateService ──

  /// The property deck is a computed view of PageStateService's discover
  /// properties. There is no separate copy; PageStateService is the sole owner
  /// of property data, pagination, and loading state.
  List<PropertyModel> get deck => _pageStateService.discoverState.value.properties;

  // ── Pagination: derived from PageStateService ──

  bool get _hasMore => _pageStateService.discoverState.value.hasMore;

  @override
  void onInit() {
    super.onInit();
    _setupStateSyncWorker();
  }

  @override
  void onReady() {
    super.onReady();

    // Listen for page activation
    _pageActivationWorker = ever(_pageStateService.currentPageType, (pageType) {
      if (pageType == PageType.discover) activatePage();
    });

    // Initial activation if already on discover page
    if (_pageStateService.currentPageType.value == PageType.discover) {
      Future.delayed(const Duration(milliseconds: 100), activatePage);
    }
  }

  /// Single worker that derives controller state from PageStateService.
  /// This replaces the former dual-sync mechanism (_setupPageStateSync +
  /// _hydrateDeckFromPageState) that could drift out of sync.
  void _setupStateSyncWorker() {
    _stateSyncWorker = ever(_pageStateService.discoverState, (PageStateModel ps) {
      // Don't override while prefetching
      if (isPrefetching.value) return;

      if (ps.isLoading && !ps.isRefreshing) {
        state.value = DiscoverState.loading;
      } else if (ps.error != null && ps.properties.isEmpty) {
        state.value = DiscoverState.error;
        error.value = ps.error;
      } else if (ps.properties.isEmpty && !ps.isLoading && !ps.isRefreshing) {
        // Only mark empty if we've actually attempted a load
        if (state.value != DiscoverState.initial) {
          state.value = DiscoverState.empty;
        }
      } else if (ps.properties.isNotEmpty) {
        // Transition to loaded from any non-loaded state when properties arrive.
        // Previously this only allowed transition from loading/initial, which
        // caused a permanent "empty" state if properties arrived after the
        // controller had already transitioned to empty or error.
        if (state.value != DiscoverState.loaded && state.value != DiscoverState.prefetching) {
          state.value = DiscoverState.loaded;
          error.value = null;
        }
      }

      // Keep currentIndex in bounds
      if (currentIndex.value > 0 && currentIndex.value >= ps.properties.length) {
        currentIndex.value = 0;
      }
    });
  }

  void activatePage() {
    final ps = _pageStateService.discoverState.value;
    final hasStaleLoadingWithoutData = ps.properties.isEmpty && ps.isLoading && !ps.isRefreshing;
    final shouldRequestWhenEmpty =
        ps.properties.isEmpty &&
        (state.value == DiscoverState.initial ||
            ps.isDataStale ||
            ps.error != null ||
            hasStaleLoadingWithoutData);

    // Already have fresh data — just ensure state is correct
    if (ps.properties.isNotEmpty && !ps.isDataStale) {
      if (state.value == DiscoverState.initial) {
        state.value = DiscoverState.loaded;
      }
      return;
    }

    // Stale data — background refresh
    if (ps.properties.isNotEmpty && ps.isDataStale) {
      _pageStateService.loadPageData(PageType.discover, backgroundRefresh: true);
      return;
    }

    // No data yet — initialize location then load
    if (shouldRequestWhenEmpty) {
      if (hasStaleLoadingWithoutData) {
        DebugLogger.warning(
          '🩹 [DISCOVER] Detected stale loading flag with empty data. Forcing reload.',
        );
      }
      // useCurrentLocationForPage triggers debounceRefresh internally,
      // which calls loadPageData. No need for a separate _loadInitialDeck.
      state.value = DiscoverState.loading;
      _pageStateService.useCurrentLocationForPage(PageType.discover);
      return;
    }

    if (ps.properties.isEmpty) {
      DebugLogger.warning(
        '🩹 [DISCOVER] activatePage: Empty properties with state=${state.value}, '
        'isDataStale=${ps.isDataStale}, lastFetched=${ps.lastFetched}. Forcing reload.',
      );
      state.value = DiscoverState.loading;
      _pageStateService.useCurrentLocationForPage(PageType.discover);
    }
  }

  Future<void> _loadInitialDeck({bool ignoreLoadingGuard = false}) async {
    if (!ignoreLoadingGuard && state.value == DiscoverState.loading) return;

    try {
      state.value = DiscoverState.loading;
      error.value = null;
      currentIndex.value = 0;

      await _pageStateService.loadPageData(PageType.discover, forceRefresh: true);
      // State is derived by _stateSyncWorker when discoverState updates
    } catch (e, stackTrace) {
      DebugLogger.error('❌ Failed to load initial deck', e, stackTrace);
      state.value = DiscoverState.error;
      error.value = ErrorMapper.mapApiError(e, stackTrace);
    }
  }

  // ── Swipe actions ──

  Future<void> swipeRight(PropertyModel property) async {
    if (!await _handleSwipe(property, true)) return;
    _recordSwipeStats(true);
    _recordDashboardActivity(
      type: 'like',
      title: 'dashboard_activity_liked'.trParams({'property': property.title}),
      icon: 'favorite',
      liked: true,
    );
    await _safeAnalytics(
      'property_like',
      () => AnalyticsService.likeProperty(property.id.toString()),
    );
  }

  Future<void> swipeLeft(PropertyModel property) async {
    if (!await _handleSwipe(property, false)) return;
    _recordSwipeStats(false);
    _recordDashboardActivity(
      type: 'pass',
      title: 'dashboard_activity_passed'.trParams({'property': property.title}),
      icon: 'close',
      liked: false,
    );
    await _safeAnalytics(
      'property_pass',
      () => AnalyticsService.logVital('property_pass', params: {'id': property.id.toString()}),
    );
  }

  /// Records swipe activity to the locally-persisted dashboard stats so the
  /// dashboard reflects real usage instead of fabricated data.
  void _recordDashboardActivity({
    required String type,
    required String title,
    required String icon,
    required bool liked,
  }) {
    try {
      if (!Get.isRegistered<DashboardController>()) return;
      final dash = Get.find<DashboardController>();
      dash.incrementStat(kDashPropertiesViewedKey);
      if (liked) dash.incrementStat(kDashPropertiesLikedKey);
      dash.recordActivity(type: type, title: title, icon: icon);
    } catch (e) {
      DebugLogger.warning('Failed to record dashboard activity: $e');
    }
  }

  /// Returns false when the swipe was ignored as a duplicate gesture.
  Future<bool> _handleSwipe(PropertyModel property, bool isLiked) async {
    // recordSwipe synchronously removes the property from the deck, so a
    // property no longer in the deck means this gesture is a duplicate
    // (e.g. rapid double-tap on an action button) — ignore it.
    if (!deck.any((p) => p.id == property.id)) {
      DebugLogger.warning('⚠️ Ignoring duplicate swipe for property ${property.id}');
      return false;
    }
    try {
      DebugLogger.api(
        '👆 Swiping ${isLiked ? 'RIGHT (LIKE)' : 'LEFT (PASS)'}: '
        '${property.title}',
      );

      // Delegate mutation to PageStateService.
      // This synchronously removes the property from the discover deck
      // (optimistic update) and fires a background network call.
      // Because the swiped property is removed, the next card naturally
      // becomes deck[currentIndex] — no index increment needed.
      _pageStateService
          .recordSwipe(propertyId: property.id, isLiked: isLiked)
          .catchError(
            (e) => DebugLogger.error('❌ Failed to record swipe for property ${property.id}: $e'),
          );

      // Track for undo
      _lastSwipe = (property: property, isLiked: isLiked);

      // After optimistic removal, check deck state
      if (deck.isEmpty) {
        if (_hasMore) {
          _prefetchMoreProperties();
        } else {
          state.value = DiscoverState.empty;
          unawaited(
            _safeAnalytics(
              'deck_exhausted',
              () => AnalyticsService.deckExhausted(totalSwiped: totalSwipesInSession.value),
            ),
          );
        }
      } else {
        _checkForPrefetch();
      }
      return true;
    } catch (e) {
      DebugLogger.error('❌ Failed to handle swipe: $e');
      return false;
    }
  }

  void _recordSwipeStats(bool isLiked) {
    totalSwipesInSession.value++;
    if (isLiked) {
      likesInSession.value++;
    } else {
      passesInSession.value++;
    }
  }

  void _checkForPrefetch() {
    final remaining = deck.length - currentIndex.value - 1;

    if (remaining <= _prefetchThreshold && _hasMore && !isPrefetching.value) {
      _prefetchMoreProperties();
    }
  }

  Future<void> _prefetchMoreProperties() async {
    if (isPrefetching.value || !_hasMore) return;

    try {
      isPrefetching.value = true;
      state.value = DiscoverState.prefetching;

      DebugLogger.api('🔄 Prefetching more properties...');
      await _pageStateService.loadMoreData(PageType.discover);

      if (state.value == DiscoverState.prefetching) {
        state.value = DiscoverState.loaded;
      }
    } catch (e) {
      DebugLogger.error('❌ Prefetch failed: $e');
    } finally {
      isPrefetching.value = false;
    }
  }

  // ── Manual refresh ──

  Future<void> refreshDeck() async {
    totalSwipesInSession.value = 0;
    likesInSession.value = 0;
    passesInSession.value = 0;
    currentIndex.value = 0;

    await _loadInitialDeck();
  }

  // ── Undo ──

  /// Tracks the last swiped property so it can be restored by [undoLastSwipe].
  /// Cleared after a successful undo or overwritten by the next swipe.
  ({PropertyModel property, bool isLiked})? _lastSwipe;

  bool get canUndo => _lastSwipe != null;

  Future<void> undoLastSwipe() async {
    final last = _lastSwipe;
    if (last == null) {
      AppToast.info('undo_unavailable'.tr, 'undo_no_previous_property'.tr);
      return;
    }

    try {
      // Restore the property to the front of the discover deck so the user
      // sees it again as the top card.
      _pageStateService.reinsertPropertyToDiscover(last.property);

      // Reverse the server-side swipe state and adjust likes list.
      // Uses undoSwipe (not recordSwipe) so the property is NOT removed from
      // the discover deck again.
      unawaited(
        _pageStateService
            .undoSwipe(propertyId: last.property.id, originalIsLiked: last.isLiked)
            .catchError((e) => DebugLogger.error('❌ Undo reverse-swipe failed: $e')),
      );

      // Update session stats
      totalSwipesInSession.value = (totalSwipesInSession.value - 1).clamp(0, 1 << 31);
      if (last.isLiked) {
        likesInSession.value = (likesInSession.value - 1).clamp(0, 1 << 31);
      } else {
        passesInSession.value = (passesInSession.value - 1).clamp(0, 1 << 31);
      }

      // Reverse the persisted dashboard stats that the original swipe recorded
      // via [_recordDashboardActivity]. Keeps persisted counters in sync so
      // undo does not leave dashboard stats permanently inflated.
      try {
        if (Get.isRegistered<DashboardController>()) {
          final dash = Get.find<DashboardController>();
          dash.decrementStat(kDashPropertiesViewedKey);
          if (last.isLiked) dash.decrementStat(kDashPropertiesLikedKey);
        }
      } catch (e) {
        DebugLogger.warning('Failed to reverse dashboard stats on undo: $e');
      }

      // Clear so a second undo does nothing
      _lastSwipe = null;

      // Ensure the controller reflects the restored deck
      if (state.value != DiscoverState.loaded && state.value != DiscoverState.prefetching) {
        state.value = DiscoverState.loaded;
      }

      AppToast.success('undo_success'.tr, 'undo_previous_property'.tr);
    } catch (e) {
      DebugLogger.error('❌ Failed to undo last swipe: $e');
      AppToast.error('action_failed'.tr, 'undo_failed'.tr);
    }
  }

  // ── Computed getters ──

  PropertyModel? get currentProperty {
    if (deck.isEmpty || currentIndex.value >= deck.length) return null;
    return deck[currentIndex.value];
  }

  List<PropertyModel> get nextProperties {
    final start = currentIndex.value + 1;
    final end = (start + 3).clamp(0, deck.length);
    return deck.sublist(start, end);
  }

  int get remainingCards => deck.isEmpty ? 0 : deck.length - currentIndex.value - 1;

  double get progressPercentage {
    if (deck.isEmpty) return 0.0;
    return (currentIndex.value / deck.length).clamp(0.0, 1.0);
  }

  String get sessionStats {
    if (totalSwipesInSession.value == 0) {
      return 'start_swiping_stats'.tr;
    }

    final likeRate = (likesInSession.value / totalSwipesInSession.value * 100).round();
    return 'session_stats'.trParams({
      'swipes': '${totalSwipesInSession.value}',
      'likes': '${likesInSession.value}',
      'rate': '$likeRate',
    });
  }

  // ── Navigation ──

  void viewPropertyDetails(PropertyModel property) {
    unawaited(
      _safeAnalytics(
        'property_view',
        () => AnalyticsService.viewPropertyOnce(property.id.toString()),
      ),
    );
    Get.toNamed(AppRoutes.propertyDetails, arguments: property);
  }

  Future<void> _safeAnalytics(String event, Future<void> Function() action) async {
    try {
      await action();
    } catch (e, stackTrace) {
      DebugLogger.warning('Analytics call failed for $event', e, stackTrace);
    }
  }

  // ── Filter shortcuts ──

  Future<void> showNearbyProperties() async {
    await _pageStateService.useCurrentLocation();
  }

  void filterByPropertyType(String type) {
    final currentFilters = _pageStateService.getCurrentPageState().filters;
    final updatedFilters = currentFilters.copyWith(propertyType: [type]);
    _pageStateService.updatePageFilters(PageType.discover, updatedFilters);
  }

  void filterByPurpose(String purpose) {
    final currentFilters = _pageStateService.getCurrentPageState().filters;
    final updatedFilters = currentFilters.copyWith(purpose: purpose);
    _pageStateService.updatePageFilters(PageType.discover, updatedFilters);
  }

  // ── Error handling ──

  void retryLoading() {
    error.value = null;
    _loadInitialDeck();
  }

  void clearError() {
    error.value = null;
    if (state.value == DiscoverState.error) {
      state.value = deck.isEmpty ? DiscoverState.empty : DiscoverState.loaded;
    }
  }

  @override
  void onClose() {
    _pageActivationWorker?.dispose();
    _stateSyncWorker?.dispose();
    super.onClose();
  }

  // ── Helper getters ──

  bool get isLoading => state.value == DiscoverState.loading;
  bool get isEmpty => state.value == DiscoverState.empty;
  bool get hasError => state.value == DiscoverState.error;
  bool get isLoaded => state.value == DiscoverState.loaded;
  bool get hasProperties => deck.isNotEmpty;
  bool get canSwipe => hasProperties && currentProperty != null;
}
