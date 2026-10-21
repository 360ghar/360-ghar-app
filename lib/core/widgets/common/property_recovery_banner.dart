import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/widgets/common/inline_retry_banner.dart';
import 'package:ghar360/features/properties/application/property_filters.dart';
import 'package:ghar360/features/properties/application/property_queries.dart';
import 'package:ghar360/features/properties/application/swipe_history.dart';

enum _Recovery { filters, ledger, page }

/// Show one actionable persistence failure at a time without hiding the feed.
class PropertyRecoveryBanner extends ConsumerStatefulWidget {
  const PropertyRecoveryBanner({super.key, required this.feed});
  final PropertyFeed feed;
  @override
  ConsumerState<PropertyRecoveryBanner> createState() => _PropertyRecoveryBannerState();
}

class _PropertyRecoveryBannerState extends ConsumerState<PropertyRecoveryBanner> {
  _Recovery? _retrying;

  Future<void> _retry(_Recovery recovery) async {
    if (_retrying != null) return;
    setState(() => _retrying = recovery);
    try {
      switch (recovery) {
        case _Recovery.filters:
          await ref.read(propertyFiltersProvider.notifier).retrySave();
        case _Recovery.ledger:
          await ref.read(swipeHistoryProvider.notifier).retrySave();
        case _Recovery.page:
          await ref.read(propertyQueryProvider(widget.feed).notifier).load(refresh: true);
      }
    } finally {
      if (mounted) setState(() => _retrying = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(propertyFiltersProvider.select((value) => value.save));
    final ledgerFailure = ref.watch(swipeHistoryProvider.select((value) => value.storageError));
    final (pageStorageError, stale, failed, busy) = ref.watch(
      propertyQueryProvider(
        widget.feed,
      ).select((page) => (page.storageError, page.stale, page.error != null, page.busy)),
    );
    if (filters.hasError || _retrying == _Recovery.filters) {
      return InlineRetryBanner(
        identifier: 'qa.filters.save.retry',
        message: context.l10n.text('filters_save_failed'),
        isLoading: _retrying != null || filters.isLoading,
        onRetry: () => _retry(_Recovery.filters),
      );
    }
    if (ledgerFailure != null || pageStorageError != null || _retrying != null) {
      return InlineRetryBanner(
        identifier: 'qa.properties.save.retry',
        message: context.l10n.text('local_save_failed'),
        isLoading: _retrying != null || (ledgerFailure == null && busy),
        onRetry: () => _retry(ledgerFailure != null ? _Recovery.ledger : _Recovery.page),
      );
    }
    if (stale && !failed) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Semantics(
          liveRegion: true,
          child: Text(
            context.l10n.text('saved_content_stale'),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.design.textSecondary),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
