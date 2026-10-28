import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/widgets/common/location_selector.dart';
import 'package:ghar360/features/properties/application/property_location.dart';

/// One quiet line under the top bar while the page shows the Gurugram
/// fallback, with a Change action that opens the location picker. It is gone once the user picks a place or a fix inside the area
/// arrives.
class OutOfAreaNote extends ConsumerWidget {
  const OutOfAreaNote({super.key, required this.pageType});
  final PageType pageType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fallback = ref.watch(
      propertyLocationProvider(pageType).select((state) => state.source == LocationSource.fallback),
    );
    if (!fallback) return const SizedBox.shrink();
    final style = Theme.of(context).textTheme.bodySmall;
    // The left edge matches the place name in the top bar (12 bar + 8 control).
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
      child: Row(
        children: [
          Flexible(
            child: Text(
              context.l10n.text('out_of_area_note'),
              key: const ValueKey('qa.out_of_area_note'),
              style: style?.copyWith(color: context.design.textSecondary),
            ),
          ),
          // Choosing another area by hand, for a visitor who declined location.
          Semantics(
            identifier: 'qa.${pageType.name}.out_of_area.change',
            child: TextButton(
              key: ValueKey('qa.${pageType.name}.out_of_area.change'),
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 44),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                textStyle: style?.copyWith(fontWeight: FontWeight.w600),
              ),
              onPressed: () => showLocationPicker(context, pageType: pageType),
              child: Text(context.l10n.text('change')),
            ),
          ),
        ],
      ),
    );
  }
}
