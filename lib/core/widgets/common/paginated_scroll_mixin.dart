import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Distance from the bottom of the scroll view (in pixels) at which the
/// next page is requested.
const kPaginatedLoadMoreThreshold = 200.0;

/// Shared lifecycle + helpers for paginated scroll views.
///
/// `PaginatedListView` and `PaginatedGridView` previously duplicated the
/// scroll-controller setup, the load-more threshold check, the full-screen
/// loading spinner, and the empty-state-with-refresh wrapper. This mixin
/// centralizes that behavior so the two widgets only differ in their
/// `ListView`/`GridView` builder.
mixin PaginatedScrollMixin<W extends StatefulWidget> on State<W> {
  ScrollController? scrollController;

  /// Registers the scroll listener that triggers [onLoadMore] once the user
  /// scrolls within [kPaginatedLoadMoreThreshold] of the bottom. The load is
  /// only fired while [hasMore] is true and [isLoadingMore] is false.
  @protected
  void initPaginatedScroll({
    required Future<void> Function() onLoadMore,
    required bool Function() hasMore,
    required bool Function() isLoadingMore,
  }) {
    scrollController = ScrollController();
    scrollController!.addListener(() {
      if (scrollController!.position.pixels >=
          scrollController!.position.maxScrollExtent - kPaginatedLoadMoreThreshold) {
        if (hasMore() && !isLoadingMore()) {
          onLoadMore();
        }
      }
    });
  }

  /// Full-screen centered loading spinner used while the first page loads.
  @protected
  Widget buildFullScreenLoader(ColorScheme colorScheme) {
    return Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
      ),
    );
  }

  /// Pull-to-refresh wrapper around [emptyWidget], so an empty list still
  /// supports swipe-to-refresh.
  @protected
  Widget buildEmptyRefresh({
    required ColorScheme colorScheme,
    required Future<void> Function() onRefresh,
    required Widget? emptyWidget,
  }) {
    return RefreshIndicator(
      color: colorScheme.primary,
      backgroundColor: colorScheme.surface,
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: math.min(MediaQuery.of(context).size.height * 0.7, 720),
          child: emptyWidget,
        ),
      ),
    );
  }

  /// Trailing cell shown after the last item while more pages load.
  @protected
  Widget buildLoadMoreIndicator({required ColorScheme colorScheme, required bool isLoadingMore}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: isLoadingMore
            ? CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  @override
  void dispose() {
    scrollController?.dispose();
    super.dispose();
  }
}
