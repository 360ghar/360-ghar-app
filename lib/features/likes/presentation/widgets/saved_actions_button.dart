import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/controllers/offline_queue_service.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/providers/pending_actions_provider.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/error_message.dart';
import 'package:ghar360/core/widgets/common/inline_retry_banner.dart';
import 'package:ghar360/core/widgets/common/loading_states.dart';
import 'package:ghar360/core/widgets/common/symmetric_safe_area.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';
import 'package:ghar360/features/properties/application/swipe_history.dart';

class SavedActionsButton extends ConsumerWidget {
  const SavedActionsButton({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingActionsProvider);
    final actions = pending.actions.where((action) => action.kind == 'swipe');
    final failure = pending.failure == null
        ? null
        : InlineRetryBanner(
            message: errorMessage(context, pending.failure),
            identifier: 'qa.saved.actions.load.retry',
            onRetry: () => ref.read(pendingActionsProvider.notifier).reload(),
          );
    if (actions.isEmpty) return failure ?? const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ?failure,
        TextButton.icon(
          key: const ValueKey('qa.saved.actions'),
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          icon: const PaperIcon(KnifeIcon.upload),
          label: Text(context.l10n.text('saved_actions', params: {'count': '${actions.length}'})),
          onPressed: () async {
            final container = ProviderScope.containerOf(context, listen: false);
            await showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              constraints: sheetConstraints(context),
              builder: (_) => UncontrolledProviderScope(
                container: container,
                child: const SafeArea(top: false, bottom: false, child: _SavedActionsSheet()),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _SavedActionsSheet extends ConsumerWidget {
  const _SavedActionsSheet();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingActionsProvider);
    final operations = ref.watch(swipeHistoryProvider.select((value) => value.pendingOperations));
    final actions = pending.actions.where((action) => action.kind == 'swipe').toList();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .6,
      minChildSize: .3,
      maxChildSize: .95,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.text('saved_actions_title'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: context.l10n.text('close'),
                onPressed: () => Navigator.of(context).pop(),
                icon: const PaperIcon(KnifeIcon.close),
              ),
            ],
          ),
          Text(context.l10n.text('swipe_discard_help')),
          if (pending.failure != null)
            InlineRetryBanner(
              identifier: 'qa.saved.actions.sheet.load.retry',
              message: errorMessage(context, pending.failure),
              onRetry: () => ref.read(pendingActionsProvider.notifier).reload(),
            ),
          for (final action in actions) ...[
            const SizedBox(height: 24),
            Text(
              context.l10n.text(
                'swipe_action_property',
                params: {
                  'action': context.l10n.text(
                    action.payload['is_liked'] == true ? 'liked' : 'passed',
                  ),
                  'id': '${action.payload['property_id'] ?? ''}',
                },
              ),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.text(
                action.failureCode == 'SUPERSEDED'
                    ? 'swipe_superseded'
                    : action.status == PendingActionStatus.failed
                    ? 'swipe_failed'
                    : 'swipe_pending',
              ),
            ),
            if (operations[action.operationId]?.hasError == true)
              Semantics(
                liveRegion: true,
                child: Text(
                  errorMessage(context, operations[action.operationId]!.error),
                  style: TextStyle(color: context.design.error),
                ),
              ),
            if (operations[action.operationId]?.isLoading == true)
              LinearProgressIndicator(
                key: ValueKey('qa.saved.action.busy.${action.operationId}'),
                semanticsLabel: context.l10n.text('loading'),
              ),
            Wrap(
              spacing: 12,
              children: [
                if (action.failureCode != 'SUPERSEDED')
                  TextButton(
                    key: ValueKey('qa.saved.action.retry.${action.operationId}'),
                    style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                    onPressed: operations[action.operationId]?.isLoading == true
                        ? null
                        : () => ref.read(swipeHistoryProvider.notifier).retryPending(action),
                    child: Text(context.l10n.text('retry')),
                  ),
                TextButton(
                  key: ValueKey('qa.saved.action.discard.${action.operationId}'),
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: operations[action.operationId]?.isLoading == true
                      ? null
                      : () => ref.read(swipeHistoryProvider.notifier).discardPending(action),
                  child: Text(context.l10n.text('discard_action')),
                ),
              ],
            ),
          ],
          if (actions.isEmpty && pending.phase == PendingActionsPhase.loading)
            Center(
              child: KeyedSubtree(
                key: const ValueKey('qa.saved.actions.loading'),
                child: LoadingStates.buttonSpinner(size: 24, color: context.design.textSecondary),
              ),
            )
          else if (actions.isEmpty && pending.failure == null)
            Text(context.l10n.text('saved_actions_empty')),
        ],
      ),
    );
  }
}
