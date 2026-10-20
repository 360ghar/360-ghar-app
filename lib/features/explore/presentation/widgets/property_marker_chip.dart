import 'package:flutter/material.dart';

import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/paper_chrome.dart';
import 'package:ghar360/core/translations/app_localizations.dart';

/// A price slip pinned on the map. The selected home is a gold slip lifted a
/// little higher; nothing pulses.
class PropertyMarkerChip extends StatelessWidget {
  final PropertyModel property;
  final bool isSelected;
  final VoidCallback onTap;
  final String label;

  const PropertyMarkerChip({
    super.key,
    required this.property,
    required this.isSelected,
    required this.onTap,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final semanticLabel = property.title.isNotEmpty
        ? context.l10n.text('property_price_marker_label', params: {'property': property.title})
        : context.l10n.text('property_price_marker_label_generic');
    return Semantics(
      label: semanticLabel,
      button: true,
      selected: isSelected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // The slip is small; the tap target stays 48 px.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48, maxWidth: 120),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: RepaintBoundary(
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: isSelected ? design.buttonPrimary : design.surface,
                  shape: CutBorder(
                    seed: 'marker',
                    amp: 1.5,
                    shadows: paperShadows(
                      isSelected ? PaperElevation.mid : PaperElevation.low,
                      design.shadowOn(design.background),
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  // A map label is pinned to a place: it grows to 1.3x at most,
                  // and the full label is in the semantics above.
                  child: MediaQuery.withClampedTextScaling(
                    maxScaleFactor: 1.3,
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: isSelected ? design.buttonPrimaryText : design.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
