import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/widgets/common/symmetric_safe_area.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';
import 'package:ghar360/core/widgets/paper/paper_vignette.dart';
import 'package:ghar360/features/location/application/location_source.dart';
import 'package:ghar360/features/properties/application/property_location.dart';
import 'package:ghar360/features/splash/presentation/controllers/splash_controller.dart';

/// Shows the location explainer once per device, on the first Discover visit
/// while the location permission is still undecided. The OS prompt appears
/// after the user taps Continue.
class LocationExplainerGate extends ConsumerStatefulWidget {
  const LocationExplainerGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LocationExplainerGate> createState() => _LocationExplainerGateState();
}

class _LocationExplainerGateState extends ConsumerState<LocationExplainerGate> {
  var _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeExplain());
  }

  Future<void> _maybeExplain() async {
    if (!mounted || _checked) return;
    _checked = true;
    if (ref.read(onboardingProvider).locationExplained) return;
    bool undecided;
    try {
      undecided = await ref.read(deviceLocationSourceProvider).permissionUndetermined();
    } on Object {
      // A missing or broken location plugin must never block Discover.
      return;
    }
    // Hidden shell tabs keep their state; only the visible tab may ask.
    if (!mounted || !undecided || !TickerMode.valuesOf(context).enabled) return;
    // App Review 5.1.1(iv): the message has one Continue button, cannot be
    // dismissed, and is always followed by the OS prompt.
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => const LocationExplainerSheet(),
    );
    if (!mounted) return;
    await ref.read(onboardingProvider.notifier).markLocationExplained();
    await ref.read(propertyLocationProvider(PageType.discover).notifier).useCurrent(quiet: true);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Why the app asks for location, before the OS asks. Continue is the only
/// way out, and the OS prompt always follows.
class LocationExplainerSheet extends StatelessWidget {
  const LocationExplainerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    return SymmetricSafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PaperVignette(PaperScene.location, seed: 'explainer', width: 260),
            const SizedBox(height: 20),
            Semantics(
              header: true,
              child: Text(
                l10n.text('location_explainer_title'),
                style: text.headlineMedium,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.text('location_explainer_body'),
              style: text.bodyMedium?.copyWith(color: context.design.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: Semantics(
                identifier: 'qa.location.explainer.allow',
                child: FilledButton(
                  key: const ValueKey('qa.location.explainer.allow'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const PaperIcon(KnifeIcon.locate, size: 18),
                      const SizedBox(width: 8),
                      Flexible(child: Text(l10n.text('location_explainer_allow'))),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
