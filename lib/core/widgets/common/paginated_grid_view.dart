import 'package:flutter/material.dart';

import 'package:ghar360/core/utils/responsive.dart';

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

class _PaginatedGridViewState<T> extends State<PaginatedGridView<T>> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      // Load more when user scrolls within 200 pixels of the bottom
      if (widget.hasMore && !widget.isLoadingMore) {
        widget.onLoadMore();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (widget.isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
        ),
      );
    }

    if (widget.items.isEmpty && widget.emptyWidget != null) {
      return RefreshIndicator(
        color: colorScheme.primary,
        backgroundColor: colorScheme.surface,
        onRefresh: widget.onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: widget.emptyWidget,
          ),
        ),
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
        controller: _scrollController,
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
            // Loading indicator at the bottom
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: widget.isLoadingMore
                    ? CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                      )
                    : const SizedBox.shrink(),
              ),
            );
          }

          return widget.itemBuilder(context, widget.items[index], index);
        },
      ),
    );
  }
}
