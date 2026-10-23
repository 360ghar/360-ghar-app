import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/features/properties/application/property_location.dart';

/// One quiet line under the top bar while the page shows the Gurugram
/// fallback. It is gone once the user picks a place or a fix inside the area
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
    // The left edge matches the place name in the top bar (12 bar + 8 control).
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          context.l10n.text('out_of_area_note'),
          key: const ValueKey('qa.out_of_area_note'),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.design.textSecondary),
        ),
      ),
    );
  }
}
