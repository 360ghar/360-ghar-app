import 'package:flutter/material.dart';

import 'package:ghar360/core/utils/responsive.dart';
import 'package:ghar360/core/widgets/common/paginated_scroll_mixin.dart';

class PaginatedGridView<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Future<void> Function() onLoadMore;
  final bool hasMore;
  final bool isLoadingMore;
  final Future<void> Function() onRefresh;

  /// Number of grid columns. When `null` (the default), the count is derived
  /// from the current [WindowSizeClass]: compact→2, medium→3, expanded→4,
  /// large→5. Pass an explicit value to lock it (backward compatible).
  final int? crossAxisCount;

  /// Ratio of item width to item height. When `null` (the default), the value
  /// is derived from the [WindowSizeClass]: compact→0.75, medium→0.80,
  /// expanded→0.82, large→0.85. Pass an explicit value to lock it.
  final double? childAspectRatio;

  final EdgeInsets padding;
  final Widget? emptyWidget;
  final bool isLoading;

  const PaginatedGridView({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.onLoadMore,
    required this.hasMore,
    required this.isLoadingMore,
    required this.onRefresh,
    this.crossAxisCount,
    this.childAspectRatio,
    this.padding = const EdgeInsets.all(16),
    this.emptyWidget,
    this.isLoading = false,
  });

  @override
  State<PaginatedGridView<T>> createState() => _PaginatedGridViewState<T>();
}

class _PaginatedGridViewState<T> extends State<PaginatedGridView<T>>
    with PaginatedScrollMixin<PaginatedGridView<T>> {
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

    // Resolve responsive defaults when the caller omits an explicit value.
    final sizeClass = context.windowSizeClass;
    final crossAxisCount =
        widget.crossAxisCount ??
        switch (sizeClass) {
          WindowSizeClass.compact => 2,
          WindowSizeClass.medium => 3,
          WindowSizeClass.expanded => 4,
          WindowSizeClass.large => 5,
        };
    final childAspectRatio =
        widget.childAspectRatio ??
        switch (sizeClass) {
          WindowSizeClass.compact => 0.75,
          WindowSizeClass.medium => 0.80,
          WindowSizeClass.expanded => 0.82,
          WindowSizeClass.large => 0.85,
        };

    return RefreshIndicator(
      color: colorScheme.primary,
      backgroundColor: colorScheme.surface,
      onRefresh: widget.onRefresh,
      child: GridView.builder(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: widget.padding,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: childAspectRatio,
        ),
        itemCount: widget.items.length + (widget.hasMore ? 1 : 0),
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
