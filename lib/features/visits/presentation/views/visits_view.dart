import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:ghar360/core/controllers/offline_queue_service.dart';
import 'package:ghar360/core/data/models/visit_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/design/paper/paper_chrome.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/providers/pending_actions_provider.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/app_toast.dart';
import 'package:ghar360/core/utils/best_effort.dart';
import 'package:ghar360/core/utils/responsive.dart';
import 'package:ghar360/core/widgets/common/error_states.dart';
import 'package:ghar360/core/widgets/common/inline_retry_banner.dart';
import 'package:ghar360/core/widgets/common/loading_states.dart';
import 'package:ghar360/core/widgets/paper/folder_tabs.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';
import 'package:ghar360/core/widgets/paper/paper_scroll_page.dart';
import 'package:ghar360/core/widgets/paper/paper_sheet.dart';
import 'package:ghar360/core/widgets/paper/scene_header_sliver.dart';
import 'package:ghar360/features/property_details/presentation/views/property_details_view.dart';
import 'package:ghar360/features/visits/presentation/controllers/visits_controller.dart';
import 'package:ghar360/features/visits/presentation/widgets/agent_card.dart';
import 'package:ghar360/features/visits/presentation/widgets/visit_card.dart';
import 'package:ghar360/features/visits/presentation/widgets/visit_edit_dialog.dart';
import 'package:ghar360/features/visits/presentation/widgets/visit_failure_message.dart';

/// Formats a phone number for dialing/WhatsApp.
///
/// Indian-number handling: a bare 10-digit number (no country code) is
/// assumed to be Indian and prefixed with `91`. Any number that already
/// carries a country code (starts with `+`, or is 11+ digits with a leading
/// `91`/`0`) is passed through unchanged so international users and numbers
/// with extensions are not misformatted.
String _formatIndianNumber(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '';
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return '';

  // Already has an explicit `+` country code: keep the original (preserves
  // extensions and international formatting). Strip extension digits (ext/x/#)
  // so they don't corrupt the dial/WhatsApp target.
  if (raw.trim().startsWith('+')) {
    final baseNumber = raw.trim().split(RegExp(r'(?:ext\.?|x|#)\s*', caseSensitive: false)).first;
    return baseNumber.replaceAll(RegExp(r'[^0-9]'), '');
  }

  String d = digits.replaceFirst(RegExp(r'^0+'), '');

  // Leading 91 with 12 digits total: already an Indian international form.
  if (d.startsWith('91') && d.length == 12) {
    return d;
  }

  // Exactly 10 digits with no country code: assume Indian, prefix 91.
  if (d.length == 10) {
    return '91$d';
  }

  // Anything longer than 10 digits that isn't a recognised Indian form is
  // treated as international; pass it through unchanged so we don't mangle it.
  return d;
}

Future<void> _launchDialer(BuildContext context, String? rawNumber) async {
  final formatted = _formatIndianNumber(rawNumber);
  if (formatted.isEmpty) {
    AppToast.warning(
      context.l10n.text('unavailable'),
      context.l10n.text('agent_contact_unavailable'),
    );
    return;
  }
  final telUri = Uri(scheme: 'tel', path: '+$formatted');

  // Each launcher variant is best-effort; the last one surfaces the toast.
  Future<bool> tryLaunch(
    Uri uri,
    String label, {
    LaunchMode mode = LaunchMode.platformDefault,
  }) async {
    var ok = false;
    await BestEffort.runAsync(() async {
      ok = await launchUrl(uri, mode: mode);
    }, label: label);
    return ok;
  }

  var launched = await tryLaunch(telUri, 'dialer-external', mode: LaunchMode.externalApplication);
  if (launched) return;

  launched = await tryLaunch(telUri, 'dialer-platform-default');
  if (launched) return;

  if (defaultTargetPlatform == TargetPlatform.iOS) {
    final telPromptUri = Uri(scheme: 'telprompt', path: '+$formatted');
    launched = await tryLaunch(telPromptUri, 'dialer-telprompt');
    if (launched) return;
  }

  final plainTelUri = Uri(scheme: 'tel', path: formatted);
  launched = await tryLaunch(plainTelUri, 'dialer-plain-tel');
  if (launched) return;

  if (!context.mounted) return;
  AppToast.error(
    context.l10n.text('action_failed'),
    context.l10n.text('could_not_open_phone_dialer'),
  );
}

Future<void> _launchWhatsApp(BuildContext context, String? rawNumber) async {
  final formatted = _formatIndianNumber(rawNumber);
  if (formatted.isEmpty) {
    AppToast.warning(
      context.l10n.text('unavailable'),
      context.l10n.text('agent_contact_unavailable'),
    );
    return;
  }
  final uri = Uri.parse('https://wa.me/$formatted');
  final ok = await canLaunchUrl(uri);
  if (!ok) {
    if (!context.mounted) return;
    AppToast.error(
      context.l10n.text('action_failed'),
      context.l10n.text('could_not_open_whatsapp'),
    );
    return;
  }
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Scheduled and past visits on one sheet under the society gate. From
/// 840 px the list sits left and the selected visit, with its home, fills
/// the right pane.
class VisitsView extends ConsumerStatefulWidget {
  const VisitsView({super.key});
  @override
  ConsumerState<VisitsView> createState() => _VisitsViewState();
}

/// Whether the first load is still running, and the failure that left the
/// screen with no visits.
(bool, Object?) _screen(VisitsState s) => (
  s.isLoading && s.visits.isEmpty,
  s.phase == VisitLoadPhase.failed && s.visits.isEmpty ? s.failure : null,
);

class _VisitsViewState extends ConsumerState<VisitsView> {
  final _scroll = ScrollController();

  /// Each tab keeps its own place, as the old per-tab lists did.
  final _offsets = <int, double>{};
  int _tab = 0;
  int? _selectedId;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_paginate);
  }

  void _paginate() {
    final state = ref.read(visitsProvider);
    final (loading, failure) = _screen(state);
    // Only the visit list pages; the first load and its failure do not.
    if (!loading &&
        failure == null &&
        _scroll.hasClients &&
        _scroll.position.extentAfter < 240 &&
        state.pagePhase == VisitPagePhase.idle) {
      unawaited(ref.read(visitsProvider.notifier).loadMoreVisits());
    }
  }

  void _select(int tab) {
    if (tab == _tab) return;
    if (_scroll.hasClients) _offsets[_tab] = _scroll.offset;
    setState(() => _tab = tab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final position = _scroll.position;
      _scroll.jumpTo(
        (_offsets[tab] ?? 0).clamp(position.minScrollExtent, position.maxScrollExtent),
      );
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (loading, failure) = ref.watch(visitsProvider.select(_screen));
    final refreshing = ref.watch(visitsProvider.select((s) => s.isRefreshing));
    final l10n = context.l10n;
    final twoPane = context.windowSizeClass.index >= WindowSizeClass.expanded.index;
    final listing = !loading && failure == null;
    final List<Widget> body;
    if (loading) {
      body = [SliverFillRemaining(child: LoadingStates.visitsSkeleton())];
    } else if (failure != null) {
      body = [
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
          sliver: SliverToBoxAdapter(child: _PendingVisits()),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorStates.genericError(
            error: failure,
            onRetry: ref.read(visitsProvider.notifier).loadVisits,
            seed: 'visits',
          ),
        ),
      ];
    } else {
      body = [
        _VisitList(
          upcoming: _tab == 0,
          selectedId: twoPane ? _selectedId : null,
          onSelect: twoPane ? (visit) => setState(() => _selectedId = visit.id) : null,
        ),
      ];
    }
    final list = LayoutBuilder(
      builder: (context, constraints) => RefreshIndicator(
        onRefresh: ref.read(visitsProvider.notifier).refreshVisits,
        notificationPredicate: (notification) => listing && notification.depth == 0,
        child: PaperScrollPage(
          key: const ValueKey('qa.visits.list'),
          controller: _scroll,
          // Wide windows keep the passes a readable width on the title's
          // left edge; the scene and the sheet still run edge to edge.
          padding: EdgeInsets.only(
            right: math.max(0.0, constraints.maxWidth - context.contentMaxWidth),
          ),
          header: SceneHeaderSliver(
            title: l10n.text('visits'),
            qaId: 'qa.visits.title',
            scene: PaperSceneSpec.visits(),
            tabs: FolderTabs(
              labels: [l10n.text('scheduled_visits'), l10n.text('past_visits')],
              selected: _tab,
              onSelect: _select,
              qaIds: const ['qa.visits.scheduled', 'qa.visits.past'],
              seed: 'visits-tabs',
            ),
          ),
          slivers: [
            if (refreshing)
              SliverToBoxAdapter(
                child: LinearProgressIndicator(semanticsLabel: l10n.text('loading')),
              ),
            ...body,
          ],
        ),
      ),
    );
    return Semantics(
      identifier: 'qa.visits.screen',
      label: l10n.text('visits'),
      child: Scaffold(
        key: const ValueKey('qa.visits.screen'),
        backgroundColor: context.design.background,
        body: SafeArea(
          top: false,
          child: !twoPane || !listing
              ? list
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 400, child: list),
                    // The same paper pane as Explore and Saved, not a rule.
                    // Its home is shown a second time, so its photo is no hero.
                    Expanded(
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(4, 12, 12, 12),
                          child: HeroMode(
                            enabled: false,
                            child: PaperSheet(
                              seed: 'pane-visits',
                              elevation: PaperElevation.low,
                              padding: const EdgeInsets.all(4),
                              child: _VisitPane(visitId: _selectedId),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// One tab as slivers: the manager and pending requests (scheduled tab
/// only), then the visit passes, then the next-page control.
class _VisitList extends ConsumerWidget {
  const _VisitList({required this.upcoming, required this.selectedId, required this.onSelect});
  final bool upcoming;
  final int? selectedId;

  /// Non-null in the two-pane layout: a tap selects instead of opening.
  final ValueChanged<VisitModel>? onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (visits, stale, failure, hasMore) = ref.watch(
      visitsProvider.select((s) => (upcoming ? s.upcoming : s.past, s.stale, s.failure, s.hasMore)),
    );
    final controller = ref.read(visitsProvider.notifier);
    final l10n = context.l10n;
    return SliverMainAxisGroup(
      slivers: [
        SliverList.list(
          children: [
            if (stale)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(
                  l10n.text('visits_saved_offline'),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: context.design.textSecondary),
                ),
              ),
            if (failure != null)
              InlineRetryBanner(
                message: visitFailureMessage(context, failure),
                error: failure,
                onRetry: controller.loadVisits,
              ),
            if (upcoming) ...[
              const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 0), child: _AgentSection()),
              const Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, 0), child: _PendingVisits()),
            ],
          ],
        ),
        // An empty first page with more to fetch is not "no visits" yet.
        if (visits.isEmpty && !hasMore)
          SliverFillRemaining(
            hasScrollBody: false,
            child: ErrorStates.emptyState(
              title: l10n.text(upcoming ? 'no_visits' : 'visits_empty_past'),
              message: l10n.text(
                upcoming ? 'visits_empty_scheduled_message' : 'visits_empty_past_message',
              ),
              actionText: l10n.text('discover'),
              onAction: () => context.go(AppRoutes.discover),
              seed: upcoming ? 'scheduled' : 'past',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            sliver: SliverList.separated(
              itemCount: visits.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final visit = visits[index];
                return VisitCard(
                  key: ValueKey('visit-${visit.id}'),
                  visit: visit,
                  isUpcoming: upcoming,
                  selected: visit.id == selectedId,
                  showActions: onSelect == null,
                  onTap: onSelect == null
                      ? () => context.push(
                          AppRoutes.propertyDetails,
                          extra: visit.property ?? visit.propertyId,
                        )
                      : () => onSelect!(visit),
                  onReschedule: () => showVisitEditDialog(context, visit, cancel: false),
                  onCancel: () => showVisitEditDialog(context, visit, cancel: true),
                );
              },
            ),
          ),
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
          sliver: SliverToBoxAdapter(child: _NextPage()),
        ),
      ],
    );
  }
}

/// The next-page footer. Rows stay put while it loads; a failure is its own
/// retry row, never a full-screen error.
class _NextPage extends ConsumerWidget {
  const _NextPage();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (phase, failure, hasMore) = ref.watch(
      visitsProvider.select((s) => (s.pagePhase, s.pageFailure, s.hasMore)),
    );
    final controller = ref.read(visitsProvider.notifier);
    if (phase == VisitPagePhase.failed) {
      return InlineRetryBanner(
        identifier: 'qa.visits.pagination.retry',
        message: visitFailureMessage(context, failure),
        error: failure,
        onRetry: controller.loadMoreVisits,
      );
    }
    if (!hasMore) return const SizedBox.shrink();
    final loading = phase == VisitPagePhase.loading;
    return Center(
      child: TextButton(
        key: const ValueKey('qa.visits.load_more'),
        onPressed: loading ? null : controller.loadMoreVisits,
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
        child: loading
            ? LoadingStates.buttonSpinner()
            : Text(context.l10n.text('visits_load_more'), textAlign: TextAlign.center),
      ),
    );
  }
}

/// The assigned relationship manager. No assignment (a 404 from the backend)
/// is a quiet line, not an error.
class _AgentSection extends ConsumerWidget {
  const _AgentSection();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agent = ref.watch(visitsProvider.select((s) => s.agent));
    final value = agent.value;
    if (value != null) {
      return AgentCard(
        agent: value,
        onCall: () => _launchDialer(context, value.contactNumber),
        onWhatsApp: () => _launchWhatsApp(context, value.contactNumber),
      );
    }
    if (agent.isLoading) return const _AgentSkeleton();
    if (agent.hasError) {
      return InlineRetryBanner(
        message: context.l10n.text('visits_agent_error'),
        error: agent.error,
        onRetry: ref.read(visitsProvider.notifier).loadRelationshipManager,
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        context.l10n.text('visits_no_agent'),
        key: const ValueKey('qa.visits.no_agent'),
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: context.design.textSecondary),
      ),
    );
  }
}

/// Placeholder in the shape of [AgentCard]: photo, two lines, two icons.
class _AgentSkeleton extends StatelessWidget {
  const _AgentSkeleton();
  @override
  Widget build(BuildContext context) => const Skeleton(
    key: ValueKey('qa.visits.agent_loading'),
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          SkeletonBox(width: 48, height: 48, radius: 24),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(height: 12, width: 140),
                SizedBox(height: 8),
                SkeletonBox(height: 18, width: 180),
              ],
            ),
          ),
          SizedBox(width: 12),
          SkeletonBox(width: 24, height: 24),
          SizedBox(width: 24),
          SkeletonBox(width: 24, height: 24),
        ],
      ),
    ),
  );
}

/// The right pane: the visit's facts and actions over its home.
class _VisitPane extends ConsumerWidget {
  const _VisitPane({required this.visitId});
  final int? visitId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visit = ref.watch(
      visitsProvider.select((s) => s.visits.where((v) => v.id == visitId).firstOrNull),
    );
    if (visit == null) {
      return ErrorStates.emptyState(
        title: context.l10n.text('visits_pane_title'),
        message: context.l10n.text('visits_pane_message'),
        seed: 'pane',
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: constraints.maxHeight * 0.4),
            child: SingleChildScrollView(child: _VisitFacts(visit: visit)),
          ),
          Expanded(
            child: PropertyDetailsView(
              key: ValueKey('visit-pane-${visit.propertyId}'),
              propertyId: visit.propertyId,
              initialProperty: visit.property,
              embedded: true,
              showBookingBar: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _VisitFacts extends StatelessWidget {
  const _VisitFacts({required this.visit});
  final VisitModel visit;
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final palette = context.design;
    final l10n = context.l10n;
    final date = visit.scheduledDate.toLocal();
    final upcoming = visit.isUpcoming;
    Widget note(String label, String value) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
        style: text.bodyMedium?.copyWith(color: palette.textSecondary),
      ),
    );
    return Padding(
      key: const ValueKey('qa.visits.pane.facts'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VisitDateBlock(date: date, seed: 'pane-stub-${visit.id}'),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${MaterialLocalizations.of(context).formatFullDate(date)} · '
                  '${TimeOfDay.fromDateTime(date).format(context)}',
                  style: text.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.text(visit.statusStringKey),
                  style: text.bodyMedium?.copyWith(
                    color: visitStatusColor(context, visit.status),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (visit.specialRequirements?.isNotEmpty ?? false)
                  note(l10n.text('visits_notes_label'), visit.specialRequirements!),
                if (visit.status == VisitStatus.cancelled &&
                    (visit.cancellationReason?.isNotEmpty ?? false))
                  note(l10n.text('visits_cancel_reason_label'), visit.cancellationReason!),
                if (upcoming && (visit.canReschedule || visit.canCancel)) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (visit.canReschedule)
                        OutlinedButton(
                          key: const ValueKey('qa.visits.pane.reschedule'),
                          onPressed: () => showVisitEditDialog(context, visit, cancel: false),
                          style: visitPaperButtonStyle(context, seed: 'pane-reschedule'),
                          child: Text(l10n.text('reschedule')),
                        ),
                      if (visit.canCancel)
                        TextButton(
                          key: const ValueKey('qa.visits.pane.cancel'),
                          onPressed: () => showVisitEditDialog(context, visit, cancel: true),
                          style: TextButton.styleFrom(
                            foregroundColor: palette.error,
                            minimumSize: const Size(48, 48),
                          ),
                          child: Text(l10n.text('cancel')),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingVisits extends ConsumerWidget {
  const _PendingVisits();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (actions, failure) = ref.watch(
      pendingActionsProvider.select((s) => (s.actions, s.failure)),
    );
    final visits = actions.where((action) => action.kind == 'visit').toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (failure != null)
          InlineRetryBanner(
            message: visitFailureMessage(context, failure),
            onRetry: () => ref.read(pendingActionsProvider.notifier).reload(),
          ),
        const _UnownedRequests(),
        if (visits.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              context.l10n.text('visits_pending_title'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ...visits.map(
            (action) => _PendingVisitCard(key: ValueKey(action.operationId), action: action),
          ),
        ],
      ],
    );
  }
}

Future<bool> _confirmDiscard(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.text('visits_discard')),
        content: Text(context.l10n.text('visits_discard_help')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.text('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.text('visits_discard')),
          ),
        ],
      ),
    ) ==
    true;

/// An unconfirmed booking: flat text with the status in warning or error
/// colour, and two quiet actions.
class _PendingVisitCard extends ConsumerStatefulWidget {
  const _PendingVisitCard({super.key, required this.action});
  final PendingAction action;
  @override
  ConsumerState<_PendingVisitCard> createState() => _PendingVisitCardState();
}

class _PendingVisitCardState extends ConsumerState<_PendingVisitCard> {
  bool _busy = false;
  String? _message;
  Future<void> _reconcile() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final found = await ref.read(visitsProvider.notifier).reconcile(widget.action);
      if (mounted && !found) setState(() => _message = context.l10n.text('visits_no_match'));
    } catch (error) {
      if (mounted) setState(() => _message = visitFailureMessage(context, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _discard() async {
    if (!await _confirmDiscard(context) || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(pendingActionsProvider.notifier).discard(widget.action.operationId);
    } catch (error) {
      if (mounted) setState(() => _message = visitFailureMessage(context, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.design;
    final text = Theme.of(context).textTheme;
    final failed = widget.action.status == PendingActionStatus.failed;
    final date = DateTime.tryParse(
      widget.action.payload['scheduled_date']?.toString() ?? '',
    )?.toLocal();
    final color = failed ? palette.error : palette.warning;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: PaperIcon(KnifeIcon.alert, size: 20, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.text(failed ? 'visits_request_failed' : 'visits_unresolved'),
                  style: text.titleSmall?.copyWith(color: color),
                ),
                if (date != null)
                  Text(
                    '${MaterialLocalizations.of(context).formatMediumDate(date)} · '
                    '${TimeOfDay.fromDateTime(date).format(context)}',
                    style: text.bodyMedium,
                  ),
                Text(
                  context.l10n.text('visits_pending_help'),
                  style: text.bodySmall?.copyWith(color: palette.textSecondary),
                ),
                if (_message != null)
                  Semantics(
                    liveRegion: true,
                    child: Text(_message!, style: text.bodySmall?.copyWith(color: palette.error)),
                  ),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: _busy ? null : _reconcile,
                      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                      child: _busy
                          ? LoadingStates.buttonSpinner()
                          : Text(context.l10n.text('visits_check_bookings')),
                    ),
                    TextButton(
                      onPressed: _busy ? null : _discard,
                      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                      child: Text(context.l10n.text('visits_discard')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UnownedRequests extends ConsumerWidget {
  const _UnownedRequests();
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(unownedActionsProvider)
      .when(
        loading: () => const SizedBox.shrink(),
        error: (error, _) => InlineRetryBanner(
          message: visitFailureMessage(context, error),
          onRetry: () => ref.invalidate(unownedActionsProvider),
        ),
        data: (actions) => actions.isEmpty
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.text('visits_legacy_requests'),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      context.l10n.text('visits_legacy_help'),
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: context.design.textSecondary),
                    ),
                    for (final action in actions)
                      TextButton(
                        onPressed: () async {
                          final database = ref.read(appDatabaseProvider);
                          if (!await _confirmDiscard(context) || !context.mounted) return;
                          try {
                            await database.discardUnownedAction(action.operationId);
                            if (context.mounted) ref.invalidate(unownedActionsProvider);
                          } catch (error) {
                            if (context.mounted) {
                              AppToast.error(
                                context.l10n.text('error'),
                                visitFailureMessage(context, error),
                              );
                            }
                          }
                        },
                        child: Text(context.l10n.text('visits_discard')),
                      ),
                  ],
                ),
              ),
      );
}
