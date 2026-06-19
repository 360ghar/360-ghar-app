import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/controllers/location_controller.dart';
import 'package:ghar360/core/controllers/page_data_loader.dart';
import 'package:ghar360/core/controllers/page_filter_manager.dart';
import 'package:ghar360/core/controllers/page_location_manager.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/utils/app_toast.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/features/properties/data/properties_repository.dart';
import 'package:ghar360/features/swipes/data/swipes_repository.dart';

class PageStateService extends GetxController {
  static PageStateService get instance => Get.find<PageStateService>();

  // Storage instance
  final _storage = GetStorage();
  static const _pageStateSchemaVersionKey = 'page_state_schema_version';
  static const _currentPageStateSchemaVersion = 2;
  static const _exploreStateStorageKey = 'explore_state';
  static const _discoverStateStorageKey = 'discover_state';
  static const _likesStateStorageKey = 'likes_state';
  // Dependencies initialized in onInit to avoid race conditions
  late final LocationController _locationController;
  late final AuthController _authController;
  late final SwipesRepository _swipesRepository;

  // Page states
  final Rx<PageStateModel> exploreState = PageStateModel.initial(PageType.explore).obs;
  final Rx<PageStateModel> discoverState = PageStateModel.initial(PageType.discover).obs;
  final Rx<PageStateModel> likesState = PageStateModel.initial(PageType.likes).obs;

  // Current active page
  final Rx<PageType> currentPageType = PageType.discover.obs;

  // Top bar refresh indicators (per page)
  final RxBool _exploreRefreshing = false.obs;
  final RxBool _discoverRefreshing = false.obs;
  final RxBool _likesRefreshing = false.obs;

  // Persistence debounce timers (500ms to batch rapid state updates)
  Timer? _explorePersistDebouncer;
  Timer? _discoverPersistDebouncer;
  Timer? _likesPersistDebouncer;
  static const _persistDebounceMs = 500;

  // Sub-services (initialized in onInit)
  late final PageDataLoader _dataLoader;
  late final PageFilterManager _filterManager;
  late final PageLocationManager _locationManager;

  @override
  Future<void> onInit() async {
    super.onInit();

    // Initialize dependencies with retry logic for race condition protection
    _locationController = await _findDependencyWithRetry<LocationController>(
      'LocationController',
      maxRetries: 3,
    );
    _authController = await _findDependencyWithRetry<AuthController>(
      'AuthController',
      maxRetries: 3,
    );
    _swipesRepository = await _findDependencyWithRetry<SwipesRepository>(
      'SwipesRepository',
      maxRetries: 3,
    );

    // Initialize sub-services
    _dataLoader = PageDataLoader(
      this,
      Get.find<PropertiesRepository>(),
      _swipesRepository,
      _locationController,
    );
    _filterManager = PageFilterManager(this, _dataLoader, _storage);
    _locationManager = PageLocationManager(this, _dataLoader, _locationController, _authController);

    _migratePersistedStateSchemaIfNeeded();
    _loadSavedStates();
    // Apply globally saved purpose/type if present, then ensure sane defaults
    _filterManager.applySavedGlobalFilters();
    // Ensure default purpose is set to 'buy' when unset for new users
    _filterManager.setPurposeForAllPages('buy', onlyIfUnset: true);
    _bootstrapInitialStates();
    _setupListeners();
  }

  /// Finds a dependency with retry logic to handle race conditions during initialization.
  Future<T> _findDependencyWithRetry<T>(String name, {required int maxRetries}) async {
    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      if (Get.isRegistered<T>()) {
        return Get.find<T>();
      }
      DebugLogger.warning(
        '⏳ PageStateService: $name not registered yet (attempt $attempt/$maxRetries), waiting...',
      );
      // Small delay to allow other bindings to complete
      await Future.delayed(Duration(milliseconds: 50 * attempt));
    }
    throw StateError(
      '$name not registered before PageStateService initialization '
      '(tried $maxRetries times). Ensure DashboardBinding registers all repositories before PageStateService.',
    );
  }

  @override
  void onClose() {
    _dataLoader.dispose();
    _filterManager.dispose();
    _locationManager.dispose();
    // Cancel persistence debouncers
    _explorePersistDebouncer?.cancel();
    _discoverPersistDebouncer?.cancel();
    _likesPersistDebouncer?.cancel();
    super.onClose();
  }

  // ──────────────────────────────────────────────────────────────────
  // State accessors (used by sub-services)
  // ──────────────────────────────────────────────────────────────────

  PageStateModel getStateForPage(PageType pageType) {
    switch (pageType) {
      case PageType.explore:
        return exploreState.value;
      case PageType.discover:
        return discoverState.value;
      case PageType.likes:
        return likesState.value;
    }
  }

  void updatePageState(PageType pageType, PageStateModel newState) {
    switch (pageType) {
      case PageType.explore:
        exploreState.value = newState;
        break;
      case PageType.discover:
        discoverState.value = newState;
        break;
      case PageType.likes:
        likesState.value = newState;
        break;
    }
  }

  // Get current page state
  PageStateModel getCurrentPageState() {
    return getStateForPage(currentPageType.value);
  }

  void setCurrentPage(PageType pageType) {
    if (currentPageType.value == pageType) return;

    final oldPageType = currentPageType.value;
    currentPageType.value = pageType;
    DebugLogger.info('📱 Switched from ${oldPageType.name} to ${pageType.name} page');
  }

  // ──────────────────────────────────────────────────────────────────
  // Delegates: Data loading (→ PageDataLoader)
  // ──────────────────────────────────────────────────────────────────

  Future<void> loadPageData(
    PageType pageType, {
    bool forceRefresh = false,
    bool backgroundRefresh = false,
  }) => _dataLoader.loadPageData(
    pageType,
    forceRefresh: forceRefresh,
    backgroundRefresh: backgroundRefresh,
  );

  Future<void> loadMorePageData(PageType pageType) => _dataLoader.loadMorePageData(pageType);

  Future<void> loadMoreData(PageType pageType) => _dataLoader.loadMoreData(pageType);

  // ──────────────────────────────────────────────────────────────────
  // Delegates: Filters & search (→ PageFilterManager)
  // ──────────────────────────────────────────────────────────────────

  void updatePageFilters(PageType pageType, UnifiedFilterModel filters) =>
      _filterManager.updatePageFilters(pageType, filters);

  void updatePageSearch(PageType pageType, String query) =>
      _filterManager.updatePageSearch(pageType, query);

  void clearPageSearch(PageType pageType) => _filterManager.clearPageSearch(pageType);

  TextEditingController getOrCreateSearchController(PageType pageType, {String? seedText}) =>
      _filterManager.getOrCreateSearchController(pageType, seedText: seedText);

  void resetPageFilters(PageType pageType) => _filterManager.resetPageFilters(pageType);

  void resetAllFilters() => _filterManager.resetAllFilters();

  void setPurposeForAllPages(String purpose, {bool onlyIfUnset = false}) =>
      _filterManager.setPurposeForAllPages(purpose, onlyIfUnset: onlyIfUnset);

  void setPropertyTypeForAllPages(List<String>? propertyTypes, {bool onlyIfUnset = false}) =>
      _filterManager.setPropertyTypeForAllPages(propertyTypes, onlyIfUnset: onlyIfUnset);

  // ──────────────────────────────────────────────────────────────────
  // Delegates: Location (→ PageLocationManager)
  // ──────────────────────────────────────────────────────────────────

  Future<void> updateLocationForPage(
    PageType pageType,
    LocationData location, {
    String source = 'manual',
  }) => _locationManager.updateLocationForPage(pageType, location, source: source);

  Future<void> updateLocation(LocationData location, {String source = 'manual'}) =>
      _locationManager.updateLocation(location, source: source);

  Future<void> useCurrentLocation() => _locationManager.useCurrentLocation();

  Future<void> useCurrentLocationForPage(PageType pageType) =>
      _locationManager.useCurrentLocationForPage(pageType);

  // ──────────────────────────────────────────────────────────────────
  // Persistence
  // ──────────────────────────────────────────────────────────────────

  void _loadSavedStates() {
    try {
      final savedExploreState = _readStateMap(_exploreStateStorageKey);
      if (savedExploreState != null) {
        exploreState.value = _loadStateFromStorage(
          savedExploreState,
          PageType.explore,
          storageKey: _exploreStateStorageKey,
          persistNormalizedSnapshot: true,
        );
      }

      final savedDiscoverState = _readStateMap(_discoverStateStorageKey);
      if (savedDiscoverState != null) {
        discoverState.value = _loadStateFromStorage(
          savedDiscoverState,
          PageType.discover,
          storageKey: _discoverStateStorageKey,
          persistNormalizedSnapshot: true,
        );
      }

      final savedLikesState = _readStateMap(_likesStateStorageKey);
      if (savedLikesState != null) {
        likesState.value = _loadStateFromStorage(
          savedLikesState,
          PageType.likes,
          storageKey: _likesStateStorageKey,
          persistNormalizedSnapshot: true,
        );
      }

      DebugLogger.success('📂 Loaded saved page states');
    } catch (e) {
      DebugLogger.error('Error loading saved page states: $e');
    }
  }

  Map<String, dynamic>? _readStateMap(String storageKey) {
    final raw = _storage.read(storageKey);
    if (raw == null) return null;
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      return _normalizePersistedStateMap(map);
    }

    DebugLogger.warning(
      '⚠️ Unexpected type for $storageKey: ${raw.runtimeType}. Ignoring persisted value.',
    );
    return null;
  }

  void _migratePersistedStateSchemaIfNeeded() {
    try {
      final rawVersion = _storage.read(_pageStateSchemaVersionKey);
      final storedVersion = rawVersion is int
          ? rawVersion
          : int.tryParse(rawVersion?.toString() ?? '');

      if (storedVersion != null && storedVersion >= _currentPageStateSchemaVersion) {
        return;
      }

      DebugLogger.info(
        '🧭 Migrating persisted page state schema '
        'from ${storedVersion ?? 0} to $_currentPageStateSchemaVersion',
      );

      _migrateSinglePageState(_exploreStateStorageKey, PageType.explore);
      _migrateSinglePageState(_discoverStateStorageKey, PageType.discover);
      _migrateSinglePageState(_likesStateStorageKey, PageType.likes);

      _storage.write(_pageStateSchemaVersionKey, _currentPageStateSchemaVersion);
      DebugLogger.success('✅ Page state schema migration complete');
    } catch (e, st) {
      DebugLogger.warning('⚠️ Failed to migrate page state schema', e, st);
    }
  }

  void _migrateSinglePageState(String storageKey, PageType fallbackType) {
    final map = _readStateMap(storageKey);
    if (map == null) return;

    _loadStateFromStorage(
      map,
      fallbackType,
      storageKey: storageKey,
      persistNormalizedSnapshot: true,
    );
  }

  PageStateModel _loadStateFromStorage(
    Map<String, dynamic> json,
    PageType fallbackType, {
    String? storageKey,
    bool persistNormalizedSnapshot = false,
  }) {
    try {
      if (json.containsKey('pageType') &&
          json['pageType'] is String &&
          !json.containsKey('properties')) {
        final snapshot = PageStateSnapshot.fromJson(json);
        final model = PageStateModel.fromSnapshot(snapshot);
        if (persistNormalizedSnapshot && storageKey != null) {
          _storage.write(storageKey, _serializeSnapshotForStorage(model.toSnapshot()));
        }
        return model;
      }

      final fullModel = PageStateModel.fromJson(json);
      final normalized = normalizeLegacyStateForRuntime(fullModel);
      if (persistNormalizedSnapshot && storageKey != null) {
        _storage.write(storageKey, _serializeSnapshotForStorage(normalized.toSnapshot()));
        DebugLogger.info('🧹 Migrated legacy full state for ${fallbackType.name}');
      }
      return normalized;
    } catch (e) {
      DebugLogger.warning('Failed to parse saved state, using initial: $e');
      return PageStateModel.initial(fallbackType);
    }
  }

  static PageStateModel normalizeLegacyStateForRuntime(PageStateModel legacyState) {
    return legacyState.copyWith(
      properties: const [],
      nextCursor: null,
      hasMore: true,
      isLoading: false,
      isLoadingMore: false,
      isRefreshing: false,
      error: null,
    );
  }

  Map<String, dynamic> _normalizePersistedStateMap(Map<String, dynamic> map) {
    final normalized = Map<String, dynamic>.from(map);

    final selectedLocation = normalized['selectedLocation'];
    if (selectedLocation is LocationData) {
      normalized['selectedLocation'] = selectedLocation.toJson();
    } else if (selectedLocation is Map) {
      normalized['selectedLocation'] = Map<String, dynamic>.from(selectedLocation);
    }

    final filters = normalized['filters'];
    if (filters is UnifiedFilterModel) {
      normalized['filters'] = filters.toJson();
    } else if (filters is Map) {
      normalized['filters'] = Map<String, dynamic>.from(filters);
    }

    final additionalData = normalized['additionalData'];
    if (additionalData is Map) {
      normalized['additionalData'] = Map<String, dynamic>.from(additionalData);
    }

    return normalized;
  }

  Map<String, dynamic> _serializeSnapshotForStorage(PageStateSnapshot snapshot) {
    final json = Map<String, dynamic>.from(snapshot.toJson());
    final selectedLocation = json['selectedLocation'];
    if (selectedLocation is LocationData) {
      json['selectedLocation'] = selectedLocation.toJson();
    }
    final filters = json['filters'];
    if (filters is UnifiedFilterModel) {
      json['filters'] = filters.toJson();
    }
    return json;
  }

  void _debouncedPersist(PageType pageType, PageStateModel state) {
    switch (pageType) {
      case PageType.explore:
        _explorePersistDebouncer?.cancel();
        _explorePersistDebouncer = Timer(
          const Duration(milliseconds: _persistDebounceMs),
          () => _storage.write(
            _exploreStateStorageKey,
            _serializeSnapshotForStorage(state.toSnapshot()),
          ),
        );
        break;
      case PageType.discover:
        _discoverPersistDebouncer?.cancel();
        _discoverPersistDebouncer = Timer(
          const Duration(milliseconds: _persistDebounceMs),
          () => _storage.write(
            _discoverStateStorageKey,
            _serializeSnapshotForStorage(state.toSnapshot()),
          ),
        );
        break;
      case PageType.likes:
        _likesPersistDebouncer?.cancel();
        _likesPersistDebouncer = Timer(
          const Duration(milliseconds: _persistDebounceMs),
          () => _storage.write(
            _likesStateStorageKey,
            _serializeSnapshotForStorage(state.toSnapshot()),
          ),
        );
        break;
    }
  }

  // ──────────────────────────────────────────────────────────────────
  // Bootstrap & listeners
  // ──────────────────────────────────────────────────────────────────

  Future<void> _bootstrapInitialStates() async {
    DebugLogger.info('🚀 Bootstrapping initial page states...');

    if (exploreState.value.hasLocation &&
        discoverState.value.hasLocation &&
        likesState.value.hasLocation) {
      DebugLogger.success('✅ All page states already have a location. Bootstrap complete.');
      await _locationManager.normalizeSavedLocations();
      return;
    }

    // Reuse any location already in storage — only fetch GPS/IP when storage is empty
    final existingLocation =
        exploreState.value.selectedLocation ??
        discoverState.value.selectedLocation ??
        likesState.value.selectedLocation;

    try {
      final initialLocation = existingLocation ?? await _locationController.getInitialLocation();

      if (!exploreState.value.hasLocation) {
        await _locationManager.updateLocationForPage(
          PageType.explore,
          initialLocation,
          source: 'initial',
        );
      }
      if (!discoverState.value.hasLocation) {
        await _locationManager.updateLocationForPage(
          PageType.discover,
          initialLocation,
          source: 'initial',
        );
      }
      if (!likesState.value.hasLocation) {
        await _locationManager.updateLocationForPage(
          PageType.likes,
          initialLocation,
          source: 'initial',
        );
      }
      await _locationManager.normalizeSavedLocations();
      DebugLogger.success('✅ Successfully bootstrapped initial location for all pages.');
    } catch (e, st) {
      DebugLogger.error('❌ Failed to bootstrap initial location', e, st);
      AppToast.error('location_error'.tr, 'failed_to_get_location_message'.tr);
    }
  }

  void _setupListeners() {
    // Save lightweight snapshots with debouncing
    ever(exploreState, (state) => _debouncedPersist(PageType.explore, state));
    ever(discoverState, (state) => _debouncedPersist(PageType.discover, state));
    ever(likesState, (state) => _debouncedPersist(PageType.likes, state));

    // Keep Crashlytics context in sync with page state
    ever(currentPageType, (PageType page) => _updateCrashlyticsContext(page));

    // Listen to GPS position updates via location manager
    _locationManager.setupLocationListener();
  }

  void _updateCrashlyticsContext(PageType page) {
    try {
      final c = FirebaseCrashlytics.instance;
      c.setCustomKey('current_page_type', page.name);
      c.setCustomKey('has_location', _locationController.hasLocation);
      final ps = getCurrentPageState();
      c.setCustomKey('property_count', ps.properties.length);
      c.setCustomKey('active_filters_count', ps.filters.activeFilterCount);
    } catch (_) {}
  }

  // ──────────────────────────────────────────────────────────────────
  // Swipe recording & optimistic mutations
  // ──────────────────────────────────────────────────────────────────

  Future<void> recordSwipe({required int propertyId, required bool isLiked}) async {
    try {
      // Maintain likes list optimistically
      if (isLiked) {
        final prop = _findPropertyInAnyList(propertyId);
        if (prop != null) addPropertyToLikes(prop);
      } else {
        removePropertyFromLikes(propertyId);
      }

      // Also remove from discover deck optimistically
      removePropertyFromDiscover(propertyId);

      // Background network sync
      unawaited(_swipesRepository.recordSwipe(propertyId: propertyId, isLiked: isLiked));
    } catch (e) {
      DebugLogger.error('Failed to record swipe: $e');
    }
  }

  PropertyModel? _findPropertyInAnyList(int propertyId) {
    for (final p in exploreState.value.properties) {
      if (p.id == propertyId) return p;
    }
    for (final p in discoverState.value.properties) {
      if (p.id == propertyId) return p;
    }
    for (final p in likesState.value.properties) {
      if (p.id == propertyId) return p;
    }
    return null;
  }

  void removePropertyFromDiscover(int propertyId) {
    final state = discoverState.value;
    final updatedList = state.properties.where((p) => p.id != propertyId).toList();
    updatePageState(PageType.discover, state.copyWith(properties: updatedList));
  }

  /// Re-inserts a property at the front of the discover deck. Used by the
  /// undo-swipe flow to restore the previously-swiped property so the user
  /// sees it again as the top card.
  void reinsertPropertyToDiscover(PropertyModel property) {
    final state = discoverState.value;
    final exists = state.properties.any((p) => p.id == property.id);
    if (exists) return;
    final updatedList = [property, ...state.properties];
    updatePageState(PageType.discover, state.copyWith(properties: updatedList));
  }

  /// Reverses a previously-recorded swipe for the undo flow. Unlike
  /// [recordSwipe], this does NOT remove the property from the discover deck
  /// (it was just reinserted by [reinsertPropertyToDiscover]). It only
  /// reverses the likes list mutation from the original swipe and fires the
  /// background network sync with the opposite action.
  Future<void> undoSwipe({required int propertyId, required bool originalIsLiked}) async {
    try {
      // Reverse ONLY the likes list mutation that the original swipe made:
      // - Original LIKE added the property to likes → undo removes it.
      // - Original PASS did not touch likes (the property was in discover,
      //   not likes) → undo leaves likes unchanged. We do NOT add to likes
      //   because the user's intent is to re-swipe, not auto-like.
      if (originalIsLiked) {
        removePropertyFromLikes(propertyId);
      }

      // Background network sync with the REVERSED action. Without a delete-
      // swipe API, recording the opposite is the best reversal we can do.
      unawaited(_swipesRepository.recordSwipe(propertyId: propertyId, isLiked: !originalIsLiked));
    } catch (e) {
      DebugLogger.error('Failed to undo swipe: $e');
    }
  }

  void removePropertyFromLikes(int propertyId) {
    final state = likesState.value;
    final updatedList = state.properties.where((p) => p.id != propertyId).toList();
    updatePageState(PageType.likes, state.copyWith(properties: updatedList));
  }

  void addPropertyToLikes(PropertyModel property) {
    if (currentLikesSegment != 'liked') return;
    final state = likesState.value;
    final exists = state.properties.any((p) => p.id == property.id);
    if (!exists) {
      final updatedList = [property, ...state.properties];
      updatePageState(PageType.likes, state.copyWith(properties: updatedList));
    }
  }

  void addPropertyToPassed(PropertyModel property) {
    if (currentLikesSegment != 'passed') return;
    final state = likesState.value;
    final exists = state.properties.any((p) => p.id == property.id);
    if (!exists) {
      final updatedList = [property, ...state.properties];
      updatePageState(PageType.likes, state.copyWith(properties: updatedList));
    }
  }

  // ──────────────────────────────────────────────────────────────────
  // Likes segment management
  // ──────────────────────────────────────────────────────────────────

  /// In-memory per-segment cache so switching between Liked and Passed tabs
  /// reuses recently-fetched data instead of always hitting the API.
  /// Not persisted (avoids disk bloat); rebuilt on cold start.
  final Map<String, _LikesSegmentCache> _likesSegmentCache = {};

  /// Switches the likes segment (liked/passed). Reuses cached data when fresh;
  /// only fetches from the network when the segment's cache is empty or stale.
  void updateLikesSegment(String segment) {
    final previousSegment = currentLikesSegment;
    if (previousSegment == segment) return;

    // Snapshot the outgoing segment's data before switching
    final ps = likesState.value;
    _likesSegmentCache[previousSegment] = _LikesSegmentCache(
      properties: List.of(ps.properties),
      lastFetched: ps.lastFetched,
      hasMore: ps.hasMore,
      nextCursor: ps.nextCursor,
    );

    // Switch the segment marker
    likesState.value = likesState.value.updateAdditionalData('currentSegment', segment);

    // Restore cached data for the target segment if fresh
    final cached = _likesSegmentCache[segment];
    final fresh = cached != null && !cached.isStale;
    if (fresh) {
      likesState.value = likesState.value.copyWith(
        properties: List.of(cached.properties),
        lastFetched: cached.lastFetched,
        hasMore: cached.hasMore,
        nextCursor: cached.nextCursor,
        error: null,
        isLoading: false,
        isLoadingMore: false,
        isRefreshing: false,
      );
      return;
    }

    // No fresh cache — fetch
    likesState.value = likesState.value.resetData();
    loadPageData(PageType.likes, forceRefresh: true);
  }

  String get currentLikesSegment =>
      likesState.value.getAdditionalData<String>('currentSegment') ?? 'liked';

  // ──────────────────────────────────────────────────────────────────
  // Preferences sync
  // ──────────────────────────────────────────────────────────────────

  Future<void> syncPreferencesToBackend() async {
    try {
      if (!_authController.isAuthenticated) return;

      final filters = getCurrentPageState().filters;
      final normalizedPurpose = UnifiedFilterModel.normalizePurposeToken(filters.purpose);
      final normalizedPropertyTypes = (filters.propertyType ?? const <String>[])
          .map((type) => UnifiedFilterModel.normalizePropertyTypeToken(type))
          .whereType<String>()
          .toSet()
          .toList();
      final locationPreference = <String>{
        if (exploreState.value.selectedLocation?.name.trim().isNotEmpty == true)
          exploreState.value.selectedLocation!.name.trim(),
        if (discoverState.value.selectedLocation?.name.trim().isNotEmpty == true)
          discoverState.value.selectedLocation!.name.trim(),
        if (likesState.value.selectedLocation?.name.trim().isNotEmpty == true)
          likesState.value.selectedLocation!.name.trim(),
      }.toList();

      final preferences = <String, dynamic>{
        if (normalizedPropertyTypes.isNotEmpty) 'property_type': normalizedPropertyTypes,
        'purpose': ?normalizedPurpose,
        if (filters.priceMin != null) 'budget_min': filters.priceMin,
        if (filters.priceMax != null) 'budget_max': filters.priceMax,
        if (filters.bedroomsMin != null) 'bedrooms_min': filters.bedroomsMin,
        if (filters.bedroomsMax != null) 'bedrooms_max': filters.bedroomsMax,
        if (filters.areaMin != null) 'area_min': filters.areaMin,
        if (filters.areaMax != null) 'area_max': filters.areaMax,
        if (locationPreference.isNotEmpty) 'location_preference': locationPreference,
        if (filters.radiusKm != null && filters.radiusKm! > 0)
          'max_distance_km': filters.radiusKm!.round(),
      };

      if (preferences.isEmpty) return;

      await _authController.updateUserPreferences(preferences);
      DebugLogger.success('✅ Synced preferences to backend');
    } catch (e) {
      DebugLogger.error('Failed to sync preferences: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────────
  // UI helpers
  // ──────────────────────────────────────────────────────────────────

  bool isSearchVisible(PageType pageType) {
    final state = getStateForPage(pageType);
    return state.getAdditionalData<bool>('searchVisible') ?? false;
  }

  void setSearchVisible(PageType pageType, bool visible) {
    final state = getStateForPage(pageType);
    final updated = state.updateAdditionalData('searchVisible', visible);
    updatePageState(pageType, updated);
  }

  void toggleSearch(PageType pageType) {
    setSearchVisible(pageType, !isSearchVisible(pageType));
  }

  void notifyPageRefreshing(PageType pageType, bool isRefreshing) {
    switch (pageType) {
      case PageType.explore:
        _exploreRefreshing.value = isRefreshing;
        break;
      case PageType.discover:
        _discoverRefreshing.value = isRefreshing;
        break;
      case PageType.likes:
        _likesRefreshing.value = isRefreshing;
        break;
    }
  }

  bool isPageRefreshing(PageType pageType) {
    switch (pageType) {
      case PageType.explore:
        return _exploreRefreshing.value;
      case PageType.discover:
        return _discoverRefreshing.value;
      case PageType.likes:
        return _likesRefreshing.value;
    }
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
