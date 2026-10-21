import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/data/models/likes_segment.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/features/properties/application/property_filters.dart';
import 'package:ghar360/features/properties/application/property_queries.dart';
import 'package:ghar360/features/properties/application/swipe_history.dart';

final likesProvider = NotifierProvider<LikesController, LikesSegment>(LikesController.new);

/// The selected history segment is the only state owned here. Lists and Like /
/// Pass mutations use the same providers as Discover, Explore and details.
class LikesController extends Notifier<LikesSegment> {
  @override
  LikesSegment build() {
    ref.watch(storageScopeProvider);
    final legacy = ref.read(appDatabaseProvider).readPreference<Map>('likes_state');
    final extra = legacy?['additionalData'];
    return LikesSegment.tryParse(
      extra is Map ? extra[LikesSegment.additionalDataKey] as String? : null,
    );
  }

  PropertyFeed get feed => state == LikesSegment.liked ? PropertyFeed.liked : PropertyFeed.passed;
  void switchToSegment(LikesSegment segment) {
    state = segment;
  }

  bool isFavourite(PropertyModel property) =>
      ref.read(swipeHistoryProvider).entries[property.id]?.isLiked ?? property.liked;
  bool isFavouriteUpdating(PropertyModel property) =>
      ref.read(swipeHistoryProvider).entries[property.id]?.phase == SwipePhase.submitting;
  Future<bool> _setFavourite(PropertyModel property, bool liked) {
    if (isFavouriteUpdating(property)) return Future.value(false);
    return ref.read(swipeHistoryProvider.notifier).record(property, liked);
  }

  Future<bool> addToFavourites(PropertyModel property) => _setFavourite(property, true);
  Future<bool> removeFromFavourites(PropertyModel property) => _setFavourite(property, false);
  Future<bool> moveToLikes(PropertyModel property) => addToFavourites(property);
  Future<bool> removeFromLikes(PropertyModel property) => removeFromFavourites(property);
  Future<bool> clearSearch() =>
      ref.read(propertyFiltersProvider.notifier).search(PageType.likes, '');
  Future<bool> updateSearchQuery(String text) =>
      ref.read(propertyFiltersProvider.notifier).search(PageType.likes, text);
  Future<void> loadMoreCurrentSegment() =>
      ref.read(propertyQueryProvider(feed).notifier).loadMore();
  Future<void> refreshCurrentSegment() =>
      ref.read(propertyQueryProvider(feed).notifier).load(refresh: true);
  Future<void> retryCurrentSegment() => refreshCurrentSegment();
}
