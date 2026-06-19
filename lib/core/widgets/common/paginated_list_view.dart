import 'package:flutter/material.dart';

import 'package:ghar360/core/widgets/common/paginated_scroll_mixin.dart';

class PaginatedListView<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Future<void> Function() onLoadMore;
  final bool hasMore;
  final bool isLoadingMore;
  final Future<void> Function() onRefresh;
  final EdgeInsets padding;
  final Widget? emptyWidget;
  final bool isLoading;
  final Widget? separatorBuilder;
  final ScrollPhysics? physics;

  const PaginatedListView({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.onLoadMore,
    required this.hasMore,
    required this.isLoadingMore,
    required this.onRefresh,
    this.padding = const EdgeInsets.all(16),
    this.emptyWidget,
    this.isLoading = false,
    this.separatorBuilder,
    this.physics,
  });

  @override
  State<PaginatedListView<T>> createState() => _PaginatedListViewState<T>();
}

class _PaginatedListViewState<T> extends State<PaginatedListView<T>>
    with PaginatedScrollMixin<PaginatedListView<T>> {
  @override
  void initState() {
    super.initState();
    initPaginatedScroll(
      onLoadMore: () => widget.onLoadMore(),
      hasMore: () => widget.hasMore,
      isLoadingMore: () => widget.isLoadingMore,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (widget.isLoading) {
      return buildFullScreenLoader(colorScheme);
    }

    if (widget.items.isEmpty && widget.emptyWidget != null) {
      return buildEmptyRefresh(
        colorScheme: colorScheme,
        onRefresh: widget.onRefresh,
        emptyWidget: widget.emptyWidget,
      );
    }

    return RefreshIndicator(
      color: colorScheme.primary,
      backgroundColor: colorScheme.surface,
      onRefresh: widget.onRefresh,
      child: ListView.separated(
        controller: scrollController,
        padding: widget.padding,
        physics: widget.physics ?? const AlwaysScrollableScrollPhysics(),
        itemCount: widget.items.length + (widget.hasMore ? 1 : 0),
        separatorBuilder: (context, index) {
          return widget.separatorBuilder ?? const SizedBox(height: 8);
        },
        itemBuilder: (context, index) {
          if (index == widget.items.length) {
            return buildLoadMoreIndicator(
              colorScheme: colorScheme,
              isLoadingMore: widget.isLoadingMore,
            );
          }
          return widget.itemBuilder(context, widget.items[index], index);
        },
      ),
    );
  }
}
