import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/utils/app_spacing.dart';
import 'package:ghar360/core/widgets/property/property_details_features.dart';

/// Price, title, location line, type chips, and key stats — the scannable top block.
class PropertyDetailsOverview extends StatelessWidget {
  const PropertyDetailsOverview({super.key, required this.property, this.onLocationTap});

  final PropertyModel property;
  final VoidCallback? onLocationTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chip(context, property.propertyTypeTranslationKey.tr),
            _chip(context, property.listingTranslationKey.tr),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: property.formattedPrice,
                style: theme.textTheme.displaySmall?.copyWith(
                  color: AppDesign.textPrimary,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
              if (property.purpose == PropertyPurpose.rent)
                TextSpan(
                  text: 'per_month_short'.tr,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppDesign.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (property.purpose == PropertyPurpose.shortStay)
                TextSpan(
                  text: 'per_day_short'.tr,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppDesign.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          property.title,
          style: theme.textTheme.titleLarge?.copyWith(
            color: AppDesign.textPrimary,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        ),
        if (property.shortAddressDisplay.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Material(
            color: AppDesign.transparent,
            child: InkWell(
              onTap: onLocationTap,
              borderRadius: BorderRadius.circular(AppBorderRadius.sm),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_rounded, size: 18, color: AppDesign.primaryYellow),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        property.shortAddressDisplay,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppDesign.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (onLocationTap != null)
                      Icon(Icons.chevron_right_rounded, size: 20, color: AppDesign.textTertiary),
                  ],
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        PropertyDetailsFeatures(property: property),
      ],
    );
  }

  Widget _chip(BuildContext context, String text) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppDesign.inputBackground : AppDesign.warmCream,
        borderRadius: BorderRadius.circular(AppBorderRadius.round),
        border: Border.all(color: AppDesign.primaryYellow.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isDark ? AppDesign.textPrimary : AppDesign.editorialInk,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
