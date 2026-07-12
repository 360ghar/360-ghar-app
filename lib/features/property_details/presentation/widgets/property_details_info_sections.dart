import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/utils/app_spacing.dart';
import 'package:ghar360/features/property_details/presentation/widgets/property_details_section_header.dart';

/// Property information card (purpose, age).
class PropertyDetailsInfoSection extends StatelessWidget {
  final PropertyModel property;

  const PropertyDetailsInfoSection({super.key, required this.property});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      buildInfoRow('property_type'.tr, property.propertyTypeTranslationKey.tr),
      buildInfoRow('purpose'.tr, property.purposeTranslationKey.tr),
      if (property.genderPreferenceTranslationKey != null)
        buildInfoRow('gender_preference'.tr, property.genderPreferenceTranslationKey!.tr),
      if (property.sharingTypeTranslationKey != null)
        buildInfoRow('room_type'.tr, property.sharingTypeTranslationKey!.tr),
      if (property.ageText.isNotEmpty) buildInfoRow('age'.tr, property.ageText),
    ];

    return _DetailsCard(title: 'property_information'.tr, children: _withDividers(rows));
  }
}

/// Pricing details card with purpose-aware rows.
class PropertyDetailsPricingSection extends StatelessWidget {
  final PropertyModel property;

  const PropertyDetailsPricingSection({super.key, required this.property});

  @override
  Widget build(BuildContext context) {
    return _DetailsCard(title: 'pricing_details'.tr, children: _withDividers(_buildPricingRows()));
  }

  List<Widget> _buildPricingRows() {
    final purpose = property.purpose;
    final rows = <Widget>[];

    if (purpose == PropertyPurpose.rent) {
      final rent = property.monthlyRent ?? property.basePrice;
      rows.add(buildInfoRow('monthly_rent'.tr, '₹${rent.toStringAsFixed(0)}', emphasize: true));
      if (property.securityDeposit != null) {
        rows.add(
          buildInfoRow('security_deposit'.tr, '₹${property.securityDeposit!.toStringAsFixed(0)}'),
        );
      }
      if (property.maintenanceCharges != null) {
        rows.add(
          buildInfoRow('maintenance'.tr, '₹${property.maintenanceCharges!.toStringAsFixed(0)}'),
        );
      }
    } else if (purpose == PropertyPurpose.shortStay) {
      final rate = property.dailyRate ?? property.basePrice;
      rows.add(buildInfoRow('daily_rate'.tr, '₹${rate.toStringAsFixed(0)}', emphasize: true));
      if (property.securityDeposit != null) {
        rows.add(
          buildInfoRow('security_deposit'.tr, '₹${property.securityDeposit!.toStringAsFixed(0)}'),
        );
      }
    } else {
      rows.add(
        buildInfoRow('sale_price'.tr, '₹${property.basePrice.toStringAsFixed(0)}', emphasize: true),
      );
      if (property.pricePerSqft != null) {
        rows.add(
          buildInfoRow('price_per_sq_ft'.tr, '₹${property.pricePerSqft!.toStringAsFixed(0)}'),
        );
      }
      if (property.maintenanceCharges != null) {
        rows.add(
          buildInfoRow('maintenance'.tr, '₹${property.maintenanceCharges!.toStringAsFixed(0)}'),
        );
      }
    }

    return rows;
  }
}

/// Builder/contact information card.
class PropertyDetailsContactSection extends StatelessWidget {
  final PropertyModel property;

  const PropertyDetailsContactSection({super.key, required this.property});

  @override
  Widget build(BuildContext context) {
    return _DetailsCard(
      title: 'builder_information'.tr,
      children: [
        if (property.builderName?.isNotEmpty == true)
          buildInfoRow('builder'.tr, property.builderName!),
      ],
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppDesign.surface,
        borderRadius: BorderRadius.circular(AppBorderRadius.card),
        border: Border.all(color: AppDesign.border.withValues(alpha: 0.75)),
        boxShadow: AppDesign.getCardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [PropertyDetailsSectionHeader(title), ...children],
      ),
    );
  }
}

List<Widget> _withDividers(List<Widget> rows) {
  if (rows.isEmpty) return rows;
  final out = <Widget>[];
  for (var i = 0; i < rows.length; i++) {
    out.add(rows[i]);
    if (i < rows.length - 1) {
      out.add(Divider(height: 1, color: AppDesign.border.withValues(alpha: 0.55)));
    }
  }
  return out;
}

/// Shared label–value row used by the info section widgets above.
Widget buildInfoRow(String label, String value, {bool emphasize = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: AppDesign.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: emphasize ? 16 : 14,
              color: AppDesign.textPrimary,
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w600,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    ),
  );
}
