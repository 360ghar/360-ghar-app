import 'package:flutter/material.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/design/paper/paper_chrome.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/widgets/common/loading_states.dart';
import 'package:ghar360/core/widgets/common/retry_wait.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';

/// A failed refresh or next-page request must not replace usable content.
/// Pass [error] so a rate limit disables retry until its wait has passed.
class InlineRetryBanner extends StatelessWidget {
  const InlineRetryBanner({
    super.key,
    required this.message,
    required this.onRetry,
    this.error,
    this.isLoading = false,
    this.identifier = 'qa.content.retry',
  });

  final String message;
  final VoidCallback onRetry;
  final Object? error;
  final bool isLoading;
  final String identifier;

  @override
  Widget build(BuildContext context) {
    final palette = context.design;
    final text = Theme.of(context).textTheme;
    // An amber slip laid over kept content: caution, not a failure screen.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: palette.notice,
          shape: CutBorder(seed: identifier, amp: 1.5),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
            child: RetryWait(
              key: ObjectKey(error),
              error: error,
              builder: (context, wait) => LayoutBuilder(
                builder: (context, constraints) {
                  final line = Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 13),
                        child: PaperIcon(KnifeIcon.alert, size: 18, color: palette.warning),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              message,
                              style: text.bodyMedium?.copyWith(color: palette.textPrimary),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                  final label = wait > 0
                      ? context.l10n.text('retry_in_seconds', params: {'seconds': '$wait'})
                      : context.l10n.text('retry');
                  final retry = Semantics(
                    identifier: identifier,
                    child: TextButton(
                      key: ValueKey(identifier),
                      onPressed: isLoading || wait > 0 ? null : onRetry,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 44),
                        foregroundColor: palette.accent,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Opacity(
                            opacity: isLoading ? 0 : 1,
                            child: Text(label, textAlign: TextAlign.center),
                          ),
                          if (isLoading)
                            LoadingStates.buttonSpinner(
                              color: palette.accent,
                              semanticsLabel: context.l10n.text('retrying'),
                            ),
                        ],
                      ),
                    ),
                  );
                  // The retry goes under the message only when both do not fit.
                  final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
                  if (constraints.maxWidth / scale < 300) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        line,
                        Padding(padding: const EdgeInsets.only(left: 18), child: retry),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: line),
                      const SizedBox(width: 4),
                      Padding(padding: const EdgeInsets.only(top: 2), child: retry),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
