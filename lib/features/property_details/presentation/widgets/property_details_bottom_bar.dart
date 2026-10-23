import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/data/models/visit_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/presentation/property_labels.dart';
import 'package:ghar360/core/providers/pending_actions_provider.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/widgets/common/sign_in_gate.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';
import 'package:ghar360/core/widgets/paper/paper_strip.dart';
import 'package:ghar360/features/property_details/presentation/widgets/property_details_visit_dialog.dart';
import 'package:ghar360/features/visits/presentation/controllers/visits_controller.dart';
import 'package:ghar360/features/visits/presentation/widgets/visit_edit_dialog.dart';
import 'package:go_router/go_router.dart';

class PropertyDetailsBottomBar extends ConsumerWidget {
  const PropertyDetailsBottomBar({super.key, required this.property});
  final PropertyModel property;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcoming = ref.watch(visitsProvider.select((state) => state.upcoming));
    VisitModel? visit;
    for (final candidate in upcoming) {
      if (candidate.propertyId == property.id) {
        visit = candidate;
        break;
      }
    }
    final pending = ref.watch(
      pendingActionsProvider.select(
        (state) => state.actions.any(
          (action) => action.kind == 'visit' && action.payload['property_id'] == property.id,
        ),
      ),
    );
    final scheduledDate = visit?.scheduledDate ?? property.userNextVisitDate;
    final scheduled = visit != null || property.userHasScheduledVisit || scheduledDate != null;
    final confirmed = visit;
    final design = context.design;
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final suffix = property.effectivePrice == null
        ? null
        : switch (property.purpose) {
            PropertyPurpose.rent => l10n.text('per_month_short'),
            PropertyPurpose.shortStay => l10n.text('per_day_short'),
            _ => null,
          };
    // The same cut card-stock strip as the navigation bar, not a hairline rule.
    return PaperStrip(
      seed: 'details-bar',
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12 + PaperStrip.cut, 20, 12),
          child: scheduled || pending
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        PaperIcon(
                          scheduled ? KnifeIcon.check : KnifeIcon.clock,
                          size: 18,
                          color: scheduled ? design.success : design.warning,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.text(scheduled ? 'visit_scheduled' : 'visits_unresolved'),
                            style: text.titleSmall,
                          ),
                        ),
                      ],
                    ),
                    if (scheduledDate != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 26, top: 2),
                        child: Text(
                          '${MaterialLocalizations.of(context).formatMediumDate(scheduledDate.toLocal())}'
                          ' · ${TimeOfDay.fromDateTime(scheduledDate.toLocal()).format(context)}',
                          style: text.bodyMedium,
                        ),
                      ),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: () => context.go(AppRoutes.visits),
                          child: Text(l10n.text('view_visits')),
                        ),
                        if (confirmed != null && confirmed.canReschedule)
                          TextButton(
                            onPressed: () => showVisitEditDialog(context, confirmed, cancel: false),
                            child: Text(l10n.text('reschedule')),
                          ),
                      ],
                    ),
                  ],
                )
              // Price and action share a line when they fit, and stack when
              // the screen is narrow or the text is large.
              : OverflowBar(
                  alignment: MainAxisAlignment.spaceBetween,
                  overflowSpacing: 8,
                  spacing: 12,
                  children: [
                    // The price says what it is; no label over it.
                    Text.rich(
                      TextSpan(
                        text: property.localizedPrice(context),
                        children: [
                          if (suffix != null)
                            TextSpan(
                              text: suffix,
                              style: text.titleSmall?.copyWith(color: design.textSecondary),
                            ),
                        ],
                      ),
                      style: text.headlineMedium,
                    ),
                    FilledButton(
                      key: const ValueKey('qa.property_details.schedule_visit'),
                      onPressed: () async {
                        if (await requireAccount(
                              context,
                              ref,
                              returnTo: '/property/${property.id}',
                            ) &&
                            context.mounted) {
                          showBookVisitDialog(context, property);
                        }
                      },
                      child: Text(l10n.text('schedule_visit'), textAlign: TextAlign.center),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
