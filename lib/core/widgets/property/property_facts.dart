import 'package:flutter/material.dart';

import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';

/// Shared, flat building blocks for property facts. Dense screens (the swipe
/// card, property details, visits) use these so a fact looks the same
/// everywhere: a bare knife icon, a value in the display face, a label.

/// A section heading on a dense screen: the words only, no icon tile.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final title = Semantics(
      header: true,
      child: Text(text, style: Theme.of(context).textTheme.headlineSmall),
    );
    // The action goes under the title when both do not fit on one line.
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: trailing == null
          ? SizedBox(width: double.infinity, child: title)
          : OverflowBar(
              alignment: MainAxisAlignment.spaceBetween,
              overflowAlignment: OverflowBarAlignment.start,
              children: [title, trailing!],
            ),
    );
  }
}

/// One fact of a home.
class Fact {
  const Fact(this.icon, this.value, this.label);
  final KnifeIcon icon;
  final String value;
  final String label;
}

/// The key numbers of a home in a flat grid: icon, value, label. Columns
/// follow the width and the text size, so 2x Hindi never overflows.
class FactGrid extends StatelessWidget {
  const FactGrid({super.key, required this.facts});

  final List<Fact> facts;

  @override
  Widget build(BuildContext context) {
    if (facts.isEmpty) return const SizedBox.shrink();
    final design = context.design;
    final text = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final columns = (constraints.maxWidth / (104 * scale)).floor().clamp(1, 4);
        final width = (constraints.maxWidth - 16 * (columns - 1)) / columns;
        Widget words(Fact fact) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              fact.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.headlineSmall,
            ),
            Text(
              fact.label,
              maxLines: 2,
              style: text.bodySmall?.copyWith(color: design.textSecondary),
            ),
          ],
        );
        Widget icon(Fact fact) => PaperIcon(fact.icon, size: 22, color: design.accent);
        return Wrap(
          spacing: 16,
          runSpacing: 18,
          children: [
            for (final fact in facts)
              SizedBox(
                width: width,
                child: Semantics(
                  label: '${fact.label}: ${fact.value}',
                  excludeSemantics: true,
                  // One column (large text, narrow screen): the icon goes
                  // beside the value, so each fact is one short row.
                  child: columns == 1
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              // Centred on the value's first line.
                              padding: EdgeInsets.only(
                                top: ((MediaQuery.textScalerOf(context).scale(19) * 1.25 - 22) / 2)
                                    .clamp(0.0, 40.0),
                              ),
                              child: icon(fact),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: words(fact)),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [icon(fact), const SizedBox(height: 6), words(fact)],
                        ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Secondary facts as label and value rows.
class FactRows extends StatelessWidget {
  const FactRows({super.key, required this.facts});

  final List<Fact> facts;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        for (final fact in facts)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PaperIcon(fact.icon, size: 18, color: design.textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    fact.label,
                    style: text.bodyMedium?.copyWith(color: design.textSecondary),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    fact.value,
                    textAlign: TextAlign.end,
                    style: text.bodyMedium?.copyWith(
                      color: design.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Amenities as a two-column list of knife icons and names, not chips.
class AmenityList extends StatelessWidget {
  const AmenityList({super.key, required this.amenities, this.max, this.moreLabel});

  final List<PropertyAmenity> amenities;

  /// Show at most this many; [moreLabel] says how many are left out.
  final int? max;
  final String Function(int hidden)? moreLabel;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final text = Theme.of(context).textTheme;
    final shown = max == null ? amenities : amenities.take(max!).toList();
    final hidden = amenities.length - shown.length;
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final columns = constraints.maxWidth / scale < 300 ? 1 : 2;
        final width = (constraints.maxWidth - 16 * (columns - 1)) / columns;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                for (final amenity in shown)
                  SizedBox(
                    width: width,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PaperIcon(amenityIcon(amenity), size: 20, color: design.accent),
                        const SizedBox(width: 10),
                        Expanded(child: Text(amenity.title, style: text.bodyMedium)),
                      ],
                    ),
                  ),
              ],
            ),
            if (hidden > 0 && moreLabel != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  moreLabel!(hidden),
                  style: text.labelMedium?.copyWith(color: design.textSecondary),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The backend's amenity icon keys, as on the website (`amenities.ts`).
const _amenityKeys = {
  'shield-check': KnifeIcon.shield,
  'clock': KnifeIcon.shield,
  'gate': KnifeIcon.shield,
  'camera': KnifeIcon.camera,
  'phone': KnifeIcon.phone,
  'garage': KnifeIcon.parking,
  'car': KnifeIcon.parking,
  'elevator': KnifeIcon.lift,
  'fitness': KnifeIcon.gym,
  'dumbbell': KnifeIcon.gym,
  'pool': KnifeIcon.pool,
  'tree': KnifeIcon.tree,
  'tree-pine': KnifeIcon.tree,
  'park': KnifeIcon.tree,
  'battery': KnifeIcon.power,
  'generator': KnifeIcon.power,
  'water': KnifeIcon.water,
  'droplets': KnifeIcon.water,
  'wifi': KnifeIcon.wifi,
  'internet': KnifeIcon.wifi,
  'train': KnifeIcon.metro,
  'building': KnifeIcon.building,
  'trash': KnifeIcon.trash,
  'playground': KnifeIcon.playground,
  'running': KnifeIcon.track,
};

/// The knife icon for an amenity: its backend icon key first, then its name.
KnifeIcon amenityIcon(PropertyAmenity amenity) {
  final byKey = _amenityKeys[amenity.icon];
  if (byKey != null) return byKey;
  final t = amenity.title.toLowerCase();
  return switch (t) {
    _ when t.contains('pool') || t.contains('swim') => KnifeIcon.pool,
    _ when t.contains('gym') || t.contains('fitness') => KnifeIcon.gym,
    _ when t.contains('parking') || t.contains('garage') => KnifeIcon.parking,
    _ when t.contains('wifi') || t.contains('internet') => KnifeIcon.wifi,
    _ when t.contains('security') || t.contains('cctv') || t.contains('guard') => KnifeIcon.shield,
    _ when t.contains('lift') || t.contains('elevator') => KnifeIcon.lift,
    _ when t.contains('garden') || t.contains('lawn') || t.contains('park') => KnifeIcon.tree,
    _ when t.contains('power') || t.contains('backup') || t.contains('generator') =>
      KnifeIcon.power,
    _ when t.contains('club') || t.contains('community') => KnifeIcon.guests,
    _ when t.contains('play') || t.contains('kids') || t.contains('child') => KnifeIcon.playground,
    _ when t.contains('jog') || t.contains('track') => KnifeIcon.track,
    _ when t.contains('water') => KnifeIcon.water,
    _ when t.contains('furnish') => KnifeIcon.sofa,
    _ when t.contains('balcony') => KnifeIcon.balcony,
    _ when t.contains('metro') => KnifeIcon.metro,
    _ => KnifeIcon.check,
  };
}
