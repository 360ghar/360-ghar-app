import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';
import 'package:ghar360/core/widgets/paper/paper_vignette.dart';
import 'package:ghar360/features/location/application/location_source.dart';
import 'package:ghar360/features/properties/application/property_location.dart';
import 'package:ghar360/features/splash/presentation/controllers/splash_controller.dart';

/// Shows the location explainer once per device, on the first Discover visit
/// while the location permission is still undecided. The OS prompt appears
/// only after the user taps Allow.
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
    final allow = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const LocationExplainerSheet(),
    );
    if (!mounted) return;
    await ref.read(onboardingProvider.notifier).markLocationExplained();
    if (allow == true) {
      await ref.read(propertyLocationProvider(PageType.discover).notifier).useCurrent();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Why the app asks for location, before the OS asks. Pops `true` for
/// Allow and `false` for Not now.
class LocationExplainerSheet extends StatelessWidget {
  const LocationExplainerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    return SafeArea(
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
                  onPressed: () => Navigator.of(context).pop(true),
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
            const SizedBox(height: 4),
            Semantics(
              identifier: 'qa.location.explainer.skip',
              child: TextButton(
                key: const ValueKey('qa.location.explainer.skip'),
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.text('location_explainer_skip')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
