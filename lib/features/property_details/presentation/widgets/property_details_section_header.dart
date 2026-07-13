import 'package:flutter/material.dart';

import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/utils/app_spacing.dart';

/// Shared section title used across property details cards and blocks.
class PropertyDetailsSectionHeader extends StatelessWidget {
  const PropertyDetailsSectionHeader(
    this.title, {
    super.key,
    this.padding = const EdgeInsets.only(bottom: 12),
  });

  final String title;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: AppDesign.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: 56,
            height: 2,
            decoration: BoxDecoration(
              color: AppDesign.primaryYellow.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(AppBorderRadius.round),
            ),
          ),
        ],
      ),
    );
  }
}
