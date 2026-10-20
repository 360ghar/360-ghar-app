import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghar360/core/data/models/likes_segment.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/design/paper/paper_chrome.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/utils/app_toast.dart';
import 'package:ghar360/core/widgets/common/error_states.dart';
import 'package:ghar360/core/widgets/common/inline_retry_banner.dart';
import 'package:ghar360/core/widgets/common/loading_states.dart';
import 'package:ghar360/core/widgets/common/location_selector.dart';
import 'package:ghar360/core/widgets/common/property_filter_widget.dart';
import 'package:ghar360/core/widgets/common/property_list_card.dart';
import 'package:ghar360/core/widgets/common/property_location_recovery.dart';
import 'package:ghar360/core/widgets/common/property_recovery_banner.dart';
import 'package:ghar360/core/widgets/paper/folder_tabs.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';
import 'package:ghar360/core/widgets/paper/paper_scroll_page.dart';
import 'package:ghar360/core/widgets/paper/scene_header_sliver.dart';
import 'package:ghar360/features/explore/presentation/widgets/property_detail_pane.dart';
import 'package:ghar360/features/likes/presentation/controllers/likes_controller.dart';
import 'package:ghar360/features/likes/presentation/widgets/saved_actions_button.dart';
import 'package:ghar360/features/properties/application/property_filters.dart';
import 'package:ghar360/features/properties/application/property_location.dart';
import 'package:ghar360/features/properties/application/property_queries.dart';
import 'package:ghar360/features/properties/application/swipe_history.dart';
import 'package:go_router/go_router.dart';

PropertyFeed _feedFor(LikesSegment segment) =>
    segment == LikesSegment.liked ? PropertyFeed.liked : PropertyFeed.passed;

/// Liked and Passed homes on one sheet under the society facade, whose lit
/// windows count the liked homes. From 840 px the open home shows in a pane
/// on the right; below that a row opens the details screen.
class LikesView extends ConsumerStatefulWidget {
  const LikesView({super.key});
  @override
  ConsumerState<LikesView> createState() => _LikesViewState();
}

class _LikesViewState extends ConsumerState<LikesView> {
  /// The home in the detail pane. Only two-pane windows use it.
  PropertyModel? _open;

  @override
  Widget build(BuildContext context) {
    ref.listen(swipeHistoryProvider.select((history) => history.failures), (previous, next) {
      if (next.isNotEmpty && next != previous) {
        AppToast.error(context.l10n.text('action_failed'), context.l10n.text('like_update_failed'));
      }
    });
    return Scaffold(
      backgroundColor: context.design.background,
      body: SafeArea(
        top: false,
        child: Semantics(
          label: context.l10n.text('liked'),
          identifier: 'qa.likes.screen',
          child: isTwoPane(context)
              ? Row(
                  children: [
                    SizedBox(
                      width: 380,
                      child: _SavedList(
                        openId: _open?.id,
                        onOpen: (property) => setState(() => _open = property),
                      ),
                    ),
                    // The pane shows the open row's home again: its photo must
                    // not be a second hero with the row's tag.
                    Expanded(
                      child: SafeArea(
                        child: HeroMode(enabled: false, child: PropertyDetailPane(property: _open)),
                      ),
                    ),
                  ],
                )
              : const _SavedList(),
        ),
      ),
    );
  }
}

class _SavedList extends ConsumerStatefulWidget {
  const _SavedList({this.onOpen, this.openId});

  final ValueChanged<PropertyModel>? onOpen;
  final int? openId;

  @override
  ConsumerState<_SavedList> createState() => _SavedListState();
}

class _SavedListState extends ConsumerState<_SavedList> {
  final _scroll = ScrollController();

  /// Each tab keeps its own place, as the old per-tab lists did.
  final _offsets = <LikesSegment, double>{};

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_loadMore);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _loadMore() {
    if (!mounted || !_scroll.hasClients || _scroll.position.extentAfter > 200) return;
    final feed = _feedFor(ref.read(likesProvider));
    // Only rows have a next page; an empty or failed list has nothing to page.
    if (ref.read(visiblePropertiesProvider(feed)).isEmpty) return;
    unawaited(ref.read(propertyQueryProvider(feed).notifier).loadMore());
  }

  void _select(LikesSegment segment) {
    final current = ref.read(likesProvider);
    if (segment == current) return;
    if (_scroll.hasClients) _offsets[current] = _scroll.offset;
    ref.read(likesProvider.notifier).switchToSegment(segment);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final position = _scroll.position;
      _scroll.jumpTo(
        (_offsets[segment] ?? 0).clamp(position.minScrollExtent, position.maxScrollExtent),
      );
    });
  }

  /// The rows of [feed] so far, or -1 before its first page. A tab that was
  /// never opened stays unknown: watching it would start its request.
  ({int rows, bool more}) _count(PropertyFeed feed, PropertyFeed open) {
    if (feed != open && !ref.exists(propertyQueryProvider(feed))) return (rows: -1, more: false);
    final (waiting, more) = ref.watch(
      propertyQueryProvider(
        feed,
      ).select((page) => (page.phase == PropertyLoadPhase.idle || page.isLoading, page.hasMore)),
    );
    if (waiting) return (rows: -1, more: false);
    return (
      rows: ref.watch(visiblePropertiesProvider(feed).select((items) => items.length)),
      more: more,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final design = context.design;
    final segment = ref.watch(likesProvider);
    final feed = _feedFor(segment);
    final liked = _count(PropertyFeed.liked, feed);
    final passed = _count(PropertyFeed.passed, feed);
    final rows = feed == PropertyFeed.liked ? liked.rows : passed.rows;
    final hasRows = ref.watch(visiblePropertiesProvider(feed).select((items) => items.isNotEmpty));
    final (refreshing, refreshError) = ref.watch(
      propertyQueryProvider(
        feed,
      ).select((page) => (page.isRefreshing, page.error is LocationException ? null : page.error)),
    );
    final locationBusy = ref.watch(
      propertyLocationProvider(
        PageType.likes,
      ).select((location) => location.load.hasError || location.load.isLoading),
    );
    final filterCount = ref.watch(
      propertyFiltersProvider.select((state) => state.forPage(PageType.likes).activeFilterCount),
    );
    final saveFailed = ref.watch(propertyFiltersProvider.select((state) => state.save.hasError));
    // A short first page can fill the viewport without a scroll event.
    // Provider guards stop concurrent requests and failed-page retry storms.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMore());

    final actions = [
      if (saveFailed)
        IconButton(
          key: const ValueKey('qa.topbar.filters.retry'),
          tooltip: '${l10n.text('filters_save_failed')} ${l10n.text('retry')}',
          icon: const PaperIcon(KnifeIcon.retry, size: 22),
          onPressed: () => ref.read(propertyFiltersProvider.notifier).retrySave(),
        ),
      IconButton(
        key: const ValueKey('qa.topbar.filter.likes'),
        tooltip: '${l10n.text('filters')}${filterCount == 0 ? '' : ' ($filterCount)'}',
        onPressed: () => showPropertyFilterBottomSheet(context, pageType: PageType.likes),
        icon: Badge(
          isLabelVisible: filterCount > 0,
          backgroundColor: design.buttonPrimary,
          textColor: design.buttonPrimaryText,
          label: Text('$filterCount'),
          child: const PaperIcon(KnifeIcon.filter, size: 22),
        ),
      ),
    ];
    final slivers = [
      SliverToBoxAdapter(
        child: SizedBox(
          height: 2,
          child: refreshing ? const LinearProgressIndicator(minHeight: 2) : null,
        ),
      ),
      const SliverPadding(
        padding: EdgeInsets.fromLTRB(16, 6, 16, 0),
        sliver: SliverToBoxAdapter(child: _SearchSlip()),
      ),
      const SliverPadding(
        padding: EdgeInsets.fromLTRB(8, 4, 8, 0),
        sliver: SliverToBoxAdapter(
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: LocationSelector(pageType: PageType.likes),
          ),
        ),
      ),
      if (rows > 0 && locationBusy)
        const SliverToBoxAdapter(
          child: PropertyLocationRecovery(pageType: PageType.likes, inline: true),
        ),
      if (rows > 0 && refreshError != null)
        SliverToBoxAdapter(
          child: InlineRetryBanner(
            message: l10n.text('refresh_content_failed'),
            error: refreshError,
            isLoading: refreshing,
            identifier: 'qa.likes.content.retry',
            onRetry: () => ref.read(propertyQueryProvider(feed).notifier).load(refresh: true),
          ),
        ),
      SliverToBoxAdapter(child: PropertyRecoveryBanner(feed: feed)),
      const SliverToBoxAdapter(child: SavedActionsButton()),
      _SavedBody(key: ValueKey(feed), feed: feed, onOpen: widget.onOpen, openId: widget.openId),
    ];
    String label(String key, double shown, bool more) {
      final count = shown.round();
      return count <= 0 ? l10n.text(key) : '${l10n.text(key)} $count${more ? '+' : ''}';
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Wide windows lay the rows in two columns (see _SavedRows), so the
        // sheet holds no empty half.
        return RefreshIndicator(
          onRefresh: ref.read(likesProvider.notifier).refreshCurrentSegment,
          notificationPredicate: (notification) => hasRows && notification.depth == 0,
          child: TweenAnimationBuilder<(double, double)>(
            tween: _CountsTween(end: (liked.rows.toDouble(), passed.rows.toDouble())),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, shown, _) => PaperScrollPage(
              controller: _scroll,
              header: SceneHeaderSliver(
                title: l10n.text('saved'),
                qaId: 'qa.likes.title',
                scene: PaperSceneSpec.saved(litCount: math.max(0, liked.rows)),
                actions: actions,
                tabs: FolderTabs(
                  labels: [
                    label('liked', shown.$1, liked.more),
                    label('passed', shown.$2, passed.more),
                  ],
                  selected: segment == LikesSegment.liked ? 0 : 1,
                  onSelect: (index) =>
                      _select(index == 0 ? LikesSegment.liked : LikesSegment.passed),
                  qaIds: const ['qa.likes.tab.liked', 'qa.likes.tab.passed'],
                  seed: 'saved-tabs',
                ),
              ),
              slivers: slivers,
            ),
          ),
        );
      },
    );
  }
}

/// The tab counts, timed like `CountUpText`: each runs from its previous
/// value. A count that was unknown (-1) jumps, so a first page never counts
/// up from zero.
class _CountsTween extends Tween<(double, double)> {
  _CountsTween({super.end});

  @override
  (double, double) lerp(double t) {
    double one(double from, double to) => from < 0 || to < 0 ? to : from + (to - from) * t;
    return (one(begin!.$1, end!.$1), one(begin!.$2, end!.$2));
  }
}

/// The likes search as a hand-cut slip at the top of the sheet. The query is
/// the likes filter; the field only mirrors it.
class _SearchSlip extends ConsumerStatefulWidget {
  const _SearchSlip();
  @override
  ConsumerState<_SearchSlip> createState() => _SearchSlipState();
}

class _SearchSlipState extends ConsumerState<_SearchSlip> {
  late final _text = TextEditingController(
    text: ref.read(propertyFiltersProvider).forPage(PageType.likes).searchQuery ?? '',
  );
  final _focus = FocusNode();

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _change(String value) =>
      ref.read(propertyFiltersProvider.notifier).search(PageType.likes, value);

  @override
  Widget build(BuildContext context) {
    ref.listen(
      propertyFiltersProvider.select((state) => state.forPage(PageType.likes).searchQuery),
      (_, value) {
        if (_text.text != (value ?? '')) _text.text = value ?? '';
      },
    );
    final design = context.design;
    return ListenableBuilder(
      listenable: Listenable.merge([_focus, _text]),
      builder: (context, _) {
        final focused = _focus.hasFocus;
        return DecoratedBox(
          decoration: ShapeDecoration(
            color: design.raised,
            shape: CutBorder(
              seed: 'saved-search',
              amp: 1.5,
              side: BorderSide(
                color: focused ? design.accent : design.fieldBorder,
                width: focused ? 2 : 1,
              ),
            ),
          ),
          child: TextField(
            key: const ValueKey('qa.topbar.search_input.likes'),
            controller: _text,
            focusNode: _focus,
            onChanged: _change,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _focus.unfocus(),
            style: TextStyle(color: design.textPrimary),
            decoration: InputDecoration(
              hintText: context.l10n.text('search_in_likes_hint'),
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              constraints: const BoxConstraints(minHeight: 48),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              prefixIcon: const PaperIcon(KnifeIcon.search),
              prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              suffixIcon: _text.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: context.l10n.text('clear'),
                      icon: const PaperIcon(KnifeIcon.close),
                      onPressed: () {
                        _text.clear();
                        _change('');
                      },
                    ),
            ),
          ),
        );
      },
    );
  }
}

/// Rows, or the one state that explains why there are none. It is a sliver.
class _SavedBody extends ConsumerWidget {
  const _SavedBody({super.key, required this.feed, this.onOpen, this.openId});

  final PropertyFeed feed;
  final ValueChanged<PropertyModel>? onOpen;
  final int? openId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final empty = ref.watch(visiblePropertiesProvider(feed).select((items) => items.isEmpty));
    final (loading, error) = ref.watch(
      propertyQueryProvider(
        feed,
      ).select((page) => (page.isLoading || page.phase == PropertyLoadPhase.idle, page.error)),
    );
    final (located, locationFailed) = ref.watch(
      propertyLocationProvider(
        PageType.likes,
      ).select((location) => (location.location != null, location.load.hasError)),
    );
    final search = ref.watch(
      propertyFiltersProvider.select((value) => value.forPage(PageType.likes).searchQuery ?? ''),
    );
    final controller = ref.read(likesProvider.notifier);
    if (!empty) return _SavedRows(feed: feed, onOpen: onOpen, openId: openId);
    final liked = feed == PropertyFeed.liked;
    final Widget state;
    if (!located && (locationFailed || error is LocationException)) {
      state = const PropertyLocationRecovery(pageType: PageType.likes);
    } else if (loading) {
      return SliverFillRemaining(child: LoadingStates.propertyRowsSkeleton());
    } else if (error != null) {
      state = ErrorStates.genericError(
        error: error,
        onRetry: controller.retryCurrentSegment,
        seed: 'saved',
      );
    } else if (search.isNotEmpty) {
      state = ErrorStates.searchEmpty(searchQuery: search, onClearSearch: controller.clearSearch);
    } else {
      state = ErrorStates.emptyState(
        title: context.l10n.text(liked ? 'no_liked_properties' : 'no_passed_properties'),
        message: context.l10n.text(liked ? 'no_favorites_message' : 'no_passed_message'),
        seed: liked ? 'liked' : 'passed',
        onAction: () => context.go(AppRoutes.discover),
        actionText: context.l10n.text('go_to_discover'),
      );
    }
    return SliverFillRemaining(hasScrollBody: false, child: state);
  }
}

/// The rows as a sliver, then the next page: progress, or its own retry.
class _SavedRows extends ConsumerWidget {
  const _SavedRows({required this.feed, this.onOpen, this.openId});
  final PropertyFeed feed;
  final ValueChanged<PropertyModel>? onOpen;
  final int? openId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(visiblePropertiesProvider(feed));
    final (loadingMore, paginationError) = ref.watch(
      propertyQueryProvider(feed).select((page) => (page.isLoadingMore, page.paginationError)),
    );
    Widget row(PropertyModel property) =>
        _SavedRow(property: property, open: openId == property.id, onOpen: onOpen);

    // Rows above stay put while the next page loads or fails.
    Widget footer() {
      if (paginationError != null) {
        return InlineRetryBanner(
          message: context.l10n.text('load_more_failed'),
          error: paginationError,
          isLoading: loadingMore,
          identifier: 'qa.likes.content.retry',
          onRetry: () => ref.read(propertyQueryProvider(feed).notifier).loadMore(retry: true),
        );
      }
      if (!loadingMore) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            LoadingStates.buttonSpinner(color: context.design.textSecondary),
            const SizedBox(width: 10),
            Flexible(child: Text(context.l10n.text('loading_more_properties'))),
          ],
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          // From 600 px the rows pair up in two columns that share one top
          // line and one height, whatever the text size.
          final columns = constraints.crossAxisExtent >= 600 ? 2 : 1;
          final lines = (items.length / columns).ceil();
          return SliverList.builder(
            itemCount: lines + 1,
            itemBuilder: (context, index) {
              if (index == lines) return footer();
              final first = index * columns;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: columns == 1
                    ? row(items[first])
                    : IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: row(items[first])),
                            const SizedBox(width: 16),
                            Expanded(
                              child: first + 1 < items.length
                                  ? row(items[first + 1])
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
              );
            },
          );
        },
      ),
    );
  }
}

/// One row. It watches only this home's like state.
class _SavedRow extends ConsumerWidget {
  const _SavedRow({required this.property, required this.open, this.onOpen});

  final PropertyModel property;
  final bool open;
  final ValueChanged<PropertyModel>? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (liked, updating) = ref.watch(
      swipeHistoryProvider.select((history) {
        final entry = history.entries[property.id];
        return (entry?.isLiked ?? property.liked, entry?.phase == SwipePhase.submitting);
      }),
    );
    final controller = ref.read(likesProvider.notifier);
    return PropertyListCard(
      property: property,
      row: true,
      selected: open,
      isFavourite: liked,
      isUpdating: updating,
      onTap: onOpen == null ? null : () => onOpen!(property),
      onFavouriteToggle: () =>
          liked ? controller.removeFromLikes(property) : controller.moveToLikes(property),
    );
  }
}
