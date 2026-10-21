import 'package:flutter/material.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/design/paper/paper_cut.dart';
import 'package:ghar360/core/storage/storage_failure.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/utils/error_message.dart';
import 'package:ghar360/core/widgets/common/retry_wait.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';
import 'package:ghar360/core/widgets/paper/paper_vignette.dart';

/// Empty, error, offline and not-found screens. Each shows one paper scene,
/// a title, one line and one next action.
class ErrorStates {
  ErrorStates._();

  /// A failed load with nothing to show. Retry appears only when a later
  /// attempt can succeed, and waits out a rate limit first.
  static Widget genericError({
    required Object? error,
    VoidCallback? onRetry,
    String? customMessage,
    String? customRetryText,
    String seed = 'page',
  }) => Builder(
    builder: (context) {
      final l10n = context.l10n;
      final scene = switch (error) {
        NetworkException() => PaperScene.offline,
        NotFoundException() || ApiException(statusCode: 404) => PaperScene.notFound,
        _ => PaperScene.error,
      };
      final title = switch (error) {
        RateLimitException() => 'rate_limited_title',
        NetworkException() => 'connection_problem',
        AuthenticationException() => 'authentication_required',
        ValidationException() => 'invalid_input',
        NotFoundException() || ApiException(statusCode: 404) => 'not_found',
        ServerException() => 'server_error',
        StorageFailure() || CacheException() => 'local_save_failed',
        _ => 'something_went_wrong',
      };
      final retry = onRetry != null && isRetryableFailure(error);
      return RetryWait(
        key: ObjectKey(error),
        error: error,
        builder: (context, wait) => StateBlock(
          scene: scene,
          seed: PaperVignette.seedFor(
            scene,
            scene == PaperScene.notFound && seed == 'details' ? 'property' : seed,
          ),
          title: l10n.text(title),
          message: customMessage ?? errorMessage(context, error),
          actionLabel: !retry
              ? null
              : wait > 0
              ? l10n.text('retry_in_seconds', params: {'seconds': '$wait'})
              : customRetryText ?? l10n.text('retry'),
          onAction: retry && wait == 0 ? onRetry : null,
          actionIcon: KnifeIcon.retry,
          identifier: 'qa.state.error',
        ),
      );
    },
  );

  /// A list with no rows yet, with one way forward.
  static Widget emptyState({
    required String title,
    required String message,
    VoidCallback? onAction,
    String? actionText,
    String seed = 'search',
  }) => Builder(
    builder: (context) => StateBlock(
      scene: PaperScene.empty,
      seed: seed,
      title: title,
      message: message,
      actionLabel: onAction == null ? null : actionText ?? context.l10n.text('explore_properties'),
      onAction: onAction,
      identifier: 'qa.state.empty',
    ),
  );

  /// A search that matched nothing.
  static Widget searchEmpty({required String searchQuery, VoidCallback? onClearSearch}) => Builder(
    builder: (context) => StateBlock(
      scene: PaperScene.empty,
      seed: 'search',
      title: context.l10n.text('no_results_found'),
      message: context.l10n.text('no_results_message', params: {'query': searchQuery}),
      actionLabel: onClearSearch == null ? null : context.l10n.text('clear_search'),
      onAction: onClearSearch,
      identifier: 'qa.state.search_empty',
    ),
  );

  /// Every card in the deck has been swiped. Changing filters is the way on;
  /// refresh stays available as a quiet link.
  static Widget swipeDeckEmpty({VoidCallback? onRefresh, VoidCallback? onChangeFilters}) => Builder(
    builder: (context) => StateBlock(
      scene: PaperScene.empty,
      seed: 'discover',
      title: context.l10n.text('no_more_properties'),
      message: context.l10n.text('no_more_properties_message'),
      actionLabel: onChangeFilters == null ? null : context.l10n.text('change_filters'),
      actionIcon: KnifeIcon.filter,
      onAction: onChangeFilters,
      secondaryLabel: onRefresh == null ? null : context.l10n.text('refresh'),
      onSecondary: onRefresh,
      identifier: 'qa.state.deck_empty',
    ),
  );

  /// A short failure line inside a form or card, with a retry link.
  static Widget inlineError({required String message, VoidCallback? onRetry}) => Builder(
    builder: (context) {
      final design = context.design;
      final line = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PaperIcon(KnifeIcon.alert, size: 20, color: design.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: design.error),
            ),
          ),
        ],
      );
      final retry = onRetry == null
          ? null
          : TextButton(onPressed: onRetry, child: Text(context.l10n.text('retry')));
      return Semantics(
        container: true,
        liveRegion: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: retry == null
              ? line
              : LayoutBuilder(
                  builder: (context, constraints) {
                    // The retry goes under the message when both do not fit on one line.
                    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
                    if (constraints.maxWidth / scale >= 360) {
                      return Row(
                        children: [
                          Expanded(child: line),
                          retry,
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        line,
                        Padding(padding: const EdgeInsets.only(left: 22), child: retry),
                      ],
                    );
                  },
                ),
        ),
      );
    },
  );

  /// The signed-in profile could not load. Retry, or sign out to recover.
  static Widget profileLoadError({
    VoidCallback? onRetry,
    VoidCallback? onSignOut,
    String? customMessage,
    bool isRetrying = false,
  }) => Builder(
    builder: (context) => StateBlock(
      scene: PaperScene.error,
      seed: 'profile',
      title: context.l10n.text('profile_load_error'),
      message: customMessage ?? context.l10n.text('profile_load_error_message'),
      actionLabel: context.l10n.text(isRetrying ? 'retrying' : 'retry'),
      actionIcon: KnifeIcon.retry,
      onAction: isRetrying ? null : onRetry,
      secondaryLabel: onSignOut == null ? null : context.l10n.text('sign_out'),
      onSecondary: onSignOut,
      identifier: 'qa.state.profile_error',
    ),
  );
}

/// The layout every state screen shares: scene, title, one line, one action,
/// centred and scrollable so 2x text never overflows.
class StateBlock extends StatelessWidget {
  const StateBlock({
    super.key,
    required this.scene,
    required this.seed,
    required this.title,
    required this.message,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
    this.detail,
    this.identifier = 'qa.state',
  });

  final PaperScene scene;
  final String seed;
  final String title;
  final String message;

  /// The one next action. Null hides the button; a null [onAction] disables it.
  final String? actionLabel;
  final KnifeIcon? actionIcon;
  final VoidCallback? onAction;

  /// A quiet text link, only where a second way out is needed.
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  /// Extra content under the message, such as a developer error dump.
  final Widget? detail;
  final String identifier;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final design = context.design;
    final label = actionLabel;
    final secondary = secondaryLabel;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MountedVignette(scene, seed: seed, width: 240),
              const SizedBox(height: 24),
              Semantics(
                header: true,
                child: Text(title, style: text.headlineMedium, textAlign: TextAlign.center),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: text.bodyMedium?.copyWith(color: design.textSecondary),
                textAlign: TextAlign.center,
              ),
              if (detail case final detail?) ...[const SizedBox(height: 20), detail],
              if (label != null) ...[
                const SizedBox(height: 24),
                Semantics(
                  identifier: '$identifier.action',
                  child: FilledButton(
                    key: ValueKey('$identifier.action'),
                    onPressed: onAction,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (actionIcon case final icon?) ...[
                          PaperIcon(icon, size: 18),
                          const SizedBox(width: 8),
                        ],
                        Flexible(child: Text(label, textAlign: TextAlign.center)),
                      ],
                    ),
                  ),
                ),
              ],
              if (secondary != null) ...[
                const SizedBox(height: 8),
                Semantics(
                  identifier: '$identifier.secondary',
                  child: TextButton(
                    key: ValueKey('$identifier.secondary'),
                    onPressed: onSecondary,
                    child: Text(secondary),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A state scene on its white card-stock mat. The scene's own card is the
/// sky tone, which is also the page tone, so on the sky page it would fade
/// into the page; the mat gives it a cut white edge to stand on. The mat is
/// painted outside the scene's box, with no shadow: inside a white sheet it
/// is the sheet itself, and the layout never moves.
class MountedVignette extends StatelessWidget {
  const MountedVignette(this.scene, {super.key, required this.seed, this.width = 220});

  final PaperScene scene;
  final String seed;
  final double width;

  /// How far the mat reaches past the scene on each side.
  static const margin = 12.0;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _MatPainter(context.design.surface, 'mat-${scene.name}-$seed'),
    child: PaperVignette(scene, seed: seed, width: width),
  );
}

class _MatPainter extends CustomPainter {
  const _MatPainter(this.color, this.seed);

  final Color color;
  final String seed;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawPath(
    cutPolygon(seed, amp: 2).toPath((Offset.zero & size).inflate(MountedVignette.margin)),
    Paint()..color = color,
  );

  @override
  bool shouldRepaint(_MatPainter old) => old.color != color || old.seed != seed;
}
