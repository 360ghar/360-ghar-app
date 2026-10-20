import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:url_launcher/url_launcher.dart';

import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/design/paper/paper_chrome.dart';
import 'package:ghar360/core/presentation/property_labels.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/app_toast.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/core/utils/indian_currency.dart';
import 'package:ghar360/core/widgets/paper/paper_icon.dart';
import 'package:ghar360/core/widgets/property/property_facts.dart';

/// What kind of home it is: type, purpose, tenant rules and age.
class PropertyDetailsInfoSection extends StatelessWidget {
  final PropertyModel property;

  const PropertyDetailsInfoSection({super.key, required this.property});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _FactSection(
      title: l10n.text('property_information'),
      facts: [
        Fact(
          KnifeIcon.building,
          l10n.text(property.propertyTypeLabelKey),
          l10n.text('property_type'),
        ),
        Fact(KnifeIcon.key, l10n.text(property.purposeTranslationKey), l10n.text('purpose')),
        if (property.genderPreferenceTranslationKey case final key?)
          Fact(KnifeIcon.guests, l10n.text(key), l10n.text('gender_preference')),
        if (property.sharingTypeTranslationKey case final key?)
          Fact(KnifeIcon.sofa, l10n.text(key), l10n.text('room_type')),
        if (property.localizedAge(context).isNotEmpty)
          Fact(KnifeIcon.age, property.localizedAge(context), l10n.text('age')),
      ],
    );
  }
}

/// Price rows that fit the purpose: sale, monthly rent or daily rate.
class PropertyDetailsPricingSection extends StatelessWidget {
  final PropertyModel property;

  const PropertyDetailsPricingSection({super.key, required this.property});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    String rupees(double value) => IndianCurrency.full(value);
    final deposit = property.securityDeposit;
    final maintenance = property.maintenanceCharges;
    final perSqft = property.pricePerSqft;
    final facts = switch (property.purpose) {
      PropertyPurpose.rent => [
        Fact(
          KnifeIcon.rupee,
          rupees(property.monthlyRent ?? property.basePrice),
          l10n.text('monthly_rent'),
        ),
        if (deposit != null) Fact(KnifeIcon.shield, rupees(deposit), l10n.text('security_deposit')),
        if (maintenance != null)
          Fact(KnifeIcon.receipt, rupees(maintenance), l10n.text('maintenance')),
      ],
      PropertyPurpose.shortStay => [
        // No base_price fallback: a short stay without a nightly rate has no daily price.
        if (property.nightlyRate ?? property.dailyRate case final rate?)
          Fact(KnifeIcon.rupee, rupees(rate), l10n.text('daily_rate')),
        if (deposit != null) Fact(KnifeIcon.shield, rupees(deposit), l10n.text('security_deposit')),
      ],
      _ => [
        Fact(KnifeIcon.rupee, rupees(property.basePrice), l10n.text('sale_price')),
        if (perSqft != null) Fact(KnifeIcon.area, rupees(perSqft), l10n.text('price_per_sq_ft')),
        if (maintenance != null)
          Fact(KnifeIcon.receipt, rupees(maintenance), l10n.text('maintenance')),
      ],
    };
    return _FactSection(title: l10n.text('pricing_details'), facts: facts);
  }
}

/// The builder of the project.
class PropertyDetailsContactSection extends StatelessWidget {
  final PropertyModel property;

  const PropertyDetailsContactSection({super.key, required this.property});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final builder = property.builderName;
    return _FactSection(
      title: l10n.text('builder_information'),
      facts: [
        if (builder != null && builder.isNotEmpty)
          Fact(KnifeIcon.briefcase, builder, l10n.text('builder')),
      ],
    );
  }
}

/// The 360 Ghar agent for the listing. Call shows only when the backend
/// sends a number; it hides the number from some viewers.
class PropertyDetailsAgentRow extends StatelessWidget {
  const PropertyDetailsAgentRow({super.key, required this.agent});

  final PropertyAgent agent;

  Future<void> _call(BuildContext context, String number) async {
    try {
      final launched = await launchUrl(Uri(scheme: 'tel', path: number));
      if (launched || !context.mounted) return;
    } catch (error) {
      DebugLogger.warning('Agent call launch failed: ${error.runtimeType}');
      if (!context.mounted) return;
    }
    AppToast.error(context.l10n.text('error'), context.l10n.text('unable_to_open_link'));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final design = context.design;
    final number = agent.contactNumber?.trim() ?? '';
    // A visiting card laid on the sheet, a little askew: mint card stock with
    // a hand-cut edge and a short shadow on the sheet.
    return Semantics(
      container: true,
      identifier: 'qa.property_details.agent',
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Transform.rotate(
            angle: -0.6 * math.pi / 180,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: design.slip,
                shape: CutBorder(
                  seed: 'agent-${agent.id}',
                  amp: 1.5,
                  shadows: paperShadows(PaperElevation.low, design.shadowOn(design.surface)),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 8, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.text('listed_by'),
                            style: text.labelSmall?.copyWith(color: design.textSecondary),
                          ),
                          const SizedBox(height: 2),
                          Text(agent.name, style: text.headlineSmall),
                        ],
                      ),
                    ),
                    if (number.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Semantics(
                        identifier: 'qa.property_details.agent_call',
                        child: TextButton(
                          key: const ValueKey('qa.property_details.agent_call'),
                          onPressed: () => _call(context, number),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const PaperIcon(KnifeIcon.phone, size: 18),
                              const SizedBox(width: 6),
                              Text(l10n.text('call')),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FactSection extends StatelessWidget {
  const _FactSection({required this.title, required this.facts});

  final String title;
  final List<Fact> facts;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SectionTitle(title),
      FactRows(facts: facts),
    ],
  );
}
