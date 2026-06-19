import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/data/models/visit_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/core/utils/app_spacing.dart';
import 'package:ghar360/core/utils/app_toast.dart';
import 'package:ghar360/core/utils/responsive.dart';
import 'package:ghar360/core/widgets/common/max_content_width.dart';
import 'package:ghar360/core/widgets/common/segmented_control.dart';
import 'package:ghar360/features/visits/presentation/controllers/visits_controller.dart';
import 'package:ghar360/features/visits/presentation/widgets/agent_card.dart';
import 'package:ghar360/features/visits/presentation/widgets/visit_card.dart';
import 'package:ghar360/features/visits/presentation/widgets/visits_skeleton_loaders.dart';
import 'package:url_launcher/url_launcher.dart';

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

  // Already has an explicit `+` country code — keep the original (preserves
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
  // treated as international — pass through unchanged so we don't mangle it.
  return d;
}

Future<void> _launchDialer(String? rawNumber) async {
  final formatted = _formatIndianNumber(rawNumber);
  if (formatted.isEmpty) {
    AppToast.warning('unavailable'.tr, 'agent_contact_unavailable'.tr);
    return;
  }
  final telUri = Uri(scheme: 'tel', path: '+$formatted');

  try {
    final launched = await launchUrl(telUri, mode: LaunchMode.externalApplication);
    if (launched) return;
  } catch (_) {}

  try {
    final launched = await launchUrl(telUri, mode: LaunchMode.platformDefault);
    if (launched) return;
  } catch (_) {}

  if (GetPlatform.isIOS) {
    final telPromptUri = Uri(scheme: 'telprompt', path: '+$formatted');
    try {
      final launched = await launchUrl(telPromptUri, mode: LaunchMode.platformDefault);
      if (launched) return;
    } catch (_) {}
  }

  final plainTelUri = Uri(scheme: 'tel', path: formatted);
  try {
    final launched = await launchUrl(plainTelUri, mode: LaunchMode.platformDefault);
    if (launched) return;
  } catch (_) {}

  AppToast.error('action_failed'.tr, 'could_not_open_phone_dialer'.tr);
}

Future<void> _launchWhatsApp(String? rawNumber) async {
  final formatted = _formatIndianNumber(rawNumber);
  if (formatted.isEmpty) {
    AppToast.warning('unavailable'.tr, 'agent_contact_unavailable'.tr);
    return;
  }
  final uri = Uri.parse('https://wa.me/$formatted');
  final ok = await canLaunchUrl(uri);
  if (!ok) {
    AppToast.error('action_failed'.tr, 'could_not_open_whatsapp'.tr);
    return;
  }
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

class VisitsView extends GetView<VisitsController> {
  const VisitsView({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Semantics(
        label: 'qa.visits.screen',
        identifier: 'qa.visits.screen',
        child: Scaffold(
          key: const ValueKey('qa.visits.screen'),
          backgroundColor: AppDesign.scaffoldBackground,
          body: SafeArea(
            child: Obx(() {
              final Widget child;
              final Key key;

              if (controller.isLoading.value) {
                key = const ValueKey('loading');
                child = _buildLoadingState();
              } else {
                key = const ValueKey('content');
                child = _VisitsContent(controller: controller);
              }

              return AnimatedSwitcher(
                duration: AppDurations.contentFade,
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: KeyedSubtree(key: key, child: child),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: [
        Container(height: 48, color: AppDesign.scaffoldBackground),
        Container(
          color: AppDesign.scaffoldBackground,
          child: const Padding(padding: EdgeInsets.all(20), child: RelationshipManagerSkeleton()),
        ),
        Expanded(child: TabBarView(children: [_buildSkeletonList(), _buildSkeletonList()])),
      ],
    );
  }

  Widget _buildSkeletonList() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: List.generate(3, (index) => const VisitCardSkeleton())),
    );
  }
}

class _VisitsContent extends StatefulWidget {
  final VisitsController controller;

  const _VisitsContent({required this.controller});

  @override
  State<_VisitsContent> createState() => _VisitsContentState();
}

class _VisitsContentState extends State<_VisitsContent> {
  TabController? _tabController;

  // Scroll controllers for the two paginated tabs. Each tab's SingleChildScrollView
  // is driven by its own controller so the bottom-of-list detection can call
  // [VisitsController.loadMoreVisits] without interfering with the other tab.
  final ScrollController _upcomingScrollController = ScrollController();
  final ScrollController _pastScrollController = ScrollController();

  /// Threshold (pixels) from the bottom at which we trigger the next page.
  /// Keep small enough to feel "infinite" but generous enough to mask the
  /// network round-trip on slow connections.
  static const double _loadMoreThresholdPx = 240;

  // Listener attachment is guarded by [_upcomingListenerAttached] /
  // [_pastListenerAttached] so rebuilds of the tab body never re-register
  // the same callback on the [ScrollController] (which would fire twice
  // per scroll event). [ScrollController.hasListeners] is a protected
  // ChangeNotifier member, so we cannot rely on it from outside the
  // subclass.
  bool _upcomingListenerAttached = false;
  bool _pastListenerAttached = false;

  void _onUpcomingScroll() => _onScrollForPagination(_upcomingScrollController);
  void _onPastScroll() => _onScrollForPagination(_pastScrollController);

  void _onTabChanged() {
    if (_tabController != null && !_tabController!.indexIsChanging) {
      setState(() {});
    }
  }

  void _onScrollForPagination(ScrollController controller) {
    if (!controller.hasClients) return;
    final position = controller.position;
    // Near-bottom detection: remaining pixels below the viewport are within
    // [_loadMoreThresholdPx]. Skip when the controller is already loading the
    // next page or when the server signalled the terminal page.
    final remaining = position.maxScrollExtent - position.pixels;
    if (remaining <= _loadMoreThresholdPx) {
      final ctrl = widget.controller;
      if (!ctrl.isLoadingMore.value && ctrl.hasMore.value) {
        // Fire-and-forget: loadMoreVisits owns its own error/isLoadingMore
        // lifecycle so the UI never gets stuck mid-pagination.
        ctrl.loadMoreVisits();
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final inherited = DefaultTabController.of(context);
    if (inherited != _tabController) {
      _tabController?.removeListener(_onTabChanged);
      _tabController = inherited;
      _tabController!.addListener(_onTabChanged);
    }
  }

  @override
  void dispose() {
    _tabController?.removeListener(_onTabChanged);
    _upcomingScrollController.removeListener(_onUpcomingScroll);
    _pastScrollController.removeListener(_onPastScroll);
    _upcomingScrollController.dispose();
    _pastScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _tabController?.index ?? 0;

    return MaxContentWidth(
      // Center the visits content and cap width on tablet/desktop. On compact
      // (phone) widths MaxContentWidth is full-bleed (no-op).
      maxWidth: 840,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              AppSpacing.sm,
              AppSpacing.screenPadding,
              0,
            ),
            child: SegmentedControl(
              selectedIndex: selectedIndex,
              segments: [
                SegmentItem(
                  label: 'scheduled_visits'.tr,
                  badge: widget.controller.upcomingVisits.length,
                  semanticsLabel: 'qa.visits.tab.scheduled',
                  semanticsIdentifier: 'qa.visits.tab.scheduled',
                ),
                SegmentItem(
                  label: 'past_visits'.tr,
                  badge: widget.controller.pastVisits.length,
                  semanticsLabel: 'qa.visits.tab.past',
                  semanticsIdentifier: 'qa.visits.tab.past',
                ),
              ],
              onSegmentChanged: (index) => _tabController?.animateTo(index),
            ),
          ),
          Obx(
            () => widget.controller.isBackgroundRefreshing.value
                ? const LinearProgressIndicator(
                    minHeight: 2,
                    backgroundColor: AppDesign.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(AppDesign.primaryYellow),
                  )
                : const SizedBox.shrink(),
          ),
          Container(
            color: AppDesign.scaffoldBackground,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: _buildRelationshipManagerCard(),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController!,
              children: [_buildUpcomingVisitsTab(), _buildPastVisitsTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingVisitsTab() {
    if (!_upcomingListenerAttached) {
      _upcomingScrollController.addListener(_onUpcomingScroll);
      _upcomingListenerAttached = true;
    }
    return RefreshIndicator(
      onRefresh: widget.controller.refreshVisits,
      child: SingleChildScrollView(
        controller: _upcomingScrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Obx(() {
              if (widget.controller.upcomingVisits.isEmpty) {
                return _buildEmptyState('no_visits'.tr, 'no_upcoming_visits_subtitle'.tr);
              }

              return _buildResponsiveVisitGrid(
                context,
                widget.controller.upcomingVisits,
                isUpcoming: true,
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPastVisitsTab() {
    if (!_pastListenerAttached) {
      _pastScrollController.addListener(_onPastScroll);
      _pastListenerAttached = true;
    }
    return RefreshIndicator(
      onRefresh: widget.controller.refreshVisits,
      child: SingleChildScrollView(
        controller: _pastScrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Obx(() {
              if (widget.controller.pastVisits.isEmpty) {
                return _buildEmptyState('no_visits'.tr, 'no_past_visits_subtitle'.tr);
              }

              return _buildResponsiveVisitGrid(
                context,
                widget.controller.pastVisits,
                isUpcoming: false,
              );
            }),
          ],
        ),
      ),
    );
  }

  /// Lays out visit cards responsively. On compact (phone) widths cards stack
  /// in a single column exactly as before. On tablet/desktop widths they
  /// reflow into a multi-column grid (2 columns on medium, 3 on expanded+)
  /// using a [Wrap] so each card keeps its natural height — visit cards have
  /// variable content (special-requirements notes, action buttons) that does
  /// not fit a fixed aspect-ratio grid cell.
  Widget _buildResponsiveVisitGrid(
    BuildContext context,
    List<VisitModel> visits, {
    required bool isUpcoming,
  }) {
    final columns = _visitColumnCount(context);

    // Single column → original stacked layout (unchanged on phones).
    if (columns <= 1) {
      return Column(
        children: visits
            .map(
              (visit) => VisitCard(
                visit: visit,
                isUpcoming: isUpcoming,
                onTap: () => _openPropertyDetails(visit),
                onReschedule: isUpcoming ? () => _showRescheduleDialog(visit) : () {},
                onCancel: isUpcoming ? () => _showCancelDialog(visit) : () {},
              ),
            )
            .toList(),
      );
    }

    // Multi-column grid via Wrap. Each card is constrained to an equal fraction
    // of the available width; the card's own internal layout (fixed 72px thumb
    // + flexible text) adapts to the narrower cell.
    const spacing = AppSpacing.listItemSpacing;
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: visits
              .map(
                (visit) => SizedBox(
                  width: cardWidth,
                  child: VisitCard(
                    visit: visit,
                    isUpcoming: isUpcoming,
                    onTap: () => _openPropertyDetails(visit),
                    onReschedule: isUpcoming ? () => _showRescheduleDialog(visit) : () {},
                    onCancel: isUpcoming ? () => _showCancelDialog(visit) : () {},
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  /// Visit-card column count by window-size class. Compact stays single-column
  /// (phone layout unchanged); medium+ reflows into a grid.
  static int _visitColumnCount(BuildContext context) {
    switch (context.windowSizeClass) {
      case WindowSizeClass.compact:
        return 1;
      case WindowSizeClass.medium:
        return 2;
      case WindowSizeClass.expanded:
        return 3;
      case WindowSizeClass.large:
        return 3;
    }
  }

  void _openPropertyDetails(VisitModel visit) {
    if (visit.property != null) {
      Get.toNamed(AppRoutes.propertyDetails, arguments: visit.property);
    }
  }

  Widget _buildRelationshipManagerCard() {
    return Obx(() {
      if (widget.controller.isLoadingAgent.value) {
        return const RelationshipManagerSkeleton();
      }

      final agent = widget.controller.relationshipManager.value;
      if (agent == null) {
        return const RelationshipManagerSkeleton();
      }

      return AgentCard(
        agent: agent,
        onCall: () {
          _launchDialer(agent.contactNumber);
        },
        onWhatsApp: () {
          _launchWhatsApp(agent.contactNumber);
        },
      );
    });
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
      width: double.infinity,
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontStyle: FontStyle.italic,
              fontSize: 18,
              color: AppDesign.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(fontSize: 14, color: AppDesign.textTertiary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showRescheduleDialog(VisitModel visit) {
    final now = DateTime.now();
    DateTime selectedDate = visit.scheduledDate.isBefore(now) ? now : visit.scheduledDate;
    TimeOfDay selectedTime = visit.scheduledDate.isBefore(now)
        ? TimeOfDay.fromDateTime(now.add(const Duration(hours: 1)))
        : TimeOfDay.fromDateTime(visit.scheduledDate);
    bool isLoading = false;

    Get.dialog(
      StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('reschedule_visit'.tr),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${'reschedule_visit_to_prefix'.tr} ${visit.propertyTitle}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(Icons.calendar_today, color: AppDesign.primaryYellow),
                  title: Text('date'.tr),
                  subtitle: Text('${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),
                  onTap: isLoading
                      ? null
                      : () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 30)),
                          );
                          if (picked != null) {
                            setState(() {
                              selectedDate = picked;
                            });
                          }
                        },
                ),
                ListTile(
                  leading: const Icon(Icons.access_time, color: AppDesign.primaryYellow),
                  title: Text('time'.tr),
                  subtitle: Text(selectedTime.format(context)),
                  onTap: isLoading
                      ? null
                      : () async {
                          final TimeOfDay? picked = await showTimePicker(
                            context: context,
                            initialTime: selectedTime,
                          );
                          if (picked != null) {
                            setState(() {
                              selectedTime = picked;
                            });
                          }
                        },
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: isLoading ? null : () => Get.back(), child: Text('cancel'.tr)),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        final newDateTime = DateTime(
                          selectedDate.year,
                          selectedDate.month,
                          selectedDate.day,
                          selectedTime.hour,
                          selectedTime.minute,
                        );

                        if (newDateTime.isBefore(DateTime.now())) {
                          AppToast.warning('invalid_time'.tr, 'select_future_datetime'.tr);
                          return;
                        }

                        setState(() {
                          isLoading = true;
                        });

                        final success = await widget.controller.rescheduleVisit(
                          visit.id.toString(),
                          newDateTime,
                        );

                        if (success) {
                          Get.back();
                        } else {
                          setState(() {
                            isLoading = false;
                          });
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppDesign.primaryYellow,
                  foregroundColor: AppDesign.buttonText,
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppDesign.overlayLight),
                        ),
                      )
                    : Text('reschedule'.tr),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showCancelDialog(VisitModel visit) {
    final TextEditingController reasonController = TextEditingController();
    bool isLoading = false;

    Get.dialog(
      StatefulBuilder(
        builder: (context, setState) {
          final canSubmit = reasonController.text.trim().isNotEmpty && !isLoading;
          return AlertDialog(
            title: Text('cancel_visit'.tr),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${'cancel_visit_confirm_prefix'.tr} ${visit.propertyTitle}?'),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  enabled: !isLoading,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'reason_required_label'.tr,
                    hintText: 'reason_required_hint'.tr,
                    filled: true,
                    fillColor: AppDesign.inputBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppDesign.border),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: isLoading ? null : () => Get.back(), child: Text('no'.tr)),
              ElevatedButton(
                onPressed: canSubmit
                    ? () async {
                        final reason = reasonController.text.trim();

                        setState(() {
                          isLoading = true;
                        });

                        final success = await widget.controller.cancelVisit(
                          visit.id.toString(),
                          reason: reason,
                        );

                        if (success) {
                          Get.back();
                        } else {
                          setState(() {
                            isLoading = false;
                          });
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppDesign.errorRed,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppDesign.overlayLight),
                        ),
                      )
                    : Text('yes_cancel'.tr),
              ),
            ],
          );
        },
      ),
    ).then((_) {
      reasonController.dispose();
    });
  }
}
