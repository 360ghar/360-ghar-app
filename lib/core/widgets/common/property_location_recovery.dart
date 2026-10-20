import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/design/paper/paper_chrome.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/widgets/common/error_states.dart';
import 'package:ghar360/core/widgets/common/loading_states.dart';
import 'package:ghar360/core/widgets/common/location_selector.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';
import 'package:ghar360/core/widgets/paper/paper_vignette.dart';
import 'package:ghar360/features/properties/application/property_location.dart';

/// Retry the missing input before requesting properties again. Existing content
/// uses the inline variant so a GPS failure does not hide the feed or map.
class PropertyLocationRecovery extends ConsumerWidget {
  const PropertyLocationRecovery({super.key, required this.pageType, this.inline = false});

  final PageType pageType;
  final bool inline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(propertyLocationProvider(pageType));
    final error = location.load.error;
    final code = error is LocationException ? error.code : null;
    final message = context.l10n.text(switch (code) {
      'LOCATION_DENIED_FOREVER' => 'location_permission_permanently_denied',
      'LOCATION_DENIED' => 'location_permission_denied',
      'LOCATION_DISABLED' => 'location_services_disabled',
      _ => 'unable_to_get_current_location',
    });
    final busy = location.load.isLoading || location.save.isLoading;
    final selectId = 'qa.${pageType.name}.location.select';
    final retryId = 'qa.${pageType.name}.location.gps_retry';
    final content = Padding(
      padding: EdgeInsets.all(inline ? 12 : 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: inline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          if (!inline) ...[
            const MountedVignette(PaperScene.location, seed: 'recovery', width: 220),
            const SizedBox(height: 24),
          ],
          Semantics(
            liveRegion: true,
            child: Text(
              message,
              textAlign: inline ? TextAlign.start : TextAlign.center,
              style: inline
                  ? Theme.of(context).textTheme.bodyMedium
                  : Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: inline ? WrapAlignment.start : WrapAlignment.center,
            children: [
              Semantics(
                identifier: selectId,
                child: FilledButton.icon(
                  key: ValueKey(selectId),
                  style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: busy ? null : () => showLocationPicker(context, pageType: pageType),
                  icon: const PaperIcon(KnifeIcon.pin),
                  label: Text(context.l10n.text('select_location')),
                ),
              ),
              Semantics(
                identifier: retryId,
                child: TextButton.icon(
                  key: ValueKey(retryId),
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: busy
                      ? null
                      : () => ref.read(propertyLocationProvider(pageType).notifier).useCurrent(),
                  icon: const PaperIcon(KnifeIcon.locate),
                  label: Stack(
                    alignment: Alignment.center,
                    children: [
                      Opacity(opacity: busy ? 0 : 1, child: Text(context.l10n.text('retry_gps'))),
                      if (busy)
                        LoadingStates.buttonSpinner(
                          semanticsLabel: context.l10n.text('getting_location'),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    // Inline, it is a caution slip over the kept feed, like a retry banner.
    return inline
        ? Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: context.design.notice,
                shape: CutBorder(seed: 'location-$selectId', amp: 1.5),
              ),
              child: content,
            ),
          )
        : Center(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: content,
              ),
            ),
          );
  }
}
