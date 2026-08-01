import 'dart:async';

import 'package:get/get.dart';

import 'package:ghar360/core/controllers/page_state_service.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/utils/app_toast.dart';
import 'package:ghar360/core/utils/debug_logger.dart';

enum LikesSegment { liked, passed }

enum LikesState { initial, loading, loaded, empty, error, loadingMore }

class LikesController extends GetxController {
  final PageStateService _pageStateService = Get.find<PageStateService>();

  // Current segment (Liked or Passed)
  final Rx<LikesSegment> currentSegment = LikesSegment.liked.obs;

  // No longer need swipe ID mapping since properties have liked attribute

  // State management for liked properties
  final Rx<LikesState> likedState = LikesState.initial.obs;
  final RxList<PropertyModel> likedProperties = <PropertyModel>[].obs;

  // State management for passed properties
  final Rx<LikesState> passedState = LikesState.initial.obs;
  final RxList<PropertyModel> passedProperties = <PropertyModel>[].obs;

  // Search functionality
  final RxString searchQuery = ''.obs;
  final RxList<PropertyModel> filteredLikedProperties = <PropertyModel>[].obs;
  final RxList<PropertyModel> filteredPassedProperties = <PropertyModel>[].obs;
  Timer? _searchDebouncer;

  // Error handling
  final Rxn<AppException> error = Rxn<AppException>();

  // Pagination totals tracked via server pages; counts not required per spec

  // Page activation listener
  Worker? _pageActivationWorker;
  Worker? _searchQueryWorker;

  @override
  void onInit() {
    super.onInit();
    // Don't set current page here - let navigation handle it
    _setupSearchListener();
    // LAZY LOADING: Remove initial data loading from onInit
  }

  @override
  void onReady() {
    super.onReady();

    // Set up listener for page activation
    _pageActivationWorker = ever(_pageStateService.currentPageType, (pageType) {
      if (pageType == PageType.likes) {
        activatePage();
      }
    });

    // Initial activation if already on this page (with delay to ensure full initialization)
    if (_pageStateService.currentPageType.value == PageType.likes) {
      Future.delayed(const Duration(milliseconds: 100), () {
        activatePage();
      });
    }
  }

  void activatePage() {
    try {
      DebugLogger.debug('💖 [LIKES_CONTROLLER] activatePage() called');
      final ps = _pageStateService.likesState.value;
      DebugLogger.debug(
        '💖 [LIKES_CONTROLLER] Page state: hasLocation=${ps.hasLocation}, isLoading=${ps.isLoading}, propertiesCount=${ps.properties.length}',
      );

      final segStr = _pageStateService.currentLikesSegment;
      DebugLogger.debug('💖 [LIKES_CONTROLLER] Current segment string: $segStr');

      currentSegment.value = segStr == 'liked' ? LikesSegment.liked : LikesSegment.passed;
      DebugLogger.debug('💖 [LIKES_CONTROLLER] Segment updated to: ${currentSegment.value}');

      if (!ps.hasLocation) {
        DebugLogger.debug('💖 [LIKES_CONTROLLER] No location available, requesting location');
        _pageStateService.useCurrentLocationForPage(PageType.likes).whenComplete(() {
          DebugLogger.debug('💖 [LIKES_CONTROLLER] Location obtained, loading data');
          _pageStateService.loadPageData(PageType.likes, forceRefresh: true);
        });
        return;
      }

      if (ps.isLoading || ps.isRefreshing) {
        DebugLogger.debug('💖 [LIKES_CONTROLLER] Already loading, skipping');
        return;
      }

      // Prefer optimistic + cached data. Only network-refresh when empty or
      // stale — a refresh-on-every-visit races the swipe POST and used to
      // flash-remove just-liked properties before the history API had them.
      if (ps.properties.isEmpty) {
        DebugLogger.debug('💖 [LIKES_CONTROLLER] No properties, loading data');
        _pageStateService.loadPageData(PageType.likes, forceRefresh: true);
      } else if (ps.isDataStale) {
        DebugLogger.debug('💖 [LIKES_CONTROLLER] Data is stale, refreshing in background');
        _pageStateService.loadPageData(PageType.likes, backgroundRefresh: true);
      } else {
        DebugLogger.debug(
          '💖 [LIKES_CONTROLLER] Data is current (${ps.properties.length} items), no refresh',
        );
      }
    } catch (e, stackTrace) {
      DebugLogger.error('❌ [LIKES_CONTROLLER] Error in activatePage: $e');
      DebugLogger.error('❌ [LIKES_CONTROLLER] Stack trace: $stackTrace');
      if (e.toString().contains('Null check operator used on a null value')) {
        DebugLogger.error('🚨 [LIKES_CONTROLLER] NULL CHECK OPERATOR ERROR in activatePage!');
      }
    }
  }

  @override
  void onClose() {
    _searchDebouncer?.cancel();
    _pageActivationWorker?.dispose();
    _searchQueryWorker?.dispose();
    super.onClose();
  }

  void _setupSearchListener() {
    // Apply search filter whenever search query changes
    _searchQueryWorker = debounce(searchQuery, (_) {
      // Propagate to global filter so API gets 'q'
      _pageStateService.updatePageSearch(PageType.likes, searchQuery.value);
    }, time: const Duration(milliseconds: 300));
  }

  // Segment switching
  void switchToSegment(LikesSegment segment) {
    if (currentSegment.value == segment) return;
    currentSegment.value = segment;
    DebugLogger.api('📱 Switched to ${segment.name} segment');
    _pageStateService.updateLikesSegment(segment == LikesSegment.liked ? 'liked' : 'passed');
  }

  // Search functionality
  void updateSearchQuery(String query) {
    searchQuery.value = query;
    DebugLogger.api('🔍 Search query updated: "$query"');
  }

  // ── Favourite state ──
  //
  // Authoritative value is [PropertyModel.liked] (set per swipe by the swipe
  // history endpoint), with an optimistic override on top for swipes made this
  // session. Same contract as ExploreController.isPropertyLiked/toggleLike.
  // It must NOT be derived from the loaded likes list: that list is whichever
  // SEGMENT is showing, so every passed property read as favourited.
  final RxMap<int, bool> likedOverrides = <int, bool>{}.obs;
  final RxSet<int> _pendingFavouriteUpdates = <int>{}.obs;

  bool isFavourite(PropertyModel property) => likedOverrides[property.id] ?? property.liked;

  bool isFavouriteUpdating(PropertyModel property) =>
      _pendingFavouriteUpdates.contains(property.id);

  Future<void> addToFavourites(PropertyModel property) => _setFavourite(property, true);

  Future<void> removeFromFavourites(PropertyModel property) => _setFavourite(property, false);

  Future<void> _setFavourite(PropertyModel property, bool liked) async {
    if (_pendingFavouriteUpdates.contains(property.id)) return;

    final previous = isFavourite(property);
    _pendingFavouriteUpdates.add(property.id);
    // Optimistic — recordSwipe already updates the likes list and segment
    // caches, so no page refetch is needed (and refetching here raced the
    // swipe POST; see activatePage).
    likedOverrides[property.id] = liked;
    try {
      DebugLogger.info('${liked ? '💖 Adding' : '💔 Removing'} property ${property.id}');
      await _pageStateService.recordSwipe(
        propertyId: property.id,
        isLiked: liked,
        property: property,
      );
      DebugLogger.success('✅ Property ${property.id} favourite -> $liked');
    } catch (e) {
      DebugLogger.error('❌ Failed to update favourite for ${property.id}: $e');
      likedOverrides[property.id] = previous;
      await _reverseFailedSwipe(property.id, liked);
      AppToast.error('action_failed'.tr, 'like_update_failed'.tr);
    } finally {
      _pendingFavouriteUpdates.remove(property.id);
    }
  }

  /// [recordSwipe] applies its likes/passed mutation BEFORE the network call,
  /// so a failed swipe leaves the property sitting in the wrong segment while
  /// the heart says the opposite. Reverses exactly that mutation.
  ///
  /// [attemptedIsLiked] is the swipe being reversed — [undoSwipe]'s
  /// `originalIsLiked` names the action it is undoing, not the prior state
  /// (see DiscoverController._revertUnsavedSwipe, same path). `notifyServer`
  /// is false because the swipe never reached the server.
  ///
  /// The discover-deck removal is deliberately NOT reversed: reinserting would
  /// jump the card to the top of Discover, which the undo flow wants and a
  /// failed heart tap does not.
  Future<void> _reverseFailedSwipe(int propertyId, bool attemptedIsLiked) {
    // Awaited by callers, but with catchError attached so a second failure is
    // logged instead of replacing the error the user is about to be shown.
    return _pageStateService
        .undoSwipe(propertyId: propertyId, originalIsLiked: attemptedIsLiked, notifyServer: false)
        .catchError((Object e) => DebugLogger.error('❌ Failed to reverse optimistic swipe: $e'));
  }

  void clearSearch() {
    searchQuery.value = '';
    _pageStateService.updatePageSearch(PageType.likes, '');
  }

  // Infinite scroll - load more
  Future<void> loadMoreCurrentSegment() async {
    await _pageStateService.loadMorePageData(PageType.likes);
  }

  Future<void> loadMoreLiked() async {
    await _pageStateService.loadMorePageData(PageType.likes);
  }

  Future<void> loadMorePassed() async {
    await _pageStateService.loadMorePageData(PageType.likes);
  }

  // Refresh
  Future<void> refreshCurrentSegment() async {
    if (currentSegment.value == LikesSegment.liked) {
      await refreshLiked();
    } else {
      await refreshPassed();
    }
  }

  Future<void> refreshLiked() async {
    await _pageStateService.loadPageData(PageType.likes, forceRefresh: true);
  }

  Future<void> refreshPassed() async {
    await _pageStateService.loadPageData(PageType.likes, forceRefresh: true);
  }

  Future<void> refreshAll() async {
    await _pageStateService.loadPageData(PageType.likes, forceRefresh: true);
  }

  // Navigation
  void viewPropertyDetails(PropertyModel property) {
    Get.toNamed(AppRoutes.propertyDetails, arguments: property);
  }

  // Remove property from likes by recording a "dislike" swipe
  Future<void> removeFromLikes(PropertyModel property) async {
    try {
      DebugLogger.api('🗑️ Removing property from likes: ${property.title}');
      // Keep the heart in sync: the same (now stale) model is handed to
      // property details, where `liked` would still read true.
      likedOverrides[property.id] = false;
      // Pass the model so optimistic passed-cache updates still work after the
      // card leaves the visible liked list.
      await _pageStateService.recordSwipe(
        propertyId: property.id,
        isLiked: false,
        property: property,
      );

      DebugLogger.success('✅ Property successfully removed from likes');

      AppToast.success(
        'removed_title'.tr,
        'removed_from_liked'.trParams({'property': property.title}),
      );
    } catch (e) {
      DebugLogger.error('❌ Failed to remove from likes: $e');

      // Revert optimistic update (heart + the list mutation recordSwipe
      // already applied locally; the refresh below cannot clear it because
      // the optimistic pass is merged back over server results).
      likedOverrides[property.id] = true;
      await _reverseFailedSwipe(property.id, false);
      AppToast.error('error'.tr, 'remove_failed'.tr);

      // Refresh to restore correct state
      await _pageStateService.loadPageData(PageType.likes, forceRefresh: true);
    }
  }

  // Move property from passed to liked by recording a "like" swipe
  Future<void> moveToLikes(PropertyModel property) async {
    try {
      DebugLogger.api('➕ Moving property to likes: ${property.title}');
      likedOverrides[property.id] = true;
      // Pass the model so optimistic liked-cache updates work after leaving
      // the visible passed list.
      await _pageStateService.recordSwipe(
        propertyId: property.id,
        isLiked: true,
        property: property,
      );

      DebugLogger.success('✅ Property successfully moved to likes');

      AppToast.success('added_title'.tr, 'moved_to_liked'.trParams({'property': property.title}));
    } catch (e) {
      DebugLogger.error('❌ Failed to move to likes: $e');

      likedOverrides[property.id] = false;
      await _reverseFailedSwipe(property.id, true);
      AppToast.error('error'.tr, 'move_failed'.tr);

      // Refresh to restore correct state
      await _pageStateService.loadPageData(PageType.likes, forceRefresh: true);
    }
  }

  // Error handling
  void retryCurrentSegment() {
    if (currentSegment.value == LikesSegment.liked) {
      retryLiked();
    } else {
      retryPassed();
    }
  }

  void retryLiked() => _pageStateService.loadPageData(PageType.likes, forceRefresh: true);

  void retryPassed() => _pageStateService.loadPageData(PageType.likes, forceRefresh: true);

  // Getters for current segment
  List<PropertyModel> get currentProperties {
    return _pageStateService.likesState.value.properties;
  }

  LikesState get currentState {
    final ps = _pageStateService.likesState.value;
    if (ps.isLoading) return LikesState.loading;
    if (ps.isLoadingMore) return LikesState.loadingMore;
    if (ps.error != null) return LikesState.error;
    if (ps.properties.isEmpty) return LikesState.empty;
    return LikesState.loaded;
  }

  String? get currentError {
    return _pageStateService.likesState.value.error?.toString();
  }

  bool get currentHasMore {
    return _pageStateService.likesState.value.hasMore;
  }

  // Statistics
  String get currentSegmentTitle {
    return currentSegment.value == LikesSegment.liked
        ? 'liked_properties'.tr
        : 'passed_properties'.tr;
  }

  String get currentCountText {
    final count = currentProperties.length;
    return searchQuery.value.isNotEmpty
        ? '$count ${'results'.tr}'
        : (count == 1 ? '$count ${'property'.tr}' : '$count ${'properties'.tr}');
  }

  String get emptyStateMessage {
    if (searchQuery.value.isNotEmpty) {
      return 'no_properties_match_your_search'.tr;
    }

    return currentSegment.value == LikesSegment.liked
        ? '${'no_liked_properties'.tr}\n${'no_favorites_message'.tr}'
        : '${'no_passed_properties'.tr}\n${'no_more_properties_message'.tr}';
  }

  // Helper getters
  bool get isCurrentLoading => _pageStateService.likesState.value.isLoading;
  bool get isCurrentEmpty =>
      !_pageStateService.likesState.value.isLoading &&
      currentProperties.isEmpty &&
      _pageStateService.likesState.value.error == null;
  bool get hasCurrentError => _pageStateService.likesState.value.error != null;
  bool get isCurrentLoaded => !isCurrentLoading && !isCurrentEmpty && !hasCurrentError;
  bool get isCurrentLoadingMore => _pageStateService.likesState.value.isLoadingMore;
  bool get hasCurrentProperties => currentProperties.isNotEmpty;
  bool get hasSearchQuery => searchQuery.value.isNotEmpty;
}
