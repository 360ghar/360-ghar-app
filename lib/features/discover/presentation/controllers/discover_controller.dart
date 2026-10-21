import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/firebase/analytics_service.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/features/properties/application/property_filters.dart';
import 'package:ghar360/features/properties/application/property_location.dart';
import 'package:ghar360/features/properties/application/property_queries.dart';
import 'package:ghar360/features/properties/application/swipe_history.dart';

class DiscoverSession {
  const DiscoverSession({this.likes = 0, this.passes = 0});
  final int likes;
  final int passes;
  int get total => likes + passes;
}

final discoverProvider = NotifierProvider<DiscoverController, DiscoverSession>(
  DiscoverController.new,
);

class DiscoverController extends Notifier<DiscoverSession> {
  @override
  DiscoverSession build() {
    ref.watch(storageScopeProvider);
    return const DiscoverSession();
  }

  List<PropertyModel> get deck => ref.read(visiblePropertiesProvider(PropertyFeed.discover));
  Future<void> swipeRight(PropertyModel property) => _swipe(property, true);
  Future<void> swipeLeft(PropertyModel property) => _swipe(property, false);
  Future<void> _swipe(PropertyModel property, bool liked) async {
    if (!deck.any((item) => item.id == property.id)) return;
    final scope = ref.read(storageScopeProvider);
    final pending = ref.read(swipeHistoryProvider.notifier).record(property, liked);
    state = DiscoverSession(
      likes: state.likes + (liked ? 1 : 0),
      passes: state.passes + (liked ? 0 : 1),
    );
    if (deck.length <= 3) {
      unawaited(ref.read(propertyQueryProvider(PropertyFeed.discover).notifier).loadMore());
    }
    final saved = await pending;
    if (!ref.mounted || !identical(scope, ref.read(storageScopeProvider))) return;
    if (!saved) {
      state = DiscoverSession(
        likes: (state.likes - (liked ? 1 : 0)).clamp(0, 1 << 31),
        passes: (state.passes - (liked ? 0 : 1)).clamp(0, 1 << 31),
      );
      return;
    }
    try {
      if (liked) {
        await AnalyticsService.likeProperty(property.id.toString());
      } else {
        await AnalyticsService.logVital('property_pass', params: {'id': property.id.toString()});
      }
    } catch (error, stack) {
      DebugLogger.warning('Swipe analytics unavailable', error.runtimeType, stack);
    }
  }

  Future<void> refreshDeck() async {
    state = const DiscoverSession();
    await ref.read(propertyQueryProvider(PropertyFeed.discover).notifier).load(refresh: true);
  }

  Future<void> retryLoading() =>
      ref.read(propertyQueryProvider(PropertyFeed.discover).notifier).load(refresh: true);
  Future<void> showNearbyProperties() =>
      ref.read(propertyLocationProvider(PageType.discover).notifier).useCurrent();
  Future<bool> filterByPropertyType(String type) => ref
      .read(propertyFiltersProvider.notifier)
      .update(
        PageType.discover,
        ref.read(propertyFiltersProvider).forPage(PageType.discover).copyWith(propertyType: [type]),
      );
  Future<bool> filterByPurpose(String purpose) => ref
      .read(propertyFiltersProvider.notifier)
      .update(
        PageType.discover,
        ref.read(propertyFiltersProvider).forPage(PageType.discover).copyWith(purpose: purpose),
      );
}
