import 'package:flutter/material.dart';

import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/design/paper/paper_chrome.dart';
import 'package:ghar360/core/map/mini_map_view.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/app_spacing.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';
import 'package:ghar360/core/widgets/property/property_facts.dart';

/// Address, a map and directions. Flat, like the swipe card.
class PropertyDetailsLocationCard extends StatelessWidget {
  const PropertyDetailsLocationCard({
    super.key,
    required this.property,
    required this.onOpenDirections,
  });

  final PropertyModel property;
  final VoidCallback onOpenDirections;

  @override
  Widget build(BuildContext context) {
    final lat = property.latitude;
    final lng = property.longitude;
    if (lat == null || lng == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final design = context.design;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          l10n.text('location'),
          trailing: TextButton(
            key: const ValueKey('qa.property_details.open_in_maps'),
            onPressed: onOpenDirections,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text(l10n.text('directions'))),
                const SizedBox(width: 6),
                const PaperIcon(KnifeIcon.arrowUpRight, size: 16),
              ],
            ),
          ),
        ),
        if (property.shortAddressDisplay.isNotEmpty)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PaperIcon(KnifeIcon.pin, size: 18, color: design.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  property.shortAddressDisplay,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: design.textSecondary),
                ),
              ),
            ],
          ),
        const SizedBox(height: AppSpacing.md),
        // The map is a print with a hand-cut edge.
        ClipPath(
          clipper: const ShapeBorderClipper(shape: CutBorder(seed: 'map')),
          child: SizedBox(
            height: 220,
            child: MiniMapView(latitude: lat, longitude: lng),
          ),
        ),
      ],
    );
  }
}
