import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/design/app_design_extensions.dart';
import 'package:ghar360/core/utils/app_spacing.dart';

class PropertyDetailsFeatures extends StatelessWidget {
  final PropertyModel property;

  const PropertyDetailsFeatures({super.key, required this.property});

  @override
  Widget build(BuildContext context) {
    final items = <_FeatureItem>[
      if (property.bedrooms != null)
        _FeatureItem(Icons.bed_rounded, '${property.bedrooms}', 'bedrooms'.tr),
      if (property.bathrooms != null)
        _FeatureItem(Icons.bathtub_outlined, '${property.bathrooms}', 'bathrooms'.tr),
      if (property.areaSqft != null)
        _FeatureItem(Icons.square_foot, '${property.areaSqft?.toInt()}', 'sq_ft'.tr),
      if (property.balconies != null)
        _FeatureItem(Icons.balcony, '${property.balconies}', 'balconies'.tr),
      if (property.parkingSpaces != null)
        _FeatureItem(Icons.local_parking, '${property.parkingSpaces}', 'parking'.tr),
      if (property.floorNumber != null)
        _FeatureItem(
          Icons.layers_outlined,
          '${property.floorNumber}/${property.totalFloors ?? "?"}',
          'floor'.tr,
        ),
    ];

    if (items.isEmpty) return const SizedBox.shrink();

    final rows = <List<_FeatureItem>>[];
    for (var i = 0; i < items.length; i += 3) {
      rows.add(items.sublist(i, i + 3 > items.length ? items.length : i + 3));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppDesign.surface,
        borderRadius: BorderRadius.circular(AppBorderRadius.card),
        border: Border.all(color: AppDesign.border.withValues(alpha: 0.7)),
        boxShadow: AppDesign.getCardShadow(),
      ),
      child: Column(
        children: [
          for (var r = 0; r < rows.length; r++) ...[
            if (r > 0) ...[
              const SizedBox(height: 12),
              Divider(height: 1, color: AppDesign.border.withValues(alpha: 0.8)),
              const SizedBox(height: 12),
            ],
            IntrinsicHeight(
              child: Row(
                children: [
                  for (var i = 0; i < rows[r].length; i++) ...[
                    if (i > 0)
                      VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: AppDesign.border.withValues(alpha: 0.8),
                        indent: 4,
                        endIndent: 4,
                      ),
                    Expanded(child: _buildFeature(rows[r][i])),
                  ],
                  // Keep row balance when fewer than 3 items.
                  for (var i = rows[r].length; i < 3 && rows[r].length < 3; i++)
                    const Expanded(child: SizedBox.shrink()),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFeature(_FeatureItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(item.icon, color: AppDesign.primaryYellow, size: 22),
          const SizedBox(height: 6),
          Text(
            item.value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppDesign.textPrimary,
              height: 1.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            item.label,
            style: TextStyle(
              fontSize: 11,
              color: AppDesign.textSecondary,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _FeatureItem {
  const _FeatureItem(this.icon, this.value, this.label);

  final IconData icon;
  final String value;
  final String label;
}
