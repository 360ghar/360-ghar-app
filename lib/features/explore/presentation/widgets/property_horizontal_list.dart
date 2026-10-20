import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/app_spacing.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/core/widgets/common/property_list_card.dart';
import 'package:ghar360/features/explore/presentation/controllers/explore_controller.dart';
import 'package:ghar360/features/properties/application/property_queries.dart';
import 'package:ghar360/features/properties/application/swipe_history.dart';

/// The horizontal strip of homes under the Explore map. Scrolling highlights
/// the home on the map; a marker tap scrolls its card to the middle.
class PropertyHorizontalList extends ConsumerStatefulWidget {
  const PropertyHorizontalList({super.key, this.onOpen, this.openId});

  /// Opens a home in the detail pane. Null pushes the details route.
  final ValueChanged<PropertyModel>? onOpen;

  /// The home shown in the detail pane.
  final int? openId;

  static double height(BuildContext context) =>
      220 + (MediaQuery.textScalerOf(context).scale(14) - 14).clamp(0, 28) * 6;

  @override
  ConsumerState<PropertyHorizontalList> createState() => _PropertyHorizontalListState();
}

class _PropertyHorizontalListState extends ConsumerState<PropertyHorizontalList> {
  final ScrollController _scrollController = ScrollController();
  ExploreController get controller => ref.read(exploreProvider.notifier);
  int? _lastSelectedId;
  Timer? _scrollDebounce;

  static const double _itemWidth = 260.0;
  static const double _spacing = 12.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollDebounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToProperty(int propertyId) {
    try {
      final index = controller.properties.indexWhere((e) => e.id == propertyId);
      if (index == -1) return;
      final viewportDimension = _scrollController.position.viewportDimension;
      // Center the selected card in the viewport.
      final target = index * (_itemWidth + _spacing) - (viewportDimension / 2) + (_itemWidth / 2);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scrollController.animateTo(
          target.clamp(0, _scrollController.position.maxScrollExtent),
          duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : AppDurations.normal,
          curve: AppCurves.standard,
        );
      });
    } catch (e, stack) {
      DebugLogger.warning('Could not scroll to property', e, stack);
    }
  }

  void _onScroll() {
    _maybeLoadMore();
    // Debounce to avoid spamming highlight updates.
    _scrollDebounce?.cancel();
    _scrollDebounce = Timer(const Duration(milliseconds: 80), () {
      try {
        final properties = controller.properties;
        if (properties.isEmpty) return;
        final rawIndex = _scrollController.offset / (_itemWidth + _spacing);
        final property = properties[rawIndex.round().clamp(0, properties.length - 1)];
        if (property.id != _lastSelectedId) {
          _lastSelectedId = property.id;
          controller.highlightPropertyFromCard(property);
        }
      } catch (e, st) {
        DebugLogger.debug('Highlight sync from scroll failed', e, st);
      }
    });
  }

  void _maybeLoadMore() {
    try {
      if (!controller.hasMore || controller.isLoadingMore) return;
      if (_scrollController.position.extentAfter < 300) {
        unawaited(controller.loadMoreProperties());
      }
    } catch (_) {
      // ScrollController may not have position yet.
    }
  }

  @override
  Widget build(BuildContext context) {
    final properties = ref.watch(
      propertyQueryProvider(PropertyFeed.explore).select((state) => state.items),
    );
    ref.listen(exploreProvider.select((state) => state.selectedId), (_, id) {
      if (id == null || id == _lastSelectedId) return;
      _lastSelectedId = id;
      HapticFeedback.selectionClick();
      _scrollToProperty(id);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) _maybeLoadMore();
    });
    if (properties.isEmpty) {
      return SizedBox(
        height: 48,
        child: Center(
          child: Text(
            context.l10n.text('no_properties_found'),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: context.design.textSecondary),
          ),
        ),
      );
    }
    return SizedBox(
      height: PropertyHorizontalList.height(context),
      child: ListView.separated(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        itemBuilder: (context, index) => SizedBox(
          width: _itemWidth,
          child: _ExploreCard(
            property: properties[index],
            open: widget.openId == properties[index].id,
            onOpen: widget.onOpen,
          ),
        ),
        separatorBuilder: (context, index) => const SizedBox(width: _spacing),
        itemCount: properties.length,
      ),
    );
  }
}

/// One card. It watches only its own selection and like state, so a
/// highlight or a like rebuilds this card and not the strip.
class _ExploreCard extends ConsumerWidget {
  const _ExploreCard({required this.property, required this.open, this.onOpen});

  final PropertyModel property;
  final bool open;
  final ValueChanged<PropertyModel>? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final highlighted = ref.watch(exploreProvider.select((s) => s.selectedId == property.id));
    final liked = ref.watch(
      swipeHistoryProvider.select((h) => h.entries[property.id]?.isLiked ?? property.liked),
    );
    final controller = ref.read(exploreProvider.notifier);
    return PropertyListCard(
      property: property,
      isFavourite: liked,
      selected: open || highlighted,
      onFavouriteToggle: () => controller.toggleLike(property),
      onTap: onOpen == null
          ? null
          : () {
              controller.highlightPropertyFromCard(property);
              onOpen!(property);
            },
    );
  }
}
