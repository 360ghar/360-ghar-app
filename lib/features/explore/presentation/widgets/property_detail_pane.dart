import 'package:flutter/material.dart';

import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/paper_chrome.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/responsive.dart';
import 'package:ghar360/core/widgets/common/error_states.dart';
import 'package:ghar360/core/widgets/paper/paper_sheet.dart';
import 'package:ghar360/features/property_details/presentation/views/property_details_view.dart';

/// From 840 px a list and the open home show side by side.
bool isTwoPane(BuildContext context) => MediaQuery.sizeOf(context).width >= kMediumBreakpoint;

/// The right pane of Explore and Saved from 840 px: the open home on a paper
/// sheet laid over the page, or a hint to pick one.
class PropertyDetailPane extends StatelessWidget {
  const PropertyDetailPane({super.key, required this.property});

  final PropertyModel? property;

  @override
  Widget build(BuildContext context) {
    final open = property;
    final design = context.design;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 12, 12),
      child: PaperSheet(
        seed: 'pane',
        elevation: PaperElevation.low,
        color: design.surface,
        padding: const EdgeInsets.all(4),
        child: Semantics(
          identifier: 'qa.pane.details',
          child: open == null
              ? ErrorStates.emptyState(
                  title: context.l10n.text('pane_empty_title'),
                  message: context.l10n.text('pane_empty_message'),
                  seed: 'pane',
                )
              // The list beside this pane shows the same home with the same
              // photo hero tag; only the list's photo may fly to a route.
              : HeroMode(
                  enabled: false,
                  child: PropertyDetailsView(
                    key: ValueKey(open.id),
                    propertyId: open.id,
                    initialProperty: open,
                    embedded: true,
                  ),
                ),
        ),
      ),
    );
  }
}
