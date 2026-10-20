import 'package:flutter/material.dart';

import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';
import 'package:ghar360/core/widgets/property/property_facts.dart';

/// Amenities as the shared two-column list, with show more and show less.
class PropertyDetailsAmenitiesGrid extends StatefulWidget {
  const PropertyDetailsAmenitiesGrid({super.key, required this.property});

  final PropertyModel property;

  @override
  State<PropertyDetailsAmenitiesGrid> createState() => _PropertyDetailsAmenitiesGridState();
}

class _PropertyDetailsAmenitiesGridState extends State<PropertyDetailsAmenitiesGrid> {
  static const int _collapsedCount = 8;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final amenities = widget.property.amenitiesData;
    if (amenities.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final canExpand = amenities.length > _collapsedCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(l10n.text('amenities')),
        AmenityList(amenities: amenities, max: _expanded ? null : _collapsedCount),
        if (canExpand)
          TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    _expanded
                        ? l10n.text('show_less_amenities')
                        : l10n.text(
                            'more_amenities',
                            params: {'count': '${amenities.length - _collapsedCount}'},
                          ),
                  ),
                ),
                const SizedBox(width: 4),
                PaperIcon(_expanded ? KnifeIcon.chevronUp : KnifeIcon.chevronDown, size: 18),
              ],
            ),
          ),
      ],
    );
  }
}
