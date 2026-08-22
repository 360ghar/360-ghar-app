import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/controllers/likes_swipe_coordinator.dart';
import 'package:ghar360/core/controllers/location_controller.dart';
import 'package:ghar360/core/controllers/page_data_loader.dart';
import 'package:ghar360/core/controllers/page_filter_manager.dart';
import 'package:ghar360/core/controllers/page_location_manager.dart';
import 'package:ghar360/core/data/models/likes_segment.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/data/ports/properties_port.dart';
import 'package:ghar360/core/data/ports/swipes_port.dart';
import 'package:ghar360/core/utils/app_toast.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/features/profile/data/profile_repository.dart';

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
  late final SwipesPort _swipesPort;
  late final ProfileRepository _profileRepository;

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
  late final LikesSwipeCoordinator _likesSwipe;

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
    _swipesPort = await _findDependencyWithRetry<SwipesPort>('SwipesPort', maxRetries: 3);
    _profileRepository = await _findDependencyWithRetry<ProfileRepository>(
      'ProfileRepository',
      maxRetries: 3,
    );
    final propertiesPort = await _findDependencyWithRetry<PropertiesPort>(
      'PropertiesPort',
      maxRetries: 3,
    );

    // Initialize sub-services
    _dataLoader = PageDataLoader(this, propertiesPort, _swipesPort, _locationController);
    _filterManager = PageFilterManager(this, _dataLoader, _storage);
    _locationManager = PageLocationManager(this, _dataLoader, _locationController, _authController);
    _likesSwipe = LikesSwipeCoordinator(this, _swipesPort);

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

  /// Resets in-memory and persisted page state after logout so the next user
  /// never sees the previous user's properties, likes, or swipe progress.
  void clearSessionData() {
    _explorePersistDebouncer?.cancel();
    _discoverPersistDebouncer?.cancel();
    _likesPersistDebouncer?.cancel();

    exploreState.value = PageStateModel.initial(PageType.explore);
    discoverState.value = PageStateModel.initial(PageType.discover);
    likesState.value = PageStateModel.initial(PageType.likes);
    _likesSwipe.resetForSession();

    // Invalidate in-flight fetches/load-mores so their completions (which
    // would otherwise carry the previous user's data into the freshly cleared
    // states) are discarded by the loaders' generation checks, and no queued
    // force-reload from a pre-logout load fires under the next session.
    _dataLoader.invalidateAllLoads();

    try {
      _storage.remove(_exploreStateStorageKey);
      _storage.remove(_discoverStateStorageKey);
      _storage.remove(_likesStateStorageKey);
    } catch (e, st) {
      DebugLogger.warning('Failed to clear persisted page state on logout', e, st);
    }

    DebugLogger.info('🧹 PageStateService session data cleared');
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
    LocationSource source = LocationSource.manual,
  }) => _locationManager.updateLocationForPage(pageType, location, source: source);

  Future<void> updateLocation(
    LocationData location, {
    LocationSource source = LocationSource.manual,
  }) => _locationManager.updateLocation(location, source: source);

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

      // Independent page updates run concurrently; normalizeSavedLocations
      // waits for all of them before declaring bootstrap complete.
      await Future.wait([
        if (!exploreState.value.hasLocation)
          _locationManager.updateLocationForPage(
            PageType.explore,
            initialLocation,
            source: LocationSource.initial,
          ),
        if (!discoverState.value.hasLocation)
          _locationManager.updateLocationForPage(
            PageType.discover,
            initialLocation,
            source: LocationSource.initial,
          ),
        if (!likesState.value.hasLocation)
          _locationManager.updateLocationForPage(
            PageType.likes,
            initialLocation,
            source: LocationSource.initial,
          ),
      ]);
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
    } catch (e, st) {
      DebugLogger.debug('🟡 Crashlytics page context update failed (ignored): $e', e, st);
    }
  }

  // ──────────────────────────────────────────────────────────────────
  // Likes & swipe domain (→ LikesSwipeCoordinator)
  // ──────────────────────────────────────────────────────────────────

  Future<void> recordSwipe({
    required int propertyId,
    required bool isLiked,
    PropertyModel? property,
  }) => _likesSwipe.recordSwipe(propertyId: propertyId, isLiked: isLiked, property: property);

  Future<void> undoSwipe({
    required int propertyId,
    required bool originalIsLiked,
    bool notifyServer = true,
  }) =>
      _likesSwipe.undoSwipe(
        propertyId: propertyId,
        originalIsLiked: originalIsLiked,
        notifyServer: notifyServer,
      );

  void updateLikesSegment(String segment) => _likesSwipe.updateLikesSegment(segment);
  LikesSegment get currentLikesSegment => _likesSwipe.currentLikesSegment;

  void addPropertyToLikes(PropertyModel property) => _likesSwipe.addPropertyToLikes(property);
  void addPropertyToPassed(PropertyModel property) => _likesSwipe.addPropertyToPassed(property);
  void removePropertyFromLikes(int propertyId) => _likesSwipe.removePropertyFromLikes(propertyId);

  void removePropertyFromDiscover(int propertyId) =>
      _likesSwipe.removePropertyFromDiscover(propertyId);
  void reinsertPropertyToDiscover(PropertyModel property) =>
      _likesSwipe.reinsertPropertyToDiscover(property);

  List<PropertyModel> mergeDiscoverRefreshResults({
    required List<PropertyModel> serverItems,
    required List<PropertyModel> localItems,
    required int epochAtRequestStart,
  }) =>
      _likesSwipe.mergeDiscoverRefreshResults(
        serverItems: serverItems,
        localItems: localItems,
        epochAtRequestStart: epochAtRequestStart,
      );

  List<PropertyModel> filterOutSessionSwiped(List<PropertyModel> items) =>
      _likesSwipe.filterOutSessionSwiped(items);

  bool isSessionSwiped(int propertyId) => _likesSwipe.isSessionSwiped(propertyId);
  int get discoverMutationEpoch => _likesSwipe.discoverMutationEpoch;

  List<PropertyModel> mergeLikesServerResults(
    List<PropertyModel> serverItems, {
    required bool isLikedSegment,
  }) =>
      _likesSwipe.mergeLikesServerResults(serverItems, isLikedSegment: isLikedSegment);

  void applyLikesSegmentFetchResult({
    required bool isLikedSegment,
    required List<PropertyModel> serverItems,
    required bool hasMore,
    String? nextCursor,
  }) =>
      _likesSwipe.applyLikesSegmentFetchResult(
        isLikedSegment: isLikedSegment,
        serverItems: serverItems,
        hasMore: hasMore,
        nextCursor: nextCursor,
      );

  void syncLikesSegmentCacheFromVisible({required bool hasMore, String? nextCursor}) =>
      _likesSwipe.syncLikesSegmentCacheFromVisible(hasMore: hasMore, nextCursor: nextCursor);

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

      await _profileRepository.updateUserPreferences(preferences);
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

