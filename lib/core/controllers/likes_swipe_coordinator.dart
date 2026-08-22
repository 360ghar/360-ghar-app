import 'package:ghar360/core/controllers/page_state_service.dart';
import 'package:ghar360/core/data/models/likes_segment.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/data/ports/swipes_port.dart';
import 'package:ghar360/core/utils/debug_logger.dart';

/// Owns the likes/swipe domain for [PageStateService]: per-segment caches,
/// optimistic like/pass tracking, session-swiped filtering and merge logic,
/// and swipe recording with network sync. Visible-list mutations go through
/// the service's page-state accessors so Rx state ownership stays in one
/// place.
class LikesSwipeCoordinator {
  LikesSwipeCoordinator(this._pageState, this._swipesPort);

  final PageStateService _pageState;
  final SwipesPort _swipesPort;

  // Swipe recording & optimistic mutations
  // ──────────────────────────────────────────────────────────────────

  /// Bumped whenever the Discover deck is mutated locally (swipe / undo /
  /// remove); kept for potential stale-response guards.
  int _discoverMutationEpoch = 0;

  void _bumpDiscoverMutation() => _discoverMutationEpoch++;

  /// [property] should be passed when the caller already holds the model
  /// (e.g. Likes remove/move) so optimistic segment updates still work after
  /// the card was removed from the visible list.
  Future<void> recordSwipe({
    required int propertyId,
    required bool isLiked,
    PropertyModel? property,
  }) async {
    // Maintain liked/passed segment caches AND the visible list so the Likes
    // tab reflects Discover swipes immediately, regardless of which segment
    // is currently selected.
    final prop = property ?? _findPropertyInAnyList(propertyId);
    if (isLiked) {
      if (prop != null) {
        // Single path for optimistic like + segment caches (shared with tests).
        addPropertyToLikes(prop);
      }
      if (currentLikesSegment == LikesSegment.passed) {
        removePropertyFromLikes(propertyId);
      }
    } else {
      // Pass: drop from liked, add to passed.
      if (prop != null) {
        addPropertyToPassed(prop);
      } else {
        // Still drop any pending like for this id.
        _optimisticLiked.remove(propertyId);
        _removeFromLikesSegmentCache(LikesSegment.liked, propertyId);
      }
      if (currentLikesSegment == LikesSegment.liked) {
        removePropertyFromLikes(propertyId);
      }
    }

    // Also remove from discover deck optimistically and remember the id so
    // a later discover refresh (cache / server lag) cannot reintroduce it.
    _sessionSwipedPropertyIds.add(propertyId);
    removePropertyFromDiscover(propertyId);

    // Network sync — await so failures propagate to callers, which revert the
    // optimistic mutation and/or surface a toast. Callers all handle errors.
    await _swipesPort.recordSwipe(propertyId: propertyId, isLiked: isLiked);
  }

  PropertyModel? _findPropertyInAnyList(int propertyId) {
    for (final p in _pageState.exploreState.value.properties) {
      if (p.id == propertyId) return p;
    }
    for (final p in _pageState.discoverState.value.properties) {
      if (p.id == propertyId) return p;
    }
    for (final p in _pageState.likesState.value.properties) {
      if (p.id == propertyId) return p;
    }
    // Segment caches + optimistic maps (caller may have already removed the
    // card from the visible list).
    for (final cache in _likesSegmentCache.values) {
      for (final p in cache.properties) {
        if (p.id == propertyId) return p;
      }
    }
    return _optimisticLiked[propertyId] ?? _optimisticPassed[propertyId];
  }

  void removePropertyFromDiscover(int propertyId) {
    _discoverPreserveIds.remove(propertyId);
    _bumpDiscoverMutation();
    final state = _pageState.discoverState.value;
    final updatedList = state.properties.where((p) => p.id != propertyId).toList();
    _pageState.updatePageState(PageType.discover, state.copyWith(properties: updatedList));
  }

  /// Property ids swiped this session. Discover fetch results are filtered
  /// against this set so cards do not reappear after tab switches / refresh
  /// races before `exclude_swiped` is reflected server-side.
  final Set<int> _sessionSwipedPropertyIds = <int>{};

  /// Property ids explicitly reinserted by undo. [mergeDiscoverRefreshResults]
  /// only preserves these local-only cards across an in-flight fetch — never
  /// the whole remaining deck (which would glue old location/filter cards onto
  /// a new server page after a mid-refresh swipe).
  final Set<int> _discoverPreserveIds = <int>{};

  /// Filters [items] to drop any property swiped earlier in this session.
  List<PropertyModel> filterOutSessionSwiped(List<PropertyModel> items) {
    if (_sessionSwipedPropertyIds.isEmpty || items.isEmpty) return items;
    final filtered = items.where((p) => !_sessionSwipedPropertyIds.contains(p.id)).toList();
    final removed = items.length - filtered.length;
    if (removed > 0) {
      DebugLogger.debug(
        '👆 Filtered $removed session-swiped propert'
        '${removed == 1 ? 'y' : 'ies'} from discover results',
      );
    }
    return filtered;
  }

  bool isSessionSwiped(int propertyId) => _sessionSwipedPropertyIds.contains(propertyId);

  /// Re-inserts a property at the front of the discover deck. Used by the
  /// undo-swipe flow to restore the previously-swiped property so the user
  /// sees it again as the top card.
  void reinsertPropertyToDiscover(PropertyModel property) {
    _sessionSwipedPropertyIds.remove(property.id);
    _discoverPreserveIds.add(property.id);
    _bumpDiscoverMutation();
    final state = _pageState.discoverState.value;
    final exists = state.properties.any((p) => p.id == property.id);
    if (exists) return;
    final updatedList = [property, ...state.properties];
    _pageState.updatePageState(PageType.discover, state.copyWith(properties: updatedList));
  }

  /// Merges a Discover network page with the local deck when concurrent
  /// mutations (swipe/undo) happened during the request.
  ///
  /// Only cards explicitly reinserted via [reinsertPropertyToDiscover] are
  /// kept when missing from the server page — and they are kept whether the
  /// undo happened mid-flight or just before the request started. A plain
  /// swipe must never preserve the rest of the pre-refresh deck (that would
  /// glue old location/filter cards onto a new server page). Session-swiped
  /// ids always stay out.
  List<PropertyModel> mergeDiscoverRefreshResults({
    required List<PropertyModel> serverItems,
    required List<PropertyModel> localItems,
  }) {
    final filtered = filterOutSessionSwiped(serverItems);
    final serverIds = filtered.map((p) => p.id).toSet();

    // Always honor undo-reinsert markers, whether the undo happened mid-flight
    // or just before the request started.
    final preserve = <PropertyModel>[];
    if (_discoverPreserveIds.isNotEmpty) {
      for (final p in localItems) {
        if (!_discoverPreserveIds.contains(p.id)) continue;
        if (serverIds.contains(p.id)) continue;
        if (_sessionSwipedPropertyIds.contains(p.id)) continue;
        preserve.add(p);
      }
    }

    // Consume markers after this merge so a later page does not keep resurrecting
    // cards that were already applied (or that the server now owns).
    _discoverPreserveIds.clear();

    if (preserve.isEmpty) return filtered;

    DebugLogger.debug(
      '👆 Preserving ${preserve.length} undo-reinserted Discover card'
      '${preserve.length == 1 ? '' : 's'} after fetch merge',
    );
    return [...preserve, ...filtered];
  }

  /// Reverses a previously-recorded swipe for the undo flow. Unlike
  /// [recordSwipe], this does NOT remove the property from the discover deck
  /// (it was just reinserted by [reinsertPropertyToDiscover]). It only
  /// reverses the likes list mutation from the original swipe and fires the
  /// background network sync with the opposite action.
  ///
  /// Pass [notifyServer]: false when the original swipe never reached the
  /// server (e.g. [recordSwipe]'s network call failed) — there is nothing to
  /// reverse remotely in that case, only the local optimistic state.
  Future<void> undoSwipe({
    required int propertyId,
    required bool originalIsLiked,
    bool notifyServer = true,
  }) async {
    // Reverse ONLY the likes/passed mutations that the original swipe made:
    // - Original LIKE added to liked → undo removes from liked (and its cache).
    // - Original PASS added to passed → undo removes from passed cache only.
    if (originalIsLiked) {
      _optimisticLiked.remove(propertyId);
      _removeFromLikesSegmentCache(LikesSegment.liked, propertyId);
      if (currentLikesSegment == LikesSegment.liked) {
        removePropertyFromLikes(propertyId);
      }
    } else {
      _optimisticPassed.remove(propertyId);
      _removeFromLikesSegmentCache(LikesSegment.passed, propertyId);
      if (currentLikesSegment == LikesSegment.passed) {
        removePropertyFromLikes(propertyId);
      }
    }

    if (!notifyServer) return;

    // Network sync with the REVERSED action. Without a delete-swipe API,
    // recording the opposite is the best reversal we can do. Await so failures
    // propagate to the caller (which logs via catchError).
    await _swipesPort.recordSwipe(propertyId: propertyId, isLiked: !originalIsLiked);
  }

  void removePropertyFromLikes(int propertyId) {
    // User explicitly removed from the visible segment — drop pending too.
    if (currentLikesSegment == LikesSegment.liked) {
      _optimisticLiked.remove(propertyId);
    } else {
      _optimisticPassed.remove(propertyId);
    }
    final state = _pageState.likesState.value;
    final updatedList = state.properties.where((p) => p.id != propertyId).toList();
    _pageState.updatePageState(PageType.likes, state.copyWith(properties: updatedList));
    // Keep whichever segment is currently loaded in sync with its cache.
    _removeFromLikesSegmentCache(currentLikesSegment, propertyId);
  }

  void addPropertyToLikes(PropertyModel property) {
    // Always keep the liked segment cache fresh so switching tabs / revisiting
    // Likes shows the property even if the user was on "passed" when swiping.
    _trackOptimisticLike(property);
    _upsertLikesSegmentCache(LikesSegment.liked, property);
    _removeFromLikesSegmentCache(LikesSegment.passed, property.id);
    if (currentLikesSegment != LikesSegment.liked) return;
    _prependToVisibleLikesList(property);
  }

  void addPropertyToPassed(PropertyModel property) {
    _trackOptimisticPass(property);
    _upsertLikesSegmentCache(LikesSegment.passed, property);
    _removeFromLikesSegmentCache(LikesSegment.liked, property.id);
    if (currentLikesSegment != LikesSegment.passed) return;
    _prependToVisibleLikesList(property);
  }

  // ── Optimistic likes/pass that survive server refresh races ──

  /// Properties liked/passed locally but not yet returned by history API.
  /// Prevents background refresh from flash-removing a just-swiped card.
  final Map<int, PropertyModel> _optimisticLiked = {};
  final Map<int, PropertyModel> _optimisticPassed = {};

  void _trackOptimisticLike(PropertyModel property) {
    _optimisticLiked[property.id] = property;
    _optimisticPassed.remove(property.id);
  }

  void _trackOptimisticPass(PropertyModel property) {
    _optimisticPassed[property.id] = property;
    _optimisticLiked.remove(property.id);
  }

  /// Merges a server history page with still-pending optimistic swipes.
  ///
  /// Pending items that the server now includes are cleared. Remaining
  /// pending items are prepended so a racey refresh cannot wipe them.
  /// Server items still present in the *opposite* optimistic map are skipped
  /// so a newer local reverse-swipe is not clobbered by a stale history page.
  List<PropertyModel> mergeLikesServerResults(
    List<PropertyModel> serverItems, {
    required bool isLikedSegment,
  }) {
    final optimistic = isLikedSegment ? _optimisticLiked : _optimisticPassed;
    final opposite = isLikedSegment ? _optimisticPassed : _optimisticLiked;
    final serverIds = <int>{};
    final merged = <PropertyModel>[];

    for (final p in serverItems) {
      if (opposite.containsKey(p.id)) {
        // Newer opposite local swipe wins over this stale server row.
        continue;
      }
      serverIds.add(p.id);
      optimistic.remove(p.id);
      merged.add(p);
    }

    final pending = optimistic.values.where((p) => !serverIds.contains(p.id)).toList();
    if (pending.isEmpty) return merged;

    DebugLogger.debug(
      '💖 Preserving ${pending.length} optimistic '
      '${isLikedSegment ? LikesSegment.liked.name : LikesSegment.passed.name} properties after server merge',
    );
    return [...pending, ...merged];
  }

  /// Applies a likes history fetch to the correct segment cache, and only
  /// updates the visible list when that segment is still selected.
  void applyLikesSegmentFetchResult({
    required bool isLikedSegment,
    required List<PropertyModel> serverItems,
    required bool hasMore,
    String? nextCursor,
  }) {
    final segment = isLikedSegment ? LikesSegment.liked : LikesSegment.passed;
    final merged = mergeLikesServerResults(serverItems, isLikedSegment: isLikedSegment);
    final now = DateTime.now();
    _likesSegmentCache[segment] = _LikesSegmentCache(
      properties: List.of(merged),
      lastFetched: now,
      hasMore: hasMore,
      nextCursor: nextCursor,
    );

    if (currentLikesSegment != segment) {
      DebugLogger.debug(
        '💖 Discarded visible apply for stale likes segment=${segment.name} '
        '(current=${currentLikesSegment.name}); cache updated only',
      );
      return;
    }

    final latest = _pageState.likesState.value;
    _pageState.updatePageState(
      PageType.likes,
      latest.copyWith(
        properties: merged,
        nextCursor: nextCursor,
        hasMore: hasMore,
        isLoading: false,
        isRefreshing: false,
        lastFetched: now,
        error: null,
      ),
    );
  }

  /// Snapshots the current likes list into the per-segment cache after a fetch.
  void syncLikesSegmentCacheFromVisible({required bool hasMore, String? nextCursor}) {
    final segment = currentLikesSegment;
    final ps = _pageState.likesState.value;
    _likesSegmentCache[segment] = _LikesSegmentCache(
      properties: List.of(ps.properties),
      lastFetched: ps.lastFetched ?? DateTime.now(),
      hasMore: hasMore,
      nextCursor: nextCursor,
    );
  }

  /// Prepends [property] to the currently visible likes list (no segment check).
  void _prependToVisibleLikesList(PropertyModel property) {
    final state = _pageState.likesState.value;
    final exists = state.properties.any((p) => p.id == property.id);
    if (exists) return;
    _pageState.updatePageState(PageType.likes, state.copyWith(properties: [property, ...state.properties]));
  }

  void _upsertLikesSegmentCache(LikesSegment segment, PropertyModel property) {
    final existing = _likesSegmentCache[segment];
    final list = List<PropertyModel>.of(existing?.properties ?? const []);
    list.removeWhere((p) => p.id == property.id);
    list.insert(0, property);
    _likesSegmentCache[segment] = _LikesSegmentCache(
      properties: list,
      // Keep lastFetched null when this cache entry is seeded purely from an
      // optimistic swipe: a fresh timestamp would make the segment look like
      // a complete server page and updateLikesSegment would restore only the
      // session's optimistic entries, hiding the user's real history.
      lastFetched: existing?.lastFetched,
      hasMore: existing?.hasMore ?? true,
      nextCursor: existing?.nextCursor,
    );
  }

  void _removeFromLikesSegmentCache(LikesSegment segment, int propertyId) {
    final existing = _likesSegmentCache[segment];
    if (existing == null) return;
    final list = existing.properties.where((p) => p.id != propertyId).toList();
    if (list.length == existing.properties.length) return;
    _likesSegmentCache[segment] = _LikesSegmentCache(
      properties: list,
      lastFetched: existing.lastFetched,
      hasMore: existing.hasMore,
      nextCursor: existing.nextCursor,
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // Likes segment management
  // ──────────────────────────────────────────────────────────────────

  /// In-memory per-segment cache so switching between Liked and Passed tabs
  /// reuses recently-fetched data instead of always hitting the API.
  /// Not persisted (avoids disk bloat); rebuilt on cold start.
  final Map<LikesSegment, _LikesSegmentCache> _likesSegmentCache = {};

  /// Switches the likes segment (liked/passed). Reuses cached data when fresh;
  /// only fetches from the network when the segment's cache is empty or stale.
  void updateLikesSegment(LikesSegment target) {
    final previousSegment = currentLikesSegment;
    if (previousSegment == target) return;

    // Snapshot the outgoing segment's data before switching
    final ps = _pageState.getStateForPage(PageType.likes);
    _likesSegmentCache[previousSegment] = _LikesSegmentCache(
      properties: List.of(ps.properties),
      lastFetched: ps.lastFetched,
      hasMore: ps.hasMore,
      nextCursor: ps.nextCursor,
    );

    // Switch the segment marker
    final marked =
        _pageState.getStateForPage(PageType.likes).updateAdditionalData(
              LikesSegment.additionalDataKey,
              target.name,
            );
    _pageState.updatePageState(PageType.likes, marked);

    // Restore cached data for the target segment if fresh; either way the
    // restored list is surfaced immediately. Without a fresh cache the fetch
    // completion merges optimistic entries over the server results, so the
    // user's just-swiped items are never hidden behind a purely-optimistic
    // cache.
    final cached = _likesSegmentCache[target];
    final restored = _pageState.getStateForPage(PageType.likes).copyWith(
      properties: cached != null ? List.of(cached.properties) : [],
      lastFetched: cached?.lastFetched,
      hasMore: cached?.hasMore ?? true,
      nextCursor: cached?.nextCursor,
      error: null,
      isLoading: false,
      isLoadingMore: false,
      isRefreshing: false,
    );
    _pageState.updatePageState(PageType.likes, restored);
    if (cached != null && !cached.isStale) return;

    _pageState.loadPageData(PageType.likes, forceRefresh: true);
  }

  LikesSegment get currentLikesSegment => LikesSegment.tryParse(_pageState
      .getStateForPage(PageType.likes)
      .getAdditionalData<String>(LikesSegment.additionalDataKey));

  /// Drops all session-scoped likes/swipe bookkeeping (logout / account
  /// switch): segment caches, optimistic maps, swiped and preserve markers.
  void resetForSession() {
    _likesSegmentCache.clear();
    _optimisticLiked.clear();
    _optimisticPassed.clear();
    _sessionSwipedPropertyIds.clear();
    _discoverPreserveIds.clear();
  }
}


/// In-memory cache for a single likes segment (liked or passed), used to
/// avoid re-fetching when the user switches tabs back and forth.
class _LikesSegmentCache {
  final List<PropertyModel> properties;
  final DateTime? lastFetched;
  final bool hasMore;
  final String? nextCursor;

  _LikesSegmentCache({
    required this.properties,
    required this.lastFetched,
    required this.hasMore,
    this.nextCursor,
  });

  static const Duration _staleThreshold = Duration(minutes: 5);

  bool get isStale {
    final fetched = lastFetched;
    if (fetched == null) return true;
    return DateTime.now().difference(fetched) > _staleThreshold;
  }
}
