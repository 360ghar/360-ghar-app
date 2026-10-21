import 'package:flutter/material.dart';

import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/presentation/property_labels.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/app_spacing.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';
import 'package:ghar360/core/widgets/property/property_facts.dart';
import 'package:ghar360/features/discover/presentation/widgets/swipe_card_details_section.dart';

/// Type, price, title, place and the key numbers: the scannable top block.
class PropertyDetailsOverview extends StatelessWidget {
  const PropertyDetailsOverview({super.key, required this.property, this.onLocationTap});

  final PropertyModel property;
  final VoidCallback? onLocationTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final design = context.design;
    final l10n = context.l10n;
    final suffix = property.effectivePrice == null
        ? null
        : switch (property.purpose) {
            PropertyPurpose.rent => l10n.text('per_month_short'),
            PropertyPurpose.shortStay => l10n.text('per_day_short'),
            _ => null,
          };
    final address = property.shortAddressDisplay.trim();
    // Centre of the address's first line (its glyphs sit a little below the
    // middle of the line box).
    final size = MediaQuery.textScalerOf(context).scale(14);
    final firstLine = ((size * 1.5 - 18) / 2 + size * 0.08).clamp(0.0, 24.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${l10n.text(property.propertyTypeLabelKey)} · '
          '${l10n.text(property.listingTranslationKey)}',
          style: text.labelLarge?.copyWith(color: design.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text.rich(
          TextSpan(
            text: property.localizedPrice(context),
            style: text.displayMedium,
            children: [
              if (suffix != null)
                TextSpan(
                  text: suffix,
                  style: text.titleSmall?.copyWith(color: design.textSecondary),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(property.title, style: text.titleLarge),
        if (address.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Material(
            // Own ink layer: the white sheet below would hide the press colour.
            type: MaterialType.transparency,
            child: InkWell(
              key: const ValueKey('qa.property_details.address'),
              onTap: onLocationTap,
              borderRadius: BorderRadius.circular(AppBorderRadius.sm),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  // The marks sit on the first line of the address when it wraps.
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: firstLine),
                        child: PaperIcon(KnifeIcon.pin, size: 18, color: design.accent),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          address,
                          style: text.bodyMedium?.copyWith(color: design.textSecondary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (onLocationTap != null)
                        Padding(
                          padding: EdgeInsets.only(top: (firstLine - 1).clamp(0.0, 20.0)),
                          child: PaperIcon(
                            KnifeIcon.chevronRight,
                            size: 20,
                            color: design.textTertiary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        FactGrid(facts: keyFacts(context, property)),
      ],
    );
  }
}
